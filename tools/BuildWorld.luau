--[[
	BuildWorld — run in the Studio Command Bar of the FORGOTTEN LANDS place,
	in EDIT MODE. Select the whole file (Ctrl+A), copy, paste, Enter.

	Builds the entire road home: five stages, from the rail platform the train
	drops you at to the breached walls of the castle. See docs/systems/
	WorldLayout.md for what each stage is saying.

	THE PRINCIPLE: every ruin here is placed to be read, never scattered. A wall
	damaged evenly reads as texture; a wall with two breaches reads as a siege.
	Village furniture is in the ROAD rather than in the houses, because it was
	dragged out to build the barricades standing next to it. The bridge is cut
	cleanly and the charges were on the near bank — somebody blew it on purpose,
	trying to stop something crossing toward the castle, and failed. A player who
	never reads a line should still learn the story by walking through it.

	DETAIL is dialled at the top. Every prop is built from parts, so the whole
	world is arithmetic and can be reshaped by changing numbers. Small pieces
	never cast shadows: there are thousands of them, they are mostly seen at
	distance, and shadows are by far the most expensive thing about a build this
	size.

	Everything lands under `Workspace.Gameplay.<Stage>.Structure`. Re-running a
	stage replaces only that stage, so one part of the road can be rebuilt
	without losing work on the rest. Markers from ScaffoldAreas are siblings and
	are never touched.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

--==========================================================================
-- What to build
--==========================================================================
local BUILD = {
	Outskirts = true,
	Village = true,
	Crossing = true,
	Siegeground = true,
	Castle = true,
	Gorge = true, -- carves terrain for the river; needs ground to already exist
}

-- 1 = the skeleton only. 2 = furnished. 3 = everything, including the small
-- lies that sell a place. Drop it if the map starts to cost frames.
local DETAIL = 3

-- Torches and braziers carry lights. They are the single biggest runtime cost
-- in here, so they are counted and capped rather than sprinkled freely.
local MAX_LIGHTS = 90
local lightsUsed = 0

local ROAD_W = 26
local rng = Random.new(1453)

--==========================================================================
-- Palette
--==========================================================================
local C = {
	stone = Color3.fromRGB(84, 82, 79),
	stoneDark = Color3.fromRGB(60, 59, 60),
	stonePale = Color3.fromRGB(112, 108, 100),
	rock = Color3.fromRGB(86, 80, 73),
	wood = Color3.fromRGB(74, 56, 40),
	woodDark = Color3.fromRGB(52, 39, 28),
	woodPale = Color3.fromRGB(104, 84, 62),
	thatch = Color3.fromRGB(96, 82, 52),
	iron = Color3.fromRGB(58, 50, 46),
	rust = Color3.fromRGB(94, 58, 40),
	road = Color3.fromRGB(92, 80, 66),
	cobble = Color3.fromRGB(78, 74, 68),
	cloth = Color3.fromRGB(96, 40, 44),
	clothPale = Color3.fromRGB(122, 110, 88),
	bone = Color3.fromRGB(186, 178, 158),
	ash = Color3.fromRGB(42, 40, 40),
	blood = Color3.fromRGB(58, 22, 22),
	flame = Color3.fromRGB(255, 150, 60),
	gold = Color3.fromRGB(150, 118, 52),
	soil = Color3.fromRGB(66, 54, 42),
}

local M = {
	stone = Enum.Material.Slate,
	brick = Enum.Material.Brick,
	cobble = Enum.Material.Cobblestone,
	rock = Enum.Material.Rock,
	wood = Enum.Material.WoodPlanks,
	log = Enum.Material.Wood,
	thatch = Enum.Material.Grass,
	iron = Enum.Material.Metal,
	rusted = Enum.Material.CorrodedMetal,
	road = Enum.Material.Ground,
	cloth = Enum.Material.Fabric,
	sand = Enum.Material.Sand,
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

local function area(name: string)
	local node = root:FindFirstChild(name)
	if not node then
		node = Instance.new("Folder")
		node.Name = name
		node.Parent = root
	end
	local old = node:FindFirstChild("Structure")
	if old then
		old:Destroy()
	end
	local structure = Instance.new("Model")
	structure.Name = "Structure"
	structure.Parent = node
	return structure
end

local function group(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

local function jitter(amount: number): number
	return rng:NextNumber(-amount, amount)
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

-- Big masses DO cast shadows; that is what gives a ruin its weight.
local function mass(parent, name, size, cf, colour, material): Part
	local part = block(parent, name, size, cf, colour, material, true)
	return part
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
local function cyl(parent, name, radius, height, at, colour, material, shadow): Part
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

-- Same, but laid along an arbitrary direction: beams, chains, fallen columns.
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

--==========================================================================
-- Fire
--==========================================================================
--[[
	Flame is built from neon spheres and one light rather than a particle
	emitter: no asset ids to go missing, and a hard cap on how many lights the
	map can ever contain. A hundred flickering point lights is how a scene like
	this quietly becomes unplayable.
]]
local function flame(parent, at: Vector3, size: number, withLight: boolean)
	local model = group(parent, "Flame")
	for i = 1, 3 do
		local s = size * (1 - (i - 1) * 0.26)
		ball(
			model,
			"Fire",
			s,
			at + Vector3.new(jitter(size * 0.2), (i - 1) * size * 0.7, jitter(size * 0.2)),
			if i == 1 then C.flame else Color3.fromRGB(255, 196, 120),
			M.neon
		)
	end
	if withLight and lightsUsed < MAX_LIGHTS then
		lightsUsed += 1
		local light = Instance.new("PointLight")
		light.Color = C.flame
		light.Brightness = 1.4
		light.Range = 26
		light.Shadows = false
		light.Parent = model:FindFirstChild("Fire")
	end
	return model
end

--==========================================================================
-- Props
--==========================================================================
local function torch(parent, at: Vector3, angle: number, lit: boolean)
	local model = group(parent, "Torch")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	block(model, "Bracket", Vector3.new(0.5, 0.5, 2.6), base * CFrame.new(0, 0, 1.2), C.iron, M.rusted)
	bar(model, "Shaft", 0.32, (base * CFrame.new(0, -0.4, 2)).Position, (base * CFrame.new(0, 2.6, 3.4)).Position, C.woodDark, M.log)
	block(model, "Head", Vector3.new(1, 1.2, 1), base * CFrame.new(0, 2.9, 3.6), C.ash, M.rock)
	if lit then
		flame(model, (base * CFrame.new(0, 3.8, 3.6)).Position, 0.9, true)
	end
	return model
end

local function brazier(parent, at: Vector3, lit: boolean)
	local model = group(parent, "Brazier")
	for i = 0, 2 do
		local a = (math.pi * 2 / 3) * i
		bar(
			model,
			"Leg",
			0.28,
			at + Vector3.new(math.cos(a) * 1.6, 0, math.sin(a) * 1.6),
			at + Vector3.new(0, 3.2, 0),
			C.iron,
			M.rusted
		)
	end
	cyl(model, "Bowl", 2.4, 1.4, at + Vector3.new(0, 3.6, 0), C.iron, M.rusted)
	block(model, "Coals", Vector3.new(3.4, 0.5, 3.4), CFrame.new(at + Vector3.new(0, 4.2, 0)), C.ash, M.rock)
	if lit then
		flame(model, at + Vector3.new(0, 5, 0), 1.3, true)
	end
	return model
end

local function barrel(parent, at: Vector3, angle: number, tipped: boolean)
	local model = group(parent, "Barrel")
	local body
	if tipped then
		body = cyl(model, "Body", 2, 4.4, at + Vector3.new(0, 2, 0), C.wood, M.log)
		body.CFrame = CFrame.new(at + Vector3.new(0, 2, 0)) * CFrame.Angles(0, math.rad(angle), 0)
	else
		body = cyl(model, "Body", 2, 4.6, at + Vector3.new(0, 2.3, 0), C.wood, M.log)
	end
	for _, offset in { -1.4, 1.4 } do
		local hoop = cyl(model, "Hoop", 2.1, 0.4, at + Vector3.new(0, 2.3 + offset, 0), C.iron, M.rusted)
		if tipped then
			hoop.CFrame = body.CFrame * CFrame.new(offset, 0, 0)
		end
	end
	return model
end

local function crate(parent, at: Vector3, angle: number, size: number)
	local model = group(parent, "Crate")
	local base = CFrame.new(at + Vector3.new(0, size / 2, 0)) * CFrame.Angles(0, math.rad(angle), 0)
	block(model, "Box", Vector3.new(size, size, size), base, C.wood, M.wood)
	for _, axis in { Vector3.new(0, 0, size / 2 + 0.1), Vector3.new(size / 2 + 0.1, 0, 0) } do
		block(model, "Batten", Vector3.new(size * 1.02, 0.5, 0.4), base * CFrame.new(axis.X, size * 0.28, axis.Z), C.woodDark, M.wood)
		block(model, "Batten", Vector3.new(size * 1.02, 0.5, 0.4), base * CFrame.new(axis.X, -size * 0.28, axis.Z), C.woodDark, M.wood)
	end
	return model
end

local function sack(parent, at: Vector3)
	local model = group(parent, "Sack")
	block(model, "Body", Vector3.new(2.4, 2.8, 2), CFrame.new(at + Vector3.new(0, 1.4, 0)) * CFrame.Angles(jitter(0.2), rng:NextNumber(0, 3), jitter(0.2)), C.clothPale, M.cloth)
	block(model, "Neck", Vector3.new(1.2, 0.8, 1), CFrame.new(at + Vector3.new(0, 3, 0)), C.clothPale, M.cloth)
	return model
end

local function fenceRun(parent, from: Vector3, to: Vector3, ruin: number)
	local model = group(parent, "Fence")
	local span = to - from
	local length = span.Magnitude
	local dir = span.Unit
	local posts = math.max(2, math.floor(length / 9))
	for i = 0, posts do
		if not chance(ruin) then
			local at = from + dir * (length * (i / posts))
			block(model, "Post", Vector3.new(0.9, 6, 0.9), CFrame.new(at + Vector3.new(0, 3, 0)) * CFrame.Angles(math.rad(jitter(7)), 0, math.rad(jitter(7))), C.woodDark, M.log)
		end
	end
	for i = 0, posts - 1 do
		if not chance(ruin * 1.4) then
			local a = from + dir * (length * (i / posts))
			local b = from + dir * (length * ((i + 1) / posts))
			for _, h in { 2.2, 4.4 } do
				bar(model, "Rail", 0.3, a + Vector3.new(0, h, 0), b + Vector3.new(0, h, 0), C.wood, M.log)
			end
		end
	end
	return model
end

local function banner(parent, at: Vector3, angle: number, height: number, colour: Color3)
	local model = group(parent, "Banner")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	bar(model, "Pole", 0.3, (base * CFrame.new(0, 0, 0)).Position, (base * CFrame.new(0, 0, 2.4)).Position, C.woodDark, M.log)
	local torn = rng:NextNumber(0.55, 1)
	block(model, "Cloth", Vector3.new(0.2, height * torn, 5), base * CFrame.new(0, -height * torn / 2 - 0.4, 2.6), colour, M.cloth)
	-- The bottom edge is never straight: cloth left out for forty years frays.
	block(model, "Frayed", Vector3.new(0.2, 1.6, 3.4), base * CFrame.new(0, -height * torn - 1, 2.9) * CFrame.Angles(0, 0, math.rad(jitter(9))), colour, M.cloth)
	return model
end

local function hangingCloth(parent, at: Vector3, angle: number, w: number, h: number, colour: Color3)
	local model = group(parent, "Cloth")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	block(model, "Sheet", Vector3.new(w, h, 0.2), base * CFrame.new(0, -h / 2, 0) * CFrame.Angles(math.rad(jitter(5)), 0, math.rad(jitter(4))), colour, M.cloth)
	return model
end

local function chain(parent, from: Vector3, to: Vector3, links: number)
	local model = group(parent, "Chain")
	local sag = (to - from).Magnitude * 0.12
	local previous = from
	for i = 1, links do
		local t = i / links
		local point = from:Lerp(to, t) - Vector3.new(0, math.sin(t * math.pi) * sag, 0)
		bar(model, "Link", 0.22, previous, point, C.iron, M.rusted)
		previous = point
	end
	return model
end

local function ladder(parent, at: Vector3, angle: number, height: number)
	local model = group(parent, "Ladder")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0) * CFrame.Angles(math.rad(-10), 0, 0)
	for side = -1, 1, 2 do
		block(model, "Rail", Vector3.new(0.5, height, 0.5), base * CFrame.new(side * 1.5, height / 2, 0), C.woodDark, M.log)
	end
	for i = 0, math.floor(height / 2.4) do
		block(model, "Rung", Vector3.new(3.4, 0.4, 0.4), base * CFrame.new(0, i * 2.4 + 1, 0), C.wood, M.log)
	end
	return model
end

-- A doorway: frame, lintel, and a door that is usually off its hinges.
local function doorway(parent, cf: CFrame, width: number, height: number, state: string)
	local model = group(parent, "Doorway")
	for side = -1, 1, 2 do
		block(model, "Jamb", Vector3.new(1, height, 1.6), cf * CFrame.new(side * (width / 2 + 0.5), height / 2, 0), C.woodDark, M.log)
	end
	block(model, "Lintel", Vector3.new(width + 3, 1.4, 1.8), cf * CFrame.new(0, height + 0.7, 0), C.woodDark, M.log)

	if state == "hanging" then
		block(model, "Door", Vector3.new(width, height - 0.6, 0.6), cf * CFrame.new(-width * 0.32, height / 2, -width * 0.3) * CFrame.Angles(0, math.rad(52), math.rad(4)), C.wood, M.wood)
	elseif state == "fallen" then
		block(model, "Door", Vector3.new(width, 0.6, height - 0.6), cf * CFrame.new(jitter(1.5), 0.3, -height * 0.45) * CFrame.Angles(0, math.rad(jitter(14)), 0), C.wood, M.wood)
	elseif state == "shut" then
		block(model, "Door", Vector3.new(width, height - 0.6, 0.6), cf * CFrame.new(0, height / 2, 0), C.wood, M.wood)
		block(model, "Band", Vector3.new(width, 0.5, 0.8), cf * CFrame.new(0, height * 0.7, 0), C.iron, M.rusted)
		block(model, "Band", Vector3.new(width, 0.5, 0.8), cf * CFrame.new(0, height * 0.3, 0), C.iron, M.rusted)
	end
	return model
end

-- An arrow loop: the narrow slit a bowman shoots through.
local function arrowLoop(parent, cf: CFrame)
	local model = group(parent, "Loop")
	block(model, "Slit", Vector3.new(0.8, 4.5, 2.4), cf, C.stoneDark, M.stone)
	block(model, "Cross", Vector3.new(3, 0.8, 2.4), cf * CFrame.new(0, 1.4, 0), C.stoneDark, M.stone)
	return model
end

local function shutteredWindow(parent, cf: CFrame, w: number, h: number, open: boolean)
	local model = group(parent, "Window")
	block(model, "Sill", Vector3.new(w + 1.6, 0.6, 2.2), cf * CFrame.new(0, -h / 2 - 0.3, 0), C.stonePale, M.stone)
	block(model, "Lintel", Vector3.new(w + 1.6, 0.6, 2.2), cf * CFrame.new(0, h / 2 + 0.3, 0), C.stonePale, M.stone)
	block(model, "Dark", Vector3.new(w, h, 0.6), cf, C.ash, M.stone)
	if open then
		for side = -1, 1, 2 do
			block(model, "Shutter", Vector3.new(w / 2, h, 0.4), cf * CFrame.new(side * (w * 0.62), 0, -0.9) * CFrame.Angles(0, math.rad(side * -58), 0), C.wood, M.wood)
		end
	end
	return model
end

local function chimney(parent, at: Vector3, height: number, angle: number)
	local model = group(parent, "Chimney")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	block(model, "Stack", Vector3.new(5, height, 5), base * CFrame.new(0, height / 2, 0), C.stonePale, M.brick)
	block(model, "Cap", Vector3.new(6.4, 1, 6.4), base * CFrame.new(0, height + 0.5, 0), C.stoneDark, M.stone)
	return model
end

local function stairs(parent, from: Vector3, to: Vector3, width: number, steps: number)
	local model = group(parent, "Stairs")
	local span = to - from
	local flat = Vector3.new(span.X, 0, span.Z)
	local dir = flat.Unit
	for i = 0, steps - 1 do
		local t = (i + 0.5) / steps
		local at = from + flat * t + Vector3.new(0, span.Y * ((i + 1) / steps) / 2, 0)
		local depth = flat.Magnitude / steps
		block(
			model,
			"Step",
			Vector3.new(if math.abs(dir.X) > 0.5 then depth + 0.3 else width, span.Y * ((i + 1) / steps), if math.abs(dir.X) > 0.5 then width else depth + 0.3),
			CFrame.new(at),
			C.stone,
			M.stone
		)
	end
	return model
end

local function archway(parent, at: Vector3, angle: number, width: number, height: number, depth: number)
	local model = group(parent, "Arch")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	for side = -1, 1, 2 do
		mass(model, "Pier", Vector3.new(4, height, depth), base * CFrame.new(side * (width / 2 + 2), height / 2, 0), C.stone, M.stone)
	end
	local voussoirs = 9
	for i = 0, voussoirs do
		local a = math.pi * (i / voussoirs)
		block(
			model,
			"Voussoir",
			Vector3.new(3, 3.4, depth),
			base * CFrame.new(math.cos(a) * (width / 2 + 2), height + math.sin(a) * (width / 2 + 2), 0) * CFrame.Angles(0, 0, -a),
			C.stonePale,
			M.stone
		)
	end
	return model
end

local function portcullis(parent, at: Vector3, angle: number, width: number, height: number, drop: number)
	local model = group(parent, "Portcullis")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	local top = height * drop
	for i = 0, math.floor(width / 3) do
		local x = -width / 2 + i * 3
		block(model, "Bar", Vector3.new(0.7, top, 0.7), base * CFrame.new(x, height - top / 2, 0), C.iron, M.rusted)
	end
	for j = 0, math.floor(top / 5) do
		block(model, "Rung", Vector3.new(width, 0.6, 0.6), base * CFrame.new(0, height - top + j * 5, 0), C.iron, M.rusted)
	end
	-- Spikes on the bottom edge, if it is still hanging.
	if drop < 0.95 then
		for i = 0, math.floor(width / 3) do
			block(model, "Spike", Vector3.new(0.7, 1.6, 0.7), base * CFrame.new(-width / 2 + i * 3, height - top - 0.8, 0) * CFrame.Angles(math.rad(180), 0, 0), C.iron, M.rusted)
		end
	end
	return model
end

local function buttress(parent, at: Vector3, angle: number, height: number, reach: number)
	local model = group(parent, "Buttress")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	mass(model, "Pier", Vector3.new(7, height * 0.62, reach), base * CFrame.new(0, height * 0.31, reach / 2), C.stone, M.stone)
	wedge(model, "Slope", Vector3.new(7, height * 0.4, reach), base * CFrame.new(0, height * 0.62 + height * 0.2, reach / 2) * CFrame.Angles(0, math.rad(180), 0), C.stone, M.stone)
	return model
end

local function spearsInGround(parent, at: Vector3, count: number, radius: number)
	local model = group(parent, "Spears")
	for _ = 1, count do
		local a = rng:NextNumber() * math.pi * 2
		local d = rng:NextNumber(0, radius)
		local p = at + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		local lean = rng:NextNumber(-0.35, 0.35)
		bar(model, "Shaft", 0.24, p, p + Vector3.new(lean * 6, 9, lean * 5), C.woodDark, M.log)
		block(model, "Head", Vector3.new(0.7, 2, 0.25), CFrame.new(p + Vector3.new(lean * 6.6, 9.9, lean * 5.5)) * CFrame.Angles(0, 0, lean), C.iron, M.rusted)
	end
	return model
end

local function shieldPile(parent, at: Vector3, count: number)
	local model = group(parent, "Shields")
	for i = 1, count do
		local a = rng:NextNumber() * math.pi * 2
		block(
			model,
			"Shield",
			Vector3.new(5, 0.5, 7),
			CFrame.new(at + Vector3.new(jitter(3), 0.4 + i * 0.5, jitter(3))) * CFrame.Angles(jitter(0.4), a, jitter(0.3)),
			if chance(0.4) then C.cloth else C.woodDark,
			M.wood
		)
	end
	return model
end

local function bonePile(parent, at: Vector3, count: number)
	local model = group(parent, "Bones")
	for _ = 1, count do
		local p = at + Vector3.new(jitter(3.5), 0.3, jitter(3.5))
		bar(model, "Bone", rng:NextNumber(0.2, 0.35), p, p + Vector3.new(jitter(3), rng:NextNumber(0, 0.6), jitter(3)), C.bone, M.sand)
	end
	if chance(0.5) then
		ball(model, "Skull", 0.9, at + Vector3.new(jitter(2), 0.9, jitter(2)), C.bone, M.sand)
	end
	return model
end

local function grave(parent, at: Vector3, angle: number)
	local model = group(parent, "Grave")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	block(model, "Mound", Vector3.new(6, 1.4, 10), base * CFrame.new(0, 0.7, 0), C.soil, M.road)
	block(model, "Marker", Vector3.new(3.4, 4.4, 0.7), base * CFrame.new(0, 2.2, -5.4) * CFrame.Angles(math.rad(jitter(8)), 0, math.rad(jitter(6))), C.stonePale, M.stone)
	if chance(0.4) then
		block(model, "Cross", Vector3.new(0.6, 5, 0.6), base * CFrame.new(0, 2.5, -5.4), C.woodDark, M.log)
		block(model, "Arm", Vector3.new(3, 0.6, 0.6), base * CFrame.new(0, 3.8, -5.4), C.woodDark, M.log)
	end
	return model
end

local function tent(parent, at: Vector3, angle: number, size: number, collapsed: boolean)
	local model = group(parent, "Tent")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	if collapsed then
		block(model, "Canvas", Vector3.new(size * 1.3, 1, size * 1.6), base * CFrame.new(0, 0.6, 0) * CFrame.Angles(math.rad(jitter(6)), 0, math.rad(jitter(6))), C.clothPale, M.cloth)
		bar(model, "Pole", 0.4, (base * CFrame.new(-size * 0.4, 0.4, 0)).Position, (base * CFrame.new(size * 0.5, 2.2, size * 0.3)).Position, C.woodDark, M.log)
		return model
	end
	bar(model, "Ridge", 0.4, (base * CFrame.new(0, size * 0.9, -size * 0.8)).Position, (base * CFrame.new(0, size * 0.9, size * 0.8)).Position, C.woodDark, M.log)
	for side = -1, 1, 2 do
		block(model, "Canvas", Vector3.new(0.4, size * 1.3, size * 1.7), base * CFrame.new(side * size * 0.45, size * 0.45, 0) * CFrame.Angles(0, 0, math.rad(side * 38)), C.clothPale, M.cloth)
		bar(model, "Guy", 0.16, (base * CFrame.new(side * size * 0.9, size * 0.85, 0)).Position, (base * CFrame.new(side * size * 1.6, 0, 0)).Position, C.clothPale, M.cloth)
	end
	return model
end

local function campfire(parent, at: Vector3, lit: boolean)
	local model = group(parent, "Campfire")
	for i = 0, 6 do
		local a = (math.pi * 2 / 7) * i
		ball(model, "Ring", rng:NextNumber(0.7, 1.1), at + Vector3.new(math.cos(a) * 3, 0.5, math.sin(a) * 3), C.rock, M.rock)
	end
	for _ = 1, 5 do
		local a = rng:NextNumber() * math.pi * 2
		bar(model, "Log", 0.4, at + Vector3.new(math.cos(a) * 2, 0.5, math.sin(a) * 2), at + Vector3.new(0, 1.6, 0), if lit then C.woodDark else C.ash, M.log)
	end
	block(model, "Ash", Vector3.new(4, 0.4, 4), CFrame.new(at + Vector3.new(0, 0.3, 0)), C.ash, M.sand)
	if lit then
		flame(model, at + Vector3.new(0, 1.8, 0), 1.1, true)
	end
	return model
end

local function marketStall(parent, at: Vector3, angle: number)
	local model = group(parent, "Stall")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			block(model, "Post", Vector3.new(0.7, 9, 0.7), base * CFrame.new(sx * 5, 4.5, sz * 3.5), C.woodDark, M.log)
		end
	end
	block(model, "Counter", Vector3.new(11, 0.6, 3), base * CFrame.new(0, 4, 3.4), C.wood, M.wood)
	-- The awning is always torn, and always on one side.
	block(model, "Awning", Vector3.new(11.5, 0.3, 5), base * CFrame.new(0, 9.2, -1.4) * CFrame.Angles(math.rad(-16), 0, 0), if chance(0.5) then C.cloth else C.clothPale, M.cloth)
	block(model, "AwningTorn", Vector3.new(5, 0.3, 3.4), base * CFrame.new(3.2, 8.7, 2.6) * CFrame.Angles(math.rad(-42), 0, math.rad(jitter(10))), C.clothPale, M.cloth)
	return model
end

local function trough(parent, at: Vector3, angle: number)
	local model = group(parent, "Trough")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	block(model, "Base", Vector3.new(4, 1, 12), base * CFrame.new(0, 1.5, 0), C.stone, M.stone)
	for side = -1, 1, 2 do
		block(model, "Side", Vector3.new(0.8, 2.4, 12), base * CFrame.new(side * 1.8, 2.2, 0), C.stone, M.stone)
	end
	for side = -1, 1, 2 do
		block(model, "End", Vector3.new(4, 2.4, 0.8), base * CFrame.new(0, 2.2, side * 5.8), C.stone, M.stone)
	end
	return model
end

local function anvilAndForge(parent, at: Vector3, angle: number, lit: boolean)
	local model = group(parent, "Forge")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	block(model, "Stump", Vector3.new(3.4, 3, 3.4), base * CFrame.new(0, 1.5, 0), C.woodDark, M.log)
	block(model, "Anvil", Vector3.new(2, 1.6, 5), base * CFrame.new(0, 3.8, 0), C.iron, M.iron)
	block(model, "Horn", Vector3.new(1.4, 1.2, 2), base * CFrame.new(0, 3.8, 3.2), C.iron, M.iron)
	block(model, "Hearth", Vector3.new(9, 4, 7), base * CFrame.new(-9, 2, 0), C.stonePale, M.brick)
	block(model, "Hood", Vector3.new(9, 5, 7), base * CFrame.new(-9, 8, 0), C.stoneDark, M.brick)
	if lit then
		flame(model, (base * CFrame.new(-9, 4.6, 0)).Position, 1.2, true)
	end
	return model
end

local function weaponRack(parent, at: Vector3, angle: number)
	local model = group(parent, "Rack")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	for side = -1, 1, 2 do
		block(model, "Post", Vector3.new(0.7, 8, 0.7), base * CFrame.new(side * 5, 4, 0), C.woodDark, M.log)
	end
	block(model, "Rail", Vector3.new(11, 0.6, 0.6), base * CFrame.new(0, 7.2, 0), C.woodDark, M.log)
	for i = -3, 3 do
		if not chance(0.35) then
			bar(model, "Spear", 0.22, (base * CFrame.new(i * 1.5, 0, 0.4)).Position, (base * CFrame.new(i * 1.5 + jitter(0.4), 9, -0.6)).Position, C.woodDark, M.log)
		end
	end
	return model
end

local function statue(parent, at: Vector3, angle: number, height: number, headless: boolean)
	local model = group(parent, "Statue")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	block(model, "Plinth", Vector3.new(7, 4, 7), base * CFrame.new(0, 2, 0), C.stoneDark, M.stone)
	block(model, "Plinth2", Vector3.new(5.6, 1.4, 5.6), base * CFrame.new(0, 4.7, 0), C.stonePale, M.stone)
	local h = height
	block(model, "Legs", Vector3.new(2.6, h * 0.45, 2), base * CFrame.new(0, 5.4 + h * 0.22, 0), C.stonePale, M.stone)
	block(model, "Torso", Vector3.new(3.6, h * 0.38, 2.4), base * CFrame.new(0, 5.4 + h * 0.62, 0), C.stonePale, M.stone)
	block(model, "Cloak", Vector3.new(4.4, h * 0.5, 1), base * CFrame.new(0, 5.4 + h * 0.55, -1.4), C.stonePale, M.stone)
	if not headless then
		ball(model, "Head", 1.3, (base * CFrame.new(0, 5.4 + h * 0.88, 0)).Position, C.stonePale, M.stone)
	else
		-- The head is on the ground, face down. Nobody put it back.
		ball(model, "Head", 1.3, (base * CFrame.new(rng:NextNumber(4, 7), 1.2, jitter(4))).Position, C.stonePale, M.stone)
	end
	-- A sword held point-down, the way monuments do it.
	bar(model, "Sword", 0.3, (base * CFrame.new(1.6, 5.6, 1)).Position, (base * CFrame.new(1.6, 5.4 + h * 0.66, 1)).Position, C.iron, M.iron)
	return model
end

local function brokenColumn(parent, at: Vector3, height: number, fallen: boolean)
	local model = group(parent, "Column")
	if fallen then
		local a = rng:NextNumber() * math.pi * 2
		for i = 0, 3 do
			local p = at + Vector3.new(math.cos(a) * i * 7, 2.4, math.sin(a) * i * 7)
			local drum = cyl(model, "Drum", 2.6, 6.5, p, C.stonePale, M.stone)
			drum.CFrame = CFrame.new(p) * CFrame.Angles(0, a, math.rad(90)) * CFrame.Angles(0, 0, math.rad(jitter(8)))
		end
		return model
	end
	block(model, "Base", Vector3.new(7, 1.6, 7), CFrame.new(at + Vector3.new(0, 0.8, 0)), C.stonePale, M.stone)
	cyl(model, "Shaft", 2.6, height, at + Vector3.new(0, 1.6 + height / 2, 0), C.stonePale, M.stone)
	block(model, "Cap", Vector3.new(6.4, 1.4, 6.4), CFrame.new(at + Vector3.new(0, 1.6 + height + 0.7, 0)), C.stonePale, M.stone)
	return model
end

local function arrowsStuck(parent, at: Vector3, count: number, spread: number, intoGround: boolean)
	local model = group(parent, "Arrows")
	for _ = 1, count do
		local p = at + Vector3.new(jitter(spread), if intoGround then 0 else jitter(spread * 0.5), jitter(spread))
		local dir = if intoGround then Vector3.new(jitter(1), 3.6, jitter(1)) else Vector3.new(0, jitter(0.6), -2.6)
		bar(model, "Shaft", 0.13, p, p + dir, C.woodPale, M.log)
		block(model, "Fletch", Vector3.new(0.6, 0.9, 0.15), CFrame.new(p + dir * 0.92) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), C.clothPale, M.cloth)
	end
	return model
end

local function rubblePile(parent, at: Vector3, radius: number, count: number)
	local model = group(parent, "Rubble")
	for _ = 1, count do
		local a = rng:NextNumber() * math.pi * 2
		local d = rng:NextNumber(0, radius)
		local s = rng:NextNumber(2.5, 9)
		block(
			model,
			"Stone",
			Vector3.new(s, s * rng:NextNumber(0.4, 0.9), s * rng:NextNumber(0.6, 1.2)),
			CFrame.new(at + Vector3.new(math.cos(a) * d, s / 3, math.sin(a) * d)) * CFrame.Angles(jitter(0.5), rng:NextNumber(0, 6), jitter(0.5)),
			if chance(0.5) then C.rock else C.stone,
			M.rock
		)
	end
	return model
end

local function bloodstain(parent, at: Vector3, size: number)
	local model = group(parent, "Stain")
	for _ = 1, 4 do
		block(
			model,
			"Blot",
			Vector3.new(size * rng:NextNumber(0.4, 1), 0.12, size * rng:NextNumber(0.4, 1)),
			CFrame.new(at + Vector3.new(jitter(size * 0.5), 0.08, jitter(size * 0.5))) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			C.blood,
			M.sand
		)
	end
	return model
end

local function cobbles(parent, fromZ: number, toZ: number, x: number, width: number)
	local model = group(parent, "Cobbles")
	local step = 9
	for z = math.min(fromZ, toZ), math.max(fromZ, toZ), step do
		for i = -2, 2 do
			if not chance(0.18) then
				block(
					model,
					"Stone",
					Vector3.new(width / 6, 0.5, step * 0.9),
					CFrame.new(x + i * (width / 5.4) + jitter(0.6), 1.3, z + jitter(1.2)) * CFrame.Angles(0, math.rad(jitter(5)), 0),
					C.cobble,
					M.cobble
				)
			end
		end
	end
	return model
end

local function wagonWheel(parent, at: Vector3, angle: number, leaning: boolean)
	local model = group(parent, "Wheel")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	local wheel = cyl(model, "Rim", 3.4, 0.9, at + Vector3.new(0, if leaning then 3.2 else 0.5, 0), C.woodDark, M.log)
	wheel.CFrame = base * CFrame.new(0, if leaning then 3.2 else 0.5, 0) * CFrame.Angles(if leaning then math.rad(12) else math.rad(90), 0, math.rad(90))
	for i = 0, 5 do
		local a = (math.pi * 2 / 6) * i
		block(model, "Spoke", Vector3.new(0.4, 3.2, 0.4), wheel.CFrame * CFrame.Angles(0, 0, a) * CFrame.new(0, 1.6, 0), C.wood, M.log)
	end
	return model
end

--==========================================================================
-- Architectural composites
--==========================================================================
local function ruinedWall(parent, name, from: Vector3, to: Vector3, height, thickness, breaks, colour, material)
	local span = to - from
	local length = span.Magnitude
	if length < 1 then
		return
	end
	local dir = span.Unit
	local segments = math.max(1, math.floor(length / 12))
	local segLen = length / segments
	local alongX = math.abs(dir.X) > math.abs(dir.Z)

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
			local size = if alongX then Vector3.new(segLen + 0.4, h, thickness) else Vector3.new(thickness, h, segLen + 0.4)
			mass(parent, name, size, CFrame.new(at.X, from.Y + h / 2, at.Z), colour or C.stone, material or M.stone)
		end
	end
end

local function crenellate(parent, from: Vector3, to: Vector3, top: number, thickness, colour)
	local span = to - from
	local length = span.Magnitude
	if length < 14 then
		return
	end
	local dir = span.Unit
	local alongX = math.abs(dir.X) > math.abs(dir.Z)
	local count = math.floor(length / 14)
	for i = 0, count - 1 do
		local at = from + dir * (length * ((i + 0.5) / count))
		block(
			parent,
			"Merlon",
			if alongX then Vector3.new(7, 7, thickness) else Vector3.new(thickness, 7, 7),
			CFrame.new(at.X, top + 3.5, at.Z),
			colour or C.stoneDark,
			M.stone
		)
	end
end

-- The walkway behind the battlements, where defenders stood.
local function wallWalk(parent, from: Vector3, to: Vector3, y: number, width: number, inward: Vector3)
	local span = to - from
	local length = span.Magnitude
	if length < 8 then
		return
	end
	local centre = (from + to) / 2 + inward * (width / 2)
	local alongX = math.abs(span.Unit.X) > math.abs(span.Unit.Z)
	block(
		parent,
		"WallWalk",
		if alongX then Vector3.new(length, 2, width) else Vector3.new(width, 2, length),
		CFrame.new(centre.X, y, centre.Z),
		C.stone,
		M.stone
	)
end

local function tower(parent, name, at: Vector3, radius, height, opts)
	opts = opts or {}
	local model = group(parent, name)
	local body = cyl(model, "Body", radius, height, Vector3.new(at.X, at.Y + height / 2, at.Z), C.stone, M.stone, true)

	if opts.lean then
		body.CFrame = CFrame.new(body.Position)
			* CFrame.Angles(math.rad(opts.lean), 0, math.rad(opts.lean * 0.7))
			* CFrame.Angles(0, 0, math.rad(90))
	end

	-- A string course: the horizontal band that stops a tower reading as a pipe.
	if DETAIL >= 2 then
		for band = 1, math.max(1, math.floor(height / 34)) do
			cyl(model, "Band", radius + 1.2, 2, Vector3.new(at.X, at.Y + band * (height / (math.floor(height / 34) + 1)), at.Z), C.stoneDark, M.stone)
		end
	end

	-- Arrow loops facing outward.
	if DETAIL >= 2 and not opts.lean then
		local loops = math.max(2, math.floor(height / 26))
		for i = 1, loops do
			local a = rng:NextNumber() * math.pi * 2
			arrowLoop(
				model,
				CFrame.new(at.X + math.cos(a) * radius, at.Y + 12 + (i - 1) * 22, at.Z + math.sin(a) * radius) * CFrame.Angles(0, -a + math.pi / 2, 0)
			)
		end
	end

	if opts.crown ~= false then
		local top = at.Y + height + 3
		local n = math.max(8, math.floor(radius / 2))
		for i = 0, n - 1 do
			local a = (math.pi * 2 / n) * i
			if not (opts.gaps and chance(opts.gaps)) then
				block(
					model,
					"Merlon",
					Vector3.new(radius * 0.34, 8, radius * 0.34),
					CFrame.new(at.X + math.cos(a) * (radius - 3), top, at.Z + math.sin(a) * (radius - 3)) * CFrame.Angles(0, -a, 0),
					C.stoneDark,
					M.stone
				)
			end
		end
		-- The floor they stood on.
		cyl(model, "Deck", radius - 1, 1.5, Vector3.new(at.X, at.Y + height, at.Z), C.stone, M.stone)
	end

	if opts.roof then
		local peak = at.Y + height + (opts.crown ~= false and 8 or 0)
		for step = 1, 6 do
			local t = step / 6
			cyl(model, "Roof", radius * (1 - t) * 1.05 + 1, 7, Vector3.new(at.X, peak + step * 5.5, at.Z), C.woodDark, M.wood)
		end
	end

	if opts.torch and DETAIL >= 2 then
		torch(model, Vector3.new(at.X, at.Y + height * 0.55, at.Z + radius), 180, opts.lit ~= false)
	end
	return model
end

local function house(parent, name, at: Vector3, size: Vector3, angle: number, ruin: number)
	local model = group(parent, name)
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	local hx, hz = size.X / 2, size.Z / 2
	local h = size.Y
	local t = 3

	local function corner(x, z): Vector3
		return (base * CFrame.new(x, 0, z)).Position
	end
	local a, b, c, d = corner(-hx, hz), corner(hx, hz), corner(hx, -hz), corner(-hx, -hz)

	local doorGap = { { 0.42, 0.6, 0 } }
	local sideBreaks = if ruin > 0.5 then { { 0.3, 0.55, 0 }, { 0.55, 0.75, 0.45 } } else { { 0.62, 0.78, 0.55 } }

	ruinedWall(model, "Wall", a, b, h, t, doorGap, C.stone, M.stone)
	ruinedWall(model, "Wall", b, c, h * (1 - ruin * 0.25), t, sideBreaks, C.stone, M.stone)
	ruinedWall(model, "Wall", c, d, h * (1 - ruin * 0.4), t, if ruin > 0.6 then { { 0.2, 0.7, 0 } } else {}, C.stone, M.stone)
	ruinedWall(model, "Wall", d, a, h * (1 - ruin * 0.25), t, sideBreaks, C.stone, M.stone)

	if DETAIL >= 2 then
		doorway(model, base * CFrame.new(0, 0, hz), 5, 9, if ruin > 0.6 then "fallen" elseif ruin > 0.3 then "hanging" else "shut")
		-- Windows, but only where the wall is still tall enough to hold one.
		if ruin < 0.7 then
			shutteredWindow(model, base * CFrame.new(-hx * 0.55, h * 0.55, hz), 4, 5, chance(0.6))
			shutteredWindow(model, base * CFrame.new(hx * 0.55, h * 0.55, hz), 4, 5, chance(0.6))
		end
		if ruin < 0.5 then
			shutteredWindow(model, base * CFrame.new(hx, h * 0.55, 0) * CFrame.Angles(0, math.rad(90), 0), 4, 5, chance(0.5))
		end
		-- A doorstep, worn by forty years of nobody.
		block(model, "Step", Vector3.new(7, 0.8, 3), base * CFrame.new(0, 0.4, hz + 2), C.stonePale, M.stone)
	end

	if ruin < 0.45 then
		local ridge = h + size.Z * 0.32
		for side = -1, 1, 2 do
			for strip = 0, 3 do
				local frac = strip / 4
				if not (strip == 3 and ruin > 0.2) then
					block(
						model,
						"Roof",
						Vector3.new(size.X + 3, 1.6, size.X * 0.28),
						base * CFrame.new(0, h + (ridge - h) * (1 - frac), side * (hz * (frac + 0.12))) * CFrame.Angles(math.rad(side * -32), 0, 0),
						C.thatch,
						M.thatch
					)
				end
			end
		end
		if DETAIL >= 2 then
			chimney(model, (base * CFrame.new(hx * 0.6, h, -hz * 0.4)).Position, size.Z * 0.5, angle)
		end
	else
		for _ = 1, 5 do
			block(
				model,
				"Beam",
				Vector3.new(2, 2, size.Z * rng:NextNumber(0.5, 0.95)),
				base * CFrame.new(jitter(hx * 0.7), rng:NextNumber(2, h * 0.5), jitter(hz * 0.3))
					* CFrame.Angles(jitter(0.5), rng:NextNumber(0, 3), jitter(0.4)),
				C.woodDark,
				M.log
			)
		end
		if DETAIL >= 3 then
			rubblePile(model, (base * CFrame.new(jitter(hx), 0, jitter(hz))).Position, 6, 7)
		end
	end
	return model
end

local function roadSlab(parent, fromZ: number, toZ: number, x: number, width: number)
	block(parent, "Road", Vector3.new(width, 1.2, math.abs(toZ - fromZ)), CFrame.new(x, 0.6, (fromZ + toZ) / 2), C.road, M.road)
	if DETAIL >= 3 then
		cobbles(parent, fromZ, toZ, x, width)
	end
end

local function barricade(parent, at: Vector3, angle: number, length: number)
	local model = group(parent, "Barricade")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	for i = 1, math.floor(length / 5) do
		local x = -length / 2 + i * 5
		block(model, "Plank", Vector3.new(4.6, rng:NextNumber(3, 7), 1.4), base * CFrame.new(x, rng:NextNumber(1.5, 3.5), jitter(0.8)) * CFrame.Angles(0, 0, math.rad(jitter(14))), C.wood, M.wood)
	end
	for _ = 1, 4 do
		block(model, "Stake", Vector3.new(1.2, 9, 1.2), base * CFrame.new(jitter(length / 2), 3, 2.5) * CFrame.Angles(math.rad(38), 0, 0), C.woodDark, M.log)
	end
	-- Whatever was to hand: a table, a door, a wheel.
	if DETAIL >= 2 then
		block(model, "Table", Vector3.new(7, 0.6, 4), base * CFrame.new(jitter(length / 3), 4.6, -1) * CFrame.Angles(math.rad(62), 0, 0), C.wood, M.wood)
		wagonWheel(model, (base * CFrame.new(length / 2 - 3, 0, 1)).Position, angle + 90, true)
	end
	return model
end

local function cairn(parent, at: Vector3, size: number)
	local model = group(parent, "Cairn")
	local layers = math.max(3, math.floor(size))
	for i = 1, layers do
		local t = i / layers
		block(model, "Stone", Vector3.new(size * (1 - t * 0.75) + 1, 1.6, size * (1 - t * 0.75) + 1), CFrame.new(at.X + jitter(0.6), at.Y + i * 1.5, at.Z + jitter(0.6)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), C.rock, M.rock)
	end
	return model
end

local function cart(parent, at: Vector3, angle: number, wrecked: boolean)
	local model = group(parent, "Cart")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	local tilt = if wrecked then math.rad(24) else 0

	block(model, "Bed", Vector3.new(9, 1.4, 15), base * CFrame.new(0, 3.4, 0) * CFrame.Angles(tilt, 0, 0), C.wood, M.wood)
	for side = -1, 1, 2 do
		block(model, "Side", Vector3.new(0.8, 3.4, 15), base * CFrame.new(side * 4.4, 5, 0) * CFrame.Angles(tilt, 0, 0), C.woodDark, M.wood)
	end
	for side = -1, 1, 2 do
		for z = -1, 1, 2 do
			if not (wrecked and side == -1 and z == 1) then
				local wheel = cyl(model, "Wheel", 3.2, 1, (base * CFrame.new(side * 5, 3.2, z * 5)).Position, C.woodDark, M.log)
				wheel.CFrame = base * CFrame.new(side * 5, 3.2, z * 5) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, math.rad(90), 0)
			end
		end
	end
	for side = -1, 1, 2 do
		block(model, "Shaft", Vector3.new(0.9, 0.9, 11), base * CFrame.new(side * 2.4, 3.6, 12) * CFrame.Angles(math.rad(-6), 0, 0), C.woodDark, M.log)
	end
	if wrecked and DETAIL >= 2 then
		wagonWheel(model, (base * CFrame.new(-8, 0, 7)).Position, angle + 40, false)
		for _ = 1, 3 do
			barrel(model, (base * CFrame.new(jitter(6), 0, jitter(8))).Position, rng:NextNumber(0, 360), chance(0.6))
		end
	end
	return model
end

local function trebuchet(parent, at: Vector3, angle: number)
	local model = group(parent, "Trebuchet")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)

	for side = -1, 1, 2 do
		block(model, "Foot", Vector3.new(2.4, 2.4, 26), base * CFrame.new(side * 7, 1.2, 0), C.woodDark, M.log)
		block(model, "Leg", Vector3.new(2, 30, 2), base * CFrame.new(side * 7, 15, -5) * CFrame.Angles(math.rad(16), 0, 0), C.wood, M.log)
		block(model, "Leg", Vector3.new(2, 30, 2), base * CFrame.new(side * 7, 15, 5) * CFrame.Angles(math.rad(-16), 0, 0), C.wood, M.log)
		block(model, "Brace", Vector3.new(1.4, 1.4, 14), base * CFrame.new(side * 7, 20, 0), C.wood, M.log)
	end
	block(model, "Axle", Vector3.new(16, 1.6, 1.6), base * CFrame.new(0, 29, 0), C.iron, M.iron)
	block(model, "Arm", Vector3.new(1.8, 1.8, 40), base * CFrame.new(0, 26, -6) * CFrame.Angles(math.rad(42), 0, 0), C.wood, M.log)
	block(model, "Counterweight", Vector3.new(7, 7, 7), base * CFrame.new(0, 12, 12), C.iron, M.iron)
	if DETAIL >= 2 then
		-- Still loaded. It never got to fire again.
		ball(model, "Shot", 2.6, (base * CFrame.new(0, 6, -22)).Position, C.rock, M.rock)
		for i = 1, 3 do
			ball(model, "Shot", rng:NextNumber(2, 3), (base * CFrame.new(jitter(9), 2, -26 - i * 4)).Position, C.rock, M.rock)
		end
		chain(model, (base * CFrame.new(0, 28, -20)).Position, (base * CFrame.new(0, 4, -24)).Position, 7)
	end
	return model
