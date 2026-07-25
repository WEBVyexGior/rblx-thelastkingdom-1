--!strict
--[[
	EnemyAIService
	Drives enemy AI in the Forgotten Lands. Per tick, for each attached enemy it:
	  1. perceives — finds the nearest alive player via CombatService,
	  2. decides  — asks the enemy's EnemyBrain for the next state,
	  3. actuates — moves toward the target / back to spawn (simple kinematic
	     movement, NO pathfinding), or attacks THROUGH the existing CombatService.

	It never contains its own combat maths: enemy attacks go through
	CombatService.applyDamage exactly like the player's melee does. Movement is
	kinematic (PivotTo) so the anchored dummy rig stays physics-free and
	deterministic. Ranges/speed/cooldown come from configs/Enemies (the enemy's
	`AI` block); nothing here is hard-coded.

	Place: Forgotten Lands ONLY (Server/World). Phase: Enemy AI (foundation).
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local CombatService = require(script.Parent.CombatService)
local CombatEntity = require(Server.Domain.Combat.CombatEntity)
local EnemyBrain = require(Server.Domain.AI.EnemyBrain)
local Enums = require(ReplicatedStorage.Shared.Combat.Enums)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local EnemyAIService = {}

EnemyAIService.Name = "EnemyAIService"

local log = Logger.new("EnemyAIService")

type Agent = {
	brain: EnemyBrain.EnemyBrain,
	spawnPosition: Vector3,
	params: EnemyBrain.Params,
	moveSpeed: number,
	attackCooldown: number,
	attackDamage: number,
	attackDamageType: string,
	lastAttack: number,
}

local agents: { [string]: Agent } = {} -- keyed by enemy entity id

local function positionOf(model: Instance): Vector3
	if model:IsA("Model") then
		return model:GetPivot().Position
	elseif model:IsA("BasePart") then
		return model.Position
	end
	return Vector3.new(0, 0, 0)
end

-- Nearest alive Players-faction entity to `pos`, with its distance.
local function nearestPlayer(pos: Vector3): (CombatEntity.CombatEntity?, number?)
	local best: CombatEntity.CombatEntity? = nil
	local bestDist: number? = nil
	for _, entity in CombatService.getAllEntities() do
		if entity.faction == Enums.Faction.Players and entity:isAlive() and entity.model then
			local d = (positionOf(entity.model) - pos).Magnitude
			if bestDist == nil or d < bestDist then
				best = entity
				bestDist = d
			end
		end
	end
	return best, bestDist
end

-- Kinematic step toward a target position, XZ only (keeps its ground Y), facing it.
local function moveToward(model: Instance, targetPos: Vector3, speed: number, dt: number)
	if not model:IsA("PVInstance") then
		return
	end
	local cur = positionOf(model)
	local flat = Vector3.new(targetPos.X, cur.Y, targetPos.Z)
	local delta = flat - cur
	local dist = delta.Magnitude
	if dist <= 0.05 then
		return
	end
	local step = math.min(speed * dt, dist)
	model:PivotTo(CFrame.lookAt(cur + delta.Unit * step, flat))
end

local function faceToward(model: Instance, targetPos: Vector3)
	if not model:IsA("PVInstance") then
		return
	end
	local cur = positionOf(model)
	local flat = Vector3.new(targetPos.X, cur.Y, targetPos.Z)
	if (flat - cur).Magnitude > 0.05 then
		model:PivotTo(CFrame.lookAt(cur, flat))
	end
end

-- Attaches an AI brain to a spawned enemy. No-op if its config has no `AI` block,
-- so non-AI enemies stay static. Called by EnemyService on spawn.
function EnemyAIService.attach(entity: CombatEntity.CombatEntity, enemyId: string, spawnPosition: Vector3)
	local enemies = Config.get("Enemies")
	local def = enemies[enemyId]
	if not def or not def.AI then
		return
	end
	local ai = def.AI
	agents[entity.id] = {
		brain = EnemyBrain.new(),
		spawnPosition = spawnPosition,
		params = {
			DetectionRadius = ai.DetectionRadius,
			AttackRange = ai.AttackRange,
			LeashRadius = ai.LeashRadius,
			ArrivalRadius = ai.ArrivalRadius,
		},
		moveSpeed = ai.MoveSpeed,
		attackCooldown = ai.AttackCooldown,
		attackDamage = ai.AttackDamage,
		attackDamageType = ai.AttackDamageType,
		lastAttack = 0,
	}
end

local function stepAgent(entityId: string, agent: Agent, dt: number)
	local entity = CombatService.getEntity(entityId)
	if not entity or not entity.model then
		agents[entityId] = nil -- enemy despawned
		return
	end
	local model = entity.model
	local selfPos = positionOf(model)

	local target, targetDist = nearestPlayer(selfPos)

	local state = agent.brain:update({
		isAlive = entity:isAlive(),
		targetDistance = targetDist,
		distanceFromSpawn = (selfPos - agent.spawnPosition).Magnitude,
		params = agent.params,
	})

	if state == EnemyBrain.States.Chase then
		if target and target.model then
			moveToward(model, positionOf(target.model), agent.moveSpeed, dt)
		end
	elseif state == EnemyBrain.States.Attack then
		if target and target.model then
			faceToward(model, positionOf(target.model))
			local now = os.clock()
			if now - agent.lastAttack >= agent.attackCooldown then
				agent.lastAttack = now
				-- Enemy damage flows through the SAME CombatService as the player's.
				local result = CombatService.applyDamage({
					sourceId = entityId,
					targetId = target.id,
					amount = agent.attackDamage,
					damageType = agent.attackDamageType,
				})
				if not result.blocked then
					log:info(("%s hit %s for %s"):format(entityId, target.id, tostring(result.amount)))
				end
			end
		end
	elseif state == EnemyBrain.States.Return then
		moveToward(model, agent.spawnPosition, agent.moveSpeed, dt)
	end
	-- Idle / Dead: no actuation.
end

function EnemyAIService.Init() end

function EnemyAIService.Start()
	RunService.Heartbeat:Connect(function(dt: number)
		for entityId, agent in agents do
			stepAgent(entityId, agent, dt)
		end
	end)
	log:info("ready")
end

return EnemyAIService
