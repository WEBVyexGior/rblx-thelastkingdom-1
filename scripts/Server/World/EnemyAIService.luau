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
local ProjectileService = require(script.Parent.ProjectileService)
local CombatEntity = require(Server.Domain.Combat.CombatEntity)
local EnemyBrain = require(Server.Domain.AI.EnemyBrain)
local Enums = require(ReplicatedStorage.Shared.Combat.Enums)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local EnemyAIService = {}

EnemyAIService.Name = "EnemyAIService"

local log = Logger.new("EnemyAIService")

-- Studs above the rig's pivot that a shot leaves from. Firing from the pivot
-- puts the arrow at knee height, where the ground eats it at any distance.
local MUZZLE_HEIGHT = 2.5

--[[
	What a ranged unit fires. Straight off the enemy def's `Ranged` block; nil
	for everything that has to swing.
]]
type RangedProfile = {
	projectile: string,
	speed: number,
	damage: number,
	damageType: string,
	spread: number,
	leadFactor: number,
	maxRange: number,
}

type Agent = {
	brain: EnemyBrain.EnemyBrain,
	spawnPosition: Vector3,
	params: EnemyBrain.Params,
	moveSpeed: number,
	attackCooldown: number,
	attackDamage: number,
	attackDamageType: string,
	lastAttack: number,

	-- Ranged units only.
	ranged: RangedProfile?,
	-- Inside this the unit uses its MELEE attack even though it has a bow.
	-- Only The King has both; nil means "whatever it has, it always uses".
	meleeRange: number?,

	-- Last known position of its target, so the shot can lead a moving one.
	-- Velocity is derived here rather than read off a Humanoid, because the
	-- player rig and the enemy rigs report it differently and one of them
	-- reports nothing at all.
	lastTargetPos: Vector3?,
	targetVelocity: Vector3,
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

--[[
	Nearest living HOSTILE entity to `pos`, with its distance.

	Hostility is "not my faction" rather than "is a player", because the cured
	villagers from the kitchens fight on the Players side and the undead have
	to be willing to attack them. Hard-coding the Players faction here would
	have the dead walk straight past the allies to reach you.
]]
local function nearestHostile(pos: Vector3, myFaction: string): (CombatEntity.CombatEntity?, number?)
	local best: CombatEntity.CombatEntity? = nil
	local bestDist: number? = nil
	for _, entity in CombatService.getAllEntities() do
		local hostile = entity.faction ~= myFaction and entity.faction ~= Enums.Faction.Neutral
		if hostile and entity:isAlive() and entity.model then
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

	local ranged: RangedProfile? = nil
	if def.Ranged then
		local r = def.Ranged
		ranged = {
			projectile = r.Projectile,
			speed = r.Speed,
			damage = r.Damage,
			damageType = r.DamageType,
			spread = r.Spread,
			leadFactor = r.LeadFactor,
			maxRange = r.MaxRange,
		}
	end

	agents[entity.id] = {
		brain = EnemyBrain.new(),
		spawnPosition = spawnPosition,
		params = {
			DetectionRadius = ai.DetectionRadius,
			AttackRange = ai.AttackRange,
			LeashRadius = ai.LeashRadius,
			ArrivalRadius = ai.ArrivalRadius,
			MinRange = ai.MinRange,
		},
		moveSpeed = ai.MoveSpeed,
		attackCooldown = ai.AttackCooldown,
		attackDamage = ai.AttackDamage,
		attackDamageType = ai.AttackDamageType,
		lastAttack = 0,
		ranged = ranged,
		meleeRange = ai.MeleeRange,
		lastTargetPos = nil,
		targetVelocity = Vector3.zero,
	}
end

--[[
	Swings or shoots, whichever this unit is holding at this distance.

	The King is the only one that owns both, and `meleeRange` is the whole
	switch: inside it the sword comes out, beyond it he uses the bow. For
	everything else one of the two branches simply never applies.
]]
local function attack(entityId: string, agent: Agent, target: CombatEntity.CombatEntity, selfPos: Vector3, distance: number)
	local useMelee = agent.ranged == nil or (agent.meleeRange ~= nil and distance <= agent.meleeRange)

	if useMelee then
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
		return
	end

	local r = agent.ranged :: RangedProfile
	if distance > r.maxRange then
		return -- out of the bow's reach; it holds the shot
	end
	ProjectileService.fire({
		sourceId = entityId,
		origin = selfPos + Vector3.new(0, MUZZLE_HEIGHT, 0),
		targetPosition = positionOf((target :: any).model) + Vector3.new(0, MUZZLE_HEIGHT * 0.6, 0),
		targetVelocity = agent.targetVelocity,
		kind = r.projectile,
		speed = r.speed,
		damage = r.damage,
		damageType = r.damageType,
		spread = r.spread,
		leadFactor = r.leadFactor,
		maxRange = r.maxRange,
	})
end

local function stepAgent(entityId: string, agent: Agent, dt: number)
	local entity = CombatService.getEntity(entityId)
	if not entity or not entity.model then
		agents[entityId] = nil -- enemy despawned
		return
	end
	local model = entity.model
	local selfPos = positionOf(model)

	local target, targetDist = nearestHostile(selfPos, entity.faction)

	--[[
		Track how fast the target is moving, so a ranged shot can lead it.
		Derived from successive positions rather than read off a Humanoid: the
		player rig and the spawned rigs report velocity differently, and the
		anchored ones report nothing at all.
	]]
	if target and target.model and dt > 0 then
		local now = positionOf(target.model)
		if agent.lastTargetPos then
			agent.targetVelocity = (now - agent.lastTargetPos) / dt
		end
		agent.lastTargetPos = now
	else
		agent.lastTargetPos = nil
		agent.targetVelocity = Vector3.zero
	end

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
	elseif state == EnemyBrain.States.Reposition then
		--[[
			Backing away — and still shooting. It walks directly away from the
			target rather than around it: an archer that circles reads as
			evasive and is miserable to pin down, whereas one that gives ground
			in a straight line can be cornered against the map, which is what
			makes the chambers' walls and barricades worth using.
		]]
		if target and target.model then
			local targetPos = positionOf(target.model)
			local away = selfPos - targetPos
			if away.Magnitude > 0.1 then
				moveToward(model, selfPos + away.Unit * 12, agent.moveSpeed, dt)
			end
			faceToward(model, targetPos)
		end
	elseif state == EnemyBrain.States.Return then
		moveToward(model, agent.spawnPosition, agent.moveSpeed, dt)
	end

	-- Attack and Reposition are BOTH firing states — see EnemyBrain.isAttacking.
	if EnemyBrain.isAttacking(state) and target and target.model and targetDist then
		if state == EnemyBrain.States.Attack then
			faceToward(model, positionOf(target.model))
		end
		local now = os.clock()
		if now - agent.lastAttack >= agent.attackCooldown then
			agent.lastAttack = now
			attack(entityId, agent, target, selfPos, targetDist)
		end
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
