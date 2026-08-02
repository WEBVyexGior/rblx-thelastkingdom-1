--[[
	BuildEndTower — run in the Studio Command Bar of the FORGOTTEN LANDS place,
	in EDIT MODE. Select the whole file (Ctrl+A), copy, paste, Enter.

	Builds the LIBRARY TOWER: the last thing in the map, standing free on the
	west side of chamber 9, and the place the story actually ends.

	The shape of it:

	  ground        the door, with an arrow worn into the flagstones outside it
	  y 24          an empty floor — a landing, so the climb has a middle
	  y 48          THE LIBRARY. Shelves, books, a desk, and the man who wrote
	                the letter, still sitting at it.
	  above         sealed. Corbels, machicolations and a parapet, all exterior.

	Makes:
	  Gameplay.Battleground.EndTower

	--------------------------------------------------------------------------
	TWO RULES THIS BUILD IS BOUND BY
	--------------------------------------------------------------------------

	NO ROUTE ONTO THE WALLS. The curtain wall is 62 high and this tower is
	taller than that. A climbable floor above 62, or any opening on the wall
	side, hands the player the exact escape route we spent a pass removing. So:

	  - the stair STOPS at the library, at 48
	  - the library ceiling at 64 is solid, and nothing goes above it
	  - every opening faces INTO the chamber or along it, never west
	  - the parapet is scenery seen from the ground, not a place to stand

	NOTHING ON THE PATH. The tower is 27 in radius and lands in a chamber that
	BuildChambers has already decorated, so it clears the decorations it covers
	and refuses to build if it would sit on the road.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

--==========================================================================
-- Measured from the world, not guessed — these match BuildBattleground
--==========================================================================
local GROUND = 2
local WALL_H = 62 -- curtain wall head; nothing climbable may reach it
local LAST = 9 -- the chamber this stands in

--[[
	WHERE IT STANDS. Free of everything, and every number here is forced.

	Chamber 9 runs z -1598 to -1758. Three things are already in it:

	  SideTowerW   (-150, -1680), radius 22 — a wall tower, and the first
	               version of this build was embedded 14 studs into it
	  the road     in from the chamber-8 passage at (-115, -1592), diagonally
	               across to (0, -1690), then south to (0, -1750)
	  the walls    west face at x -143

	That diagonal takes the whole north-west quarter, so the only clear ground
	on the west side is SOUTH of it and PAST the wall tower. Here:

	  to the road         ~75    (needs 40)
	  to SideTowerW       ~81    (needs 49)
	  to the west wall     36    free-standing, touching nothing

	Standing clear rather than built into the curtain also drops the reason the
	first version fought with the wall tower at all.
]]
local TOWER_X = -80
local TOWER_Z = -1720

local R_SHAFT = 27 -- outer radius of the shaft
local R_BASE = 34 -- outer radius at the foot of the batter
local WALL_THICK = 6
local R_IN = R_SHAFT - WALL_THICK -- 21, the inside face

local Y_BATTER = GROUND + 15 -- where the splay stops
local Y_FLOOR = { GROUND, GROUND + 22, GROUND + 46 } -- entrance, landing, library
local Y_CEIL = GROUND + 62 -- library ceiling. Solid. Equal to the wall head.
local Y_CORBEL = GROUND + 66
local Y_PARAPET = GROUND + 74
local Y_TOP = GROUND + 86

local SEGMENTS = 22 -- blocks per course; the shaft is a polygon, densely enough

--[[
	THE STAIR WELL. Module scope on purpose: the interior builds the stair in it
	and the library has to keep its furniture OUT of it, and a second copy of
	these numbers would eventually put a bookcase in mid-air over a stairwell.
]]
local WELL_A = 2.5 -- across the room from the door, so you cross the floor
local WELL_DIST = 11 -- how far the well's axis sits from the tower's
local WELL_R = 9 -- inside face of the well
local HOLE_R = WELL_R + 2.5 -- what the floors cut: always wider than the well
local NEWEL_R = 2

local WELL_X = TOWER_X + math.cos(WELL_A) * WELL_DIST
local WELL_Z = TOWER_Z + math.sin(WELL_A) * WELL_DIST

-- Distance from the well's axis. Every clearance test in this file wants it.
local function fromWell(px: number, pz: number): number
	return Vector3.new(px - WELL_X, 0, pz - WELL_Z).Magnitude
end

local rng = Random.new(20260802)

--==========================================================================
local C = {
	stone = Color3.fromRGB(84, 82, 79),
	stoneDark = Color3.fromRGB(60, 59, 60),
	stonePale = Color3.fromRGB(112, 108, 100),
	stoneWarm = Color3.fromRGB(98, 92, 82),
	rock = Color3.fromRGB(86, 80, 73),
	wood = Color3.fromRGB(66, 49, 34),
	woodDark = Color3.fromRGB(44, 32, 22),
	woodPale = Color3.fromRGB(92, 72, 50),
	iron = Color3.fromRGB(56, 48, 44),
	rust = Color3.fromRGB(92, 54, 34),
	ash = Color3.fromRGB(36, 34, 34),
	bone = Color3.fromRGB(186, 178, 158),
	paper = Color3.fromRGB(196, 182, 148),
	wax = Color3.fromRGB(206, 198, 170),
	chalk = Color3.fromRGB(148, 140, 126),
}

--[[
	Book covers. Leather in the colours leather actually took — the reds and
	greens are dye, the browns and blacks are what dye faded into. A few pale
	ones are vellum, unbound, which is what breaks up a shelf.
]]
local COVERS = {
	Color3.fromRGB(74, 34, 30),
	Color3.fromRGB(96, 44, 36),
	Color3.fromRGB(58, 40, 26),
	Color3.fromRGB(44, 32, 22),
	Color3.fromRGB(38, 48, 36),
	Color3.fromRGB(50, 62, 44),
	Color3.fromRGB(34, 40, 56),
	Color3.fromRGB(28, 28, 30),
	Color3.fromRGB(92, 74, 40),
	Color3.fromRGB(112, 96, 62),
	Color3.fromRGB(150, 140, 116),
	Color3.fromRGB(168, 158, 132),
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
	fabric = Enum.Material.Fabric,
	sand = Enum.Material.Sand,
	paper = Enum.Material.Sand,
}

--==========================================================================
-- Foundations
--==========================================================================
local gameplay = workspace:FindFirstChild("Gameplay")
local battleground = gameplay and gameplay:FindFirstChild("Battleground")
if not battleground then
	warn("[EndTower] no Gameplay.Battleground — build the battleground first.")
	return
end

local made = 0

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function jitter(a: number): number
	return rng:NextNumber(-a, a)
end

local function chance(p: number): boolean
	return rng:NextNumber() < p
end

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

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

-- Only the masonry casts shadows. Books and bones would cost a great deal of
-- frame time for shadows nobody will ever pick out.
local function mass(parent, name, size, cf, colour, material): Part
	return block(parent, name, size, cf, colour, material, true)
end

local function drum(parent, name, radius, height, at: Vector3, colour, material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.Size = Vector3.new(height, radius * 2, radius * 2)
	part.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	part.Color = colour or C.stone
	part.Material = material or M.stone
	part.CastShadow = false
	part.Parent = parent
	made += 1
	return part
end

local function bar(parent, name, radius, from: Vector3, to: Vector3, colour, material): Part
	local span = to - from
	if span.Magnitude < 0.05 then
		return block(parent, name, Vector3.new(radius, radius, radius), CFrame.new(from), colour, material)
	end
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

--==========================================================================
-- Round-tower helpers
--==========================================================================
local function at(angle: number, radius: number, y: number): Vector3
	return Vector3.new(TOWER_X + math.cos(angle) * radius, y, TOWER_Z + math.sin(angle) * radius)
end

--[[
	A block sitting on the circle at `angle`, turned so its width runs along the
	tangent and its depth points out through the wall.

	Solving it once here is worth it: local X maps to (cos θ, 0, -sin θ), and we
	want that to be the tangent (-sin a, 0, cos a), which gives θ = -(a + π/2).
	Every ring, corbel, merlon and shelf in this file leans on that.
]]
local function facing(angle: number): CFrame
	return CFrame.Angles(0, -(angle + math.pi / 2), 0)
end

--[[
	One course of masonry around the tower.

	`skip(angle, index)` returns true to leave a block out, which is how every
	opening in this build is made — a door is a hole in three courses, not a
	part laid over the wall.
]]
local function ring(parent, name, y: number, radius: number, height: number, thickness: number, colour, material, skip)
	local arc = (2 * math.pi * radius) / SEGMENTS
	for i = 0, SEGMENTS - 1 do
		local a = (i / SEGMENTS) * math.pi * 2
		if not (skip and skip(a, i)) then
			mass(parent, name, Vector3.new(arc + 0.8, height, thickness), CFrame.new(at(a, radius, y)) * facing(a), colour, material)
		end
	end
end

-- Is `angle` inside the arc centred on `centre` and `width` wide? Angles wrap,
-- so this is done on the difference rather than by comparing raw values.
local function within(angle: number, centre: number, width: number): boolean
	local diff = math.abs((angle - centre + math.pi) % (2 * math.pi) - math.pi)
	return diff < width / 2
end

--==========================================================================
-- SAFETY: refuse to build on the road, and clear what we land on
--==========================================================================
local FOOTPRINT = R_BASE + 6

do
	local path = battleground:FindFirstChild("Path")
	if path then
		for _, part in ipairs(path:GetDescendants()) do
			if part:IsA("BasePart") then
				local flat = Vector3.new(part.Position.X - TOWER_X, 0, part.Position.Z - TOWER_Z)
				if flat.Magnitude < FOOTPRINT then
					warn(("[EndTower] ABORTED: the road runs through the tower footprint at %d, %d."):format(part.Position.X, part.Position.Z))
					warn("[EndTower] Move TOWER_X / TOWER_Z, or re-run BuildChambers after this tool so the road is drawn around it.")
					return
				end
			end
		end
	end

	--[[
		And the CASTLE.

		Measuring a tower by its Model bounding box does NOT work, and the first
		attempt at this check proved it: SideTowerW measured 88 and is 22. The
		box includes the rubble cone spalled off its foot and the merlons that
		fell around it, which spread more than twice as far as the shaft does. A
		check built on that rejects every position in the chamber.

		So measure AT HEIGHT. Above the rubble line only the shaft is left, and
		the horizontal extent of what is up there is the thing a neighbour has
		to clear. Curtain walls are skipped either way: a wall's box spans the
		whole chamber and is not a footprint.
	]]
	local RUBBLE_LINE = 30 -- above the batter, the rubble and the fallen stones

	local function shaftFootprint(node: Model): (number?, number?, number?)
		local minX, maxX, minZ, maxZ
		for _, part in ipairs(node:GetDescendants()) do
			if part:IsA("BasePart") and part.Position.Y >= RUBBLE_LINE then
				local hx, hz = part.Size.X / 2, part.Size.Z / 2
				local lo, hi = part.Position.X - hx, part.Position.X + hx
				local zlo, zhi = part.Position.Z - hz, part.Position.Z + hz
				minX = if minX then math.min(minX, lo) else lo
				maxX = if maxX then math.max(maxX, hi) else hi
				minZ = if minZ then math.min(minZ, zlo) else zlo
				maxZ = if maxZ then math.max(maxZ, zhi) else zhi
			end
		end
		if not minX then
			return nil, nil, nil
		end
		return (minX + maxX) / 2, (minZ + maxZ) / 2, math.max(maxX - minX, maxZ - minZ) / 2
	end

	local chamber = battleground:FindFirstChild(("Chamber%d"):format(LAST))
	local structure = chamber and chamber:FindFirstChild("Structure")
	if structure then
		for _, node in ipairs(structure:GetChildren()) do
			if node:IsA("Model") and node.Name:find("Tower") then
				local cx, cz, reach = shaftFootprint(node)
				if cx and cz and reach then
					local gap = Vector3.new(cx - TOWER_X, 0, cz - TOWER_Z).Magnitude
					if gap < reach + R_BASE then
						warn(("[EndTower] ABORTED: %s stands at %d, %d with a shaft radius of %d — this needs %d clear and has %d."):format(node.Name, cx, cz, reach, reach + R_BASE, gap))
						warn("[EndTower] Move TOWER_X / TOWER_Z. Run tools/SurveyEndZone.luau to see what is where.")
						return
					end
				end
			end
		end
	end

	-- Decorations are ours to move; the road is not.
	local decorations = battleground:FindFirstChild("Decorations")
	local area = decorations and decorations:FindFirstChild(("Area%d"):format(LAST))
	local cleared = 0
	if area then
		for _, child in ipairs(area:GetChildren()) do
			local pivot: Vector3?
			if child:IsA("Model") then
				pivot = child:GetPivot().Position
			elseif child:IsA("BasePart") then
				pivot = child.Position
			elseif child:IsA("Folder") then
				local first = child:FindFirstChildWhichIsA("BasePart", true)
				pivot = first and first.Position
			end
			if pivot then
				local flat = Vector3.new(pivot.X - TOWER_X, 0, pivot.Z - TOWER_Z)
				if flat.Magnitude < FOOTPRINT then
					child:Destroy()
					cleared += 1
				end
			end
		end
	end
	if cleared > 0 then
		print(("[EndTower] cleared %d decorations from the footprint."):format(cleared))
	end
end

local old = battleground:FindFirstChild("EndTower")
if old then
	old:Destroy()
end
local root = folder(battleground, "EndTower")

--==========================================================================
-- WHERE THE OPENINGS GO
--==========================================================================
--[[
	The door faces EAST, into the chamber, because that is the side the player
	arrives from and the only side there is anything to arrive from.

	Nothing is ever cut on the west (π) side. That is the curtain wall, and an
	opening there is a hole into the one place the map must stay sealed.
]]
local DOOR_A = 0 -- east, into the chamber
local DOOR_W = 0.42 -- arc width in radians
local WEST = math.pi

--[[
	Where the library's lancets go. Declared ONCE, up here, because two places
	need them and they have to agree: the openings section cuts them, and the
	library section has to leave those bays clear of shelving. Two copies of this
	list would eventually drift and put a bookcase across a window.
]]
local WINDOW_ANGLES = { -1.9, -0.62, 0, 0.62, 1.9 }

--==========================================================================
-- 1. THE FOOT — batter, plinth roll
--==========================================================================
do
	local m = model(root, "Foot")

	-- The batter: a splayed, sloping thickening. It is the single most
	-- recognisable feature of a real tower and the thing most often missing.
	local steps = 7
	for i = 0, steps - 1 do
		local t = i / steps
		local y = GROUND + (Y_BATTER - GROUND) * t
		local radius = R_BASE + (R_SHAFT - R_BASE) * t
		ring(m, "Batter", y + (Y_BATTER - GROUND) / (steps * 2), radius, (Y_BATTER - GROUND) / steps + 0.4, WALL_THICK + 4 * (1 - t), C.stoneWarm, M.stone, function(a)
			-- The doorway is cut through the batter too, or the door opens into
			-- a slope.
			return within(a, DOOR_A, DOOR_W) and t > 0.15
		end)
	end

	-- Plinth roll: a rounded band where the batter meets the shaft, to shed the
	-- water the slope has been gathering.
	for i = 0, SEGMENTS - 1 do
		local a = (i / SEGMENTS) * math.pi * 2
		if not within(a, DOOR_A, DOOR_W) then
			bar(m, "PlinthRoll", 1.5, at(a - 0.16, R_SHAFT + 1, Y_BATTER), at(a + 0.16, R_SHAFT + 1, Y_BATTER), C.stonePale, M.stone)
		end
	end

	-- Rubble that has spalled off the foot over forty winters.
	for _ = 1, 26 do
		local a = rng:NextNumber(0, math.pi * 2)
		local dist = R_BASE + rng:NextNumber(1, 14)
		local s = rng:NextNumber(1.6, 5)
		block(
			m,
			"Rubble",
			Vector3.new(s, s * rng:NextNumber(0.4, 0.8), s * rng:NextNumber(0.6, 1.2)),
			CFrame.new(at(a, dist, GROUND + s / 3)) * CFrame.Angles(jitter(0.4), rng:NextNumber(0, 6), jitter(0.4)),
			if chance(0.5) then C.rock else C.stone,
			M.rock
		)
	end
end

--==========================================================================
-- 2. THE SHAFT — courses, string courses, putlog holes
--==========================================================================
do
	local m = model(root, "Shaft")

	local COURSE = 4.2
	local y = Y_BATTER
	local courseIndex = 0

	-- Up to the corbel table, NOT to the ceiling. The ceiling at 64 is where the
	-- inside stops; the masonry has to carry on past it to the crown, or the
	-- tower has a four-stud gap of nothing under its machicolations.
	while y < Y_CORBEL do
		local h = math.min(COURSE, Y_CORBEL - y)
		ring(m, "Course", y + h / 2, R_SHAFT, h + 0.3, WALL_THICK, if courseIndex % 2 == 0 then C.stone else C.stoneWarm, M.stone, function(a)
			-- The doorway, up to its head.
			if within(a, DOOR_A, DOOR_W) and y < GROUND + 16 then
				return true
			end
			return false
		end)
		y += COURSE
		courseIndex += 1
	end

	-- String courses mark the floors inside. Without them a tower is a pipe.
	for _, floorY in ipairs({ Y_FLOOR[2], Y_FLOOR[3] }) do
		ring(m, "StringCourse", floorY - 1, R_SHAFT + 1.2, 1.6, WALL_THICK + 3, C.stoneDark, M.stone)
	end

	--[[
		Putlog holes: where the scaffolding poles sat while it was built, in a
		rising spiral because that is how the scaffold went up. Nobody ever
		filled them in. Free authenticity, twelve parts.
	]]
	for i = 0, 15 do
		local a = (i * 0.9) % (math.pi * 2)
		local y2 = Y_BATTER + 5 + i * 3.2
		if y2 < Y_CEIL - 4 and not within(a, WEST, 0.7) then
			block(m, "Putlog", Vector3.new(2, 2, WALL_THICK + 1), CFrame.new(at(a, R_SHAFT, y2)) * facing(a), C.ash, M.stone)
		end
	end

	-- Iron anchor plates: the tie rods holding the floors in. Tiny, and they
	-- read as engineering rather than decoration.
	for _, floorY in ipairs({ Y_FLOOR[2], Y_FLOOR[3] }) do
		for i = 0, 5 do
			local a = (i / 6) * math.pi * 2 + 0.3
			if not within(a, WEST, 0.6) then
				block(m, "AnchorV", Vector3.new(0.8, 4, 1.4), CFrame.new(at(a, R_SHAFT + 0.6, floorY + 3)) * facing(a), C.rust, M.rusted)
				block(m, "AnchorH", Vector3.new(4, 0.8, 1.4), CFrame.new(at(a, R_SHAFT + 0.6, floorY + 3)) * facing(a), C.rust, M.rusted)
			end
		end
	end
end

--==========================================================================
-- 3. THE DOOR, and the arrow worn into the ground outside it
--==========================================================================
do
	local m = model(root, "Entrance")
	local doorH = 14
	local doorW = 11

	-- Dressed surround: jambs, a segmental arch, a worn threshold.
	for side = -1, 1, 2 do
		local a = DOOR_A + side * (DOOR_W / 2)
		mass(m, "Jamb", Vector3.new(3, doorH + 2, WALL_THICK + 2), CFrame.new(at(a, R_SHAFT, GROUND + doorH / 2)) * facing(a), C.stonePale, M.stone)
	end

	--[[
		Segmental arch. R = (s²/4 + r²) / 2r, the same solve as the houses.

		The door faces east, so the arch stands in the Y–Z plane: each voussoir
		is thick through world X, deep along the radius, and narrow across it.
		Rotating about X by the voussoir's own angle is what leans it into the
		curve — Rx(φ) takes (0,1,0) to (0, cos φ, sin φ), which is exactly the
		radial direction at φ.
	]]
	local span, arcRise = doorW + 3, 3.4
	local radius = (span * span / 4 + arcRise * arcRise) / (2 * arcRise)
	local halfSweep = math.asin((span / 2) / radius)
	local centreY = GROUND + doorH + arcRise - radius
	for i = 0, 8 do
		local ang = -halfSweep + (2 * halfSweep) * (i / 8)
		block(
			m,
			"Voussoir",
			Vector3.new(WALL_THICK + 2, 3.2, 2.8),
			CFrame.new(TOWER_X + R_SHAFT - 1, centreY + math.cos(ang) * radius, TOWER_Z + math.sin(ang) * radius) * CFrame.Angles(ang, 0, 0),
			C.stonePale,
			M.stone
		)
	end
	-- Keystone, and the hood over the whole opening.
	block(m, "Keystone", Vector3.new(WALL_THICK + 3, 4.4, 3.4), CFrame.new(TOWER_X + R_SHAFT - 1, GROUND + doorH + arcRise + 1, TOWER_Z), C.stoneDark, M.stone)
	block(m, "Hood", Vector3.new(2, 1.6, span + 6), CFrame.new(TOWER_X + R_SHAFT + 1.5, GROUND + doorH + arcRise + 3, TOWER_Z), C.stoneDark, M.stone)

	block(m, "Threshold", Vector3.new(6, 1, doorW + 3), CFrame.new(TOWER_X + R_SHAFT - 2, GROUND + 0.5, TOWER_Z), C.stonePale, M.stone)

	-- The door itself, long since off its hinges and lying in the doorway.
	local leaf = CFrame.new(TOWER_X + R_SHAFT + 4, GROUND + 0.6, TOWER_Z + 3) * CFrame.Angles(0, math.rad(14), math.rad(90))
	for i = 0, 5 do
		block(m, "Board", Vector3.new(doorW / 6, doorH - 1, 0.9), leaf * CFrame.new(-doorW / 2 + (i + 0.5) * (doorW / 6), 0, 0), C.woodDark, M.wood)
	end
	for _, off in { -4, 4 } do
		block(m, "Strap", Vector3.new(doorW * 0.8, 1.3, 1.1), leaf * CFrame.new(-doorW * 0.06, off, 0.7), C.iron, M.rusted)
	end

	--[[
		THE ARROW.

		It has to read as made by a person in a hurry, not printed by a level
		designer — so it is scratched through the grime rather than painted on,
		three strokes and a head, with the strokes slightly out of line.

		It points at the door and sits just clear of the threshold, where a
		player walking the road will cross it.
	]]
	local arrow = model(root, "Arrow")
	local ax = TOWER_X + R_SHAFT + 26
	local function scratch(name, size, offset, angle)
		block(
			arrow,
			name,
			size,
			CFrame.new(ax + offset.X, GROUND + 0.12, TOWER_Z + offset.Z) * CFrame.Angles(0, math.rad(angle), 0),
			C.chalk,
			M.sand
		)
	end
	-- Shaft of the arrow, in three broken strokes.
	scratch("Stroke", Vector3.new(11, 0.25, 2.4), Vector3.new(1, 0, 0), jitter(2))
	scratch("Stroke", Vector3.new(8, 0.25, 2.2), Vector3.new(-9.5, 0, 0.5), jitter(3))
	scratch("Stroke", Vector3.new(5, 0.25, 2), Vector3.new(-16, 0, -0.4), jitter(3))
	-- Head: two strokes back from the tip, pointing at the door.
	scratch("Head", Vector3.new(9, 0.25, 2.4), Vector3.new(9.5, 0, 4), -34)
	scratch("Head", Vector3.new(9, 0.25, 2.4), Vector3.new(9.5, 0, -4), 34)

	-- A handprint or two on the jamb, at the height a hand goes.
	for _ = 1, 3 do
		block(
			arrow,
			"Smear",
			Vector3.new(0.3, rng:NextNumber(2, 4), rng:NextNumber(1.5, 3)),
			CFrame.new(TOWER_X + R_SHAFT + 1.2, GROUND + rng:NextNumber(6, 10), TOWER_Z + jitter(6)),
			C.ash,
			M.sand
		)
	end
end

--==========================================================================
-- 4. OPENINGS UP THE SHAFT — cross loops and lancets
--==========================================================================
do
	local m = model(root, "Openings")

	--[[
		A cross loop: an arrow slit with a cross bar, splayed wide on the inside
		so an archer can swing and narrow outside so nobody can hit him.

		Narrow is also the point structurally: none of these is wide enough to
		climb through, which is why they are allowed above the door.
	]]
	local function crossLoop(a: number, y: number)
		if within(a, WEST, 0.8) then
			return -- never on the wall side
		end
		local cf = CFrame.new(at(a, R_SHAFT, y)) * facing(a)
		block(m, "Slit", Vector3.new(1.6, 9, WALL_THICK + 1), cf, C.ash, M.stone)
		block(m, "SlitBar", Vector3.new(6, 1.6, WALL_THICK + 1), cf * CFrame.new(0, 2, 0), C.ash, M.stone)
		-- The splayed embrasure behind it, opening inward.
		block(m, "Embrasure", Vector3.new(7, 12, 2), cf * CFrame.new(0, 0, WALL_THICK / 2 + 1), C.ash, M.stone)
		-- Dressed surround outside.
		for side = -1, 1, 2 do
			block(m, "LoopJamb", Vector3.new(1.4, 11, 2), cf * CFrame.new(side * 1.8, 0, -1), C.stonePale, M.stone)
		end
		block(m, "LoopSill", Vector3.new(5.4, 1.2, 2.4), cf * CFrame.new(0, -5.6, -1), C.stonePale, M.stone)
	end

	for i = 0, 4 do
		crossLoop(0.55 + i * 1.25, GROUND + 20)
	end
	for i = 0, 4 do
		crossLoop(1.05 + i * 1.25, GROUND + 34)
	end

	--[[
		The library windows. Lancets — tall, narrow, arch-headed — because a
		scriptorium needed light and this is the one floor that was lived in.

		East and along the chamber only. Never west.
	]]
	local function lancet(a: number, y: number)
		local cf = CFrame.new(at(a, R_SHAFT, y)) * facing(a)
		block(m, "Light", Vector3.new(4.4, 12, WALL_THICK + 1), cf, C.ash, M.stone)
		for side = -1, 1, 2 do
			block(m, "Jamb", Vector3.new(1.4, 13, WALL_THICK + 2), cf * CFrame.new(side * 2.9, 0, 0), C.stonePale, M.stone)
		end
		-- Arched head.
		for i = 0, 5 do
			local ang = math.pi * (i / 5)
			block(m, "Voussoir", Vector3.new(1.4, 1.8, WALL_THICK + 2), cf * CFrame.new(math.cos(ang) * 2.9, 6 + math.sin(ang) * 2.9, 0) * CFrame.Angles(0, 0, -ang), C.stonePale, M.stone)
		end
		block(m, "Sill", Vector3.new(8, 1.4, WALL_THICK + 4), cf * CFrame.new(0, -6.7, -1), C.stonePale, M.stone)
		block(m, "Hood", Vector3.new(10, 1.2, 2), cf * CFrame.new(0, 10.6, -2), C.stoneDark, M.stone)
		-- The stone mullion, and the iron that held the glass.
		block(m, "Mullion", Vector3.new(1.1, 12, WALL_THICK), cf, C.stonePale, M.stone)
		for i = -2, 2 do
			block(m, "Ferramenta", Vector3.new(4.2, 0.3, 0.4), cf * CFrame.new(0, i * 2.6, -2.6), C.rust, M.rusted)
		end
	end

	local libraryY = Y_FLOOR[3] + 9
	for _, a in ipairs(WINDOW_ANGLES) do
		lancet(a, libraryY)
	end
end

--==========================================================================
-- 5. INSIDE — floors, and the stair that stops at the library
--==========================================================================
do
	local m = model(root, "Interior")

	--[[
		THE STAIR.

		The first version wound around the CENTRE of the tower with treads
		running from the newel all the way out to the wall — which means the
		stair occupied the entire floor plan at every height, and the floors were
		then built straight through it. Climbing, you walked into the joists
		spanning the diameter. That is the wood that stopped you.

		A vice belongs in its own WELL: a tight spiral in a shaft off to one
		side, so the rest of each floor is a room. Everything below is built off
		the well, and the floors cut a circular hole around it that is wider than
		the well itself, so nothing can overhang the climb.

		It still STOPS AT THE LIBRARY. The wall head is 62; a flight above 48 is
		a way out of the map.
	]]
	local topY = Y_FLOOR[3]
	local riseTotal = topY - GROUND
	local RISE = 1.45 -- a Roblox character steps 2; 1.45 is comfortable
	local steps = math.floor(riseTotal / RISE)
	local PER_TURN = 18
	local turnPerStep = (2 * math.pi) / PER_TURN

	-- The newel the whole spiral winds around.
	drum(m, "Newel", NEWEL_R, riseTotal + 3, Vector3.new(WELL_X, GROUND + riseTotal / 2, WELL_Z), C.stonePale, M.stone)

	for i = 0, steps do
		local a = 0.6 + i * turnPerStep
		local y = GROUND + i * RISE
		local mid = (NEWEL_R + WELL_R) / 2
		local treadLen = WELL_R - NEWEL_R + 1.5
		local treadDepth = (2 * math.pi * mid) / PER_TURN + 1.2

		--[[
			A tread runs radially out from the newel. `facing` turns a block so
			its width lies along the tangent; a further 90° about Y swaps that,
			putting the length radial and the depth along the tread, which is the
			way round a stair actually wants.
		]]
		mass(
			m,
			"Tread",
			Vector3.new(treadLen, 1.3, treadDepth),
			CFrame.new(WELL_X + math.cos(a) * mid, y, WELL_Z + math.sin(a) * mid) * CFrame.Angles(0, -(a + math.pi / 2), 0) * CFrame.Angles(0, math.rad(90), 0),
			C.stonePale,
			M.stone
		)
		-- The hollow a thousand feet wore into the middle of it.
		if chance(0.45) then
			block(m, "Worn", Vector3.new(3, 0.25, 3), CFrame.new(WELL_X + math.cos(a) * mid, y + 0.75, WELL_Z + math.sin(a) * mid), C.stoneDark, M.stone)
		end
		-- A rope handrail on the outer side, on iron rings.
		if i % 2 == 0 and i < steps then
			local ringAt = Vector3.new(WELL_X + math.cos(a) * (WELL_R - 0.6), y + 5, WELL_Z + math.sin(a) * (WELL_R - 0.6))
			local nextA = a + turnPerStep * 2
			local nextAt = Vector3.new(WELL_X + math.cos(nextA) * (WELL_R - 0.6), y + 5 + RISE * 2, WELL_Z + math.sin(nextA) * (WELL_R - 0.6))
			bar(m, "Rope", 0.3, ringAt, nextAt, C.wood, M.fabric)
		end
	end

	--[[
		Floors. Timber on stone corbels, with a clean circular hole around the
		well — joists included. The old version cut only the boards, and left the
		joists running the full diameter straight through the stair.
	]]
	for index = 2, 3 do
		local y = Y_FLOOR[index]
		local floor = model(m, ("Floor%d"):format(index))

		-- Corbels carrying the joists, all the way round.
		for i = 0, SEGMENTS - 1 do
			local a = (i / SEGMENTS) * math.pi * 2
			mass(floor, "Corbel", Vector3.new(4, 2.4, 4), CFrame.new(at(a, R_IN + 1, y - 1.6)) * facing(a), C.stonePale, M.stone)
		end

		--[[
			Joists, in SEGMENTS rather than as one bar per line. A joist that
			would cross the well is cut either side of it — which is what a
			carpenter does too: the ones that meet a stair well are trimmed into
			a header around it.
		]]
		for j = -4, 4 do
			local z = j * 4.6
			local halfSpan = math.sqrt(math.max(0, R_IN * R_IN - z * z))
			if halfSpan > 3 then
				local pieces = 14
				local run = { }
				for p = 0, pieces - 1 do
					local x0 = -halfSpan + (2 * halfSpan) * (p / pieces)
					local x1 = -halfSpan + (2 * halfSpan) * ((p + 1) / pieces)
					local clear = fromWell(TOWER_X + (x0 + x1) / 2, TOWER_Z + z) > HOLE_R
					if clear then
						if not run[1] then
							run[1] = x0
						end
						run[2] = x1
					elseif run[1] then
						bar(floor, "Joist", 1, Vector3.new(TOWER_X + run[1], y - 0.8, TOWER_Z + z), Vector3.new(TOWER_X + run[2], y - 0.8, TOWER_Z + z), C.woodDark, M.log)
						run = {}
					end
				end
				if run[1] then
					bar(floor, "Joist", 1, Vector3.new(TOWER_X + run[1], y - 0.8, TOWER_Z + z), Vector3.new(TOWER_X + run[2], y - 0.8, TOWER_Z + z), C.woodDark, M.log)
				end
			end
		end

		-- Boards across them, in short runs so a missing one is a missing board
		-- and not a missing floor.
		for i = -6, 6 do
			local x = i * 3.4
			local halfSpan = math.sqrt(math.max(0, R_IN * R_IN - x * x))
			if halfSpan > 3 then
				local runs = 6
				for r = 0, runs - 1 do
					local z0 = -halfSpan + (2 * halfSpan) * (r / runs)
					local z1 = -halfSpan + (2 * halfSpan) * ((r + 1) / runs)
					local zc = (z0 + z1) / 2
					local clear = fromWell(TOWER_X + x, TOWER_Z + zc) > HOLE_R
					if clear and not chance(0.05) then
						block(floor, "Board", Vector3.new(3.3, 0.7, z1 - z0), CFrame.new(TOWER_X + x, y, TOWER_Z + zc), C.wood, M.wood)
					end
				end
			end
		end

		--[[
			A rail round the hole, because it is a long drop — but only where the
			stair is NOT arriving, or the rail becomes the next thing to walk
			into. The opening arc is left free.
		]]
		local arrive = 0.6 + math.floor((y - GROUND) / RISE) * turnPerStep
		local posts = 16
		for p = 0, posts - 1 do
			local a = (p / posts) * math.pi * 2
			if not within(a, arrive, 1.5) then
				local px, pz = WELL_X + math.cos(a) * (HOLE_R + 0.8), WELL_Z + math.sin(a) * (HOLE_R + 0.8)
				bar(floor, "Baluster", 0.45, Vector3.new(px, y, pz), Vector3.new(px, y + 4.4, pz), C.woodDark, M.log)
				local nextA = ((p + 1) / posts) * math.pi * 2
				if not within(nextA, arrive, 1.5) then
					bar(
						floor,
						"Rail",
						0.5,
						Vector3.new(px, y + 4.2, pz),
						Vector3.new(WELL_X + math.cos(nextA) * (HOLE_R + 0.8), y + 4.2, WELL_Z + math.sin(nextA) * (HOLE_R + 0.8)),
						C.woodDark,
						M.log
					)
				end
			end
		end
	end

	--[[
		The ceiling over the library, at the wall head. SOLID, and the reason the
		tower stops being enterable here: above this line there is nothing but
		masonry and the parapet, so there is no way out onto the curtain wall.
	]]
	for i = -8, 8 do
		local x = i * 2.8
		local halfSpan = math.sqrt(math.max(0, (R_IN + 2) * (R_IN + 2) - x * x))
		if halfSpan > 2 then
			mass(m, "Ceiling", Vector3.new(2.8, 2.4, halfSpan * 2), CFrame.new(TOWER_X + x, Y_CEIL, TOWER_Z), C.stoneDark, M.stone)
		end
	end
	-- Ribs under it, so it reads as vaulted rather than as a lid.
	for i = 0, 5 do
		local a = (i / 6) * math.pi
		bar(m, "Rib", 1.2, at(a, R_IN, Y_CEIL - 1.4), at(a + math.pi, R_IN, Y_CEIL - 1.4), C.stonePale, M.stone)
	end
	drum(m, "Boss", 2.6, 1.6, Vector3.new(TOWER_X, Y_CEIL - 2.2, TOWER_Z), C.stoneDark, M.stone)
end

--==========================================================================
-- 6. THE LIBRARY
--==========================================================================
do
	local m = model(root, "Library")
	local y = Y_FLOOR[3]

	--[[
		Books.

		This is the cheapest detail in the whole map and one of the loudest: a
		block, a colour off a list, a little lean. What sells it is that no two
		are the same size and the row is not full — real shelves have gaps,
		leaning runs, and flat stacks where somebody put a book down and never
		came back for it.
	]]
	local function books(parent, cf: CFrame, length: number, shelfH: number)
		local x = -length / 2 + 1
		while x < length / 2 - 1 do
			if chance(0.14) then
				x += rng:NextNumber(1.5, 4) -- a gap
			elseif chance(0.16) then
				-- A flat stack.
				local n = rng:NextInteger(2, 5)
				local wide = rng:NextNumber(3.4, 4.6)
				for i = 0, n - 1 do
					block(parent, "Book", Vector3.new(wide, rng:NextNumber(0.6, 1.1), rng:NextNumber(2.6, 3.6)), cf * CFrame.new(x + wide / 2, 0.6 + i * 0.95, jitter(0.3)) * CFrame.Angles(0, math.rad(jitter(6)), 0), pick(COVERS), M.fabric)
				end
				x += wide + 0.6
			else
				local thick = rng:NextNumber(0.7, 1.9)
				local tall = rng:NextNumber(shelfH * 0.5, shelfH * 0.86)
				local lean = if chance(0.16) then math.rad(rng:NextNumber(8, 22)) else 0
				block(parent, "Book", Vector3.new(thick, tall, rng:NextNumber(2.4, 3.4)), cf * CFrame.new(x + thick / 2, tall / 2 + 0.3, jitter(0.25)) * CFrame.Angles(0, 0, lean), pick(COVERS), M.fabric)
				x += thick + 0.12 + (if lean > 0 then 0.5 else 0)
			end
		end
	end

	--[[
		Shelving around the wall, in the bays between the windows. Curved rooms
		get straight furniture — a bookcase is a flat thing standing against a
		round wall — so each unit is a chord, not an arc.

		Bays are skipped where a window is, and where the door's stair well comes
		up. A bookcase across a lancet blocks the only light in the room.
	]]
	local function blocked(a: number): boolean
		for _, wa in ipairs(WINDOW_ANGLES) do
			if within(a, wa, 0.62) then
				return true
			end
		end
		-- And the bay the stair well eats. The well's axis is 11 out from the
		-- centre with a 9 radius, so at WELL_A it swallows everything from
		-- radius 2 to 20 — which is exactly where the shelving stands.
		local px, pz = at(a, R_IN - 3, 0).X, at(a, R_IN - 3, 0).Z
		return fromWell(px, pz) < HOLE_R + 9
	end

	local shelfCount = 11
	for i = 0, shelfCount - 1 do
		local a = (i / shelfCount) * math.pi * 2
		if not blocked(a) then
			local case = model(m, "Bookcase")
			local cf = CFrame.new(at(a, R_IN - 3, y)) * facing(a)
			local width = 15
			local height = 15

			-- Carcass: sides, back, top.
			for side = -1, 1, 2 do
				block(case, "Side", Vector3.new(1, height, 6), cf * CFrame.new(side * width / 2, height / 2, 0), C.woodDark, M.wood)
			end
			block(case, "Back", Vector3.new(width, height, 0.8), cf * CFrame.new(0, height / 2, -2.8), C.woodDark, M.wood)
			block(case, "Cornice", Vector3.new(width + 2, 1.6, 7), cf * CFrame.new(0, height + 0.8, 0), C.woodDark, M.wood)

			-- Four shelves, and the books on them.
			local shelves = 4
			for s = 0, shelves - 1 do
				local sy = 1 + s * (height / shelves)
				block(case, "Shelf", Vector3.new(width, 0.7, 6), cf * CFrame.new(0, sy, 0), C.wood, M.wood)
				-- The top shelf is emptier: it was reached last and least.
				if chance(if s == shelves - 1 then 0.55 else 0.94) then
					books(case, cf * CFrame.new(0, sy, 0), width - 1, height / shelves - 1.4)
				end
			end
		end
	end

	--[[
		Books and sheets that came off the shelves and stayed where they fell.

		Rejected if they land over the stair well — otherwise they hang in the
		air down the middle of the shaft, which is the sort of thing that is
		invisible in code and unmissable the moment you climb past it.
	]]
	local function onFloor(minR: number, maxR: number): (number?, number?)
		for _ = 1, 20 do
			local a = rng:NextNumber(0, math.pi * 2)
			local dist = rng:NextNumber(minR, maxR)
			local p = at(a, dist, 0)
			if fromWell(p.X, p.Z) > HOLE_R + 1 then
				return a, dist
			end
		end
		return nil, nil
	end

	for _ = 1, 40 do
		local a, dist = onFloor(5, R_IN - 4)
		if a then
			block(
				m,
				"FallenBook",
				Vector3.new(rng:NextNumber(3, 4.4), rng:NextNumber(0.7, 1.3), rng:NextNumber(2.6, 3.6)),
				CFrame.new(at(a, dist, y + 0.7)) * CFrame.Angles(jitter(0.1), rng:NextNumber(0, 6), jitter(0.1)),
				pick(COVERS),
				M.fabric
			)
		end
	end
	-- Loose sheets, which is what a scriptorium leaves more of than books.
	for _ = 1, 26 do
		local a, dist = onFloor(4, R_IN - 3)
		if a then
			block(m, "Sheet", Vector3.new(rng:NextNumber(2.4, 3.6), 0.12, rng:NextNumber(2, 3)), CFrame.new(at(a, dist, y + 0.4)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), C.paper, M.paper)
		end
	end

	--==================================================================
	-- The desk, and the man at it
	--==================================================================
	local deskA = 0.0 -- facing the east windows, where the light was
	local deskAt = at(deskA, 9, y)
	local deskCf = CFrame.new(deskAt) * facing(deskA)

	local desk = model(m, "Desk")
	block(desk, "Top", Vector3.new(16, 1.2, 8), deskCf * CFrame.new(0, 8.4, 0), C.woodDark, M.wood)
	-- A sloped writing surface on it, which is what a scribe actually wrote on.
	block(desk, "Slope", Vector3.new(13, 0.8, 7), deskCf * CFrame.new(0, 9.6, -0.6) * CFrame.Angles(math.rad(-14), 0, 0), C.wood, M.wood)
	block(desk, "Ledge", Vector3.new(13, 0.9, 0.9), deskCf * CFrame.new(0, 9.1, 2.6), C.wood, M.wood)
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			block(desk, "Leg", Vector3.new(1.4, 8.4, 1.4), deskCf * CFrame.new(sx * 7, 4.2, sz * 3), C.woodDark, M.log)
		end
	end
	block(desk, "Stretcher", Vector3.new(14, 1, 1.2), deskCf * CFrame.new(0, 2, 0), C.woodDark, M.log)

	-- What is on it: the inkwell, the quill, a knife for cutting nibs, sheets,
	-- and two candles burnt to nothing.
	drum(desk, "Inkwell", 1.1, 1.8, (deskCf * CFrame.new(5, 9.4, 0)).Position, C.ash, M.stone)
	bar(desk, "Quill", 0.25, (deskCf * CFrame.new(4.4, 9.6, 0)).Position, (deskCf * CFrame.new(6.4, 12.4, 1.6)).Position, C.paper, M.paper)
	block(desk, "PenKnife", Vector3.new(2.6, 0.2, 0.5), deskCf * CFrame.new(2, 9.2, 1.6) * CFrame.Angles(0, math.rad(24), 0), C.iron, M.rusted)
	for i = 1, 5 do
		block(desk, "Sheet", Vector3.new(4.4, 0.1, 3.4), deskCf * CFrame.new(-3 + jitter(1.4), 9.3 + i * 0.1, jitter(1.2)) * CFrame.Angles(0, math.rad(jitter(9)), 0), C.paper, M.paper)
	end
	for _, cx in { -6, 6.5 } do
		local h = rng:NextNumber(1.2, 3)
		drum(desk, "CandleStub", 0.8, h, (deskCf * CFrame.new(cx, 9 + h / 2, -2)).Position, C.wax, M.sand)
		drum(desk, "Wax", 1.5, 0.4, (deskCf * CFrame.new(cx, 9.1, -2)).Position, C.wax, M.sand)
	end

	-- The stool, pushed back and never pushed in again.
	local stoolCf = deskCf * CFrame.new(1.5, 0, -6.5) * CFrame.Angles(0, math.rad(12), 0)
	block(desk, "StoolSeat", Vector3.new(6, 1, 6), stoolCf * CFrame.new(0, 5.5, 0), C.woodDark, M.wood)
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			block(desk, "StoolLeg", Vector3.new(1, 5.5, 1), stoolCf * CFrame.new(sx * 2.2, 2.75, sz * 2.2), C.woodDark, M.log)
		end
	end

	--[[
		THE SCRIBE.

		Seated, slumped forward over the desk, one arm still out across it. The
		letter is under that hand — not held up for the player, but where it fell
		when he stopped writing.

		Bones only, and roll-only rotations: an upright skeleton reads as a
		Halloween prop, and a pitched one ends up half in the floor. Both of
		those were mistakes made on the skeletons outside, and this is the same
		fix — pose it, then lift it to sit ON the seat.
	]]
	local scribe = model(m, "Scribe")
	local sit = stoolCf * CFrame.new(0, 6, 0)
	local lean = sit * CFrame.new(0, 0, 2.2) * CFrame.Angles(math.rad(-28), 0, 0)

	-- Pelvis on the seat, spine leaning onto the desk.
	block(scribe, "Pelvis", Vector3.new(4.4, 2, 3), sit * CFrame.new(0, 0.8, 0), C.bone, M.sand)
	for i = 0, 5 do
		local t = i / 5
		block(scribe, "Vertebra", Vector3.new(1.6, 1.2, 1.6), lean * CFrame.new(0, 1.6 + t * 7, 0), C.bone, M.sand)
	end
	-- Ribs, narrowing upward.
	for i = 0, 4 do
		local t = i / 4
		local rw = 5.6 - t * 1.6
		block(scribe, "Rib", Vector3.new(rw, 0.7, 3.4 - t), lean * CFrame.new(0, 3.4 + t * 4.2, 0.2), C.bone, M.sand)
	end
	block(scribe, "Skull", Vector3.new(3, 3.2, 3.4), lean * CFrame.new(0, 9.6, 0.6) * CFrame.Angles(math.rad(-24), 0, 0), C.bone, M.sand)
	block(scribe, "Jaw", Vector3.new(2.4, 0.9, 2.6), lean * CFrame.new(0, 8.2, 1.4), C.bone, M.sand)

	-- Legs under the desk.
	for side = -1, 1, 2 do
		bar(scribe, "Femur", 0.75, (sit * CFrame.new(side * 1.6, 0.4, 0)).Position, (sit * CFrame.new(side * 1.9, 0.2, 3.6)).Position, C.bone, M.sand)
		bar(scribe, "Tibia", 0.65, (sit * CFrame.new(side * 1.9, 0.2, 3.6)).Position, (sit * CFrame.new(side * 2.1, -5.6, 3.2)).Position, C.bone, M.sand)
		block(scribe, "Foot", Vector3.new(1.6, 0.7, 3), sit * CFrame.new(side * 2.1, -5.9, 4.2), C.bone, M.sand)
	end

	-- The writing arm, still out across the desk. The other has dropped.
	local handAt = deskCf * CFrame.new(-1.2, 9.9, 0.4)
	bar(scribe, "Humerus", 0.7, (lean * CFrame.new(-2.6, 8.2, 0)).Position, (lean * CFrame.new(-3.4, 4.6, 2.2)).Position, C.bone, M.sand)
	bar(scribe, "Radius", 0.6, (lean * CFrame.new(-3.4, 4.6, 2.2)).Position, handAt.Position, C.bone, M.sand)
	for f = -1, 1 do
		bar(scribe, "Finger", 0.3, handAt.Position, (handAt * CFrame.new(f * 0.7, -0.2, 1.6)).Position, C.bone, M.sand)
	end
	bar(scribe, "Humerus", 0.7, (lean * CFrame.new(2.6, 8.2, 0)).Position, (sit * CFrame.new(3.6, -1.6, -1)).Position, C.bone, M.sand)
	bar(scribe, "Radius", 0.6, (sit * CFrame.new(3.6, -1.6, -1)).Position, (sit * CFrame.new(3.9, -5.4, -0.4)).Position, C.bone, M.sand)

	-- What is left of his robe, collapsed over the bones.
	block(scribe, "Robe", Vector3.new(6.4, 7, 4.6), lean * CFrame.new(0, 4.4, -0.4), Color3.fromRGB(46, 40, 44), M.fabric)
	block(scribe, "Hood", Vector3.new(4.4, 3, 4), lean * CFrame.new(0, 9, -1), Color3.fromRGB(38, 34, 38), M.fabric)

	--==================================================================
	-- THE LETTER
	--==================================================================
	--[[
		The prop the whole map ends on. It is deliberately its own Model with a
		named part, so the interaction service can find it by name later without
		anything else in this tool having to know the text exists.

		The text lives on a StringValue beside it. Its proper home is a config
		module once the ending UI is built — this is so the words cannot be lost
		in the meantime.
	]]
	local letter = model(m, "Letter")
	local paper = block(letter, "Parchment", Vector3.new(5.4, 0.16, 4.2), handAt * CFrame.new(0.6, -0.5, 1.4) * CFrame.Angles(0, math.rad(-8), 0), C.paper, M.paper)
	paper.Name = "Parchment"
	-- Curled at one corner, because flat paper reads as a decal.
	block(letter, "Curl", Vector3.new(2, 0.5, 1.6), paper.CFrame * CFrame.new(1.8, 0.3, -1.6) * CFrame.Angles(math.rad(18), 0, 0), C.paper, M.paper)
	-- Lines of writing, suggested rather than written.
	for i = 0, 6 do
		block(letter, "Line", Vector3.new(rng:NextNumber(2.6, 4.4), 0.03, 0.16), paper.CFrame * CFrame.new(jitter(0.4), 0.11, -1.6 + i * 0.5), C.ash, M.paper)
	end

	local text = Instance.new("StringValue")
	text.Name = "Text"
	text.Value = table.concat({
		"To whoever finds this.",
		"",
		"I kept the books here. That is all I was. It seems a small thing to have been,",
		"but I am the last one who can still write, so it falls to me to set down what",
		"happened, and you are the only reason to bother.",
		"",
		"We were four hundred when the gate came down. I have not heard another voice",
		"in nine days.",
		"",
		"I watched families come apart in the yard below this window. I watched men hold",
		"torches to the dead because fire was the only thing that ever slowed them, and",
		"burn where they stood because they would not let go in time. I buried what I",
		"could carry. Then I stopped burying.",
		"",
		"On the third night, when the inner ward broke, near a hundred ran for the back",
		"gate. I opened it for them myself, and I closed it behind them, and I did not go",
		"through it, because somebody had to close it.",
		"",
		"I do not know if they lived. I have no way to know.",
		"",
		"But if you are reading this, then you came in through a gate that has been shut",
		"for forty years, and you are the first thing to move in this castle that was not",
		"already dead. So there is one thing I can still give you:",
		"",
		"THEY WENT NORTH.",
		"",
		"They took what food was left and they went north, to the high country, and if",
		"any of them are still breathing that is where they are.",
		"",
		"Find them. Tell them the gate is open. Tell them it is finished.",
		"",
		"And when you go back down my stair, walk slowly, and look at them.",
		"",
		"They are not monsters. They are the people who did not get out.",
		"",
		"They are still here. They are only not themselves any more.",
	}, "\n")
	text.Parent = letter

	--[[
		Where the interaction goes. Invisible, unclickable in the viewport, and
		named — the same treatment the gameplay markers get, so it stays out of
		the way while the room is being dressed.
	]]
	local prompt = block(letter, "ReadPoint", Vector3.new(8, 10, 8), CFrame.new(handAt.Position + Vector3.new(0, 2, 0)), C.paper, M.paper)
	prompt.Name = "ReadPoint"
	prompt.Transparency = 1
	prompt.CanCollide = false
	prompt.CanQuery = false
	prompt.CanTouch = false
	prompt.Locked = true

	-- A reading desk, and a chest nobody emptied. Both kept well off the stair
	-- well: the first version put the lectern 4 studs from its axis, hanging
	-- over the shaft.
	local lectern = model(m, "Lectern")
	local lc = CFrame.new(at(-1.2, 11, y))
	block(lectern, "Post", Vector3.new(2, 10, 2), lc * CFrame.new(0, 5, 0), C.woodDark, M.log)
	block(lectern, "Foot", Vector3.new(7, 1.2, 7), lc * CFrame.new(0, 0.6, 0), C.woodDark, M.wood)
	block(lectern, "Slope", Vector3.new(9, 0.8, 7), lc * CFrame.new(0, 10.4, 0) * CFrame.Angles(math.rad(-22), 0, 0), C.wood, M.wood)
	block(lectern, "OpenBook", Vector3.new(7.4, 0.9, 5.4), lc * CFrame.new(0, 11.1, 0.3) * CFrame.Angles(math.rad(-22), 0, 0), C.paper, M.paper)

	local chest = model(m, "Chest")
	-- NOT at 2.5: that is the well's own bearing, and the chest stood in the
	-- middle of the stair shaft.
	local cc = CFrame.new(at(-2.4, R_IN - 6, y))
	block(chest, "Body", Vector3.new(9, 5, 5.4), cc * CFrame.new(0, 2.5, 0), C.woodDark, M.wood)
	block(chest, "Lid", Vector3.new(9.4, 1.2, 5.8), cc * CFrame.new(0, 5.6, -2.4) * CFrame.Angles(math.rad(-64), 0, 0), C.woodDark, M.wood)
	for _, bx in { -3, 3 } do
		block(chest, "Band", Vector3.new(0.9, 5.4, 5.8), cc * CFrame.new(bx, 2.5, 0), C.rust, M.rusted)
	end
	for i = 1, 5 do
		block(chest, "Book", Vector3.new(3.6, 1, 3), cc * CFrame.new(jitter(2), 1 + i * 0.9, jitter(1)) * CFrame.Angles(0, math.rad(jitter(20)), 0), pick(COVERS), M.fabric)
	end
end

--==========================================================================
-- 7. THE TOP — corbels, machicolations, parapet. Scenery, not a floor.
--==========================================================================
do
	local m = model(root, "Crown")

	-- Corbel table: the ring of brackets carrying the overhang above it.
	for i = 0, SEGMENTS * 2 - 1 do
		local a = (i / (SEGMENTS * 2)) * math.pi * 2
		mass(m, "Corbel", Vector3.new(3, 3.4, 5.4), CFrame.new(at(a, R_SHAFT + 1.6, Y_CORBEL)) * facing(a), C.stonePale, M.stone)
		block(m, "CorbelRoll", Vector3.new(3.2, 1.4, 5.8), CFrame.new(at(a, R_SHAFT + 2.2, Y_CORBEL + 2.4)) * facing(a), C.stoneDark, M.stone)
	end

	--[[
		Machicolations: boxes projecting out on those corbels with gaps between
		them, so things can be dropped through onto anyone at the foot of the
		wall. THE mark of a tower somebody meant to hold.
	]]
	local R_OUT = R_SHAFT + 4
	ring(m, "Machicolation", Y_CORBEL + 5.6, R_OUT, 5.4, WALL_THICK + 3, C.stone, M.stone, function(_, i)
		return i % 3 == 2 -- the gaps
	end)

	-- Parapet above, and the merlons on it.
	ring(m, "Parapet", Y_PARAPET + 3, R_OUT, 6.4, WALL_THICK, C.stone, M.stone)
	for i = 0, SEGMENTS - 1 do
		local a = (i / SEGMENTS) * math.pi * 2
		if i % 2 == 0 then
			local h = if chance(0.22) then rng:NextNumber(3, 6) else 8
			mass(m, "Merlon", Vector3.new((2 * math.pi * R_OUT) / SEGMENTS + 0.6, h, WALL_THICK), CFrame.new(at(a, R_OUT, Y_PARAPET + 6.2 + h / 2)) * facing(a), C.stone, M.stone)
			-- Merlons often carry their own slit.
			if h > 6 and chance(0.5) then
				block(m, "MerlonSlit", Vector3.new(1.2, 3.4, WALL_THICK + 1), CFrame.new(at(a, R_OUT, Y_PARAPET + 8 + h / 2)) * facing(a), C.ash, M.stone)
			end
		end
	end

	--[[
		The roof cone over the sealed top, and the staff where a banner was.

		It is timber, and mostly gone — this tower has stood forty years without
		anybody on it. What survives is the frame and a few boards, the same rule
		the houses follow: a whole roof and a bare skeleton both look wrong.
	]]
	local apex = Vector3.new(TOWER_X, Y_TOP + 16, TOWER_Z)
	for i = 0, SEGMENTS - 1 do
		local a = (i / SEGMENTS) * math.pi * 2
		if chance(0.82) then
			bar(m, "Rafter", 0.8, at(a, R_SHAFT, Y_PARAPET + 8), apex, C.woodDark, M.log)
		end
	end
	for i = 0, SEGMENTS - 1 do
		local a = (i / SEGMENTS) * math.pi * 2
		if chance(0.4) then
			local t = rng:NextNumber(0.2, 0.8)
			local r = R_SHAFT * (1 - t)
			block(m, "Boards", Vector3.new(4.4, 0.6, 6), CFrame.new(at(a, r, Y_PARAPET + 8 + (apex.Y - Y_PARAPET - 8) * t)) * facing(a) * CFrame.Angles(math.rad(52), 0, 0), C.woodPale, M.wood)
		end
	end
	bar(m, "Staff", 0.5, apex, apex + Vector3.new(0, 12, 0), C.woodDark, M.log)
	block(m, "Banner", Vector3.new(0.3, 9, 6), CFrame.new(apex + Vector3.new(0.4, 6, 3)), Color3.fromRGB(58, 24, 28), M.fabric)
end

--==========================================================================
-- SELF-CHECK: is the climb actually clear?
--==========================================================================
--[[
	The first version of this tower could not be climbed: the floors were built
	straight through the stair, and the joists spanning the diameter stopped you
	two flights up. It looked right in the code and was wrong in the viewport,
	which is the worst combination there is.

	So the tool now measures its own result. Anything that is not part of the
	stair, sitting over the well between the ground and the library, is reported
	by name and position — no arithmetic in a comment, an actual sweep of what
	was built.
]]
do
	local STAIR_PARTS = { Tread = true, Newel = true, Worn = true, Rope = true }
	local offenders = {}

	for _, part in ipairs(root:GetDescendants()) do
		if part:IsA("BasePart") and not STAIR_PARTS[part.Name] then
			local p = part.Position
			if p.Y > GROUND - 2 and p.Y < Y_FLOOR[3] + 6 and fromWell(p.X, p.Z) < HOLE_R then
				table.insert(offenders, ("%s at %d, %d, %d"):format(part.Name, p.X, p.Y, p.Z))
			end
		end
	end

	if #offenders > 0 then
		warn(("[EndTower] %d parts are sitting in the stair well:"):format(#offenders))
		for i = 1, math.min(#offenders, 12) do
			warn("    " .. offenders[i])
		end
		warn("[EndTower] The climb is blocked. Move them clear of the well axis.")
	else
		print("[EndTower] climb check: clear — nothing but the stair is in the well.")
	end
end

--==========================================================================
print("")
print("[EndTower] DONE — " .. made .. " parts.")
print(("[EndTower] Gameplay.Battleground.EndTower, at x %d, z %d."):format(TOWER_X, TOWER_Z))
print("")
print("  Entrance   y " .. Y_FLOOR[1] .. "   door faces east, arrow on the ground outside")
print("  Landing    y " .. Y_FLOOR[2])
print("  LIBRARY    y " .. Y_FLOOR[3] .. "   the desk, the scribe, and the letter")
print("  Ceiling    y " .. Y_CEIL .. "   SOLID — the stair stops below it")
print("")
print("The letter text is on EndTower.Library.Letter.Text (a StringValue).")
print("Its read point is EndTower.Library.Letter.ReadPoint — hidden and locked,")
print("named so the interaction service can find it without touching this tool.")
print("")
print(("Nothing is climbable above y %d, and the curtain wall head is y %d."):format(Y_FLOOR[3], GROUND + WALL_H))