end

--==========================================================================
-- STAGE 1 — Outskirts
--==========================================================================
if BUILD.Outskirts then
	local f = area("Area1_Outskirts")

	-- The platform the train arrives at: the last piece of the world that works.
	local plat = group(f, "Platform")
	mass(plat, "Deck", Vector3.new(70, 3, 90), CFrame.new(0, 1.5, 235), C.stonePale, M.stone)
	block(plat, "Edge", Vector3.new(70, 1.5, 2), CFrame.new(0, 3.4, 190), C.stoneDark, M.stone)
	for side = -1, 1, 2 do
		for i = 0, 3 do
			block(plat, "Post", Vector3.new(1.6, 14, 1.6), CFrame.new(side * 30, 10, 200 + i * 22), C.woodDark, M.log)
		end
		block(plat, "Canopy", Vector3.new(10, 1, 90), CFrame.new(side * 30, 17.5, 235), C.woodDark, M.wood)
		block(plat, "Fascia", Vector3.new(10, 2, 1), CFrame.new(side * 30, 16.6, 190), C.wood, M.wood)
	end
	for side = -1, 1, 2 do
		block(plat, "Rail", Vector3.new(1.2, 1, 200), CFrame.new(side * 6, 1, 300), C.rust, M.rusted)
	end
	for i = 0, 24 do
		block(plat, "Sleeper", Vector3.new(20, 0.9, 3), CFrame.new(0, 0.6, 205 + i * 8), C.woodDark, M.log)
	end
	if DETAIL >= 2 then
		-- A ticket hut nobody has staffed in decades.
		house(plat, "TicketHut", Vector3.new(-24, 3, 262), Vector3.new(16, 12, 14), 0, 0.25)
		for _, z in { 208, 246, 272 } do
			block(plat, "Bench", Vector3.new(12, 0.7, 3), CFrame.new(22, 5, z), C.wood, M.wood)
			for s = -1, 1, 2 do
				block(plat, "BenchLeg", Vector3.new(0.8, 2, 2.6), CFrame.new(22 + s * 5, 4, z), C.woodDark, M.log)
			end
		end
		torch(plat, Vector3.new(-30, 12, 214), 0, true)
		torch(plat, Vector3.new(30, 12, 256), 180, true)
		for _ = 1, 6 do
			crate(plat, Vector3.new(rng:NextNumber(-26, -14), 3, rng:NextNumber(206, 230)), rng:NextNumber(0, 360), rng:NextNumber(3, 5))
		end
		barrel(plat, Vector3.new(-20, 3, 244), 0, false)
		barrel(plat, Vector3.new(-16, 3, 248), 0, true)
		sack(plat, Vector3.new(-24, 3, 252))
	end

	roadSlab(f, 190, -120, 0, ROAD_W)

	-- The first objective: a survivor's cairn, and a signpost pointing nowhere useful.
	cairn(f, Vector3.new(-16, 0, -30), 6)
	local sign = group(f, "Signpost")
	block(sign, "Post", Vector3.new(1.4, 15, 1.4), CFrame.new(-13, 7.5, -30) * CFrame.Angles(0, 0, math.rad(9)), C.woodDark, M.log)
	block(sign, "Board", Vector3.new(14, 4, 0.8), CFrame.new(-10, 13, -30) * CFrame.Angles(0, math.rad(18), math.rad(9)), C.wood, M.wood)
	block(sign, "Rag", Vector3.new(3, 7, 0.3), CFrame.new(-13, 4, -30.6) * CFrame.Angles(0, 0, math.rad(6)), C.cloth, M.cloth)
	if DETAIL >= 3 then
		bonePile(f, Vector3.new(-21, 0, -34), 6)
		bloodstain(f, Vector3.new(-8, 0, -28), 5)
	end

	-- Milestones down the road: the distance to a place that no longer exists.
	if DETAIL >= 2 then
		for i = 1, 4 do
			local z = 120 - i * 60
			block(f, "Milestone", Vector3.new(2.6, 5, 1.8), CFrame.new(-18, 2.5, z) * CFrame.Angles(0, math.rad(jitter(12)), math.rad(jitter(7))), C.stonePale, M.stone)
		end
	end

	-- The second: a burned farm.
	house(f, "Farmhouse", Vector3.new(34, 0, -62), Vector3.new(30, 16, 24), -14, 0.7)
	house(f, "Barn", Vector3.new(58, 0, -40), Vector3.new(24, 20, 34), 8, 0.8)
	fenceRun(f, Vector3.new(20, 0, -20), Vector3.new(20, 0, -90), 0.35)
	fenceRun(f, Vector3.new(20, 0, -90), Vector3.new(78, 0, -90), 0.45)
	cart(f, Vector3.new(-22, 0, -70), 28, true)
	if DETAIL >= 2 then
		trough(f, Vector3.new(48, 0, -74), 12)
		for _ = 1, 5 do
			block(f, "Hay", Vector3.new(rng:NextNumber(4, 7), 3, rng:NextNumber(4, 7)), CFrame.new(64 + jitter(9), 1.5, -58 + jitter(9)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), C.thatch, M.thatch)
		end
		campfire(f, Vector3.new(-30, 0, -46), false)
		tent(f, Vector3.new(-38, 0, -54), 24, 7, true)
		brazier(f, Vector3.new(10, 0, -96), true)
	end
	if DETAIL >= 3 then
		bonePile(f, Vector3.new(40, 0, -50), 8)
		arrowsStuck(f, Vector3.new(30, 0, -44), 6, 5, true)
		rubblePile(f, Vector3.new(52, 0, -30), 9, 10)
		for _ = 1, 8 do
			barrel(f, Vector3.new(rng:NextNumber(24, 70), 0, rng:NextNumber(-84, -24)), rng:NextNumber(0, 360), chance(0.5))
		end
	end

	-- The palisade — thrown up in a hurry, and from the wrong side.
	local pal = group(f, "Palisade")
	for x = -180, 180, 6 do
		if math.abs(x) > 16 then
			mass(pal, "Stake", Vector3.new(5, rng:NextNumber(16, 21), 4), CFrame.new(x, 9, -110) * CFrame.Angles(math.rad(jitter(4)), 0, math.rad(jitter(4))), C.woodDark, M.log)
		end
	end
	block(pal, "GateFrame", Vector3.new(38, 4, 6), CFrame.new(0, 20, -110), C.wood, M.log)
	for side = -1, 1, 2 do
		block(pal, "GatePost", Vector3.new(4, 22, 6), CFrame.new(side * 17, 11, -110), C.wood, M.log)
		torch(pal, Vector3.new(side * 20, 12, -108), if side > 0 then 90 else -90, true)
	end
	if DETAIL >= 2 then
		-- A firing step behind it, and a ladder up.
		block(pal, "Step", Vector3.new(120, 2, 6), CFrame.new(-70, 7, -104), C.wood, M.wood)
		ladder(pal, Vector3.new(-70, 0, -100), 0, 8)
		spearsInGround(pal, Vector3.new(-60, 0, -118), 5, 12)
		spearsInGround(pal, Vector3.new(70, 0, -118), 4, 10)
		shieldPile(pal, Vector3.new(-40, 0, -104), 4)
	end

	print("[World] stage 1 — Outskirts")
