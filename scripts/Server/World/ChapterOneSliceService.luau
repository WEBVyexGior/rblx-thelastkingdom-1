--!strict
--[[
	ChapterOneSliceService
	Orchestrator for the Chapter 1 VERTICAL SLICE. It does NOT own combat, enemies,
	or missions — it drives the EXISTING systems' public APIs in sequence to form one
	real gameplay loop:

		Spawn -> Story Intro -> Exploration -> Lore -> Objective -> Undead Encounter
		      -> Combat -> Reward -> End

	It never touches other systems' internals (no rewrites). Player feedback is the
	simplest possible (client prints) — no UI/VFX/animations in this slice.

	STEP 1: scaffold + Story Intro (start-once per player; survives respawn).
	STEP 2: real exploration flow — markers + distance detection advance
	        Exploring -> Lore -> Objective; reaching the objective spawns the first
	        SCRIPTED undead encounter (via EnemyService).
	STEP 3: completion — encounter deaths (via CombatService.EntityDied) -> Reward ->
	        End -> marker cleanup.
	STEP 4 (this commit): the state machine is extracted to the pure, testable
	        Server/Domain/ChapterOneSliceFlow; every transition is validated against it.

	Place: Forgotten Lands ONLY (Server/World). Phase: Chapter 1 integration slice.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Server = script.Parent.Parent
local GameService = require(Server.Services.GameService)
local MissionService = require(Server.Services.MissionService)
local SliceFlow = require(Server.Domain.ChapterOneSliceFlow)
local EnemyService = require(script.Parent.EnemyService)
local CombatService = require(script.Parent.CombatService)
local Net = require(ReplicatedStorage.Shared.Net)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local ChapterOneSliceService = {}

ChapterOneSliceService.Name = "ChapterOneSliceService"

local log = Logger.new("ChapterOneSliceService")

-- State names + transition rules live in the pure domain module (testable).
local States = SliceFlow.States

local playerState: { [Player]: string } = {}
-- Guards the slice to start ONCE per player — respawns must not restart the intro.
local sliceStarted: { [Player]: boolean } = {}
local config: any = nil
local narrativeRemote: RemoteEvent? = nil

-- Scaffolding / run state (STEP 2-3). NOTE: single shared run (single-player slice);
-- per-run encapsulation for multiplayer is later work (see Todo tech debt).
local loreMarker: BasePart? = nil
local objectiveMarker: BasePart? = nil
local encounterSpawned = false
local encounterEnemies: { [string]: boolean } = {} -- entity id -> still in the encounter
local encounterRemaining = 0
local detectAccumulator = 0

-- Sends one placeholder narrative beat to a player (the client just prints it).
local function sendNarrative(player: Player, kind: string, text: string)
	if narrativeRemote then
		narrativeRemote:FireClient(player, { kind = kind, text = text })
	end
end

-- Validated forward transition (rules from ChapterOneSliceFlow). Warns and refuses
-- an illegal step so a logic bug surfaces loudly instead of corrupting the run.
local function advance(player: Player, toState: string): boolean
	local from = playerState[player]
	if from == nil or not SliceFlow.canAdvance(from, toState) then
		log:warn(("illegal transition for %s: %s -> %s"):format(player.Name, tostring(from), toState))
		return false
	end
	playerState[player] = toState
	return true
end

-- STEP 1: begins the slice for a player — sends the intro after a short delay, then
-- advances to Exploring (the entry point the STEP 2 detection loop drives).
local function beginSliceForPlayer(player: Player)
	playerState[player] = States.Intro -- initial seed (no prior state to validate)
	task.delay(config.IntroDelaySeconds, function()
		if not player.Parent then
			return
		end
		sendNarrative(player, "intro", config.Narrative.Intro)
		advance(player, States.Exploring)
		log:info(("intro sent to %s"):format(player.Name))
	end)
end

-- Starts the slice exactly ONCE per player, on their first character. Later
-- respawns keep the existing state (the run survives death) and must NOT restart
-- the intro; the detection loop simply resumes with the new character.
local function tryBeginSlice(player: Player)
	if sliceStarted[player] then
		return
	end
	sliceStarted[player] = true
	beginSliceForPlayer(player)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function()
		tryBeginSlice(player)
	end)
	if player.Character then
		tryBeginSlice(player)
	end
end

local function onPlayerRemoving(player: Player)
	playerState[player] = nil
	sliceStarted[player] = nil
end

-- A plain visible anchored marker (DEV scaffolding — like the test dummy, not VFX).
local function createMarker(name: string, position: Vector3, color: Color3): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.Size = Vector3.new(3, 6, 3)
	part.Color = color
	part.Position = position
	part.Parent = Workspace
	return part
end

-- STEP 3: removes the exploration markers once the slice ends.
local function cleanupMarkers()
	if loreMarker then
		loreMarker:Destroy()
		loreMarker = nil
	end
	if objectiveMarker then
		objectiveMarker:Destroy()
		objectiveMarker = nil
	end
end

local function playerRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function withinZone(root: BasePart, zone: any): boolean
	return (root.Position - zone.Position).Magnitude <= zone.Radius
end

-- Spawns the first scripted undead encounter ONCE, via the generic EnemyService
-- (reuses the provisional `training_dummy` stat block — real undead content later).
local function spawnEncounter()
	if encounterSpawned then
		return
	end
	encounterSpawned = true
	local count: number = config.Encounter.EnemyCount
	local center: Vector3 = config.Encounter.SpawnCenter
	local spread: number = config.Encounter.SpawnSpread
	for i = 1, count do
		local offset = (i - 1) * spread - ((count - 1) * spread) / 2
		local id = EnemyService.spawnDummy(center + Vector3.new(offset, 0, 0))
		encounterEnemies[id] = true
		encounterRemaining += 1
	end
	log:info(("scripted encounter spawned: %d undead"):format(count))
end

-- STEP 3: every encounter undead is dead — the objective is complete. Reward every
-- player still in the run, then (after a beat) end the slice and clean up markers.
local function onEncounterCleared()
	log:info("encounter cleared -> reward")

	for player, state in playerState do
		if state == States.Encounter and advance(player, States.Reward) then
			-- Reward is symbolic for now (narrative only) — real banking goes through
			-- the Economy/persistence layer when it exists (see Todo tech debt).
			sendNarrative(player, "reward", config.Narrative.Reward)
		end
	end

	task.delay(config.RewardToEndDelaySeconds, function()
		for player, state in playerState do
			if state == States.Reward and advance(player, States.Ended) then
				sendNarrative(player, "end", config.Narrative.End)
			end
		end
		cleanupMarkers()
		log:info("slice ended")
	end)
end

-- STEP 3: fires for every entity death; acts only on our encounter undead.
local function onEntityDied(entity: any)
	local id = entity.id
	if not encounterEnemies[id] then
		return
	end
	encounterEnemies[id] = nil
	encounterRemaining -= 1
	if encounterRemaining <= 0 then
		onEncounterCleared()
	end
end

-- STEP 2: advances one player through Exploring -> Lore -> Objective -> Encounter
-- by distance to the markers.
local function updatePlayer(player: Player)
	local state = playerState[player]
	local root = playerRoot(player)
	if not root then
		return
	end

	if state == States.Exploring then
		if withinZone(root, config.LoreZone) then
			-- Reached the lore marker: deliver lore (Exploring -> Lore), then hand out
			-- the objective (Lore -> Objective) and route to the objective marker.
			sendNarrative(player, "lore", config.Narrative.Lore)
			advance(player, States.Lore)
			sendNarrative(player, "objective", config.Narrative.Objective)
			advance(player, States.Objective)
			log:info(("%s reached lore -> objective given"):format(player.Name))
		end
	elseif state == States.Objective then
		if withinZone(root, config.ObjectiveZone) then
			advance(player, States.Encounter)
			spawnEncounter()
			log:info(("%s reached objective -> encounter spawned"):format(player.Name))
		end
	end
end

local function onHeartbeat(dt: number)
	detectAccumulator += dt
	if detectAccumulator < config.DetectionInterval then
		return
	end
	detectAccumulator = 0
	for player in playerState do
		updatePlayer(player)
	end
end

function ChapterOneSliceService.Init()
	config = Config.get("ChapterOneSlice")

	-- Use the existing mission framework: register a provisional definition. The
	-- objective is orchestrated here for now (the Mission schema gains objective
	-- data in a later phase).
	if not MissionService.get(config.MissionId) then
		MissionService.register({
			id = config.MissionId,
			displayName = config.MissionDisplayName,
			region = config.Region,
		})
	end
end

function ChapterOneSliceService.Start()
	local settings = Config.get("Settings")
	if settings.FeatureFlags.EnableChapterOneSlice ~= true then
		log:info("disabled (FeatureFlags.EnableChapterOneSlice = false)")
		return
	end
	-- Safety: this service lives in Server/World, so it only syncs into the
	-- Forgotten Lands place — but guard anyway.
	if GameService.getPlaceRole() ~= Constants.PlaceRole.World then
		log:info("not the Forgotten Lands place; slice inactive")
		return
	end

	narrativeRemote = Net.getEvent("SliceNarrative")

	-- STEP 2: place the exploration markers (shared, once).
	loreMarker = createMarker("SliceLoreMarker", config.LoreZone.Position, Color3.fromRGB(60, 120, 220))
	objectiveMarker = createMarker("SliceObjectiveMarker", config.ObjectiveZone.Position, Color3.fromRGB(220, 200, 60))

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- STEP 3: watch for encounter undead deaths through the authoritative combat seam.
	CombatService.EntityDied:connect(onEntityDied)

	-- STEP 2: drive exploration detection.
	RunService.Heartbeat:Connect(onHeartbeat)

	log:info("ready")
end

return ChapterOneSliceService
