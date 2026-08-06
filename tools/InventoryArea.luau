--[[
	InventoryArea — run in the Studio Command Bar of the FORGOTTEN LANDS place,
	in EDIT MODE. Select all, copy, paste, Enter. It CHANGES NOTHING.

	--------------------------------------------------------------------------
	WHAT THIS IS AND WHY IT EXISTS

	The road was asked to zigzag through the town, and what got written instead
	picked random free cells and called the result a design. It was not a
	design — it was noise with a seed number on it, and in the two densest
	chambers it routed nothing at all and drew straight lines through houses.

	The reason is simple: a route cannot be designed without knowing where
	things ARE. That was asked for, and a summary of part counts per folder was
	sent back instead. This is the thing that was actually wanted.

	It prints, for each chamber, every OBJECT — a house, a cart, a well, a
	tower — with its exact footprint:

	    x  -84.. -42   z -310..-268    42 x 42    Abandoned House V1

	Rolled up so a 300-part house is one line, sorted north to south, which is
	the order you walk past them. From this a road can be drawn by hand,
	corner by corner, against real numbers.

	--------------------------------------------------------------------------
	AREA and MIN_SIZE below. Leave AREA at 0 for all nine at once; set it to a
	number for one chamber in full detail including the small stuff.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

local AREA = 0 -- 0 = every chamber; 1..9 = that one, in full
local MIN_SIZE = 8 -- ignore anything whose footprint is smaller than this

--==========================================================================
local Z_START = 20
local CHAMBER_D = 200
local CHAMBERS = 9
local HALF_W = 150
local GROUND = 2

--[[
	Folders that are scaffolding rather than objects.

	Rolling a part up to its top-level ancestor gives "Battleground" for
	everything and is useless; rolling it up to its immediate parent gives one
	line per plank. The answer is to climb until the PARENT is one of these,
	which lands exactly on the thing a person would call an object.
]]
local CONTAINERS = {
	Workspace = true,
	Gameplay = true,
	Battleground = true,
	Decorations = true,
	Structure = true,
	Shell = true,
	Path = true,
	Spawns = true,
	Objectives = true,
	Flagstones = true,
	Kerbs = true,
	Dirt = true,
	Fences = true,
	Barriers = true,
	Approach = true,
	Buildings = true,
}

local function isContainer(instance: Instance): boolean
	if CONTAINERS[instance.Name] then
		return true
	end
	-- Chamber1..9 and Area1..9 are containers too, whatever else is in them.
	return string.match(instance.Name, "^Chamber%d+$") ~= nil
		or string.match(instance.Name, "^Area%d+$") ~= nil
end

--==========================================================================
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
	The object a part belongs to.

	Climbs while the PARENT is scaffolding, so it stops on the highest thing
	that is still a real object. A part directly inside a container is its own
	object, which is right — a lone barrel in Decorations is a barrel.
]]
local function objectOf(part: BasePart): Instance
	local node: Instance = part
	while node.Parent and node.Parent ~= workspace and not isContainer(node.Parent) do
		node = node.Parent
	end
	return node
end

--==========================================================================
local gameplay = workspace:FindFirstChild("Gameplay")
if not gameplay then
	warn("[Inventory] no Workspace.Gameplay.")
	return
end

-- One sweep for the whole castle. Nine sweeps of thirty thousand instances
-- freezes Studio for long enough to look like a crash.
local parts: { BasePart } = {}
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("BasePart") and d ~= workspace.Terrain and d.CanCollide then
		local _, hi = span(d)
		-- Floors, flagstones and anything buried are not objects in the way.
		if hi.Y > GROUND + 2.5 then
			table.insert(parts, d)
		end
	end
end

print("")
print("======================= AREA INVENTORY ======================")
print(("  %d solid parts above ground"):format(#parts))
print("")

--==========================================================================
local first = if AREA == 0 then 1 else AREA
local last = if AREA == 0 then CHAMBERS else AREA
local minSize = if AREA == 0 then MIN_SIZE else 0

for index = first, last do
	local zNear = Z_START - (index - 1) * CHAMBER_D
	local zFar = zNear - CHAMBER_D
	local gap = if index % 2 == 1 then 115 else -115

	local entryGap = if index == 1 then 0 else (if (index - 1) % 2 == 1 then 115 else -115)

	print(("--- AREA %d ------------------------------------------------"):format(index))
	print(("    room     x -150..150   z %d..%d"):format(zFar, zNear))
	print(("    you enter at  x %d, z %d"):format(entryGap, zNear))
	print(("    you leave at  x %d, z %d"):format(gap, zFar))
	print("")

	--------------------------------------------------------------------------
	local objects: { [Instance]: { minX: number, maxX: number, minZ: number, maxZ: number, n: number } } = {}

	for _, p in ipairs(parts) do
		local lo, hi = span(p)
		local cz = (lo.Z + hi.Z) / 2
		local cx = (lo.X + hi.X) / 2
		if cz <= zNear and cz >= zFar and math.abs(cx) <= HALF_W then
			local owner = objectOf(p)
			local entry = objects[owner]
			if not entry then
				entry = { minX = lo.X, maxX = hi.X, minZ = lo.Z, maxZ = hi.Z, n = 0 }
				objects[owner] = entry
			end
			entry.minX = math.min(entry.minX, lo.X)
			entry.maxX = math.max(entry.maxX, hi.X)
			entry.minZ = math.min(entry.minZ, lo.Z)
			entry.maxZ = math.max(entry.maxZ, hi.Z)
			entry.n += 1
		end
	end

	local rows = {}
	for owner, e in pairs(objects) do
		local w = e.maxX - e.minX
		local d = e.maxZ - e.minZ
		if w >= minSize or d >= minSize then
			table.insert(rows, { owner = owner, e = e, w = w, d = d })
		end
	end

	-- North to south: the order you walk past them.
	table.sort(rows, function(a, b)
		return (a.e.maxZ + a.e.minZ) > (b.e.maxZ + b.e.minZ)
	end)

	for _, row in ipairs(rows) do
		print(("    x %7.0f..%-7.0f  z %7.0f..%-7.0f  %4.0f x %-4.0f  %s"):format(
			row.e.minX,
			row.e.maxX,
			row.e.minZ,
			row.e.maxZ,
			row.w,
			row.d,
			row.owner.Name
		))
	end

	print(("    %d objects%s"):format(#rows, if minSize > 0 then (" over %d studs"):format(minSize) else ""))
	print("")
end

--==========================================================================
print("--- HOW TO READ THIS ----------------------------------------")
print("  Each line is one object and its exact footprint in world studs.")
print("  Sorted north to south, which is the order you meet them.")
print("")
print("  Set AREA = 1..9 at the top for one chamber including the small")
print("  stuff; leave it 0 for all nine with only the buildings.")
print("=========================== END ==============================")
