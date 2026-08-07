--[[
	DumpSizes — run in the Studio Command Bar of the FORGOTTEN LANDS place,
	in EDIT MODE. Select all, copy, paste, Enter. It CHANGES NOTHING.

	--------------------------------------------------------------------------
	EVERY DIMENSION OF EVERYTHING

	Width, HEIGHT and length in studs — the real size of the box a thing
	occupies, not a scale factor. For every object in every chamber, plus the
	loose things outside them, plus what is waiting in ServerStorage.

	    WIDTH x HEIGHT x LENGTH    x from..to    z from..to    name

	Sorted north to south inside each chamber, which is the order you walk past
	them. This is the sheet a layout gets drawn on.

	--------------------------------------------------------------------------
	IT REPORTS THE FENCES SEPARATELY AND IN FULL

	Because they are the thing being placed by hand next, and because "the
	fences are bigger than you think" turned out to be exactly right — every
	number that matters for one is printed on its own line: its footprint, its
	height, whether it has a Barrier inside it, and whether that barrier
	actually matches.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

local SHOW_SMALL = false -- true to include everything under 8 studs

--==========================================================================
local Z_START = 20
local CHAMBER_D = 200
local CHAMBERS = 9
local HALF_W = 150
local MIN_SIZE = 8

local ServerStorage = game:GetService("ServerStorage")

--==========================================================================
--[[
	The world-axis extent of a part.

	Part.Size is measured along the PART's own axes, so a rotated part's world
	footprint is the sum of what each local axis contributes. Reading Size
	directly on anything turned is simply wrong, and it is wrong quietly.
]]
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
	RoadFences = true,
	Approach = true,
	Buildings = true,
	Models = true,
	Weapons = true,
}

local function isContainer(instance: Instance): boolean
	return CONTAINERS[instance.Name] == true
		or string.match(instance.Name, "^Chamber%d+$") ~= nil
		or string.match(instance.Name, "^Area%d+$") ~= nil
end

local function objectOf(part: BasePart): Instance
	local node: Instance = part
	while node.Parent and node.Parent ~= workspace and not isContainer(node.Parent) do
		node = node.Parent
	end
	return node
end

--==========================================================================
type Box = { minX: number, maxX: number, minY: number, maxY: number, minZ: number, maxZ: number, n: number }

local function grow(box: Box?, lo: Vector3, hi: Vector3): Box
	if not box then
		return { minX = lo.X, maxX = hi.X, minY = lo.Y, maxY = hi.Y, minZ = lo.Z, maxZ = hi.Z, n = 1 }
	end
	box.minX = math.min(box.minX, lo.X)
	box.maxX = math.max(box.maxX, hi.X)
	box.minY = math.min(box.minY, lo.Y)
	box.maxY = math.max(box.maxY, hi.Y)
	box.minZ = math.min(box.minZ, lo.Z)
	box.maxZ = math.max(box.maxZ, hi.Z)
	box.n += 1
	return box
end

--==========================================================================
local parts: { BasePart } = {}
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("BasePart") and d ~= workspace.Terrain then
		table.insert(parts, d)
	end
end

print("")
print("========================== DUMP SIZES ========================")
print(("  %d parts in the Workspace"):format(#parts))
print("")
print("  Every line reads:")
print("     W x H x L      x from..to      z from..to      name")
print("  W, H and L are STUDS — the real box, not a scale.")
print("")

--==========================================================================
-- THE CHAMBERS
--==========================================================================
for index = 1, CHAMBERS do
	local zNear = Z_START - (index - 1) * CHAMBER_D
	local zFar = zNear - CHAMBER_D

	local objects: { [Instance]: Box } = {}
	for _, p in ipairs(parts) do
		local lo, hi = span(p)
		local cz = (lo.Z + hi.Z) / 2
		local cx = (lo.X + hi.X) / 2
		if cz <= zNear and cz >= zFar and math.abs(cx) <= HALF_W then
			local owner = objectOf(p)
			objects[owner] = grow(objects[owner], lo, hi)
		end
	end

	local rows = {}
	for owner, b in pairs(objects) do
		local w, h, l = b.maxX - b.minX, b.maxY - b.minY, b.maxZ - b.minZ
		if SHOW_SMALL or w >= MIN_SIZE or l >= MIN_SIZE or h >= MIN_SIZE then
			table.insert(rows, { owner = owner, b = b, w = w, h = h, l = l })
		end
	end
	table.sort(rows, function(a, b)
		return (a.b.maxZ + a.b.minZ) > (b.b.maxZ + b.b.minZ)
	end)

	print(("--- AREA %d    z %d..%d    %d objects ------------------"):format(index, zFar, zNear, #rows))

	for _, r in ipairs(rows) do
		print(("   %5.0f x%5.0f x%5.0f   x %6.0f..%-6.0f  z %6.0f..%-6.0f  %s"):format(
			r.w,
			r.h,
			r.l,
			r.b.minX,
			r.b.maxX,
			r.b.minZ,
			r.b.maxZ,
			r.owner.Name
		))
	end
	print("")
end

--==========================================================================
-- THE FENCES, IN FULL
--==========================================================================
print("--- FENCES ---------------------------------------------------")
do
	local found = 0
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") and string.find(string.lower(d.Name), "fence") then
			found += 1
			local cf, size = d:GetBoundingBox()
			local p = cf.Position

			print(("  %s"):format(d:GetFullName()))
			print(("     size in its OWN frame  %.1f wide  %.1f high  %.1f long"):format(size.X, size.Y, size.Z))
			print(("     centre  x %.1f  y %.1f  z %.1f"):format(p.X, p.Y, p.Z))
			print(("     parts   %d"):format(#d:GetDescendants()))

			local barrier = d:FindFirstChild("Barrier")
			if barrier and barrier:IsA("BasePart") then
				local matches = math.abs(barrier.Size.X - size.X) < 2 and math.abs(barrier.Size.Z - size.Z) < 2
				print(("     barrier %.1f x %.1f x %.1f   %s"):format(
					barrier.Size.X,
					barrier.Size.Y,
					barrier.Size.Z,
					if matches then "matches the fence" else "DOES NOT MATCH THE FENCE"
				))
			else
				print("     barrier NONE — run tools/FenceBarrier with this selected")
			end
		end
	end
	if found == 0 then
		print("  none found. A fence needs 'fence' in its name to be seen here.")
	end
end

--==========================================================================
-- WHAT IS WAITING IN SERVERSTORAGE
--==========================================================================
print("")
print("--- SERVERSTORAGE --------------------------------------------")
do
	local function describe(instance: Instance, indent: string)
		if instance:IsA("BasePart") then
			print(("%s%s  [%s]  %.1f x %.1f x %.1f"):format(
				indent,
				instance.Name,
				instance.ClassName,
				instance.Size.X,
				instance.Size.Y,
				instance.Size.Z
			))
		elseif instance:IsA("Model") then
			local _, size = instance:GetBoundingBox()
			print(("%s%s  [Model, %d parts]  %.1f x %.1f x %.1f"):format(
				indent,
				instance.Name,
				#instance:GetDescendants(),
				size.X,
				size.Y,
				size.Z
			))
		else
			print(("%s%s  [%s]"):format(indent, instance.Name, instance.ClassName))
		end
		for _, child in ipairs(instance:GetChildren()) do
			if #indent < 8 then
				describe(child, indent .. "  ")
			end
		end
	end

	for _, child in ipairs(ServerStorage:GetChildren()) do
		describe(child, "  ")
	end
end

print("")
print("=========================== END ==============================")
