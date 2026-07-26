--!strict
--[[
	EnemyService
	Generic spawn layer for the Forgotten Lands: spawns a unit (enemy OR neutral NPC)
	from `configs/Enemies`, registers it as a CombatEntity (faction from its def),
	binds Health<->Humanoid, attaches the AI brain if the def has an `AI` block, and
	cleans it up on death. Generic on purpose — undead, animals, bosses, and NPC
	targets (Defend/Escort) all flow through here; archetype-specific content is data.

	The Wave System will later drive spawning through this same API (batches, pacing).

	Place: Forgotten Lands ONLY (Server/World). Phase: Combat / Missions.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Server = script.Parent.Parent
local CombatService = require(script.Parent.CombatService)
local EnemyAIService = require(script.Parent.EnemyAIService)
local HumanoidAdapter = require(Server.Domain.Combat.HumanoidAdapter)
local Enums = require(ReplicatedStorage.Shared.Combat.Enums)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local EnemyService = {}

EnemyService.Name = "EnemyService"

local log = Logger.new("EnemyService")

-- Height (studs) of the placeholder rig; used to rest its feet on the ground.
local RIG_HEIGHT = 5

local nextId = 0
local bindings: { [string]: HumanoidAdapter.Binding } = {}

local function generateId(): string
	nextId += 1
	return Constants.CombatId.EnemyPrefix .. nextId
end

-- Simple visible marker colour by faction (placeholder rig, not VFX).
local function colorForFaction(faction: string): Color3
	if faction == Enums.Faction.Neutral then
		return Color3.fromRGB(60, 160, 90)
	elseif faction == Enums.Faction.Players then
		return Color3.fromRGB(60, 120, 220)
	end
	return Color3.fromRGB(150, 40, 40) -- Enemies / default
end

-- Minimal anchored Humanoid rig used as a stand-in body. TEST scaffolding only —
-- real models (models/World) come later.
local function buildRig(color: Color3): (Model, Humanoid)
	local model = Instance.new("Model")
	model.Name = "SpawnedUnit"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, RIG_HEIGHT, 1)
	root.Anchored = true
	root.Color = color
	root.Parent = model
	model.PrimaryPart = root

	local humanoid = Instance.new("Humanoid")
	-- Headless rig would auto-die without this.
	humanoid.RequiresNeck = false
	humanoid.Parent = model

	return model, humanoid
end

-- Spawns unit `enemyId` at `position`, registers it as a CombatEntity, and returns
-- its entity id. Attaches the AI brain only if the def has an `AI` block (so neutral
-- NPCs are passive). Despawns automatically on death. `healthMult` scales max health
-- (difficulty scaling); defaults to 1.
function EnemyService.spawn(enemyId: string, position: Vector3, healthMult: number?): string
	local enemies = Config.get("Enemies")
	local def = enemies[enemyId]
	assert(def, "Unknown enemy id: " .. tostring(enemyId))

	local model, humanoid = buildRig(colorForFaction(def.Faction))

	-- Rest feet on the ground under the spawn XZ (baseplate/terrain), else fall back.
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { model }
	local groundY = position.Y
	local hit = Workspace:Raycast(
		Vector3.new(position.X, position.Y + 200, position.Z),
		Vector3.new(0, -400, 0),
		rayParams
	)
	if hit then
		groundY = hit.Position.Y
	end
	local spawnPos = Vector3.new(position.X, groundY + RIG_HEIGHT / 2, position.Z)
	model:PivotTo(CFrame.new(spawnPos))
	model.Parent = Workspace

	local id = generateId()
	local entity = CombatService.registerEntity({
		id = id,
		faction = def.Faction,
		maxHealth = def.MaxHealth * (healthMult or 1),
		model = model,
	})
	bindings[id] = HumanoidAdapter.bind(entity.health, humanoid)

	-- AI brain (no-op if the def has no AI block — neutral NPCs stay passive).
	EnemyAIService.attach(entity, enemyId, spawnPos)

	entity.health.Died:connect(function()
		EnemyService.despawn(id)
	end)

	return id
end

function EnemyService.despawn(id: string)
	local binding = bindings[id]
	if binding then
		binding.disconnect()
		bindings[id] = nil
	end
	local entity = CombatService.getEntity(id)
	if entity and entity.model then
		entity.model:Destroy()
	end
	CombatService.unregisterEntity(id)
end

function EnemyService.Init() end

function EnemyService.Start()
	log:info("ready")
end

return EnemyService
