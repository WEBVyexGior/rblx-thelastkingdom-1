--[[
	BuildStables — run in the Studio Command Bar of the FORGOTTEN LANDS place,
	in EDIT MODE. Select the whole file (Ctrl+A), copy, paste, Enter.

	--------------------------------------------------------------------------
	WHAT IT BUILDS

	Area 2's identity: a lean-to stable range against the east wall of the
	second chamber, and the yard in front of it. Eight stalls, a tack room, a
	hay loft, and everything a stable yard has once nobody has mucked it out for
	forty years.

	It is a LEAN-TO on purpose: a high blank back wall on the east, one roof
	plane falling west, and an open front of posts. A barn with two pitches in
	the middle of a ward is a farm; a range with its back turned to the wall and
	its face to the yard is a castle. One roof plane also means the detail
	budget goes into the stalls instead of into a second slope nobody looks at.

	It does NOT touch the curtain wall — it cannot. The side tower's inner face
	reaches x = 128 and the east enemy spawn sits at x = 110, so the range stops
	at x = 97 and stands clear in the ward, which is where a stable block goes
	anyway.

	--------------------------------------------------------------------------
	SURGICAL AND RE-RUNNABLE

	Everything lands in `Battleground.Decorations.Area2_Stables`, which this
	tool deletes and rebuilds. It touches nothing else — not the road, not
	BuildChambers' decorations, not a single part placed by hand. Run it as many
	times as you like.

	It finishes by SWEEPING its own footprint and naming anything already
	standing in it, rather than deleting what it finds. What to move is a design
	decision and this is a build tool.

	--------------------------------------------------------------------------
	THE RULE IT DOES NOT BREAK

	No stairs, no ladder, nothing climbable. The hay loft has a hoist beam and a
	FALLEN ladder lying in the yard — which is how you say "there was a way up"
	without giving anyone a way up. The castle's one hard rule is that nothing
	reaches the wall walk, and a stable ladder against the east wall would be
	the most obvious breach in the map.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

--==========================================================================
-- The chamber, from tools/BuildBattleground
--==========================================================================
local Z_START = 20
local CHAMBER_D = 200
local AREA = 2

local Z_NEAR = Z_START - (AREA - 1) * CHAMBER_D -- -180
local BASE = 2 -- the level BuildChambers builds its road and houses on

--==========================================================================
-- The range
--
-- Placed against the EAST wall, clear of three things that are all fatal to
-- get wrong: the road (which crosses this chamber diagonally from the east
-- passage down to the west one), the east enemy spawn at x = 110, and the
-- side tower whose inner face reaches x = 128.
--==========================================================================
local Z1 = Z_NEAR - 36 -- -216
local Z2 = Z_NEAR - 164 -- -344
local BAYS = 8
local BAY = (Z1 - Z2) / BAYS -- 16

local X_BACK = 97 -- the back wall, against the curtain
local X_FRONT = 71 -- the posts along the open front
local X_EAVE = 66 -- how far the roof oversails them

local Y_FLOOR = BASE + 0.2
local Y_BACK = BASE + 19 -- head of the back wall
local Y_EAVE = BASE + 9 -- underside at the front posts

local rng = Random.new(20260805)

--==========================================================================
local C = {
	stone = Color3.fromRGB(84, 82, 79),
	stoneDark = Color3.fromRGB(60, 59, 60),
	stonePale = Color3.fromRGB(112, 108, 100),
	stoneWarm = Color3.fromRGB(98, 92, 82),
	wood = Color3.fromRGB(66, 49, 34),
	woodDark = Color3.fromRGB(44, 32, 22),
	woodPale = Color3.fromRGB(92, 72, 50),
	woodGrey = Color3.fromRGB(86, 79, 68),
	straw = Color3.fromRGB(146, 122, 68),
	strawDark = Color3.fromRGB(112, 92, 50),
	thatch = Color3.fromRGB(78, 68, 44),
	iron = Color3.fromRGB(56, 48, 44),
	rust = Color3.fromRGB(92, 54, 34),
	leather = Color3.fromRGB(72, 48, 32),
	bone = Color3.fromRGB(186, 178, 158),
	muck = Color3.fromRGB(52, 42, 30),
	slate = Color3.fromRGB(70, 70, 74),
	water = Color3.fromRGB(46, 56, 52),
}

local M = {
	stone = Enum.Material.Slate,
	rock = Enum.Material.Rock,
	cobble = Enum.Material.Cobblestone,
	wood = Enum.Material.WoodPlanks,
	log = Enum.Material.Wood,
	iron = Enum.Material.Metal,
	rusted = Enum.Material.CorrodedMetal,
	cloth = Enum.Material.Fabric,
	sand = Enum.Material.Sand,
	ground = Enum.Material.Ground,
	grass = Enum.Material.LeafyGrass,
}

--==========================================================================
local gameplay = workspace:FindFirstChild("Gameplay")
local battleground = gameplay and gameplay:FindFirstChild("Battleground")
if not battleground then
	warn("[Stables] no Gameplay.Battleground — build the battleground first.")
	return
end

local decorRoot = battleground:FindFirstChild("Decorations")
if not decorRoot then
	decorRoot = Instance.new("Folder")
	decorRoot.Name = "Decorations"
	decorRoot.Parent = battleground
end

local ROOT_NAME = "Area2_Stables"
local old = decorRoot:FindFirstChild(ROOT_NAME)
if old then
	old:Destroy()
	print("[Stables] removed the previous build")
end

local root = Instance.new("Folder")
root.Name = ROOT_NAME
root.Parent = decorRoot

local made = 0

local function group(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material): Part
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
	made += 1
	return p
end

-- A cylinder's axis is its LOCAL X, so its Size is (length, dia, dia). Every
-- round thing here is built through this so that is stated once.
local function rod(parent: Instance, name: string, length: number, dia: number, cf: CFrame, colour: Color3, material: Enum.Material): Part
	local p = block(parent, name, Vector3.new(length, dia, dia), cf, colour, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function jitter(a: number): number
	return rng:NextNumber(-a, a)
end

local function chance(p: number): boolean
	return rng:NextNumber() < p
end

-- The middle of bay `i`, counting from the near (north) end.
local function bayZ(i: number): number
	return Z1 - (i - 0.5) * BAY
end

--==========================================================================
-- The roof plane. Everything that sits on it asks here rather than repeating
-- the arithmetic, because a rafter and the boards nailed to it disagreeing by
-- half a stud is the most visible mistake a roof can make.
--==========================================================================
local ROOF_RUN = X_BACK - X_EAVE
local ROOF_RISE = Y_BACK - Y_EAVE
local ROOF_PITCH = math.atan2(ROOF_RISE, ROOF_RUN)
local ROOF_LEN = math.sqrt(ROOF_RUN ^ 2 + ROOF_RISE ^ 2)

local function roofY(x: number): number
	return Y_EAVE + (x - X_EAVE) * (ROOF_RISE / ROOF_RUN)
end

--==========================================================================
-- THE SHELL
--==========================================================================
local shell = group(root, "Range")

do
	local length = Z1 - Z2

	-- A plinth that runs into the ground, so the range never floats however the
	-- terrain sits under it.
	block(
		shell,
		"Plinth",
		Vector3.new(X_BACK - X_FRONT + 8, 4, length + 6),
		CFrame.new((X_BACK + X_FRONT) / 2 + 2, BASE - 1.6, (Z1 + Z2) / 2),
		C.stoneDark,
		M.rock
	)

	-- The floor of the range: worn brick, laid in bays.
	for i = 1, BAYS do
		block(
			shell,
			"Floor",
			Vector3.new(X_BACK - X_FRONT + 2, 0.5, BAY - 0.4),
			CFrame.new((X_BACK + X_FRONT) / 2, Y_FLOOR, bayZ(i)),
			if i % 2 == 0 then C.stoneWarm else C.stonePale,
			M.cobble
		)
	end

	--------------------------------------------------------------------------
	-- The back wall, in courses so it reads as masonry rather than as a slab.
	--------------------------------------------------------------------------
	local courses = 8
	local courseH = (Y_BACK - Y_FLOOR) / courses
	for c = 0, courses - 1 do
		local y = Y_FLOOR + courseH * (c + 0.5)
		local inset = if c % 2 == 0 then 0 else 0.35
		block(
			shell,
			"BackWall",
			Vector3.new(3.4 - inset, courseH + 0.06, length),
			CFrame.new(X_BACK + inset / 2, y, (Z1 + Z2) / 2),
			if c % 3 == 0 then C.stone elseif c % 3 == 1 then C.stoneWarm else C.stoneDark,
			M.stone
		)
	end

	-- Putlog holes: the square sockets a mason's scaffold left behind. Nothing
	-- says "built by hand" faster, and they cost one part each.
	for i = 1, BAYS do
		block(
			shell,
			"Putlog",
			Vector3.new(1.2, 1.1, 1.1),
			CFrame.new(X_BACK - 1.4, Y_FLOOR + 12.5, bayZ(i) + jitter(2)),
			C.stoneDark,
			M.stone
		)
	end

	--------------------------------------------------------------------------
	-- The two gable ends, cut to the roof line.
	--------------------------------------------------------------------------
	for _, endZ in { Z1, Z2 } do
		local dir = if endZ == Z1 then 1 else -1
		-- Stepped to follow the slope: six blocks, each shorter than the last.
		local steps = 7
		for s = 0, steps - 1 do
			local x0 = X_FRONT - 3 + (X_BACK - X_FRONT + 6) * (s / steps)
			local x1 = X_FRONT - 3 + (X_BACK - X_FRONT + 6) * ((s + 1) / steps)
			local top = roofY((x0 + x1) / 2) - 0.3
			block(
				shell,
				"EndWall",
				Vector3.new(x1 - x0 + 0.2, top - Y_FLOOR, 3),
				CFrame.new((x0 + x1) / 2, (top + Y_FLOOR) / 2, endZ + dir * 1.5),
				if s % 2 == 0 then C.stone else C.stoneWarm,
				M.stone
			)
		end
	end

	--------------------------------------------------------------------------
	-- The front: a post per division, with a head beam along them.
	--------------------------------------------------------------------------
	for i = 0, BAYS do
		local z = Z1 - i * BAY
		local lean = jitter(1.4)
		block(
			shell,
			"Post",
			Vector3.new(2.2, Y_EAVE - Y_FLOOR + 1, 2.2),
			CFrame.new(X_FRONT, (Y_EAVE + Y_FLOOR) / 2, z) * CFrame.Angles(math.rad(lean), 0, math.rad(jitter(1.2))),
			C.woodDark,
			M.log
		)
		-- A stone pad under it, so the post foot is not in the mud.
		block(
			shell,
			"PostPad",
			Vector3.new(3.6, 1, 3.6),
			CFrame.new(X_FRONT, Y_FLOOR + 0.3, z),
			C.stonePale,
			M.rock
		)
	end

	block(
		shell,
		"HeadBeam",
		Vector3.new(2.6, 2, Z1 - Z2 + 4),
		CFrame.new(X_FRONT, Y_EAVE + 0.6, (Z1 + Z2) / 2),
		C.wood,
		M.log
	)

	-- Braces from post to beam: the joint that keeps a range standing.
	for i = 0, BAYS do
		local z = Z1 - i * BAY
		for _, side in { -1, 1 } do
			block(
				shell,
				"Brace",
				Vector3.new(1.4, 1.2, 6.4),
				CFrame.new(X_FRONT, Y_EAVE - 2.2, z + side * 2.6) * CFrame.Angles(math.rad(side * 38), 0, 0),
				C.wood,
				M.log
			)
		end
	end
end

--==========================================================================
-- THE ROOF
--==========================================================================
do
	local roof = group(root, "Roof")

	--[[
		POSITIVE, not negative. A rotation about Z takes local +X toward +Y, and
		this roof rises toward +X (the back wall is the high side). With the sign
		the other way every rafter and every course tilts the wrong way and the
		roof drains into the building.
	]]
	local slope = CFrame.Angles(0, 0, ROOF_PITCH)
	local midX = (X_BACK + X_EAVE) / 2
	local midY = roofY(midX)

	-- Rafters, every 4 studs, each one a little out of true.
	local rafters = math.floor((Z1 - Z2) / 4)
	for i = 0, rafters do
		local z = Z1 - i * ((Z1 - Z2) / rafters)
		block(
			roof,
			"Rafter",
			Vector3.new(ROOF_LEN + 2, 1.1, 0.85),
			CFrame.new(midX, midY + 0.2, z + jitter(0.3)) * slope,
			C.woodDark,
			M.log
		)
	end

	-- Purlins along the range, under the rafters.
	for _, frac in { 0.25, 0.6, 0.9 } do
		local x = X_EAVE + ROOF_RUN * frac
		block(
			roof,
			"Purlin",
			Vector3.new(1.6, 1.6, Z1 - Z2 + 2),
			CFrame.new(x, roofY(x) - 1.3, (Z1 + Z2) / 2),
			C.wood,
			M.log
		)
	end

	--[[
		The covering, laid bay by bay and course by course so holes can be
		punched in it. Two bays have lost most of their boards and one has lost
		a strip along the ridge — a roof that is uniformly whole reads as new,
		and a roof that is uniformly gone reads as a mistake.
	]]
	local courses = 9
	for b = 1, BAYS do
		local gone = (b == 3) or (b == 6)
		for c = 0, courses - 1 do
			local x = X_EAVE + 1.5 + (ROOF_RUN - 3) * (c / (courses - 1))
			local ridgeStrip = (b == 5 and c >= courses - 2)
			if not ridgeStrip and (not gone or chance(0.28)) then
				local y = roofY(x)
				block(
					roof,
					"Slate",
					Vector3.new(ROOF_LEN / courses + 1.4, 0.45, BAY - 0.5),
					CFrame.new(x, y + 0.75, bayZ(b)) * slope,
					if chance(0.3) then C.slate else C.stoneDark,
					M.stone
				)
			end
		end
		-- Moss and fallen leaves gather on a roof nobody sweeps.
		if chance(0.55) then
			local x = X_EAVE + rng:NextNumber(3, ROOF_RUN - 4)
			block(
				roof,
				"Moss",
				Vector3.new(rng:NextNumber(3, 7), 0.25, rng:NextNumber(3, 9)),
				CFrame.new(x, roofY(x) + 1.05, bayZ(b) + jitter(4)) * slope,
				C.thatch,
				M.grass
			)
		end
	end

	-- The eaves board along the front, and the gutter spouts through it.
	block(
		roof,
		"EavesBoard",
		Vector3.new(0.6, 2.2, Z1 - Z2 + 3),
		CFrame.new(X_EAVE - 0.4, Y_EAVE - 0.6, (Z1 + Z2) / 2),
		C.woodPale,
		M.wood
	)
	for i = 1, 3 do
		local z = Z1 - (Z1 - Z2) * (i / 4)
		rod(
			roof,
			"Spout",
			3.4,
			1.1,
			CFrame.new(X_EAVE - 2, Y_EAVE - 0.9, z) * CFrame.Angles(0, 0, math.rad(-20)),
			C.woodGrey,
			M.log
		)
	end
end

--==========================================================================
-- THE STALLS
--==========================================================================
do
	local stalls = group(root, "Stalls")

	--[[
		Bay 1 is the tack room, not a stall: it is boarded to the roof and has a
		real door. A range of eight identical boxes is a diagram; one of them
		being a room somebody worked in is what makes the other seven read as
		stalls.
	]]
	local TACK_BAY = 1

	for i = 1, BAYS do
		local z = bayZ(i)
		local stall = group(stalls, "Stall" .. i)
		local broken = (i == 5)

		------------------------------------------------------------------
		-- The divisions between stalls: boarded low, railed above.
		------------------------------------------------------------------
		for _, edge in { z + BAY / 2, z - BAY / 2 } do
			local full = (i == TACK_BAY) or (edge == bayZ(TACK_BAY) - BAY / 2)
			local boards = if full then 7 else 4
			for b = 0, boards - 1 do
				local y = Y_FLOOR + 1.2 + b * 1.55
				if not (broken and b >= 2 and chance(0.6)) then
					block(
						stall,
						"Division",
						Vector3.new(X_BACK - X_FRONT - 1, 1.45, 0.6),
						CFrame.new((X_BACK + X_FRONT) / 2 - 0.5, y, edge)
							* CFrame.Angles(0, 0, math.rad(jitter(0.8))),
						if b % 2 == 0 then C.wood else C.woodPale,
						M.wood
					)
				end
			end
			-- The rail on top, and its uprights.
			block(
				stall,
				"DivisionRail",
				Vector3.new(X_BACK - X_FRONT - 1, 0.9, 1.3),
				CFrame.new((X_BACK + X_FRONT) / 2 - 0.5, Y_FLOOR + 1.2 + boards * 1.55, edge),
				C.woodDark,
				M.log
			)
			for _, dx in { -7, 0, 7 } do
				block(
					stall,
					"DivisionPost",
					Vector3.new(1.3, boards * 1.55 + 2, 1.3),
					CFrame.new((X_BACK + X_FRONT) / 2 - 0.5 + dx, Y_FLOOR + 1.2 + boards * 1.55 / 2, edge),
					C.woodDark,
					M.log
				)
			end
		end

		------------------------------------------------------------------
		if i == TACK_BAY then
			continue
		end

		------------------------------------------------------------------
		-- The manger on the back wall, and the hay rack over it.
		------------------------------------------------------------------
		block(
			stall,
			"Manger",
			Vector3.new(4.4, 2.6, BAY - 5),
			CFrame.new(X_BACK - 4, Y_FLOOR + 2.6, z),
			C.wood,
			M.wood
		)
		block(
			stall,
			"MangerLip",
			Vector3.new(0.7, 1.2, BAY - 5),
			CFrame.new(X_BACK - 6.1, Y_FLOOR + 4.4, z),
			C.woodPale,
			M.wood
		)
		if chance(0.7) then
			block(
				stall,
				"Feed",
				Vector3.new(3.4, 0.9, BAY - 6.5),
				CFrame.new(X_BACK - 4, Y_FLOOR + 4, z),
				C.strawDark,
				M.grass
			)
		end
		-- Hay rack: iron bars raked out from the wall.
		for b = -2, 2 do
			rod(
				stall,
				"RackBar",
				5.2,
				0.35,
				CFrame.new(X_BACK - 3.4, Y_FLOOR + 7.4, z + b * 1.5) * CFrame.Angles(0, 0, math.rad(28)),
				C.iron,
				M.rusted
			)
		end
		if chance(0.6) then
			block(
				stall,
				"RackHay",
				Vector3.new(4, 2.2, 5.6),
				CFrame.new(X_BACK - 4.6, Y_FLOOR + 8.4, z),
				C.straw,
				M.grass
			)
		end

		------------------------------------------------------------------
		-- Bedding: straw, thicker at the back where a horse would lie.
		------------------------------------------------------------------
		for s = 1, 7 do
			local px = rng:NextNumber(X_FRONT + 3, X_BACK - 7)
			block(
				stall,
				"Straw",
				Vector3.new(rng:NextNumber(3, 7), rng:NextNumber(0.3, 0.8), rng:NextNumber(3, 8)),
				CFrame.new(px, Y_FLOOR + 0.5, z + jitter(BAY / 2 - 3))
					* CFrame.Angles(0, math.rad(rng:NextNumber(0, 180)), 0),
				if chance(0.5) then C.straw else C.strawDark,
				M.grass
			)
		end
		-- Muck in the corner nobody reached.
		block(
			stall,
			"Muck",
			Vector3.new(4.5, 0.6, 4.5),
			CFrame.new(X_BACK - 8, Y_FLOOR + 0.4, z + (BAY / 2 - 3) * (if chance(0.5) then 1 else -1)),
			C.muck,
			M.ground
		)

		------------------------------------------------------------------
		-- The half door at the front, in whatever state it ended up.
		------------------------------------------------------------------
		local state = rng:NextInteger(1, 4)
		if state ~= 4 then
			local swing = if state == 1 then 0 elseif state == 2 then 62 else 104
			local hinge = CFrame.new(X_FRONT + 0.4, Y_FLOOR + 3.4, z + BAY / 2 - 1.4)
			local door = hinge * CFrame.Angles(0, math.rad(-swing), 0) * CFrame.new(0, 0, -(BAY / 2 - 1.6))
			block(stall, "HalfDoor", Vector3.new(1, 6.4, BAY - 3.2), door, C.wood, M.wood)
			for _, dy in { -2, 2 } do
				block(
					stall,
					"DoorLedge",
					Vector3.new(1.5, 0.8, BAY - 3.6),
					door * CFrame.new(0, dy, 0),
					C.woodDark,
					M.wood
				)
			end
			-- Strap hinges, which is what you actually see of a door this size.
			for _, dy in { -2.2, 2.2 } do
				block(
					stall,
					"Hinge",
					Vector3.new(1.7, 0.7, 4.4),
					door * CFrame.new(0, dy, (BAY - 3.2) / 2 - 2.4),
					C.iron,
					M.rusted
				)
			end
		else
			-- Off its hinges and lying in the yard.
			block(
				stall,
				"FallenDoor",
				Vector3.new(BAY - 3.2, 1, 6.4),
				CFrame.new(X_FRONT - 6, Y_FLOOR + 0.7, z + jitter(2)) * CFrame.Angles(0, math.rad(jitter(30)), 0),
				C.wood,
				M.wood
			)
		end

		------------------------------------------------------------------
		-- What is left of who lived here.
		------------------------------------------------------------------
		if i == 3 or i == 7 then
			local bones = group(stall, "Remains")
			local bx = rng:NextNumber(X_FRONT + 6, X_BACK - 9)
			-- Skull, jaw, and the long line of a spine.
			block(bones, "Skull", Vector3.new(4.4, 2.6, 2.4), CFrame.new(bx, Y_FLOOR + 1.3, z + 3)
				* CFrame.Angles(0, math.rad(rng:NextNumber(0, 360)), math.rad(12)), C.bone, M.rock)
			block(bones, "Jaw", Vector3.new(3.2, 0.8, 1.6), CFrame.new(bx + 1.6, Y_FLOOR + 0.5, z + 4.2)
				* CFrame.Angles(0, math.rad(rng:NextNumber(0, 360)), 0), C.bone, M.rock)
			for s = 0, 9 do
				rod(bones, "Vertebra", 1.5, 1.3 - s * 0.06,
					CFrame.new(bx - 1.5 - s * 1.5, Y_FLOOR + 0.9 + jitter(0.2), z + 3 - s * 0.5)
						* CFrame.Angles(0, math.rad(jitter(18)), 0), C.bone, M.rock)
			end
			for s = 1, 6 do
				rod(bones, "Rib", 4.6, 0.5,
					CFrame.new(bx - 3 - s * 1.6, Y_FLOOR + 1.1, z + 2 - s * 0.4)
						* CFrame.Angles(0, 0, math.rad(70 + jitter(14))), C.bone, M.rock)
			end
			for s = 1, 4 do
				rod(bones, "Leg", 6.5, 0.7,
					CFrame.new(bx - rng:NextNumber(2, 12), Y_FLOOR + 0.6, z - rng:NextNumber(1, 5))
						* CFrame.Angles(0, math.rad(rng:NextNumber(0, 180)), math.rad(88)), C.bone, M.rock)
			end
		end

		------------------------------------------------------------------
		-- Tack, hung where a groom would hang it.
		------------------------------------------------------------------
		if chance(0.75) then
			local hookZ = z + (BAY / 2 - 2.2) * (if chance(0.5) then 1 else -1)
			rod(stall, "Peg", 2.2, 0.55, CFrame.new(X_BACK - 4.6, Y_FLOOR + 6.2, hookZ), C.woodDark, M.log)
			local what = rng:NextInteger(1, 3)
			if what == 1 then
				-- A saddle over the peg.
				block(stall, "Saddle", Vector3.new(3.6, 2.4, 5),
					CFrame.new(X_BACK - 5.4, Y_FLOOR + 5, hookZ) * CFrame.Angles(math.rad(jitter(8)), 0, 0),
					C.leather, M.cloth)
				block(stall, "Girth", Vector3.new(1, 3.4, 1.2),
					CFrame.new(X_BACK - 5.4, Y_FLOOR + 2.6, hookZ), C.leather, M.cloth)
			elseif what == 2 then
				-- A bridle: two straps and a bit.
				for _, dz in { -0.8, 0.8 } do
					block(stall, "Strap", Vector3.new(0.5, 4.6, 0.7),
						CFrame.new(X_BACK - 5, Y_FLOOR + 4.2, hookZ + dz) * CFrame.Angles(0, 0, math.rad(dz * 5)),
						C.leather, M.cloth)
				end
				rod(stall, "Bit", 2.4, 0.35, CFrame.new(X_BACK - 5, Y_FLOOR + 2, hookZ), C.iron, M.rusted)
			else
				-- A coil of rope.
				for c = 1, 4 do
					rod(stall, "Coil", 0.6, 2.6 - c * 0.3,
						CFrame.new(X_BACK - 5, Y_FLOOR + 5.4 - c * 0.5, hookZ) * CFrame.Angles(0, math.rad(90), 0),
						C.straw, M.cloth)
				end
			end
		end

		-- A bucket, upright or kicked over.
		if chance(0.7) then
			local bx = rng:NextNumber(X_FRONT + 4, X_BACK - 8)
			local tipped = chance(0.45)
			local bucket = rod(
				stall,
				"Bucket",
				2.8,
				3.2,
				CFrame.new(bx, Y_FLOOR + (if tipped then 1.6 else 1.5), z + jitter(4))
					* CFrame.Angles(0, 0, math.rad(if tipped then 0 else 90)),
				C.woodPale,
				M.wood
			)
			bucket.Color = if chance(0.5) then C.woodPale else C.woodGrey
			rod(stall, "Hoop", 0.4, 3.4, bucket.CFrame * CFrame.new(0.9, 0, 0), C.iron, M.rusted)
			rod(stall, "Hoop", 0.4, 3.4, bucket.CFrame * CFrame.new(-0.9, 0, 0), C.iron, M.rusted)
		end
	end
end

--==========================================================================
-- THE TACK ROOM — bay 1, boarded and doored
--==========================================================================
do
	local room = group(root, "TackRoom")
	local z = bayZ(1)

	-- Boarded front, with a door hanging open.
	for b = 0, 5 do
		local y = Y_FLOOR + 1.6 + b * 1.6
		block(
			room,
			"Boarding",
			Vector3.new(0.8, 1.5, BAY - 1),
			CFrame.new(X_FRONT + 0.3, y, z),
			if b % 2 == 0 then C.woodPale else C.wood,
			M.wood
		)
	end
	local hinge = CFrame.new(X_FRONT + 0.3, Y_FLOOR + 5, z + BAY / 2 - 1.2)
	local door = hinge * CFrame.Angles(0, math.rad(-48), 0) * CFrame.new(0, 0, -3.4)
	block(room, "Door", Vector3.new(1, 10, 6.8), door, C.woodDark, M.wood)
	for _, dy in { -3.4, 0, 3.4 } do
		block(room, "DoorBand", Vector3.new(1.5, 0.9, 6.8), door * CFrame.new(0, dy, 0), C.iron, M.rusted)
	end

	-- A bench along the back, with the things that live on one.
	block(room, "Bench", Vector3.new(4.6, 1, BAY - 4), CFrame.new(X_BACK - 4, Y_FLOOR + 4.4, z), C.wood, M.wood)
	for _, dz in { -4, 4 } do
		block(room, "BenchLeg", Vector3.new(1.2, 4, 1.2), CFrame.new(X_BACK - 4, Y_FLOOR + 2, z + dz), C.woodDark, M.log)
	end
	block(room, "Crate", Vector3.new(4, 3.4, 4), CFrame.new(X_BACK - 5, Y_FLOOR + 1.9, z - 5.5)
		* CFrame.Angles(0, math.rad(18), 0), C.woodGrey, M.wood)
	block(room, "Anvil", Vector3.new(1.8, 1.4, 4), CFrame.new(X_BACK - 4, Y_FLOOR + 5.6, z + 2), C.iron, M.iron)

	-- Horseshoes on a nail, a rasp, an oil jar.
	for s = 1, 5 do
		rod(room, "Shoe", 0.5, 2.4,
			CFrame.new(X_BACK - 2.4, Y_FLOOR + 9 - s * 0.35, z - 3 + s * 0.15) * CFrame.Angles(0, math.rad(90), 0),
			C.iron, M.rusted)
	end
	block(room, "Rasp", Vector3.new(0.5, 0.8, 6), CFrame.new(X_BACK - 4, Y_FLOOR + 5.2, z - 2)
		* CFrame.Angles(0, math.rad(12), 0), C.iron, M.rusted)
	rod(room, "OilJar", 3.2, 2.4, CFrame.new(X_BACK - 5, Y_FLOOR + 6.5, z + 5) * CFrame.Angles(0, 0, math.rad(90)),
		C.stoneWarm, M.rock)
end

--==========================================================================
-- THE LOFT — over the back half, with a hoist beam and no way up
--==========================================================================
do
	local loft = group(root, "Loft")
	local yLoft = Y_FLOOR + 11.5
	local from, to = Z1 - BAY, Z2 + BAY * 3

	block(loft, "LoftBeam", Vector3.new(2.4, 2.4, from - to),
		CFrame.new(X_BACK - 9, yLoft - 1.2, (from + to) / 2), C.woodDark, M.log)

	-- Floorboards, with three missing.
	local boards = math.floor((from - to) / 2.4)
	for b = 0, boards do
		if not chance(0.09) then
			block(loft, "LoftBoard", Vector3.new(9, 0.5, 2.2),
				CFrame.new(X_BACK - 5, yLoft, from - b * 2.4 + jitter(0.15)),
				if b % 3 == 0 then C.woodPale else C.wood, M.wood)
		end
	end

	-- Bales stacked where they were thrown up.
	for b = 1, 6 do
		local bz = rng:NextNumber(to + 4, from - 4)
		block(loft, "Bale", Vector3.new(5, 3, 4),
			CFrame.new(X_BACK - 5.5 + jitter(1.5), yLoft + 1.9, bz) * CFrame.Angles(0, math.rad(jitter(22)), 0),
			if chance(0.5) then C.straw else C.strawDark, M.grass)
		-- The two cords round it.
		for _, dz in { -1.2, 1.2 } do
			block(loft, "BaleCord", Vector3.new(5.2, 0.3, 0.3),
				CFrame.new(X_BACK - 5.5, yLoft + 1.9, bz + dz), C.strawDark, M.cloth)
		end
	end

	-- Loose hay falling through where the boards are gone.
	for h = 1, 8 do
		block(loft, "LooseHay", Vector3.new(rng:NextNumber(2, 5), rng:NextNumber(1.5, 4), rng:NextNumber(1, 3)),
			CFrame.new(X_BACK - 6 + jitter(3), yLoft - rng:NextNumber(1, 5), rng:NextNumber(to, from))
				* CFrame.Angles(math.rad(jitter(30)), math.rad(jitter(40)), 0),
			C.straw, M.grass)
	end

	--[[
		The hoist beam, projecting from the gable with its pulley and rope. This
		is the ONLY thing in the range that suggests height, and it is eleven
		studs up with nothing under it — the way up is the ladder lying in the
		yard, which is the point.
	]]
	block(loft, "HoistBeam", Vector3.new(2, 2, 14),
		CFrame.new(X_BACK - 8, Y_FLOOR + 16, Z1 + 4), C.woodDark, M.log)
	rod(loft, "Pulley", 1.2, 2.6, CFrame.new(X_BACK - 8, Y_FLOOR + 15, Z1 + 9) * CFrame.Angles(0, math.rad(90), 0),
		C.iron, M.rusted)
	rod(loft, "HoistRope", 9, 0.4, CFrame.new(X_BACK - 8, Y_FLOOR + 10.4, Z1 + 9) * CFrame.Angles(0, 0, math.rad(90)),
		C.straw, M.cloth)
	rod(loft, "HoistHook", 1.8, 0.6, CFrame.new(X_BACK - 8, Y_FLOOR + 5.6, Z1 + 9) * CFrame.Angles(0, 0, math.rad(50)),
		C.iron, M.rusted)
end

--==========================================================================
-- THE YARD
--==========================================================================
do
	local yard = group(root, "Yard")
	local xy = X_FRONT - 12 -- the middle of the working strip in front

	--[[
		The yard stops ten studs short of the range's north end. The road comes
		out of the chamber-1 passage at x = 115 and cuts down across this corner
		— at z = -212 it is already at x = 61, which is right where loose
		cobbles would be. Nothing this tool builds may sit on the road; that is
		the one rule BuildChambers enforces and this has to keep.
	]]
	local YARD_N = Z1 - 10
	local YARD_S = Z2 - 4

	-- Cobbles, worn into a hollow where the water ran.
	for i = 1, 26 do
		block(yard, "Cobble",
			Vector3.new(rng:NextNumber(4, 9), 0.4, rng:NextNumber(4, 9)),
			CFrame.new(rng:NextNumber(X_FRONT - 20, X_FRONT - 1), BASE + 0.15, rng:NextNumber(YARD_S, YARD_N))
				* CFrame.Angles(0, math.rad(rng:NextNumber(0, 90)), 0),
			if chance(0.5) then C.stonePale else C.stoneWarm, M.cobble)
	end

	-- The trough: a hollowed block, still holding black water.
	local tz = bayZ(4)
	block(yard, "Trough", Vector3.new(5, 3.4, 16), CFrame.new(xy, BASE + 1.7, tz), C.stone, M.rock)
	block(yard, "TroughHollow", Vector3.new(3.4, 2, 14.4), CFrame.new(xy, BASE + 2.6, tz), C.stoneDark, M.rock)
	local water = block(yard, "Water", Vector3.new(3.2, 0.2, 14.2), CFrame.new(xy, BASE + 2.9, tz), C.water, Enum.Material.Glass)
	water.Transparency = 0.35
	water.Reflectance = 0.25
	water.CanCollide = false

	-- The muck heap, downwind at the far end.
	for m = 1, 9 do
		block(yard, "Heap",
			Vector3.new(rng:NextNumber(5, 11), rng:NextNumber(1.5, 3.5), rng:NextNumber(5, 11)),
			CFrame.new(X_FRONT - 16 + jitter(5), BASE + rng:NextNumber(0.4, 2), Z2 + 8 + jitter(6))
				* CFrame.Angles(0, math.rad(rng:NextNumber(0, 90)), 0),
			if chance(0.6) then C.muck else C.strawDark, M.ground)
	end

	-- The cart: one wheel on, one off and leaning against it.
	do
		local cart = group(yard, "Cart")
		local cx, cz = X_FRONT - 17, bayZ(6)
		block(cart, "Bed", Vector3.new(9, 1.2, 16), CFrame.new(cx, BASE + 4.2, cz)
			* CFrame.Angles(0, 0, math.rad(-6)), C.wood, M.wood)
		for _, dz in { -8, 8 } do
			block(cart, "Side", Vector3.new(9, 3.4, 0.8), CFrame.new(cx, BASE + 6, cz + dz)
				* CFrame.Angles(0, 0, math.rad(-6)), C.woodPale, M.wood)
		end
		block(cart, "Axle", Vector3.new(13, 1, 1), CFrame.new(cx, BASE + 3.2, cz), C.woodDark, M.log)
		for _, sh in { 1, -1 } do
			block(cart, "Shaft", Vector3.new(1.2, 1.2, 13), CFrame.new(cx + sh * 3.2, BASE + 3.6, cz + 13)
				* CFrame.Angles(math.rad(10), 0, 0), C.woodDark, M.log)
		end
		-- The wheel still on it.
		-- Spokes turn about the wheel's own axle, which is its LOCAL X.
		local wheel = rod(cart, "Wheel", 1.2, 8.4, CFrame.new(cx + 5.5, BASE + 4.2, cz), C.woodDark, M.log)
		for s = 0, 5 do
			block(cart, "Spoke", Vector3.new(0.9, 7.8, 0.9),
				wheel.CFrame * CFrame.Angles(math.rad(s * 60), 0, 0), C.woodPale, M.log)
		end
		-- And the one that came off.
		local off = rod(cart, "WheelOff", 1.2, 8.4,
			CFrame.new(cx - 8, BASE + 4.4, cz - 6) * CFrame.Angles(0, 0, math.rad(74)), C.woodDark, M.log)
		for s = 0, 5 do
			block(cart, "Spoke", Vector3.new(0.9, 7.8, 0.9),
				off.CFrame * CFrame.Angles(math.rad(s * 60), 0, 0), C.woodPale, M.log)
		end
	end

	-- The hitching rail.
	for _, dz in { -9, 0, 9 } do
		block(yard, "RailPost", Vector3.new(1.6, 7, 1.6), CFrame.new(X_FRONT - 22, BASE + 3.5, bayZ(2) + dz), C.woodDark, M.log)
	end
	block(yard, "Rail", Vector3.new(1.4, 1.4, 20), CFrame.new(X_FRONT - 22, BASE + 6.6, bayZ(2)), C.wood, M.log)
	for i = 1, 3 do
		rod(yard, "TieRope", 3.4, 0.35,
			CFrame.new(X_FRONT - 22, BASE + 5, bayZ(2) - 8 + i * 6) * CFrame.Angles(0, 0, math.rad(80 + jitter(20))),
			C.straw, M.cloth)
	end

	--[[
		The ladder, lying down. It is the whole reason the loft is legible and
		the whole reason nobody can reach the wall walk: there WAS a way up, and
		it is on the floor.
	]]
	do
		local lz = bayZ(7)
		local base = CFrame.new(X_FRONT - 9, BASE + 0.6, lz) * CFrame.Angles(0, math.rad(24), 0)
		for _, dz in { -1.8, 1.8 } do
			block(yard, "Stile", Vector3.new(1, 0.9, 22), base * CFrame.new(dz, 0, 0), C.woodPale, M.log)
		end
		for r = -4, 4 do
			block(yard, "Rung", Vector3.new(4.4, 0.7, 0.7), base * CFrame.new(0, 0, r * 2.4), C.wood, M.log)
		end
	end

	-- Barrels, a pitchfork, a shovel, a broom.
	for b = 1, 4 do
		local bx = rng:NextNumber(X_FRONT - 20, X_FRONT - 5)
		local bz = rng:NextNumber(Z2 + 6, YARD_N - 4)
		local down = chance(0.3)
		local barrel = rod(yard, "Barrel", 6.4, 5,
			CFrame.new(bx, BASE + (if down then 2.5 else 3.2), bz)
				* CFrame.Angles(0, math.rad(rng:NextNumber(0, 180)), math.rad(if down then 0 else 90)),
			C.wood, M.wood)
		for _, d in { -2.2, 0, 2.2 } do
			rod(yard, "Band", 0.5, 5.2, barrel.CFrame * CFrame.new(d, 0, 0), C.iron, M.rusted)
		end
	end

	for _, tool in {
		{ name = "Pitchfork", len = 11, head = 3.2 },
		{ name = "Shovel", len = 10, head = 3.6 },
		{ name = "Broom", len = 10, head = 3 },
	} do
		local tx = rng:NextNumber(X_FRONT - 14, X_FRONT - 4)
		local tz = rng:NextNumber(Z2 + 10, YARD_N - 6)
		local lean = CFrame.new(tx, BASE + 4.5, tz) * CFrame.Angles(math.rad(jitter(20)), 0, math.rad(66))
		rod(yard, tool.name, tool.len, 0.7, lean, C.woodPale, M.log)
		block(yard, tool.name .. "Head", Vector3.new(1, tool.head, 2.6),
			lean * CFrame.new(-tool.len / 2, 0, 0), C.iron, M.rusted)
	end

	-- Weeds, because forty years is a long time for a cobbled yard.
	for w = 1, 22 do
		block(yard, "Weed",
			Vector3.new(rng:NextNumber(1, 3), rng:NextNumber(1, 3.5), rng:NextNumber(1, 3)),
			CFrame.new(rng:NextNumber(X_FRONT - 24, X_FRONT - 1), BASE + 1, rng:NextNumber(Z2, YARD_N))
				* CFrame.Angles(0, math.rad(rng:NextNumber(0, 90)), 0),
			C.thatch, M.grass).CanCollide = false
	end
end

--==========================================================================
-- SELF-CHECK
--==========================================================================
print("")
print("========================== STABLES ===========================")
print(("  built %d parts in Decorations.%s"):format(made, ROOT_NAME))
print(("  range x %d..%d   z %d..%d   %d bays"):format(X_FRONT, X_BACK, Z2, Z1, BAYS))

do
	--[[
		Anything ALREADY standing inside the footprint. Reported, never deleted:
		what to move is a design decision and this is a build tool.
	]]
	local lo = Vector3.new(X_FRONT - 26, BASE - 2, Z2 - 6)
	local hi = Vector3.new(X_BACK + 4, BASE + 24, Z1 + 2)

	local function spans(p: BasePart): (Vector3, Vector3)
		local cf, s = p.CFrame, p.Size
		local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
		local h = Vector3.new(
			math.abs(r.X) * s.X / 2 + math.abs(u.X) * s.Y / 2 + math.abs(l.X) * s.Z / 2,
			math.abs(r.Y) * s.X / 2 + math.abs(u.Y) * s.Y / 2 + math.abs(l.Y) * s.Z / 2,
			math.abs(r.Z) * s.X / 2 + math.abs(u.Z) * s.Y / 2 + math.abs(l.Z) * s.Z / 2
		)
		return p.Position - h, p.Position + h
	end

	local clashes = {}
	for _, d in ipairs(battleground:GetDescendants()) do
		if d:IsA("BasePart") and not d:IsDescendantOf(root) then
			local a, b = spans(d)
			if a.X < hi.X and b.X > lo.X and a.Y < hi.Y and b.Y > lo.Y and a.Z < hi.Z and b.Z > lo.Z then
				local owner = d:FindFirstAncestorOfClass("Model") or d
				clashes[owner:GetFullName()] = (clashes[owner:GetFullName()] or 0) + 1
			end
		end
	end

	local n = 0
	for path, count in pairs(clashes) do
		n += 1
		if n <= 10 then
			print(("  IN THE WAY  %-4d parts  %s"):format(count, path))
		end
	end
	if n == 0 then
		print("  footprint is clear — nothing else was standing here")
	else
		print(("  %d other object(s) overlap the range. Move them, or leave them"):format(n))
		print("  if they read as clutter against the stalls — your call.")
	end
end

print("")
print("  No stairs and no ladder. The loft's way up is lying in the yard.")
print("  Re-run any time: this folder is rebuilt, nothing else is touched.")
print("=========================== END ==============================")