end

--==========================================================================
-- STAGE 2 — Village
--==========================================================================
if BUILD.Village then
	local f = area("Area2_Village")
	roadSlab(f, -260, -580, 0, ROAD_W)

	local plots = {
		{ x = -46, z = -310, w = 30, d = 24, a = 4, ruin = 0.35 },
		{ x = -50, z = -360, w = 26, d = 22, a = -6, ruin = 0.75 },
		{ x = -44, z = -408, w = 32, d = 26, a = 2, ruin = 0.5 },
		{ x = -52, z = -462, w = 24, d = 20, a = 9, ruin = 0.85 },
		{ x = -48, z = -516, w = 28, d = 24, a = -4, ruin = 0.65 },
		{ x = 46, z = -324, w = 28, d = 24, a = -3, ruin = 0.6 },
		{ x = 50, z = -374, w = 30, d = 26, a = 5, ruin = 0.3 },
		{ x = 44, z = -424, w = 26, d = 22, a = -8, ruin = 0.8 },
		{ x = 54, z = -476, w = 32, d = 24, a = 1, ruin = 0.55 },
		{ x = 48, z = -528, w = 26, d = 22, a = 7, ruin = 0.7 },
	}
	for i, p in plots do
		house(f, "House" .. i, Vector3.new(p.x, 0, p.z), Vector3.new(p.w, 16, p.d), p.a, p.ruin)
		if DETAIL >= 3 then
			-- Belongings between the houses and the road, dropped in the leaving.
			if chance(0.6) then
				barrel(f, Vector3.new(p.x * 0.62, 0, p.z + jitter(10)), rng:NextNumber(0, 360), chance(0.5))
			end
			if chance(0.5) then
				crate(f, Vector3.new(p.x * 0.6, 0, p.z + jitter(12)), rng:NextNumber(0, 360), rng:NextNumber(3, 5))
			end
			if chance(0.4) then
				sack(f, Vector3.new(p.x * 0.55, 0, p.z + jitter(9)))
			end
			if chance(0.35) then
				bloodstain(f, Vector3.new(p.x * 0.5, 0, p.z + jitter(8)), 6)
			end
		end
	end

	-- The square. The well is boarded over FROM ABOVE.
	local well = group(f, "Well")
	cyl(well, "Ring", 7, 5, Vector3.new(0, 2.5, -392), C.stone, M.stone, true)
	cyl(well, "Bore", 5.4, 5.4, Vector3.new(0, 2.7, -392), C.ash, M.stone)
	for side = -1, 1, 2 do
		block(well, "Post", Vector3.new(1.4, 12, 1.4), CFrame.new(side * 6, 8, -392), C.woodDark, M.log)
	end
	block(well, "Beam", Vector3.new(14, 1.4, 1.4), CFrame.new(0, 14, -392), C.woodDark, M.log)
	chain(well, Vector3.new(0, 13.4, -392), Vector3.new(0, 6, -392), 6)
	for i = -2, 2 do
		block(well, "Board", Vector3.new(3, 0.6, 13), CFrame.new(i * 3.2, 5.4, -392) * CFrame.Angles(0, math.rad(jitter(6)), 0), C.wood, M.wood)
	end
	block(well, "Nailed", Vector3.new(15, 0.5, 1.2), CFrame.new(0, 5.9, -392) * CFrame.Angles(0, math.rad(28), 0), C.woodDark, M.wood)

	-- Furniture in the ROAD: dragged out to build these.
	barricade(f, Vector3.new(0, 0, -340), 0, 46)
	barricade(f, Vector3.new(-18, 0, -440), 74, 30)
	barricade(f, Vector3.new(22, 0, -500), -66, 34)
	cart(f, Vector3.new(14, 0, -360), 96, true)
	cart(f, Vector3.new(-12, 0, -470), -80, true)

	if DETAIL >= 2 then
		marketStall(f, Vector3.new(-22, 0, -386), 12)
		marketStall(f, Vector3.new(24, 0, -400), -104)
		marketStall(f, Vector3.new(-26, 0, -414), 96)
		brazier(f, Vector3.new(12, 0, -392), true)
		brazier(f, Vector3.new(-14, 0, -352), false)
		banner(f, Vector3.new(-30, 0, -330), 90, 14, C.cloth)
		banner(f, Vector3.new(32, 0, -448), -90, 12, C.cloth)
		trough(f, Vector3.new(30, 0, -378), 0)
		weaponRack(f, Vector3.new(-8, 0, -348), 8)
	end

	if DETAIL >= 3 then
		for _ = 1, 14 do
			local z = rng:NextNumber(-540, -300)
			bloodstain(f, Vector3.new(jitter(16), 0, z), rng:NextNumber(4, 8))
		end
		for _ = 1, 9 do
			bonePile(f, Vector3.new(jitter(24), 0, rng:NextNumber(-530, -310)), rng:NextInteger(4, 9))
		end
		for _ = 1, 10 do
			arrowsStuck(f, Vector3.new(jitter(30), 0, rng:NextNumber(-520, -320)), rng:NextInteger(3, 7), 6, true)
		end
		for _ = 1, 6 do
			rubblePile(f, Vector3.new(jitter(50), 0, rng:NextNumber(-520, -310)), 8, 9)
		end
		for _ = 1, 5 do
			wagonWheel(f, Vector3.new(jitter(34), 0, rng:NextNumber(-500, -330)), rng:NextNumber(0, 360), chance(0.5))
		end
		hangingCloth(f, Vector3.new(-40, 14, -344), 0, 8, 9, C.clothPale)
		hangingCloth(f, Vector3.new(42, 13, -398), 180, 7, 8, C.cloth)
	end

	-- The chapel: the only building with its walls whole. That is its own statement.
	local chapel = group(f, "Chapel")
	ruinedWall(chapel, "Wall", Vector3.new(-104, 0, -400), Vector3.new(-104, 0, -450), 22, 4, {}, C.stonePale, M.stone)
	ruinedWall(chapel, "Wall", Vector3.new(-70, 0, -400), Vector3.new(-70, 0, -450), 22, 4, {}, C.stonePale, M.stone)
	ruinedWall(chapel, "Wall", Vector3.new(-104, 0, -450), Vector3.new(-70, 0, -450), 22, 4, {}, C.stonePale, M.stone)
	ruinedWall(chapel, "Wall", Vector3.new(-104, 0, -400), Vector3.new(-70, 0, -400), 22, 4, { { 0.4, 0.6, 0 } }, C.stonePale, M.stone)
	for i = 0, 5 do
		wedge(chapel, "Roof", Vector3.new(36, 9, 9), CFrame.new(-87, 24 + i * 0.2, -404 - i * 8.5) * CFrame.Angles(0, math.rad(90), 0), C.woodDark, M.wood)
	end
	tower(chapel, "BellTower", Vector3.new(-87, 0, -394), 9, 34, { crown = false, lean = 3 })
	block(chapel, "Bell", Vector3.new(6, 6, 6), CFrame.new(-79, 3, -388) * CFrame.Angles(0.4, 0.8, 0.2), C.rust, M.rusted)
	if DETAIL >= 2 then
		archway(chapel, Vector3.new(-87, 0, -400), 0, 8, 12, 4)
		block(chapel, "Altar", Vector3.new(10, 4, 4), CFrame.new(-87, 2, -444), C.stonePale, M.stone)
		for _, x in { -98, -76 } do
			brokenColumn(chapel, Vector3.new(x, 0, -420), 14, false)
		end
		for i = 0, 3 do
			block(chapel, "Pew", Vector3.new(18, 1, 2.4), CFrame.new(-87, 2, -412 - i * 7) * CFrame.Angles(0, math.rad(jitter(5)), 0), C.woodDark, M.wood)
		end
		torch(chapel, Vector3.new(-101, 12, -420), 90, true)
		torch(chapel, Vector3.new(-73, 12, -420), -90, true)
	end
	if DETAIL >= 3 then
		-- A graveyard behind it, which is where the village kept its dead before
		-- there were too many to keep.
		for row = 0, 2 do
			for i = 0, 4 do
				grave(chapel, Vector3.new(-118 - row * 14, 0, -404 - i * 13 + jitter(2)), jitter(9))
			end
		end
		fenceRun(chapel, Vector3.new(-140, 0, -396), Vector3.new(-140, 0, -462), 0.3)
		bonePile(chapel, Vector3.new(-92, 0, -456), 10)
	end

	print("[World] stage 2 — Village")
