--!strict
--[[
	WinchService
	Area 2's mechanic: the portcullis out of the Stables is down, the winch that
	raises it has lost its handle, and the handle is in one of the crates.

	--------------------------------------------------------------------------
	HOW IT PLAYS

	1. Walk in. The gate is shut and the winch has no handle.
	2. Search the boxes, barrels, bales and sacks around the stables. One of
	   them has it. Which one changes every run.
	3. Fit it, then turn. The gate creeps up while you hold, and SLIPS BACK
	   while you do not.

	The whole area is the walk between the two: the search points are down by
	the stables and the winch is up at the passage, so every trip is a chance to
	be caught in the open, and every fight costs you height on the gate.

	--------------------------------------------------------------------------
	THE GATE IS THE PROGRESS BAR

	Nothing is drawn on screen for this. Turning the winch raises the actual
	portcullis, a fraction at a time, and letting go lowers it. The player looks
	at the thing they are trying to get through and can see exactly how close
	they are — which no bar in the corner can do, and which makes the slip-back
	hurt in a way a number never would.

	--------------------------------------------------------------------------
	HOLD IT. DO NOT TAP IT.

	One continuous press. Hold E and the gate climbs at RAISE_RATE; let go and
	it falls at half as fast again, from that same frame, with no grace period
	and nothing banked.

	That multiplier is the area. Fourteen unbroken seconds gets you through, so
	the room has to be cleared enough to give you fourteen seconds — and every
	second spent swinging at something costs a second and a half of height. You
	do not chip away at this while being chewed on; you make space, then you
	wind.

	SOLO-FIRST. One player alone beats the fall rate comfortably. Each extra
	pair of hands adds half a pair's worth, so a second player is always worth
	having and never required, and nobody has to be anywhere at the same moment
	as anybody else.

	--------------------------------------------------------------------------
	EVERY POSITION IN HERE WAS MEASURED, NOT COMPUTED

	The last thing built for this chamber was placed from the constants in
	BuildChambers and landed on the road, because the place has been edited by
	hand since those constants were true. So: the winch site is clear of the
	flanking tower and the road by survey, and every search point is chosen at
	runtime by raycasting for a floor and rejecting anything that overlaps
	something already standing there.

	Place: Forgotten Lands ONLY (Server/World). Phase: Areas.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Server = script.Parent.Parent
local GameService = require(Server.Services.GameService)
local AreaService = require(script.Parent.AreaService)
local Net = require(ReplicatedStorage.Shared.Net)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local WinchService = {}

WinchService.Name = "WinchService"

local log = Logger.new("WinchService")

--==========================================================================
local AREA = 2

--[[
	The winch site, from tools/SurveyArea2.

	x = -88, z = -364. The passage is at x = -115 in the cross wall at z = -380;
	PassageTowerB stands at x = -70 with a radius of 18, so its footprint at
	this z reaches x = -78, and the measured road through this slice spans
	x -123.8 .. -106.2. This spot is clear of both with room to fight in.
]]
local WINCH = Vector3.new(-88, 2, -364)
local GATE_TOP = Vector3.new(-115, 48, -378) -- where the rope disappears into the arch

--[[
	Where the handle can be hidden: the ground around the stables, east of the
	road all the way down this end of the chamber. The measured road maximum in
	these z slices is x = -67 at worst, so the whole zone is clear of it — and
	every candidate is still checked against the world before it is used.
]]
local ZONE_X = { -8, 104 }
local ZONE_Z = { -364, -298 }

local SEARCH_POINTS = 9
local MIN_APART = 17
local ROAD_CLEARANCE = 20

-- Above this, a downward ray has hit a roof rather than the ward's floor. The
-- road sits at y = 2 and the terrain at 0, so eight is generous and still well
-- under anything with a lid on it.
local MAX_FLOOR_Y = 8

--==========================================================================
-- Turning
--
-- HOLD, do not tap. The first version banked a notch per completed hold and
-- the note back was that it should be one continuous press: hold E and the
-- gate climbs, let go and it starts down THAT INSTANT.
--
-- So there is no grace period and no per-hold gain — just two rates. Up is
-- slow and deliberate; down is HALF AS FAST AGAIN, which is the number that
-- makes the whole area work. You cannot wind it while you are being hit, so
-- the room has to be cleared enough to give you fourteen unbroken seconds, and
-- every second you spend swinging is a second and a half of height given back.
--==========================================================================
local RAISE_RATE = 1 / 14 -- fourteen seconds of holding, floor to lintel
local FALL_MULT = 1.5 -- and nine and a bit to lose it all
local FALL_RATE = RAISE_RATE * FALL_MULT

--[[
	A second pair of hands is worth half a first. Two people winding is 1.5x,
	three is 2x — faster, and never the difference between possible and not,
	because one player alone still beats the fall rate by a comfortable margin.
]]
local EXTRA_HANDS = 0.5

--[[
	The prompt has to stay unfinished for as long as anyone cares to hold it,
	and ProximityPrompt only raises its hold events when HoldDuration > 0. A
	long duration is how you get "held" without ever getting "triggered" — the
	ring creeps round at 1/90th a second, which nobody looks at, because the
	thing they are looking at is the gate.
]]
local HOLD_SECONDS = 90
local REACH = 13

--==========================================================================
local PALETTE = {
	oak = Color3.fromRGB(71, 52, 35),
	oakPale = Color3.fromRGB(94, 71, 47),
	oakGrey = Color3.fromRGB(86, 79, 68),
	iron = Color3.fromRGB(52, 45, 41),
	ironPale = Color3.fromRGB(78, 70, 63),
	rope = Color3.fromRGB(163, 138, 96),
	straw = Color3.fromRGB(146, 122, 68),
	strawDark = Color3.fromRGB(112, 92, 50),
	sack = Color3.fromRGB(112, 98, 74),
	stone = Color3.fromRGB(84, 82, 79),
	stonePale = Color3.fromRGB(112, 108, 100),
}

--==========================================================================
type SearchPoint = {
	model: Model,
	prompt: ProximityPrompt,
	glow: Highlight?,
	hasHandle: boolean,
	searched: boolean,
}

local root: Model? = nil
local started = false
local points: { SearchPoint } = {}

local drum: Model? = nil
local drumHome: CFrame = CFrame.new()
local winchPrompt: ProximityPrompt? = nil
local winchGlow: Highlight? = nil

local handleFound = false
local progress = 0
local done = false
local turning: { [number]: boolean } = {} -- UserIds currently holding

local hintEvent: RemoteEvent? = nil
local rng = Random.new()

--==========================================================================
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A cylinder's axis is its LOCAL X, so Size reads (length, diameter, diameter).
local function rod(parent: Instance, name: string, length: number, dia: number, cf: CFrame, colour: Color3, material: Enum.Material): Part
	local p = part(parent, name, Vector3.new(length, dia, dia), cf, colour, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function softGlow(adornee: Instance): Highlight
	--[[
		Pale, warm, and OCCLUDED — it does not draw through walls.

		That last part is the point of the area. Nine boxes lit up through the
		stables from the doorway is not searching, it is reading a map: you walk
		straight to the one you want and the room may as well not be there. Now
		a box lights up when you can see it, so finding the handle costs a walk
		round the stalls, which is the whole reason the winch is at the far end.
	]]
	local glow = Instance.new("Highlight")
	glow.Name = "Glow"
	glow.FillColor = Color3.fromRGB(232, 216, 182)
	glow.FillTransparency = 0.86
	glow.OutlineColor = Color3.fromRGB(240, 230, 206)
	glow.OutlineTransparency = 0.88
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Adornee = adornee
	glow.Parent = adornee

	--[[
		The FILL breathes, not the outline.

		A hard bright edge round a barrel is a video game marker; a faint warmth
		coming off the wood is a thing catching the light. The outline is turned
		down to almost nothing — it is there to define the shape at a distance
		and for no other reason.
	]]
	TweenService:Create(glow, TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		FillTransparency = 0.95,
	}):Play()
	return glow
end

local function hint(text: string?)
	if hintEvent then
		hintEvent:FireAllClients({ source = "area", text = text })
	end
end

--==========================================================================
-- FINDING SOMEWHERE TO PUT THINGS
--==========================================================================

-- Every road part's footprint, gathered once, so search points can be kept off
-- the road without re-walking the folder for each candidate.
local function roadPoints(): { Vector3 }
	local out: { Vector3 } = {}
	local gameplay = Workspace:FindFirstChild("Gameplay")
	local battleground = gameplay and gameplay:FindFirstChild("Battleground")
	local path = battleground and battleground:FindFirstChild("Path")
	if not path then
		return out
	end
	for _, d in path:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d.Position)
		end
	end
	return out
end

--[[
	Where the floor actually is under `x, z`, by raycast.

	Not "GROUND = 2". The chamber has a road at one level, terrain at another,
	and whatever the designer has dragged in on top of both — the only honest
	answer is to drop a ray and see what it lands on.
]]
local function floorAt(x: number, z: number, ignore: Instance?): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if ignore then { ignore } else {}
	params.IgnoreWater = true

	local hit = Workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -80, 0), params)
	if not hit then
		return nil
	end

	--[[
		A ray dropped over the stables lands on the ROOF, and a crate placed on
		that answer floats twenty studs up in the air. Anything much above the
		ward's floor is not a floor, it is something's lid — reject it and throw
		another dart.
	]]
	local y = hit.Position.Y
	if y > MAX_FLOOR_Y or y < -4 then
		return nil
	end
	return y
