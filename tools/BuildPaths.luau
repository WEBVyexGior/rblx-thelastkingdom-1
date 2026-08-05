--[[
	BuildPaths — run in the Studio Command Bar of the FORGOTTEN LANDS place,
	in EDIT MODE. Select all, copy, paste, Enter.

	It rebuilds ONE folder: `Battleground.Path`. Nothing else in the map is
	touched, moved or deleted — not a wall, not a house, not the Horse Stable,
	not a single thing placed by hand. (It does nudge the enemy spawn markers,
	which is explained where it does it.)

	--------------------------------------------------------------------------
	THE PROBLEM IT SOLVES

	Every chamber played out in under five minutes because the road was a
	straight diagonal across an empty room: you could see the far gate from the
	near one and walk at it. The survey says each chamber is already about half
	full of buildings — so the room is not empty, the ROUTE was.

	--------------------------------------------------------------------------
	SO THE BUILDINGS BECOME THE MAZE

	This does not lay a road and then ask the buildings to move. It reads what
	is standing, builds an occupancy grid out of it, and threads the road
	through the gaps with A*. The zigzag is not random noise — it is the shape
	of the town that is already there, which is why it will look deliberate
	rather than generated.

	Then it fences the road, but only where the road runs through OPEN ground.
	Where a house already stands beside it, the house is the wall. Fewer parts,
	and it reads as a street rather than as railings dropped on a field.

	  - main road 9 wide, worn flagstones, same look as before, smaller stones
	  - one BRANCH per chamber that leaves and rejoins, in dirt rather than
	    stone, so it reads as the unofficial way round
	  - fences 5 studs tall with an invisible barrier to y=26 over them, so
	    jumping does not get you into the gaps between houses
	  - the enemy spawn markers moved onto the road

	Re-run it as often as you like. It is deterministic per SEED; change the
	seed for a different town.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

--==========================================================================
local SEED = 40711

-- The castle, from tools/BuildBattleground.
local Z_START = 20
local CHAMBER_D = 200
local CHAMBERS = 9
local HALF_W = 150
local GAP_W = 46
local GAP_INSET = 12
local GROUND = 2

-- The end tower, from tools/BuildEndTower — where chamber 9's road finishes,
-- because the ninth room's way out is a door and not another arch.
local TOWER = Vector3.new(-80, GROUND, -1720)

--==========================================================================
-- The road
--==========================================================================
local CELL = 8 -- occupancy grid resolution
local MAIN_W = 9 -- was 13, and it was too generous to feel like a street
local BRANCH_W = 6.5

--[[
	How far from anything solid the road must stay.

	Half the road plus a margin. Without it A* will happily thread a
	nine-stud road through a seven-stud gap, because to a grid of cells the
	centre line fits perfectly and the edges are somebody else's problem.
]]
local CLEARANCE = MAIN_W / 2 + 4

local STONE_EVERY = 7 -- studs between courses of flagstones
local LANES = 4

--==========================================================================
-- The fences
--==========================================================================
local FENCE_H = 5
local BARRIER_TOP = 26 -- no jumping over, no standing on
local FENCE_OFFSET = MAIN_W / 2 + 2.5
local FENCE_SEGMENT = 10

-- Where the fence is allowed to stop: a gap every so often so the road is a
-- street and not a corridor, and so the dead can join it.
local OPENING_EVERY = 6

--==========================================================================
local C = {
	flag = Color3.fromRGB(92, 88, 82),
	flagWorn = Color3.fromRGB(104, 99, 91),
	soil = Color3.fromRGB(62, 51, 40),
	sand = Color3.fromRGB(104, 92, 70),
	stonePale = Color3.fromRGB(112, 108, 100),
	wood = Color3.fromRGB(66, 49, 34),
	woodPale = Color3.fromRGB(92, 72, 50),
	woodGrey = Color3.fromRGB(86, 79, 68),
}

local M = {
	cobble = Enum.Material.Cobblestone,
	stone = Enum.Material.Slate,
	ground = Enum.Material.Ground,
	sand = Enum.Material.Sand,
	log = Enum.Material.Wood,
	plank = Enum.Material.WoodPlanks,
}

local rng = Random.new(SEED)

local function jitter(a: number): number
	return rng:NextNumber(-a, a)
end

local function chance(p: number): boolean
	return rng:NextNumber() < p
end

--==========================================================================
local gameplay = workspace:FindFirstChild("Gameplay")
local battleground = gameplay and gameplay:FindFirstChild("Battleground")
if not battleground then
	warn("[Paths] no Gameplay.Battleground — build the battleground first.")
	return
end

--[[
	The old road goes FIRST, before anything is measured. It is the one thing
	being replaced, and leaving it in would have every cell it occupies read as
	blocked — the new road would then carefully route around the old one.
]]
for _, child in ipairs(battleground:GetChildren()) do
	if child.Name == "Path" then
		child:Destroy()
	end
end

local pathRoot = Instance.new("Folder")
pathRoot.Name = "Path"
pathRoot.Parent = battleground

local made = 0

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
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

--==========================================================================
-- WHAT IS STANDING
--==========================================================================

-- Part.Size is along the PART's own axes; a rotated part's world extent is the
-- sum of what each local axis contributes.
local function span(p: BasePart): (Vector3, Vector3)
	local cf, s = p.CFrame, p.Size
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local h = Vector3.new(
		math.abs(r.X) * s.X / 2 + math.abs(u.X) * s.Y / 2 + math.abs(l.X) * s.Z / 2,
		math.abs(r.Y) * s.X / 2 + math.abs(u.Y) * s.Y / 2 + math.abs(l.Y) * s.Z / 2,
		math.abs(r.Z) * s.X / 2 + math.abs(u.Z) * s.Y / 2 + math.abs(l.Z) * s.Z / 2
	)
	return p.Position - h, p.Position + h
end

--[[
	Everything solid, gathered ONCE for the whole castle.

	Nine sweeps of thirty thousand instances is thirty seconds of frozen
	Studio. One sweep, then nine cheap filters over an array.

	CanCollide is the test, deliberately: the hidden gameplay markers, the
	grass, the loose straw and every decorative wisp in the map are all
	non-colliding, and a road that refuses to run past a tuft of grass is
	not a road.
]]
local solids: { { min: Vector3, max: Vector3 } } = {}
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("BasePart") and d.CanCollide and not d:IsDescendantOf(pathRoot) then
		local a, b = span(d)
		-- Ignore the ground itself and anything buried: a flagstone or a floor
		-- slab is not an obstacle, a wall is.
		if b.Y > GROUND + 2.5 then
			table.insert(solids, { min = a, max = b })
		end
	end
end

--==========================================================================
-- THE GRID
--==========================================================================
type Grid = {
	blocked: { { boolean } },
	cols: number,
	rows: number,
	x0: number,
	z0: number,
}

local function gridFor(zNear: number, zFar: number): Grid
	local x0 = -HALF_W + CELL
	local z0 = zFar + CELL
	local cols = math.floor((HALF_W * 2 - CELL * 2) / CELL)
	local rows = math.floor((zNear - zFar - CELL * 2) / CELL)

	local blocked: { { boolean } } = {}
	for c = 1, cols do
		local column: { boolean } = {}
		for r = 1, rows do
			column[r] = false
		end
		blocked[c] = column
	end

	--[[
		Mark every cell an obstacle touches, INFLATED by the clearance. The
		inflation is why the road never scrapes a wall: the grid already knows
		a nine-stud road cannot use a cell four studs from a house.
	]]
	for _, s in ipairs(solids) do
		if s.max.Z >= zFar and s.min.Z <= zNear then
			local cMin = math.floor((s.min.X - CLEARANCE - x0) / CELL) + 1
			local cMax = math.ceil((s.max.X + CLEARANCE - x0) / CELL) + 1
			local rMin = math.floor((s.min.Z - CLEARANCE - z0) / CELL) + 1
			local rMax = math.ceil((s.max.Z + CLEARANCE - z0) / CELL) + 1

			for c = math.max(cMin, 1), math.min(cMax, cols) do
				for r = math.max(rMin, 1), math.min(rMax, rows) do
					blocked[c][r] = true
				end
			end
		end
	end

	return { blocked = blocked, cols = cols, rows = rows, x0 = x0, z0 = z0 }
end

local function toCell(grid: Grid, x: number, z: number): (number, number)
	return math.floor((x - grid.x0) / CELL) + 1, math.floor((z - grid.z0) / CELL) + 1
end

local function toWorld(grid: Grid, c: number, r: number): Vector3
	return Vector3.new(grid.x0 + (c - 0.5) * CELL, GROUND, grid.z0 + (r - 0.5) * CELL)
end

local function inside(grid: Grid, c: number, r: number): boolean
	return c >= 1 and c <= grid.cols and r >= 1 and r <= grid.rows
end

--[[
	Forces a disc of cells free.

	The entry and the exit are archways: their cells are full of gate, wall and
	voussoir, and the honest grid says the road may not start or finish. This
	says it may.
]]
local function carve(grid: Grid, at: Vector3, radius: number)
	local c0, r0 = toCell(grid, at.X, at.Z)
	local cells = math.ceil(radius / CELL)
	for c = c0 - cells, c0 + cells do
		for r = r0 - cells, r0 + cells do
			if inside(grid, c, r) then
				grid.blocked[c][r] = false
			end
		end
	end
end

--==========================================================================
-- A*
--==========================================================================
local NEIGHBOURS = {
	{ 1, 0, 1 },
	{ -1, 0, 1 },
	{ 0, 1, 1 },
	{ 0, -1, 1 },
	{ 1, 1, 1.41 },
	{ 1, -1, 1.41 },
	{ -1, 1, 1.41 },
	{ -1, -1, 1.41 },
}

--[[
	A binary min-heap, because the obvious version of this is too slow to ship.

	The first draft kept the open set as a plain array and scanned it for the
	cheapest cell on every pop. The grid is 35 x 23, so the open set reaches a
	couple of thousand entries and gets popped a couple of thousand times —
	millions of comparisons per leg, four legs a chamber, nine chambers and the
	branches on top. That is not a millisecond nobody is waiting for; that is
	Studio locked up long enough to look like a crash.

	Push and pop are both log n here, and the whole castle routes in a blink.
]]
local Heap = {}
Heap.__index = Heap

local function newHeap()
	return setmetatable({ items = {}, n = 0 }, Heap)
end

function Heap.push(self, item)
	self.n += 1
	self.items[self.n] = item
	local i = self.n
	while i > 1 do
		local parent = i // 2
		if self.items[parent].f <= self.items[i].f then
			break
		end
		self.items[parent], self.items[i] = self.items[i], self.items[parent]
		i = parent
	end
end

function Heap.pop(self)
	if self.n == 0 then
		return nil
	end
	local top = self.items[1]
	self.items[1] = self.items[self.n]
	self.items[self.n] = nil
	self.n -= 1

	local i = 1
	while true do
		local left, right = i * 2, i * 2 + 1
		local smallest = i
		if left <= self.n and self.items[left].f < self.items[smallest].f then
			smallest = left
		end
		if right <= self.n and self.items[right].f < self.items[smallest].f then
			smallest = right
		end
		if smallest == i then
			break
		end
		self.items[smallest], self.items[i] = self.items[i], self.items[smallest]
		i = smallest
	end
	return top
end

--[[
	Shortest walkable run of cells from one point to another.
]]
local function route(grid: Grid, from: Vector3, to: Vector3): { Vector3 }?
	local sc, sr = toCell(grid, from.X, from.Z)
	local gc, gr = toCell(grid, to.X, to.Z)
	if not inside(grid, sc, sr) or not inside(grid, gc, gr) then
		return nil
	end

	local function key(c: number, r: number): number
		return c * 10000 + r
	end

	local gScore: { [number]: number } = { [key(sc, sr)] = 0 }
	local came: { [number]: { number } } = {}
	local closed: { [number]: boolean } = {}

	local open = newHeap()
	open:push({ c = sc, r = sr, f = 0 })

	while true do
		local best = open:pop()
		if not best then
			break
		end

		local k = key(best.c, best.r)
		if not closed[k] then
			closed[k] = true

			if best.c == gc and best.r == gr then
				local out: { Vector3 } = {}
				local c, r = gc, gr
				while true do
					table.insert(out, 1, toWorld(grid, c, r))
					local prev = came[key(c, r)]
					if not prev then
						break
					end
					c, r = prev[1], prev[2]
				end
				return out
			end

			for _, n in ipairs(NEIGHBOURS) do
				local nc, nr = best.c + n[1], best.r + n[2]
				if inside(grid, nc, nr) and not grid.blocked[nc][nr] then
					local nk = key(nc, nr)
					-- Already settled: its cost cannot improve, and pushing it
					-- again is the other half of what made the first draft slow.
					if not closed[nk] then
						local tentative = gScore[k] + n[3]
						if gScore[nk] == nil or tentative < gScore[nk] then
							gScore[nk] = tentative
							came[nk] = { best.c, best.r }
							local h = math.abs(nc - gc) + math.abs(nr - gr)
							open:push({ c = nc, r = nr, f = tentative + h })
						end
					end
				end
			end
		end
	end

	return nil
end

--[[
	Thins a cell-by-cell run down to the corners.

	A* returns one point every eight studs, most of them in a straight line.
	Laying stones along that is fine and fencing along it is not — a fence post
	every eight studs round a curve that is not there. So: keep a point only
	where the direction actually changes.
]]
local function simplify(points: { Vector3 }): { Vector3 }
	if #points < 3 then
		return points
	end
	local out = { points[1] }
	local lastDir = (points[2] - points[1]).Unit
	for i = 2, #points - 1 do
		local dir = (points[i + 1] - points[i]).Unit
		if dir:Dot(lastDir) < 0.985 then
			table.insert(out, points[i])
			lastDir = dir
		end
	end
	table.insert(out, points[#points])
	return out
end

--==========================================================================
-- LAYING IT
--==========================================================================
local function isFree(grid: Grid, at: Vector3): boolean
	local c, r = toCell(grid, at.X, at.Z)
	return inside(grid, c, r) and not grid.blocked[c][r]
end

local function layRoad(parent: Instance, points: { Vector3 }, width: number, dirt: boolean)
	local stones = folder(parent, if dirt then "Dirt" else "Flagstones")

	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local delta = b - a
		local length = delta.Magnitude
		if length > 0.1 then
			local dir = delta.Unit
			local right = Vector3.new(-dir.Z, 0, dir.X)
			local yaw = math.atan2(dir.X, dir.Z)
			local steps = math.max(1, math.floor(length / STONE_EVERY))

			for s = 0, steps - 1 do
				local at = a + dir * (length * ((s + 0.5) / steps))
				for lane = 0, LANES - 1 do
					local across = (lane - (LANES - 1) / 2) * (width / LANES)
					local centre = at + right * across + Vector3.new(jitter(0.5), 0, jitter(0.5))

					if dirt then
						--[[
							The branch is beaten earth, not stone. It reads as
							the way people started going rather than the way
							the castle built — which is what a shortcut is.
						]]
						block(
							stones,
							"Dirt",
							Vector3.new(width / LANES * rng:NextNumber(1, 1.25), 0.4, STONE_EVERY * 1.2),
							CFrame.new(centre + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, yaw + math.rad(jitter(8)), 0),
							if chance(0.4) then C.sand else C.soil,
							if chance(0.5) then M.sand else M.ground
						)
					elseif not chance(0.14) then
						-- One stone in seven missing, so soil shows through. A
						-- perfectly paved road in a forty-year ruin is the most
						-- obvious tell there is.
						block(
							stones,
							"Flagstone",
							Vector3.new(
								width / LANES * rng:NextNumber(0.8, 1.05),
								0.7,
								STONE_EVERY * rng:NextNumber(0.75, 1)
							),
							CFrame.new(centre + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, yaw + math.rad(jitter(6)), 0),
							if chance(0.3) then C.flagWorn else C.flag,
							M.cobble
						)
					else
						block(
							stones,
							"BareEarth",
							Vector3.new(width / LANES, 0.35, STONE_EVERY),
							CFrame.new(centre + Vector3.new(0, 0.18, 0)) * CFrame.Angles(0, yaw, 0),
							C.soil,
							M.ground
						)
					end
				end
			end
		end
	end
end

--==========================================================================
--[[
	Fences the road — but only where it needs fencing.

	Where a building already stands beside the road, the building IS the wall,
	and a railing in front of it is parts spent on nothing. So each segment
	asks the grid whether the ground just off the verge is open, and only
	fences the open side.

	Every OPENING_EVERY-th segment is left out on both sides. Without gaps the
	road is a corridor, the town behind it is unreachable, and the dead spawn
	into sealed pockets they can never leave.
]]
local function layFence(parent: Instance, grid: Grid, points: { Vector3 }, width: number)
	local posts = folder(parent, "Fences")
	local barriers = folder(parent, "Barriers")
	local segment = 0

	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local delta = b - a
		local length = delta.Magnitude
		if length < 1 then
			continue
		end
		local dir = delta.Unit
		local right = Vector3.new(-dir.Z, 0, dir.X)
		local yaw = math.atan2(dir.X, dir.Z)
		local runs = math.max(1, math.floor(length / FENCE_SEGMENT))

		for s = 0, runs - 1 do
			segment += 1
			local at = a + dir * (length * ((s + 0.5) / runs))
			local runLength = length / runs

			if segment % OPENING_EVERY == 0 then
				continue -- a way off the road
			end

			for _, side in { -1, 1 } do
				local line = at + right * (side * (width / 2 + 2.5))

				-- Is there open ground behind this verge to fence off? If the
				-- next thing along is already a house, leave it alone.
				local behind = at + right * (side * (width / 2 + 12))
				if not isFree(grid, behind) then
					continue
				end

				local posY = GROUND + FENCE_H / 2
				block(
					posts,
					"Post",
					Vector3.new(1.1, FENCE_H + 1, 1.1),
					CFrame.new(line - dir * (runLength / 2) + Vector3.new(0, posY, 0))
						* CFrame.Angles(0, yaw, math.rad(jitter(3))),
					C.wood,
					M.log
				)

				-- Three rails, the middle one a shade lighter, one in six gone.
				for rail = 1, 3 do
					if not chance(0.16) then
						local y = GROUND + 1.4 + (rail - 1) * 1.6
						block(
							posts,
							"Rail",
							Vector3.new(0.5, 0.75, runLength * rng:NextNumber(0.94, 1)),
							CFrame.new(line + Vector3.new(0, y, 0)) * CFrame.Angles(0, yaw, math.rad(jitter(2))),
							if rail == 2 then C.woodPale else C.woodGrey,
							M.plank
						)
					end
				end

				--[[
					And the thing that actually stops you.

					The fence is five studs and a Roblox character jumps seven,
					so without this the whole system is decoration. It reaches
					to 26 because that is above anything a player can stack,
					stand on or climb in this map.
				]]
				local barrier = block(
					barriers,
					"NoEntry",
					Vector3.new(1.6, BARRIER_TOP, runLength),
					CFrame.new(line + Vector3.new(0, BARRIER_TOP / 2, 0)) * CFrame.Angles(0, yaw, 0),
					C.wood,
					M.log
				)
				barrier.Transparency = 1
				barrier.CanQuery = true -- the pathfinder must see it too
				barrier.CastShadow = false
			end
		end
	end
end

--==========================================================================
-- WHERE EACH CHAMBER'S ROAD STARTS AND ENDS
--==========================================================================
local function gapX(index: number): number
	local x = HALF_W - GAP_W / 2 - GAP_INSET
	return if index % 2 == 1 then x else -x
end

local function entryOf(index: number, zNear: number): Vector3
	if index == 1 then
		-- The gatehouse, a little way inside it.
		return Vector3.new(0, GROUND, zNear - 30)
	end
	return Vector3.new(gapX(index - 1), GROUND, zNear - 14)
end

local function exitOf(index: number, zFar: number): Vector3
	if index == CHAMBERS then
		return TOWER
	end
	return Vector3.new(gapX(index), GROUND, zFar + 14)
end

--[[
	Three points to bend the road around, between the entry and the exit.

	This is what makes it a serpentine rather than a diagonal. The chamber is
	cut into bands across its depth and one free cell is taken from each,
	alternating sides — so the road is forced to cross the room, come back, and
	cross again, and every crossing is a stretch of open ground with buildings
	either side.

	Free cells only: a bend point inside a house is a leg A* cannot walk.
]]
local function bends(grid: Grid, entry: Vector3, exitAt: Vector3): { Vector3 }
	local out: { Vector3 } = {}
	local bandCount = 3
	local startSide = if entry.X > 0 then -1 else 1

	for band = 1, bandCount do
		local t = band / (bandCount + 1)
		local z = entry.Z + (exitAt.Z - entry.Z) * t
		local side = startSide * (if band % 2 == 1 then 1 else -1)

		-- Walk in from the wall on this side until a free cell turns up.
		local found: Vector3? = nil
		for step = 0, 12 do
			local x = side * (HALF_W - 26 - step * 9)
			local candidate = Vector3.new(x, GROUND, z + jitter(10))
			if isFree(grid, candidate) then
				found = candidate
				break
			end
		end

		if found then
			table.insert(out, found)
		end
	end

	return out
end

--==========================================================================
-- BUILD
--==========================================================================
print("")
print("========================= BUILD PATHS ========================")
print(("  %d solid parts standing in the castle"):format(#solids))
print("")

local roadsByChamber: { [number]: { Vector3 } } = {}

for index = 1, CHAMBERS do
	local zNear = Z_START - (index - 1) * CHAMBER_D
	local zFar = zNear - CHAMBER_D
	local node = folder(pathRoot, ("Area%d"):format(index))

	local grid = gridFor(zNear, zFar)
	local entry = entryOf(index, zNear)
	local exitAt = exitOf(index, zFar)

	-- The arch is full of arch. Let the road start and finish in it anyway.
	carve(grid, entry, 16)
	carve(grid, exitAt, 16)

	--------------------------------------------------------------------------
	-- The main road: entry -> bend -> bend -> bend -> exit
	--------------------------------------------------------------------------
	local stops = { entry }
	for _, bend in ipairs(bends(grid, entry, exitAt)) do
		table.insert(stops, bend)
	end
	table.insert(stops, exitAt)

	local full: { Vector3 } = {}
	local failed = 0
	for i = 1, #stops - 1 do
		local leg = route(grid, stops[i], stops[i + 1])
		if leg then
			for j, p in ipairs(leg) do
				-- Skip the first point of every leg after the first: it is the
				-- previous leg's last point, and a doubled point makes a
				-- zero-length segment that the fence maths divides by.
				if not (i > 1 and j == 1) then
					table.insert(full, p)
				end
			end
		else
			failed += 1
			table.insert(full, stops[i + 1])
		end
	end

	local road = simplify(full)
	roadsByChamber[index] = road

	local walked = 0
	for i = 1, #road - 1 do
		walked += (road[i + 1] - road[i]).Magnitude
	end

	layRoad(node, road, MAIN_W, false)
	layFence(node, grid, road, MAIN_W)

	--------------------------------------------------------------------------
	-- The branch: leaves a third of the way along, rejoins two thirds along,
	-- by way of the other side of the room.
	--------------------------------------------------------------------------
	local branchLength = 0
	if #road >= 6 then
		local from = road[math.floor(#road * 0.3)]
		local to = road[math.floor(#road * 0.7)]

		-- A detour point on the far side from wherever the main road is here.
		local side = if (from.X + to.X) / 2 > 0 then -1 else 1
		local via: Vector3? = nil
		for step = 0, 12 do
			local candidate = Vector3.new(side * (HALF_W - 30 - step * 9), GROUND, (from.Z + to.Z) / 2)
			if isFree(grid, candidate) then
				via = candidate
				break
			end
		end

		if via then
			local legA = route(grid, from, via)
			local legB = route(grid, via, to)
			if legA and legB then
				local branch: { Vector3 } = {}
				for _, p in ipairs(legA) do
					table.insert(branch, p)
				end
				for j, p in ipairs(legB) do
					if j > 1 then
						table.insert(branch, p)
					end
				end
				branch = simplify(branch)
				for i = 1, #branch - 1 do
					branchLength += (branch[i + 1] - branch[i]).Magnitude
				end
				layRoad(node, branch, BRANCH_W, true)
			end
		end
	end

	--------------------------------------------------------------------------
	--[[
		The spawn markers move ONTO the road.

		Once the verges are fenced, a spawn point out in the town is a sealed
		pocket: the dead spawn behind a fence they cannot cross and stand there
		for the run. On the road they come AT you, from ahead and from behind,
		which is both the fix and the better fiction.

		The markers are moved, never replaced — configs point at them by name
		and level design drags them by hand.
	]]
	--------------------------------------------------------------------------
	local chamber = battleground:FindFirstChild(("Chamber%d"):format(index))
	local spawns = chamber and chamber:FindFirstChild("Spawns")
	if spawns and #road >= 4 then
		local places = {
			North = road[#road - 1],
			East = road[math.max(2, math.floor(#road * 0.55))],
			West = road[math.max(2, math.floor(#road * 0.25))],
		}
		for name, at in pairs(places) do
			local marker = spawns:FindFirstChild(name)
			if marker and marker:IsA("BasePart") then
				marker.Position = Vector3.new(at.X, GROUND + 3, at.Z)
			end
		end
	end

	--------------------------------------------------------------------------
	print(("  Area %d   %d bends   %.0f studs of road   %.0f of branch%s"):format(
		index,
		#road,
		walked,
		branchLength,
		if failed > 0 then ("   (%d leg(s) had no route)"):format(failed) else ""
	))
end

--==========================================================================
print("")
print(("  %d parts, in Battleground.Path.Area1..9"):format(made))
print("")
print("  Roads run through the gaps between what is already standing, so")
print("  nothing was deleted, nothing moved, and the zigzag is the shape of")
print("  the town rather than random noise.")
print("")
print("  Fences only where the verge is open ground — where a house is")
print("  already there, the house is the wall. Every 6th segment is a gap.")
print("")
print("  Enemy spawn markers were moved ONTO the road. They will come at you")
print("  along it now, from ahead and from behind.")
print("")
print(("  Deterministic per SEED (currently %d). Change it for a new town."):format(SEED))
print("=========================== END ==============================")