end

--==========================================================================
-- STAGE 3 — Crossing
--==========================================================================
if BUILD.Crossing then
	local f = area("Area3_Bridge")
	roadSlab(f, -680, -800, 0, ROAD_W)
	roadSlab(f, -880, -1000, 0, ROAD_W)

	local bridge = group(f, "Bridge")
	local function span(fromZ, toZ)
		mass(bridge, "Deck", Vector3.new(30, 4, math.abs(toZ - fromZ)), CFrame.new(0, 0, (fromZ + toZ) / 2), C.stone, M.stone)
		for side = -1, 1, 2 do
			block(bridge, "Parapet", Vector3.new(2.5, 7, math.abs(toZ - fromZ)), CFrame.new(side * 14, 5, (fromZ + toZ) / 2), C.stoneDark, M.stone)
			if DETAIL >= 2 then
				for z = math.min(fromZ, toZ) + 4, math.max(fromZ, toZ) - 4, 9 do
					block(bridge, "Capstone", Vector3.new(3.4, 1, 5), CFrame.new(side * 14, 8.8, z), C.stonePale, M.stone)
				end
			end
		end
	end
	span(-800, -826)
	span(-856, -880)

	for _, z in { -813, -868 } do
		for i = 0, 7 do
			local a = math.pi * (i / 7)
			cyl(bridge, "Arch", 3, 30, Vector3.new(math.cos(a) * 13, -2 - math.sin(a) * 13, z), C.stone, M.stone)
		end
	end

	-- Planks thrown across since, by someone who came after.
	for i = -3, 3 do
		block(bridge, "Plank", Vector3.new(3.4, 0.8, 34), CFrame.new(i * 4 + jitter(1), -0.4, -841) * CFrame.Angles(0, math.rad(jitter(4)), math.rad(jitter(3))), C.wood, M.wood)
	end
	if DETAIL >= 2 then
		-- Ropes lashing the planks to what is left of the stone.
		for side = -1, 1, 2 do
			chain(bridge, Vector3.new(side * 12, 2, -827), Vector3.new(side * 12, -1, -840), 5)
			chain(bridge, Vector3.new(side * 12, 2, -855), Vector3.new(side * 12, -1, -842), 5)
		end
	end
	for _ = 1, 8 do
		block(bridge, "Fallen", Vector3.new(rng:NextNumber(8, 18), rng:NextNumber(4, 9), rng:NextNumber(8, 16)), CFrame.new(jitter(22), -34 + jitter(3), -841 + jitter(18)) * CFrame.Angles(jitter(0.6), rng:NextNumber(0, 3), jitter(0.6)), C.stone, M.stone)
	end

	tower(f, "TowerNear", Vector3.new(-40, 0, -792), 12, 46, { roof = true, gaps = 0.2, torch = true })
	tower(f, "TowerFar", Vector3.new(40, 0, -888), 12, 40, { crown = false, lean = 5 })
	house(f, "Tollhouse", Vector3.new(44, 0, -770), Vector3.new(20, 14, 18), -12, 0.45)

	if DETAIL >= 2 then
		ladder(f, Vector3.new(-40, 0, -780), 0, 22)
		barricade(f, Vector3.new(0, 0, -790), 0, 34)
		spearsInGround(f, Vector3.new(-14, 0, -784), 6, 10)
		brazier(f, Vector3.new(16, 0, -796), true)
		-- Warning boards nailed up on the near side, facing the way you came.
		for _, x in { -22, 22 } do
			block(f, "WarningPost", Vector3.new(1.2, 11, 1.2), CFrame.new(x, 5.5, -770), C.woodDark, M.log)
			block(f, "WarningBoard", Vector3.new(9, 5, 0.6), CFrame.new(x, 10, -770) * CFrame.Angles(0, math.rad(jitter(10)), math.rad(jitter(6))), C.wood, M.wood)
		end
	end
	if DETAIL >= 3 then
		bonePile(f, Vector3.new(-8, 0, -795), 9)
		bloodstain(f, Vector3.new(0, 0, -806), 9)
		arrowsStuck(f, Vector3.new(6, 0, -798), 9, 8, true)
		rubblePile(f, Vector3.new(-30, 0, -830), 10, 12)
		rubblePile(f, Vector3.new(34, 0, -856), 10, 12)
		for _ = 1, 4 do
			barrel(f, Vector3.new(jitter(30), 0, rng:NextNumber(-790, -770)), rng:NextNumber(0, 360), true)
		end
	end

	print("[World] stage 3 — Crossing")
