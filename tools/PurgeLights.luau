--[[
	PurgeLights — run in the Studio Command Bar of the FORGOTTEN LANDS place,
	in EDIT MODE. Select the whole file (Ctrl+A), copy, paste, Enter.

	Strips every light and every torch out of the generated castle, so the
	lighting can be done by hand from a clean slate.

	It removes:
	  - every PointLight / SpotLight / SurfaceLight anywhere under Gameplay
	  - every model named Torch, including the replacements
	  - every Flame model and any leftover neon "Fire" balls
	  - anything else still using Neon, which is only ever fire in this build

	It does NOT touch Lighting itself — ClockTime, Atmosphere and the colour
	grade stay as they are. Set BLANK_ATMOSPHERE below if you want those reset
	as well.

	Safe to re-run.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

local BLANK_ATMOSPHERE = false

local ground = workspace:FindFirstChild("Gameplay")
if not ground then
	warn("[Purge] no Workspace.Gameplay — nothing to clean.")
	return
end

local lights, torches, flames, neon = 0, 0, 0, 0

--==========================================================================
-- Torches and flames go whole, so nothing is left standing in the wall
--==========================================================================
-- Collected first: destroying while walking GetDescendants would skip entries.
local doomed = {}
for _, descendant in ipairs(ground:GetDescendants()) do
	if descendant:IsA("Model") and (descendant.Name == "Torch" or descendant.Name == "Flame" or descendant.Name == "Brazier") then
		table.insert(doomed, descendant)
	end
end
for _, model in ipairs(doomed) do
	if model.Name == "Flame" then
		flames += 1
	else
		torches += 1
	end
	model:Destroy()
end

--==========================================================================
-- Then anything that still glows
--==========================================================================
for _, descendant in ipairs(ground:GetDescendants()) do
	if descendant:IsA("Light") then
		descendant:Destroy()
		lights += 1
	end
end

for _, descendant in ipairs(ground:GetDescendants()) do
	-- Neon is only ever fire or a gameplay marker in this build; the markers are
	-- handled separately below, so anything left is a stray ember.
	if descendant:IsA("BasePart") and descendant.Material == Enum.Material.Neon then
		local isMarker = descendant.Parent
			and (descendant.Parent.Name == "Spawns" or descendant.Parent.Name == "Objectives" or descendant.Name == "Checkpoint" or descendant.Name == "Storyteller")
		if not isMarker then
			descendant:Destroy()
			neon += 1
		end
	end
end

--==========================================================================
-- The gameplay markers stay, but stop being visible
--==========================================================================
--[[
	They are guides, not scenery: the wave and objective systems find them by
	name. Deleting them would break the map; leaving them lit would put glowing
	cubes in the middle of every fight. Invisible is the only correct answer.
]]
local hidden = 0
for _, descendant in ipairs(ground:GetDescendants()) do
	if descendant:IsA("BasePart") then
		local parentName = descendant.Parent and descendant.Parent.Name or ""
		if parentName == "Spawns" or parentName == "Objectives" or descendant.Name == "Checkpoint" or descendant.Name == "Storyteller" then
			descendant.Transparency = 1
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			hidden += 1
		end
	end
end

if BLANK_ATMOSPHERE then
	local Lighting = game:GetService("Lighting")
	for _, name in { "Atmosphere", "Sky", "ColorCorrectionEffect", "BloomEffect" } do
		local item = Lighting:FindFirstChildOfClass(name)
		if item then
			item:Destroy()
		end
	end
	print("[Purge] Lighting effects cleared as well.")
end

--==========================================================================
print(("[Purge] removed %d torch(es), %d flame(s), %d light(s), %d stray neon part(s)."):format(torches, flames, lights, neon))
print(("[Purge] hid %d gameplay marker(s) — they are still there, and still read by name."):format(hidden))
print("[Purge] The castle is dark. Light it however you like.")
