--[[
	BuildWorld — run in the Studio Command Bar of the FORGOTTEN LANDS place,
	in EDIT MODE. Select the whole file (Ctrl+A), copy, paste, Enter.

	Builds the entire road home: five stages from the rail platform where the
	train drops you to the breached walls of the castle. See docs/systems/
	WorldLayout.md for what each stage is saying.

	THE PRINCIPLE: every ruin here is placed to be read, never scattered. A wall
	that is evenly damaged everywhere reads as texture; a wall with two breaches
	reads as a siege. Furniture is in the road rather than in the houses because
	it was dragged out to build barricades. The bridge is cut cleanly from the
	near bank because somebody blew it on purpose, trying to stop something
	crossing toward the castle — and failed. A player who never reads a line of
	dialogue should still learn the story by walking through it.

	This is a SKELETON, not a finished world. It gives you streets, walls, roofs
	and silhouettes at the right scale and in the right places. Torches, banners,
	corpses, barrels, sound and the thousand small lies that make a place feel
	lived in are yours to add on top — that is where it stops being a diagram.

	Everything lands under `Workspace.Gameplay.<Stage>.Structure`. Re-running a
	stage replaces only that stage's Structure folder, so you can rebuild one
	part of the road without losing your work on the others. Turn stages off
	below once you are happy with them.

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
	thatch = Color3.fromRGB(96, 82, 52),
	iron = Color3.fromRGB(58, 50, 46),
	rust = Color3.fromRGB(94, 58, 40),
	road = Color3.fromRGB(92, 80, 66),
	cloth = Color3.fromRGB(96, 40, 44),
}

local M = {
	stone = Enum.Material.Slate,
	rock = Enum.Material.Rock,
	wood = Enum.Material.WoodPlanks,
	log = Enum.Material.Wood,
	thatch = Enum.Material.Grass,
	iron = Enum.Material.Metal,
	road = Enum.Material.Ground,
	cloth = Enum.Material.Fabric,
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

local function area(name: string): Folder
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
	return structure :: any
end

local function group(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

-- Small parts do not cast shadows. There are thousands of them, they are
-- mostly seen at a distance, and shadows are the most expensive thing about a
-- build this size.
local function block(parent, name, size, cf, colour, material, shadow): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.Color = colour
	part.Material = material or M.stone
	part.CastShadow = shadow ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	made += 1
	return part
end

local function wedge(parent, name, size, cf, colour, material): WedgePart
	local part = Instance.new("WedgePart")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.Color = colour
	part.Material = material or M.stone
	part.CastShadow = false
	part.Parent = parent
	made += 1
	return part
end

-- A cylinder part points along X, so it has to be stood upright.
local function cyl(parent, name, radius, height, at, colour, material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.Size = Vector3.new(height, radius * 2, radius * 2)
	part.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	part.Color = colour
	part.Material = material or M.stone
	part.Parent = parent
	made += 1
	return part
end

local function jitter(amount: number): number
	return rng:NextNumber(-amount, amount)
end

--==========================================================================
-- Composites
--==========================================================================

--[[
	A wall built from vertical strips, so pieces of it can be missing or
	shortened. `breaks` is a list of {startFraction, endFraction, heightScale}
	where a heightScale of 0 removes the strip entirely.
]]
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
			local size = if alongX
				then Vector3.new(segLen + 0.4, h, thickness)
				else Vector3.new(thickness, h, segLen + 0.4)
			block(
				parent,
				name,
				size,
				CFrame.new(at.X, from.Y + h / 2, at.Z),
				colour or C.stone,
				material or M.stone
			)
		end
	end
end

local function crenellate(parent, from: Vector3, to: Vector3, top: number, thickness, colour)
	local span = to - from
	local length = span.Magnitude
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
			M.stone,
			false
		)
	end
end

local function tower(parent, name, at: Vector3, radius, height, opts)
	opts = opts or {}
	local model = group(parent, name)
	local body = cyl(model, "Body", radius, height, Vector3.new(at.X, at.Y + height / 2, at.Z), C.stone, M.stone)

	if opts.lean then
		body.CFrame = CFrame.new(body.Position)
			* CFrame.Angles(math.rad(opts.lean), 0, math.rad(opts.lean * 0.7))
			* CFrame.Angles(0, 0, math.rad(90))
	end

	-- A ring of merlons, unless the top has come off.
	if opts.crown ~= false then
		local top = at.Y + height + 3
		local n = math.max(8, math.floor(radius / 2))
		for i = 0, n - 1 do
			local a = (math.pi * 2 / n) * i
			if not (opts.gaps and rng:NextNumber() < opts.gaps) then
				block(
					model,
					"Merlon",
					Vector3.new(radius * 0.34, 8, radius * 0.34),
					CFrame.new(at.X + math.cos(a) * (radius - 3), top, at.Z + math.sin(a) * (radius - 3))
						* CFrame.Angles(0, -a, 0),
					C.stoneDark,
					M.stone,
					false
				)
			end
		end
	end

	-- A conical roof, for towers that still have one.
	if opts.roof then
		local peak = at.Y + height + (opts.crown ~= false and 8 or 0)
		for step = 1, 5 do
			local t = step / 5
			cyl(
				model,
				"Roof",
				radius * (1 - t) * 1.05 + 1,
				7,
				Vector3.new(at.X, peak + step * 6, at.Z),
				C.woodDark,
				M.wood
			)
		end
	end
	return model
end

--[[
	A house: four walls, openings for a door and windows, and a roof that is
	usually gone. `ruin` from 0 (intact) to 1 (little left standing).
]]
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

	-- The front wall has the door; the others take damage instead.
	local doorGap = { { 0.42, 0.6, 0 } }
	local sideBreaks = if ruin > 0.5
		then { { 0.3, 0.55, 0 }, { 0.55, 0.75, 0.45 } }
		else { { 0.62, 0.78, 0.55 } }

	ruinedWall(model, "Wall", a, b, h, t, doorGap, C.stone, M.stone)
	ruinedWall(model, "Wall", b, c, h * (1 - ruin * 0.25), t, sideBreaks, C.stone, M.stone)
	ruinedWall(model, "Wall", c, d, h * (1 - ruin * 0.4), t, if ruin > 0.6 then { { 0.2, 0.7, 0 } } else {}, C.stone, M.stone)
	ruinedWall(model, "Wall", d, a, h * (1 - ruin * 0.25), t, sideBreaks, C.stone, M.stone)

	-- Roof: only the least ruined houses keep any of it, and never all of it.
	if ruin < 0.45 then
		local ridge = h + size.Z * 0.32
		for side = -1, 1, 2 do
			for strip = 0, 3 do
				local frac = strip / 4
				if not (strip == 3 and ruin > 0.2) then
					local width = size.X * 0.28
					block(
						model,
						"Roof",
						Vector3.new(size.X + 3, 1.6, width),
						base
							* CFrame.new(0, h + (ridge - h) * (1 - frac), side * (hz * (frac + 0.12)))
							* CFrame.Angles(math.rad(side * -32), 0, 0),
						C.thatch,
						M.thatch,
						false
					)
				end
			end
		end
	else
		-- Fallen beams where the roof used to be.
		for i = 1, 4 do
			block(
				model,
				"Beam",
				Vector3.new(2, 2, size.Z * rng:NextNumber(0.5, 0.95)),
				base * CFrame.new(jitter(hx * 0.7), rng:NextNumber(2, h * 0.5), jitter(hz * 0.3))
					* CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)),
				C.woodDark,
				M.log,
				false
			)
		end
	end

	return model
end

local function roadSlab(parent, fromZ: number, toZ: number, x: number, width: number)
	local length = math.abs(toZ - fromZ)
	block(
		parent,
		"Road",
		Vector3.new(width, 1.2, length),
		CFrame.new(x, 0.6, (fromZ + toZ) / 2),
		C.road,
		M.road,
		false
	)
end

local function barricade(parent, at: Vector3, angle: number, length: number)
	local model = group(parent, "Barricade")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	for i = 1, math.floor(length / 5) do
		local x = -length / 2 + i * 5
		block(
			model,
			"Plank",
			Vector3.new(4.6, rng:NextNumber(3, 7), 1.4),
			base * CFrame.new(x, rng:NextNumber(1.5, 3.5), jitter(0.8)) * CFrame.Angles(0, 0, math.rad(jitter(14))),
			C.wood,
			M.wood,
			false
		)
	end
	-- Stakes angled outward: this was built to stop something, not to look neat.
	for i = 1, 4 do
		block(
			model,
			"Stake",
			Vector3.new(1.2, 9, 1.2),
			base * CFrame.new(jitter(length / 2), 3, 2.5) * CFrame.Angles(math.rad(38), 0, 0),
			C.woodDark,
			M.log,
			false
		)
	end
	return model
end

local function cairn(parent, at: Vector3, size: number)
	local model = group(parent, "Cairn")
	local layers = math.max(3, math.floor(size))
	for i = 1, layers do
		local t = i / layers
		block(
			model,
			"Stone",
			Vector3.new(size * (1 - t * 0.75) + 1, 1.6, size * (1 - t * 0.75) + 1),
			CFrame.new(at.X + jitter(0.6), at.Y + i * 1.5, at.Z + jitter(0.6))
				* CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			C.rock,
			M.rock,
			false
		)
	end
	return model
end

local function cart(parent, at: Vector3, angle: number, wrecked: boolean)
	local model = group(parent, "Cart")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)
	local tilt = if wrecked then math.rad(24) else 0

	block(model, "Bed", Vector3.new(9, 1.4, 15), base * CFrame.new(0, 3.4, 0) * CFrame.Angles(tilt, 0, 0), C.wood, M.wood, false)
	for side = -1, 1, 2 do
		block(
			model,
			"Side",
			Vector3.new(0.8, 3.4, 15),
			base * CFrame.new(side * 4.4, 5, 0) * CFrame.Angles(tilt, 0, 0),
			C.woodDark,
			M.wood,
			false
		)
	end
	for side = -1, 1, 2 do
		for z = -1, 1, 2 do
			local broken = wrecked and side == -1 and z == 1
			if not broken then
				cyl(
					model,
					"Wheel",
					3.2,
					1,
					(base * CFrame.new(side * 5, 3.2, z * 5)).Position,
					C.woodDark,
					M.log
				)
			end
		end
	end
	-- Shafts, pointing at nothing.
	for side = -1, 1, 2 do
		block(
			model,
			"Shaft",
			Vector3.new(0.9, 0.9, 11),
			base * CFrame.new(side * 2.4, 3.6, 12) * CFrame.Angles(math.rad(-6), 0, 0),
			C.woodDark,
			M.log,
			false
		)
	end
	return model