end

--==========================================================================
-- STAGE 4 — Siegeground
--==========================================================================
if BUILD.Siegeground then
	local f = area("Area4_Courtyard")
	roadSlab(f, -1080, -1450, 0, ROAD_W)

	trebuchet(f, Vector3.new(-72, 0, -1180), 8)
	trebuchet(f, Vector3.new(78, 0, -1226), -6)
	trebuchet(f, Vector3.new(-58, 0, -1300), 14)

	local ram = group(f, "Ram")
	block(ram, "Log", Vector3.new(5, 5, 40), CFrame.new(6, 8, -1370) * CFrame.Angles(0, math.rad(6), 0), C.woodDark, M.log)
	block(ram, "Head", Vector3.new(6, 6, 7), CFrame.new(8, 8, -1390), C.iron, M.iron)
	for side = -1, 1, 2 do
		block(ram, "Frame", Vector3.new(1.8, 16, 36), CFrame.new(6 + side * 6, 9, -1368), C.wood, M.log)
	end
	block(ram, "Canopy", Vector3.new(16, 1.4, 38), CFrame.new(6, 17, -1368) * CFrame.Angles(math.rad(3), 0, 0), C.wood, M.wood)
	if DETAIL >= 2 then
		chain(ram, Vector3.new(6, 16, -1352), Vector3.new(6, 9, -1356), 5)
		chain(ram, Vector3.new(6, 16, -1384), Vector3.new(6, 9, -1382), 5)
		for side = -1, 1, 2 do
			wagonWheel(ram, Vector3.new(6 + side * 7, 0, -1356), 0, false)
			wagonWheel(ram, Vector3.new(6 + side * 7, 0, -1380), 0, false)
		end
	end

	-- The siege camp: they lived out here long enough to dig in.
	if DETAIL >= 2 then
		for i = 1, 9 do
			local x = -230 + (i % 3) * 34
			local z = -1160 - math.floor(i / 3) * 40
			tent(f, Vector3.new(x, 0, z), jitter(20), rng:NextNumber(7, 10), chance(0.35))
		end
		for i = 1, 4 do
			campfire(f, Vector3.new(-212 + i * 30, 0, -1195 - i * 26), chance(0.4))
		end
		for i = 1, 6 do
			tent(f, Vector3.new(190 + jitter(40), 0, -1200 - i * 26), jitter(24), rng:NextNumber(7, 10), chance(0.5))
		end
		weaponRack(f, Vector3.new(-176, 0, -1216), 82)
		weaponRack(f, Vector3.new(206, 0, -1256), -84)
		for _ = 1, 5 do
			shieldPile(f, Vector3.new(rng:NextNumber(-230, -150), 0, rng:NextNumber(-1300, -1150)), rng:NextInteger(3, 6))
		end
		banner(f, Vector3.new(-200, 0, -1150), 4, 18, C.cloth)
		banner(f, Vector3.new(200, 0, -1178), -4, 18, C.cloth)
		anvilAndForge(f, Vector3.new(-196, 0, -1268), 90, false)
	end

	-- Cairns in rows: somebody had time to bury these. Then nobody had time to
	-- bury the ones who did the burying.
	for row = 0, 3 do
		for i = 0, 7 do
			cairn(f, Vector3.new(-150 + i * 15 + jitter(2), 0, -1240 - row * 22 + jitter(3)), rng:NextNumber(3, 5))
		end
	end
	for i = 1, 9 do
		cairn(f, Vector3.new(110 + jitter(40), 0, -1200 - i * 18 + jitter(6)), rng:NextNumber(3, 5))
	end
	if DETAIL >= 3 then
		for row = 0, 2 do
			for i = 0, 6 do
				grave(f, Vector3.new(-120 + i * 16 + jitter(2), 0, -1330 - row * 15), jitter(6))
			end
		end
	end

	for x = -260, -120, 7 do
		block(f, "SiegeStake", Vector3.new(5, rng:NextNumber(12, 17), 4), CFrame.new(x, 7, -1150) * CFrame.Angles(math.rad(-20), 0, 0), C.woodDark, M.log)
	end
	if DETAIL >= 3 then
		for _ = 1, 16 do
			rubblePile(f, Vector3.new(jitter(200), 0, rng:NextNumber(-1420, -1150)), 9, 8)
		end
		for _ = 1, 18 do
			arrowsStuck(f, Vector3.new(jitter(180), 0, rng:NextNumber(-1430, -1160)), rng:NextInteger(4, 9), 9, true)
		end
		for _ = 1, 14 do
			bonePile(f, Vector3.new(jitter(190), 0, rng:NextNumber(-1430, -1160)), rng:NextInteger(5, 11))
		end
		for _ = 1, 10 do
			bloodstain(f, Vector3.new(jitter(120), 0, rng:NextNumber(-1440, -1350)), rng:NextNumber(6, 12))
		end
		spearsInGround(f, Vector3.new(0, 0, -1410), 14, 40)
	end

	-- The barbican: the outer gate, torn open.
	local barb = group(f, "Barbican")
	ruinedWall(barb, "Wall", Vector3.new(-200, 0, -1450), Vector3.new(-24, 0, -1450), 40, 12, { { 0.7, 0.85, 0.35 } }, C.stone, M.stone)
	ruinedWall(barb, "Wall", Vector3.new(24, 0, -1450), Vector3.new(200, 0, -1450), 40, 12, { { 0.2, 0.38, 0 } }, C.stone, M.stone)
	crenellate(barb, Vector3.new(-200, 0, -1450), Vector3.new(-24, 0, -1450), 40, 12, C.stoneDark)
	crenellate(barb, Vector3.new(24, 0, -1450), Vector3.new(200, 0, -1450), 40, 12, C.stoneDark)
	tower(barb, "BarbicanW", Vector3.new(-30, 0, -1450), 16, 56, { gaps = 0.3, torch = true })
	tower(barb, "BarbicanE", Vector3.new(30, 0, -1450), 16, 48, { crown = false })
	block(barb, "Lintel", Vector3.new(64, 10, 16), CFrame.new(0, 44, -1450), C.stoneDark, M.stone)
	block(barb, "BrokenGate", Vector3.new(34, 2.4, 40), CFrame.new(-6, 1.6, -1424) * CFrame.Angles(0, math.rad(12), 0), C.woodDark, M.wood)
	if DETAIL >= 2 then
		portcullis(barb, Vector3.new(0, 0, -1450), 0, 44, 40, 0.42)
		buttress(barb, Vector3.new(-90, 0, -1450), 0, 40, 10)
		buttress(barb, Vector3.new(120, 0, -1450), 0, 40, 10)
		rubblePile(barb, Vector3.new(150, 0, -1448), 16, 22)
	end

	print("[World] stage 4 — Siegeground")
