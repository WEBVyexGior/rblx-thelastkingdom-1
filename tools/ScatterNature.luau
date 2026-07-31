--[[
	ScatterNature — run ONCE in the Studio Command Bar, in EDIT MODE (not playtest).

	Copy this whole file, paste it into the Command Bar, press Enter.

	What it does:
	  1. Extends the terrain to 1000 x 1000, leaving the built camp untouched.
	  2. Scatters trees, rocks and sticks in three rings that grow denser as they
	     go out — sparse at the treeline, a wall of trunks at the edge — so the
	     player never sees where the world stops.

	Everything it creates goes in `Lobby.Nature.Scattered`. Re-running replaces
	that folder and nothing else, so it is safe to run again after tweaking the
	numbers below. Your hand-placed trees are never touched.

	NOTE: this is a tool, not game code. It is not synced by Rojo.
]]

--==========================================================================
-- Tune these
--==========================================================================
local HALF = 500 -- half of 1000 x 1000
local CAMP_RADIUS = 250 -- nothing is planted inside this
local TERRAIN_PROTECT = 220 -- terrain inside this is left exactly as it is

-- Rings, innermost first. Density climbs so the horizon closes up.
local RINGS = {
	{ from = 250, to = 340, trees = 150, rocks = 140, sticks = 120, scale = { 0.75, 1.05 } },
	{ from = 340, to = 430, trees = 300, rocks = 90, sticks = 70, scale = { 0.9, 1.25 } },
	{ from = 430, to = 498, trees = 460, rocks = 40, sticks = 30, scale = { 1.0, 1.45 } },
}

local TREES = { "Tree Type1", "Tree Type2" }
local ROCKS = { "Small Rock" }
local STICKS = { "Stick" }

--==========================================================================

local lobby = workspace:FindFirstChild("Lobby")
assert(lobby, "no workspace.Lobby")
local nature = lobby:FindFirstChild("Nature")
assert(nature, "no Lobby.Nature")

-- Find one source instance per asset name, from the ones already placed.
local function source(name)
	for _, child in ipairs(nature:GetChildren()) do
		if child.Name == name then
			return child
		end
	end
	return nil
end

local sources = {}
for _, list in ipairs({ TREES, ROCKS, STICKS }) do
	for _, name in ipairs(list) do
		local found = source(name)
		if found then
			sources[name] = found
		else
			warn("[Scatter] missing source: " .. name)
		end
	end
end

-- Fresh start: only ever removes what this tool made.
local old = nature:FindFirstChild("Scattered")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "Scattered"
folder.Parent = nature

--==========================================================================
-- 1. Terrain
--==========================================================================
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { lobby }

local spawnPart = lobby:FindFirstChild("Spawn") and lobby.Spawn:FindFirstChild("SpawnPoint")
local groundY = if spawnPart then spawnPart.Position.Y - 0.5 else 0

local TILE = 50
local filled = 0
for x = -HALF, HALF - TILE, TILE do
	for z = -HALF, HALF - TILE, TILE do
		local cx, cz = x + TILE / 2, z + TILE / 2
		-- Leave the camp alone: only fill what is outside it.
		if math.sqrt(cx * cx + cz * cz) > TERRAIN_PROTECT then
			workspace.Terrain:FillBlock(
				CFrame.new(cx, groundY - 10, cz),
				Vector3.new(TILE, 20, TILE),
				Enum.Material.Ground
			)
			filled += 1
		end
	end
	task.wait()
end
print(("[Scatter] terrain: %d tiles filled at y=%.1f"):format(filled, groundY))

--==========================================================================
-- 2. Scatter
--==========================================================================
local rng = Random.new(20260731)

local function place(name, ring)
	local template = sources[name]
	if not template then
		return false
	end

	-- sqrt keeps the points evenly spread over the RING'S AREA; without it they
	-- bunch towards the inner edge.
	local t = rng:NextNumber()
	local radius = math.sqrt((ring.from ^ 2) + t * ((ring.to ^ 2) - (ring.from ^ 2)))
	local angle = rng:NextNumber() * math.pi * 2
	local x, z = math.cos(angle) * radius, math.sin(angle) * radius

	-- Ground-snap: placing at a guessed height either buries the trunk or floats it.
	local hit = workspace:Raycast(Vector3.new(x, groundY + 200, z), Vector3.new(0, -400, 0), params)
	local y = if hit then hit.Position.Y else groundY

	local clone = template:Clone()
	local scale = rng:NextNumber(ring.scale[1], ring.scale[2])
	local spin = CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
	-- A degree or two of lean: a forest of perfectly upright trunks reads as a grid.
	local lean = CFrame.Angles(math.rad(rng:NextNumber(-3, 3)), 0, math.rad(rng:NextNumber(-3, 3)))

	if clone:IsA("Model") then
		clone:ScaleTo(scale)
		clone:PivotTo(CFrame.new(x, y, z) * spin * lean)
		for _, part in ipairs(clone:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
			end
		end
	else
		clone.Size = template.Size * scale
		clone.CFrame = CFrame.new(x, y + (clone.Size.Y / 2), z) * spin * lean
		clone.Anchored = true
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
	end

	clone.Parent = folder
	return true
end

local made = 0
for index, ring in ipairs(RINGS) do
	local groups = {
		{ list = TREES, count = ring.trees },
		{ list = ROCKS, count = ring.rocks },
		{ list = STICKS, count = ring.sticks },
	}
	for _, group in ipairs(groups) do
		for n = 1, group.count do
			local name = group.list[rng:NextInteger(1, #group.list)]
			if place(name, ring) then
				made += 1
			end
			if n % 60 == 0 then
				task.wait()
			end
		end
	end
	print(("[Scatter] ring %d (%d-%d studs) done"):format(index, ring.from, ring.to))
end

print(("[Scatter] DONE — %d objects in Lobby.Nature.Scattered"):format(made))
print("Look around from spawn. Too thin or too dense? Change the numbers at the top and run it again.")
