--!strict
--[[
	EnemyAIService
	Drives enemy AI in the Forgotten Lands. Per tick, for each attached enemy it:
	  1. perceives — finds the nearest alive hostile via CombatService,
	  2. decides  — asks the enemy's EnemyBrain for the next state,
	  3. actuates — walks toward it AROUND the buildings, or attacks THROUGH the
	     existing CombatService.

	It never contains its own combat maths: enemy attacks go through
	CombatService.applyDamage exactly like the player's melee does. Ranges,
	speed and cooldown come from configs/Enemies (the enemy's `AI` block);
	nothing here is hard-coded.

	--------------------------------------------------------------------------
	THEY USED TO WALK THROUGH HOUSES

	Movement was a straight line: take the direction to the target and PivotTo
	along it. Kinematic, deterministic, and completely blind — the dead came
	through walls, through the stables, and out of the side of a building into
	your face. That is not a difficulty problem, it is a legibility one: if
	nothing in the world stops a zombie then no fence, no house and no layout
	means anything, and the whole map is decoration.

	So movement is now in three layers, cheapest first:

	  1. LINE OF SIGHT. One raycast. If the way to the target is clear — which
	     it is most of the time, in a courtyard — walk straight at it and
	     compute nothing.

	  2. A PATH. When the line is blocked, ask PathfindingService for a route
	     and follow its waypoints. Recomputed about once a second per agent and
	     rate-limited across all of them, because thirty agents each pathing
	     every frame is a stall, not an AI.

	  3. A HARD STOP. Every step, whatever produced it, is raycast before it is
	     taken. If something solid is in the way the step is not taken. This is
	     the layer that makes the guarantee absolute: a path can be stale and a
	     line of sight can be wrong, but nothing gets to move into a wall.

	Other characters are ignored by both raycasts — the dead crowd, and a unit
	that refuses to step because another unit is in front of it is a unit that
	stands in a doorway forever.

	Place: Forgotten Lands ONLY (Server/World). Phase: Enemy AI.
]]

local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")
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

--==========================================================================
-- Walking around things
--==========================================================================

-- How wide and tall the pathfinder should assume a body is. Slightly generous:
-- a route that scrapes a doorway looks like clipping even when it is legal.
local AGENT_RADIUS = 2.4
local AGENT_HEIGHT = 6

-- How often one agent re-asks for a route, and how far its target may drift
-- before it asks early. A second is imperceptible on something walking at 7
-- studs a second and is the difference between an AI and a stall.
local REPATH_SECONDS = 0.9
local GOAL_DRIFT = 10

-- Globally, per frame. Thirty agents will not all recompute together.
local MAX_COMPUTES_PER_FRAME = 3

-- Close enough to a waypoint to start walking to the next one.
local WAYPOINT_RADIUS = 4

-- The step-blocking ray leaves from chest height, not the pivot: a ray along
-- the floor catches every kerb, doorstep and flagstone in the castle and would
-- have the dead refuse to walk down the road.
local PROBE_HEIGHT = 1.6

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

	-- Routing. `waypoints` is empty whenever the agent is walking on line of
	-- sight, which is most of the time.
	waypoints: { Vector3 },
	waypointIndex: number,
	pathGoal: Vector3?, -- what the current route was computed toward
	repathAt: number, -- os.clock() when it may ask again
	computing: boolean, -- a ComputeAsync is in flight for this agent
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

--==========================================================================
-- Seeing
--==========================================================================

--[[
	Is `hit` a body rather than the world?

	Characters are ignored by every ray in this file. The dead arrive in
	crowds, and a unit that will not take a step because another unit is in
	front of it is a unit that stands in a doorway for the rest of the run.
]]
local function isCharacter(instance: BasePart): boolean
	local model = instance:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return true
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return false
end

--[[
	Casts from `from` to `to` at chest height and reports what is in the way,
	ignoring `me` and anything with a Humanoid in it.

	Returns nil when the way is clear.
]]
local function obstacleBetween(me: Instance, from: Vector3, to: Vector3): BasePart?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { me }
	params.IgnoreWater = true

	local origin = from + Vector3.new(0, PROBE_HEIGHT, 0)
	local finish = Vector3.new(to.X, from.Y + PROBE_HEIGHT, to.Z)
	local delta = finish - origin
	if delta.Magnitude < 0.05 then
		return nil
	end

	--[[
		Up to three casts. The first hit is very often another body, and
		Exclude cannot express "everything with a Humanoid in it" without
		rebuilding a list of every character every frame — so instead the ray
		is re-cast past whatever it found. Three is enough for a crowd and
		bounded enough not to matter.
	]]
	for _ = 1, 3 do
		local hit = Workspace:Raycast(origin, delta, params)
		if not hit then
			return nil
		end
		if not isCharacter(hit.Instance) then
			return hit.Instance
		end
		local skipped = table.clone(params.FilterDescendantsInstances)
		table.insert(skipped, hit.Instance)
		params.FilterDescendantsInstances = skipped
	end
	return nil
end

--==========================================================================
-- Moving
--==========================================================================

--[[
	One kinematic step toward `targetPos`, XZ only, facing where it goes.

	The step is PROBED before it is taken. This is the layer that makes the
	no-walking-through-walls guarantee absolute: a path can be stale and a line
	of sight can be a frame old, but a step that would end inside something
	simply does not happen. Returns false when it was refused, so the caller
	can ask for a new route.
]]
local function moveToward(model: Instance, targetPos: Vector3, speed: number, dt: number): boolean
	if not model:IsA("PVInstance") then
		return false
	end
	local cur = positionOf(model)
	local flat = Vector3.new(targetPos.X, cur.Y, targetPos.Z)
	local delta = flat - cur
	local dist = delta.Magnitude
	if dist <= 0.05 then
		return true
	end

	local step = math.min(speed * dt, dist)
	local nextPos = cur + delta.Unit * step

	-- Probe a little beyond the step, so a body stops short of a wall rather
	-- than with its nose in it.
	if obstacleBetween(model, cur, cur + delta.Unit * (step + AGENT_RADIUS)) then
		-- Still turn to face the way it wants to go: a unit pressed against a
		-- corner but looking at you reads as blocked, not as broken.
		model:PivotTo(CFrame.lookAt(cur, flat))
		return false
	end

	model:PivotTo(CFrame.lookAt(nextPos, flat))
	return true
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
		waypoints = {},
		waypointIndex = 1,
		pathGoal = nil,
		--[[
			Staggered from birth. Ten shamblers spawned in the same frame would
			otherwise ask for ten routes in the same frame, for the rest of the
			run, forever in lockstep.
		]]
		repathAt = os.clock() + math.random() * REPATH_SECONDS,
		computing = false,
	}