end

--==========================================================================
-- STAGE 5 — Castle
--==========================================================================
if BUILD.Castle then
	local f = area("Area5_Castle")
	local CX, CZ = 0, -1900
	local COURT = 460
	local half = COURT / 2
	local WALL_H, WALL_T = 62, 16
	local PLINTH_H = 26
	local baseY = PLINTH_H

	roadSlab(f, -1520, -1660, 0, ROAD_W)
	mass(f, "Plinth", Vector3.new(COURT + 120, PLINTH_H, COURT + 120), CFrame.new(CX, PLINTH_H / 2, CZ), C.rock, M.rock)
	wedge(f, "Causeway", Vector3.new(56, PLINTH_H, 90), CFrame.new(CX, PLINTH_H / 2, CZ + half + 100) * CFrame.Angles(0, math.rad(180), 0), C.rock, M.rock)

	local nearZ, farZ = CZ + half, CZ - half
	local leftX, rightX = CX - half, CX + half
	local gateHalf = 30

	local walls = group(f, "Walls")
	local function side(name, from, to, breaks)
		local a = Vector3.new(from.X, baseY, from.Z)
		local b = Vector3.new(to.X, baseY, to.Z)
		ruinedWall(walls, name, a, b, WALL_H, WALL_T, breaks, C.stone, M.stone)
		crenellate(walls, a, b, baseY + WALL_H, WALL_T, C.stoneDark)
		if DETAIL >= 2 then
			local inward = (Vector3.new(CX, baseY, CZ) - (a + b) / 2)
			inward = Vector3.new(inward.X, 0, inward.Z).Unit
			wallWalk(walls, a, b, baseY + WALL_H - 1, 10, inward)
		end
	end

	side("WallFront", Vector3.new(leftX, 0, nearZ), Vector3.new(CX - gateHalf, 0, nearZ), { { 0.6, 0.78, 0.45 } })
	side("WallFront", Vector3.new(CX + gateHalf, 0, nearZ), Vector3.new(rightX, 0, nearZ), {})
	side("WallLeft", Vector3.new(leftX, 0, nearZ), Vector3.new(leftX, 0, farZ), { { 0.36, 0.56, 0 }, { 0.56, 0.72, 0.4 } })
	side("WallRight", Vector3.new(rightX, 0, nearZ), Vector3.new(rightX, 0, farZ), { { 0.72, 0.84, 0.5 } })
	side("WallBack", Vector3.new(leftX, 0, farZ), Vector3.new(rightX, 0, farZ), { { 0.22, 0.36, 0.6 } })

	if DETAIL >= 2 then
		for i = -1, 1 do
			buttress(walls, Vector3.new(leftX, baseY, CZ + i * 130), 90, WALL_H, 14)
			buttress(walls, Vector3.new(rightX, baseY, CZ + i * 130), -90, WALL_H, 14)
			buttress(walls, Vector3.new(CX + i * 130, baseY, farZ), 180, WALL_H, 14)
		end
	end

	local towers = group(f, "Towers")
	local TR, TH = 27, 96
	tower(towers, "TowerNW", Vector3.new(leftX, baseY, farZ), TR, TH, { gaps = 0.25, torch = true })
	tower(towers, "TowerNE", Vector3.new(rightX, baseY, farZ), TR, TH * 0.68, { crown = false })
	tower(towers, "TowerSW", Vector3.new(leftX, baseY, nearZ), TR, TH, { lean = 4, gaps = 0.4 })
	tower(towers, "TowerSE", Vector3.new(rightX, baseY, nearZ), TR, TH, { roof = true, torch = true })
	tower(towers, "TowerWMid", Vector3.new(leftX, baseY, CZ), TR * 0.8, TH * 0.85, { crown = false })
	tower(towers, "TowerEMid", Vector3.new(rightX, baseY, CZ), TR * 0.8, TH * 0.9, { roof = true, gaps = 0.2 })
	tower(towers, "TowerNMid", Vector3.new(CX, baseY, farZ), TR * 0.8, TH * 0.88, { gaps = 0.3 })
	tower(towers, "GateW", Vector3.new(CX - gateHalf - 18, baseY, nearZ), TR * 1.05, TH * 1.2, { gaps = 0.15, torch = true })
	tower(towers, "GateE", Vector3.new(CX + gateHalf + 18, baseY, nearZ), TR * 1.05, TH * 1.2, { gaps = 0.15, torch = true })
	block(towers, "GateLintel", Vector3.new(gateHalf * 2 + 26, 18, WALL_T + 8), CFrame.new(CX, baseY + 50, nearZ), C.stoneDark, M.stone)
	if DETAIL >= 2 then
		portcullis(towers, Vector3.new(CX, baseY, nearZ), 0, gateHalf * 2, 50, 0.6)
		archway(towers, Vector3.new(CX, baseY, nearZ + 12), 0, gateHalf * 2 - 6, 34, 8)
		-- Murder holes above the passage. Somebody planned for this.
		for i = -2, 2 do
			block(towers, "MurderHole", Vector3.new(4, 3, 4), CFrame.new(CX + i * 10, baseY + 42, nearZ - 6), C.ash, M.stone)
		end
	end

	-- Inside: a courtyard that was lived in.
	local inner = group(f, "Inner")
	local hallZ = CZ + 40
	ruinedWall(inner, "HallWall", Vector3.new(CX - 70, baseY, hallZ - 60), Vector3.new(CX - 70, baseY, hallZ + 60), 40, 6, { { 0.5, 0.7, 0.4 } }, C.stonePale, M.stone)
	ruinedWall(inner, "HallWall", Vector3.new(CX + 70, baseY, hallZ - 60), Vector3.new(CX + 70, baseY, hallZ + 60), 40, 6, { { 0.2, 0.34, 0 } }, C.stonePale, M.stone)
	ruinedWall(inner, "HallWall", Vector3.new(CX - 70, baseY, hallZ - 60), Vector3.new(CX + 70, baseY, hallZ - 60), 40, 6, { { 0.44, 0.58, 0 } }, C.stonePale, M.stone)
	for i = -2, 2 do
		for s = -1, 1, 2 do
			brokenColumn(inner, Vector3.new(CX + s * 44, baseY, hallZ + i * 26), 34, chance(0.25))
		end
	end
	for _ = 1, 7 do
		block(inner, "FallenBeam", Vector3.new(3, 3, rng:NextNumber(30, 70)), CFrame.new(CX + jitter(60), baseY + rng:NextNumber(1, 6), hallZ + jitter(55)) * CFrame.Angles(jitter(0.4), rng:NextNumber(0, 3), jitter(0.3)), C.woodDark, M.log)
	end
	if DETAIL >= 2 then
		-- The high table, still where it stood.
		block(inner, "HighTable", Vector3.new(40, 1.4, 6), CFrame.new(CX, baseY + 5, hallZ - 48), C.woodDark, M.wood)
		for s = -1, 1, 2 do
			block(inner, "TableLeg", Vector3.new(2, 5, 5), CFrame.new(CX + s * 17, baseY + 2.5, hallZ - 48), C.woodDark, M.log)
		end
		for i = -1, 1 do
			block(inner, "Bench", Vector3.new(6, 1.2, 44), CFrame.new(CX + i * 26, baseY + 3, hallZ + 4) * CFrame.Angles(0, 0, if chance(0.4) then math.rad(52) else 0), C.woodDark, M.wood)
		end
		for _, s in { -1, 1 } do
			banner(inner, Vector3.new(CX + s * 66, baseY + 36, hallZ + 10), if s > 0 then -90 else 90, 22, C.cloth)
		end
		torch(inner, Vector3.new(CX - 68, baseY + 22, hallZ), 90, true)
		torch(inner, Vector3.new(CX + 68, baseY + 22, hallZ), -90, true)
		brazier(inner, Vector3.new(CX, baseY, hallZ + 30), true)
	end

	house(inner, "Stables", Vector3.new(CX - 140, baseY, CZ + 90), Vector3.new(36, 18, 70), 0, 0.6)
	house(inner, "Chapel", Vector3.new(CX - 145, baseY, CZ - 60), Vector3.new(34, 24, 46), 0, 0.3)
	house(inner, "Barracks", Vector3.new(CX + 140, baseY, CZ + 70), Vector3.new(36, 18, 80), 0, 0.7)
	house(inner, "Smithy", Vector3.new(CX + 138, baseY, CZ - 50), Vector3.new(30, 16, 34), 0, 0.5)
	if DETAIL >= 2 then
		for i = 0, 3 do
			trough(inner, Vector3.new(CX - 140, baseY, CZ + 66 + i * 16), 90)
		end
		anvilAndForge(inner, Vector3.new(CX + 138, baseY, CZ - 50), -90, true)
		for i = 0, 3 do
			block(inner, "Bunk", Vector3.new(6, 1, 14), CFrame.new(CX + 132, baseY + 3 + (i % 2) * 6, CZ + 46 + math.floor(i / 2) * 20), C.woodDark, M.wood)
		end
		weaponRack(inner, Vector3.new(CX + 150, baseY, CZ + 100), 180)
	end

	-- The keep, split open at the top.
	local KEEP = Vector3.new(160, 200, 130)
	local keepZ = CZ - 110
	mass(inner, "Keep", KEEP, CFrame.new(CX, baseY + KEEP.Y / 2, keepZ), C.stone, M.stone)
	mass(inner, "KeepBreak", Vector3.new(KEEP.X * 0.5, KEEP.Y * 0.2, KEEP.Z * 0.55), CFrame.new(CX + KEEP.X * 0.26, baseY + KEEP.Y - KEEP.Y * 0.08, keepZ + KEEP.Z * 0.22) * CFrame.Angles(0, 0, math.rad(7)), C.stoneDark, M.stone)
	for i = 0, 9 do
		local a = (math.pi * 2 / 10) * i
		block(inner, "KeepMerlon", Vector3.new(15, 11, 15), CFrame.new(CX + math.cos(a) * (KEEP.X / 2 - 9), baseY + KEEP.Y + 5, keepZ + math.sin(a) * (KEEP.Z / 2 - 9)), C.stoneDark, M.stone)
	end
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			tower(inner, "KeepTurret", Vector3.new(CX + sx * (KEEP.X / 2 - 6), baseY + KEEP.Y - 30, keepZ + sz * (KEEP.Z / 2 - 6)), 9, 44, { roof = sx ~= sz, crown = sx == sz })
		end
	end
	doorway(inner, CFrame.new(CX, baseY, keepZ + KEEP.Z / 2 + 1), 16, 30, "hanging")
	if DETAIL >= 2 then
		-- Arrow loops and string courses up the keep's face.
		for level = 1, 5 do
			for i = -1, 1 do
				arrowLoop(inner, CFrame.new(CX + i * 46, baseY + 26 + level * 32, keepZ + KEEP.Z / 2 + 0.6))
			end
			block(inner, "StringCourse", Vector3.new(KEEP.X + 4, 2, KEEP.Z + 4), CFrame.new(CX, baseY + 20 + level * 34, keepZ), C.stoneDark, M.stone)
		end
		stairs(inner, Vector3.new(CX + 30, baseY, keepZ + KEEP.Z / 2 + 24), Vector3.new(CX + 30, baseY + 14, keepZ + KEEP.Z / 2 + 2), 12, 8)
		banner(inner, Vector3.new(CX - 20, baseY + 60, keepZ + KEEP.Z / 2 + 1), 0, 30, C.cloth)
		banner(inner, Vector3.new(CX + 20, baseY + 60, keepZ + KEEP.Z / 2 + 1), 0, 30, C.cloth)
	end

	if DETAIL >= 2 then
		-- The courtyard itself: a well, a monument, and the gallows nobody took down.
		cyl(inner, "CourtWell", 8, 6, Vector3.new(CX - 60, baseY + 3, CZ + 130), C.stone, M.stone, true)
		cyl(inner, "CourtWellBore", 6, 6.2, Vector3.new(CX - 60, baseY + 3.2, CZ + 130), C.ash, M.stone)
		statue(inner, Vector3.new(CX + 60, baseY, CZ + 130), 180, 14, true)
		block(inner, "GallowsPost", Vector3.new(2.6, 26, 2.6), CFrame.new(CX + 96, baseY + 13, CZ + 170), C.woodDark, M.log)
		block(inner, "GallowsPost", Vector3.new(2.6, 26, 2.6), CFrame.new(CX + 120, baseY + 13, CZ + 170), C.woodDark, M.log)
		block(inner, "GallowsBeam", Vector3.new(28, 2.4, 2.4), CFrame.new(CX + 108, baseY + 25, CZ + 170), C.woodDark, M.log)
		for _, x in { 100, 108, 116 } do
			chain(inner, Vector3.new(CX + x, baseY + 24, CZ + 170), Vector3.new(CX + x, baseY + 14, CZ + 170), 4)
		end
	end

	if DETAIL >= 3 then
		for _ = 1, 40 do
			local a = rng:NextNumber() * math.pi * 2
			local d = rng:NextNumber(0, 110)
			rubblePile(f, Vector3.new(leftX + math.cos(a) * d * 0.6, baseY, CZ + math.sin(a) * d), 8, 4)
		end
		for _ = 1, 16 do
			bonePile(inner, Vector3.new(CX + jitter(180), baseY, CZ + jitter(180)), rng:NextInteger(5, 12))
		end
		for _ = 1, 12 do
			bloodstain(inner, Vector3.new(CX + jitter(160), baseY, CZ + jitter(160)), rng:NextNumber(6, 13))
		end
		for _ = 1, 14 do
			arrowsStuck(inner, Vector3.new(CX + jitter(170), baseY, CZ + jitter(170)), rng:NextInteger(4, 9), 8, true)
		end
		for _ = 1, 10 do
			shieldPile(inner, Vector3.new(CX + jitter(150), baseY, CZ + jitter(150)), rng:NextInteger(3, 6))
		end
		spearsInGround(inner, Vector3.new(CX, baseY, CZ + 190), 16, 60)
	end

	pcall(function()
		(f :: any).ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	print("[World] stage 5 — Castle")
end

--==========================================================================
-- The gorge
--==========================================================================
if BUILD.Gorge then
	for x = -700, 700, 50 do
		workspace.Terrain:FillBlock(CFrame.new(x + 25, -30, -841), Vector3.new(50, 120, 62), Enum.Material.Air)
		workspace.Terrain:FillBlock(CFrame.new(x + 25, -74, -841), Vector3.new(50, 32, 62), Enum.Material.Water)
		task.wait()
	end
	print("[World] gorge carved and flooded at z=-841")
end

--==========================================================================
print(("[World] DONE — %d parts, %d lights, detail level %d."):format(made, lightsUsed, DETAIL))
print("Landmarks: platform z=+235 | cairn z=-30 | farm z=-62 | palisade z=-110")
print("           village z=-310..-530 | chapel z=-420 | bridge z=-841")
print("           siege camp z=-1160..-1330 | barbican z=-1450 | castle gate z=-1670 | keep z=-2010")
print("If it costs frames, set DETAIL = 2 (or 1) at the top and run again.")
