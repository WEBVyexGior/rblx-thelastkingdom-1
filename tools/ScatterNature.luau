--[[
	ScatterNature — run in the Studio Command Bar, in EDIT MODE (not playtest).

	Select the WHOLE file (Ctrl+A), copy, paste into the Command Bar, Enter.

	It does three things, in order:
	  1. CLEANS UP — deletes every rock and stick, thins out the hand-placed
	     trees, and turns off shadows on everything left.
	  2. FILLS THE GROUND to 3000 x 3000 with no gaps anywhere, so there is
	     nowhere left to fall through.
	  3. PLANTS a sparse forest that thickens towards the horizon, with a
	     minimum gap between trunks so the trees have room to breathe.

	Anything it plants goes in `Lobby.Nature.Scattered`. Re-running replaces only
	that folder — but note that step 1 deletes hand-placed objects, so it will
	not put those back. Ctrl+Z undoes the whole run if you dislike it.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

--==========================================================================
-- Tune these
--==========================================================================
local HALF = 1500 -- half of 3000 x 3000

-- Rings, innermost first. Trees only — rocks and sticks were costing frames for
-- scenery nobody walks up to. `gap` is the minimum distance between two trunks:
-- it is what stops the forest reading as a thicket.
local RINGS = {
	{ from = 260, to = 620, trees = 130, gap = 58, scale = { 0.8, 1.1 } },
	{ from = 620, to = 1050, trees = 210, gap = 48, scale = { 0.9, 1.3 } },
	{ from = 1050, to = 1490, trees = 380, gap = 38, scale = { 1.0, 1.5 } },
}

local TREES = { "Tree Type1", "Tree Type2" }
-- How many hand-placed trees of each type to KEEP. Expressed as a target rather
-- than "remove 50" so running the tool twice does not strip the lobby bare:
-- Tree Type1 goes 60 -> 10, Tree Type2 goes 47 -> 10. (A flat 50 would have
-- erased Type2 entirely, since only 47 were placed.)
local KEEP_PER_TREE_TYPE = 10
local DELETE_NAMES = { "Small Rock", "Stick" } -- gone entirely

--==========================================================================

local lobby = workspace:FindFirstChild("Lobby")
assert(lobby, "no workspace.Lobby")
local nature = lobby:FindFirstChild("Nature")
assert(nature, "no Lobby.Nature")

local function positionOf(instance)
	if instance:IsA("Model") then
		return instance:GetPivot().Position
	elseif instance:IsA("BasePart") then
		return instance.Position
	end
	return Vector3.zero
end

local function killShadows(instance)
	if instance:IsA("BasePart") then
		instance.CastShadow = false
	end
	for _, part in ipairs(instance:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CastShadow = false
		end
	end
end

--==========================================================================
-- 1. Clean up
--==========================================================================
local removed = 0
for _, child in ipairs(nature:GetChildren()) do
	if table.find(DELETE_NAMES, child.Name) then
		child:Destroy()
		removed += 1
	end
end
print(("[Scatter] removed %d rock(s)/stick(s)"):format(removed))

-- Thin the hand-placed trees FURTHEST FROM SPAWN first: the ones close to camp
-- were placed deliberately, the far ones were filler.
local spawnPart = lobby:FindFirstChild("Spawn") and lobby.Spawn:FindFirstChild("SpawnPoint")
local origin = if spawnPart then spawnPart.Position else Vector3.zero

for _, treeName in ipairs(TREES) do
	local found = {}
	for _, child in ipairs(nature:GetChildren()) do
		if child.Name == treeName then
			table.insert(found, child)
		end
	end
	table.sort(found, function(a, b)
		return (positionOf(a) - origin).Magnitude > (positionOf(b) - origin).Magnitude
	end)

	local keep = math.max(1, KEEP_PER_TREE_TYPE) -- at least one, to clone from
	local target = math.max(0, #found - keep)
	for index = 1, target do
		found[index]:Destroy()
	end
	print(("[Scatter] %s: removed %d of %d, %d left"):format(treeName, target, #found, #found - target))
end

-- One source of each type must survive to clone from.
local sources = {}
for _, name in ipairs(TREES) do
	for _, child in ipairs(nature:GetChildren()) do
		if child.Name == name then
			sources[name] = child
			break
		end
	end
	if not sources[name] then
		warn("[Scatter] no '" .. name .. "' left to clone from — keep at least one")
	end
end

local old = nature:FindFirstChild("Scattered")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "Scattered"
folder.Parent = nature

-- Shadows off everywhere. Hundreds of shadow-casting trunks is the single
-- biggest avoidable cost in a scene like this, and nobody looks at them.
for _, child in ipairs(nature:GetChildren()) do
	killShadows(child)
end

--==========================================================================
-- 2. Ground — everywhere, no gaps
--==========================================================================
local groundY = if spawnPart then spawnPart.Position.Y - 0.5 else 0

-- The whole square is filled, including under the camp. Where ground already
-- exists this changes nothing; where it was missing, it closes the hole a
-- player could have fallen through.
local TILE = 100
local filled = 0
for x = -HALF, HALF - TILE, TILE do
	for z = -HALF, HALF - TILE, TILE do
		workspace.Terrain:FillBlock(
			CFrame.new(x + TILE / 2, groundY - 10, z + TILE / 2),
			Vector3.new(TILE, 20, TILE),
			Enum.Material.Ground
		)
		filled += 1
	end
	task.wait()
end
print(("[Scatter] ground: %d tiles, %d x %d studs, at y=%.1f"):format(filled, HALF * 2, HALF * 2, groundY))

--==========================================================================
-- 3. Plant
--==========================================================================
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { lobby }

local rng = Random.new(20260731)

-- A grid of planted points, so "is anything already near here" is a handful of
-- lookups instead of a walk through every tree planted so far.
--
-- ONE fixed cell size for all rings, larger than the biggest gap: a per-ring
-- grid would key the same spot differently in each ring and let trees from
-- neighbouring rings grow through each other at the seams. Each cell holds a
-- list, because several trees can share one.
local CELL = 60
local grid = {}

local function key(cx: number, cz: number): string
	return ("%d:%d"):format(cx, cz)
end

local function tooClose(x: number, z: number, gap: number): boolean
	local here = Vector2.new(x, z)
	local cx, cz = math.floor(x / CELL), math.floor(z / CELL)
	for dx = -1, 1 do
		for dz = -1, 1 do
			local bucket = grid[key(cx + dx, cz + dz)]
			if bucket then
				for _, point in ipairs(bucket) do
					if (point - here).Magnitude < gap then
						return true
					end
				end
			end
		end
	end
	return false
end

local function remember(x: number, z: number)
	local k = key(math.floor(x / CELL), math.floor(z / CELL))
	grid[k] = grid[k] or {}
	table.insert(grid[k], Vector2.new(x, z))
end

local planted = 0
for index, ring in ipairs(RINGS) do
	local made = 0
	-- Attempts are capped: with a minimum gap enforced, a ring can simply run
	-- out of room, and it must not spin forever looking for space.
	for _ = 1, ring.trees * 12 do
		if made >= ring.trees then
			break
		end

		-- sqrt spreads the points evenly over the ring's AREA; without it they
		-- bunch against the inner edge.
		local t = rng:NextNumber()
		local radius = math.sqrt((ring.from ^ 2) + t * ((ring.to ^ 2) - (ring.from ^ 2)))
		local angle = rng:NextNumber() * math.pi * 2
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius

		if not tooClose(x, z, ring.gap) then
			local name = TREES[rng:NextInteger(1, #TREES)]
			local template = sources[name]
			if template then
				local hit = workspace:Raycast(Vector3.new(x, groundY + 300, z), Vector3.new(0, -600, 0), params)
				local y = if hit then hit.Position.Y else groundY

				local clone = template:Clone()
				local scale = rng:NextNumber(ring.scale[1], ring.scale[2])
				local spin = CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
				-- A degree or two of lean: perfectly upright trunks read as a grid.
				local lean = CFrame.Angles(math.rad(rng:NextNumber(-3, 3)), 0, math.rad(rng:NextNumber(-3, 3)))

				if clone:IsA("Model") then
					clone:ScaleTo(scale)
					clone:PivotTo(CFrame.new(x, y, z) * spin * lean)
				else
					clone.Size = template.Size * scale
					clone.CFrame = CFrame.new(x, y + (clone.Size.Y / 2), z) * spin * lean
				end

				for _, part in ipairs(clone:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Anchored = true
						part.CanCollide = false
						part.CanQuery = false
						part.CanTouch = false
						part.CastShadow = false
					end
				end
				if clone:IsA("BasePart") then
					clone.Anchored = true
					clone.CanCollide = false
					clone.CanQuery = false
					clone.CanTouch = false
					clone.CastShadow = false
				end

				clone.Parent = folder
				remember(x, z)
				made += 1
				planted += 1

				if planted % 60 == 0 then
					task.wait()
				end
			end
		end
	end
	print(("[Scatter] ring %d (%d-%d studs, %d gap): %d tree(s)"):format(index, ring.from, ring.to, ring.gap, made))
end

print(("[Scatter] DONE — %d trees planted, shadows off, ground sealed"):format(planted))
print("Too sparse or too dense? Change `trees` and `gap` at the top and run again.")
