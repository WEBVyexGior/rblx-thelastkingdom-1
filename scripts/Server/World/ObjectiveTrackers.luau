--!strict
--[[
	ObjectiveTrackers
	The World bridge between a pure `Objective` and live gameplay. One tracker per
	ObjectiveType connects the relevant world events/loops to a small Context the
	MissionRuntimeService supplies. Trackers push progress via ctx.addProgress /
	setProgress / complete / fail — the pure Objective stays the single source of
	truth; the runtime decides what a completion means.

	Fully functional: Reach, Kill, Survive, Interact. Foundational (functional, minimal
	NPC): Defend, Escort — spawn a neutral NPC and use simple kinematic movement;
	richer behaviour arrives with the AI/Wave systems.

	Place: Forgotten Lands ONLY (Server/World). Phase: Missions.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local CombatService = require(script.Parent.CombatService)
local EnemyService = require(script.Parent.EnemyService)
local WaveService = require(script.Parent.WaveService)
local Objective = require(Server.Domain.Objective)
local Markers = require(ReplicatedStorage.Shared.World.Markers)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local log = Logger.new("ObjectiveTrackers")

local DETECTION_INTERVAL = 0.25
local INTERACT_HOLD_SECONDS = 1.25
local ESCORT_SPEED = 10 -- studs/sec (foundational kinematic)
local DEFAULT_NPC = "villager_npc"

export type Context = {
	players: () -> { Player },
	addProgress: (amount: number) -> (),
	setProgress: (value: number) -> (),
	complete: () -> (),
	fail: () -> (),
	emit: (payload: any) -> (), -- send a raw MissionEvent (progress/narrative) to clients
}

local function rootOf(player: Player): BasePart?
	local char = player.Character
	if not char then
		return nil
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	return (root and root:IsA("BasePart")) and root or nil
end

local function anyPlayerWithin(players: { Player }, pos: Vector3, radius: number): boolean
	for _, player in players do
		local root = rootOf(player)
		if root and (root.Position - pos).Magnitude <= radius then
			return true
		end
	end
	return false
end

-- Runs `fn(dt)` on Heartbeat at most every `interval` seconds. Returns a disconnect.
local function everyInterval(interval: number, fn: (dt: number) -> ()): () -> ()
	local acc = 0
	local conn = RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < interval then
			return
		end
		local elapsed = acc
		acc = 0
		fn(elapsed)
	end)
	return function()
		conn:Disconnect()
	end
end

local Trackers = {}

-- Objective positions may be written as coordinates or as the name of a marker
-- in the map (see Shared.World.Markers). A missing marker is announced loudly:
-- silently falling back to the origin would put the objective somewhere the
-- player can never reach, and read as a broken mission rather than a typo.
local function targetOf(objective: Objective.Objective, label: string): Vector3
	local resolved = Markers.resolve(objective.def.position)
	if resolved then
		return resolved
	end
	log:warn(("%s: cannot resolve position for objective '%s' (%s)"):format(
		label,
		tostring(objective.def.id),
		tostring(objective.def.position)
	))
	return Vector3.zero
end

-- Reach: complete when any player is within radius of the target position.
function Trackers.Reach(objective: Objective.Objective, ctx: Context): () -> ()
	local pos = targetOf(objective, "Reach")
	local radius = objective.def.radius or 8
	local finished = false
	return everyInterval(DETECTION_INTERVAL, function()
		if finished then
			return
		end
		if anyPlayerWithin(ctx.players(), pos, radius) then
			finished = true
			ctx.complete()
		end
	end)
end

-- Interact: proximity-hold — stay within radius for a short time.
function Trackers.Interact(objective: Objective.Objective, ctx: Context): () -> ()
	local pos = targetOf(objective, "Interact")
	local radius = objective.def.radius or 6
	local held = 0
	local finished = false
	return everyInterval(DETECTION_INTERVAL, function(dt)
		if finished then
			return
		end
		if anyPlayerWithin(ctx.players(), pos, radius) then
			held += dt
			if held >= INTERACT_HOLD_SECONDS then
				finished = true
				ctx.complete()
			end
		else
			held = 0
		end
	end)
end

-- Kill: spawn the objective's enemies (if any) and count their deaths toward target.
function Trackers.Kill(objective: Objective.Objective, ctx: Context): () -> ()
	local tracked: { [string]: boolean } = {}
	local spawnedIds: { string } = {}
	local spawns = objective.def.spawns
	if spawns then
		for _, spec in spawns do
			local count = spec.count
			local spread = spec.spread or 0
			for i = 1, count do
				local offset = (i - 1) * spread - ((count - 1) * spread) / 2
				local id = EnemyService.spawn(spec.enemyId, spec.center + Vector3.new(offset, 0, 0))
				tracked[id] = true
				table.insert(spawnedIds, id)
			end
		end
	end

	local disconnect = CombatService.EntityDied:connect(function(entity: any)
		if not tracked[entity.id] then
			return
		end
		tracked[entity.id] = nil
		ctx.addProgress(1)
	end)
	return function()
		disconnect()
		-- Despawn any survivors so leftover enemies never roam after the objective
		-- ends (e.g. the run failed, or a future objective completes early).
		for _, id in spawnedIds do
			if CombatService.getEntity(id) then
				EnemyService.despawn(id)
			end
		end
	end
end

-- Survive: complete after `target` seconds elapse.
function Trackers.Survive(objective: Objective.Objective, ctx: Context): () -> ()
	local seconds = objective.target
	local finished = false
	local elapsed = 0
	local lastReport = 0
	local conn = RunService.Heartbeat:Connect(function(dt)
		if finished then
			return
		end
		elapsed += dt
		if elapsed >= seconds then
			finished = true
			ctx.setProgress(seconds) -- completes
		elseif elapsed - lastReport >= 1 then
			lastReport = elapsed
			ctx.setProgress(math.floor(elapsed))
		end
	end)
	return function()
		conn:Disconnect()
	end
end

-- Defend: keep a spawned neutral target alive for `target` seconds; fail if it dies.
function Trackers.Defend(objective: Objective.Objective, ctx: Context): () -> ()
	local seconds = objective.target
	local pos = targetOf(objective, "Defend")
	local spawns = objective.def.spawns
	local npcId = (spawns and spawns[1] and spawns[1].enemyId) or DEFAULT_NPC
	local id = EnemyService.spawn(npcId, pos)
	local finished = false
	local elapsed = 0
	local lastReport = 0

	local disconnect = CombatService.EntityDied:connect(function(entity: any)
		if not finished and entity.id == id then
			finished = true
			ctx.fail()
		end
	end)
	local conn = RunService.Heartbeat:Connect(function(dt)
		if finished then
			return
		end
		elapsed += dt
		if elapsed >= seconds then
			finished = true
			ctx.setProgress(seconds)
		elseif elapsed - lastReport >= 1 then
			lastReport = elapsed
			ctx.setProgress(math.floor(elapsed))
		end
	end)
	return function()
		disconnect()
		conn:Disconnect()
		EnemyService.despawn(id)
	end
end

-- Escort: move a spawned neutral NPC toward the destination; complete on arrival,
-- fail if it dies. Foundational kinematic movement (no pathfinding).
function Trackers.Escort(objective: Objective.Objective, ctx: Context): () -> ()
	local dest = targetOf(objective, "Escort")
	local radius = objective.def.radius or 6
	local spawns = objective.def.spawns
	local spec = spawns and spawns[1]
	local npcId = (spec and spec.enemyId) or DEFAULT_NPC
	local spawnPos = (spec and spec.center) or (dest + Vector3.new(0, 0, 40))
	local id = EnemyService.spawn(npcId, spawnPos)
	local finished = false

	local disconnect = CombatService.EntityDied:connect(function(entity: any)
		if not finished and entity.id == id then
			finished = true
			ctx.fail()
		end
	end)
	local conn = RunService.Heartbeat:Connect(function(dt)
		if finished then
			return
		end
		local entity = CombatService.getEntity(id)
		if not entity or not entity.model then
			return
		end
		local model = entity.model :: Model
		local cf = model:GetPivot()
		local toDest = dest - cf.Position
		local flat = Vector3.new(toDest.X, 0, toDest.Z)
		if flat.Magnitude <= radius then
			finished = true
			ctx.complete()
			return
		end
		if flat.Magnitude > 0 then
			local stepLen = math.min(ESCORT_SPEED * dt, flat.Magnitude)
			model:PivotTo(cf + flat.Unit * stepLen)
		end
	end)
	return function()
		disconnect()
		conn:Disconnect()
		EnemyService.despawn(id)
	end
end

-- Clear: hand off to the Wave System to run an encounter; complete when it clears,
-- fail if it fails. This is the Mission->Wave seam: the mission decides WHEN, the
-- WaveService decides HOW.
function Trackers.Clear(objective: Objective.Objective, ctx: Context): () -> ()
	local encounterId = objective.def.encounterId
	if not encounterId then
		log:warn("Clear objective without encounterId: " .. tostring(objective.id))
		ctx.complete()
		return function() end
	end
	return WaveService.startEncounter(encounterId, {
		eliteEnemyId = objective.def.eliteEnemyId,
		onWaveStart = function(waveIndex: number, totalWaves: number)
			ctx.emit({ kind = "narrative", text = ("[PLACEHOLDER] Wave %d of %d"):format(waveIndex, totalWaves) })
		end,
		onProgress = function(killed: number, total: number)
			ctx.emit({ kind = "objectiveProgress", current = killed, target = total })
		end,
		onComplete = function()
			ctx.complete()
		end,
		onFail = function()
			ctx.fail()
		end,
	})
end

local ObjectiveTrackers = {}

-- Starts tracking `objective`; returns a `stop` function that MUST be called to
-- disconnect and clean up (on completion or when the run ends).
function ObjectiveTrackers.start(objective: Objective.Objective, ctx: Context): () -> ()
	local fn = Trackers[objective.type]
	if not fn then
		log:warn("no tracker for objective type: " .. tostring(objective.type))
		return function() end
	end
	return fn(objective, ctx)
end

return ObjectiveTrackers
