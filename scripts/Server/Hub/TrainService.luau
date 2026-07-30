--!strict
--[[
	TrainService
	The Kingdom Hub's departure train — the only way out of the lobby and into the
	Forgotten Lands.

	EACH WAGON IS ITS OWN DEPARTURE. Four wagons means four independent parties
	forming side by side, each with its own size, countdown and private world
	server. Nothing about one wagon touches another.

	The flow per wagon:
		1. A glowing footprint marks the wagon. Step into it and the panel opens.
		2. The first player picks a party size (1-8) and CALLS the party. They are
		   placed in the wagon, invisible walls close behind them, and a countdown
		   starts.
		3. Anyone else who steps up can take a seat until it fills. The moment it
		   fills, the countdown RESTARTS at five seconds.
		4. On zero the whole party is teleported into its own private world server.

	Once aboard, the only way out is the Leave button: the walls are on a collision
	group that only boarded players collide with, so a party cannot be jumped,
	climbed or glitched out of — while everyone else walks straight through to
	join. Players leaving never disturbs a running countdown.

	The train does not move. With a single rake, watching it roll away cost frames
	and emptied the platform.

	Server-authoritative: standing in a zone only OFFERS the panel. Boarding is an
	explicit, validated request, so a client can neither seat itself nor board a
	wagon it is not standing in.

	Place: Kingdom Hub only. Phase: Hub Systems.

	Location: ServerScriptService.Server.Hub.TrainService
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local BoardingRoster = require(Server.Domain.BoardingRoster)
local PartyService = require(Server.Services.PartyService)
local MatchService = require(Server.Services.MatchService)
local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local TrainService = {}

TrainService.Name = "TrainService"

local log = Logger.new("TrainService")

local State = {
	Idle = "Idle", -- empty wagon; open to anyone
	Forming = "Forming", -- a party is filling and the countdown is running
	Departing = "Departing", -- teleport in flight; the wagon is closed
}

local BOARDED_GROUP = "TLKBoarded"
local BARRIER_GROUP = "TLKTrainBarrier"
local DEFAULT_GROUP = "Default"

type Berth = {
	index: number,
	wagon: Model,
	zone: BasePart,
	roster: BoardingRoster.BoardingRoster,
	state: string,
	departAt: number?,
	locked: boolean, -- countdown restarted by a full wagon; nothing may disturb it
	barrier: Folder?,
	lastSeconds: number,
	attempts: number, -- teleports tried for this party, successful or not
}

local cfg: any = nil
local barrierCfg: any = nil
local markerCfg: any = nil
local spawnCfg: any = nil
local run: any = nil
local tiers: { BoardingRoster.Tier } = {}

local berths: { Berth } = {}
local spawnPoint: BasePart? = nil
local boardedAt: { [Player]: Berth } = {}
local nearby: { [Player]: Berth } = {}
-- When each standing player's boarding offer runs out. Held on the SERVER so the
-- timeout is real, not a client's promise.
local promptExpires: { [Player]: number } = {}

local trainEvent: RemoteEvent
local boardRequest: RemoteEvent
local leaveRequest: RemoteEvent
local departRequest: RemoteEvent

--============================================================================
-- Collision groups
--============================================================================

-- The barrier only exists for players already aboard. Everyone else must be able
-- to walk through it to reach the wagon and join.
local function setupCollisionGroups()
	for _, group in { BOARDED_GROUP, BARRIER_GROUP } do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(group)
		end)
	end
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(BARRIER_GROUP, BOARDED_GROUP, true)
		PhysicsService:CollisionGroupSetCollidable(BARRIER_GROUP, DEFAULT_GROUP, false)
		PhysicsService:CollisionGroupSetCollidable(BARRIER_GROUP, BARRIER_GROUP, false)
	end)
end

local function setCharacterGroup(player: Player, group: string)
	local character = player.Character
	if not character then
		return
	end
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			pcall(function()
				part.CollisionGroup = group
			end)
		end
	end
end

