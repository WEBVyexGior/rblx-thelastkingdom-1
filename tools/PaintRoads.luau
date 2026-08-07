--[[
	PaintRoads — run in the Studio Command Bar of the FORGOTTEN LANDS place,
	in EDIT MODE. Select all, copy, paste, Enter.

	--------------------------------------------------------------------------
	THE ROAD IS TERRAIN NOW, NOT PARTS

	Two attempts at a parts road failed, and the reason was never the routing —
	it was that a road made of two thousand flagstones is brittle. It has to
	avoid every wall exactly, it cannot be nudged by hand afterwards, undo
	destroys it, and when the route is wrong you are left with stones inside a
	house.

	Sand painted into the terrain has none of those problems. It costs zero
	parts, it is edited with the terrain brush like anything else, sand under a
	corner of a building is invisible rather than broken, and moving it later is
	a designer's job rather than a rebuild.

	--------------------------------------------------------------------------
	THE SHAPE IS AUTHORED, NOT RANDOM

	The last version picked free cells and called it a design. This one has a
	written route: in from the gate, across the room, down, back across, down,
	across again, and out. A snail. Three full crossings where the old road was
	one diagonal, so the walk is about three times as long in the same room and
	the far gate is visible for most of it without being reachable.

	Every leg is then CHECKED against what is actually standing, and shifted
	along z until it is clear, up to a limit. Whatever cannot be cleared is
	named in the output rather than quietly painted through a wall.

	--------------------------------------------------------------------------
	FENCES

	If there is a model with "fence" in its name anywhere in the Workspace, it
	is used as the template and cloned along the verges. Otherwise a plain rail
	fence is built. Either way an invisible barrier goes over the top of it, to
	26 studs, because a five-stud fence and a seven-stud jump is decoration.

	Fences go only where the verge is open ground: where a house is already
	beside the road, the house is the wall.

	RUN IT AS OFTEN AS YOU LIKE. It repaints the same strips and rebuilds the
	same folder. Do NOT press Ctrl+Z afterwards — undo cannot restore terrain
	it did not paint.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

--==========================================================================
local ROAD_W = 16 -- how wide the sand strip is
local ROAD_DEPTH = 3 -- how deep into the terrain it is painted
local FENCE_H = 5
local BARRIER_TOP = 26
local FENCE_STEP = 12 -- studs between fence posts
local VERGE = ROAD_W / 2 + 3 -- where the fence line sits from the centre

-- How far a leg may be shifted along z to get it clear of a building.
local NUDGE_MAX = 34
local NUDGE_STEP = 6

-- Anything shorter than this is walked over, not around: fallen doors, rubble,
-- kerbs, crates. Only real buildings push the road aside.
local TALL = 6

--==========================================================================
local Z_START = 20
local CHAMBER_D = 200
local CHAMBERS = 9
local HALF_W = 150
local GAP_W = 46
local GAP_INSET = 12
local GROUND = 2

-- The lanes the snail runs up and down. Inside the side towers, which stand at
-- x +/-105 and reach in to about +/-106.
local LANE = 88

local TOWER = Vector3.new(-80, GROUND, -1720) -- chamber 9 ends at the tower

local Terrain = workspace.Terrain

--==========================================================================
local gameplay = workspace:FindFirstChild("Gameplay")
local battleground = gameplay and gameplay:FindFirstChild("Battleground")
if not battleground then
	warn("[Roads] no Gameplay.Battleground.")
	return
end

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
	Everything TALL, once.

	Height is the filter that the parts road never had. A fallen door, a crate
	and a kerb are all solid and all irrelevant — you walk over them. Only
	things you cannot see past should bend a road, and using height to say so
	is why this route will run past the rubble instead of around it.
]]
local walls: { { min: Vector3, max: Vector3, name: string } } = {}
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("BasePart") and d ~= Terrain and d.CanCollide then
		local lo, hi = span(d)
		if hi.Y - GROUND >= TALL then
			table.insert(walls, { min = lo, max = hi, name = d.Name })
		end
	end
end

--==========================================================================
-- The fence template, if one has been put in the map.
--==========================================================================
local fenceTemplate: Model? = nil
local fenceSize: Vector3? = nil
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Model") and string.find(string.lower(d.Name), "fence") then
		local ok, _, size = pcall(function()
			return d:GetBoundingBox()
		end)
		if ok then
			local _, s = d:GetBoundingBox()
			if s.X > 2 or s.Z > 2 then
				fenceTemplate = d
				fenceSize = s
				break
			end
		end
	end
end

--==========================================================================
local folderName = "RoadFences"
local old = battleground:FindFirstChild(folderName)
if old then
	old:Destroy()
end
local fenceRoot = Instance.new("Folder")
fenceRoot.Name = folderName
fenceRoot.Parent = battleground