end

local function trebuchet(parent, at: Vector3, angle: number)
	local model = group(parent, "Trebuchet")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(angle), 0)

	for side = -1, 1, 2 do
		block(model, "Foot", Vector3.new(2.4, 2.4, 26), base * CFrame.new(side * 7, 1.2, 0), C.woodDark, M.log, false)
		-- A-frame legs.
		block(
			model,
			"Leg",
			Vector3.new(2, 30, 2),
			base * CFrame.new(side * 7, 15, -5) * CFrame.Angles(math.rad(16), 0, 0),
			C.wood,
			M.log
		)
		block(
			model,
			"Leg",
			Vector3.new(2, 30, 2),
			base * CFrame.new(side * 7, 15, 5) * CFrame.Angles(math.rad(-16), 0, 0),
			C.wood,
			M.log
		)
	end
	block(model, "Axle", Vector3.new(16, 1.6, 1.6), base * CFrame.new(0, 29, 0), C.iron, M.iron, false)
	-- The throwing arm, still up. It never got to fire again.
	block(
		model,
		"Arm",
		Vector3.new(1.8, 1.8, 40),
		base * CFrame.new(0, 26, -6) * CFrame.Angles(math.rad(42), 0, 0),
		C.wood,
		M.log
	)
	block(model, "Counterweight", Vector3.new(7, 7, 7), base * CFrame.new(0, 12, 12), C.iron, M.iron)
	return model