--============================================================================
-- Station
--============================================================================

-- The footprint is drawn on the ZONE'S OWN FLOOR — i.e. the wagon deck the player
-- actually stands on. Drawing it on the ground below (the obvious first instinct)
-- puts it underneath the train, where the wagon body hides it completely.
local function buildMarker(container: Instance, zone: BasePart)
	if not markerCfg.Enabled then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "Marker"
	folder.Parent = container

	local size = zone.Size
	local halfX, halfZ = size.X / 2, size.Z / 2
	local floorY = -size.Y / 2 + markerCfg.Height
	local thickness = markerCfg.Thickness

	local edges = {
		{ offset = Vector3.new(0, floorY, halfZ), length = Vector3.new(size.X, markerCfg.Height, thickness) },
		{ offset = Vector3.new(0, floorY, -halfZ), length = Vector3.new(size.X, markerCfg.Height, thickness) },
		{ offset = Vector3.new(halfX, floorY, 0), length = Vector3.new(thickness, markerCfg.Height, size.Z) },
		{ offset = Vector3.new(-halfX, floorY, 0), length = Vector3.new(thickness, markerCfg.Height, size.Z) },
	}

	local parts: { Part } = {}
	for index, edge in edges do
		local rail = Instance.new("Part")
		rail.Name = "MarkerEdge" .. index
		rail.Anchored = true
		rail.CanCollide = false
		rail.CanQuery = false
		rail.CanTouch = false
		rail.Material = Enum.Material.Neon
		rail.Color = markerCfg.Color
		rail.Size = edge.length
		-- Relative to the zone, so a hand-moved or rotated zone keeps its outline.
		rail.CFrame = zone.CFrame * CFrame.new(edge.offset)
		rail.Parent = folder
		table.insert(parts, rail)
	end

	local light = Instance.new("PointLight")
	light.Color = markerCfg.Color
	light.Brightness = markerCfg.LightBrightness
	light.Range = markerCfg.LightRange
	light.Shadows = false
	light.Parent = parts[1]

	local info = TweenInfo.new(markerCfg.PulseSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	for _, rail in parts do
		rail.Transparency = 0.55
		TweenService:Create(rail, info, { Transparency = 0.1 }):Play()
	end
	TweenService:Create(light, info, { Brightness = markerCfg.LightBrightness * 2 }):Play()
end

-- A wagon's own bounds, used only when no zone has been placed by hand.
local function autoZone(wagon: Model, parent: Instance, index: number): BasePart
	local boxCFrame, boxSize = wagon:GetBoundingBox()
	local part = Instance.new("Part")
	part.Name = cfg.ZonePrefix .. index .. "Auto"
	part.Size = boxSize + cfg.AutoZonePadding
	part.CFrame = boxCFrame
	part.Parent = parent
	return part
end

local function resolveStation(): boolean
	local lobby = workspace:FindFirstChild(cfg.LobbyFolder)
	local station = if lobby then lobby:FindFirstChild(cfg.StationFolder) else nil
	if not lobby or not station then
		log:warn(("station not found: workspace.%s.%s — train disabled"):format(cfg.LobbyFolder, cfg.StationFolder))
		return false
	end

	-- Where players are put back down when they step off or time out.
	local spawnFolder = lobby:FindFirstChild(spawnCfg.Folder)
	local point = if spawnFolder then spawnFolder:FindFirstChild(spawnCfg.PartName) else nil
	if point and point:IsA("BasePart") then
		spawnPoint = point
	else
		log:warn(("spawn point not found: %s.%s — players will be left where they stand"):format(
			spawnCfg.Folder,
			spawnCfg.PartName
		))
	end

	local wagons: { Model } = {}
	for _, child in station:GetChildren() do
		if child:IsA("Model") and child.Name == cfg.WagonName then
			table.insert(wagons, child)
		end
	end
	if #wagons == 0 then
		log:warn(("no '%s' models under the station — train disabled"):format(cfg.WagonName))
		return false
	end

	-- Front of the rake first, so "Wagon 1" is the one behind the engine.
	table.sort(wagons, function(a, b)
		return a:GetPivot().Position.X > b:GetPivot().Position.X
	end)

	local runtime = Instance.new("Folder")
	runtime.Name = "TrainRuntime"
	runtime.Parent = lobby:FindFirstChild("Invisible") or workspace

	local zoneFolder = lobby:FindFirstChild(cfg.ZoneFolder)
	local placed = 0

	for index, wagon in wagons do
		local zone: BasePart? = nil
		if zoneFolder then
			local candidate = zoneFolder:FindFirstChild(cfg.ZonePrefix .. index)
			if candidate and candidate:IsA("BasePart") then
				zone = candidate
				placed += 1
			end
		end
		if not zone then
			zone = autoZone(wagon, runtime, index)
		end

		local part = zone :: BasePart
		-- However the zone got here, it is a trigger and never a wall.
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Transparency = 1

		local container = Instance.new("Folder")
		container.Name = "Berth" .. index
		container.Parent = runtime
		buildMarker(container, part)

		-- Logged because a zone that does not contain the player is invisible in
		-- every other way: no error, no glow, just a panel that never opens.
		log:info(("  berth %d: zone size %s centre %s"):format(index, tostring(part.Size), tostring(part.Position)))

		table.insert(berths, {
			index = index,
			wagon = wagon,
			zone = part,
			roster = BoardingRoster.new(Constants.MAX_PARTY_SIZE),
			state = State.Idle,
			departAt = nil,
			locked = false,
			barrier = nil,
			lastSeconds = -1,
			attempts = 0,
		})
	end

	log:info(("station ready: %d wagons (%d hand-placed zones, %d generated)"):format(
		#berths,
		placed,
		#berths - placed
	))
	return true
end

--============================================================================
-- Barrier
--============================================================================

local function buildBarrier(berth: Berth)
	if not barrierCfg.Enabled or berth.barrier then
		return
	end

	local zone = berth.zone
	local size = zone.Size
	local height = barrierCfg.Height
	local thickness = barrierCfg.Thickness
	local baseY = -size.Y / 2

	local folder = Instance.new("Folder")
	folder.Name = "Barrier"
	folder.Parent = zone.Parent

	local walls = {
		{ off = Vector3.new(size.X / 2 + thickness / 2, baseY + height / 2, 0), s = Vector3.new(thickness, height, size.Z + thickness * 2) },
		{ off = Vector3.new(-size.X / 2 - thickness / 2, baseY + height / 2, 0), s = Vector3.new(thickness, height, size.Z + thickness * 2) },
		{ off = Vector3.new(0, baseY + height / 2, size.Z / 2 + thickness / 2), s = Vector3.new(size.X + thickness * 2, height, thickness) },
		{ off = Vector3.new(0, baseY + height / 2, -size.Z / 2 - thickness / 2), s = Vector3.new(size.X + thickness * 2, height, thickness) },
	}
	if barrierCfg.Roof then
		table.insert(walls, {
			off = Vector3.new(0, baseY + height, 0),
			s = Vector3.new(size.X + thickness * 2, thickness, size.Z + thickness * 2),
		})
	end

	for index, wall in walls do
		local part = Instance.new("Part")
		part.Name = "Wall" .. index
		part.Anchored = true
		part.CanCollide = true
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = wall.s
		part.CFrame = zone.CFrame * CFrame.new(wall.off)
		pcall(function()
			part.CollisionGroup = BARRIER_GROUP
		end)
		part.Parent = folder
	end

	berth.barrier = folder
end

local function clearBarrier(berth: Berth)
	if berth.barrier then
		berth.barrier:Destroy()
		berth.barrier = nil
	end
end

--============================================================================
-- State helpers
--============================================================================

local function inZone(zone: BasePart, player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local offset = zone.CFrame:PointToObjectSpace(root.Position)
	local half = zone.Size / 2
	return math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z
end

local function berthAt(player: Player): Berth?
	for _, berth in berths do
		if inZone(berth.zone, player) then
			return berth
		end
	end
	return nil
end

local function remainingSeconds(berth: Berth): number
	local deadline = berth.departAt
	if not deadline then
		return 0
	end
	return math.max(math.ceil(deadline - os.clock()), 0)
end

local function statusPayload(berth: Berth): { [string]: any }
	-- Names, not user ids: the panel shows people you are about to fight beside,
	-- and boarding order doubles as the party order (first aboard leads).
	local members: { string } = {}
	for _, member in berth.roster:members() do
		table.insert(members, (member :: Player).Name)
	end

	return {
		kind = "status",
		wagon = berth.index,
		state = berth.state,
		count = berth.roster:count(),
		capacity = berth.roster.capacity,
		tier = BoardingRoster.tierFor(berth.roster:count(), tiers) or "Normal",
		seconds = remainingSeconds(berth),
		members = members,
		leader = members[1],
	}
end

-- Only the people this wagon concerns: those aboard it and those standing in it.
local function notify(berth: Berth)
	local payload = statusPayload(berth)
	for _, player in Players:GetPlayers() do
		if boardedAt[player] == berth or nearby[player] == berth then
			trainEvent:FireClient(player, payload)
		end
	end
end

-- Walks a player back to the camp spawn. Used whenever they stop being part of a
-- departure, so nobody is ever left standing on the rails.
local function returnToSpawn(player: Player)
	local point = spawnPoint
	local character = player.Character
	if not point or not character then
		return
	end
	character:PivotTo(point.CFrame + Vector3.new(0, spawnCfg.DropHeight, 0))
end

local function sendPrompt(player: Player, berth: Berth)
	trainEvent:FireClient(player, statusPayload(berth))

	local mode
	if berth.state == State.Idle then
		mode = "create"
	elseif berth.state == State.Forming and not berth.roster:isFull() then
		mode = "join"
	else
		mode = "full"
	end

	-- The offer stands for a fixed window; a full wagon has nothing to offer, so
	-- it starts no clock.
	if mode == "full" then
		promptExpires[player] = nil
	else
		promptExpires[player] = os.clock() + cfg.PromptWindowSeconds
	end

	trainEvent:FireClient(player, {
		kind = "prompt",
		mode = mode,
		wagon = berth.index,
		windowSeconds = cfg.PromptWindowSeconds,
	})
end

local function seat(player: Player, berth: Berth)
	local character = player.Character
	if not character then
		return
	end
	local boxCFrame, boxSize = berth.wagon:GetBoundingBox()
	character:PivotTo(CFrame.new(boxCFrame.Position + Vector3.new(0, boxSize.Y / 2 + cfg.SeatDropHeight, 0)))
end

local function release(player: Player)
	boardedAt[player] = nil
	promptExpires[player] = nil
	setCharacterGroup(player, DEFAULT_GROUP)
end

local function resetBerth(berth: Berth)
	berth.state = State.Idle
	berth.roster:clear()
	berth.roster:setCapacity(Constants.MAX_PARTY_SIZE)
	berth.departAt = nil
	berth.locked = false
	berth.lastSeconds = -1
	berth.attempts = 0
	clearBarrier(berth)

	for _, player in Players:GetPlayers() do
		if nearby[player] == berth then
			sendPrompt(player, berth)
		end
	end
end

--============================================================================
-- Departure
--============================================================================

local function depart(berth: Berth)
	if berth.state == State.Departing then
		return
	end
	berth.state = State.Departing
	berth.departAt = nil

	local travellers: { Player } = {}
	for _, member in berth.roster:members() do
		local player = member :: Player
		if player.Parent then
			table.insert(travellers, player)
		end
	end
	for _, player in travellers do
		release(player)
	end

	if #travellers == 0 then
		resetBerth(berth)
		return
	end

	local tier = BoardingRoster.tierFor(#travellers, tiers) or "Normal"
	local leader = travellers[1]

	for _, player in travellers do
		PartyService.leaveParty(player)
	end
	local party = PartyService.createParty(leader)
	if not party then
		log:warn("depart: could not create a party for " .. leader.Name)
		resetBerth(berth)
		return
	end
	for index, player in travellers do
		if index > 1 and not PartyService.joinParty(player, party.id) then
			log:warn("depart: " .. player.Name .. " could not join the party")
		end
	end

	log:info(("wagon %d departing with %d player(s) on %s"):format(berth.index, #travellers, tier))
	for _, player in travellers do
		trainEvent:FireClient(player, { kind = "departing", wagon = berth.index })
	end

	berth.attempts += 1
	local _, sent = MatchService.startMatch(leader, run.MissionId, {
		chapterId = run.ChapterId,
		difficulty = tier,
	})

	if not sent then
		-- Nobody went anywhere. Say so, put the party back on board, and try once
		-- more; a teleport can fail for reasons no player caused.
		local retrying = berth.attempts < cfg.DepartureAttempts
		log:warn(("wagon %d departure failed (attempt %d)%s"):format(
			berth.index,
			berth.attempts,
			if retrying then " — retrying" else " — giving up"
		))

		if retrying then
			berth.state = State.Forming
			berth.locked = true -- the retry clock is not up for negotiation
			berth.departAt = os.clock() + cfg.RetrySeconds
			berth.lastSeconds = -1
			for _, player in travellers do
				if player.Parent then
					boardedAt[player] = berth
					setCharacterGroup(player, BOARDED_GROUP)
					-- They were told the train was leaving, which closed their
					-- panel. Put them back on board first, so the explanation
					-- that follows lands on a screen that is showing again.
					trainEvent:FireClient(player, { kind = "aboard", wagon = berth.index })
				end
			end
			notify(berth)
		else
			for _, player in travellers do
				returnToSpawn(player)
			end
			resetBerth(berth)
		end

		for _, player in travellers do
			trainEvent:FireClient(player, {
				kind = "failed",
				wagon = berth.index,
				retrying = retrying,
			})
		end
		return
	end

	-- The party is on its way. The wagon reopens shortly for the next group —
	-- deferred so the poll loop this was called from is never blocked.
	task.delay(2, function()
		resetBerth(berth)
	end)
end

--============================================================================
-- Requests
--============================================================================

local function onBoardRequest(player: Player, requestedSize: any)
	if boardedAt[player] then
		return
	end
	local berth = berthAt(player)
	if not berth or berth.state == State.Departing then
		return
	end

	if berth.state == State.Idle then
		local size = tonumber(requestedSize)
		if not size then
			return
		end
		size = math.clamp(math.floor(size), 1, Constants.MAX_PARTY_SIZE)

		berth.state = State.Forming
		berth.roster:setCapacity(size)
		berth.roster:add(player)
		berth.departAt = os.clock() + cfg.DepartureSeconds
		berth.locked = false
		buildBarrier(berth)
		log:info(("%s called a party of %d in wagon %d"):format(player.Name, size, berth.index))
	elseif berth.roster:isFull() or not berth.roster:add(player) then
		trainEvent:FireClient(player, { kind = "denied", reason = "full" })
		return
	end

	boardedAt[player] = berth
	nearby[player] = berth
	promptExpires[player] = nil -- the offer was taken; no timeout to serve
	setCharacterGroup(player, BOARDED_GROUP)
	seat(player, berth)
	trainEvent:FireClient(player, { kind = "aboard", wagon = berth.index })

	-- A full wagon restarts the countdown at five seconds and LOCKS it: from here
	-- nothing — not even everyone changing their mind — moves the clock.
	if berth.roster:isFull() and not berth.locked then
		berth.locked = true
		berth.departAt = os.clock() + cfg.FullDepartureSeconds
	end

	berth.lastSeconds = -1
	notify(berth)
end

-- The leader may skip the wait. Two friends who are ready should not have to
-- stand in a wagon for half a minute.
local function onDepartRequest(player: Player)
	local berth = boardedAt[player]
	if not berth or berth.state ~= State.Forming then
		return
	end
	if berth.roster:leader() ~= player then
		return
	end
	log:info(("%s departed wagon %d early"):format(player.Name, berth.index))
	depart(berth)
end

local function onLeaveRequest(player: Player)
	local berth = boardedAt[player]
	if not berth or berth.state == State.Departing then
		return
	end

	berth.roster:remove(player)
	release(player)
	nearby[player] = nil
	trainEvent:FireClient(player, { kind = "left", wagon = berth.index })

	-- Straight back to camp: stepping off must never drop the player onto the
	-- rails beside the train.
	returnToSpawn(player)

	-- Leaving never disturbs the countdown; an empty wagon simply reopens.
	if berth.roster:isEmpty() then
		resetBerth(berth)
		return
	end

	notify(berth)
end

--============================================================================
-- Poll
--============================================================================

local function poll()
	for _, player in Players:GetPlayers() do
		local aboard = boardedAt[player]
		if aboard then
			-- Safety net behind the walls: physics can be argued with, this cannot.
			if not inZone(aboard.zone, player) and player.Character then
				seat(player, aboard)
			end
		else
			local berth = berthAt(player)
			if berth ~= nearby[player] then
				nearby[player] = berth
				if berth then
					sendPrompt(player, berth)
				else
					promptExpires[player] = nil
					trainEvent:FireClient(player, { kind = "dismiss" })
				end
			end

			-- Offer expired: close the panel and send them back to camp rather
			-- than leaving them loitering on a wagon they never boarded.
			local expiry = promptExpires[player]
			if expiry and os.clock() >= expiry then
				promptExpires[player] = nil
				nearby[player] = nil
				trainEvent:FireClient(player, { kind = "dismiss" })
				returnToSpawn(player)
			end
		end
	end

	for _, berth in berths do
		if berth.state == State.Forming then
			local remaining = remainingSeconds(berth)
			if remaining ~= berth.lastSeconds then
				berth.lastSeconds = remaining
				notify(berth)
			end
			if remaining <= 0 then
				depart(berth)
			end
		end
	end
end

--============================================================================
-- Lifecycle
--============================================================================

function TrainService.Init()
	local hub = Config.get("Hub")
	cfg = hub.Train
	barrierCfg = hub.Barrier
	markerCfg = hub.Marker
	spawnCfg = hub.Spawn
	run = hub.Run
	tiers = Config.get("Difficulty").Tiers
end

function TrainService.Start()
	trainEvent = Net.getEvent("TrainEvent")
	boardRequest = Net.getEvent("RequestTrainBoard")
	leaveRequest = Net.getEvent("RequestTrainLeave")
	departRequest = Net.getEvent("RequestTrainDepart")

	setupCollisionGroups()

	if not resolveStation() then
		return
	end

	boardRequest.OnServerEvent:Connect(onBoardRequest)
	leaveRequest.OnServerEvent:Connect(onLeaveRequest)
	departRequest.OnServerEvent:Connect(onDepartRequest)

	local function forget(player: Player)
		local berth = boardedAt[player]
		nearby[player] = nil
		if berth then
			berth.roster:remove(player)
			boardedAt[player] = nil
			if berth.roster:isEmpty() and berth.state == State.Forming then
				resetBerth(berth)
			else
				notify(berth)
			end
		end
	end

	Players.PlayerRemoving:Connect(forget)

	-- A respawn puts the player back at the lobby spawn, which is not a wagon.
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			if boardedAt[player] then
				forget(player)
			end
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function()
			if boardedAt[player] then
				forget(player)
			end
		end)
	end

	task.spawn(function()
		while true do
			task.wait(cfg.PollSeconds)
			local ok, err = pcall(poll)
			if not ok then
				log:warn("poll failed: " .. tostring(err))
			end
		end
	end)

	log:info("ready")
end

return TrainService
