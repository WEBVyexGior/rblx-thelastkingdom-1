--!strict
--[[
	DeathService
	Owns what happens WHEN A PLAYER FALLS in the Forgotten Lands. It controls respawn
	(CharacterAutoLoads is off in the World; this service spawns/respawns), tracks each
	run participant's death status, and drives the choices, revive, teammate revive,
	the spectate window, and the run-over (total wipe) that fails the mission.

	Party-aware: a SOLO run is only offered Back to Lobby / Revive (no teammate-dependent
	"Wait"); a multiplayer run also offers Wait, with free teammate revives. A run-over
	does NOT auto-restart — players get a Play Again prompt (handled by ChapterService).

	Mission = WHEN, Wave = HOW, Progression = WHAT YOU EARN, Death = WHAT HAPPENS WHEN
	YOU FALL. Feedback is minimal (a DeathEvent the client prints) — the diegetic death
	parchment (systems/DeathSystem.md) is later Tier 3 polish.

	Place: Forgotten Lands ONLY (Server/World). Phase: Death System.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local GameService = require(Server.Services.GameService)
local CombatService = require(script.Parent.CombatService)
local DataService = require(Server.Services.DataService)
local DeathGroup = require(Server.Domain.DeathGroup)
local CombatEnums = require(ReplicatedStorage.Shared.Combat.Enums)
local DeathEnums = require(ReplicatedStorage.Shared.Death.Enums)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local DeathService = {}

DeathService.Name = "DeathService"

local log = Logger.new("DeathService")

local Choice = DeathEnums.DeathChoice
local Status = DeathEnums.DeathStatus

local deathEvent: RemoteEvent? = nil

-- Death status per player (Alive on spawn). Run tracking + revive bookkeeping.
local status: { [Player]: string } = {}
local downedPosition: { [Player]: Vector3 } = {}
local lastRevive: { [Player]: number } = {}
local reviveProgress: { [Player]: number } = {} -- downed player -> teammate-revive hold time

local runPlayers: { Player } = {}
local runActive = false
local onWipeCb: (() -> ())? = nil

local function fireDeath(player: Player, payload: any)
	if deathEvent then
		deathEvent:FireClient(player, payload)
	end
end

local function entityIdFor(player: Player): string
	return Constants.CombatId.PlayerPrefix .. player.UserId
end

local function rootOf(player: Player): BasePart?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return (root and root:IsA("BasePart")) and root or nil
end

-- True when the run has more than one participant (teammate options are relevant).
local function isMultiplayer(): boolean
	return #runPlayers > 1
end

-- Loads a fresh character (respawn). The CALLER sets the status.
local function loadCharacter(player: Player)
	downedPosition[player] = nil
	reviveProgress[player] = nil
	player:LoadCharacter()
end

-- After a fresh spawn, drops the player's HP to `percent` of max (revive at reduced
-- health). Waits for the new character + its CombatEntity registration.
local function setHealthPercent(player: Player, percent: number)
	task.spawn(function()
		local deadline = os.clock() + 5
		while os.clock() < deadline do
			local entity = CombatService.getEntity(entityIdFor(player))
			if entity and entity:isAlive() and entity.model then
				local target = math.max(1, math.floor(entity.health.max * percent))
				local remove = entity.health.current - target
				if remove > 0 then
					entity.health:damage(remove)
				end
				return
			end
			task.wait(0.1)
		end
	end)
end

local function runStatuses(): { [Player]: string }
	local result: { [Player]: string } = {}
	for _, player in runPlayers do
		result[player] = status[player] or Status.Alive
	end
	return result
end

-- Run-over check: nobody Alive and nobody still Down (deciding). One-shot per run:
-- fails the mission (no auto-restart), respawns everyone idle at spawn, and offers a
-- Play Again prompt.
local function checkRunOver()
	if not runActive or not DeathGroup.isWipe(runStatuses()) then
		return
	end
	runActive = false
	local cb = onWipeCb
	onWipeCb = nil
	log:info("run over (party down)")

	-- Respawn everyone idle at spawn so no one is stuck dead, and prompt Play Again.
	for _, player in runPlayers do
		if player.Parent then
			status[player] = Status.Alive
			loadCharacter(player)
			fireDeath(player, { kind = "wiped" })
		end
	end

	if cb then
		task.spawn(cb) -- mission fails; ChapterService halts (Play Again is manual)
	end
end

-- Revives a player at `percent` HP (self-revive and teammate revive).
local function revive(player: Player, percent: number)
	status[player] = Status.Alive
	loadCharacter(player)
	setHealthPercent(player, percent)
	fireDeath(player, { kind = "revived" })
end

local function trySelfRevive(player: Player)
	local revCfg = Config.get("Economy").Revive
	local now = os.clock()
	if lastRevive[player] and now - lastRevive[player] < (revCfg.CooldownSeconds or 0) then
		fireDeath(player, { kind = "reviveDenied", reason = "cooldown" })
		return
	end
	local profile = DataService.get(player)
	local cost = revCfg.GoldCost or 0
	if not profile or (profile.currency or 0) < cost then
		fireDeath(player, { kind = "reviveDenied", reason = "gold" })
		return
	end
	profile.currency -= cost
	lastRevive[player] = now
	revive(player, revCfg.ReviveHealthPercent or 0.5)
	log:info(("%s self-revived (-%d gold)"):format(player.Name, cost))
end

local function handleChoice(player: Player, choice: string)
	if status[player] ~= Status.Down then
		return -- only a downed player may choose
	end
	if choice == Choice.Revive then
		trySelfRevive(player)
	elseif choice == Choice.Lobby then
		-- Back to Lobby: leave the run. Real Hub teleport is a Multiplayer-flow
		-- follow-up; for now the player is out of the run (a run-over then offers
		-- Play Again). No chapter restart is triggered by this choice itself.
		status[player] = Status.Left
		fireDeath(player, { kind = "leftRun" })
		checkRunOver()
	elseif choice == Choice.Wait and isMultiplayer() then
		status[player] = Status.Waiting
		fireDeath(player, { kind = "waiting" })
		checkRunOver()
	end
	-- A solo player is never offered Wait, so it is ignored here.
end

local function onPlayerDown(player: Player)
	local s = status[player]
	if s ~= Status.Alive then
		return -- already downed / waiting / left: one death flow at a time
	end
	status[player] = Status.Down
	local root = rootOf(player)
	if root then
		downedPosition[player] = root.Position
	end

	local revCfg = Config.get("Economy").Revive
	local profile = DataService.get(player)
	local cost = revCfg.GoldCost or 0
	local spectate = Config.get("Settings").Death.SpectateSeconds
	fireDeath(player, {
		kind = "downed",
		canWait = isMultiplayer(), -- solo runs never offer teammate-dependent Wait
		spectateSeconds = spectate,
		reviveCost = cost,
		canAfford = (profile ~= nil) and ((profile.currency or 0) >= cost),
	})
	log:info(player.Name .. " is down")

	-- Spectate timeout: an undecided player auto-resolves — solo leaves to lobby, a
	-- multiplayer player waits for teammates.
	task.delay(spectate, function()
		if status[player] == Status.Down then
			status[player] = if isMultiplayer() then Status.Waiting else Status.Left
			fireDeath(player, { kind = if isMultiplayer() then "waiting" else "leftRun" })
			checkRunOver()
		end
	end)
end

-- Free teammate revive (multiplayer only): a living run-mate holding position near a
-- downed/waiting player revives them at no cost.
local function updateTeammateRevive(dt: number)
	if not runActive or not isMultiplayer() then
		return
	end
	local revCfg = Config.get("Economy").Revive
	local radius = revCfg.TeammateReviveRadius or 10
	local holdTime = revCfg.FreeTeammateReviveSeconds or 3

	for _, downed in runPlayers do
		local s = status[downed]
		local pos = downedPosition[downed]
		if (s == Status.Down or s == Status.Waiting) and pos then
			local reviverNear = false
			for _, other in runPlayers do
				if other ~= downed and status[other] == Status.Alive then
					local root = rootOf(other)
					if root and (root.Position - pos).Magnitude <= radius then
						reviverNear = true
						break
					end
				end
			end
			if reviverNear then
				reviveProgress[downed] = (reviveProgress[downed] or 0) + dt
				if reviveProgress[downed] >= holdTime then
					revive(downed, revCfg.ReviveHealthPercent or 0.5)
					log:info(downed.Name .. " was revived by a teammate")
				end
			else
				reviveProgress[downed] = 0
			end
		end
	end
end

-- Public: MissionRuntimeService marks the run's players and a run-over callback.
-- Respawns any dead players (so a Play Again / new run brings everyone back).
function DeathService.beginRun(players: { Player }, onWipe: () -> ())
	runPlayers = table.clone(players)
	onWipeCb = onWipe
	runActive = true
	for _, player in players do
		if status[player] ~= Status.Alive then
			status[player] = Status.Alive
			loadCharacter(player)
		end
		status[player] = Status.Alive
	end
end

function DeathService.endRun()
	runActive = false
	runPlayers = {}
	onWipeCb = nil
end

function DeathService.isAlive(player: Player): boolean
	return status[player] == Status.Alive
end

local function onPlayerAdded(player: Player)
	status[player] = Status.Alive
	if not player.Character then
		-- Defer so this spawns AFTER every service has finished Start() — in
		-- particular PlayerCombatService's CharacterAdded handler must be connected
		-- before the character exists, or it would never become a CombatEntity.
		task.defer(function()
			if player.Parent and not player.Character then
				player:LoadCharacter()
			end
		end)
	end
end

function DeathService.Init() end

function DeathService.Start()
	if GameService.getPlaceRole() ~= Constants.PlaceRole.World then
		return -- the Kingdom Hub keeps default auto-spawn; no combat death there
	end

	deathEvent = Net.getEvent("DeathEvent")
	Players.CharacterAutoLoads = false -- this service owns spawning in the World

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		status[player] = nil
		downedPosition[player] = nil
		lastRevive[player] = nil
		reviveProgress[player] = nil
	end)

	-- Death detection through the authoritative combat seam (players only).
	CombatService.EntityDied:connect(function(entity: any)
		if entity.faction == CombatEnums.Faction.Players and entity.model then
			local player = Players:GetPlayerFromCharacter(entity.model)
			if player then
				onPlayerDown(player)
			end
		end
	end)

	Net.getEvent("RequestDeathChoice").OnServerEvent:Connect(function(player: Player, choice: any)
		if typeof(choice) == "string" then
			handleChoice(player, choice)
		end
	end)

	RunService.Heartbeat:Connect(updateTeammateRevive)

	log:info("ready")
end

return DeathService