end

--==========================================================================
-- STAGE 1 — Outskirts
--==========================================================================
if BUILD.Outskirts then
	local f = area("Area1_Outskirts")

	-- The platform the train from the Hub arrives at: the last working thing.
	local plat = group(f, "Platform")
	block(plat, "Deck", Vector3.new(70, 3, 90), CFrame.new(0, 1.5, 235), C.stonePale, M.stone)
	block(plat, "Edge", Vector3.new(70, 1.5, 2), CFrame.new(0, 3.4, 190), C.stoneDark, M.stone, false)
	for side = -1, 1, 2 do
		for i = 0, 3 do
			block(
				plat,
				"Post",
				Vector3.new(1.6, 14, 1.6),
				CFrame.new(side * 30, 10, 200 + i * 22),
				C.woodDark,
				M.log
			)
		end
		block(plat, "Canopy", Vector3.new(10, 1, 90), CFrame.new(side * 30, 17.5, 235), C.woodDark, M.wood, false)
	end
	-- Rails running back the way you came, and stopping.
	for side = -1, 1, 2 do
		block(plat, "Rail", Vector3.new(1.2, 1, 200), CFrame.new(side * 6, 1, 300), C.rust, M.iron, false)
	end
	for i = 0, 24 do
		block(plat, "Sleeper", Vector3.new(20, 0.9, 3), CFrame.new(0, 0.6, 205 + i * 8), C.woodDark, M.log, false)
	end

	roadSlab(f, 190, -120, 0, ROAD_W)

	-- The first objective: a survivor's cairn and a signpost that no longer points
	-- anywhere useful.
	cairn(f, Vector3.new(-16, 0, -30), 6)
	local sign = group(f, "Signpost")
	block(sign, "Post", Vector3.new(1.4, 15, 1.4), CFrame.new(-13, 7.5, -30) * CFrame.Angles(0, 0, math.rad(9)), C.woodDark, M.log)
	block(sign, "Board", Vector3.new(14, 4, 0.8), CFrame.new(-10, 13, -30) * CFrame.Angles(0, math.rad(18), math.rad(9)), C.wood, M.wood, false)
	block(sign, "Rag", Vector3.new(3, 7, 0.3), CFrame.new(-13, 4, -30.6) * CFrame.Angles(0, 0, math.rad(6)), C.cloth, M.cloth, false)

	-- The second: a burned farm.
	house(f, "Farmhouse", Vector3.new(34, 0, -62), Vector3.new(30, 16, 24), -14, 0.7)
	house(f, "Barn", Vector3.new(58, 0, -40), Vector3.new(24, 20, 34), 8, 0.8)
	for i = 1, 5 do
		block(
			f,
			"Fence",
			Vector3.new(0.8, 5, 12),
			CFrame.new(20 + jitter(2), 2.5, -20 - i * 13) * CFrame.Angles(0, 0, math.rad(jitter(12))),
			C.woodDark,
			M.log,
			false
		)
	end
	cart(f, Vector3.new(-22, 0, -70), 28, true)

	-- The palisade at the far end — thrown up in a hurry, and from the wrong side.
	local pal = group(f, "Palisade")
	for x = -180, 180, 6 do
		if math.abs(x) > 16 then
			block(
				pal,
				"Stake",
				Vector3.new(5, rng:NextNumber(16, 21), 4),
				CFrame.new(x, 9, -110) * CFrame.Angles(math.rad(jitter(4)), 0, math.rad(jitter(4))),
				C.woodDark,
				M.log
			)
		end
	end
	block(pal, "GateFrame", Vector3.new(38, 4, 6), CFrame.new(0, 20, -110), C.wood, M.log)
	for side = -1, 1, 2 do
		block(pal, "GatePost", Vector3.new(4, 22, 6), CFrame.new(side * 17, 11, -110), C.wood, M.log)
	end

	print("[World] stage 1 — Outskirts")