end

-- Is there room for a prop this big, standing on the floor here?
local function isClear(at: Vector3, radius: number, ignore: Instance?): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if ignore then { Workspace.Terrain, ignore } else { Workspace.Terrain }
	params.MaxParts = 1

	--[[
		The test box starts ABOVE the floor on purpose. Sitting a crate on
		flagstones is fine and sitting it inside a wall is not, so what matters
		is whether the space a person would walk through is empty — not whether
		the ground exists.
	]]
	local box = CFrame.new(at + Vector3.new(0, radius * 0.6 + 1.5, 0))
	local size = Vector3.new(radius * 2, radius * 1.2, radius * 2)
	return #Workspace:GetPartBoundsInBox(box, size, params) == 0
end

--==========================================================================
-- THE PROPS
--==========================================================================
local function buildCrate(parent: Instance, at: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "Crate"
	m.Parent = parent

	part(m, "Body", Vector3.new(5.2, 4.6, 5.2), at * CFrame.new(0, 2.3, 0), PALETTE.oak, Enum.Material.WoodPlanks)
	-- Facing boards on two sides, a shade darker, so it is not one flat cube.
	for _, side in { 1, -1 } do
		part(m, "Board", Vector3.new(5.4, 1.1, 0.4), at * CFrame.new(0, 3.4, side * 2.7), PALETTE.oakPale, Enum.Material.Wood)
		part(m, "Board", Vector3.new(5.4, 1.1, 0.4), at * CFrame.new(0, 1.2, side * 2.7), PALETTE.oakPale, Enum.Material.Wood)
	end
	part(m, "Lid", Vector3.new(5.6, 0.6, 5.6), at * CFrame.new(0, 4.8, 0) * CFrame.Angles(0, math.rad(rng:NextNumber(-6, 6)), 0), PALETTE.oakGrey, Enum.Material.Wood)
	for _, side in { 1, -1 } do
		part(m, "Band", Vector3.new(5.6, 0.5, 0.5), at * CFrame.new(0, 2.3, side * 2.7), PALETTE.iron, Enum.Material.CorrodedMetal)
	end
	return m
end

local function buildBarrel(parent: Instance, at: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "Barrel"
	m.Parent = parent

	local body = rod(m, "Body", 6.4, 5, at * CFrame.new(0, 3.2, 0) * CFrame.Angles(0, 0, math.rad(90)), PALETTE.oak, Enum.Material.Wood)
	for _, d in { -2.4, 0, 2.4 } do
		rod(m, "Hoop", 0.5, 5.3, body.CFrame * CFrame.new(d, 0, 0), PALETTE.iron, Enum.Material.CorrodedMetal)
	end
	rod(m, "Lid", 0.4, 4.6, body.CFrame * CFrame.new(3.3, 0, 0), PALETTE.oakGrey, Enum.Material.Wood)
	return m
end

local function buildBale(parent: Instance, at: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "Bale"
	m.Parent = parent

	for i = 1, 2 do
		local y = 1.6 + (i - 1) * 3.1
		local turn = CFrame.Angles(0, math.rad(rng:NextNumber(-20, 20)), 0)
		part(m, "Bale", Vector3.new(6, 3, 4.4), at * CFrame.new(rng:NextNumber(-0.6, 0.6), y, 0) * turn, if i == 1 then PALETTE.straw else PALETTE.strawDark, Enum.Material.LeafyGrass)
		for _, dz in { -1.3, 1.3 } do
			part(m, "Cord", Vector3.new(6.2, 0.3, 0.3), at * CFrame.new(0, y, dz) * turn, PALETTE.strawDark, Enum.Material.Fabric)
		end
	end
	-- Loose straw around the foot.
	for s = 1, 4 do
		part(m, "Loose", Vector3.new(rng:NextNumber(2, 4), 0.4, rng:NextNumber(2, 4)), at * CFrame.new(rng:NextNumber(-4, 4), 0.3, rng:NextNumber(-3, 3)) * CFrame.Angles(0, math.rad(rng:NextNumber(0, 90)), 0), PALETTE.straw, Enum.Material.LeafyGrass).CanCollide = false
	end
	return m
end

local function buildSacks(parent: Instance, at: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "Sacks"
	m.Parent = parent

	for i = 1, 4 do
		local a = math.rad(rng:NextNumber(0, 360))
		local r = if i == 4 then 0 else 2.4
		local y = if i == 4 then 4.1 else 1.8
		local sack = part(
			m,
			"Sack",
			Vector3.new(3.4, 3.2, 2.8),
			at * CFrame.new(math.cos(a) * r, y, math.sin(a) * r) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), a, math.rad(rng:NextNumber(-10, 10))),
			PALETTE.sack,
			Enum.Material.Fabric
		)
		-- The tie at the neck.
		part(m, "Tie", Vector3.new(0.9, 0.9, 0.9), sack.CFrame * CFrame.new(0, 1.7, 0), PALETTE.strawDark, Enum.Material.Fabric)
	end
	return m
end

local function buildChest(parent: Instance, at: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "Chest"
	m.Parent = parent

	part(m, "Body", Vector3.new(7.4, 3.4, 4), at * CFrame.new(0, 1.7, 0), PALETTE.oakGrey, Enum.Material.Wood)
	-- The lid, propped open a crack.
	part(m, "Lid", Vector3.new(7.6, 0.7, 4.2), at * CFrame.new(0, 3.6, -0.3) * CFrame.Angles(math.rad(-14), 0, 0), PALETTE.oak, Enum.Material.Wood)
	for _, dx in { -2.6, 2.6 } do
		part(m, "Band", Vector3.new(0.6, 3.8, 4.3), at * CFrame.new(dx, 1.9, 0), PALETTE.iron, Enum.Material.CorrodedMetal)
	end
	part(m, "Lock", Vector3.new(1.4, 1.6, 0.7), at * CFrame.new(0, 2.4, 2.2), PALETTE.ironPale, Enum.Material.CorrodedMetal)
	for _, dx in { -3, 3 } do
		part(m, "Foot", Vector3.new(1, 0.8, 4), at * CFrame.new(dx, 0.4, 0), PALETTE.oak, Enum.Material.Wood)
	end
	return m
end

local BUILDERS = { buildCrate, buildBarrel, buildBale, buildSacks, buildChest }

--==========================================================================
-- THE WINCH
--==========================================================================
local function buildWinch(parent: Instance)
	local frame = Instance.new("Model")
	frame.Name = "Winch"
	frame.Parent = parent

	local floor = floorAt(WINCH.X, WINCH.Z, parent) or WINCH.Y
	local base = CFrame.new(WINCH.X, floor, WINCH.Z)

	-- A stone pad, so it does not read as dropped on the mud.
	part(frame, "Pad", Vector3.new(14, 1, 10), base * CFrame.new(0, 0.4, 0), PALETTE.stonePale, Enum.Material.Cobblestone)

	-- Two uprights and the beam they carry.
	for _, dx in { -5, 5 } do
		part(frame, "Upright", Vector3.new(2.2, 9, 2.2), base * CFrame.new(dx, 5, 0), PALETTE.oak, Enum.Material.Wood)
		part(frame, "Foot", Vector3.new(3.6, 1.2, 3.6), base * CFrame.new(dx, 1.2, 0), PALETTE.stone, Enum.Material.Rock)
		-- The brace that stops it racking.
		part(frame, "Brace", Vector3.new(1.2, 5.4, 1.2), base * CFrame.new(dx, 4, 2.2) * CFrame.Angles(math.rad(26), 0, 0), PALETTE.oak, Enum.Material.Wood)
	end
	part(frame, "Header", Vector3.new(14, 1.6, 2.4), base * CFrame.new(0, 10.2, 0), PALETTE.oak, Enum.Material.Wood)

	--------------------------------------------------------------------------
	-- The drum. Its own Model so the whole assembly turns as one.
	--------------------------------------------------------------------------
	local turningPart = Instance.new("Model")
	turningPart.Name = "Drum"
	turningPart.Parent = frame

	--[[
		NO ROTATION ON ANY OF THESE. A cylinder's axis is its local X, `axis`
		has no rotation of its own, so the drum lies horizontal along world X —
		which is what a winch is. The obvious-looking `* CFrame.Angles(0, 0,
		rad(90))` swings that axis to world Y and stands the whole drum on end,
		and then PivotTo spins it like a potter's wheel.
	]]
	local axis = base * CFrame.new(0, 8.4, 0)

	local body = rod(turningPart, "Barrel", 9, 5.4, axis, PALETTE.oakPale, Enum.Material.Wood)
	body.CanCollide = false
	for _, dx in { -4.2, 4.2 } do
		rod(turningPart, "Cheek", 0.8, 6.6, axis * CFrame.new(dx, 0, 0), PALETTE.oak, Enum.Material.Wood)
	end

	-- Rope wound on it: seven turns, so the drum reads as something a rope is
	-- stored on rather than a log.
	for i = -3, 3 do
		rod(turningPart, "Wound", 0.7, 5.9, axis * CFrame.new(i * 0.95, 0, 0), PALETTE.rope, Enum.Material.Fabric)
	end

	-- The ratchet wheel, and the two spokes you push.
	rod(turningPart, "Ratchet", 0.7, 7.4, axis * CFrame.new(5, 0, 0), PALETTE.iron, Enum.Material.CorrodedMetal)
	for i = 0, 11 do
		local a = i * math.pi / 6
		part(turningPart, "Tooth", Vector3.new(0.7, 1.2, 1.2), axis * CFrame.new(5, math.cos(a) * 3.7, math.sin(a) * 3.7) * CFrame.Angles(a, 0, 0), PALETTE.iron, Enum.Material.CorrodedMetal)
	end
	for _, dir in { 1, -1 } do
		part(turningPart, "Spoke", Vector3.new(1.3, 7.4, 1.3), axis * CFrame.new(-3.4, 0, 0) * CFrame.Angles(math.rad(if dir == 1 then 0 else 90), 0, 0), PALETTE.oak, Enum.Material.Wood)
	end

	turningPart.PrimaryPart = body
	drum = turningPart
	drumHome = turningPart:GetPivot()

	-- The pawl that drops into the ratchet: the reason it holds at all, and the
	-- reason it does not hold well any more.
	part(frame, "Pawl", Vector3.new(0.8, 0.9, 4.4), base * CFrame.new(5, 11.6, 2) * CFrame.Angles(math.rad(-32), 0, 0), PALETTE.iron, Enum.Material.CorrodedMetal)

	--------------------------------------------------------------------------
	-- The rope up to the gate. It is what says this handle moves that iron.
	--------------------------------------------------------------------------
	local from = base.Position + Vector3.new(0, 8.4, 0)
	local delta = GATE_TOP - from
	local rope = part(
		frame,
		"Rope",
		Vector3.new(0.5, delta.Magnitude, 0.5),
		CFrame.lookAt(from + delta / 2, GATE_TOP) * CFrame.Angles(math.rad(90), 0, 0),
		PALETTE.rope,
		Enum.Material.Fabric
	)
	rope.CanCollide = false
	rope.CastShadow = false

	--------------------------------------------------------------------------
	local hook = part(frame, "Hook", Vector3.new(1, 1, 1), base * CFrame.new(-6.5, 6, 3), PALETTE.oak, Enum.Material.Wood)
	hook.Transparency = 1
	hook.CanCollide = false
	hook.CanQuery = false

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Turn"
	prompt.ActionText = "Turn"
	prompt.ObjectText = "Winch — no handle"

	--[[
		The long hold is set from the START, not only once the handle turns up.
		PromptButtonHoldBegan does not fire at all when HoldDuration is 0, and
		that is the event which tells a player pressing E at a handle-less winch
		why nothing is happening.
	]]
	prompt.HoldDuration = HOLD_SECONDS
	prompt.MaxActivationDistance = REACH
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = hook
	winchPrompt = prompt

	log:info(("winch at %.0f, %.0f, %.0f"):format(base.X, floor, base.Z))
end

--==========================================================================
-- PLACING THE SEARCH POINTS
--==========================================================================
local function placeSearchPoints(parent: Instance)
	local road = roadPoints()
	local chosen: { Vector3 } = {}

	local function farEnough(at: Vector3): boolean
		for _, p in chosen do
			if (Vector2.new(at.X - p.X, at.Z - p.Z)).Magnitude < MIN_APART then
				return false
			end
		end
		for _, p in road do
			if (Vector2.new(at.X - p.X, at.Z - p.Z)).Magnitude < ROAD_CLEARANCE then
				return false
			end
		end
		return true
	end

	--[[
		Dart-throwing with a real budget. Nine points in a zone this size is not
		a tight fit, but the stables and whatever else is standing there take up
		most of it, so a few hundred attempts is honest rather than optimistic.
	]]
	local attempts = 0
	while #chosen < SEARCH_POINTS and attempts < 600 do
		attempts += 1
		local x = rng:NextNumber(ZONE_X[1], ZONE_X[2])
		local z = rng:NextNumber(ZONE_Z[1], ZONE_Z[2])

		local y = floorAt(x, z, parent)
		if y and farEnough(Vector3.new(x, y, z)) then
			local at = Vector3.new(x, y, z)
			if isClear(at, 5, parent) then
				table.insert(chosen, at)
			end
		end
	end

	if #chosen == 0 then
		log:warn("could not place a single search point — is the chamber full?")
		return
	end
	if #chosen < SEARCH_POINTS then
		log:warn(("only %d of %d search points fitted"):format(#chosen, SEARCH_POINTS))
	end

	-- One of them has the handle, and which one changes every run.
	local withHandle = rng:NextInteger(1, #chosen)

	for i, at in chosen do
		local builder = BUILDERS[((i - 1) % #BUILDERS) + 1]
		local cf = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local model = builder(parent, cf)

		local hook = part(model, "Hook", Vector3.new(1, 1, 1), CFrame.new(at + Vector3.new(0, 4, 0)), PALETTE.oak, Enum.Material.Wood)
		hook.Transparency = 1
		hook.CanCollide = false
		hook.CanQuery = false

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Search"
		prompt.ActionText = "Search"
		prompt.ObjectText = model.Name
		prompt.HoldDuration = 0.9
		prompt.MaxActivationDistance = 11
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = hook

		local point: SearchPoint = {
			model = model,
			prompt = prompt,
			glow = softGlow(model),
			hasHandle = (i == withHandle),
			searched = false,
		}
		table.insert(points, point)

		prompt.Triggered:Connect(function(player: Player)
			WinchService.search(point, player)
		end)
	end

	log:info(("%d search points placed in %d attempts"):format(#chosen, attempts))
end

--==========================================================================
-- SEARCHING
--==========================================================================
function WinchService.search(point: SearchPoint, player: Player)
	if point.searched then
		return
	end
	point.searched = true
	point.prompt.Enabled = false
	if point.glow then
		point.glow:Destroy()
		point.glow = nil
	end

	-- Something visibly happens either way: the lid tips, the sacks slump.
	local lid = point.model:FindFirstChild("Lid") or point.model:FindFirstChild("Bale")
	if lid and lid:IsA("BasePart") then
		TweenService:Create(lid, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			CFrame = lid.CFrame * CFrame.new(rng:NextNumber(-1.5, 1.5), 0.6, rng:NextNumber(1, 2.5))
				* CFrame.Angles(math.rad(rng:NextNumber(10, 40)), 0, math.rad(rng:NextNumber(-25, 25))),
		}):Play()
	end

	if not point.hasHandle then
		return
	end

	--------------------------------------------------------------------------
	handleFound = true
	log:info(("%s found the winch handle in the %s"):format(player.Name, point.model.Name))

	-- The handle itself, lifting out of the box and away.
	local at = point.model:GetPivot()
	local handle = Instance.new("Model")
	handle.Name = "WinchHandle"
	handle.Parent = point.model.Parent

	local bar = rod(handle, "Bar", 7, 1.1, at * CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(20)), PALETTE.iron, Enum.Material.CorrodedMetal)
	bar.CanCollide = false
	local grip = rod(handle, "Grip", 3, 1.6, bar.CFrame * CFrame.new(3, 0, 0), PALETTE.oak, Enum.Material.Wood)
	grip.CanCollide = false
	handle.PrimaryPart = bar
	softGlow(handle)

	task.spawn(function()
		local start = handle:GetPivot()
		local t = 0
		while t < 1.1 do
			local dt = RunService.Heartbeat:Wait()
			t = math.min(t + dt, 1.1)
			local a = t / 1.1
			handle:PivotTo(start * CFrame.new(0, a * 4, 0) * CFrame.Angles(0, a * 8, 0))
		end
		handle:Destroy()
	end)

	if winchPrompt then
		winchPrompt.ObjectText = "Winch"
	end
	if not winchGlow and drum then
		winchGlow = softGlow(drum)
	end

	-- Every other box stops being worth opening.
	for _, other in points do
		if not other.searched then
			other.prompt.Enabled = false
			if other.glow then
				other.glow:Destroy()
				other.glow = nil
			end
		end
	end

	hint("Turn the winch")
end

--==========================================================================
-- TURNING
--==========================================================================
local function applyProgress()
	AreaService.setOpenFraction(AREA, progress)
	if drum then
		-- Four full turns from shut to open: enough that the drum is obviously
		-- doing the work, few enough that it does not blur.
		drum:PivotTo(drumHome * CFrame.Angles(progress * math.pi * 8, 0, 0))
	end
end

local function finish()
	hint(nil)
	if winchPrompt then
		winchPrompt.Enabled = false
	end
	if winchGlow then
		winchGlow:Destroy()
		winchGlow = nil
	end
	log:info("winch fully wound — area 2 open")
	AreaService.clear(AREA)
end

--[[
	How many hands are on it, and how fast that makes it climb.

	Zero hands is the fall. One is the raise rate. Each extra pair adds half a
	pair's worth, so it is always worth having someone else on the winch and
	never necessary.
]]
local function windRate(): number
	local hands = 0
	for _ in turning do
		hands += 1
	end
	if hands == 0 then
		return -FALL_RATE
	end
	return RAISE_RATE * (1 + (hands - 1) * EXTRA_HANDS)
end

--[[
	Someone grabbed it. The handle has to be in before anything happens — and
	saying so costs one line and saves a player standing there pressing E at a
	winch that will never move.
]]
local function grab(player: Player)
	if handleFound then
		turning[player.UserId] = true
		return
	end
	hint("Find the handle first")
	task.delay(3, function()
		if not handleFound then
			hint("Find the winch handle")
		end
	end)
end

local function release(player: Player)
	turning[player.UserId] = nil
end

--==========================================================================
local function begin(player: Player)
	if started then
		return
	end
	started = true

	local parent = AreaService.gateModel(AREA)
	if not parent then
		log:info("no gate for area 2 — nothing to wind")
		return
	end

	local model = Instance.new("Model")
	model.Name = "WinchWorks"
	model.Parent = parent
	root = model

	buildWinch(model)
	placeSearchPoints(model)

	--[[
		Hold events, not Triggered. HOLD_SECONDS is long enough that the prompt
		is never actually completed, so `Began` and `Ended` bracket exactly how
		long the player kept E down — which is the whole mechanic. Triggered is
		still wired for the case where somebody does hold it for a minute and a
		half, so the winch does not silently stop responding.
	]]
	if winchPrompt then
		winchPrompt.PromptButtonHoldBegan:Connect(grab)
		winchPrompt.PromptButtonHoldEnded:Connect(release)
		winchPrompt.Triggered:Connect(release)
	end

	Players.PlayerRemoving:Connect(release)

	hint("Find the winch handle")
	log:info(("%s entered — winch armed, handle hidden"):format(player.Name))
end

--==========================================================================
function WinchService.Init() end

function WinchService.Start()
	if GameService.getPlaceRole() ~= Constants.PlaceRole.World then
		return
	end

	hintEvent = Net.getEvent("ObjectiveHint")
	AreaService.onEnter(AREA, begin)

	--[[
		One loop, both directions. Hands on it and it climbs; hands off and it
		falls, from the same frame, with no grace and nothing banked. That is
		what "hold E" means, and it is why letting go to swing at something
		costs real height rather than a notch on a counter.
	]]
	RunService.Heartbeat:Connect(function(dt: number)
		if not started or done then
			return
		end

		local rate = windRate()
		if rate < 0 and progress <= 0 then
			return -- already on the floor; nothing to lose
		end

		progress = math.clamp(progress + rate * dt, 0, 1)
		applyProgress()

		if progress >= 1 then
			done = true
			finish()
		end
	end)

	log:info("armed — waits for a player to enter area 2")
end

-- Development shortcut: wind it all the way without finding anything.
function WinchService.forceOpen()
	handleFound = true
	progress = 1
	done = true
	applyProgress()
	finish()
end

return WinchService
