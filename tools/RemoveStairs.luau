--[[
	RemoveStairs — run in the Studio Command Bar of the FORGOTTEN LANDS place,
	in EDIT MODE. Select the whole file (Ctrl+A), copy, paste, Enter.

	Takes every step out of the castle, because a staircase is a way onto the
	walls and a way onto the walls is a way out of the map.

	IT DOES NOT JUST DELETE THEM. A tower door hanging twenty studs up with
	nothing beneath it looks like a mistake. So wherever a flight is removed, a
	small fall of rubble is left at its foot — which is what actually happens to
	a stone stair in a ruin, and turns "the stairs are missing" into "the stairs
	collapsed". The door above it stops being a route and becomes a detail.

	Also raises the doorway sills slightly where a stair used to meet them, so
	nothing is left standing on thin air.

	Safe to re-run: with no steps left it simply reports none found.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

local LEAVE_RUBBLE = true
local RUBBLE_PER_FLIGHT = 7

local ROCK = Color3.fromRGB(86, 80, 73)
local STONE = Color3.fromRGB(84, 82, 79)

local ground = workspace:FindFirstChild("Gameplay")
if not ground then
	warn("[Stairs] no Workspace.Gameplay — nothing to clean.")
	return
end

local rng = Random.new(97)

--==========================================================================
-- Find every step, grouped by the model it belongs to
--==========================================================================
--[[
	Grouping matters: a flight of seven steps under one tower is ONE collapsed
	stair and should leave one pile. Treating each step separately would carpet
	the castle in gravel.
]]
local flights: { [Instance]: { BasePart } } = {}
local total = 0

for _, descendant in ipairs(ground:GetDescendants()) do
	if descendant:IsA("BasePart") and (descendant.Name == "Step" or descendant.Name == "Stairs") then
		local owner = descendant.Parent
		if owner then
			flights[owner] = flights[owner] or {}
			table.insert(flights[owner], descendant)
			total += 1
		end
	end
end

-- Whole models named Stairs, from the older builders.
for _, descendant in ipairs(ground:GetDescendants()) do
	if descendant:IsA("Model") and descendant.Name == "Stairs" then
		for _, part in ipairs(descendant:GetDescendants()) do
			if part:IsA("BasePart") then
				total += 1
			end
		end
		flights[descendant] = flights[descendant] or {}
	end
end

if total == 0 then
	print("[Stairs] none found. Nothing to remove.")
	return
end

--==========================================================================
-- Remove, and leave the story of the removal behind
--==========================================================================
local removed, piles = 0, 0

for owner, steps in pairs(flights) do
	-- Where the flight stood, and how low it reached.
	local centre = Vector3.zero
	local lowest = math.huge
	local count = 0
	for _, step in ipairs(steps) do
		centre += step.Position
		lowest = math.min(lowest, step.Position.Y - step.Size.Y / 2)
		count += 1
	end

	if count > 0 then
		centre /= count

		for _, step in ipairs(steps) do
			step:Destroy()
			removed += 1
		end

		if LEAVE_RUBBLE then
			local pile = Instance.new("Model")
			pile.Name = "CollapsedStair"
			pile.Parent = owner

			for _ = 1, RUBBLE_PER_FLIGHT do
				local s = rng:NextNumber(2.5, 7)
				local part = Instance.new("Part")
				part.Name = "Stone"
				part.Anchored = true
				part.CanCollide = true
				part.CastShadow = false
				part.Size = Vector3.new(s, s * rng:NextNumber(0.35, 0.7), s * rng:NextNumber(0.6, 1.1))
				part.CFrame = CFrame.new(
					centre.X + rng:NextNumber(-7, 7),
					lowest + s * 0.3,
					centre.Z + rng:NextNumber(-7, 7)
				) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4))
				part.Color = if rng:NextNumber() < 0.5 then ROCK else STONE
				part.Material = Enum.Material.Rock
				part.Parent = pile
			end
			piles += 1
		end
	end

	-- Older tools wrapped a flight in its own model; once emptied it is litter.
	if owner:IsA("Model") and owner.Name == "Stairs" then
		for _, part in ipairs(owner:GetDescendants()) do
			if part:IsA("BasePart") then
				part:Destroy()
				removed += 1
			end
		end
		if #owner:GetChildren() == 0 then
			owner:Destroy()
		end
	end
end

--==========================================================================
print(("[Stairs] removed %d step(s) across %d flight(s)."):format(removed, piles))
if LEAVE_RUBBLE then
	print(("[Stairs] left %d fall(s) of rubble where they collapsed."):format(piles))
end
print("[Stairs] The wall-walks are now unreachable, which is the point.")
print("[Stairs] Run it again after any rebuild — BuildBattleground no longer makes them, but old geometry might.")