end

--==========================================================================
-- STAGE 2 — Village
--==========================================================================
if BUILD.Village then
	local f = area("Area2_Village")
	roadSlab(f, -260, -580, 0, ROAD_W)

	-- Two rows of houses down one street. None of them keep a full roof.
	local plots = {
		{ x = -46, z = -310, w = 30, d = 24, a = 4, ruin = 0.35 },
		{ x = -50, z = -360, w = 26, d = 22, a = -6, ruin = 0.75 },
		{ x = -44, z = -408, w = 32, d = 26, a = 2, ruin = 0.5 },
		{ x = -52, z = -462, w = 24, d = 20, a = 9, ruin = 0.85 },
		{ x = 46, z = -324, w = 28, d = 24, a = -3, ruin = 0.6 },
		{ x = 50, z = -374, w = 30, d = 26, a = 5, ruin = 0.3 },
		{ x = 44, z = -424, w = 26, d = 22, a = -8, ruin = 0.8 },
		{ x = 54, z = -476, w = 32, d = 24, a = 1, ruin = 0.55 },
	}
	for i, p in plots do
		house(f, "House" .. i, Vector3.new(p.x, 0, p.z), Vector3.new(p.w, 16, p.d), p.a, p.ruin)
	end

	-- The square. The well is boarded over FROM ABOVE.
	local well = group(f, "Well")
	cyl(well, "Ring", 7, 5, Vector3.new(0, 2.5, -392), C.stone, M.stone)
	cyl(well, "Bore", 5.4, 5.4, Vector3.new(0, 2.7, -392), C.stoneDark, M.stone)
	for side = -1, 1, 2 do
		block(well, "Post", Vector3.new(1.4, 12, 1.4), CFrame.new(side * 6, 8, -392), C.woodDark, M.log)
	end
	block(well, "Beam", Vector3.new(14, 1.4, 1.4), CFrame.new(0, 14, -392), C.woodDark, M.log, false)
	for i = -2, 2 do
		block(well, "Board", Vector3.new(3, 0.6, 13), CFrame.new(i * 3.2, 5.4, -392) * CFrame.Angles(0, math.rad(jitter(6)), 0), C.wood, M.wood, false)
	end

	-- Furniture in the ROAD, not in the homes: dragged out to build these.
	barricade(f, Vector3.new(0, 0, -340), 0, 46)
	barricade(f, Vector3.new(-18, 0, -440), 74, 30)
	barricade(f, Vector3.new(22, 0, -500), -66, 34)
	cart(f, Vector3.new(14, 0, -360), 96, true)
	cart(f, Vector3.new(-12, 0, -470), -80, true)

	-- The chapel: the only building with its walls still whole, which is its own
	-- kind of statement. The bell tower is not.
	local chapel = group(f, "Chapel")
	ruinedWall(chapel, "Wall", Vector3.new(-104, 0, -400), Vector3.new(-104, 0, -450), 22, 4, {}, C.stonePale, M.stone)
	ruinedWall(chapel, "Wall", Vector3.new(-70, 0, -400), Vector3.new(-70, 0, -450), 22, 4, {}, C.stonePale, M.stone)
	ruinedWall(chapel, "Wall", Vector3.new(-104, 0, -450), Vector3.new(-70, 0, -450), 22, 4, {}, C.stonePale, M.stone)
	ruinedWall(chapel, "Wall", Vector3.new(-104, 0, -400), Vector3.new(-70, 0, -400), 22, 4, { { 0.4, 0.6, 0 } }, C.stonePale, M.stone)
	for i = 0, 5 do
		wedge(
			chapel,
			"Roof",
			Vector3.new(36, 9, 9),
			CFrame.new(-87, 24 + i * 0.2, -404 - i * 8.5) * CFrame.Angles(0, math.rad(90), 0),
			C.woodDark,
			M.wood
		)
	end
	tower(chapel, "BellTower", Vector3.new(-87, 0, -394), 9, 34, { crown = false, lean = 3 })
	block(chapel, "Bell", Vector3.new(6, 6, 6), CFrame.new(-79, 3, -388) * CFrame.Angles(0.4, 0.8, 0.2), C.rust, M.iron)

	print("[World] stage 2 — Village")
