--[[
	BuildApproach — run in the Studio Command Bar of the FORGOTTEN LANDS place,
	in EDIT MODE. Select the whole file (Ctrl+A), copy, paste, Enter.

	Everything OUTSIDE the gate: the rail line that carried you here, the road it
	feeds, the moat, the causeway across it, and the gate itself — torn off its
	hinges and lying where it fell.

	This stretch has one job. In the first ten seconds, without a word, it has to
	say: you arrived by that, you walk along this, and you go in THERE. So it is
	built as one unbroken line of sight — buffer stop, platform, road, causeway,
	gate — with nothing beside it competing for attention.

	The gate is the set piece. A gate that has merely vanished says nothing; a
	gate lying in its own archway, one leaf splintered flat and the other still
	hanging off a hinge, with the portcullis torn out of its groove and the
	winch chain hanging cut, says the whole story of how this castle fell.

	Everything lands in `Workspace.Gameplay.Approach`. Re-running replaces only
	that. The battleground is untouched.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

--==========================================================================
-- Where things are. These match BuildBattleground.
--==========================================================================
local HALF_W = 150 -- the castle's half-width
local GATE_Z = 20 -- the gate line

local MOAT_Z = 85 -- centre of the channel in front
local MOAT_W = 44 -- how wide the water is
local MOAT_DEPTH = 30
local MOAT_OUT = 62 -- how far the side channels sit off the walls

local PLATFORM_Z = 285 -- where the train stops
local ROAD_W = 30

local DETAIL = 3
local CARVE_MOAT = true

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
	cobble = Color3.fromRGB(78, 74, 68),
	road = Color3.fromRGB(92, 80, 66),
	rut = Color3.fromRGB(70, 60, 48),
	wood = Color3.fromRGB(74, 56, 40),
	woodDark = Color3.fromRGB(48, 36, 26),
	woodSplint = Color3.fromRGB(96, 76, 54),
	iron = Color3.fromRGB(58, 50, 46),
	rust = Color3.fromRGB(96, 56, 36),
	bone = Color3.fromRGB(198, 190, 172),
	boneOld = Color3.fromRGB(158, 150, 130),
	blood = Color3.fromRGB(62, 16, 18),
	bloodOld = Color3.fromRGB(46, 14, 16),
	cloth = Color3.fromRGB(78, 40, 40),
	rag = Color3.fromRGB(92, 84, 66),
	flesh = Color3.fromRGB(88, 96, 74), -- the dead ones are not pink any more
	ash = Color3.fromRGB(38, 36, 36),
}

local M = {
	stone = Enum.Material.Slate,
	cobble = Enum.Material.Cobblestone,
	rock = Enum.Material.Rock,
	brick = Enum.Material.Brick,
	wood = Enum.Material.WoodPlanks,
	log = Enum.Material.Wood,
	iron = Enum.Material.Metal,
	rusted = Enum.Material.CorrodedMetal,
	cloth = Enum.Material.Fabric,
	sand = Enum.Material.Sand,
	ground = Enum.Material.Ground,
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

local old = root:FindFirstChild("Approach")
if old then
	old:Destroy()
end
local approach = Instance.new("Folder")
approach.Name = "Approach"
approach.Parent = root

local made = 0

--==========================================================================
-- The standing folder structure. Every place in this game uses the same five,
-- so anything can be found in the same drawer whichever map you are in.
--==========================================================================
local BUCKETS = { "Buildings", "Nature", "Decorations", "NPCs", "Interactions" }
local bucket = {}

--[[
	Nothing is placed over the moat.

	The channel is carved out of the terrain, so anything dropped across it
	hangs in mid-air over open water — and worse, it has to be fished out by
	hand later. The causeway is the one thing allowed to cross, because it is
	built to.
]]
local function overMoat(z: number, x: number): boolean
	local inFrontChannel = math.abs(z - MOAT_Z) < (MOAT_W / 2 + 8)
	local onCauseway = math.abs(x) < 22
	return inFrontChannel and not onCauseway
end

--[[
	MODEL vs FOLDER, and it matters more than it looks.

	Studio selects the OUTERMOST Model you click. So if every skeleton on the
	field lives inside one big Model called "TheDead", clicking a single rib
	selects all two hundred of them and there is no way to delete just the one.

	A Folder is not selectable that way. So: containers are FOLDERS, and only a
	single, self-contained object — one skeleton, one corpse, one blood pool —
	is a Model. Click a rib, get that skeleton. Click again, get that rib.
]]
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

for _, name in BUCKETS do
	bucket[name] = folder(approach, name)
end

local function jitter(a: number): number
	return rng:NextNumber(-a, a)
end

local function chance(p: number): boolean
	return rng:NextNumber() < p
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

local function mass(parent, name, size, cf, colour, material): Part
	return block(parent, name, size, cf, colour, material, true)
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
	part.Color = colour or C.bone
	part.Material = material or M.sand
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
	part.Color = colour or C.bone
	part.Material = material or M.sand
	part.CastShadow = false
	part.Parent = parent
	made += 1
	return part
end

local function cyl(parent, name, radius, height, at, colour, material): Part
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

--==========================================================================
-- THE DEAD
--==========================================================================
--[[
	A skeleton built to proportion, not a handful of sticks.

	Real bones are what sell this: a skull with a jaw, a ribcage that curves,
	a spine of separate vertebrae, a pelvis wider than it is tall, and limbs in
	TWO segments with a joint between them. Get those five right and the eye
	accepts it instantly; get any of them wrong and it reads as litter.

	Everything is jointed off a single base CFrame so a body can be laid at any
	angle, face down or on its side, and still hang together.
]]
local function skeleton(parent, at: Vector3, facing: number, pose: string)
	local model = group(parent, "Skeleton")

	--[[
		A body is built LYING DOWN already: the spine runs along local Z, head at
		+3.6, feet at -9.6, everything within a stud or so of local y = 0.

		The first version then pitched it ninety degrees on top of that, which
		stood every corpse bolt upright — and sank half of each one into the
		ground for good measure. So there is no pitch here at all. A pose is a
		ROLL about the body's own length, plus a lift that clears the ground for
		whatever that roll makes the widest part.
	]]
	local roll = 0
	local pitch = 0
	local lift = 1.4

	if pose == "facedown" then
		roll = 0
	elseif pose == "faceup" then
		roll = math.rad(180)
	elseif pose == "side" then
		roll = math.rad(90)
		lift = 2.1 -- on its side, the shoulders are what sit lowest
	elseif pose == "curled" then
		roll = math.rad(58)
		lift = 1.9
	elseif pose == "propped" then
		pitch = math.rad(-24) -- head raised, as if it went down against a wall
		lift = 2.4
	end

	local base = CFrame.new(at + Vector3.new(0, lift, 0))
		* CFrame.Angles(0, math.rad(facing), 0)
		* CFrame.Angles(pitch, 0, roll)

	local colour = if chance(0.5) then C.bone else C.boneOld

	local function at3(x, y, z): Vector3
		return (base * CFrame.new(x, y, z)).Position
	end

	-- Skull and jaw.
	ball(model, "Skull", 1.15, at3(0, 0, 3.6), colour, M.sand)
	block(model, "Jaw", Vector3.new(1.5, 0.5, 1.1), base * CFrame.new(0, -0.75, 4), colour, M.sand)
	-- Eye sockets: two small dark voids are what make a ball read as a skull.
	for side = -1, 1, 2 do
		ball(model, "Socket", 0.34, at3(side * 0.45, 0.2, 4.5), C.ash, M.sand)
	end

	-- Spine, vertebra by vertebra.
	for i = 0, 5 do
		local z = 2.6 - i * 0.85
		ball(model, "Vertebra", 0.36, at3(0, 0, z), colour, M.sand)
	end

	-- Ribcage: six pairs, each curving out and forward.
	for i = 0, 5 do
		local z = 2.2 - i * 0.62
		local spread = 1.5 - math.abs(i - 2) * 0.22
		for side = -1, 1, 2 do
			bar(model, "Rib", 0.16, at3(0, 0, z), at3(side * spread, -0.5, z - 0.35), colour, M.sand)
			bar(model, "Rib", 0.15, at3(side * spread, -0.5, z - 0.35), at3(side * spread * 0.62, -1.15, z - 0.6), colour, M.sand)
		end
	end

	-- Collarbones and shoulder blades.
	for side = -1, 1, 2 do
		bar(model, "Clavicle", 0.18, at3(0, 0.2, 2.5), at3(side * 1.5, 0.1, 2.3), colour, M.sand)
	end

	-- Pelvis: wider than it is tall, which is the tell.
	block(model, "Pelvis", Vector3.new(2.5, 0.7, 1.5), base * CFrame.new(0, -0.2, -2.6), colour, M.sand)

	-- Legs, in two segments with a knee between.
	for side = -1, 1, 2 do
		local hip = at3(side * 0.85, -0.2, -3)
		local sprawl = if pose == "curled" then side * 1.9 else side * 0.5
		local knee = at3(side * 0.85 + sprawl, -0.4, -6.2)
		local ankle = at3(side * 0.85 + sprawl * (if pose == "curled" then 0.4 else 1.2), -0.5, -9.6)
		bar(model, "Femur", 0.3, hip, knee, colour, M.sand)
		ball(model, "Knee", 0.36, knee, colour, M.sand)
		bar(model, "Tibia", 0.26, knee, ankle, colour, M.sand)
		block(model, "Foot", Vector3.new(0.8, 0.4, 1.6), CFrame.new(ankle) * CFrame.Angles(0, math.rad(facing), 0), colour, M.sand)
	end

	-- Arms. One is usually thrown out; that is how people fall.
	for side = -1, 1, 2 do
		local shoulder = at3(side * 1.5, 0.1, 2.3)
		local out = if side == 1 then 2.6 else 1.2
		local elbow = at3(side * (1.5 + out), -0.3, 0.4)
		local wrist = at3(side * (1.5 + out * 1.3), -0.4, -1.6)
		bar(model, "Humerus", 0.26, shoulder, elbow, colour, M.sand)
		ball(model, "Elbow", 0.3, elbow, colour, M.sand)
		bar(model, "Radius", 0.22, elbow, wrist, colour, M.sand)
		-- A hand is five tiny bones, and at this size three is enough.
		for f = -1, 1 do
			bar(model, "Finger", 0.11, wrist, wrist + Vector3.new(jitter(0.7), -0.1, -0.6 + f * 0.2), colour, M.sand)
		end
	end

	-- What they were wearing, and what they were holding.
	if DETAIL >= 2 and chance(0.6) then
		block(model, "Rag", Vector3.new(3, 0.2, 4), base * CFrame.new(jitter(0.5), -0.6, 0.4) * CFrame.Angles(0, math.rad(jitter(20)), 0), if chance(0.5) then C.cloth else C.rag, M.cloth)
	end
	if DETAIL >= 2 and chance(0.45) then
		local hand = at3(2.6, -0.4, -1.6)
		bar(model, "Spear", 0.2, hand + Vector3.new(0, 0, 2), hand + Vector3.new(jitter(3), 0.2, -7), C.woodDark, M.log)
	end
	if DETAIL >= 3 and chance(0.35) then
		block(model, "Helm", Vector3.new(2.2, 1.6, 2.2), base * CFrame.new(jitter(3), 0.3, 5.5) * CFrame.Angles(jitter(0.6), rng:NextNumber(0, 3), jitter(0.6)), C.rust, M.rusted)
	end

	return model
end

--[[
	A pool of blood, forty years old.

	One flat disc reads as a sticker. What reads as blood is an IRREGULAR body —
	several overlapping ellipses of slightly different size and darkness — with
	a few separate droplets thrown clear of it, because blood spatters before it
	pools. Old blood is nearly black at the centre and browner at the edge.
]]
local function bloodPool(parent, at: Vector3, size: number)
	local model = group(parent, "Blood")

	for i = 1, 5 do
		local s = size * rng:NextNumber(0.45, 1)
		local part = cyl(model, "Pool", s / 2, 0.14, at + Vector3.new(jitter(size * 0.35), 0.07 + i * 0.005, jitter(size * 0.35)), if i <= 2 then C.bloodOld else C.blood, M.sand)
		part.CFrame = CFrame.new(part.Position) * CFrame.Angles(math.rad(90), rng:NextNumber(0, 3), 0)
		-- Squashed into an ellipse: a perfect circle is the giveaway.
		part.Size = Vector3.new(0.14, s, s * rng:NextNumber(0.55, 1))
	end

	if DETAIL >= 2 then
		for _ = 1, math.floor(size) do
			local a = rng:NextNumber() * math.pi * 2
			local d = size * rng:NextNumber(0.6, 1.6)
			local s = rng:NextNumber(0.3, 1.1)
			local drop = cyl(model, "Droplet", s / 2, 0.12, at + Vector3.new(math.cos(a) * d, 0.08, math.sin(a) * d), C.blood, M.sand)
			drop.CFrame = CFrame.new(drop.Position) * CFrame.Angles(math.rad(90), rng:NextNumber(0, 3), 0)
			drop.Size = Vector3.new(0.12, s, s * rng:NextNumber(0.4, 1))
		end
	end
	return model
end

-- A dead one of the things that took this castle. Bulkier than a skeleton,
-- still fleshed, and always face down — nothing here fell backwards.
local function corpse(parent, at: Vector3, facing: number)
	local model = group(parent, "Corpse")
	-- Built lying down, like the skeletons, and for the same reason: the torso
	-- is already long in Z and flat in Y. Only a small roll, never a pitch.
	local base = CFrame.new(at + Vector3.new(0, 1.1, 0))
		* CFrame.Angles(0, math.rad(facing), 0)
		* CFrame.Angles(0, 0, math.rad(jitter(22)))

	block(model, "Torso", Vector3.new(3.6, 1.8, 5), base * CFrame.new(0, 0.9, 0), C.flesh, M.sand)
	block(model, "Hips", Vector3.new(3.2, 1.6, 2), base * CFrame.new(0, 0.9, -3), C.flesh, M.sand)
	ball(model, "Head", 1.3, (base * CFrame.new(jitter(0.6), 0.9, 3.4)).Position, C.flesh, M.sand)
	for side = -1, 1, 2 do
		block(model, "Arm", Vector3.new(1.2, 1.2, 4.4), base * CFrame.new(side * 2.4, 0.7, 0.6) * CFrame.Angles(0, math.rad(side * 22), 0), C.flesh, M.sand)
		block(model, "Leg", Vector3.new(1.4, 1.4, 5), base * CFrame.new(side * 1, 0.8, -5.4) * CFrame.Angles(math.rad(jitter(14)), 0, 0), C.flesh, M.sand)
	end
	block(model, "Rags", Vector3.new(4.2, 0.3, 5.4), base * CFrame.new(0, 1.85, -0.4) * CFrame.Angles(0, math.rad(jitter(14)), 0), C.rag, M.cloth)
	if DETAIL >= 2 then
		bloodPool(model, at + Vector3.new(jitter(2), 0, jitter(2)), rng:NextNumber(5, 9))
	end
	return model
end

--==========================================================================
-- THE RAIL LINE — how you got here
--==========================================================================
local rails = group(bucket.Buildings, "RailLine")
do
	local fromZ, toZ = 620, PLATFORM_Z - 20

	-- Ballast: the stone bed the sleepers sit in.
	block(rails, "Ballast", Vector3.new(34, 1.6, fromZ - toZ), CFrame.new(0, 0.8, (fromZ + toZ) / 2), C.rock, M.rock)

	for z = toZ, fromZ, 7 do
		block(rails, "Sleeper", Vector3.new(24, 1.2, 3.2), CFrame.new(0, 1.9, z) * CFrame.Angles(0, math.rad(jitter(1.5)), 0), C.woodDark, M.log)
	end
	for side = -1, 1, 2 do
		block(rails, "Rail", Vector3.new(1.4, 1.4, fromZ - toZ), CFrame.new(side * 7, 3.1, (fromZ + toZ) / 2), C.rust, M.rusted)
		-- Chairs: the little iron blocks holding the rail to each sleeper.
		if DETAIL >= 3 then
			for z = toZ, fromZ, 21 do
				block(rails, "Chair", Vector3.new(2.6, 1, 2.6), CFrame.new(side * 7, 2.6, z), C.iron, M.rusted)
			end
		end
	end

	-- Buffer stop: the line ENDS here, and the eye needs to be told that.
	local stop = group(rails, "BufferStop")
	mass(stop, "Block", Vector3.new(26, 7, 5), CFrame.new(0, 4.5, toZ - 4), C.stoneDark, M.stone)
	for side = -1, 1, 2 do
		block(stop, "Buffer", Vector3.new(3, 3, 3), CFrame.new(side * 7, 4.6, toZ - 7), C.rust, M.rusted)
		block(stop, "Brace", Vector3.new(1.6, 1.6, 9), CFrame.new(side * 7, 6.5, toZ + 1) * CFrame.Angles(math.rad(28), 0, 0), C.iron, M.rusted)
	end
end

--==========================================================================
-- THE PLATFORM — the last working thing
--==========================================================================
local platform = group(bucket.Buildings, "Platform")
do
	mass(platform, "Deck", Vector3.new(72, 4, 86), CFrame.new(0, 2, PLATFORM_Z + 16), C.stonePale, M.stone)
	block(platform, "Coping", Vector3.new(72, 1, 3), CFrame.new(0, 4.4, PLATFORM_Z - 26), C.stoneDark, M.stone)

	for side = -1, 1, 2 do
		for i = 0, 3 do
			block(platform, "Post", Vector3.new(1.8, 15, 1.8), CFrame.new(side * 31, 11.5, PLATFORM_Z - 12 + i * 22), C.woodDark, M.log)
		end
		block(platform, "Canopy", Vector3.new(11, 1.2, 84), CFrame.new(side * 31, 19.5, PLATFORM_Z + 16), C.woodDark, M.wood)
		block(platform, "Fascia", Vector3.new(11, 2.4, 1), CFrame.new(side * 31, 18.4, PLATFORM_Z - 25), C.wood, M.wood)
	end

	if DETAIL >= 2 then
		for _, z in { PLATFORM_Z - 6, PLATFORM_Z + 24, PLATFORM_Z + 48 } do
			block(platform, "Bench", Vector3.new(13, 0.8, 3.4), CFrame.new(23, 5.6, z), C.wood, M.wood)
			for s = -1, 1, 2 do
				block(platform, "BenchLeg", Vector3.new(0.9, 2.2, 3), CFrame.new(23 + s * 5.5, 4.5, z), C.woodDark, M.log)
			end
		end
		-- Luggage nobody came back for.
		for _ = 1, 7 do
			local s = rng:NextNumber(3, 5)
			block(bucket.Decorations, "Crate", Vector3.new(s, s, s), CFrame.new(rng:NextNumber(-28, -16), 4 + s / 2, rng:NextNumber(PLATFORM_Z - 14, PLATFORM_Z + 40)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), C.wood, M.wood)
		end
	end
end

--==========================================================================
-- THE ROAD — the line the eye follows to the gate
--==========================================================================
local road = group(bucket.Buildings, "Road")
do
	local fromZ, toZ = PLATFORM_Z - 28, MOAT_Z + MOAT_W / 2

	block(road, "Bed", Vector3.new(ROAD_W + 8, 1.4, fromZ - toZ), CFrame.new(0, 0.7, (fromZ + toZ) / 2), C.road, M.ground)

	-- Cobbles, laid in courses and missing a few.
	if DETAIL >= 2 then
		for z = toZ, fromZ, 5 do
			for i = -3, 3 do
				if not chance(0.14) then
					block(road, "Cobble", Vector3.new(ROAD_W / 7.4, 0.6, 4.6), CFrame.new(i * (ROAD_W / 7) + jitter(0.5), 1.5, z + jitter(0.8)) * CFrame.Angles(0, math.rad(jitter(6)), 0), C.cobble, M.cobble)
				end
			end
		end
		-- Kerbs, and the ruts worn between them by forty years of carts that
		-- stopped coming.
		for side = -1, 1, 2 do
			block(road, "Kerb", Vector3.new(2.4, 1.6, fromZ - toZ), CFrame.new(side * (ROAD_W / 2 + 1.5), 1.5, (fromZ + toZ) / 2), C.stonePale, M.stone)
			block(road, "Rut", Vector3.new(4.4, 0.3, fromZ - toZ), CFrame.new(side * 6, 1.75, (fromZ + toZ) / 2), C.rut, M.ground)
		end
	end

	if DETAIL >= 3 then
		for i = 1, 3 do
			block(road, "Milestone", Vector3.new(2.8, 5.5, 2), CFrame.new(-(ROAD_W / 2 + 8), 2.7, fromZ - i * 55) * CFrame.Angles(0, math.rad(jitter(14)), math.rad(jitter(8))), C.stonePale, M.stone)
		end
	end
end

--==========================================================================
-- THE MOAT
--==========================================================================
local moat = group(bucket.Buildings, "Moat")
if CARVE_MOAT then
	--[[
		Cut, then flood, then face the edges in stone. The revetment is what
		separates a moat from a ditch: somebody built this, and the fact that it
		is faced tells you they built it to last, and it still did not save them.
	]]
	local function channel(centre: Vector3, size: Vector3)
		workspace.Terrain:FillBlock(CFrame.new(centre), size, Enum.Material.Air)
		workspace.Terrain:FillBlock(
			CFrame.new(centre - Vector3.new(0, size.Y / 2 - MOAT_DEPTH * 0.32, 0)),
			Vector3.new(size.X, MOAT_DEPTH * 0.64, size.Z),
			Enum.Material.Water
		)
	end

	local length = 1900
	local midZ = GATE_Z - 880

	-- Front, across the approach.
	channel(Vector3.new(0, -MOAT_DEPTH / 2 + 2, MOAT_Z), Vector3.new(HALF_W * 2 + MOAT_OUT * 2 + 90, MOAT_DEPTH, MOAT_W))
	-- Both flanks.
	for side = -1, 1, 2 do
		channel(Vector3.new(side * (HALF_W + MOAT_OUT), -MOAT_DEPTH / 2 + 2, midZ), Vector3.new(MOAT_W, MOAT_DEPTH, length))
	end
	-- And behind, so it is a ring and not a trench.
	channel(Vector3.new(0, -MOAT_DEPTH / 2 + 2, GATE_Z - 1840), Vector3.new(HALF_W * 2 + MOAT_OUT * 2 + 90, MOAT_DEPTH, MOAT_W))

	task.wait()

	-- Stone facing along the near edge of the front channel, where it is seen.
	if DETAIL >= 2 then
		local wall = HALF_W + MOAT_OUT + 45
		for x = -wall, wall, 12 do
			if math.abs(x) > ROAD_W / 2 + 6 then
				for side = -1, 1, 2 do
					block(moat, "Revetment", Vector3.new(12.4, 10, 3), CFrame.new(x, -3, MOAT_Z + side * (MOAT_W / 2)), C.stoneWarm, M.stone)
					block(moat, "Coping", Vector3.new(12.4, 1.6, 5), CFrame.new(x, 2.2, MOAT_Z + side * (MOAT_W / 2)), C.stonePale, M.stone)
				end
			end
		end
	end
end

--==========================================================================
-- THE CAUSEWAY — the only way across
--==========================================================================
local causeway = group(bucket.Buildings, "Causeway")
do
	local fromZ, toZ = MOAT_Z + MOAT_W / 2 + 4, MOAT_Z - MOAT_W / 2 - 4
	local width = 34

	mass(causeway, "Deck", Vector3.new(width, 4, fromZ - toZ), CFrame.new(0, 1, (fromZ + toZ) / 2), C.stone, M.stone)

	-- Two arches under it, and a pier between them standing in the water.
	for _, z in { MOAT_Z + 11, MOAT_Z - 11 } do
		for i = 0, 7 do
			local a = math.pi * (i / 7)
			cyl(causeway, "Arch", 2.4, width, Vector3.new(math.cos(a) * 9, -1 - math.sin(a) * 9, z), C.stone, M.stone)
		end
	end
	mass(causeway, "Pier", Vector3.new(width, 14, 7), CFrame.new(0, -6, MOAT_Z), C.stoneWarm, M.stone)
	-- A cutwater: the wedge that splits the current. Nobody builds a pier without one.
	block(causeway, "Cutwater", Vector3.new(7, 14, 7), CFrame.new(0, -6, MOAT_Z + 5) * CFrame.Angles(0, math.rad(45), 0), C.stoneWarm, M.stone)

	if DETAIL >= 2 then
		for side = -1, 1, 2 do
			-- The parapet is broken in one place, and only one. Two would read as
			-- neglect; one reads as something heavy going over the edge.
			for z = toZ, fromZ, 8 do
				if not (side == 1 and z > MOAT_Z - 6 and z < MOAT_Z + 10) then
					block(causeway, "Parapet", Vector3.new(2.6, 7, 8.2), CFrame.new(side * (width / 2 - 1), 6.5, z), C.stoneDark, M.stone)
					block(causeway, "Capstone", Vector3.new(3.4, 1, 8.4), CFrame.new(side * (width / 2 - 1), 10.5, z), C.stonePale, M.stone)
				end
			end
		end
		-- And the piece of it that went in, lying in the water below.
		for _ = 1, 4 do
			local s = rng:NextNumber(4, 9)
			block(causeway, "Fallen", Vector3.new(s, s * 0.6, s * 1.2), CFrame.new(rng:NextNumber(18, 30), -MOAT_DEPTH * 0.55, MOAT_Z + jitter(9)) * CFrame.Angles(jitter(0.6), rng:NextNumber(0, 3), jitter(0.6)), C.stoneDark, M.stone)
		end
	end
end

--==========================================================================
-- THE FALLEN GATE — the set piece
--==========================================================================
local gate = group(bucket.Buildings, "FallenGate")
do
	local GW = 34 -- the opening, matching the gatehouse

	--[[
		The doors. Each leaf is a raft of vertical planks banded with iron, and
		each is destroyed differently, because two identical wrecks read as
		wallpaper:

		  WEST  — thrown flat into the passage, face up, split down the middle.
		  EAST  — still on its top hinge, hanging inward at an angle, the bottom
		          third smashed out of it.

		The hinges tell the rest. The pintles are still in the stone; the straps
		are still on the wood; they are simply not attached to each other any
		more, which is what happens when something big enough goes through.
	]]

	-- WEST leaf: flat on the ground, split.
	local west = group(gate, "WestLeaf")
	local westBase = CFrame.new(-9, 1.2, GATE_Z - 26) * CFrame.Angles(0, math.rad(12), 0)
	for half = -1, 1, 2 do
		for i = 0, 6 do
			block(west, "Plank", Vector3.new(2.2, 1.4, 30), westBase * CFrame.new(half * 9 + i * 2.3 - 7, jitter(0.15), jitter(0.6)) * CFrame.Angles(0, math.rad(half * 2.5), math.rad(jitter(2))), C.woodDark, M.wood)
		end
		for _, z in { -10, 2, 12 } do
			block(west, "Band", Vector3.new(17, 0.6, 2.4), westBase * CFrame.new(half * 9 - 1, 0.9, z), C.rust, M.rusted)
			block(west, "Boss", Vector3.new(1.6, 1, 1.6), westBase * CFrame.new(half * 9 - 6, 1.3, z), C.iron, M.rusted)
			block(west, "Boss", Vector3.new(1.6, 1, 1.6), westBase * CFrame.new(half * 9 + 4, 1.3, z), C.iron, M.rusted)
		end
	end
	-- The split: splintered ends pointing up out of the break.
	for _ = 1, 9 do
		block(west, "Splinter", Vector3.new(0.8, rng:NextNumber(2, 5), 1), westBase * CFrame.new(jitter(2), 1.6, jitter(13)) * CFrame.Angles(math.rad(jitter(40)), math.rad(jitter(30)), math.rad(jitter(40))), C.woodSplint, M.log)
	end

	-- EAST leaf: still hanging, bottom smashed out.
	local east = group(gate, "EastLeaf")
	local eastBase = CFrame.new(GW / 2 - 2, 20, GATE_Z + 2) * CFrame.Angles(0, math.rad(-38), math.rad(6))
	for i = 0, 7 do
		local height = if i > 4 then rng:NextNumber(9, 16) else 26
		block(east, "Plank", Vector3.new(2.2, height, 1.4), eastBase * CFrame.new(i * 2.3 - 8, 13 - (26 - height) / 2 - 13, 0) * CFrame.Angles(0, 0, math.rad(jitter(1.5))), C.woodDark, M.wood)
	end
	for _, y in { 4, -4 } do
		block(east, "Band", Vector3.new(19, 2.4, 0.6), eastBase * CFrame.new(0, y, -0.9), C.rust, M.rusted)
	end
	for _ = 1, 7 do
		block(east, "Splinter", Vector3.new(0.8, rng:NextNumber(2, 4), 1), eastBase * CFrame.new(jitter(8), -11 + jitter(2), 0) * CFrame.Angles(math.rad(jitter(40)), 0, math.rad(jitter(40))), C.woodSplint, M.log)
	end
	-- The hinge that held, and the one that did not.
	block(east, "Strap", Vector3.new(9, 2, 1), eastBase * CFrame.new(-6, 10, -0.9), C.iron, M.rusted)
	block(gate, "Pintle", Vector3.new(2.4, 2.4, 4), CFrame.new(GW / 2 + 6, 30, GATE_Z), C.iron, M.rusted)
	block(gate, "Pintle", Vector3.new(2.4, 2.4, 4), CFrame.new(-GW / 2 - 6, 30, GATE_Z), C.iron, M.rusted)
	block(gate, "Strap", Vector3.new(8, 2, 1.4), CFrame.new(-GW / 2 - 2, 30, GATE_Z - 1) * CFrame.Angles(0, 0, math.rad(-24)), C.iron, M.rusted)

	--[[
		The portcullis, torn OUT of its groove rather than merely lowered. It
		lies half in the passage with its spiked foot buried and its head still
		caught on the arch, which is the only way a thing that heavy comes down.
	]]
	local port = group(gate, "Portcullis")
	local portBase = CFrame.new(4, 9, GATE_Z - 12) * CFrame.Angles(math.rad(-58), math.rad(8), math.rad(4))
	for i = 0, 10 do
		block(port, "Bar", Vector3.new(0.9, 40, 0.9), portBase * CFrame.new(i * 3.2 - 16, 0, 0) * CFrame.Angles(0, 0, math.rad(jitter(2))), C.rust, M.rusted)
	end
	for j = 0, 6 do
		block(port, "Rung", Vector3.new(34, 0.8, 0.8), portBase * CFrame.new(0, -20 + j * 6.6, 0), C.rust, M.rusted)
	end
	for i = 0, 10 do
		block(port, "Spike", Vector3.new(0.9, 2.6, 0.9), portBase * CFrame.new(i * 3.2 - 16, -21.5, 0) * CFrame.Angles(math.rad(180), 0, 0), C.iron, M.rusted)
	end
	-- The winch chain, cut, still hanging out of the murder hole.
	do
		local from = Vector3.new(-6, 44, GATE_Z - 3)
		local previous = from
		for i = 1, 9 do
			local point = from + Vector3.new(jitter(0.8), -i * 3.1, jitter(0.8) - i * 0.3)
			bar(port, "ChainLink", 0.3, previous, point, C.rust, M.rusted)
			previous = point
		end
	end

	-- Rubble out of the arch, thickest where the doors gave.
	for _ = 1, 26 do
		local s = rng:NextNumber(3, 12)
		block(gate, "Rubble", Vector3.new(s, s * rng:NextNumber(0.4, 0.8), s * rng:NextNumber(0.6, 1.2)), CFrame.new(jitter(30), s / 3, GATE_Z - rng:NextNumber(-8, 34)) * CFrame.Angles(jitter(0.5), rng:NextNumber(0, 6), jitter(0.5)), if chance(0.5) then C.rock else C.stone, M.rock)
	end
	-- Scorching on the jambs. They tried fire before they tried the ram.
	if DETAIL >= 3 then
		for side = -1, 1, 2 do
			for i = 0, 3 do
				block(gate, "Scorch", Vector3.new(6, 9, 0.3), CFrame.new(side * (GW / 2 + 1), 8 + i * 9, GATE_Z + 5.2) * CFrame.Angles(0, 0, math.rad(jitter(6))), C.ash, M.stone)
			end
		end
	end
end

--==========================================================================
-- THE LAST STAND — where they died holding it
--==========================================================================
if DETAIL >= 2 then
	-- A FOLDER, so clicking a bone selects that skeleton and not all of them.
	local dead = bucket.Decorations

	-- Thickest in the gateway itself, thinning as you go back up the road: they
	-- were pushed backwards, and this is the shape that tells you so.
	local poses = { "facedown", "side", "curled", "propped", "facedown", "faceup" }

	local placedDead = 0
	for i = 1, 34 do
		local t = (i - 1) / 33
		local z = GATE_Z + 8 + t * t * 200
		local spread = 26 + t * 60
		local x, zz = jitter(spread), z + jitter(14)
		if not overMoat(zz, x) then
			skeleton(dead, Vector3.new(x, 0, zz), rng:NextNumber(0, 360), poses[rng:NextInteger(1, #poses)])
			placedDead += 1
		end
	end

	for i = 1, 12 do
		local t = (i - 1) / 11
		local x, zz = jitter(30 + t * 40), GATE_Z + 14 + t * 150 + jitter(12)
		if not overMoat(zz, x) then
			corpse(dead, Vector3.new(x, 0, zz), rng:NextNumber(0, 360))
		end
	end

	for _ = 1, 20 do
		local x, zz = jitter(70), GATE_Z + rng:NextNumber(0, 190)
		if not overMoat(zz, x) then
			bloodPool(dead, Vector3.new(x, 0, zz), rng:NextNumber(5, 14))
		end
	end

	-- A last knot of them at the gateway, shoulder to shoulder. Somebody held
	-- this line until they could not.
	for i = -3, 3 do
		skeleton(dead, Vector3.new(i * 6 + jitter(2), 0, GATE_Z + 6 + jitter(4)), 180 + jitter(24), if chance(0.5) then "facedown" else "side")
	end
	bloodPool(dead, Vector3.new(0, 0, GATE_Z + 6), 22)

	if DETAIL >= 3 then
		-- Their weapons, dropped where they fell.
		for _ = 1, 18 do
			local x, z = jitter(60), GATE_Z + rng:NextNumber(0, 170)
			if not overMoat(z, x) then
				local at = Vector3.new(x, 0.6, z)
				if chance(0.5) then
					bar(dead, "DroppedSpear", 0.22, at, at + Vector3.new(jitter(9), 0.2, jitter(9)), C.woodDark, M.log)
				else
					block(dead, "Shield", Vector3.new(5.4, 0.5, 7.4), CFrame.new(at) * CFrame.Angles(jitter(0.35), rng:NextNumber(0, 3), jitter(0.25)), if chance(0.4) then C.cloth else C.woodDark, M.wood)
				end
			end
		end
		for _ = 1, 26 do
			local x, z = jitter(80), GATE_Z + rng:NextNumber(-4, 200)
			if not overMoat(z, x) then
				local at = Vector3.new(x, 0, z)
				bar(dead, "Arrow", 0.12, at, at + Vector3.new(jitter(1.6), 3.4, jitter(1.6)), C.woodSplint, M.log)
			end
		end
	end
end

--==========================================================================
print(("[Approach] DONE — %d parts."):format(made))
print(("Rails end at z=%d | platform z=%d | road z=%d..%d"):format(PLATFORM_Z - 24, PLATFORM_Z, PLATFORM_Z - 28, MOAT_Z + 22))
print(("Moat centred z=%d, %d wide, %d deep | causeway across it at x=0"):format(MOAT_Z, MOAT_W, MOAT_DEPTH))
print(("Gate line z=%d — both leaves down, portcullis torn out, chain cut."):format(GATE_Z))
print("Everything is in Gameplay.Approach. Re-run to replace only that.")
