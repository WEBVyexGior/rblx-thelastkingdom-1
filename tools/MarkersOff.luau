--[[
	MarkersOff — run in the Studio Command Bar of the FORGOTTEN LANDS place,
	in EDIT MODE. Select the whole file (Ctrl+A), copy, paste, Enter.

	Gets the gameplay markers out of the way while you design: the enemy spawns,
	objective points, checkpoints and storyteller spots that BuildBattleground
	leaves behind.

	MODE, set below:

	  "hide"    invisible AND LOCKED. A locked part cannot be clicked in the
	            viewport, so it is exactly as out of the way as a deleted one —
	            except nothing is lost and the game still finds it. This is the
	            default, and the one worth using.

	  "stash"   moved into ServerStorage.StashedMarkers. Gone from the Workspace
	            entirely, still recoverable. Gameplay stops resolving them until
	            they come back.

	  "delete"  actually gone. The positions go with them, and getting them back
	            means re-running BuildBattleground, which would take your design
	            work with it.

	  "restore" puts a stash back, and unhides anything hidden.

	Configs point at these by name — `Battleground.Chamber1.Spawns.North` and so
	on — so with "stash" or "delete" you will see "cannot resolve position"
	warnings in a playtest until they are back. That is expected, not a fault.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

local MODE = "hide"

--==========================================================================
local ServerStorage = game:GetService("ServerStorage")

local root = workspace:FindFirstChild("Gameplay")
if not root and MODE ~= "restore" then
	warn("[Markers] no Workspace.Gameplay — nothing to do.")
	return
end

--[[
	What counts as a marker. Matched by NAME and by the folder it sits in, not by
	colour or material — a designer will recolour things, and a rule that depends
	on how something looks stops being true the moment somebody edits it.
]]
local MARKER_NAMES = { Checkpoint = true, Storyteller = true }
local MARKER_FOLDERS = { Spawns = true, Objectives = true }

local function isMarker(part: Instance): boolean
	if not part:IsA("BasePart") then
		return false
	end
	if MARKER_NAMES[part.Name] then
		return true
	end
	local parent = part.Parent
	return parent ~= nil and MARKER_FOLDERS[parent.Name] == true
end

--==========================================================================
if MODE == "restore" then
	local stash = ServerStorage:FindFirstChild("StashedMarkers")
	local returned = 0

	if stash then
		for _, entry in ipairs(stash:GetChildren()) do
			local path = entry:GetAttribute("OriginalParent")
			if path then
				-- Walk the saved path back down from Workspace.
				local node: Instance? = workspace
				for segment in string.gmatch(path, "[^%.]+") do
					if node then
						node = node:FindFirstChild(segment)
					end
				end
				if node then
					entry.Parent = node
					returned += 1
				else
					warn("[Markers] cannot restore " .. entry.Name .. ": " .. path .. " no longer exists")
				end
			end
		end
		if #stash:GetChildren() == 0 then
			stash:Destroy()
		end
	end

	local unhidden = 0
	if root then
		for _, descendant in ipairs(root:GetDescendants()) do
			if isMarker(descendant) then
				descendant.Locked = false
				descendant.Transparency = 0.6
				unhidden += 1
			end
		end
	end

	print(("[Markers] restored %d from the stash, unhid %d in place."):format(returned, unhidden))
	return
end

--==========================================================================
local found = {}
for _, descendant in ipairs(root:GetDescendants()) do
	if isMarker(descendant) then
		table.insert(found, descendant)
	end
end

if #found == 0 then
	print("[Markers] none found. Already dealt with?")
	return
end

if MODE == "hide" then
	for _, part in ipairs(found) do
		part.Transparency = 1
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Locked = true -- this is the part that stops it being clickable
	end
	print(("[Markers] hid and locked %d. They are invisible, unclickable, and still working."):format(#found))
	print("[Markers] Set MODE = \"restore\" and run again to bring them back.")
	return
end

if MODE == "stash" then
	local stash = ServerStorage:FindFirstChild("StashedMarkers")
	if not stash then
		stash = Instance.new("Folder")
		stash.Name = "StashedMarkers"
		stash.Parent = ServerStorage
	end

	for _, part in ipairs(found) do
		-- Remember exactly where it came from, so restoring is not guesswork.
		local path = {}
		local node: Instance? = part.Parent
		while node and node ~= workspace do
			table.insert(path, 1, node.Name)
			node = node.Parent
		end
		part:SetAttribute("OriginalParent", table.concat(path, "."))
		part.Parent = stash
	end

	print(("[Markers] stashed %d in ServerStorage.StashedMarkers."):format(#found))
	print("[Markers] Playtests will warn about unresolved positions until they are restored.")
	print("[Markers] Set MODE = \"restore\" and run again to put them back exactly where they were.")
	return
end

if MODE == "delete" then
	for _, part in ipairs(found) do
		part:Destroy()
	end
	warn(("[Markers] DELETED %d. Their positions are gone with them."):format(#found))
	warn("[Markers] Getting them back now means re-running BuildBattleground, which replaces the whole castle.")
	return
end

warn('[Markers] MODE must be "hide", "stash", "delete" or "restore".')
