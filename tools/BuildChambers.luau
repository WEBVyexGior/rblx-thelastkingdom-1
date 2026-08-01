--[[
	BuildChambers — run in the Studio Command Bar of the FORGOTTEN LANDS place,
	in EDIT MODE. Select the whole file (Ctrl+A), copy, paste, Enter.

	DECORATION ONLY. It does not touch the walls, the towers, the gate or the
	approach. It fills the nine empty chambers, and draws the road that joins
	them.

	What it makes:

	  Gameplay.Battleground.Path            the stone road, gate to keep
	  Gameplay.Battleground.Decorations     one folder per chamber inside it

	Each building is its own Model, so a whole house can be grabbed and moved in
	one click. Containers are Folders, so clicking a barrel selects that barrel's
	building and not all nine chambers at once.

	See docs/systems/ChamberThemes.md for what each chamber is meant to be. The
	short version: nine identical yards would be nine identical fights, and nine
	PLACES let a player say "I'm at the graveyard" without a map.

	Three rules it never breaks:
	  - nothing on the path
	  - nothing on an enemy spawn
	  - every door faces the road, because that is where people walked

	Ground is at y = 2 here, measured, not assumed.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

--==========================================================================
-- Measured from the world, not guessed
--==========================================================================
local GROUND = 2
local HALF_W = 150
--[[
	Usable half-width. NOT 150, and not 132 either: the side towers stand on the
	wall line at x = 150 with a radius of 22, so their inner faces reach in to
	x = 128. Anything allowed out to 132 would be built through a tower.
]]
local INNER = 122
local Z_START = 20
local CHAMBER_D = 200
local CHAMBERS = 9
local PASSAGE_X = 115 -- alternates sign; +odd, -even

local PATH_W = 13
local DETAIL = 3

local rng = Random.new(20260801)

--==========================================================================
-- Palette — the same two materials as the walls: dark timber and stone
--==========================================================================
local C = {
	stone = Color3.fromRGB(84, 82, 79),
	stoneDark = Color3.fromRGB(60, 59, 60),
	stonePale = Color3.fromRGB(112, 108, 100),
	stoneWarm = Color3.fromRGB(98, 92, 82),
	rock = Color3.fromRGB(86, 80, 73),
	flag = Color3.fromRGB(92, 88, 82),
	flagWorn = Color3.fromRGB(104, 99, 91),
	wood = Color3.fromRGB(66, 49, 34),
	woodDark = Color3.fromRGB(44, 32, 22),
	woodPale = Color3.fromRGB(92, 72, 50),
	plaster = Color3.fromRGB(122, 116, 102),
	thatch = Color3.fromRGB(78, 68, 44),
	iron = Color3.fromRGB(56, 48, 44),
	rust = Color3.fromRGB(92, 54, 34),
	ash = Color3.fromRGB(36, 34, 34),
	soil = Color3.fromRGB(62, 51, 40),
	cloth = Color3.fromRGB(88, 36, 40),
	bone = Color3.fromRGB(186, 178, 158),
	blood = Color3.fromRGB(58, 16, 18),
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
	sand = Enum.Material.Sand,
	ground = Enum.Material.Ground,
	plaster = Enum.Material.Concrete,
}

--==========================================================================
-- Foundations
--==========================================================================
local gameplay = workspace:FindFirstChild("Gameplay")
if not gameplay then
	warn("[Chambers] no Workspace.Gameplay — build the battleground first.")
	return
end
local battleground = gameplay:FindFirstChild("Battleground")
if not battleground then
	warn("[Chambers] no Gameplay.Battleground — build the battleground first.")
	return
end

for _, name in { "Path", "Decorations" } do
	local old = battleground:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

local pathFolder = Instance.new("Folder")
pathFolder.Name = "Path"
pathFolder.Parent = battleground

local decorRoot = Instance.new("Folder")
decorRoot.Name = "Decorations"
decorRoot.Parent = battleground

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

-- Only walls and roofs cast shadows. At twenty-odd thousand parts already in
-- this map, every small piece that tries is a frame nobody gets back.
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

--==========================================================================
-- THE PATH — drawn first, so everything else can avoid it
--==========================================================================
--[[
	The route, corner to corner: spawn, then alternately to the east and west
	passages, then the keep.

	It is drawn FIRST for a reason. Every building afterwards tests against it,
	so the road is never blocked and never has to be unblocked by hand later.
]]
local waypoints: { Vector3 } = {}
do
	table.insert(waypoints, Vector3.new(0, GROUND, Z_START - 40))
	for i = 1, CHAMBERS - 1 do
		local zNear = Z_START - (i - 1) * CHAMBER_D
		local zFar = zNear - CHAMBER_D
		local x = if i % 2 == 1 then PASSAGE_X else -PASSAGE_X
		-- Into the room, across to the passage side, then through it.
		table.insert(waypoints, Vector3.new(x * 0.35, GROUND, zNear - CHAMBER_D * 0.35))
		table.insert(waypoints, Vector3.new(x, GROUND, zFar + 34))
		table.insert(waypoints, Vector3.new(x, GROUND, zFar - 12))
	end
	table.insert(waypoints, Vector3.new(0, GROUND, Z_START - CHAMBERS * CHAMBER_D + 90))
	table.insert(waypoints, Vector3.new(0, GROUND, Z_START - CHAMBERS * CHAMBER_D + 30))
end

-- Distance from a point to the road, for the placement tests below.
local function distanceToPath(x: number, z: number): number
	local p = Vector2.new(x, z)
	local best = math.huge
	for i = 1, #waypoints - 1 do
		local a = Vector2.new(waypoints[i].X, waypoints[i].Z)
		local b = Vector2.new(waypoints[i + 1].X, waypoints[i + 1].Z)
		local ab = b - a
		local t = math.clamp((p - a):Dot(ab) / math.max(ab:Dot(ab), 0.001), 0, 1)
		best = math.min(best, (p - (a + ab * t)).Magnitude)
	end
	return best
end

do
	local flags = folder(pathFolder, "Flagstones")
	local kerbs = folder(pathFolder, "Kerbs")

	for i = 1, #waypoints - 1 do
		local a, b = waypoints[i], waypoints[i + 1]
		local span = b - a
		local length = span.Magnitude
		local dir = span.Unit
		local right = Vector3.new(-dir.Z, 0, dir.X)
		local steps = math.max(1, math.floor(length / 6))

		for s = 0, steps - 1 do
			local at = a + dir * (length * ((s + 0.5) / steps))

			-- Flagstones: irregular, and one in eight missing so soil shows
			-- through. A perfectly paved road in a forty-year ruin is the single
			-- most obvious tell there is.
			for lane = -2, 2 do
				if not chance(0.13) then
					local w = PATH_W / 5.6 * rng:NextNumber(0.82, 1.1)
					local l = 5.4 * rng:NextNumber(0.8, 1.1)
					block(
						flags,
						"Flagstone",
						Vector3.new(w, 0.7, l),
						CFrame.new(at + right * (lane * (PATH_W / 5)) + Vector3.new(jitter(0.4), 0.35, jitter(0.4)))
							* CFrame.Angles(0, math.atan2(dir.X, dir.Z) + math.rad(jitter(5)), 0),
						if chance(0.3) then C.flagWorn else C.flag,
						M.cobble
					)
				else
					block(
						flags,
						"BareEarth",
						Vector3.new(PATH_W / 5, 0.35, 5.2),
						CFrame.new(at + right * (lane * (PATH_W / 5)) + Vector3.new(0, 0.18, 0))
							* CFrame.Angles(0, math.atan2(dir.X, dir.Z), 0),
						C.soil,
						M.ground
					)
				end
			end

			-- Kerbs, broken here and there.
			if DETAIL >= 2 and not chance(0.22) then
				for side = -1, 1, 2 do
					block(
						kerbs,
						"Kerb",
						Vector3.new(2.2, 1.1, 5.6),
						CFrame.new(at + right * (side * (PATH_W / 2 + 1.2)) + Vector3.new(0, 0.55, 0))
							* CFrame.Angles(0, math.atan2(dir.X, dir.Z), math.rad(jitter(4))),
						C.stonePale,
						M.stone
					)
				end
			end
		end
	end
end

--==========================================================================
-- PLACEMENT — nothing on the road, nothing on a spawn, nothing in a wall
--==========================================================================
local taken: { { x: number, z: number, r: number } } = {}

local function free(x: number, z: number, radius: number): boolean
	if math.abs(x) + radius > INNER then
		return false
	end
	if distanceToPath(x, z) < radius + PATH_W / 2 + 5 then
		return false
	end
	for _, t in taken do
		if (Vector2.new(x - t.x, z - t.z)).Magnitude < radius + t.r + 6 then
			return false
		end
	end
	return true
end

local function claim(x: number, z: number, radius: number)
	table.insert(taken, { x = x, z = z, r = radius })
end

-- Enemy spawns and the objective marker are kept clear: a building on a spawn
-- drops zombies inside a wall.
local function reserveMarkers(index: number)
	local zNear = Z_START - (index - 1) * CHAMBER_D
	claim(0, zNear - CHAMBER_D + 30, 26) -- north spawn
	claim(110, zNear - 100, 22)
	claim(-110, zNear - 100, 22)
	claim(0, zNear - 100, 18) -- objective
end

-- Which way the road is, from any point. Doors are turned to face it.
local function facingPath(x: number, z: number): number
	local best, bestD = 0, math.huge
	for i = 1, #waypoints - 1 do
		local a, b = waypoints[i], waypoints[i + 1]
		local ab = Vector2.new(b.X - a.X, b.Z - a.Z)
		local ap = Vector2.new(x - a.X, z - a.Z)
		local t = math.clamp(ap:Dot(ab) / math.max(ab:Dot(ab), 0.001), 0, 1)
		local closest = Vector2.new(a.X, a.Z) + ab * t
		local d = (Vector2.new(x, z) - closest).Magnitude
		if d < bestD then
			bestD = d
			best = math.deg(math.atan2(closest.X - x, closest.Y - z))
		end
	end
	return best
end

--==========================================================================
-- BUILDING LIBRARY
-- Same language as the towers: a battered foot, a banded middle, and openings
-- that are cut rather than punched.
--==========================================================================

-- The splayed foot. On a house it is shallower than on a tower, but it is the
-- same idea and the same reason: water off, and something to stand on.
local function plinth(parent, at: Vector3, w: number, d: number, angle: number)
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	for i = 0, 2 do
		local t = i / 3
		mass(parent, "Plinth", Vector3.new(w + 3 * (1 - t), 1.4, d + 3 * (1 - t)), base * CFrame.new(0, 0.7 + i * 1.4, 0), C.stoneWarm, M.stone)
	end
end

--[[
	A wall in courses, so it can be broken realistically.

	`breaks` is a list of {from, to, heightScale} in fractions of the run, the
	same idea as the curtain walls. Openings are cut by passing a heightScale of
	zero and then framing the hole.
]]
local function courseWall(parent, from: Vector3, to: Vector3, height, thickness, breaks, colour, material)
	local span = to - from
	local length = span.Magnitude
	if length < 1 then
		return
	end
	local dir = span.Unit
	local segments = math.max(1, math.floor(length / 7))
	local alongX = math.abs(dir.X) > math.abs(dir.Z)
	local angle = math.atan2(dir.X, dir.Z)

	for i = 0, segments - 1 do
		local t = i / segments
		local h = height
		local skip = false
		for _, b in breaks do
			if t >= b[1] and t < b[2] then
				if b[3] <= 0 then
					skip = true
				else
					h = height * b[3]
				end
			end
		end
		if not skip then
			local at = from + dir * (length * (t + 0.5 / segments))
			local segLen = length / segments + 0.3
			mass(
				parent,
				"Wall",
				if alongX then Vector3.new(segLen, h, thickness) else Vector3.new(thickness, h, segLen),
				CFrame.new(at.X, from.Y + h / 2, at.Z) * CFrame.Angles(0, if alongX then 0 else 0, 0),
				colour or C.stone,
				material or M.stone
			)
			-- A quoin at the top of each surviving course: the dressed corner
			-- stone. Cheap, and it stops a wall reading as one extruded slab.
			if DETAIL >= 3 and h > height * 0.8 and chance(0.4) then
				block(
					parent,
					"Quoin",
					if alongX then Vector3.new(segLen * 0.5, 1.2, thickness + 0.4) else Vector3.new(thickness + 0.4, 1.2, segLen * 0.5),
					CFrame.new(at.X, from.Y + h - 0.6, at.Z),
					C.stonePale,
					M.stone
				)
			end
		end
	end
	return angle
end

-- A doorway with jambs, a lintel and a worn step. Every one of these faces the
-- road; a door that opens onto a wall reads as generated.
local function doorway(parent, cf: CFrame, w: number, h: number, state: string)
	block(parent, "DoorVoid", Vector3.new(w, h, 4.4), cf * CFrame.new(0, h / 2, 0), C.ash, M.stone)
	for side = -1, 1, 2 do
		block(parent, "Jamb", Vector3.new(1.4, h + 1, 4.6), cf * CFrame.new(side * (w / 2 + 0.7), h / 2, 0), C.stonePale, M.stone)
	end
	block(parent, "Lintel", Vector3.new(w + 4, 1.6, 5), cf * CFrame.new(0, h + 0.8, 0), C.stonePale, M.stone)
	block(parent, "Step", Vector3.new(w + 3, 0.6, 3.4), cf * CFrame.new(0, 0.3, 2.4), C.stonePale, M.stone)

	if state == "hanging" then
		block(parent, "Door", Vector3.new(w, h - 0.6, 0.7), cf * CFrame.new(-w * 0.3, h / 2, -w * 0.32) * CFrame.Angles(0, math.rad(58), math.rad(5)), C.woodDark, M.wood)
		block(parent, "Band", Vector3.new(w, 0.5, 0.9), cf * CFrame.new(-w * 0.3, h * 0.7, -w * 0.32) * CFrame.Angles(0, math.rad(58), 0), C.rust, M.rusted)
	elseif state == "fallen" then
		block(parent, "Door", Vector3.new(w, 0.7, h - 0.6), cf * CFrame.new(jitter(1.4), 0.35, -h * 0.42) * CFrame.Angles(0, math.rad(jitter(16)), 0), C.woodDark, M.wood)
	elseif state == "shut" then
		block(parent, "Door", Vector3.new(w, h - 0.5, 0.7), cf * CFrame.new(0, h / 2, 0), C.woodDark, M.wood)
		for _, y in { 0.3, 0.7 } do
			block(parent, "Band", Vector3.new(w, 0.5, 1), cf * CFrame.new(0, h * y, -0.2), C.rust, M.rusted)
		end
	end
end

local function window(parent, cf: CFrame, w: number, h: number, arched: boolean, shutters: boolean)
	block(parent, "Void", Vector3.new(w, h, 4.4), cf, C.ash, M.stone)
	for side = -1, 1, 2 do
		block(parent, "Jamb", Vector3.new(1.1, h, 4.6), cf * CFrame.new(side * (w / 2 + 0.55), 0, 0), C.stonePale, M.stone)
	end
	block(parent, "Sill", Vector3.new(w + 3.2, 1, 5.4), cf * CFrame.new(0, -h / 2 - 0.5, 0.4), C.stonePale, M.stone)
	if arched then
		for i = 0, 5 do
			local a = math.pi * (i / 5)
			block(parent, "Voussoir", Vector3.new(1.3, 1.8, 4.6), cf * CFrame.new(math.cos(a) * (w / 2 + 0.4), h / 2 + math.sin(a) * (w / 2 + 0.4), 0) * CFrame.Angles(0, 0, -a), C.stonePale, M.stone)
		end
	else
		block(parent, "Lintel", Vector3.new(w + 3.2, 1.2, 4.8), cf * CFrame.new(0, h / 2 + 0.6, 0), C.stonePale, M.stone)
	end
	if shutters and chance(0.7) then
		for side = -1, 1, 2 do
			if chance(0.75) then
				block(parent, "Shutter", Vector3.new(w / 2, h, 0.5), cf * CFrame.new(side * (w * 0.62), 0, -1.1) * CFrame.Angles(0, math.rad(side * -55), math.rad(jitter(6))), C.woodDark, M.wood)
			end
		end
	end
end

-- The timber frame that half these buildings were built with: posts, a sill
-- beam, a head beam, and the diagonal braces that stop it racking.
local function timberFrame(parent, from: Vector3, to: Vector3, height: number, base: number)
	local span = to - from
	local length = span.Magnitude
	local dir = span.Unit
	local bays = math.max(2, math.floor(length / 9))

	bar(parent, "Sill", 0.6, from + Vector3.new(0, base, 0), to + Vector3.new(0, base, 0), C.woodDark, M.log)
	bar(parent, "Head", 0.6, from + Vector3.new(0, base + height, 0), to + Vector3.new(0, base + height, 0), C.woodDark, M.log)

	for i = 0, bays do
		local at = from + dir * (length * (i / bays))
		bar(parent, "Post", 0.55, at + Vector3.new(0, base, 0), at + Vector3.new(0, base + height, 0), C.woodDark, M.log)
	end
	for i = 0, bays - 1 do
		local a = from + dir * (length * (i / bays))
		local b = from + dir * (length * ((i + 1) / bays))
		-- Braces alternate direction bay to bay, the way a real frame does.
		if i % 2 == 0 then
			bar(parent, "Brace", 0.42, a + Vector3.new(0, base + 1, 0), b + Vector3.new(0, base + height * 0.62, 0), C.woodDark, M.log)
		else
			bar(parent, "Brace", 0.42, b + Vector3.new(0, base + 1, 0), a + Vector3.new(0, base + height * 0.62, 0), C.woodDark, M.log)
		end
		-- Infill panel between the timbers.
		if chance(0.72) then
			local mid = (a + b) / 2
			block(parent, "Infill", Vector3.new((length / bays) * 0.9, height * 0.9, 1.4), CFrame.new(mid.X, base + height / 2, mid.Z) * CFrame.Angles(0, math.atan2(dir.X, dir.Z), 0), C.plaster, M.plaster)
		end
	end
end

-- A roof of rafters and boards, mostly gone.
local function roof(parent, centre: Vector3, w: number, d: number, angle: number, height: number, survival: number)
	local base = CFrame.new(centre) * CFrame.Angles(0, math.rad(angle), 0)
	local ridge = height + d * 0.3

	bar(parent, "RidgeBeam", 0.7, (base * CFrame.new(-w / 2, ridge, 0)).Position, (base * CFrame.new(w / 2, ridge, 0)).Position, C.woodDark, M.log)

	local rafters = math.max(3, math.floor(w / 5))
	for i = 0, rafters do
		local x = -w / 2 + (w * i / rafters)
		for side = -1, 1, 2 do
			if rng:NextNumber() < survival then
				bar(parent, "Rafter", 0.42, (base * CFrame.new(x, ridge, 0)).Position, (base * CFrame.new(x, height, side * d / 2)).Position, C.woodDark, M.log)
			end
		end
	end

	-- Boarding, in patches. Whole roofs and bare skeletons both look wrong; a
	-- roof half on is what forty years actually leaves.
	for side = -1, 1, 2 do
		for strip = 0, 3 do
			if rng:NextNumber() < survival * (1 - strip * 0.18) then
				local frac = strip / 4
				block(
					parent,
					"Boards",
					Vector3.new(w * rng:NextNumber(0.35, 0.9), 0.7, d * 0.3),
					base * CFrame.new(jitter(w * 0.2), height + (ridge - height) * (1 - frac), side * (d / 2) * (frac + 0.15)) * CFrame.Angles(math.rad(side * -34), 0, 0),
					if chance(0.4) then C.thatch else C.woodPale,
					M.wood
				)
			end
		end
	end

	-- And what came down, lying inside.
	for _ = 1, math.floor((1 - survival) * 7) do
		bar(parent, "FallenRafter", 0.4, (base * CFrame.new(jitter(w * 0.4), 0.6, jitter(d * 0.4))).Position, (base * CFrame.new(jitter(w * 0.4), rng:NextNumber(2, 8), jitter(d * 0.4))).Position, C.woodDark, M.log)
	end
end

local function chimney(parent, at: Vector3, height: number, angle: number, broken: boolean)
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	local h = if broken then height * rng:NextNumber(0.45, 0.7) else height
	mass(parent, "Stack", Vector3.new(6, h, 6), base * CFrame.new(0, h / 2, 0), C.stonePale, M.brick)
	if not broken then
		block(parent, "Cap", Vector3.new(7.6, 1.2, 7.6), base * CFrame.new(0, h + 0.6, 0), C.stoneDark, M.stone)
		block(parent, "Flue", Vector3.new(2.4, 1.6, 2.4), base * CFrame.new(0, h + 1.6, 0), C.ash, M.stone)
	else
		for _ = 1, 4 do
			block(parent, "Fallen", Vector3.new(rng:NextNumber(2, 4), rng:NextNumber(1, 2), rng:NextNumber(2, 4)), base * CFrame.new(jitter(9), 0.9, jitter(9)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), C.stonePale, M.brick)
		end
	end
end

local function rubble(parent, at: Vector3, radius: number, count: number)
	for _ = 1, count do
		local a = rng:NextNumber() * math.pi * 2
		local d = rng:NextNumber(0, radius)
		local s = rng:NextNumber(2, 7)
		block(parent, "Rubble", Vector3.new(s, s * rng:NextNumber(0.35, 0.8), s * rng:NextNumber(0.6, 1.2)), CFrame.new(at + Vector3.new(math.cos(a) * d, s / 3, math.sin(a) * d)) * CFrame.Angles(jitter(0.4), rng:NextNumber(0, 6), jitter(0.4)), if chance(0.5) then C.rock else C.stone, M.rock)
	end
end

local function barrel(parent, at: Vector3, tipped: boolean)
	local m = model(parent, "Barrel")
	local body
	if tipped then
		body = drum(m, "Body", 2, 4.4, at + Vector3.new(0, 2, 0), C.wood, M.log)
		body.CFrame = CFrame.new(at + Vector3.new(0, 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0)
	else
		body = drum(m, "Body", 2, 4.6, at + Vector3.new(0, 2.3, 0), C.wood, M.log)
	end
	for _, o in { -1.4, 1.4 } do
		local hoop = drum(m, "Hoop", 2.1, 0.4, at + Vector3.new(0, 2.3 + o, 0), C.rust, M.rusted)
		if tipped then
			hoop.CFrame = body.CFrame * CFrame.new(o, 0, 0)
		end
	end
	return m
end

local function crate(parent, at: Vector3, size: number, angle: number)
	local m = model(parent, "Crate")
	local base = CFrame.new(at + Vector3.new(0, size / 2, 0)) * CFrame.Angles(0, math.rad(angle), 0)
	block(m, "Box", Vector3.new(size, size, size), base, C.wood, M.wood)
	for _, off in { size / 2 + 0.1, -(size / 2 + 0.1) } do
		block(m, "Batten", Vector3.new(size * 1.02, 0.5, 0.4), base * CFrame.new(0, size * 0.28, off), C.woodDark, M.wood)
		block(m, "Batten", Vector3.new(0.4, 0.5, size * 1.02), base * CFrame.new(off, -size * 0.28, 0), C.woodDark, M.wood)
	end
	return m
end

local function cart(parent, at: Vector3, angle: number)
	local m = model(parent, "Cart")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	local tilt = math.rad(rng:NextNumber(0, 26))
	block(m, "Bed", Vector3.new(9, 1.4, 15), base * CFrame.new(0, 3.4, 0) * CFrame.Angles(tilt, 0, 0), C.wood, M.wood)
	for side = -1, 1, 2 do
		block(m, "Side", Vector3.new(0.8, 3.2, 15), base * CFrame.new(side * 4.4, 5, 0) * CFrame.Angles(tilt, 0, 0), C.woodDark, M.wood)
		block(m, "Shaft", Vector3.new(0.9, 0.9, 11), base * CFrame.new(side * 2.4, 3.6, 12) * CFrame.Angles(math.rad(-8), 0, 0), C.woodDark, M.log)
	end
	for side = -1, 1, 2 do
		for z = -1, 1, 2 do
			if not (side == -1 and z == 1) then
				local w = drum(m, "Wheel", 3.2, 1, Vector3.zero, C.woodDark, M.log)
				w.CFrame = base * CFrame.new(side * 5, 3.2, z * 5) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, math.rad(90), 0)
				for spoke = 0, 5 do
					block(m, "Spoke", Vector3.new(0.4, 3, 0.4), w.CFrame * CFrame.Angles(0, 0, (math.pi * 2 / 6) * spoke) * CFrame.new(0, 1.5, 0), C.wood, M.log)
				end
			end
		end
	end
	-- The wheel that came off, leaning where it stopped.
	local off = drum(m, "LooseWheel", 3.2, 1, Vector3.zero, C.woodDark, M.log)
	off.CFrame = base * CFrame.new(-9, 3, 8) * CFrame.Angles(math.rad(14), 0, math.rad(90))
	return m
end

local function barricade(parent, at: Vector3, angle: number, length: number)
	local m = model(parent, "Barricade")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	for i = 1, math.floor(length / 5) do
		block(m, "Plank", Vector3.new(4.6, rng:NextNumber(3, 8), 1.4), base * CFrame.new(-length / 2 + i * 5, rng:NextNumber(1.8, 4), jitter(0.9)) * CFrame.Angles(0, 0, math.rad(jitter(13))), C.wood, M.wood)
	end
	for _ = 1, 4 do
		block(m, "Stake", Vector3.new(1.2, 9, 1.2), base * CFrame.new(jitter(length / 2), 3.2, 2.6) * CFrame.Angles(math.rad(36), 0, 0), C.woodDark, M.log)
	end
	block(m, "Table", Vector3.new(7, 0.7, 4), base * CFrame.new(jitter(length / 3), 4.6, -1.4) * CFrame.Angles(math.rad(64), 0, 0), C.wood, M.wood)
	return m
end

--==========================================================================
-- BUILDINGS
--==========================================================================

--[[
	The workhorse: a stone house with a battered foot, cut openings, a chimney,
	and a roof that is mostly gone. `ruin` from 0 to 1 decides how much survives
	and how far the walls have come down.
]]
local function stoneHouse(parent, at: Vector3, w: number, d: number, h: number, angle: number, ruin: number, doorState: string)
	local m = model(parent, "House")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	local hw, hd = w / 2, d / 2

	plinth(m, at, w, d, angle)
	local y = at.Y + 4.2

	local function corner(x, z): Vector3
		local p = (base * CFrame.new(x, 0, z)).Position
		return Vector3.new(p.X, y, p.Z)
	end
	local a, b, c, dd = corner(-hw, hd), corner(hw, hd), corner(hw, -hd), corner(-hw, -hd)

	local sideBreaks = if ruin > 0.55 then { { 0.28, 0.52, 0 }, { 0.52, 0.74, 0.42 } } else { { 0.6, 0.76, 0.62 } }
	local backBreaks = if ruin > 0.7 then { { 0.18, 0.72, 0 } } else if ruin > 0.4 then { { 0.4, 0.6, 0.5 } } else {}

	-- The front wall keeps its full height longest: it is the thickest, and it
	-- is the one facing the road.
	courseWall(m, a, b, h, 4, { { 0.4, 0.58, 0 } }, C.stone, M.stone)
	courseWall(m, b, c, h * (1 - ruin * 0.22), 4, sideBreaks, C.stone, M.stone)
	courseWall(m, c, dd, h * (1 - ruin * 0.38), 4, backBreaks, C.stone, M.stone)
	courseWall(m, dd, a, h * (1 - ruin * 0.22), 4, sideBreaks, C.stone, M.stone)

	doorway(m, base * CFrame.new(0, 4.2, hd), 6, 10, doorState)

	if ruin < 0.72 then
		window(m, base * CFrame.new(-hw * 0.58, 4.2 + h * 0.55, hd), 4.4, 5.4, false, true)
		window(m, base * CFrame.new(hw * 0.58, 4.2 + h * 0.55, hd), 4.4, 5.4, false, true)
	end
	if ruin < 0.5 then
		window(m, base * CFrame.new(hw, 4.2 + h * 0.55, 0) * CFrame.Angles(0, math.rad(90), 0), 4.4, 5.4, false, true)
	end

	roof(m, at + Vector3.new(0, y - at.Y, 0), w, d, angle, h, math.max(0, 1 - ruin * 1.35))
	chimney(m, (base * CFrame.new(hw * 0.62, 0, -hd * 0.45)).Position + Vector3.new(0, y - at.Y, 0), h + d * 0.42, angle, ruin > 0.4)

	if DETAIL >= 3 and ruin > 0.4 then
		rubble(m, at + Vector3.new(jitter(hw), 0, jitter(hd)), 9, 8)
	end
	return m
end

--[[
	Timber over a stone base: the ordinary building of the period, and a
	completely different silhouette from the stone houses, which is the point.
	Two of the same thing is one thing too many.
]]
local function timberHouse(parent, at: Vector3, w: number, d: number, h: number, angle: number, ruin: number)
	local m = model(parent, "TimberHouse")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	local hw, hd = w / 2, d / 2
	local stoneH = 6

	plinth(m, at, w, d, angle)
	local y = at.Y + 4.2

	local function corner(x, z): Vector3
		local p = (base * CFrame.new(x, 0, z)).Position
		return Vector3.new(p.X, y, p.Z)
	end
	local a, b, c, dd = corner(-hw, hd), corner(hw, hd), corner(hw, -hd), corner(-hw, -hd)

	-- Stone to waist height, timber above. That is how they were built and it
	-- is why the stone half is still standing.
	courseWall(m, a, b, stoneH, 3.4, { { 0.4, 0.58, 0 } }, C.stoneWarm, M.stone)
	courseWall(m, b, c, stoneH, 3.4, {}, C.stoneWarm, M.stone)
	courseWall(m, c, dd, stoneH, 3.4, if ruin > 0.6 then { { 0.3, 0.6, 0.4 } } else {}, C.stoneWarm, M.stone)
	courseWall(m, dd, a, stoneH, 3.4, {}, C.stoneWarm, M.stone)

	local survival = 1 - ruin
	if survival > 0.3 then
		timberFrame(m, a, b, h - stoneH, y + stoneH)
		timberFrame(m, b, c, h - stoneH, y + stoneH)
		if survival > 0.55 then
			timberFrame(m, c, dd, h - stoneH, y + stoneH)
			timberFrame(m, dd, a, h - stoneH, y + stoneH)
		end
	end

	doorway(m, base * CFrame.new(0, 4.2, hd), 5.6, 9, if ruin > 0.55 then "fallen" else "hanging")
	if ruin < 0.6 then
		window(m, base * CFrame.new(-hw * 0.55, 4.2 + h * 0.62, hd), 4, 4.6, false, true)
		window(m, base * CFrame.new(hw * 0.55, 4.2 + h * 0.62, hd), 4, 4.6, false, true)
	end

	roof(m, at + Vector3.new(0, y - at.Y, 0), w, d, angle, h, math.max(0, 1 - ruin * 1.5))
	if DETAIL >= 3 then
		rubble(m, at + Vector3.new(jitter(hw), 0, jitter(hd)), 8, 6)
	end
	return m
end

-- A long building: barracks, stable, storehouse. Same anatomy, different
-- proportion, and a row of openings instead of one.
local function longBuilding(parent, at: Vector3, w: number, d: number, h: number, angle: number, ruin: number, bays: number)
	local m = model(parent, "LongBuilding")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	local hw, hd = w / 2, d / 2

	plinth(m, at, w, d, angle)
	local y = at.Y + 4.2

	local function corner(x, z): Vector3
		local p = (base * CFrame.new(x, 0, z)).Position
		return Vector3.new(p.X, y, p.Z)
	end
	local a, b, c, dd = corner(-hw, hd), corner(hw, hd), corner(hw, -hd), corner(-hw, -hd)

	-- The front is opened up into bays; the back takes the damage.
	local frontBreaks = {}
	for i = 0, bays - 1 do
		local centre = (i + 0.5) / bays
		table.insert(frontBreaks, { centre - 0.055, centre + 0.055, 0 })
	end

	courseWall(m, a, b, h, 4, frontBreaks, C.stone, M.stone)
	courseWall(m, b, c, h * (1 - ruin * 0.2), 4, { { 0.55, 0.78, 0.5 } }, C.stone, M.stone)
	courseWall(m, c, dd, h * (1 - ruin * 0.45), 4, if ruin > 0.5 then { { 0.25, 0.55, 0 } } else {}, C.stone, M.stone)
	courseWall(m, dd, a, h * (1 - ruin * 0.2), 4, { { 0.2, 0.4, 0.55 } }, C.stone, M.stone)

	for i = 0, bays - 1 do
		local x = -hw + w * ((i + 0.5) / bays)
		doorway(m, base * CFrame.new(x, 4.2, hd), 7, 11, pick({ "fallen", "hanging", "none", "hanging" }))
	end

	roof(m, at + Vector3.new(0, y - at.Y, 0), w, d, angle, h, math.max(0, 1 - ruin * 1.3))
	if DETAIL >= 3 then
		rubble(m, at + Vector3.new(jitter(hw), 0, -hd - 6), 10, 9)
	end
	return m
end

-- Four walls and nothing else: the buildings that lost. Cheap, and essential —
-- a yard where every building is repairable does not read as a ruin.
local function ruinShell(parent, at: Vector3, w: number, d: number, h: number, angle: number)
	local m = model(parent, "Ruin")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	local hw, hd = w / 2, d / 2

	plinth(m, at, w, d, angle)
	local y = at.Y + 4.2

	local function corner(x, z): Vector3
		local p = (base * CFrame.new(x, 0, z)).Position
		return Vector3.new(p.X, y, p.Z)
	end
	local a, b, c, dd = corner(-hw, hd), corner(hw, hd), corner(hw, -hd), corner(-hw, -hd)

	courseWall(m, a, b, h * 0.62, 4, { { 0.35, 0.7, 0 } }, C.stone, M.stone)
	courseWall(m, b, c, h * 0.78, 4, { { 0.4, 0.62, 0.35 } }, C.stone, M.stone)
	courseWall(m, c, dd, h * 0.35, 4, { { 0.2, 0.5, 0 } }, C.stone, M.stone)
	courseWall(m, dd, a, h * 0.85, 4, { { 0.55, 0.8, 0.4 } }, C.stone, M.stone)

	-- Floor joist sockets in the inside faces, where the upper floor pulled out.
	if DETAIL >= 3 then
		for i = 0, 4 do
			block(m, "JoistSocket", Vector3.new(2.4, 2.4, 3), base * CFrame.new(-hw + w * (i + 0.5) / 5, 4.2 + h * 0.45, hd - 2), C.ash, M.stone)
		end
	end
	rubble(m, at, math.max(w, d) * 0.55, 16)
	for _ = 1, 5 do
		bar(m, "FallenBeam", 0.45, at + Vector3.new(jitter(hw), 1, jitter(hd)), at + Vector3.new(jitter(hw), rng:NextNumber(2, 9), jitter(hd)), C.woodDark, M.log)
	end
	return m
end

local function well(parent, at: Vector3, boarded: boolean)
	local m = model(parent, "Well")
	drum(m, "Ring", 7, 6, at + Vector3.new(0, 3, 0), C.stoneWarm, M.stone, true)
	drum(m, "Bore", 5.4, 6.2, at + Vector3.new(0, 3.2, 0), C.ash, M.stone)
	block(m, "Coping", Vector3.new(16, 1.2, 16), CFrame.new(at + Vector3.new(0, 6.2, 0)), C.stonePale, M.stone)
	for side = -1, 1, 2 do
		block(m, "Post", Vector3.new(1.6, 13, 1.6), CFrame.new(at + Vector3.new(side * 6, 12.5, 0)), C.woodDark, M.log)
	end
	bar(m, "Beam", 0.7, at + Vector3.new(-7, 19, 0), at + Vector3.new(7, 19, 0), C.woodDark, M.log)
	drum(m, "Windlass", 1.4, 8, at + Vector3.new(0, 18, 0), C.woodDark, M.log)
	-- The rope, and nothing on the end of it.
	do
		local from = at + Vector3.new(0, 17.4, 0)
		local prev = from
		for i = 1, 6 do
			local p = from + Vector3.new(jitter(0.4), -i * 2.2, jitter(0.4))
			bar(m, "Rope", 0.18, prev, p, C.woodPale, M.cloth)
			prev = p
		end
	end
	if boarded then
		for i = -2, 2 do
			block(m, "Board", Vector3.new(3.2, 0.7, 15), CFrame.new(at + Vector3.new(i * 3.4, 6.6, 0)) * CFrame.Angles(0, math.rad(jitter(7)), 0), C.wood, M.wood)
		end
		block(m, "Nailed", Vector3.new(17, 0.6, 1.4), CFrame.new(at + Vector3.new(0, 7.1, 0)) * CFrame.Angles(0, math.rad(31), 0), C.woodDark, M.wood)
	end
	return m
end

local function forge(parent, at: Vector3, angle: number)
	local m = model(parent, "Forge")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	mass(m, "Hearth", Vector3.new(12, 5, 9), base * CFrame.new(0, 2.5, 0), C.stonePale, M.brick)
	block(m, "Coals", Vector3.new(8, 0.8, 6), base * CFrame.new(0, 5.2, 0), C.ash, M.rock)
	mass(m, "Hood", Vector3.new(12, 7, 9), base * CFrame.new(0, 9.5, 0), C.stoneDark, M.brick)
	mass(m, "Flue", Vector3.new(5, 16, 5), base * CFrame.new(0, 20, 0), C.stonePale, M.brick)
	-- Anvil on its stump.
	block(m, "Stump", Vector3.new(4, 3.4, 4), base * CFrame.new(11, 1.7, 3), C.woodDark, M.log)
	block(m, "Anvil", Vector3.new(2.4, 1.8, 6), base * CFrame.new(11, 4.3, 3), C.iron, M.iron)
	block(m, "Horn", Vector3.new(1.6, 1.3, 2.4), base * CFrame.new(11, 4.3, 6.6), C.iron, M.iron)
	-- Quench trough, bellows, and the tools left on the bench.
	block(m, "Trough", Vector3.new(4, 3, 9), base * CFrame.new(-11, 1.5, 2), C.woodDark, M.wood)
	block(m, "Water", Vector3.new(3.4, 0.4, 8.4), base * CFrame.new(-11, 2.9, 2), C.ash, M.sand)
	block(m, "Bellows", Vector3.new(5, 3, 8), base * CFrame.new(0, 3, -8) * CFrame.Angles(math.rad(-12), 0, 0), C.wood, M.wood)
	block(m, "Bench", Vector3.new(12, 0.9, 4), base * CFrame.new(16, 4, -4), C.wood, M.wood)
	for i = -2, 2 do
		bar(m, "Tool", 0.3, (base * CFrame.new(16 + i * 2, 4.6, -5)).Position, (base * CFrame.new(16 + i * 2 + jitter(1), 4.6, -1)).Position, C.iron, M.rusted)
	end
	return m
end

local function bakeOven(parent, at: Vector3, angle: number)
	local m = model(parent, "Oven")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	mass(m, "Base", Vector3.new(14, 5, 14), base * CFrame.new(0, 2.5, 0), C.stonePale, M.brick)
	-- The dome, in courses.
	for i = 0, 5 do
		local t = i / 6
		drum(m, "Dome", 6.4 * math.cos(t * math.pi * 0.42), 2.4, at + Vector3.new(0, 6 + i * 2.2, 0), C.stoneWarm, M.brick)
	end
	block(m, "Mouth", Vector3.new(5, 4, 4), base * CFrame.new(0, 7, 7), C.ash, M.brick)
	for i = 0, 4 do
		local a = math.pi * (i / 4)
		block(m, "Voussoir", Vector3.new(1.4, 1.8, 4), base * CFrame.new(math.cos(a) * 3, 7 + math.sin(a) * 3, 7) * CFrame.Angles(0, 0, -a), C.stonePale, M.brick)
	end
	block(m, "Peel", Vector3.new(0.6, 0.4, 14), base * CFrame.new(6, 6, 10) * CFrame.Angles(math.rad(-32), 0, 0), C.woodDark, M.log)
	block(m, "Ash", Vector3.new(9, 0.5, 7), base * CFrame.new(0, 0.4, 10), C.ash, M.sand)
	return m
end

local function grave(parent, at: Vector3, angle: number, style: string)
	local m = model(parent, "Grave")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	block(m, "Mound", Vector3.new(7, 1.6, 12), base * CFrame.new(0, 0.8, 0), C.soil, M.ground)

	if style == "stone" then
		block(m, "Headstone", Vector3.new(4.4, 5.4, 1), base * CFrame.new(0, 2.7, -6.4) * CFrame.Angles(math.rad(jitter(9)), 0, math.rad(jitter(7))), C.stonePale, M.stone)
		block(m, "Shoulder", Vector3.new(4.4, 1, 1.2), base * CFrame.new(0, 5.2, -6.4), C.stoneDark, M.stone)
	elseif style == "cross" then
		block(m, "Post", Vector3.new(0.8, 6, 0.8), base * CFrame.new(0, 3, -6.4) * CFrame.Angles(math.rad(jitter(11)), 0, math.rad(jitter(9))), C.woodDark, M.log)
		block(m, "Arm", Vector3.new(3.6, 0.8, 0.8), base * CFrame.new(0, 4.4, -6.4), C.woodDark, M.log)
	else
		-- Unmarked. By the end they had stopped naming them.
		for _ = 1, 3 do
			block(m, "Stone", Vector3.new(rng:NextNumber(1.5, 3), 1, rng:NextNumber(1.5, 3)), base * CFrame.new(jitter(2), 1.6, -6 + jitter(1.5)), C.rock, M.rock)
		end
	end
	return m
end

local function tomb(parent, at: Vector3, angle: number)
	local m = model(parent, "Tomb")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	mass(m, "Chest", Vector3.new(9, 5, 16), base * CFrame.new(0, 2.5, 0), C.stonePale, M.stone)
	for i = -1, 1, 2 do
		block(m, "Moulding", Vector3.new(9.8, 1, 16.8), base * CFrame.new(0, 2.5 + i * 2, 0), C.stoneDark, M.stone)
	end
	-- The lid, pushed aside. Not fallen — pushed, and from the inside.
	block(m, "Lid", Vector3.new(10, 1.6, 17), base * CFrame.new(3.4, 5.8, 1.2) * CFrame.Angles(0, math.rad(9), math.rad(4)), C.stonePale, M.stone)
	block(m, "Void", Vector3.new(7, 1, 13), base * CFrame.new(-1, 4.8, 0), C.ash, M.stone)
	return m
end

local function chapelRuin(parent, at: Vector3, angle: number)
	local m = model(parent, "Chapel")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	local w, d, h = 34, 52, 26

	plinth(m, at, w, d, angle)
	local y = at.Y + 4.2
	local function corner(x, z): Vector3
		local p = (base * CFrame.new(x, 0, z)).Position
		return Vector3.new(p.X, y, p.Z)
	end
	local a, b, c, dd = corner(-w / 2, d / 2), corner(w / 2, d / 2), corner(w / 2, -d / 2), corner(-w / 2, -d / 2)

	courseWall(m, a, b, h, 5, { { 0.42, 0.58, 0 } }, C.stonePale, M.stone)
	courseWall(m, b, c, h, 5, { { 0.62, 0.78, 0.55 } }, C.stonePale, M.stone)
	courseWall(m, c, dd, h * 0.9, 5, {}, C.stonePale, M.stone)
	courseWall(m, dd, a, h, 5, { { 0.3, 0.44, 0 } }, C.stonePale, M.stone)

	-- Buttresses: the detail that says chapel rather than shed.
	for i = -1, 1 do
		for side = -1, 1, 2 do
			mass(m, "Buttress", Vector3.new(5, h * 0.72, 7), base * CFrame.new(side * (w / 2 + 3), 4.2 + h * 0.36, i * 15), C.stonePale, M.stone)
			wedge(m, "Weathering", Vector3.new(5, 5, 7), base * CFrame.new(side * (w / 2 + 3), 4.2 + h * 0.72 + 2.5, i * 15) * CFrame.Angles(0, math.rad(if side > 0 then 90 else -90), 0), C.stoneDark, M.stone)
		end
	end

	-- Arched windows down both sides.
	for i = -1, 1 do
		for side = -1, 1, 2 do
			window(m, base * CFrame.new(side * (w / 2), 4.2 + h * 0.55, i * 15 + 7) * CFrame.Angles(0, math.rad(90 * side), 0), 4.4, 11, true, false)
		end
	end
	doorway(m, base * CFrame.new(0, 4.2, d / 2), 8, 14, "fallen")

	-- Altar, and the columns that carried a roof there is no longer any of.
	block(m, "Altar", Vector3.new(12, 4.4, 5), base * CFrame.new(0, 6.4, -d / 2 + 8), C.stonePale, M.stone)
	for i = -1, 1, 2 do
		for j = -1, 1 do
			drum(m, "Column", 2.6, 20, (base * CFrame.new(i * 11, 0, j * 13)).Position + Vector3.new(0, y + 10 - at.Y, 0), C.stonePale, M.stone, true)
			block(m, "Capital", Vector3.new(6.4, 1.4, 6.4), base * CFrame.new(i * 11, y + 20.7 - at.Y, j * 13), C.stoneDark, M.stone)
		end
	end
	roof(m, at + Vector3.new(0, y - at.Y, 0), w, d, angle, h, 0.18)
	rubble(m, at, 22, 20)
	return m
end

local function stallRow(parent, at: Vector3, angle: number, count: number)
	local m = model(parent, "Stalls")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	for i = 0, count do
		-- Partitions, some kicked out. Whatever left did not use the door.
		local broken = chance(0.35)
		block(m, "Partition", Vector3.new(1.2, if broken then rng:NextNumber(2, 5) else 8, 16), base * CFrame.new(i * 11 - count * 5.5, if broken then 3 else 6, 0) * CFrame.Angles(0, 0, math.rad(if broken then jitter(24) else 0)), C.woodDark, M.wood)
	end
	for i = 0, count - 1 do
		block(m, "Trough", Vector3.new(8, 2.4, 3.4), base * CFrame.new(i * 11 - count * 5.5 + 5.5, 3.2, -7), C.stone, M.stone)
		if chance(0.6) then
			block(m, "Straw", Vector3.new(9, 1, 12), base * CFrame.new(i * 11 - count * 5.5 + 5.5, 2.5, 1) * CFrame.Angles(0, math.rad(jitter(12)), 0), C.thatch, M.sand)
		end
	end
	return m
end

--[[
	A tower on its side across the yard. The single most useful ruin there is:
	it is instantly readable, it breaks a rectangular space into two, and it says
	something fell on this castle that could pull a tower over.
]]
local function fallenTower(parent, at: Vector3, angle: number, length: number, radius: number)
	local m = model(parent, "FallenTower")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)

	-- The stump it broke off, still upright.
	for i = 0, 3 do
		local t = i / 4
		drum(m, "Stump", radius + 4 * (1 - t), 5, (base * CFrame.new(-length / 2 - 6, 0, 0)).Position + Vector3.new(0, 2.5 + i * 5, 0), C.stoneWarm, M.stone, true)
	end
	-- The break is diagonal, because masonry fails along a line.
	wedge(m, "Break", Vector3.new(radius * 2.2, radius, radius * 2.2), (base * CFrame.new(-length / 2 - 6, 0, 0)) * CFrame.new(0, 22, 0), C.stoneDark, M.stone)

	-- The barrel itself, in drums, sagging where it hit.
	local drums = math.floor(length / 14)
	for i = 0, drums - 1 do
		local t = i / math.max(drums - 1, 1)
		local sag = math.sin(t * math.pi) * 2
		local piece = drum(m, "Barrel", radius * (1 - t * 0.12), 15, Vector3.zero, C.stone, M.stone, true)
		piece.CFrame = base
			* CFrame.new(-length / 2 + i * 14 + 8, radius - sag, jitter(1.6))
			* CFrame.Angles(0, math.rad(jitter(3)), math.rad(90 + jitter(2)))
	end

	-- Battlements that went over with it, scattered along the fall line.
	for i = 1, 9 do
		block(m, "Merlon", Vector3.new(6, 7, 6), base * CFrame.new(-length / 2 + rng:NextNumber(0, length), 3, jitter(radius * 2.2)) * CFrame.Angles(jitter(0.6), rng:NextNumber(0, 6), jitter(0.6)), C.stoneDark, M.stone)
	end
	-- And the crater of rubble where the head landed.
	rubble(m, (base * CFrame.new(length / 2 + 6, 0, 0)).Position, radius * 2.2, 24)
	return m
end

local function marketStall(parent, at: Vector3, angle: number)
	local m = model(parent, "Stall")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			block(m, "Post", Vector3.new(0.8, 10, 0.8), base * CFrame.new(sx * 6, 5, sz * 4), C.woodDark, M.log)
		end
	end
	block(m, "Counter", Vector3.new(13, 0.8, 3.4), base * CFrame.new(0, 4.4, 4), C.wood, M.wood)
	block(m, "Awning", Vector3.new(13.6, 0.4, 6), base * CFrame.new(0, 10.2, -1.6) * CFrame.Angles(math.rad(-15), 0, 0), C.cloth, M.cloth)
	block(m, "AwningTorn", Vector3.new(6, 0.4, 4), base * CFrame.new(3.6, 9.6, 3) * CFrame.Angles(math.rad(-44), 0, math.rad(jitter(12))), C.thatch, M.cloth)
	return m
end

--==========================================================================
-- THE NINE
--==========================================================================
local function chamberBounds(index: number)
	local zNear = Z_START - (index - 1) * CHAMBER_D
	return zNear - 18, zNear - CHAMBER_D + 22
end

--[[
	Places a building somewhere free in the chamber, trying a few spots before
	giving up. The alternative — a fixed layout per chamber — would put a house
	through the road the moment any number above changed.
]]
local function place(index: number, radius: number, build: (Vector3, number) -> ())
	local zA, zB = chamberBounds(index)
	for _ = 1, 60 do
		local x = rng:NextNumber(-INNER + radius, INNER - radius)
		local z = rng:NextNumber(math.min(zA, zB) + radius, math.max(zA, zB) - radius)
		if free(x, z, radius) then
			claim(x, z, radius)
			build(Vector3.new(x, GROUND, z), facingPath(x, z))
			return true
		end
	end
	return false
end

local THEMES = {
	"Outer Ward",
	"Stables",
	"Kitchens",
	"Graveyard",
	"Smithy",
	"Great Hall",
	"The Rows",
	"Inner Ward",
	"Keep Steps",
}

for index = 1, CHAMBERS do
	local f = folder(decorRoot, ("Area%d"):format(index))
	reserveMarkers(index)

	-- Ruin deepens as you go in: the fight moved one way and lost ground the
	-- whole way, and the buildings should say so before anything else does.
	local decay = 0.2 + (index / CHAMBERS) * 0.55

	if index == 1 then
		-- Outer Ward: a guardhouse, and everything barricaded from the inside.
		place(index, 22, function(at, a)
			stoneHouse(f, at, 30, 24, 18, a, decay, "hanging")
		end)
		place(index, 20, function(at, a)
			longBuilding(f, at, 44, 20, 16, a, decay, 3)
		end)
		place(index, 16, function(at, a)
			ruinShell(f, at, 24, 20, 16, a)
		end)
		for _ = 1, 4 do
			place(index, 12, function(at, a)
				barricade(f, at, a + 90, rng:NextNumber(22, 34))
			end)
		end
		for _ = 1, 6 do
			place(index, 6, function(at)
				if chance(0.5) then
					barrel(f, at, chance(0.5))
				else
					crate(f, at, rng:NextNumber(4, 6), rng:NextNumber(0, 360))
				end
			end)
		end
	elseif index == 2 then
		place(index, 26, function(at, a)
			longBuilding(f, at, 56, 24, 18, a, decay, 4)
		end)
		place(index, 22, function(at, a)
			stallRow(f, at, a, 5)
		end)
		place(index, 18, function(at, a)
			timberHouse(f, at, 26, 22, 17, a, decay)
		end)
		place(index, 12, function(at, a)
			cart(f, at, a)
		end)
		for _ = 1, 5 do
			place(index, 6, function(at)
				barrel(f, at, chance(0.6))
			end)
		end
	elseif index == 3 then
		place(index, 12, function(at)
			well(f, at, true)
		end)
		place(index, 16, function(at, a)
			bakeOven(f, at, a)
		end)
		place(index, 16, function(at, a)
			bakeOven(f, at, a + 20)
		end)
		place(index, 24, function(at, a)
			longBuilding(f, at, 46, 22, 17, a, decay, 3)
		end)
		place(index, 18, function(at, a)
			stoneHouse(f, at, 26, 22, 17, a, decay, "fallen")
		end)
		for _ = 1, 9 do
			place(index, 6, function(at)
				if chance(0.6) then
					barrel(f, at, chance(0.5))
				else
					crate(f, at, rng:NextNumber(4, 7), rng:NextNumber(0, 360))
				end
			end)
		end
	elseif index == 4 then
		place(index, 30, function(at, a)
			chapelRuin(f, at, a)
		end)
		place(index, 14, function(at, a)
			tomb(f, at, a)
		end)
		place(index, 14, function(at, a)
			tomb(f, at, a + 30)
		end)
		-- Graves in rows, then graves anywhere. The order breaks down exactly
		-- as the time to bury them ran out.
		for row = 0, 2 do
			for i = 0, 4 do
				local x = -70 + i * 16 + jitter(3)
				local z = select(1, chamberBounds(index)) - 40 - row * 18 + jitter(3)
				if free(x, z, 8) then
					claim(x, z, 8)
					grave(f, Vector3.new(x, GROUND, z), jitter(8), "stone")
				end
			end
		end
		for _ = 1, 14 do
			place(index, 8, function(at, a)
				grave(f, at, a + jitter(40), pick({ "cross", "none", "none" }))
			end)
		end
	elseif index == 5 then
		place(index, 20, function(at, a)
			forge(f, at, a)
		end)
		place(index, 20, function(at, a)
			forge(f, at, a + 180)
		end)
		place(index, 24, function(at, a)
			longBuilding(f, at, 48, 22, 18, a, decay, 3)
		end)
		place(index, 18, function(at, a)
			stoneHouse(f, at, 28, 22, 18, a, decay, "hanging")
		end)
		for _ = 1, 7 do
			place(index, 6, function(at)
				crate(f, at, rng:NextNumber(4, 7), rng:NextNumber(0, 360))
			end)
		end
	elseif index == 6 then
		-- The Great Hall: one big thing, and space around it to be seen.
		place(index, 40, function(at, a)
			local m = model(f, "GreatHall")
			local w, d, h = 64, 90, 34
			local base = CFrame.new(at) * CFrame.Angles(0, math.rad(a), 0)
			plinth(m, at, w, d, a)
			local y = at.Y + 4.2
			local function corner(x, z): Vector3
				local p = (base * CFrame.new(x, 0, z)).Position
				return Vector3.new(p.X, y, p.Z)
			end
			local p1, p2, p3, p4 = corner(-w / 2, d / 2), corner(w / 2, d / 2), corner(w / 2, -d / 2), corner(-w / 2, -d / 2)
			courseWall(m, p1, p2, h, 6, { { 0.42, 0.58, 0 } }, C.stonePale, M.stone)
			courseWall(m, p2, p3, h, 6, { { 0.5, 0.68, 0.4 } }, C.stonePale, M.stone)
			courseWall(m, p3, p4, h * 0.85, 6, { { 0.3, 0.5, 0 } }, C.stonePale, M.stone)
			courseWall(m, p4, p1, h, 6, { { 0.2, 0.34, 0.45 } }, C.stonePale, M.stone)
			doorway(m, base * CFrame.new(0, 4.2, d / 2), 12, 18, "fallen")
			for i = -2, 2 do
				for side = -1, 1, 2 do
					window(m, base * CFrame.new(side * (w / 2), 4.2 + h * 0.6, i * 16) * CFrame.Angles(0, math.rad(90 * side), 0), 5, 13, true, false)
					if i ~= 0 then
						mass(m, "Buttress", Vector3.new(6, h * 0.68, 8), base * CFrame.new(side * (w / 2 + 3.5), 4.2 + h * 0.34, i * 16 + 8), C.stonePale, M.stone)
					end
				end
			end
			-- The columns, the high table, and the benches nobody stacked.
			for i = -2, 2 do
				for side = -1, 1, 2 do
					drum(m, "Column", 3.4, 26, (base * CFrame.new(side * 20, 0, i * 17)).Position + Vector3.new(0, y + 13 - at.Y, 0), C.stonePale, M.stone, true)
					block(m, "Capital", Vector3.new(8, 1.6, 8), base * CFrame.new(side * 20, y + 26.8 - at.Y, i * 17), C.stoneDark, M.stone)
				end
			end
			block(m, "HighTable", Vector3.new(38, 1.6, 6), base * CFrame.new(0, y + 5 - at.Y, -d / 2 + 12), C.woodDark, M.wood)
			for side = -1, 1, 2 do
				block(m, "TableLeg", Vector3.new(2.4, 5, 5), base * CFrame.new(side * 16, y + 2.5 - at.Y, -d / 2 + 12), C.woodDark, M.log)
			end
			for i = -1, 1 do
				block(m, "Bench", Vector3.new(6, 1.4, 46), base * CFrame.new(i * 22, y + 3 - at.Y, 6) * CFrame.Angles(0, 0, if chance(0.4) then math.rad(58) else 0), C.woodDark, M.wood)
			end
			for _, side in { -1, 1 } do
				block(m, "Banner", Vector3.new(0.4, 22, 7), base * CFrame.new(side * (w / 2 - 4), y + 24 - at.Y, 0), C.cloth, M.cloth)
			end
			roof(m, at + Vector3.new(0, y - at.Y, 0), w, d, a, h, 0.14)
			rubble(m, at, 34, 26)
		end)
		place(index, 16, function(at, a)
			ruinShell(f, at, 24, 20, 16, a)
		end)
	elseif index == 7 then
		-- The Rows: ordinary streets. The only cheerful place in the castle.
		for _ = 1, 5 do
			place(index, 16, function(at, a)
				timberHouse(f, at, rng:NextNumber(22, 30), rng:NextNumber(20, 26), 18, a, decay * rng:NextNumber(0.7, 1.15))
			end)
		end
		for _ = 1, 2 do
			place(index, 14, function(at, a)
				stoneHouse(f, at, 24, 22, 17, a, decay, pick({ "hanging", "fallen" }))
			end)
		end
		for _ = 1, 3 do
			place(index, 12, function(at, a)
				marketStall(f, at, a)
			end)
		end
		place(index, 12, function(at)
			well(f, at, false)
		end)
		for _ = 1, 6 do
			place(index, 6, function(at)
				if chance(0.5) then
					barrel(f, at, chance(0.5))
				else
					crate(f, at, rng:NextNumber(4, 6), rng:NextNumber(0, 360))
				end
			end)
		end
	elseif index == 8 then
		-- Inner Ward: the line broke here, and a tower came down across it.
		place(index, 46, function(at, a)
			fallenTower(f, at, a + 90, 96, 20)
		end)
		place(index, 18, function(at, a)
			ruinShell(f, at, 28, 24, 20, a)
		end)
		place(index, 16, function(at, a)
			ruinShell(f, at, 22, 20, 18, a)
		end)
		for _ = 1, 5 do
			place(index, 12, function(at, a)
				barricade(f, at, a + 90, rng:NextNumber(24, 38))
			end)
		end
		for _ = 1, 4 do
			place(index, 10, function(at)
				rubble(f, at, 12, 12)
			end)
		end
	else
		-- Keep Steps: kept deliberately open. Whatever happens at the end of
		-- this map needs room, and a crowded last room would swallow it.
		place(index, 20, function(at, a)
			ruinShell(f, at, 30, 24, 22, a)
		end)
		place(index, 14, function(at, a)
			tomb(f, at, a)
		end)
		for _ = 1, 6 do
			place(index, 12, function(at, a)
				barricade(f, at, a + 90, rng:NextNumber(20, 30))
			end)
		end
		for _ = 1, 3 do
			place(index, 10, function(at)
				rubble(f, at, 14, 14)
			end)
		end
	end

	print(("[Chambers] Area%d — %s"):format(index, THEMES[index]))
	task.wait()
end

--==========================================================================
print(("[Chambers] DONE — %d parts."):format(made))
print(("Path: %d waypoints, %d wide, from the gate to the keep."):format(#waypoints, PATH_W))
print("Gameplay.Battleground.Path        — the road")
print("Gameplay.Battleground.Decorations — Area1..9, one folder each")
print("Every building is its own Model: click once for the house, Alt+click for a part.")
print("Nothing sits on the road, on a spawn, or inside a wall.")
