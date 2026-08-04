--[[
	SurveyArea2 — run in the Studio Command Bar of the FORGOTTEN LANDS place,
	in EDIT MODE. Select all, copy, paste, Enter. It CHANGES NOTHING except one
	thing it can be told to delete (see REMOVE_MY_STABLES below).

	--------------------------------------------------------------------------
	WHY THIS EXISTS

	I placed a stable range in area 2 by computing where the road ought to be
	from the numbers in BuildChambers, and it landed on the road. The model was
	right and the place is what it is — somebody has moved things, rebuilt
	things, and added things by hand since, which is exactly what a place is
	FOR.

	So: no more computing where anything ought to be. This reads the actual
	parts and reports where the road actually runs, chamber by chamber slice,
	and what is standing in area 2 right now.

	Send me the output and I will place the winch and the search points against
	real numbers.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

--==========================================================================
-- Set this true ONCE to delete the stable range I built. It only ever removes
-- `Decorations.Area2_Stables` and nothing else.
local REMOVE_MY_STABLES = true

--==========================================================================
local Z_START = 20
local CHAMBER_D = 200
local AREA = 2
local Z_NEAR = Z_START - (AREA - 1) * CHAMBER_D -- -180
local Z_FAR = Z_NEAR - CHAMBER_D -- -380

local SLICES = 10 -- how many z bands to report the road in

--==========================================================================
local function line(s: string)
	print(s)
end

-- Part.Size is measured along the PART's own axes; a rotated part's world
-- extent is the sum of what each local axis contributes.
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

line("")
line("========================= AREA 2 SURVEY ======================")
line(("  chamber 2 runs z %d .. %d,  x -150 .. 150"):format(Z_FAR, Z_NEAR))
line("")

--==========================================================================
if REMOVE_MY_STABLES then
	local decor = battleground:FindFirstChild("Decorations")
	local mine = decor and decor:FindFirstChild("Area2_Stables")
	if mine then
		local n = #mine:GetDescendants()
		mine:Destroy()
		line(("  REMOVED my stable range (%d instances)."):format(n))
	else
		line("  (my stable range is not in this place — nothing to remove)")
	end
	line("")
end

--==========================================================================
-- WHERE THE ROAD ACTUALLY IS
--==========================================================================
line("--- THE ROAD, MEASURED ---------------------------------------")

local pathFolder = battleground:FindFirstChild("Path")
if not pathFolder then
	line("  no Battleground.Path — the road has not been built, or was renamed.")
else
	local step = (Z_NEAR - Z_FAR) / SLICES
	local anyFound = false

	for i = 0, SLICES - 1 do
		local zHi = Z_NEAR - i * step
		local zLo = zHi - step
		local minX, maxX = math.huge, -math.huge
		local count = 0

		for _, d in ipairs(pathFolder:GetDescendants()) do
			if d:IsA("BasePart") then
				local a, b = span(d)
				-- Any part whose z range touches this slice.
				if a.Z < zHi and b.Z > zLo then
					minX = math.min(minX, a.X)
					maxX = math.max(maxX, b.X)
					count += 1
				end
			end
		end

		if count > 0 then
			anyFound = true
			line(("  z %6.0f..%-7.0f  road spans x %7.1f .. %-7.1f  (%d parts)"):format(
				zHi, zLo, minX, maxX, count
			))
		else
			line(("  z %6.0f..%-7.0f  no road parts"):format(zHi, zLo))
		end
	end

	if not anyFound then
		line("  the Path folder exists but has nothing inside this chamber.")
	end
end

--==========================================================================
-- YOUR STABLE
--==========================================================================
line("")
line("--- YOUR HORSE STABLE ----------------------------------------")
do
	local found: Instance? = nil
	for _, d in ipairs(workspace:GetDescendants()) do
		if (d:IsA("Model") or d:IsA("Folder")) and string.find(string.lower(d.Name), "stable") then
			found = d
			break
		end
	end

	if not found then
		line("  no model with 'stable' in its name anywhere in the Workspace.")
	elseif found:IsA("Model") then
		local ok, cf, size = pcall(function()
			local c, s = (found :: Model):GetBoundingBox()
			return c, s
		end)
		if ok and cf then
			local p = cf.Position
			line(("  %s"):format(found:GetFullName()))
			line(("  centre  x %.0f  y %.0f  z %.0f"):format(p.X, p.Y, p.Z))
			line(("  size    %.0f x %.0f x %.0f"):format(size.X, size.Y, size.Z))
			line(("  x range %.0f .. %.0f"):format(p.X - size.X / 2, p.X + size.X / 2))
			line(("  z range %.0f .. %.0f"):format(p.Z - size.Z / 2, p.Z + size.Z / 2))
			if p.Z > Z_NEAR or p.Z < Z_FAR then
				line("  NOTE: its centre is OUTSIDE chamber 2. Move it in first.")
			end
			line(("  parts   %d"):format(#found:GetDescendants()))
		else
			line("  found it, but could not measure it: " .. found:GetFullName())
		end
	else
		line(("  found a folder, not a model: %s"):format(found:GetFullName()))
	end
end

--==========================================================================
-- WHAT ELSE IS IN THE CHAMBER
--==========================================================================
line("")
line("--- WHAT IS STANDING IN AREA 2 -------------------------------")
do
	local groups: { [string]: { n: number, minX: number, maxX: number, minZ: number, maxZ: number } } = {}

	-- `pathFolder or workspace` would make EVERY part a descendant and report
	-- nothing at all, so the road is skipped only when there is a road to skip.
	local function isRoad(d: Instance): boolean
		return pathFolder ~= nil and d:IsDescendantOf(pathFolder)
	end

	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and not isRoad(d) then
			local a, b = span(d)
			local cz = (a.Z + b.Z) / 2
			if cz <= Z_NEAR and cz >= Z_FAR and math.abs(d.Position.X) <= 150 then
				-- Roll up to the nearest interesting ancestor, so a 900-part
				-- model is one line and not 900.
				local owner: Instance = d
				local hops = 0
				while owner.Parent and owner.Parent ~= workspace and hops < 3 do
					owner = owner.Parent
					hops += 1
				end
				local key = owner:GetFullName()
				local g = groups[key]
				if not g then
					g = { n = 0, minX = math.huge, maxX = -math.huge, minZ = math.huge, maxZ = -math.huge }
					groups[key] = g
				end
				g.n += 1
				g.minX = math.min(g.minX, a.X)
				g.maxX = math.max(g.maxX, b.X)
				g.minZ = math.min(g.minZ, a.Z)
				g.maxZ = math.max(g.maxZ, b.Z)
			end
		end
	end

	local rows = {}
	for key, g in pairs(groups) do
		table.insert(rows, { key = key, g = g })
	end
	table.sort(rows, function(a, b)
		return a.g.n > b.g.n
	end)

	if #rows == 0 then
		line("  nothing but the shell.")
	end
	for i, row in ipairs(rows) do
		if i > 14 then
			line(("  ... and %d more"):format(#rows - 14))
			break
		end
		line(("  %5d parts   x %6.0f..%-6.0f  z %6.0f..%-6.0f   %s"):format(
			row.g.n, row.g.minX, row.g.maxX, row.g.minZ, row.g.maxZ, row.key
		))
	end
end

--==========================================================================
line("")
line("--- FIXED POINTS ---------------------------------------------")
line(("  passage out of area 2 is at x -115, z %d  (west side)"):format(Z_FAR))
line(("  enemy spawns:  x 0 z %d   x 110 z %d   x -110 z %d"):format(Z_FAR + 30, Z_NEAR - 100, Z_NEAR - 100))
line("  side towers stand on the wall line; their inner faces reach x +/-128")
line("")
line("=========================== END ==============================")
