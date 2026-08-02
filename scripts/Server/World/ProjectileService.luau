--!strict
--[[
	ProjectileService
	Server-authoritative projectiles: arrows and javelins that actually TRAVEL,
	are traced along their flight, and hit whatever is in the way.

	--------------------------------------------------------------------------
	WHY NOT HITSCAN WITH A DICE ROLL

	The cheap way to build a ranged enemy is to roll a number, and on a hit
	apply damage instantly. It is a third of this code and it is much worse,
	because a shot that misses for reasons the player cannot see is not a
	near-miss, it is a shrug.

	A travelling, traced projectile can fail three honest ways:

	  1. the aim error put it off line,
	  2. the player MOVED during the flight time,
	  3. it hit a wall, a barricade or a house on the way.

	The third is the one worth all the work. It makes cover real, and every
	ruin, cart and barricade in the nine chambers suddenly does something. The
	player learns to fight archers from behind the map rather than by luck.

	--------------------------------------------------------------------------
	Damage flows through CombatService.applyDamage — the SAME path as the
	player's melee and the enemies' swings. Nothing here does its own maths.

	Place: Forgotten Lands ONLY (Server/World). Phase: Enemy AI / ranged.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CombatService = require(script.Parent.CombatService)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local ProjectileService = {}

ProjectileService.Name = "ProjectileService"

local log = Logger.new("ProjectileService")

--==========================================================================
-- Tuning
--==========================================================================

-- Seconds a spent projectile stays stuck in whatever it hit before vanishing.
-- Long enough to read as "that landed there", short enough not to litter.
local STICK_SECONDS = 6

-- Hard ceiling on flight time, in case something is fired into open sky.
local MAX_LIFETIME = 8

--[[
	The look of each kind. Deliberately the castle's own palette — dark timber
	and corroded iron — so a shot in flight reads as part of this world and not
	as a game object.
]]
local KINDS = {
	arrow = {
		length = 5.5,
		radius = 0.14,
		shaft = Color3.fromRGB(92, 72, 50),
		head = Color3.fromRGB(56, 48, 44),
		fletch = Color3.fromRGB(78, 68, 44),
	},
	javelin = {
		length = 9,
		radius = 0.26,
		shaft = Color3.fromRGB(66, 49, 34),
		head = Color3.fromRGB(56, 48, 44),
		fletch = Color3.fromRGB(44, 32, 22),
	},
}

local rng = Random.new()

--==========================================================================
type Shot = {
	model: Model,
	position: Vector3,
	direction: Vector3,
	speed: number,
	damage: number,
	damageType: string,
	sourceId: string,
	sourceFaction: string,
	travelled: number,
	maxRange: number,
	age: number,
	params: RaycastParams,
}

local live: { Shot } = {}
local folder: Folder? = nil

local function container(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "Projectiles"
	f.Parent = Workspace
	folder = f
	return f
end

--==========================================================================
-- Aim
--==========================================================================

--[[
	Nudges `dir` off true by up to `angle` radians.

	The radius inside the cone is picked LINEARLY rather than by area, which
	biases shots toward the centre: most arrows go roughly where they were
	aimed and the occasional one goes wide. Sampling uniformly over the disc
	would push too many shots to the edge of the cone, and the archers would
	read as incompetent rather than as archers.
]]
local function spread(dir: Vector3, angle: number): Vector3
	if angle <= 0 then
		return dir
	end
	-- Any axis not parallel to dir will do to build the basis from.
	local seed = if math.abs(dir.Y) < 0.99 then Vector3.yAxis else Vector3.xAxis
	local right = dir:Cross(seed)
	if right.Magnitude < 1e-4 then
		return dir
	end
	right = right.Unit
	local up = right:Cross(dir).Unit

	local theta = rng:NextNumber(0, math.pi * 2)
	local r = math.tan(angle) * rng:NextNumber()
	return (dir + right * (math.cos(theta) * r) + up * (math.sin(theta) * r)).Unit
end

--==========================================================================
-- The body
--==========================================================================
local function buildProjectile(kind: string): Model
	local look = KINDS[kind] or KINDS.arrow
	local m = Instance.new("Model")
	m.Name = "Projectile"

	local shaft = Instance.new("Part")
	shaft.Name = "Shaft"
	shaft.Shape = Enum.PartType.Cylinder
	shaft.Size = Vector3.new(look.length, look.radius * 2, look.radius * 2)
	shaft.Color = look.shaft
	shaft.Material = Enum.Material.Wood
	shaft.Anchored = true
	shaft.CanCollide = false
	shaft.CanQuery = false -- must never be hit by another projectile's trace
	shaft.CanTouch = false
	shaft.CastShadow = false
	shaft.Parent = m
	m.PrimaryPart = shaft

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(look.radius * 4, look.radius * 3, look.radius * 3)
	head.Color = look.head
	head.Material = Enum.Material.CorrodedMetal
	head.Anchored = true
	head.CanCollide = false
	head.CanQuery = false
	head.CanTouch = false
	head.CastShadow = false
	head.Parent = m

	local fletch = Instance.new("Part")
	fletch.Name = "Fletching"
	fletch.Size = Vector3.new(look.length * 0.18, look.radius * 5, 0.08)
	fletch.Color = look.fletch
	fletch.Material = Enum.Material.Fabric
	fletch.Anchored = true
	fletch.CanCollide = false
	fletch.CanQuery = false
	fletch.CanTouch = false
	fletch.CastShadow = false
	fletch.Parent = m

	m.Parent = container()
	return m
end

-- Lays the model out along `dir`, nose first.
local function orient(shot: Shot)
	local m = shot.model
	local cf = CFrame.lookAt(shot.position, shot.position + shot.direction)

	local shaft = m:FindFirstChild("Shaft") :: BasePart?
	if not shaft then
		return
	end
	local length = shaft.Size.X

	-- The cylinder's long axis is its X, so it is rolled a quarter turn to lie
	-- along the direction of travel rather than across it.
	shaft.CFrame = cf * CFrame.Angles(0, math.rad(90), 0)

	local head = m:FindFirstChild("Head") :: BasePart?
	if head then
		head.CFrame = cf * CFrame.new(0, 0, -length / 2)
	end
	local fletch = m:FindFirstChild("Fletching") :: BasePart?
	if fletch then
		fletch.CFrame = cf * CFrame.new(0, 0, length / 2 - 0.4)
	end
end

--==========================================================================
-- Hit resolution
--==========================================================================

--[[
	Which CombatEntity, if any, owns `part`?

	Walks up the ancestry looking for a model that some registered entity calls
	its own. Walking up matters: an arrow hits a limb or a rig part, never the
	model itself.
]]
local function entityFor(part: BasePart)
	local node: Instance? = part
	while node do
		for _, entity in CombatService.getAllEntities() do
			if entity.model == node then
				return entity
			end
		end
		node = node.Parent
		if node == Workspace then
			break
		end
	end
	return nil
end

local function retire(shot: Shot, stuckAt: Vector3?)
	if stuckAt then
		shot.position = stuckAt
		orient(shot)
		-- Leave it in the wall for a moment, then take it away.
		local model = shot.model
		task.delay(STICK_SECONDS, function()
			if model and model.Parent then
				model:Destroy()
			end
		end)
	else
		shot.model:Destroy()
	end
end

--==========================================================================
-- API
--==========================================================================

export type FireOptions = {
	sourceId: string, -- the CombatEntity that loosed it
	origin: Vector3,
	targetPosition: Vector3,
	targetVelocity: Vector3?, -- for leading; zero if unknown
	kind: string?, -- "arrow" | "javelin"
	speed: number,
	damage: number,
	damageType: string,
	spread: number?, -- cone half-angle, radians
	leadFactor: number?, -- 0..1 of target velocity compensated for
	maxRange: number?,
}

--[[
	Looses one projectile. Returns false if the shooter is not a registered
	entity — there is nobody to attribute the damage to, and an unattributed
	hit is how friendly fire gets invented by accident.
]]
function ProjectileService.fire(opts: FireOptions): boolean
	local source = CombatService.getEntity(opts.sourceId)
	if not source then
		return false
	end

	--[[
		Aim. The shooter leads a moving target by `leadFactor` of the time the
		arrow will be in the air — never the full amount, so running is always
		worth something. Then the cone error is applied on top.
	]]
	local toTarget = opts.targetPosition - opts.origin
	local distance = toTarget.Magnitude
	if distance < 0.5 then
		return false
	end

	local flightTime = distance / math.max(opts.speed, 1)
	local lead = (opts.targetVelocity or Vector3.zero) * (opts.leadFactor or 0) * flightTime
	local aimAt = opts.targetPosition + lead
	local direction = (aimAt - opts.origin)
	if direction.Magnitude < 1e-4 then
		return false
	end
	direction = spread(direction.Unit, opts.spread or 0)

	local kind = opts.kind or "arrow"
	local model = buildProjectile(kind)

	-- The trace must ignore the shooter's own body and every other projectile.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model, container(), source.model :: any }

	local shot: Shot = {
		model = model,
		position = opts.origin,
		direction = direction,
		speed = opts.speed,
		damage = opts.damage,
		damageType = opts.damageType,
		sourceId = opts.sourceId,
		sourceFaction = source.faction,
		travelled = 0,
		maxRange = opts.maxRange or 200,
		age = 0,
		params = params,
	}
	orient(shot)
	table.insert(live, shot)
	return true
end

--==========================================================================
local function step(shot: Shot, dt: number): boolean
	shot.age += dt
	if shot.age > MAX_LIFETIME then
		retire(shot, nil)
		return false
	end

	local move = shot.speed * dt
	local nextPos = shot.position + shot.direction * move

	--[[
		Trace the SEGMENT just travelled, not the destination point. At 145
		studs a second a projectile covers two or three studs per frame, and a
		point test would sail straight through a wall between two frames.
	]]
	local hit = Workspace:Raycast(shot.position, shot.direction * move, shot.params)
	if hit then
		local entity = entityFor(hit.Instance)
		if entity and entity.faction ~= shot.sourceFaction and entity:isAlive() then
			CombatService.applyDamage({
				sourceId = shot.sourceId,
				targetId = entity.id,
				amount = shot.damage,
				damageType = shot.damageType,
			})
			retire(shot, nil) -- it went into a body; nothing to stick into
		else
			-- A wall, a barricade, a house. This is the miss that cover earns.
			retire(shot, hit.Position - shot.direction * 0.4)
		end
		return false
	end

	shot.position = nextPos
	shot.travelled += move
	if shot.travelled >= shot.maxRange then
		retire(shot, nil)
		return false
	end

	orient(shot)
	return true
end

function ProjectileService.Init() end

function ProjectileService.Start()
	RunService.Heartbeat:Connect(function(dt: number)
		-- Backwards, so removing a spent shot does not skip the next one.
		for i = #live, 1, -1 do
			if not step(live[i], dt) then
				table.remove(live, i)
			end
		end
	end)
	log:info("ready")
end

return ProjectileService
