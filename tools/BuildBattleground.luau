--[[
	BuildBattleground — run in the Studio Command Bar of the FORGOTTEN LANDS
	place, in EDIT MODE. Select the whole file (Ctrl+A), copy, paste, Enter.

	THE MAP IS INSIDE THE CASTLE. Not a road toward it — the walls are already
	around you when you spawn, and everything that happens, happens in here.

	A 300 x 1800 enclosure, sealed on all four sides, divided into nine chambers
	by cross-walls. Each cross-wall has ONE gap, and the gap alternates side to
	side, so the route is forward, right, forward, left, forward, right — a
	serpentine you cannot get lost in and cannot leave. No invisible walls: the
	castle itself is the boundary, which is the only kind of boundary a player
	ever accepts.

	Each chamber is roughly 300 x 190 — an arena, sized for a wave — and comes
	with markers the gameplay systems already read: enemy spawns, an objective
	point, the gate to the next chamber, a checkpoint, and a spot for a
	storyteller.

	The towers are the point of this file. See docs/systems/TowerAnatomy.md for
	what each piece of them is and why it is there. A cylinder with square teeth
	on top reads as a chess piece; batter, machicolations and a stair turret read
	as a building somebody died defending.

	The interior of each chamber is left EMPTY on purpose — that is where your
	houses, rubble and set dressing go.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

--==========================================================================
-- Shape of the world
--==========================================================================
local HALF_W = 150 -- 300 wide
local Z_START = 20 -- behind the gate
local CHAMBERS = 9
local CHAMBER_D = 200 -- 9 x 200 = 1800 long
local WALL_H = 62
local WALL_T = 14
local GAP_W = 46 -- the opening in each cross-wall

-- 1 = masses only. 2 = the architecture. 3 = every detail in the anatomy notes.
local DETAIL = 3
local BUILD_TERRAIN = true
local BUILD_LIGHTING = true
local BUILD_TORCHES = false -- lighting is placed by hand; see tools/PurgeLights
local MAX_LIGHTS = 80
local lightsUsed = 0

local rng = Random.new(1453)

--==========================================================================
-- Palette
--==========================================================================
local C = {
	stone = Color3.fromRGB(84, 82, 79),
	stoneDark = Color3.fromRGB(60, 59, 60),
	stonePale = Color3.fromRGB(112, 108, 100),
	stoneWarm = Color3.fromRGB(98, 92, 82),
	rock = Color3.fromRGB(86, 80, 73),
	wood = Color3.fromRGB(74, 56, 40),
	woodDark = Color3.fromRGB(52, 39, 28),
	iron = Color3.fromRGB(58, 50, 46),
	rust = Color3.fromRGB(94, 58, 40),
	cloth = Color3.fromRGB(96, 40, 44),
	ash = Color3.fromRGB(38, 36, 36),
	flame = Color3.fromRGB(255, 150, 60),
	ground = Color3.fromRGB(96, 82, 64),
}

local M = {
	stone = Enum.Material.Slate,
	brick = Enum.Material.Brick,
	cobble = Enum.Material.Cobblestone,
	rock = Enum.Material.Rock,
	wood = Enum.Material.WoodPlanks,
	log = Enum.Material.Wood,
	iron = Enum.Material.Metal,
	rusted = Enum.Material.CorrodedMetal,
	cloth = Enum.Material.Fabric,
	neon = Enum.Material.Neon,
}

--==========================================================================
-- Foundations
--==========================================================================
local root = workspace:FindFirstChild("Gameplay")
if not root then
	root = Instance.new("Folder")
	root.Name = "Gameplay"
	root.Parent = workspace
end

local made = 0

local function group(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

local function folder(parent: Instance, name: string): Folder
	local item = Instance.new("Folder")
	item.Name = name
	item.Parent = parent
	return item
end

local function jitter(a: number): number
	return rng:NextNumber(-a, a)
end

local function chance(p: number): boolean
	return rng:NextNumber() < p
end

--==========================================================================
-- Primitives
--==========================================================================
local function block(parent, name, size, cf, colour, material, shadow): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.Color = colour or C.stone
	part.Material = material or M.stone
	part.CastShadow = shadow == true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	made += 1
	return part
end

-- Only the big masses cast shadows; that is what gives a ruin its weight, and
-- there are far too many small pieces here to let any of them try.
local function mass(parent, name, size, cf, colour, material): Part
	return block(parent, name, size, cf, colour, material, true)
end

local function wedge(parent, name, size, cf, colour, material): WedgePart
	local part = Instance.new("WedgePart")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.Color = colour or C.stone
	part.Material = material or M.stone
	part.CastShadow = false
	part.Parent = parent
	made += 1
	return part
end

-- A cylinder part points along X, so it has to be stood upright.
local function drum(parent, name, radius, height, at, colour, material, shadow): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.Size = Vector3.new(height, radius * 2, radius * 2)
	part.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	part.Color = colour or C.stone
	part.Material = material or M.stone
	part.CastShadow = shadow == true
	part.Parent = parent
	made += 1
	return part
end

local function bar(parent, name, radius, from: Vector3, to: Vector3, colour, material): Part
	local span = to - from
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.Size = Vector3.new(span.Magnitude, radius * 2, radius * 2)
	part.CFrame = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0)
	part.Color = colour or C.woodDark
	part.Material = material or M.log
	part.CastShadow = false
	part.Parent = parent
	made += 1
	return part
end

local function ball(parent, name, radius, at, colour, material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	part.CFrame = CFrame.new(at)
	part.Color = colour or C.rock
	part.Material = material or M.rock
	part.CastShadow = false
	part.Parent = parent
	made += 1
	return part
end

local function flame(parent, at: Vector3, size: number)
	local model = group(parent, "Flame")
	for i = 1, 3 do
		local s = size * (1 - (i - 1) * 0.26)
		ball(model, "Fire", s, at + Vector3.new(jitter(size * 0.2), (i - 1) * size * 0.7, jitter(size * 0.2)), if i == 1 then C.flame else Color3.fromRGB(255, 200, 130), M.neon)
	end
	if lightsUsed < MAX_LIGHTS then
		lightsUsed += 1
		local light = Instance.new("PointLight")
		light.Color = C.flame
		light.Brightness = 1.5
		light.Range = 30
		light.Shadows = false
		light.Parent = model:FindFirstChild("Fire")
	end
	return model
end

local function torch(parent, at: Vector3, facing: number, lit: boolean)
	-- Off by default. Placing sixty torches by arithmetic gets sixty torches in
	-- roughly the right place, and roughly is not good enough for the thing the
	-- player's eye goes to first. They are placed by hand instead.
	if not BUILD_TORCHES then
		return nil
	end
	local model = group(parent, "Torch")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(facing), 0)
	block(model, "Bracket", Vector3.new(0.5, 0.5, 2.6), base * CFrame.new(0, 0, 1.2), C.iron, M.rusted)
	bar(model, "Shaft", 0.32, (base * CFrame.new(0, -0.4, 2)).Position, (base * CFrame.new(0, 2.6, 3.4)).Position, C.woodDark, M.log)
	block(model, "Head", Vector3.new(1, 1.2, 1), base * CFrame.new(0, 2.9, 3.6), C.ash, M.rock)
	if lit then
		flame(model, (base * CFrame.new(0, 3.8, 3.6)).Position, 0.9)
	end
	return model
end

--==========================================================================
-- TOWER ANATOMY
-- Each piece below is one line in docs/systems/TowerAnatomy.md.
--==========================================================================

--[[
	The batter: the splayed, sloping thickening at a tower's foot. It deflects
	dropped stones outward and resists undermining, and it is the single most
	recognisable feature of a real tower — the thing almost always missing from
	a fake one. Built as a short stack of drums stepping inward.
]]
local function batter(parent, at: Vector3, radius: number, height: number, spread: number)
	local steps = 7
	for i = 0, steps - 1 do
		local t = i / steps
		local r = radius + spread * (1 - t)
		drum(parent, "Batter", r, height / steps + 0.4, at + Vector3.new(0, height * (t + 0.5 / steps), 0), C.stoneWarm, M.stone, i == 0)
	end
	-- The plinth roll: sheds water off the slope and gives the eye a base line.
	drum(parent, "PlinthRoll", radius + 1.4, 2.4, at + Vector3.new(0, height, 0), C.stonePale, M.stone)
end

-- Horizontal bands marking the floors inside. Without them a tower is a pipe.
local function stringCourse(parent, at: Vector3, radius: number, y: number)
	drum(parent, "StringCourse", radius + 1.1, 2, at + Vector3.new(0, y, 0), C.stoneDark, M.stone)
end

--[[
	Putlog holes: where the scaffolding poles sat while the tower went up.
	Nobody ever filled them in. They spiral, because the scaffold did.
]]
local function putlogs(parent, at: Vector3, radius: number, fromY: number, toY: number)
	local rows = math.floor((toY - fromY) / 11)
	for row = 0, rows do
		local y = fromY + row * 11
		local base = row * 0.9
		for i = 0, 5 do
			local a = base + (math.pi * 2 / 6) * i
			block(parent, "Putlog", Vector3.new(1.5, 1.5, 2), CFrame.new(at.X + math.cos(a) * radius, at.Y + y, at.Z + math.sin(a) * radius) * CFrame.Angles(0, -a, 0), C.ash, M.stone)
		end
	end
end

--[[
	A cross loop: the arrow slit, splayed wider on the inside so the archer can
	swing while the attacker has almost nothing to hit. The cross bar is for a
	crossbow.
]]
local function crossLoop(parent, cf: CFrame, scale: number)
	local s = scale or 1
	block(parent, "Slit", Vector3.new(0.9 * s, 6 * s, 3), cf, C.ash, M.stone)
	block(parent, "Cross", Vector3.new(3.6 * s, 0.9 * s, 3), cf * CFrame.new(0, 1.6 * s, 0), C.ash, M.stone)
	-- Splayed embrasure: the recess is wider than the slit.
	block(parent, "Embrasure", Vector3.new(3.4 * s, 7.5 * s, 1.2), cf * CFrame.new(0, 0, -1.6), C.stoneDark, M.stone)
	-- Dressed stone surround, so the opening reads as cut rather than knocked.
	for side = -1, 1, 2 do
		block(parent, "Jamb", Vector3.new(1.1, 8 * s, 2.6), cf * CFrame.new(side * 1.6 * s, 0, 0.2), C.stonePale, M.stone)
	end
	block(parent, "Sill", Vector3.new(4.2 * s, 1, 2.8), cf * CFrame.new(0, -4.2 * s, 0.2), C.stonePale, M.stone)
end

-- A narrow arch-headed window. Only the upper floors ever get real ones:
-- ground-floor windows are how a tower falls.
local function lancet(parent, cf: CFrame, w: number, h: number)
	block(parent, "Opening", Vector3.new(w, h, 3), cf, C.ash, M.stone)
	for side = -1, 1, 2 do
		block(parent, "Jamb", Vector3.new(1.2, h, 2.8), cf * CFrame.new(side * (w / 2 + 0.6), 0, 0.2), C.stonePale, M.stone)
	end
	block(parent, "Sill", Vector3.new(w + 3.4, 1.2, 3.4), cf * CFrame.new(0, -h / 2 - 0.6, 0.4), C.stonePale, M.stone)
	-- Voussoirs: the wedge stones of the arch head.
	local n = 5
	for i = 0, n do
		local a = math.pi * (i / n)
		block(parent, "Voussoir", Vector3.new(1.4, 2, 3), cf * CFrame.new(math.cos(a) * (w / 2 + 0.4), h / 2 + math.sin(a) * (w / 2 + 0.4), 0.1) * CFrame.Angles(0, 0, -a), C.stonePale, M.stone)
	end
	-- Hood mould: the drip band over the arch that keeps rain off the opening.
	for i = 0, n do
		local a = math.pi * (i / n)
		block(parent, "Hood", Vector3.new(1.6, 1.4, 1.6), cf * CFrame.new(math.cos(a) * (w / 2 + 2.4), h / 2 + math.sin(a) * (w / 2 + 2.4), 1.2) * CFrame.Angles(0, 0, -a), C.stoneDark, M.stone)
	end
end

-- The latrine, projecting off the shaft with a chute down the outside. Ugly,
-- universal, and instantly convincing.
local function garderobe(parent, at: Vector3, radius: number, y: number, angle: number)
	local model = group(parent, "Garderobe")
	local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local pos = at + out * (radius + 3) + Vector3.new(0, y, 0)
	block(model, "Box", Vector3.new(7, 9, 8), CFrame.new(pos) * CFrame.Angles(0, -angle, 0), C.stoneWarm, M.stone)
	block(model, "Roof", Vector3.new(8, 1.4, 9), CFrame.new(pos + Vector3.new(0, 5.2, 0)) * CFrame.Angles(0, -angle, 0), C.stoneDark, M.stone)
	-- Corbels carrying it.
	for i = -1, 1 do
		block(model, "Corbel", Vector3.new(2, 2.4, 4), CFrame.new(at + out * (radius + 1.4) + Vector3.new(0, y - 5.4, 0) + Vector3.new(-math.sin(angle) * i * 2.4, 0, math.cos(angle) * i * 2.4)) * CFrame.Angles(0, -angle, 0), C.stonePale, M.stone)
	end
	-- The chute, and the stain forty years of it left.
	block(model, "Chute", Vector3.new(2.6, y - 6, 2.6), CFrame.new(at + out * (radius + 1.6) + Vector3.new(0, (y - 6) / 2, 0)) * CFrame.Angles(0, -angle, 0), C.stoneDark, M.stone)
	return model
end

--[[
	Machicolations: boxes projecting on corbels with gaps between them, so that
	things can be dropped through onto whoever is at the wall foot. The mark of
	a tower built by someone who expected to be attacked.
]]
local function machicolation(parent, at: Vector3, radius: number, y: number, count: number)
	local model = group(parent, "Machicolation")
	for i = 0, count - 1 do
		local a = (math.pi * 2 / count) * i
		local outer = Vector3.new(math.cos(a), 0, math.sin(a))

		-- Two corbels per box, stepping outward.
		for step = 1, 3 do
			local r = radius + step * 1.1
			block(model, "Corbel", Vector3.new(3.4, 1.6, 2.6), CFrame.new(at + outer * r + Vector3.new(0, y - 5 + step * 1.3, 0)) * CFrame.Angles(0, -a, 0), C.stonePale, M.stone)
		end
		-- The box itself, sitting proud of the wall.
		block(model, "Box", Vector3.new(5.6, 4.4, 4.6), CFrame.new(at + outer * (radius + 3.2) + Vector3.new(0, y + 1.4, 0)) * CFrame.Angles(0, -a, 0), C.stoneWarm, M.stone)
		-- The hole you drop things through.
		block(model, "Hole", Vector3.new(2.6, 1, 2.6), CFrame.new(at + outer * (radius + 3.4) + Vector3.new(0, y - 0.6, 0)) * CFrame.Angles(0, -a, 0), C.ash, M.stone)
	end
	return model
end

-- The battlement on top: merlons with their own slits, gaps between, and the
-- walkway behind them.
local function parapet(parent, at: Vector3, radius: number, y: number, count: number, ruinGaps: number)
	local model = group(parent, "Parapet")
	drum(model, "Allure", radius - 1, 2, at + Vector3.new(0, y, 0), C.stone, M.stone)
	drum(model, "ParapetWall", radius + 2, 4, at + Vector3.new(0, y + 2, 0), C.stoneWarm, M.stone)
	for i = 0, count - 1 do
		local a = (math.pi * 2 / count) * i
		if not chance(ruinGaps or 0) then
			local outer = Vector3.new(math.cos(a), 0, math.sin(a))
			local merlon = block(model, "Merlon", Vector3.new(radius * 0.42, 9, 4.4), CFrame.new(at + outer * (radius + 0.4) + Vector3.new(0, y + 8.5, 0)) * CFrame.Angles(0, -a, 0), C.stoneDark, M.stone)
			-- Merlons on a serious tower have slits of their own.
			if DETAIL >= 3 and chance(0.55) then
				block(model, "MerlonSlit", Vector3.new(0.8, 4, 5), merlon.CFrame * CFrame.new(0, 0.6, 0), C.ash, M.stone)
			end
			-- Capstone, weathered to shed rain.
			block(model, "Cap", Vector3.new(radius * 0.5, 1, 5.2), merlon.CFrame * CFrame.new(0, 5, 0), C.stonePale, M.stone)
		end
	end
	return model
end

-- A small turret corbelled out near the top, covering the tower's blind spots.
local function bartizan(parent, at: Vector3, radius: number, y: number, angle: number)
	local model = group(parent, "Bartizan")
	local outer = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local pos = at + outer * (radius + 2)
	-- Corbelled underside: three drums stepping outward as they rise.
	for step = 1, 4 do
		drum(model, "Corbel", 1.4 + step * 0.9, 1.6, pos + Vector3.new(0, y - 7 + step * 1.7, 0), C.stonePale, M.stone)
	end
	drum(model, "Body", 5, 13, pos + Vector3.new(0, y + 6, 0), C.stoneWarm, M.stone)
	for i = 0, 5 do
		local a = (math.pi * 2 / 6) * i
		block(model, "Merlon", Vector3.new(2.4, 4.4, 2.4), CFrame.new(pos + Vector3.new(math.cos(a) * 4, y + 14.5, math.sin(a) * 4)) * CFrame.Angles(0, -a, 0), C.stoneDark, M.stone)
	end
	-- Its own little conical cap.
	for step = 1, 4 do
		drum(model, "Cap", 5 * (1 - step / 5), 3, pos + Vector3.new(0, y + 17 + step * 2.4, 0), C.woodDark, M.wood)
	end
	crossLoop(model, CFrame.new(pos + outer * 5 + Vector3.new(0, y + 6, 0)) * CFrame.Angles(0, -angle + math.pi / 2, 0), 0.6)
	return model
end

-- The spiral stair has to go somewhere, and it always overshoots the roof.
local function stairTurret(parent, at: Vector3, radius: number, height: number, angle: number)
	local model = group(parent, "StairTurret")
	local outer = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local pos = at + outer * (radius * 0.86)
	local r = radius * 0.42

	batter(model, pos, r, 8, 1.8)
	drum(model, "Shaft", r, height, pos + Vector3.new(0, height / 2 + 8, 0), C.stoneWarm, M.stone, true)
	for level = 1, math.floor(height / 26) do
		stringCourse(model, pos, r, 8 + level * 26)
		if DETAIL >= 3 then
			crossLoop(model, CFrame.new(pos + outer * r + Vector3.new(0, 8 + level * 26 - 8, 0)) * CFrame.Angles(0, -angle + math.pi / 2, 0), 0.55)
		end
	end
	-- Its cap: a little cone, higher than the tower it serves.
	local top = height + 8
	for step = 1, 6 do
		drum(model, "Cap", r * (1 - step / 7) + 0.6, 3, pos + Vector3.new(0, top + step * 2.6, 0), C.woodDark, M.wood)
	end
	bar(model, "Finial", 0.3, pos + Vector3.new(0, top + 17, 0), pos + Vector3.new(0, top + 24, 0), C.iron, M.rusted)
	return model
end

-- Tie rods hold the floors into the walls. The plates on the outside are tiny
-- and pay for themselves.
local function anchorPlates(parent, at: Vector3, radius: number, fromY: number, toY: number)
	local levels = math.floor((toY - fromY) / 26)
	for level = 0, levels do
		local y = fromY + level * 26
		for i = 0, 3 do
			local a = (math.pi * 2 / 4) * i + level * 0.4
			local pos = at + Vector3.new(math.cos(a) * radius, y, math.sin(a) * radius)
			block(parent, "AnchorV", Vector3.new(0.7, 3.4, 1.4), CFrame.new(pos) * CFrame.Angles(0, -a, 0), C.rust, M.rusted)
			block(parent, "AnchorH", Vector3.new(3.4, 0.7, 1.4), CFrame.new(pos) * CFrame.Angles(0, -a, 0), C.rust, M.rusted)
		end
	end
end

-- Sockets in the inner face where floor beams pulled out when it burned.
local function floorSockets(parent, at: Vector3, radius: number, y: number, count: number)
	for i = 0, count - 1 do
		local a = (math.pi * 2 / count) * i
		block(parent, "Socket", Vector3.new(2.6, 2.6, 3), CFrame.new(at + Vector3.new(math.cos(a) * (radius - 1), y, math.sin(a) * (radius - 1))) * CFrame.Angles(0, -a, 0), C.ash, M.stone)
	end
end

local function rubbleCone(parent, at: Vector3, angle: number, radius: number, count: number)
	local model = group(parent, "Rubble")
	local outer = Vector3.new(math.cos(angle), 0, math.sin(angle))
	for _ = 1, count do
		local d = rng:NextNumber(0, radius)
		local spread = jitter(radius * 0.5)
		local s = rng:NextNumber(3, 11)
		local pos = at + outer * d + Vector3.new(-outer.Z * spread, s / 3, outer.X * spread)
		block(model, "Stone", Vector3.new(s, s * rng:NextNumber(0.4, 0.9), s * rng:NextNumber(0.6, 1.2)), CFrame.new(pos) * CFrame.Angles(jitter(0.5), rng:NextNumber(0, 6), jitter(0.5)), if chance(0.5) then C.rock else C.stone, M.rock)
	end
	return model
end

--==========================================================================
-- THE TOWER
--==========================================================================
--[[
	`opts`:
	  radius, height   the drum itself
	  ruin             0 intact, 1 barely standing
	  roof             "cone" | "flat" | nil
	  stair            angle in radians for the stair turret, or nil
	  bartizans        how many, near the top
	  torch            light it
	  banner           fly a banner from the roof
]]
local function tower(parent, name: string, at: Vector3, opts)
	opts = opts or {}
	local R = opts.radius or 26
	local H = opts.height or 96
	local ruin = opts.ruin or 0
	local model = group(parent, name)

	-- How much of the tower survives, and where it broke. Masonry fails along a
	-- diagonal, never a level line, so the break is a wedge cut off the top.
	local standing = H * (1 - ruin * 0.55)

	-- 1. Batter, always. It is the last thing to go.
	batter(model, at, R, 14, 5)

	-- 2. The shaft.
	drum(model, "Shaft", R, standing - 14, at + Vector3.new(0, 14 + (standing - 14) / 2, 0), C.stone, M.stone, true)

	-- 3. String courses marking the floors.
	local floors = math.max(2, math.floor(standing / 28))
	for level = 1, floors - 1 do
		stringCourse(model, at, R, 14 + level * ((standing - 14) / floors))
	end

	-- 4. Openings. Cross loops low, real windows only high up.
	if DETAIL >= 2 then
		for level = 1, floors do
			local y = 14 + (level - 0.5) * ((standing - 14) / floors)
			local faces = if level == 1 then 3 else 4
			for i = 0, faces - 1 do
				local a = (math.pi * 2 / faces) * i + level * 0.7
				local cf = CFrame.new(at + Vector3.new(math.cos(a) * R, y, math.sin(a) * R)) * CFrame.Angles(0, -a + math.pi / 2, 0)
				if level >= floors - 1 and chance(0.55) then
					lancet(model, cf, 3.4, 9)
				else
					crossLoop(model, cf, 1)
				end
			end
		end
	end

	-- 5. The small truths: scaffolding holes, tie plates, the latrine.
	if DETAIL >= 3 then
		putlogs(model, at, R, 22, standing - 14)
		anchorPlates(model, at, R, 30, standing - 20)
		if chance(0.6) then
			garderobe(model, at, R, standing * 0.45, rng:NextNumber(0, math.pi * 2))
		end
	end

	-- 6. The top — machicolations and battlements, if the top survived at all.
	if ruin < 0.45 then
		if DETAIL >= 2 then
			machicolation(model, at, R, standing, math.max(10, math.floor(R * 0.75)))
		end
		parapet(model, at, R + 3, standing + 4, math.max(10, math.floor(R * 0.62)), ruin * 0.9)

		if DETAIL >= 3 and opts.bartizans then
			for i = 1, opts.bartizans do
				bartizan(model, at, R, standing - 6, (math.pi * 2 / opts.bartizans) * i + 0.6)
			end
		end

		if opts.roof == "cone" then
			local top = standing + 14
			for step = 1, 9 do
				drum(model, "Roof", R * (1 - step / 10) + 1, 4, at + Vector3.new(0, top + step * 3.4, 0), C.woodDark, M.wood)
			end
			bar(model, "Finial", 0.4, at + Vector3.new(0, top + 32, 0), at + Vector3.new(0, top + 42, 0), C.iron, M.rusted)
			if opts.banner then
				block(model, "Banner", Vector3.new(0.3, 9, 6), CFrame.new(at + Vector3.new(0, top + 36, 3.2)), C.cloth, M.cloth)
			end
		end
	else
		-- A ruined top: the break is diagonal, the floors show, and what fell is
		-- lying at the foot on the side it fell.
		local breakAngle = rng:NextNumber(0, math.pi * 2)
		wedge(model, "Break", Vector3.new(R * 2.1, R * 0.9, R * 2.1), CFrame.new(at + Vector3.new(0, standing, 0)) * CFrame.Angles(0, breakAngle, 0), C.stoneDark, M.stone)
		if DETAIL >= 2 then
			floorSockets(model, at, R, standing - 8, 7)
			floorSockets(model, at, R, standing - 34, 7)
		end
		if DETAIL >= 3 then
			rubbleCone(model, at + Vector3.new(0, 0, 0), breakAngle, R * 2.4, 16)
		end
	end

	-- 7. The stair turret, which usually outlives the tower it served.
	if opts.stair then
		stairTurret(model, at, R, standing * (if ruin > 0.45 then 1.15 else 1.06), opts.stair)
	end

	-- 8. A door at the foot, with steps up to it.
	if DETAIL >= 2 then
		local a = opts.doorAngle or math.pi
		local outer = Vector3.new(math.cos(a), 0, math.sin(a))
		local doorPos = at + outer * R + Vector3.new(0, 22, 0)
		block(model, "Doorway", Vector3.new(8, 14, 3.4), CFrame.new(doorPos) * CFrame.Angles(0, -a + math.pi / 2, 0), C.ash, M.stone)
		for i = 0, 5 do
			local aa = math.pi * (i / 5)
			block(model, "Voussoir", Vector3.new(1.6, 2.2, 3.6), CFrame.new(doorPos + Vector3.new(math.cos(aa) * 4 * math.cos(a + math.pi / 2), 7 + math.sin(aa) * 4, math.cos(aa) * 4 * math.sin(a + math.pi / 2))) * CFrame.Angles(0, -a + math.pi / 2, -aa), C.stonePale, M.stone)
		end
		-- NO STEPS UP TO IT. A stair to a tower door is a stair onto the walls,
		-- and a stair onto the walls is a way out of the map. What is left is a
		-- door twenty studs up with its approach collapsed beneath it — which is
		-- both unclimbable and exactly what happens to a stone stair in a ruin.
		for i = 1, 8 do
			local s = rng:NextNumber(3, 8)
			block(model, "CollapsedStair", Vector3.new(s, s * rng:NextNumber(0.35, 0.7), s * rng:NextNumber(0.6, 1.1)), CFrame.new(at + outer * (R + 4 + rng:NextNumber(0, 12)) + Vector3.new(jitter(6), s * 0.3, jitter(6))) * CFrame.Angles(jitter(0.4), rng:NextNumber(0, 6), jitter(0.4)), if chance(0.5) then C.rock else C.stone, M.rock)
		end
	end

	if opts.torch and DETAIL >= 2 then
		local a = opts.doorAngle or math.pi
		torch(model, at + Vector3.new(math.cos(a) * (R + 1), 34, math.sin(a) * (R + 1)), math.deg(-a) + 90, true)
	end

	return model
end

--==========================================================================
-- Curtain wall, with the same seriousness
--==========================================================================
local function curtain(parent, name: string, from: Vector3, to: Vector3, opts)
	opts = opts or {}
	local model = group(parent, name)
	local span = to - from
	local length = span.Magnitude
	if length < 4 then
		return model
	end
	local dir = span.Unit
	local alongX = math.abs(dir.X) > math.abs(dir.Z)
	local inward = opts.inward or Vector3.new(-dir.Z, 0, dir.X)
	local h = opts.height or WALL_H
	local t = opts.thickness or WALL_T
	local mid = (from + to) / 2

	local function sizeFor(len: number, height: number, thick: number): Vector3
		return if alongX then Vector3.new(len, height, thick) else Vector3.new(thick, height, len)
	end

	-- Batter at the foot of the whole run.
	for i = 0, 4 do
		local ti = i / 5
		mass(model, "Batter", sizeFor(length, 3, t + 5 * (1 - ti)), CFrame.new(mid.X, from.Y + 1.5 + i * 3, mid.Z), C.stoneWarm, M.stone)
	end
	mass(model, "Wall", sizeFor(length, h - 15, t), CFrame.new(mid.X, from.Y + 15 + (h - 15) / 2, mid.Z), C.stone, M.stone)

	-- String course, and the wall-walk behind.
	block(model, "StringCourse", sizeFor(length, 2, t + 2.2), CFrame.new(mid.X, from.Y + h * 0.62, mid.Z), C.stoneDark, M.stone)
	local walkCentre = mid + inward * (t / 2 + 5)
	block(model, "Allure", sizeFor(length, 2, 10), CFrame.new(walkCentre.X, from.Y + h - 1, walkCentre.Z), C.stone, M.stone)

	-- Machicolated overhang along the outer face, then the battlements.
	local count = math.max(3, math.floor(length / 16))
	for i = 0, count - 1 do
		local at = from + dir * (length * ((i + 0.5) / count))
		local outer = -inward
		if DETAIL >= 2 then
			for step = 1, 3 do
				block(model, "Corbel", sizeFor(4.4, 1.6, 2.6), CFrame.new(at + outer * (t / 2 + step * 1.1) + Vector3.new(0, from.Y + h - 5 + step * 1.3, 0)), C.stonePale, M.stone)
			end
			block(model, "Machicolation", sizeFor(6.4, 4.4, 4.6), CFrame.new(at + outer * (t / 2 + 3.2) + Vector3.new(0, from.Y + h + 1.4, 0)), C.stoneWarm, M.stone)
			block(model, "Hole", sizeFor(3, 1, 2.6), CFrame.new(at + outer * (t / 2 + 3.4) + Vector3.new(0, from.Y + h - 0.6, 0)), C.ash, M.stone)
		end
		if not chance(opts.ruin or 0) then
			-- Merlons SIT ON the wall head. Centring them any higher leaves a gap
			-- you can see daylight through, and battlements floating four studs
			-- above their own wall is the fastest way to make stonework look fake.
			block(model, "Merlon", sizeFor(8, 9, t), CFrame.new(at.X, from.Y + h + 4.5, at.Z), C.stoneDark, M.stone)
			block(model, "Cap", sizeFor(8.4, 1, t + 0.6), CFrame.new(at.X, from.Y + h + 9.5, at.Z), C.stonePale, M.stone)
		end
	end

	-- Cross loops along the fighting face, and pilaster buttresses outside.
	if DETAIL >= 2 then
		local loops = math.max(2, math.floor(length / 34))
		for i = 0, loops - 1 do
			local at = from + dir * (length * ((i + 0.5) / loops))
			local facing = if alongX then (if inward.Z > 0 then math.pi / 2 else -math.pi / 2) else (if inward.X > 0 then 0 else math.pi)
			crossLoop(model, CFrame.new(at + (-inward) * (t / 2) + Vector3.new(0, from.Y + h * 0.55, 0)) * CFrame.Angles(0, facing, 0), 1)
		end
		local piers = math.max(2, math.floor(length / 60))
		for i = 0, piers do
			local at = from + dir * (length * (i / piers))
			block(model, "Pilaster", sizeFor(9, h * 0.72, t + 7), CFrame.new(at.X + (-inward.X) * 3, from.Y + h * 0.36, at.Z + (-inward.Z) * 3), C.stoneWarm, M.stone)
		end
	end

	-- There is deliberately NO stair to the wall-walk. The allure is visible
	-- through the battlements, which is all it is for; giving it an approach
	-- would hand the player a route onto the outer wall and out of the map.

	if DETAIL >= 2 and opts.torches then
		local n = math.max(1, math.floor(length / 90))
		for i = 0, n - 1 do
			local at = from + dir * (length * ((i + 0.5) / n)) + inward * (t / 2 + 1)
			torch(model, at + Vector3.new(0, from.Y + 30, 0), math.deg(math.atan2(inward.X, inward.Z)), true)
		end
	end

	return model
end

--==========================================================================
-- The gate you came in through, now behind you
--==========================================================================
local function gatehouse(parent, at: Vector3)
	local model = group(parent, "Gatehouse")
	local gh = 34

	tower(model, "GateTowerW", at + Vector3.new(-gh - 20, 0, 0), { radius = 24, height = 118, roof = "cone", stair = math.pi, bartizans = 2, torch = true, banner = true, doorAngle = math.pi / 2 })
	tower(model, "GateTowerE", at + Vector3.new(gh + 20, 0, 0), { radius = 24, height = 112, roof = "cone", stair = 0, bartizans = 2, torch = true, doorAngle = math.pi / 2 })

	-- The passage between them, arched and machicolated over the entry.
	mass(model, "Span", Vector3.new(gh * 2 + 8, 26, WALL_T + 10), CFrame.new(at + Vector3.new(0, 62, 0)), C.stone, M.stone)
	for i = 0, 11 do
		local a = math.pi * (i / 11)
		block(model, "Voussoir", Vector3.new(5, 5.4, WALL_T + 12), CFrame.new(at + Vector3.new(math.cos(a) * gh, 48 + math.sin(a) * gh, 0)) * CFrame.Angles(0, 0, -a), C.stonePale, M.stone)
	end
	if DETAIL >= 2 then
		for i = -3, 3 do
			block(model, "Corbel", Vector3.new(4, 2, 3.4), CFrame.new(at + Vector3.new(i * 11, 72, -(WALL_T / 2 + 3))), C.stonePale, M.stone)
			block(model, "Machicolation", Vector3.new(7, 5, 5), CFrame.new(at + Vector3.new(i * 11, 77, -(WALL_T / 2 + 5))), C.stoneWarm, M.stone)
			block(model, "Hole", Vector3.new(3, 1, 3), CFrame.new(at + Vector3.new(i * 11, 74.6, -(WALL_T / 2 + 5))), C.ash, M.stone)
		end
		-- Sitting on the span's head (which tops out at 75), not hovering above it.
		for i = -4, 4 do
			block(model, "Merlon", Vector3.new(7, 10, WALL_T + 8), CFrame.new(at + Vector3.new(i * 9, 80, 0)), C.stoneDark, M.stone)
		end
		-- The portcullis, jammed part way down. Nobody raised it again.
		for i = 0, math.floor(gh * 2 / 4) do
			block(model, "Bar", Vector3.new(0.8, 30, 0.8), CFrame.new(at + Vector3.new(-gh + i * 4, 34, 3)), C.iron, M.rusted)
		end
		for j = 0, 5 do
			block(model, "Rung", Vector3.new(gh * 2, 0.7, 0.7), CFrame.new(at + Vector3.new(0, 20 + j * 6, 3)), C.iron, M.rusted)
		end
		-- The doors themselves, off their hinges and lying in the passage.
		block(model, "Door", Vector3.new(30, 2.6, 40), CFrame.new(at + Vector3.new(-16, 1.4, -30)) * CFrame.Angles(0, math.rad(14), 0), C.woodDark, M.wood)
		block(model, "Door", Vector3.new(28, 2.6, 38), CFrame.new(at + Vector3.new(20, 1.4, -46)) * CFrame.Angles(0, math.rad(-24), 0), C.woodDark, M.wood)
	end
	return model
end

--==========================================================================
-- LAYOUT — the serpentine
--==========================================================================
-- Anything left by the old road-to-the-castle builder. Its Area5_Castle sat at
-- z = -1900, which is straight through chamber 8 of this layout, and two
-- castles occupying the same stone is not a look.
for _, child in ipairs(root:GetChildren()) do
	if string.match(child.Name, "^Area%d") then
		child:Destroy()
		print("[Battleground] removed leftover " .. child.Name)
	end
end

local ground = folder(root, "Battleground")
for _, child in ipairs(ground:GetChildren()) do
	child:Destroy()
end
local shell = group(ground, "Shell")

local Z_END = Z_START - CHAMBERS * CHAMBER_D

-- The outer skin: four sealed sides. There is no invisible wall anywhere in
-- this map — the castle is the boundary, which is the only boundary a player
-- ever accepts.
curtain(shell, "WestWall", Vector3.new(-HALF_W, 0, Z_START), Vector3.new(-HALF_W, 0, Z_END), { inward = Vector3.new(1, 0, 0), ruin = 0.12, torches = true })
curtain(shell, "EastWall", Vector3.new(HALF_W, 0, Z_START), Vector3.new(HALF_W, 0, Z_END), { inward = Vector3.new(-1, 0, 0), ruin = 0.12, torches = true })
curtain(shell, "BackWall", Vector3.new(-HALF_W, 0, Z_END), Vector3.new(HALF_W, 0, Z_END), { inward = Vector3.new(0, 0, 1), ruin = 0.08 })

-- The front wall, with the gate you arrived through.
curtain(shell, "FrontWallW", Vector3.new(-HALF_W, 0, Z_START), Vector3.new(-54, 0, Z_START), { inward = Vector3.new(0, 0, -1), ruin = 0.1 })
curtain(shell, "FrontWallE", Vector3.new(54, 0, Z_START), Vector3.new(HALF_W, 0, Z_START), { inward = Vector3.new(0, 0, -1), ruin = 0.1 })
gatehouse(shell, Vector3.new(0, 0, Z_START))

-- Corner towers: the biggest, most complete ones, so the corners read as strong.
tower(shell, "CornerNW", Vector3.new(-HALF_W, 0, Z_START), { radius = 27, height = 124, roof = "cone", stair = math.pi * 1.25, bartizans = 3, torch = true, banner = true })
tower(shell, "CornerNE", Vector3.new(HALF_W, 0, Z_START), { radius = 27, height = 118, roof = "cone", stair = math.pi * 1.75, bartizans = 3, torch = true })
tower(shell, "CornerSW", Vector3.new(-HALF_W, 0, Z_END), { radius = 27, height = 110, ruin = 0.5, stair = math.pi * 0.75 })
tower(shell, "CornerSE", Vector3.new(HALF_W, 0, Z_END), { radius = 27, height = 116, roof = "cone", stair = math.pi * 0.25, bartizans = 2 })

--==========================================================================
-- Chambers
--==========================================================================
--[[
	Nine rooms, each with one way on, and the way on alternates sides. The
	player goes forward, crosses right, forward, crosses left — a serpentine
	they cannot get lost in and cannot leave.

	Every chamber also gets the markers the gameplay systems already read, so a
	wave can be pointed at a room without anyone typing a coordinate.
]]
local towerStyles = {
	{ height = 104, roof = "cone", bartizans = 2, banner = true },
	{ height = 92, ruin = 0.35 },
	{ height = 112, roof = "cone", bartizans = 3, torch = true },
	{ height = 86, ruin = 0.6 },
	{ height = 118, roof = "cone", bartizans = 2, torch = true, banner = true },
	{ height = 96, ruin = 0.25 },
	{ height = 108, roof = "cone", bartizans = 3 },
	{ height = 90, ruin = 0.55 },
	{ height = 120, roof = "cone", bartizans = 3, torch = true, banner = true },
}

for index = 1, CHAMBERS do
	local zNear = Z_START - (index - 1) * CHAMBER_D
	local zFar = zNear - CHAMBER_D
	local node = folder(ground, ("Chamber%d"):format(index))
	local structure = group(node, "Structure")

	-- The wall closing this chamber, with its single gap. Odd chambers open on
	-- the east, even on the west.
	local openEast = (index % 2 == 1)
	local gapX = if openEast then HALF_W - GAP_W / 2 - 12 else -HALF_W + GAP_W / 2 + 12
	local gapFrom, gapTo = gapX - GAP_W / 2, gapX + GAP_W / 2

	if index < CHAMBERS then
		curtain(structure, "CrossWallA", Vector3.new(-HALF_W, 0, zFar), Vector3.new(gapFrom, 0, zFar), { inward = Vector3.new(0, 0, 1), ruin = 0.18, height = 48 })
		curtain(structure, "CrossWallB", Vector3.new(gapTo, 0, zFar), Vector3.new(HALF_W, 0, zFar), { inward = Vector3.new(0, 0, 1), ruin = 0.18, height = 48 })

		-- The gap is an arched, defended doorway rather than a hole.
		local gate = group(structure, "Passage")
		for i = 0, 9 do
			local a = math.pi * (i / 9)
			block(gate, "Voussoir", Vector3.new(4, 4.4, WALL_T + 8), CFrame.new(gapX + math.cos(a) * (GAP_W / 2), 26 + math.sin(a) * (GAP_W / 2), zFar) * CFrame.Angles(0, 0, -a), C.stonePale, M.stone)
		end
		mass(gate, "Span", Vector3.new(GAP_W + 18, 14, WALL_T + 4), CFrame.new(gapX, 55, zFar), C.stone, M.stone)
		if DETAIL >= 2 then
			for i = -2, 2 do
				block(gate, "Merlon", Vector3.new(7, 9, WALL_T + 4), CFrame.new(gapX + i * 10, 66, zFar), C.stoneDark, M.stone)
			end
			for i = 0, math.floor(GAP_W / 4) do
				block(gate, "Bar", Vector3.new(0.7, 16, 0.7), CFrame.new(gapFrom + i * 4, 44, zFar + 2.5), C.iron, M.rusted)
			end
			torch(gate, Vector3.new(gapX - GAP_W / 2 - 3, 24, zFar + 2), 0, true)
			torch(gate, Vector3.new(gapX + GAP_W / 2 + 3, 24, zFar + 2), 0, true)
		end

		-- Flanking towers on the passage: this is the strong point of the room.
		tower(structure, "PassageTowerA", Vector3.new(gapFrom - 22, 0, zFar), { radius = 18, height = 78, roof = "cone", stair = math.pi * 0.5, torch = true, doorAngle = math.pi / 2 })
		tower(structure, "PassageTowerB", Vector3.new(gapTo + 22, 0, zFar), { radius = 18, height = 72, ruin = 0.3, doorAngle = math.pi / 2 })
	end

	-- Wall towers along the sides, alternating so the two flanks never match.
	local style = towerStyles[index]
	tower(structure, "SideTowerW", Vector3.new(-HALF_W, 0, zNear - CHAMBER_D / 2), {
		radius = 22,
		height = style.height,
		ruin = style.ruin,
		roof = style.roof,
		bartizans = style.bartizans,
		torch = style.torch,
		banner = style.banner,
		stair = 0,
		doorAngle = 0,
	})
	tower(structure, "SideTowerE", Vector3.new(HALF_W, 0, zNear - CHAMBER_D / 2), {
		radius = 22,
		height = style.height - 8,
		ruin = if style.ruin then style.ruin * 0.7 else nil,
		roof = style.roof,
		bartizans = style.bartizans,
		stair = math.pi,
		doorAngle = math.pi,
	})

	--------------------------------------------------------------------------
	-- Gameplay markers
	--------------------------------------------------------------------------
	local spawns = folder(node, "Spawns")
	local objectives = folder(node, "Objectives")

	local function marker(parent, name, at, colour, size)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Material = M.neon
		part.Color = colour
		part.Transparency = 0.6
		part.Size = size or Vector3.new(4, 4, 4)
		part.Position = at
		part.Parent = parent
		made += 1
		return part
	end

	local midZ = zNear - CHAMBER_D / 2
	marker(spawns, "North", Vector3.new(0, 4, zFar + 30), Color3.fromRGB(178, 54, 54))
	marker(spawns, "East", Vector3.new(HALF_W - 40, 4, midZ), Color3.fromRGB(178, 54, 54))
	marker(spawns, "West", Vector3.new(-HALF_W + 40, 4, midZ), Color3.fromRGB(178, 54, 54))
	marker(objectives, "Centre", Vector3.new(0, 4, midZ), Color3.fromRGB(198, 158, 66))
	marker(node, "Checkpoint", Vector3.new(0, 3, zNear - 26), Color3.fromRGB(74, 132, 84), Vector3.new(8, 1, 8))
	marker(node, "Storyteller", Vector3.new(if openEast then -60 else 60, 4, zNear - 40), Color3.fromRGB(120, 90, 200))

	print(("[Battleground] chamber %d  z %d..%d  passage on the %s"):format(index, zNear, zFar, if openEast then "east" else "west"))
end

--==========================================================================
-- Spawn: in front of the gate, and already inside
--==========================================================================
local spawnZ = Z_START - 55
local pad = group(ground, "SpawnPad")
mass(pad, "Pad", Vector3.new(70, 2, 50), CFrame.new(0, 1, spawnZ), C.stonePale, M.cobble)
if DETAIL >= 2 then
	-- A shallow lip rather than steps. Nothing in this map is called a step, so
	-- that "remove every stair" stays a rule with no exceptions to remember.
	block(pad, "Lip", Vector3.new(70, 1.4, 26), CFrame.new(0, 0.7, spawnZ - 34), C.stonePale, M.stone)
	torch(pad, Vector3.new(-32, 4, spawnZ), 0, true)
	torch(pad, Vector3.new(32, 4, spawnZ), 0, true)
end

local existing = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
if existing then
	existing:Destroy()
end
local spawn = Instance.new("SpawnLocation")
spawn.Name = "ArrivalSpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(24, 1, 24)
spawn.Position = Vector3.new(0, 2.5, spawnZ)
spawn.Transparency = 1
spawn.CanCollide = false
spawn.Neutral = true
spawn.Parent = pad
made += 1

--==========================================================================
-- Ground
--==========================================================================
if BUILD_TERRAIN then
	-- Solid, edge to edge, with a wide apron outside the walls so the horizon is
	-- never the end of the world. No gaps anywhere: there is nothing to fall
	-- through and nowhere to slip out.
	-- 800 studs of ground beyond the walls on every side: room to breathe, room
	-- for whatever comes after this map, and no visible edge from anywhere inside.
	local pad2 = 800
	local tile = 100
	for x = -HALF_W - pad2, HALF_W + pad2 - tile, tile do
		for z = Z_END - pad2, Z_START + pad2 - tile, tile do
			workspace.Terrain:FillBlock(CFrame.new(x + tile / 2, -10, z + tile / 2), Vector3.new(tile, 20, tile), Enum.Material.Ground)
		end
		task.wait()
	end
	workspace.Terrain:SetMaterialColor(Enum.Material.Ground, C.ground)
	print("[Battleground] ground filled, no gaps")
end

--==========================================================================
-- Light
--==========================================================================
if BUILD_LIGHTING then
	local Lighting = game:GetService("Lighting")

	-- Held at late sunset. Not night — you must be able to read the ground you
	-- are fighting on — and not day, because nothing in here should feel safe.
	Lighting.ClockTime = 17.6
	Lighting.GeographicLatitude = 12
	Lighting.Brightness = 1.1
	Lighting.ExposureCompensation = -0.15
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.35
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(28, 26, 34)
	Lighting.OutdoorAmbient = Color3.fromRGB(74, 66, 74)
	Lighting.ColorShift_Top = Color3.fromRGB(126, 82, 52)
	Lighting.ColorShift_Bottom = Color3.fromRGB(28, 24, 32)
	Lighting.FogEnd = 100000 -- legacy fog off; Atmosphere does this properly

	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.Parent = Lighting
	-- No sun, no moon. A visible disc gives the player a direction and a time of
	-- day, and this place should have neither.
	sky.SunTextureId = ""
	sky.MoonTextureId = ""
	sky.SunAngularSize = 0
	sky.MoonAngularSize = 0
	sky.StarCount = 0
	sky.CelestialBodiesShown = false

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
	atmosphere.Density = 0.42 -- the haze that closes the horizon
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(168, 148, 132)
	atmosphere.Decay = Color3.fromRGB(88, 72, 74)
	atmosphere.Glare = 0.15
	atmosphere.Haze = 2.8

	local grade = Lighting:FindFirstChild("WorldGrade")
	if not grade then
		grade = Instance.new("ColorCorrectionEffect")
		grade.Name = "WorldGrade"
		grade.Parent = Lighting
	end
	grade.Brightness = -0.02
	grade.Contrast = 0.12
	grade.Saturation = -0.22 -- drained, not grey: some colour has to survive
	grade.TintColor = Color3.fromRGB(255, 238, 224)

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Parent = Lighting
	bloom.Intensity = 0.5
	bloom.Size = 20
	bloom.Threshold = 1.1

	print("[Battleground] lighting: permanent sunset, no sun disc, heavy haze")
	print("[Battleground] REMINDER — set Lighting.Technology to Future BY HAND; a script cannot.")
end

pcall(function()
	(shell :: any).ModelStreamingMode = Enum.ModelStreamingMode.Persistent
end)

--==========================================================================
print(("[Battleground] DONE — %d parts, %d lights, detail %d"):format(made, lightsUsed, DETAIL))
print(("Enclosure %d x %d studs, %d chambers of %d."):format(HALF_W * 2, CHAMBERS * CHAMBER_D, CHAMBERS, CHAMBER_D))
print(("Spawn at (0, %d) — inside the gate, facing down the map."):format(spawnZ))
print("Chambers are EMPTY on purpose. Your houses go in them; the walls and towers are done.")
print("If it costs frames, set DETAIL = 2 at the top and run again.")
