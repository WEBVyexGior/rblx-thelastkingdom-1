--[[
	FixArrival — run in the Studio Command Bar of the FORGOTTEN LANDS, in EDIT
	MODE. Select all, copy, paste, Enter.

	--------------------------------------------------------------------------
	WHAT IT FIXES

	The two gatehouse doors lie "off their hinges in the passage" — except they
	were placed 30 and 46 studs PAST the gate, which puts them flat across the
	arrival pad. The player spawns standing on a fallen door.

	This moves both doors back into the archway where they belong and leaves the
	pad clear. It also sweeps the spawn box afterwards and names anything else
	standing in it, because the doors are the cause I found and not necessarily
	the only one.

	SURGICAL ON PURPOSE. Re-running tools/BuildBattleground would fix this too
	and would destroy every decoration placed by hand since. This touches two
	parts and reads everything else.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

--==========================================================================
-- The gatehouse sits at z = Z_START; these are absolute world CFrames, taken
-- from the same arithmetic BuildBattleground now uses.
--==========================================================================
local Z_START = 20
local GATE = Vector3.new(0, 0, Z_START)

local DOORS = {
	{
		size = Vector3.new(30, 2.6, 40),
		cf = CFrame.new(GATE + Vector3.new(-18, 1.4, -12)) * CFrame.Angles(0, math.rad(14), 0),
	},
	{
		size = Vector3.new(22, 2.6, 30),
		cf = CFrame.new(GATE + Vector3.new(20, 1.4, -14)) * CFrame.Angles(0, math.rad(-24), 0),
	},
}

-- How much room the player needs to land in. The spawn part is 24 x 24; a
-- character is about 5 tall and arrives a couple of studs above the pad.
local CLEAR_XZ = 14
local CLEAR_Y = 9

--==========================================================================
local function line(s: string)
	print(s)
end

--[[
	Part.Size is measured along the PART's own axes. Projecting an oriented box
	onto the world axes means summing each local axis' contribution — the
	mistake this codebase has already made twice, once on a tower and once on a
	stair well.
]]
local function worldSpan(p: BasePart): (Vector3, Vector3)
	local cf, s = p.CFrame, p.Size
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local h = Vector3.new(
		math.abs(r.X) * s.X / 2 + math.abs(u.X) * s.Y / 2 + math.abs(l.X) * s.Z / 2,
		math.abs(r.Y) * s.X / 2 + math.abs(u.Y) * s.Y / 2 + math.abs(l.Y) * s.Z / 2,
		math.abs(r.Z) * s.X / 2 + math.abs(u.Z) * s.Y / 2 + math.abs(l.Z) * s.Z / 2
	)
	return p.Position - h, p.Position + h
end

local function overlaps(aMin: Vector3, aMax: Vector3, bMin: Vector3, bMax: Vector3): boolean
	return aMin.X < bMax.X
		and aMax.X > bMin.X
		and aMin.Y < bMax.Y
		and aMax.Y > bMin.Y
		and aMin.Z < bMax.Z
		and aMax.Z > bMin.Z
end

--==========================================================================
line("")
line("======================== FIX ARRIVAL =========================")

local gameplay = workspace:FindFirstChild("Gameplay")
local ground = gameplay and gameplay:FindFirstChild("Battleground")
local shell = ground and ground:FindFirstChild("Shell")
local gatehouse = shell and shell:FindFirstChild("Gatehouse")

if not gatehouse then
	line("  ABORT: Workspace.Gameplay.Battleground.Shell.Gatehouse not found.")
	line("  Nothing was changed.")
	return
end

--==========================================================================
-- Move the doors
--==========================================================================
local doors: { BasePart } = {}
for _, child in ipairs(gatehouse:GetChildren()) do
	if child:IsA("BasePart") and child.Name == "Door" then
		table.insert(doors, child)
	end
end

line(("  found %d door(s) in the gatehouse"):format(#doors))

if #doors ~= #DOORS then
	line(("  WARNING: expected %d. Moving what is there; check the rest by eye."):format(#DOORS))
end

-- Left to right, so the same door gets the same target on every run and this
-- tool is safe to run twice.
table.sort(doors, function(a, b)
	return a.Position.X < b.Position.X
end)

for i, door in ipairs(doors) do
	local target = DOORS[i]
	if target then
		local was = door.Position
		door.Size = target.size
		door.CFrame = target.cf
		line(("  moved Door %d  z %.0f -> %.0f"):format(i, was.Z, door.Position.Z))
	end
end

--==========================================================================
-- Prove the pad is clear
--==========================================================================
line("")
line("--- SPAWN BOX -----------------------------------------------")

local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
if not spawn then
	line("  no SpawnLocation in this place — cannot verify.")
	line("")
	line("=========================== END ==============================")
	return
end

local base = spawn.Position
line(("  spawn at %.0f, %.0f, %.0f"):format(base.X, base.Y, base.Z))

local boxMin = Vector3.new(base.X - CLEAR_XZ, base.Y - 0.5, base.Z - CLEAR_XZ)
local boxMax = Vector3.new(base.X + CLEAR_XZ, base.Y + CLEAR_Y, base.Z + CLEAR_XZ)

local blockers = 0
for _, d in ipairs(gameplay:GetDescendants()) do
	if d:IsA("BasePart") and d ~= spawn and d.CanCollide then
		local lo, hi = worldSpan(d)
		if overlaps(lo, hi, boxMin, boxMax) then
			blockers += 1
			if blockers <= 12 then
				line(("  IN THE WAY  %-14s  %s"):format(d.Name, d:GetFullName()))
			end
		end
	end
end

line("")
if blockers == 0 then
	line("  CLEAR. Nothing collidable stands where the player lands.")
else
	line(("  %d part(s) still in the spawn box — listed above."):format(blockers))
	line("  Anything named Pad or Lip is the floor and is fine.")
end

line("")
line("  Doors moved in THIS place only. tools/BuildBattleground carries the")
line("  same numbers now, so a future rebuild lands them in the right spot.")
line("")
line("=========================== END ==============================")
