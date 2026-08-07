--[[
	CleanSlate — run in the Studio Command Bar of the FORGOTTEN LANDS place,
	in EDIT MODE. Select all, copy, paste, Enter.

	--------------------------------------------------------------------------
	IT TAKES BACK EVERYTHING I ADDED TO THE LAYOUT

	  - every sand strip painted into the terrain, back to Ground
	  - the whole RoadFences folder, every fence and every barrier in it
	  - any leftover Path folder from the two parts roads
	  - the archived old paths in ServerStorage, which are now just weight

	What it does NOT touch: the castle, the buildings, the Horse Stable, the
	decorations, the towers, the gates, or one single thing placed by hand. The
	previous design stays exactly as it was.

	After this the ground is ground and the layout is yours to draw.

	--------------------------------------------------------------------------
	WHY THE SAND HAS TO BE REPLACED RATHER THAN DELETED

	Terrain is not instances; there is nothing to Destroy. Sand is unpainted by
	painting Ground back over the same volume, which is what ReplaceMaterial
	does across a region. It only ever touches Sand, so anything that was Ground
	before is untouched and anything you paint yourself later is safe.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

--==========================================================================
local Z_START = 20
local CHAMBER_D = 200
local CHAMBERS = 9

local Terrain = workspace.Terrain
local ServerStorage = game:GetService("ServerStorage")

print("")
print("========================== CLEAN SLATE =======================")

--==========================================================================
-- 1. THE SAND
--==========================================================================
do
	--[[
		The whole castle plus a wide apron, in slices.

		ReplaceMaterial works on a Region3 and the castle is 300 x 1800 studs,
		which is a large volume to hand the engine in one call. Slicing it keeps
		each call small and lets Studio breathe between them.

		Resolution 4 is the terrain grid: anything coarser skips voxels and
		leaves sand behind in stripes.
	]]
	local slices = 0
	local zTop = Z_START + 200
	local zBottom = Z_START - CHAMBERS * CHAMBER_D - 200

	for z = zBottom, zTop, 200 do
		local region = Region3.new(Vector3.new(-400, -30, z), Vector3.new(400, 40, math.min(z + 200, zTop)))
		region = region:ExpandToGrid(4)
		Terrain:ReplaceMaterial(region, 4, Enum.Material.Sand, Enum.Material.Ground)
		slices += 1
		task.wait()
	end

	print(("  repainted %d slices of terrain: Sand -> Ground"):format(slices))
end

--==========================================================================
-- 2. THE FENCES AND THE PARTS ROADS
--==========================================================================
local removed = 0

local gameplay = workspace:FindFirstChild("Gameplay")
local battleground = gameplay and gameplay:FindFirstChild("Battleground")

if battleground then
	for _, name in { "RoadFences", "Path" } do
		local folder = battleground:FindFirstChild(name)
		while folder do
			removed += #folder:GetDescendants()
			folder:Destroy()
			print(("  removed Battleground.%s"):format(name))
			folder = battleground:FindFirstChild(name)
		end
	end
end

--[[
	Anything of mine that ended up loose in the Workspace. Matched by NAME and
	only by names this project's tools invent — nothing a person would call a
	part of their own build.
]]
local MINE = {
	NoEntry = true,
	RoadFences = true,
}

for _, d in ipairs(workspace:GetDescendants()) do
	if MINE[d.Name] then
		removed += 1
		d:Destroy()
	end
end

print(("  removed %d instances of road and fence"):format(removed))

--==========================================================================
-- 3. THE ARCHIVE
--==========================================================================
do
	local archive = ServerStorage:FindFirstChild("OldPaths")
	if archive then
		local n = #archive:GetDescendants()
		archive:Destroy()
		print(("  emptied ServerStorage.OldPaths (%d instances)"):format(n))
	end
end

--==========================================================================
-- 4. WHAT IS LEFT
--==========================================================================
print("")
print("--- WHAT SURVIVED -------------------------------------------")
if battleground then
	for _, child in ipairs(battleground:GetChildren()) do
		print(("  %-22s %d parts"):format(child.Name, #child:GetDescendants()))
	end
end

local fences = 0
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Model") and string.find(string.lower(d.Name), "fence") then
		fences += 1
		print(("  fence: %s"):format(d:GetFullName()))
	end
end
print(("  %d fence model(s) still in the Workspace"):format(fences))

print("")
print("  The ground is ground. The castle, the buildings and everything")
print("  placed by hand are untouched.")
print("=========================== END ==============================")