end

--==========================================================================
-- Routing
--==========================================================================
local computesThisFrame = 0

--[[
	Asks PathfindingService for a route to `goal` and stores its waypoints.

	Async, so the agent keeps walking on whatever it had while this runs, and
	everything is re-checked afterwards — a second may have passed and the
	agent may be dead, despawned or somewhere else entirely.
]]
local function requestPath(entityId: string, agent: Agent, from: Vector3, goal: Vector3)
	if agent.computing or computesThisFrame >= MAX_COMPUTES_PER_FRAME then
		return
	end
	agent.computing = true
	computesThisFrame += 1
	agent.repathAt = os.clock() + REPATH_SECONDS

	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = AGENT_RADIUS,
			AgentHeight = AGENT_HEIGHT,
			AgentCanJump = false,
			AgentCanClimb = false,
		})

		local ok = pcall(function()
			path:ComputeAsync(from, goal)
		end)

		-- It may have died or despawned while that was computing.
		if agents[entityId] ~= agent then
			return
		end
		agent.computing = false

		if not ok or path.Status ~= Enum.PathStatus.Success then
			--[[
				No route. Do NOT fall back to walking straight at the target —
				that is the bug this whole system exists to remove. Keep
				whatever route it had; the step probe stops it at the wall, and
				it asks again in a second.
			]]
			return
		end

		local points: { Vector3 } = {}
		for i, waypoint in path:GetWaypoints() do
			-- Skip the first: it is where the agent already is, and walking to
			-- it produces a visible stutter at the start of every route.
			if i > 1 then
				table.insert(points, waypoint.Position)
			end
		end

		agent.waypoints = points
		agent.waypointIndex = 1
		agent.pathGoal = goal
	end)
end

--[[
	Walks the agent toward `goal`, around whatever is in the way.

	Line of sight first, because in an open ward it almost always is, and one
	raycast is a thousandth of the cost of a route.
]]
local function travelTo(entityId: string, agent: Agent, model: Instance, selfPos: Vector3, goal: Vector3, dt: number)
	if not obstacleBetween(model, selfPos, goal) then
		agent.waypoints = {}
		agent.pathGoal = nil
		moveToward(model, goal, agent.moveSpeed, dt)
		return
	end

	-- Blocked. Ask for a route if the one it has is old, missing, or was
	-- computed toward somewhere the target has since left.
	local stale = agent.pathGoal == nil
		or (goal - (agent.pathGoal :: Vector3)).Magnitude > GOAL_DRIFT
		or os.clock() >= agent.repathAt
	if stale then
		requestPath(entityId, agent, selfPos, goal)
	end

	local point = agent.waypoints[agent.waypointIndex]
	if not point then
		return -- nothing to follow yet; the probe keeps it honest either way
	end

	local flat = Vector3.new(point.X - selfPos.X, 0, point.Z - selfPos.Z)
	if flat.Magnitude <= WAYPOINT_RADIUS then
		agent.waypointIndex += 1
		point = agent.waypoints[agent.waypointIndex]
		if not point then
			agent.waypoints = {}
			agent.pathGoal = nil
			return
		end
	end

	--[[
		A refused step means the route no longer matches the world — something
		has moved, or the waypoint cuts a corner too fine. Ask again now rather
		than grinding against the obstacle for the rest of the second.
	]]
	if not moveToward(model, point, agent.moveSpeed, dt) then
		agent.repathAt = 0
	end
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
			travelTo(entityId, agent, model, selfPos, positionOf(target.model), dt)
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
		travelTo(entityId, agent, model, selfPos, agent.spawnPosition, dt)
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
		-- The per-frame routing budget resets here, so no matter how many
		-- agents are alive only a handful may ask the pathfinder each frame.
		computesThisFrame = 0
		for entityId, agent in agents do
			stepAgent(entityId, agent, dt)
		end
	end)
	log:info("ready")
end

return EnemyAIService
