--[[
	SurveyWorld — run in the Studio Command Bar of the FORGOTTEN LANDS place.
	Select the whole file (Ctrl+A), copy, paste, Enter. It changes NOTHING.

	Reports what is in the world and where, in a form small enough to read.

	A full dump of every part would be tens of thousands of lines and useless.
	What is actually needed to design into a space is: how big each room is, how
	much of it is free, where the way out of it is, how high the ground sits, and
	what has already been put there by hand. That is what this prints.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

local function line(s: string)
	print(s)
end

local function fmt(v: Vector3): string
	return ("%d, %d, %d"):format(v.X, v.Y, v.Z)
end

--==========================================================================
-- Bounds of anything, ignoring the markers (which are not scenery)
--==========================================================================
local function boundsOf(node: Instance)
	local minV, maxV
	local count = 0
	for _, d in ipairs(node:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			count += 1
			local half = d.Size / 2
			local p = d.Position
			local lo = p - half
			local hi = p + half
			if not minV then
				minV, maxV = lo, hi
			else
				minV = Vector3.new(math.min(minV.X, lo.X), math.min(minV.Y, lo.Y), math.min(minV.Z, lo.Z))
				maxV = Vector3.new(math.max(maxV.X, hi.X), math.max(maxV.Y, hi.Y), math.max(maxV.Z, hi.Z))
			end
		end
	end
	return minV, maxV, count
end

local function countParts(node: Instance): number
	local n = 0
	for _, d in ipairs(node:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

--==========================================================================
line("")
line("========================= WORLD SURVEY =========================")

local gameplay = workspace:FindFirstChild("Gameplay")
if not gameplay then
	warn("No Workspace.Gameplay. Nothing built yet?")
	return
end

--==========================================================================
-- 1. The tree, two levels deep, with weights
--==========================================================================
line("")
line("--- STRUCTURE ---------------------------------------------------")
for _, area in ipairs(gameplay:GetChildren()) do
	line(("%s (%s) — %d parts"):format(area.Name, area.ClassName, countParts(area)))
	for _, child in ipairs(area:GetChildren()) do
		local n = countParts(child)
		local extra = ""
		if child:IsA("Folder") and n == 0 then
			extra = (" [%d children, no parts]"):format(#child:GetChildren())
		end
		line(("    %s (%s) — %d parts%s"):format(child.Name, child.ClassName, n, extra))
	end
end

--==========================================================================
-- 2. Chambers: how big, how free, and where the way out is
--==========================================================================
local battleground = gameplay:FindFirstChild("Battleground")
if battleground then
	line("")
	line("--- CHAMBERS ----------------------------------------------------")
	line("index | z range          | structure bounds x / y      | passage")

	for i = 1, 20 do
		local node = battleground:FindFirstChild(("Chamber%d"):format(i))
		if not node then
			break
		end

		local structure = node:FindFirstChild("Structure")
		local minV, maxV = nil, nil
		if structure then
			minV, maxV = boundsOf(structure)
		end

		-- The gap in this chamber's far wall, found from the arch that frames it.
		local passageX, passageZ = nil, nil
		if structure then
			local passage = structure:FindFirstChild("Passage")
			if passage then
				local pmin, pmax = boundsOf(passage)
				if pmin and pmax then
					passageX = (pmin.X + pmax.X) / 2
					passageZ = (pmin.Z + pmax.Z) / 2
				end
			end
		end

		local zText = if minV then ("%6d .. %6d"):format(maxV.Z, minV.Z) else "     ?"
		local xyText = if minV then ("x %5d..%5d  y %3d..%3d"):format(minV.X, maxV.X, minV.Y, maxV.Y) else "?"
		local pText = if passageX then ("x %+5d  z %6d"):format(passageX, passageZ) else "none (last chamber?)"
		line(("  %2d  | %s | %s | %s"):format(i, zText, xyText, pText))
	end
end

--==========================================================================
-- 3. Markers, so the free space is known even when they are hidden
--==========================================================================
if battleground then
	line("")
	line("--- MARKERS (positions only; hidden or not) ---------------------")
	for i = 1, 20 do
		local node = battleground:FindFirstChild(("Chamber%d"):format(i))
		if not node then
			break
		end
		local bits = {}
		for _, folderName in { "Spawns", "Objectives" } do
			local f = node:FindFirstChild(folderName)
			if f then
				for _, m in ipairs(f:GetChildren()) do
					if m:IsA("BasePart") then
						table.insert(bits, ("%s.%s(%s)"):format(folderName, m.Name, fmt(m.Position)))
					end
				end
			end
		end
		for _, name in { "Checkpoint", "Storyteller" } do
			local m = node:FindFirstChild(name)
			if m and m:IsA("BasePart") then
				table.insert(bits, ("%s(%s)"):format(name, fmt(m.Position)))
			end
		end
		if #bits > 0 then
			line(("  Chamber%d: %s"):format(i, table.concat(bits, "  ")))
		end
	end
end

--==========================================================================
-- 4. Ground height, sampled down the whole map
--==========================================================================
line("")
line("--- GROUND (raycast down, ignoring everything built) -------------")
do
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { gameplay }

	local samples = {}
	for z = 300, -1900, -200 do
		local row = {}
		for _, x in { -120, 0, 120 } do
			local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -500, 0), params)
			table.insert(row, if hit then ("%s@%d"):format(tostring(math.floor(hit.Position.Y * 10) / 10), x) else ("NONE@%d"):format(x))
		end
		table.insert(samples, ("  z %+6d : %s"):format(z, table.concat(row, "  ")))
	end
	for _, s in ipairs(samples) do
		line(s)
	end
	line("  (NONE means no terrain there — a hole, or the moat)")
end

--==========================================================================
-- 5. What has been placed BY HAND
--==========================================================================
--[[
	Anything sitting directly in the Workspace, or inside a chamber but outside
	its Structure folder, was almost certainly put there by a person. Those are
	the things a generator has to design AROUND rather than on top of.
]]
line("")
line("--- HAND-PLACED ---------------------------------------------------")
local KNOWN = {
	Gameplay = true,
	Terrain = true,
	Camera = true,
	Baseplate = true,
	SpawnLocation = true,
}
local handful = 0
for _, child in ipairs(workspace:GetChildren()) do
	if not KNOWN[child.Name] and not child:IsA("Terrain") and not child:IsA("Camera") then
		local minV, maxV, parts = boundsOf(child)
		if minV then
			line(("  workspace.%s (%s) — %d parts, centre %s, size %s"):format(
				child.Name,
				child.ClassName,
				parts,
				fmt((minV + maxV) / 2),
				fmt(maxV - minV)
			))
		else
			line(("  workspace.%s (%s) — no visible parts"):format(child.Name, child.ClassName))
		end
		handful += 1
	end
end

if battleground then
	for i = 1, 20 do
		local node = battleground:FindFirstChild(("Chamber%d"):format(i))
		if not node then
			break
		end
		for _, child in ipairs(node:GetChildren()) do
			local skip = child.Name == "Structure"
				or child.Name == "Spawns"
				or child.Name == "Objectives"
				or child.Name == "Checkpoint"
				or child.Name == "Storyteller"
			if not skip then
				local minV, maxV, parts = boundsOf(child)
				line(("  Chamber%d.%s (%s) — %d parts%s"):format(
					i,
					child.Name,
					child.ClassName,
					parts,
					if minV then (", centre " .. fmt((minV + maxV) / 2)) else ""
				))
				handful += 1
			end
		end
	end
end

if handful == 0 then
	line("  (nothing outside the generated folders)")
end

--==========================================================================
-- 6. Totals
--==========================================================================
line("")
line("--- TOTALS --------------------------------------------------------")
line(("  parts under Gameplay : %d"):format(countParts(gameplay)))
line(("  parts in Workspace   : %d"):format(countParts(workspace)))
local gmin, gmax = boundsOf(gameplay)
if gmin then
	line(("  everything spans     : x %d..%d   y %d..%d   z %d..%d"):format(gmin.X, gmax.X, gmin.Y, gmax.Y, gmin.Z, gmax.Z))
end
line("")
line("=========================== END ================================")
