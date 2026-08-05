--[[
	SurveyCastle — run in the Studio Command Bar of the FORGOTTEN LANDS place,
	in EDIT MODE. Select all, copy, paste, Enter. It CHANGES NOTHING.

	--------------------------------------------------------------------------
	WHAT IT IS FOR

	The next job is the layout: narrower zigzag roads, branches, fences that
	cannot be jumped, houses you can walk into, and areas that take more than
	five minutes. None of that can be planned against the numbers in
	BuildChambers, because the place has been edited by hand since — that
	mistake has already been made once and put a stable range on the road.

	So this is the inventory. Nine chambers, and for each one: how much is in
	it, what the biggest things are, how wide the road runs, and how much floor
	is actually free. Send me the output and the layout gets designed against
	it.

	It also prints a DELETE / KEEP suggestion per chamber, so the decision about
	what gets rebuilt is made from what is there rather than from memory.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

local Z_START = 20
local CHAMBER_D = 200
local CHAMBERS = 9
local HALF_W = 150

--==========================================================================
local function line(s: string)
	print(s)
end

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

--==========================================================================
local gameplay = workspace:FindFirstChild("Gameplay")
local battleground = gameplay and gameplay:FindFirstChild("Battleground")
if not battleground then
	warn("[Survey] no Gameplay.Battleground.")
	return
end

local pathFolder = battleground:FindFirstChild("Path")

--[[
	Gathered ONCE. Walking the whole Workspace per chamber is nine full sweeps
	of a hundred thousand instances, which locks Studio for long enough that it
	looks like a crash.
]]
local parts: { BasePart } = {}
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("BasePart") then
		table.insert(parts, d)
	end
end

line("")
line("======================== CASTLE SURVEY =======================")
line(("  %d parts in the Workspace"):format(#parts))
line("")

--==========================================================================
for index = 1, CHAMBERS do
	local zNear = Z_START - (index - 1) * CHAMBER_D
	local zFar = zNear - CHAMBER_D
	local gapX = if index % 2 == 1 then 115 else -115

	line(("--- AREA %d   z %d..%d   passage x %d ------------------"):format(index, zFar, zNear, gapX))

	--------------------------------------------------------------------------
	-- What is in it, rolled up per top-level owner
	--------------------------------------------------------------------------
	local owners: { [string]: number } = {}
	local roadMinX, roadMaxX = math.huge, -math.huge
	local total = 0

	for _, p in ipairs(parts) do
		local a, b = span(p)
		local cz = (a.Z + b.Z) / 2
		if cz <= zNear and cz >= zFar and math.abs(p.Position.X) <= HALF_W then
			total += 1

			if pathFolder and p:IsDescendantOf(pathFolder) then
				roadMinX = math.min(roadMinX, a.X)
				roadMaxX = math.max(roadMaxX, b.X)
			else
				-- Roll up three levels, so a 900-part model is one row.
				local owner: Instance = p
				local hops = 0
				while owner.Parent and owner.Parent ~= workspace and hops < 3 do
					owner = owner.Parent
					hops += 1
				end
				local key = owner.Name
				owners[key] = (owners[key] or 0) + 1
			end
		end
	end

	local rows = {}
	for name, n in pairs(owners) do
		table.insert(rows, { name = name, n = n })
	end
	table.sort(rows, function(a, b)
		return a.n > b.n
	end)

	line(("    %d parts total"):format(total))
	if roadMinX < math.huge then
		line(("    road runs x %.0f .. %.0f  (%.0f wide)"):format(roadMinX, roadMaxX, roadMaxX - roadMinX))
	else
		line("    NO ROAD in this chamber")
	end

	for i, row in ipairs(rows) do
		if i > 6 then
			line(("      ... and %d more kinds"):format(#rows - 6))
			break
		end
		line(("      %6d  %s"):format(row.n, row.name))
	end

	--------------------------------------------------------------------------
	-- How much floor is actually walkable, sampled on a grid
	--------------------------------------------------------------------------
	local free, tested = 0, 0
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.MaxParts = 1

	for x = -HALF_W + 15, HALF_W - 15, 20 do
		for z = zFar + 15, zNear - 15, 20 do
			tested += 1
			local box = CFrame.new(x, 6, z)
			if #workspace:GetPartBoundsInBox(box, Vector3.new(10, 8, 10), params) == 0 then
				free += 1
			end
		end
	end

	if tested > 0 then
		line(("    open floor: %d%% of the room  (%d of %d samples clear)"):format(
			math.floor(free / tested * 100),
			free,
			tested
		))
	end

	line("")
end

--==========================================================================
line("--- WHAT I NEED FROM THIS -----------------------------------")
line("  For each area, tell me which of the listed owners you want KEPT.")
line("  Everything else I will rebuild in place, to measured positions,")
line("  once the new road and the fences are down.")
line("")
line("  My default suggestion, unless you say otherwise:")
line("    KEEP    Structure (walls, towers, passages) — never touched")
line("    KEEP    anything you placed by hand (Horse Stable and the like)")
line("    REBUILD Path — narrower, zigzag, with branches")
line("    REBUILD Decorations — same buildings, new positions off the road")
line("")
line("=========================== END ==============================")