local made = 0

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
-- IS THIS LINE CLEAR?
--==========================================================================
local function segmentBlocked(a: Vector3, b: Vector3): string?
	local delta = b - a
	local length = delta.Magnitude
	if length < 0.5 then
		return nil
	end
	local dir = delta.Unit
	local steps = math.ceil(length / 6)

	for s = 0, steps do
		local at = a + dir * (length * (s / steps))
		for _, w in ipairs(walls) do
			if
				at.X + ROAD_W / 2 > w.min.X
				and at.X - ROAD_W / 2 < w.max.X
				and at.Z + ROAD_W / 2 > w.min.Z
				and at.Z - ROAD_W / 2 < w.max.Z
			then
				return w.name
			end
		end
	end
	return nil
end

--[[
	Slides a crossing along z until it stops hitting a building.

	The SHAPE stays authored — it is still a crossing at roughly this depth —
	and only the exact depth moves. That is the difference between a design
	that adapts and a generator that wanders.
]]
local function clearCrossing(x1: number, x2: number, z: number): (number, string?)
	local blocker = segmentBlocked(Vector3.new(x1, GROUND, z), Vector3.new(x2, GROUND, z))
	if not blocker then
		return z, nil
	end
	for step = NUDGE_STEP, NUDGE_MAX, NUDGE_STEP do
		for _, dir in { -1, 1 } do
			local tryZ = z + dir * step
			if not segmentBlocked(Vector3.new(x1, GROUND, tryZ), Vector3.new(x2, GROUND, tryZ)) then
				return tryZ, nil
			end
		end
	end
	return z, blocker
end

--==========================================================================
-- PAINTING
--==========================================================================
local function paint(a: Vector3, b: Vector3)
	local delta = b - a
	local length = delta.Magnitude
	if length < 0.5 then
		return
	end
	local dir = delta.Unit
	local yaw = math.atan2(dir.X, dir.Z)
	local mid = a + delta / 2

	--[[
		One FillBlock for the whole leg rather than a hundred small ones. The
		block is rotated to the leg's own angle, so a diagonal reads as a
		diagonal and not as a staircase of squares.

		It is painted from below the surface up to just above it: the terrain
		sits at y = 0 and the road at y = 2, so a block spanning -3 to +1
		replaces the top of the ground without leaving a lip to trip on.
	]]
	Terrain:FillBlock(
		CFrame.new(mid.X, -1, mid.Z) * CFrame.Angles(0, yaw, 0),
		Vector3.new(ROAD_W, ROAD_DEPTH + 1, length + ROAD_W * 0.6),
		Enum.Material.Sand
	)
end

--==========================================================================
-- FENCING
--==========================================================================
local function verge(a: Vector3, b: Vector3)
	local delta = b - a
	local length = delta.Magnitude
	if length < FENCE_STEP then
		return
	end
	local dir = delta.Unit
	local right = Vector3.new(-dir.Z, 0, dir.X)
	local yaw = math.atan2(dir.X, dir.Z)
	local runs = math.floor(length / FENCE_STEP)

	for s = 0, runs - 1 do
		-- One gap in five, so the road is a street and not a corridor, and so
		-- the dead can step onto it.
		if (s + 1) % 5 == 0 then
			continue
		end
		local at = a + dir * (length * ((s + 0.5) / runs))

		for _, side in { -1, 1 } do
			local line = at + right * (side * VERGE)

			--[[
				Only fence open ground. If something tall is already standing
				where this post would go, or just behind it, that thing is the
				wall and a railing in front of it is parts spent on nothing.
			]]
			local behind = at + right * (side * (VERGE + 10))
			local occupied = false
			for _, w in ipairs(walls) do
				if
					behind.X > w.min.X - 4
					and behind.X < w.max.X + 4
					and behind.Z > w.min.Z - 4
					and behind.Z < w.max.Z + 4
				then
					occupied = true
					break
				end
			end
			if not occupied then
				if fenceTemplate and fenceSize then
					local clone = fenceTemplate:Clone()
					clone.Parent = fenceRoot
					clone:PivotTo(CFrame.new(line.X, GROUND + fenceSize.Y / 2, line.Z) * CFrame.Angles(0, yaw, 0))
					for _, d in clone:GetDescendants() do
						if d:IsA("BasePart") then
							d.Anchored = true
						elseif d:IsA("LuaSourceContainer") then
							d:Destroy()
						end
					end
					made += 1
				else
					-- No template supplied: a plain post and two rails.
					block(
						fenceRoot,
						"Post",
						Vector3.new(1.2, FENCE_H, 1.2),
						CFrame.new(line.X, GROUND + FENCE_H / 2, line.Z) * CFrame.Angles(0, yaw, 0),
						Color3.fromRGB(66, 49, 34),
						Enum.Material.Wood
					)
					for rail = 1, 2 do
						block(
							fenceRoot,
							"Rail",
							Vector3.new(0.5, 0.7, FENCE_STEP),
							CFrame.new(line.X, GROUND + 1.8 + (rail - 1) * 1.8, line.Z) * CFrame.Angles(0, yaw, 0),
							Color3.fromRGB(86, 79, 68),
							Enum.Material.WoodPlanks
						)
					end
				end

				--[[
					And the part that actually stops a player.

					A fence is five studs, a Roblox character jumps seven. This
					reaches 26 because that is above anything anyone can stack,
					stand on or climb here, and it is invisible so the fence is
					still what you see.
				]]
				local barrier = block(
					fenceRoot,
					"NoEntry",
					Vector3.new(1.4, BARRIER_TOP, FENCE_STEP),
					CFrame.new(line.X, GROUND + BARRIER_TOP / 2, line.Z) * CFrame.Angles(0, yaw, 0),
					Color3.fromRGB(66, 49, 34),
					Enum.Material.Wood
				)
				barrier.Transparency = 1
				barrier.CastShadow = false
			end
		end
	end