end

--==========================================================================
-- STAGE 3 — Crossing
--==========================================================================
if BUILD.Crossing then
	local f = area("Area3_Bridge")
	roadSlab(f, -680, -800, 0, ROAD_W)
	roadSlab(f, -880, -1000, 0, ROAD_W)

	-- The bridge. Its centre is GONE, and the cut is clean — this was
	-- demolition, from the near bank, and it did not work.
	local bridge = group(f, "Bridge")
	local function span(fromZ, toZ)
		block(bridge, "Deck", Vector3.new(30, 4, math.abs(toZ - fromZ)), CFrame.new(0, 0, (fromZ + toZ) / 2), C.stone, M.stone)
		for side = -1, 1, 2 do
			block(bridge, "Parapet", Vector3.new(2.5, 7, math.abs(toZ - fromZ)), CFrame.new(side * 14, 5, (fromZ + toZ) / 2), C.stoneDark, M.stone, false)
		end
	end
	span(-800, -826)
	span(-856, -880)

	-- Arches under what is left.
	for _, z in { -813, -868 } do
		for i = 0, 7 do
			local a = math.pi * (i / 7)
			cyl(bridge, "Arch", 3, 30, Vector3.new(math.cos(a) * 13, -2 - math.sin(a) * 13, z), C.stone, M.stone)
		end
	end

	-- Planks thrown across since, by someone who came after.
	for i = -3, 3 do
		block(
			bridge,
			"Plank",
			Vector3.new(3.4, 0.8, 34),
			CFrame.new(i * 4 + jitter(1), -0.4, -841) * CFrame.Angles(0, math.rad(jitter(4)), math.rad(jitter(3))),
			C.wood,
			M.wood,
			false
		)
	end
	-- The fallen span, in the water below.
	for i = 1, 6 do
		block(
			bridge,
			"Fallen",
			Vector3.new(rng:NextNumber(8, 18), rng:NextNumber(4, 9), rng:NextNumber(8, 16)),
			CFrame.new(jitter(22), -34 + jitter(3), -841 + jitter(18))
				* CFrame.Angles(rng:NextNumber(0, 0.6), rng:NextNumber(0, 3), rng:NextNumber(0, 0.6)),
			C.stone,
			M.stone,
			false
		)
	end

	-- A watchtower on each bank, facing each other across the gap.
	tower(f, "TowerNear", Vector3.new(-40, 0, -792), 12, 46, { roof = true, gaps = 0.2 })
	tower(f, "TowerFar", Vector3.new(40, 0, -888), 12, 40, { crown = false, lean = 5 })

	-- A tollhouse nobody collects from any more.
	house(f, "Tollhouse", Vector3.new(44, 0, -770), Vector3.new(20, 14, 18), -12, 0.45)

	print("[World] stage 3 — Crossing")
