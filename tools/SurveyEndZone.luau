--[[
	SurveyEndZone — run in the Studio Command Bar of the FORGOTTEN LANDS place.
	Select the whole file (Ctrl+A), copy, paste, Enter. It CHANGES NOTHING.

	Answers one question: where is there room in the last chamber, and what is
	already standing in it?

	SurveyWorld reports the whole map at a level of detail useful for planning.
	This is the opposite — one chamber, every object in it, with the number that
	actually matters for placing something round next to it: how far its
	bounding box reaches from its own centre.

	It prints three things:

	  1. Everything in the chamber, with centre and reach
	  2. Where the road runs through it
	  3. A GRID of candidate positions, each scored by its clearance

	The grid is the point. Rather than reading a list and doing the arithmetic by
	hand — which is how a tower ended up 14 studs inside another tower — it tests
	positions and tells you which ones are actually free.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

--==========================================================================
local CHAMBER = 9 -- which chamber to survey
local WANT_RADIUS = 34 -- the footprint you are trying to fit (EndTower: 34)

-- These match BuildBattleground / BuildChambers.
local GROUND = 2
local HALF_W = 150
local INNER = 122
local Z_START = 20
local CHAMBER_D = 200
local CHAMBERS = 9
local PASSAGE_X = 115

--==========================================================================
local function line(s: string)
	print(s)
end

local gameplay = workspace:FindFirstChild("Gameplay")
local battleground = gameplay and gameplay:FindFirstChild("Battleground")
if not battleground then
	warn("[Survey] no Gameplay.Battleground — nothing to survey.")
	return
end

local zNear = Z_START - (CHAMBER - 1) * CHAMBER_D
local zFar = zNear - CHAMBER_D

line("")
line("=================== END ZONE SURVEY — CHAMBER " .. CHAMBER .. " ===================")
line(("Chamber spans z %d .. %d, x %d .. %d (usable to +/-%d)"):format(zNear, zFar, -HALF_W, HALF_W, INNER))
line(("Fitting something of radius %d."):format(WANT_RADIUS))

--==========================================================================
-- 1. THE ROAD
--==========================================================================
--[[
	Rebuilt from the same rule BuildChambers uses, rather than measured off the
	flagstones: the flagstones are scattered and one in eight is missing, so
	measuring them gives a fuzzy answer to a question with an exact one.
]]
local waypoints: { Vector3 } = {}
do
	table.insert(waypoints, Vector3.new(0, GROUND, Z_START - 40))
	for i = 1, CHAMBERS - 1 do
		local n = Z_START - (i - 1) * CHAMBER_D
		local f = n - CHAMBER_D
		local x = if i % 2 == 1 then PASSAGE_X else -PASSAGE_X
		table.insert(waypoints, Vector3.new(x * 0.35, GROUND, n - CHAMBER_D * 0.35))
		table.insert(waypoints, Vector3.new(x, GROUND, f + 34))
		table.insert(waypoints, Vector3.new(x, GROUND, f - 12))
	end
	table.insert(waypoints, Vector3.new(0, GROUND, Z_START - CHAMBERS * CHAMBER_D + 90))
	table.insert(waypoints, Vector3.new(0, GROUND, Z_START - CHAMBERS * CHAMBER_D + 30))
end

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

line("")
line("--- THE ROAD THROUGH THIS CHAMBER -------------------------------")
for i = 1, #waypoints do
	local w = waypoints[i]
	if w.Z <= zNear + 20 and w.Z >= zFar - 20 then
		line(("  waypoint  x %+5d   z %6d"):format(w.X, w.Z))
	end
end

--==========================================================================
-- 2. WHAT IS ALREADY STANDING HERE
--==========================================================================
local obstacles: { { name: string, x: number, z: number, reach: number } } = {}

--[[
	How wide something is WHERE IT MATTERS.

	A tower's bounding box is not its footprint. It includes the rubble cone
	spalled off the foot and the merlons that fell around it, which spread more
	than twice as far as the shaft: SideTowerW boxes at 88 and is 22. A grid
	scored on the box says the whole chamber is full.

	So anything above `RUBBLE_LINE` is measured on its own, because above the
	rubble only the standing structure is left. Falls back to the full extent
	when there is nothing up there — a low ruin genuinely is what its box says.
]]
local RUBBLE_LINE = 30

--[[
	How far a part reaches in WORLD x and z.

	`Size` is in the part's OWN axes, not the world's — so reading `Size.X` as a
	world-X extent is wrong for anything rotated, and the castle is built almost
	entirely out of rotated pieces. A cylinder's Size.X is its LENGTH along its
	own axis; a roof rafter leaning in to a tower's apex was counted as half its
	length in world X, which made SideTowerW measure a shaft radius of 67 when it
	is about 22.

	Projecting the oriented box onto each world axis is the fix.
]]
local function worldSpan(part: BasePart): (number, number, number, number)
	local cf, s = part.CFrame, part.Size
	local right, up, look = cf.RightVector, cf.UpVector, cf.LookVector
	local hx = math.abs(right.X) * s.X / 2 + math.abs(up.X) * s.Y / 2 + math.abs(look.X) * s.Z / 2
	local hz = math.abs(right.Z) * s.X / 2 + math.abs(up.Z) * s.Y / 2 + math.abs(look.Z) * s.Z / 2
	local p = part.Position
	return p.X - hx, p.X + hx, p.Z - hz, p.Z + hz
end

local function extentsAbove(node: Instance, minY: number)
	local minX, maxX, minZ, maxZ
	for _, part in ipairs(node:GetDescendants()) do
		if part:IsA("BasePart") and part.Position.Y >= minY then
			local lo, hi, zlo, zhi = worldSpan(part)
			minX = if minX then math.min(minX, lo) else lo
			maxX = if maxX then math.max(maxX, hi) else hi
			minZ = if minZ then math.min(minZ, zlo) else zlo
			maxZ = if maxZ then math.max(maxZ, zhi) else zhi
		end
	end
	if not minX then
		return nil
	end
	return (minX + maxX) / 2, (minZ + maxZ) / 2, math.max(maxX - minX, maxZ - minZ) / 2
end

local function record(node: Instance, label: string)
	local cx, cz, reach = extentsAbove(node, RUBBLE_LINE)
	if not cx then
		cx, cz, reach = extentsAbove(node, -math.huge)
	end
	if not cx or not cz or not reach then
		return
	end
	if cz > zNear + 30 or cz < zFar - 30 then
		return
	end
	table.insert(obstacles, { name = label, x = cx, z = cz, reach = reach })
end

local chamber = battleground:FindFirstChild(("Chamber%d"):format(CHAMBER))
local structure = chamber and chamber:FindFirstChild("Structure")

line("")
line("--- STRUCTURE ---------------------------------------------------")
line("  name                        centre x      z    reach")
if structure then
	for _, node in ipairs(structure:GetChildren()) do
		record(node, node.Name)
	end
end
for _, o in ipairs(obstacles) do
	--[[
		Curtain walls are flagged, not trusted. A wall is a long flat slab, so
		its bounding box reaches across the entire chamber and would reject every
		position in it — but it is still worth SEEING, because it is what defines
		the edges.
	]]
	local note = ""
	if o.reach > 90 then
		note = "   <- a wall or a span; its box is not a real footprint"
	end
	line(("  %-26s %+7d %+7d %7d%s"):format(o.name, o.x, o.z, o.reach, note))
end
if #obstacles == 0 then
	line("  (nothing found — is the chamber built?)")
end

-- Decorations, summarised rather than listed: there are hundreds.
local decorations = battleground:FindFirstChild("Decorations")
local area = decorations and decorations:FindFirstChild(("Area%d"):format(CHAMBER))
if area then
	line("")
	line(("--- DECORATIONS in Area%d: %d objects ---------------------------"):format(CHAMBER, #area:GetChildren()))
	line("  (these are cleared automatically by BuildEndTower, not an obstacle)")
end

-- And anything already built here by another tool. EndTower is a FOLDER, not a
-- Model — GetBoundingBox does not exist on it, which is what crashed this
-- report the first time it ran against a built tower.
local endTower = battleground:FindFirstChild("EndTower")
if endTower then
	local cx, cz, reach = extentsAbove(endTower, -math.huge)
	line("")
	if cx then
		line(("--- EXISTING EndTower at %d, %d, reaching %d --------------"):format(cx, cz, reach))
	else
		line("--- EXISTING EndTower (empty) ------------------------------")
	end
	line("  (it will be replaced, so it is not counted against you below)")
end

--==========================================================================
-- 3. WHERE THERE IS ROOM
--==========================================================================
--[[
	The useful part. Walks a grid across the chamber and scores each point by its
	worst clearance — to the road, to the round towers, and to the walls.

	Only towers are counted as blocking. Everything with a reach above 90 is a
	wall or a span, and its bounding box is not a footprint.
]]
line("")
line("--- CLEARANCE GRID ----------------------------------------------")
line(("  Each cell: clearance in studs. Needs %d. A dot is too tight."):format(WANT_RADIUS))
line("")

local function clearanceAt(x: number, z: number): number
	local best = math.huge

	-- The road.
	best = math.min(best, distanceToPath(x, z))

	-- Round towers.
	for _, o in ipairs(obstacles) do
		if o.reach <= 90 and o.name:find("Tower") then
			local gap = Vector2.new(x - o.x, z - o.z).Magnitude - o.reach
			best = math.min(best, gap)
		end
	end

	-- The side walls, and the chamber ends.
	best = math.min(best, INNER - math.abs(x))
	best = math.min(best, math.abs(z - zNear), math.abs(z - zFar))

	return best
end

local best = { x = 0, z = 0, score = -1 }
local header = "        "
for x = -110, 110, 20 do
	header ..= ("%+6d"):format(x)
end
line(header)

for z = zNear - 20, zFar + 20, -20 do
	local row = ("  %6d"):format(z)
	for x = -110, 110, 20 do
		local c = clearanceAt(x, z)
		if c >= WANT_RADIUS then
			row ..= ("%6d"):format(math.floor(c))
			if c > best.score then
				best = { x = x, z = z, score = c }
			end
		else
			row ..= "     ."
		end
	end
	line(row)
end

line("")
if best.score > 0 then
	line(("  ROOMIEST SPOT: x %d, z %d — %d studs of clearance."):format(best.x, best.z, math.floor(best.score)))
	line(("  In BuildEndTower:   local TOWER_X = %d      local TOWER_Z = %d"):format(best.x, best.z))
else
	line(("  NOTHING in this chamber fits a radius of %d."):format(WANT_RADIUS))
	line("  Lower WANT_RADIUS, or move something.")
end

line("")
line("=========================== END ================================")