end

--==========================================================================
-- THE SNAIL
--==========================================================================
local function gapX(index: number): number
	local x = HALF_W - GAP_W / 2 - GAP_INSET
	return if index % 2 == 1 then x else -x
end

--[[
	The authored route for one chamber.

	  in from the gate, a little way
	  cross the room
	  down the far side
	  cross back
	  down
	  cross again
	  out through the far gate

	Three full crossings of a 300-stud room where the old road was one
	diagonal: about 700 studs of walking instead of 230, in exactly the same
	space, with the exit visible for most of it and not reachable.
]]
local function routeFor(index: number): ({ Vector3 }, { string })
	local zNear = Z_START - (index - 1) * CHAMBER_D
	local zFar = zNear - CHAMBER_D
	local entryX = if index == 1 then 0 else gapX(index - 1)
	local exitX = if index == CHAMBERS then TOWER.X else gapX(index)
	local exitZ = if index == CHAMBERS then TOWER.Z else zFar + 12

	-- Start the snail on the side AWAY from the entry, so the first thing the
	-- player does is cross the room rather than hug the wall they came in by.
	local laneA = if entryX > 0 then -LANE else LANE
	local laneB = -laneA

	local complaints: { string } = {}
	local function crossing(x1: number, x2: number, z: number): number
		local got, blocker = clearCrossing(x1, x2, z)
		if blocker then
			table.insert(complaints, ("crossing at z %d runs through %s"):format(math.floor(z), blocker))
		end
		return got
	end

	local z1 = crossing(entryX, laneA, zNear - 34)
	local z2 = crossing(laneA, laneB, zNear - 84)
	local z3 = crossing(laneB, laneA, zNear - 132)
	local z4 = crossing(laneA, exitX, zNear - 172)

	return {
		Vector3.new(entryX, GROUND, zNear - 10),
		Vector3.new(entryX, GROUND, z1),
		Vector3.new(laneA, GROUND, z1),
		Vector3.new(laneA, GROUND, z2),
		Vector3.new(laneB, GROUND, z2),
		Vector3.new(laneB, GROUND, z3),
		Vector3.new(laneA, GROUND, z3),
		Vector3.new(laneA, GROUND, z4),
		Vector3.new(exitX, GROUND, z4),
		Vector3.new(exitX, GROUND, exitZ),
	},
		complaints
end

--==========================================================================
-- BUILD
--==========================================================================
print("")
print("========================= PAINT ROADS ========================")
print(("  %d things tall enough to bend a road"):format(#walls))
if fenceTemplate then
	print(("  using your fence: %s  (%.0f x %.0f x %.0f)"):format(
		fenceTemplate:GetFullName(),
		(fenceSize :: Vector3).X,
		(fenceSize :: Vector3).Y,
		(fenceSize :: Vector3).Z
	))
else
	print("  no model with 'fence' in its name found — building plain rails")
end
print("")

for index = 1, CHAMBERS do
	local route, complaints = routeFor(index)

	local walked = 0
	for i = 1, #route - 1 do
		paint(route[i], route[i + 1])
		verge(route[i], route[i + 1])
		walked += (route[i + 1] - route[i]).Magnitude
	end

	print(("  Area %d   %.0f studs of road   (%.0f direct)"):format(
		index,
		walked,
		(route[#route] - route[1]).Magnitude
	))
	for _, c in ipairs(complaints) do
		warn(("    Area %d: %s"):format(index, c))
	end

	--------------------------------------------------------------------------
	-- Spawns onto the road, so the dead come along it and not out of a pocket.
	--------------------------------------------------------------------------
	local chamber = battleground:FindFirstChild(("Chamber%d"):format(index))
	local spawns = chamber and chamber:FindFirstChild("Spawns")
	if spawns then
		local places = { North = route[9], East = route[5], West = route[3] }
		for name, at in pairs(places) do
			local marker = spawns:FindFirstChild(name)
			if marker and marker:IsA("BasePart") and at then
				marker.Position = Vector3.new(at.X, GROUND + 3, at.Z)
			end
		end
	end
end

--==========================================================================
print("")
print(("  %d fence parts in Battleground.%s"):format(made, folderName))
print("")
print("  The road is SAND painted into the terrain. No parts, and you can")
print("  reshape it with the terrain brush whenever you like — repainting")
print("  over it with Ground erases it.")
print("")
print("  Do NOT press Ctrl+Z. Undo cannot restore terrain it did not paint.")
print("=========================== END ==============================")