end

--==========================================================================
-- STAGE 4 — Siegeground
--==========================================================================
if BUILD.Siegeground then
	local f = area("Area4_Courtyard")
	roadSlab(f, -1080, -1450, 0, ROAD_W)

	-- The field where the relief army died, facing walls it never took.
	trebuchet(f, Vector3.new(-72, 0, -1180), 8)
	trebuchet(f, Vector3.new(78, 0, -1226), -6)
	trebuchet(f, Vector3.new(-58, 0, -1300), 14)

	-- The ram, stopped short of the gate.
	local ram = group(f, "Ram")
	block(ram, "Log", Vector3.new(5, 5, 40), CFrame.new(6, 8, -1370) * CFrame.Angles(0, math.rad(6), 0), C.woodDark, M.log)
	block(ram, "Head", Vector3.new(6, 6, 7), CFrame.new(8, 8, -1390), C.iron, M.iron)
	for side = -1, 1, 2 do
		block(ram, "Frame", Vector3.new(1.8, 16, 36), CFrame.new(6 + side * 6, 9, -1368), C.wood, M.log, false)
	end
	block(ram, "Canopy", Vector3.new(16, 1.4, 38), CFrame.new(6, 17, -1368) * CFrame.Angles(math.rad(3), 0, 0), C.wood, M.wood, false)

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

	-- Palisade the besiegers built, facing the wrong way now.
	for x = -260, -120, 7 do
		block(f, "SiegeStake", Vector3.new(5, rng:NextNumber(12, 17), 4), CFrame.new(x, 7, -1150) * CFrame.Angles(math.rad(-20), 0, 0), C.woodDark, M.log, false)
	end
	for i = 1, 12 do
		block(
			f,
			"Debris",
			Vector3.new(rng:NextNumber(4, 11), rng:NextNumber(2, 5), rng:NextNumber(4, 11)),
			CFrame.new(jitter(180), 1.5, -1180 - rng:NextNumber(0, 220)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			C.rock,
			M.rock,
			false
		)
	end

	-- The barbican: the outer gate, torn open.
	local barb = group(f, "Barbican")
	ruinedWall(barb, "Wall", Vector3.new(-200, 0, -1450), Vector3.new(-24, 0, -1450), 40, 12, { { 0.7, 0.85, 0.35 } }, C.stone, M.stone)
	ruinedWall(barb, "Wall", Vector3.new(24, 0, -1450), Vector3.new(200, 0, -1450), 40, 12, { { 0.2, 0.38, 0 } }, C.stone, M.stone)
	tower(barb, "BarbicanW", Vector3.new(-30, 0, -1450), 16, 56, { gaps = 0.3 })
	tower(barb, "BarbicanE", Vector3.new(30, 0, -1450), 16, 48, { crown = false })
	block(barb, "Lintel", Vector3.new(64, 10, 16), CFrame.new(0, 44, -1450), C.stoneDark, M.stone)
	-- The gate itself, off its hinges and lying in the road.
	block(barb, "BrokenGate", Vector3.new(34, 2.4, 40), CFrame.new(-6, 1.6, -1424) * CFrame.Angles(0, math.rad(12), 0), C.woodDark, M.wood, false)

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

	block(f, "Plinth", Vector3.new(COURT + 120, PLINTH_H, COURT + 120), CFrame.new(CX, PLINTH_H / 2, CZ), C.rock, M.rock)
	-- A causeway up onto it, so the approach has a last climb.
	wedge(f, "Causeway", Vector3.new(56, PLINTH_H, 90), CFrame.new(CX, PLINTH_H / 2, CZ + half + 100) * CFrame.Angles(0, math.rad(180), 0), C.rock, M.rock)

	local nearZ, farZ = CZ + half, CZ - half
	local leftX, rightX = CX - half, CX + half
	local gateHalf = 30

	local walls = group(f, "Walls")
	local function side(name, from, to, breaks)
		local at = Vector3.new(from.X, baseY, from.Z)
		local to2 = Vector3.new(to.X, baseY, to.Z)
		ruinedWall(walls, name, at, to2, WALL_H, WALL_T, breaks, C.stone, M.stone)
		crenellate(walls, at, to2, baseY + WALL_H, WALL_T, C.stoneDark)
	end

	side("WallFront", Vector3.new(leftX, 0, nearZ), Vector3.new(CX - gateHalf, 0, nearZ), { { 0.6, 0.78, 0.45 } })
	side("WallFront", Vector3.new(CX + gateHalf, 0, nearZ), Vector3.new(rightX, 0, nearZ), {})
	-- The breach. Something came through here.
	side("WallLeft", Vector3.new(leftX, 0, nearZ), Vector3.new(leftX, 0, farZ), { { 0.36, 0.56, 0 }, { 0.56, 0.72, 0.4 } })
	side("WallRight", Vector3.new(rightX, 0, nearZ), Vector3.new(rightX, 0, farZ), { { 0.72, 0.84, 0.5 } })
	side("WallBack", Vector3.new(leftX, 0, farZ), Vector3.new(rightX, 0, farZ), { { 0.22, 0.36, 0.6 } })

	-- Towers: corners AND mid-wall. Four alone did not read as a castle.
	local towers = group(f, "Towers")
	local TR, TH = 27, 96
	tower(towers, "TowerNW", Vector3.new(leftX, baseY, farZ), TR, TH, { gaps = 0.25 })
	tower(towers, "TowerNE", Vector3.new(rightX, baseY, farZ), TR, TH * 0.68, { crown = false })
	tower(towers, "TowerSW", Vector3.new(leftX, baseY, nearZ), TR, TH, { lean = 4, gaps = 0.4 })
	tower(towers, "TowerSE", Vector3.new(rightX, baseY, nearZ), TR, TH, { roof = true })
	tower(towers, "TowerWMid", Vector3.new(leftX, baseY, CZ), TR * 0.8, TH * 0.85, { crown = false })
	tower(towers, "TowerEMid", Vector3.new(rightX, baseY, CZ), TR * 0.8, TH * 0.9, { roof = true, gaps = 0.2 })
	tower(towers, "TowerNMid", Vector3.new(CX, baseY, farZ), TR * 0.8, TH * 0.88, { gaps = 0.3 })
	tower(towers, "GateW", Vector3.new(CX - gateHalf - 18, baseY, nearZ), TR * 1.05, TH * 1.2, { gaps = 0.15 })
	tower(towers, "GateE", Vector3.new(CX + gateHalf + 18, baseY, nearZ), TR * 1.05, TH * 1.2, { gaps = 0.15 })
	block(towers, "GateLintel", Vector3.new(gateHalf * 2 + 26, 18, WALL_T + 8), CFrame.new(CX, baseY + 50, nearZ), C.stoneDark, M.stone)

	-- Inside: a courtyard that was lived in.
	local inner = group(f, "Inner")

	-- The great hall, roof gone, columns standing.
	local hallZ = CZ + 40
	ruinedWall(inner, "HallWall", Vector3.new(CX - 70, baseY, hallZ - 60), Vector3.new(CX - 70, baseY, hallZ + 60), 40, 6, { { 0.5, 0.7, 0.4 } }, C.stonePale, M.stone)
	ruinedWall(inner, "HallWall", Vector3.new(CX + 70, baseY, hallZ - 60), Vector3.new(CX + 70, baseY, hallZ + 60), 40, 6, { { 0.2, 0.34, 0 } }, C.stonePale, M.stone)
	ruinedWall(inner, "HallWall", Vector3.new(CX - 70, baseY, hallZ - 60), Vector3.new(CX + 70, baseY, hallZ - 60), 40, 6, { { 0.44, 0.58, 0 } }, C.stonePale, M.stone)
	for i = -2, 2 do
		for s = -1, 1, 2 do
			cyl(inner, "Column", 5, 38, Vector3.new(CX + s * 44, baseY + 19, hallZ + i * 26), C.stonePale, M.stone)
		end
	end
	for i = 1, 7 do
		block(
			inner,
			"FallenBeam",
			Vector3.new(3, 3, rng:NextNumber(30, 70)),
			CFrame.new(CX + jitter(60), baseY + rng:NextNumber(1, 6), hallZ + jitter(55))
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)),
			C.woodDark,
			M.log,
			false
		)
	end

	-- Stables and a chapel along the west wall.
	house(inner, "Stables", Vector3.new(CX - 140, baseY, CZ + 90), Vector3.new(36, 18, 70), 0, 0.6)
	house(inner, "Chapel", Vector3.new(CX - 145, baseY, CZ - 60), Vector3.new(34, 24, 46), 0, 0.3)
	house(inner, "Barracks", Vector3.new(CX + 140, baseY, CZ + 70), Vector3.new(36, 18, 80), 0, 0.7)
	house(inner, "Smithy", Vector3.new(CX + 138, baseY, CZ - 50), Vector3.new(30, 16, 34), 0, 0.5)

	-- The keep, split open at the top.
	local KEEP = Vector3.new(160, 200, 130)
	local keepZ = CZ - 110
	block(inner, "Keep", KEEP, CFrame.new(CX, baseY + KEEP.Y / 2, keepZ), C.stone, M.stone)
	block(
		inner,
		"KeepBreak",
		Vector3.new(KEEP.X * 0.5, KEEP.Y * 0.2, KEEP.Z * 0.55),
		CFrame.new(CX + KEEP.X * 0.26, baseY + KEEP.Y - KEEP.Y * 0.08, keepZ + KEEP.Z * 0.22) * CFrame.Angles(0, 0, math.rad(7)),
		C.stoneDark,
		M.stone
	)
	for i = 0, 9 do
		local a = (math.pi * 2 / 10) * i
		block(
			inner,
			"KeepMerlon",
			Vector3.new(15, 11, 15),
			CFrame.new(CX + math.cos(a) * (KEEP.X / 2 - 9), baseY + KEEP.Y + 5, keepZ + math.sin(a) * (KEEP.Z / 2 - 9)),
			C.stoneDark,
			M.stone,
			false
		)
	end
	-- Corner turrets on the keep: the detail that says "this is the last one standing".
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			tower(
				inner,
				"KeepTurret",
				Vector3.new(CX + sx * (KEEP.X / 2 - 6), baseY + KEEP.Y - 30, keepZ + sz * (KEEP.Z / 2 - 6)),
				9,
				44,
				{ roof = sx ~= sz, crown = sx == sz }
			)
		end
	end
	block(inner, "KeepDoor", Vector3.new(22, 34, 6), CFrame.new(CX, baseY + 17, keepZ + KEEP.Z / 2 + 1), C.woodDark, M.wood)

	-- Rubble at the breach, spilling into the courtyard.
	for i = 1, 40 do
		local a = rng:NextNumber() * math.pi * 2
		local d = rng:NextNumber(0, 110)
		local s = rng:NextNumber(6, 20)
		block(
			f,
			"Rubble",
			Vector3.new(s, s * rng:NextNumber(0.35, 0.85), s * rng:NextNumber(0.6, 1.2)),
			CFrame.new(leftX + math.cos(a) * d * 0.6, baseY + s / 3, CZ + math.sin(a) * d)
				* CFrame.Angles(rng:NextNumber(0, 0.5), rng:NextNumber(0, 6), rng:NextNumber(0, 0.5)),
			C.rock,
			M.rock,
			false
		)
	end

	local structure = f
	pcall(function()
		(structure :: any).ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)

	print("[World] stage 5 — Castle")
end

--==========================================================================
-- The gorge (terrain)
--==========================================================================
if BUILD.Gorge then
	-- Carve, then flood. Air removes terrain; Water fills the bottom.
	for x = -700, 700, 50 do
		workspace.Terrain:FillBlock(CFrame.new(x + 25, -30, -841), Vector3.new(50, 120, 62), Enum.Material.Air)
		workspace.Terrain:FillBlock(CFrame.new(x + 25, -74, -841), Vector3.new(50, 32, 62), Enum.Material.Water)
		task.wait()
	end
	print("[World] gorge carved and flooded at z=-841")
end

--==========================================================================
print(("[World] DONE — %d parts across the road home."):format(made))
print("Landmarks: platform z=+235 | cairn z=-30 | farm z=-62 | palisade z=-110")
print("           village z=-310..-480 | bridge z=-841 | siege z=-1180..-1370")
print("           barbican z=-1450 | castle gate z=-1670 | keep z=-2010")
print("Now add torches, banners, barrels, bodies and sound. That is where it stops being a diagram.")
