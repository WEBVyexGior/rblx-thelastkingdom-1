--!strict
--[[
	EnemyService
	Generic enemy layer for the Forgotten Lands: spawns an enemy model, registers
	it as a CombatEntity (faction Enemies), binds its Health to its Humanoid, and
	cleans it up on death. Generic on purpose — undead, animals, bosses, and NPC
	enemies all flow through here; archetype-specific content (e.g. undead waves)
	is a later layer on top, NOT baked in.

	For the vertical slice it spawns a minimal TEST "training dummy" so melee has a
	target. Real, config-driven enemy content comes later.

	Place: Forgotten Lands ONLY (Server/World). Phase: Combat (vertical slice).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Server = script.Parent.Parent
local CombatService = require(script.Parent.CombatService)
local HumanoidAdapter = require(Server.Domain.Combat.HumanoidAdapter)
local Enums = require(ReplicatedStorage.Shared.Combat.Enums)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local EnemyService = {}

EnemyService.Name = "EnemyService"

local log = Logger.new("EnemyService")
local nextId = 0
local bindings: { [string]: HumanoidAdapter.Binding } = {}

-- Height (studs) of the placeholder dummy part; used to rest its feet on the ground.
local DUMMY_HEIGHT = 5

local function generateId(): string
	nextId += 1
	return Constants.CombatId.EnemyPrefix .. nextId
end

-- Minimal anchored Humanoid rig used as a stand-in target. TEST scaffolding only
-- — real enemy models (models/World) and config-driven spawning come later.
local function buildDummyRig(): (Model, Humanoid)
	local model = Instance.new("Model")
	model.Name = "TrainingDummy"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, DUMMY_HEIGHT, 1)
	root.Anchored = true
	root.Color = Color3.fromRGB(150, 40, 40) -- visible test-target marker (not VFX)
	root.Parent = model
	model.PrimaryPart = root

	local humanoid = Instance.new("Humanoid")
	-- The minimal rig has no Head/neck; without this a headless Humanoid can
	-- auto-die on spawn. Keep it alive until it actually takes damage.
	humanoid.RequiresNeck = false
	humanoid.Parent = model

	return model, humanoid
end

-- Spawns a training dummy at `position` and registers it as a CombatEntity.
-- Returns its entity id.
function EnemyService.spawnDummy(position: Vector3): string
	local enemies = Config.get("Enemies")
	local def = enemies.training_dummy -- TEST placeholder definition

	local model, humanoid = buildDummyRig()

	-- Rest the dummy's feet on the ground: raycast down at the spawn XZ and place
	-- it on whatever it hits (baseplate/terrain), else fall back to the given Y.
	-- Keeps it from sinking into (or floating above) any baseplate height.
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
	model:PivotTo(CFrame.new(position.X, groundY + DUMMY_HEIGHT / 2, position.Z))
	model.Parent = Workspace

	local id = generateId()
	local entity = CombatService.registerEntity({
		id = id,
		faction = Enums.Faction.Enemies,
		maxHealth = def.MaxHealth,
		model = model,
	})
	bindings[id] = HumanoidAdapter.bind(entity.health, humanoid)

	-- Despawn on death (no ragdoll / VFX in this slice).
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
	log:info(id .. " died and despawned")
end

function EnemyService.Init() end

function EnemyService.Start()
	local settings = Config.get("Settings")
	if settings.FeatureFlags.EnableCombatTestDummies then
		local dummy = settings.Combat.TestDummy
		local count: number = dummy.Count
		local offset: number = dummy.SpawnOffset
		for i = 1, count do
			EnemyService.spawnDummy(Vector3.new((i - 1) * 6, 3, -offset))
		end
		log:info(("spawned %d test dummy(ies)"):format(count))
	end
	log:info("ready")
end

return EnemyService
