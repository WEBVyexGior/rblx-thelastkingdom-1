--[[
	ScaffoldAreas — run in the Studio Command Bar of the FORGOTTEN LANDS place,
	in EDIT MODE. Select the whole file (Ctrl+A), copy, paste, Enter.

	Builds the skeleton the gameplay systems read:

		Workspace/Gameplay/
		  Area1_Outskirts/  Spawns/  Objectives/  Gate  Checkpoint
		  Area2_Village/    ...
		  Area3_Bridge/     ...
		  Area4_Courtyard/  ...
		  Area5_Castle/     ...

	The markers are the contract. Configs name them — "Area1_Outskirts.Spawns.North"
	— instead of carrying coordinates, so you can drag any of them anywhere and
	the game follows. Build the map AROUND them; never delete or rename one
	without changing the config that names it.

	Area 1's markers are placed to match the existing Chapter 1 mission, so it
	plays immediately. Areas 2-5 are laid out down the road for you to build into.

	Safe to re-run: it only replaces `Workspace.Gameplay`.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

local SPACING = 420 -- studs between one area and the next, along -Z
local GROUND = 3

local AREAS = {
	{ name = "Area1_Outskirts", z = 0 },
	{ name = "Area2_Village", z = -SPACING },
	{ name = "Area3_Bridge", z = -SPACING * 2 },
	{ name = "Area4_Courtyard", z = -SPACING * 3 },
	{ name = "Area5_Castle", z = -SPACING * 4 },
}

local GOLD = Color3.fromRGB(198, 158, 66)
local RED = Color3.fromRGB(178, 54, 54)
local GREEN = Color3.fromRGB(74, 132, 84)
local BORDEAUX = Color3.fromRGB(126, 30, 43)

--==========================================================================

local old = workspace:FindFirstChild("Gameplay")
if old then
	old:Destroy()
end

local root = Instance.new("Folder")
root.Name = "Gameplay"
root.Parent = workspace

local function marker(parent: Instance, name: string, position: Vector3, colour: Color3, size: Vector3?)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = colour
	part.Transparency = 0.55
	part.Size = size or Vector3.new(3, 3, 3)
	part.Position = position
	part.Parent = parent
	return part
end

local function folder(parent: Instance, name: string): Folder
	local item = Instance.new("Folder")
	item.Name = name
	item.Parent = parent
	return item
end

for index, area in ipairs(AREAS) do
	local node = folder(root, area.name)
	local spawns = folder(node, "Spawns")
	local objectives = folder(node, "Objectives")
	local z = area.z

	-- Three spawn points around the far edge of the area, so waves can arrive
	-- from more than one direction without any config change.
	marker(spawns, "North", Vector3.new(0, GROUND, z - 70), RED)
	marker(spawns, "East", Vector3.new(40, GROUND, z - 45), RED)
	marker(spawns, "West", Vector3.new(-40, GROUND, z - 45), RED)

	-- A landmark to walk to. Area 1's two match the Chapter 1 mission exactly.
	if index == 1 then
		marker(objectives, "SurvivorMarker", Vector3.new(0, GROUND, -30), GOLD)
		marker(objectives, "RuinedSite", Vector3.new(0, GROUND, -60), GOLD)
	else
		marker(objectives, "Landmark", Vector3.new(0, GROUND, z - 20), GOLD)
	end

	-- Where the party respawns into this area after a checkpoint.
	marker(node, "Checkpoint", Vector3.new(0, GROUND, z + 30), GREEN, Vector3.new(6, 1, 6))

	-- The way on, closed until the area is cleared. Sized as a doorway so it can
	-- be dropped straight into a wall you build.
	local gate = marker(node, "Gate", Vector3.new(0, GROUND + 8, z - 110), BORDEAUX, Vector3.new(28, 18, 2))
	gate.Transparency = 0.7

	print(("[Scaffold] %s at z=%d"):format(area.name, z))
end

print(("[Scaffold] DONE — %d areas in Workspace.Gameplay, %d studs apart."):format(#AREAS, SPACING))
print("Build the map around these markers. Drag them anywhere; the configs follow by name.")
