--[[
	BuildCastle — run in the Studio Command Bar of the FORGOTTEN LANDS place,
	in EDIT MODE. Select the whole file (Ctrl+A), copy, paste, Enter.

	Builds the fallen kingdom's castle at the end of the road: a plinth of rock,
	a curtain wall with round corner towers, a gatehouse, and a keep behind it —
	all of it broken.

	It is built to be seen from two thousand studs away, so it is deliberately
	oversized and simple. Silhouette is the only thing that reads at that
	distance: a shape you can recognise on the horizon and walk towards for an
	hour. Detail added now would be invisible where it matters and expensive
	where it does not.

	The ruin is not decoration. Gaps in the wall, a leaning tower and a keep with
	its corner torn away are what tell the player, from the first minute and
	without a word, that they are already too late.

	Everything lands in `Workspace.Gameplay.Area5_Castle.Structure`. Re-running
	replaces only that folder — anything you add elsewhere is untouched. Edit
	whatever you like afterwards; from that point it is yours.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

--==========================================================================
-- Tune these
--==========================================================================
local CENTRE = Vector3.new(0, 0, -1900) -- where the castle stands
local GROUND_Y = 0

local PLINTH = 520 -- rock the castle sits on
local PLINTH_H = 26
local COURT = 420 -- outer wall, side to side
local WALL_T = 14
local WALL_H = 58
local TOWER_R = 26
local TOWER_H = 92
local GATE_W = 52 -- opening in the front wall
local KEEP = Vector3.new(150, 190, 120)

local STONE = Color3.fromRGB(78, 76, 74)
local STONE_DARK = Color3.fromRGB(58, 57, 58)
local ROCK = Color3.fromRGB(84, 78, 72)

--==========================================================================
local area = workspace:FindFirstChild("Gameplay") and workspace.Gameplay:FindFirstChild("Area5_Castle")
if not area then
	area = Instance.new("Folder")
	area.Name = "Area5_Castle"
	local root = workspace:FindFirstChild("Gameplay")
	if not root then
		root = Instance.new("Folder")
		root.Name = "Gameplay"
		root.Parent = workspace
	end
	area.Parent = root
end

local old = area:FindFirstChild("Structure")
if old then
	old:Destroy()
end
local root = Instance.new("Model")
root.Name = "Structure"
root.Parent = area

local made = 0

-- Small parts (crenellations, rubble) do not cast shadows: there are hundreds
-- of them, they are seen from a mile away, and shadows are the most expensive
-- thing about a build this size.
local function block(name: string, size: Vector3, cf: CFrame, colour: Color3, shadow: boolean?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.Color = colour
	part.Material = Enum.Material.Slate
	part.CastShadow = shadow ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = root
	made += 1
	return part
end

local function cylinder(name: string, radius: number, height: number, at: Vector3, colour: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	-- A cylinder part points along X, so it has to be stood upright.
	part.Size = Vector3.new(height, radius * 2, radius * 2)
	part.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	part.Color = colour
	part.Material = Enum.Material.Slate
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = root
	made += 1
	return part
end

local rng = Random.new(1453) -- the year Constantinople fell; as good a seed as any

--==========================================================================
-- The rock it stands on
--==========================================================================
block(
	"Plinth",
	Vector3.new(PLINTH, PLINTH_H, PLINTH),
	CFrame.new(CENTRE + Vector3.new(0, GROUND_Y + PLINTH_H / 2, 0)),
	ROCK
)
local baseY = GROUND_Y + PLINTH_H

--==========================================================================
-- Curtain wall — built in segments so it can be broken
--==========================================================================
local half = COURT / 2

-- `gap` is where the wall is missing entirely; `low` is where it has crumbled
-- to half height. Neither is random: a wall that is evenly ruined everywhere
-- reads as texture, while a wall with two obvious breaches reads as a siege.
local function runWall(name: string, from: Vector3, to: Vector3, gaps: { { number } })
	local span = (to - from)
	local length = span.Magnitude
	local direction = span.Unit
	local segments = math.floor(length / 20)

	for i = 0, segments - 1 do
		local t0 = i / segments
		local skip = false
		local height = WALL_H
		for _, range in gaps do
			if t0 >= range[1] and t0 < range[2] then
				if range[3] == 0 then
					skip = true
				else
					height = WALL_H * range[3]
				end
			end
		end
		if not skip then
			local at = from + direction * (length * (t0 + 0.5 / segments))
			local size = if math.abs(direction.X) > 0.5
				then Vector3.new(length / segments + 0.5, height, WALL_T)
				else Vector3.new(WALL_T, height, length / segments + 0.5)
			block(name, size, CFrame.new(Vector3.new(at.X, baseY + height / 2, at.Z)), STONE)

			-- Crenellations, but only on the stretches still standing tall.
			if height > WALL_H * 0.8 then
				for c = -1, 1 do
					local step = (length / segments) / 3
					local offset = direction * (c * step)
					block(
						"Merlon",
						Vector3.new(if math.abs(direction.X) > 0.5 then 6 else WALL_T, 7, if math.abs(direction.X) > 0.5 then WALL_T else 6),
						CFrame.new(Vector3.new(at.X + offset.X, baseY + height + 3.5, at.Z + offset.Z)),
						STONE_DARK,
						false
					)
				end
			end
		end
	end
end

local nearZ = CENTRE.Z + half -- the side the player approaches from
local farZ = CENTRE.Z - half
local leftX = CENTRE.X - half
local rightX = CENTRE.X + half

-- Front wall, split either side of the gate.
local gateHalf = GATE_W / 2
runWall("WallFront", Vector3.new(leftX, 0, nearZ), Vector3.new(CENTRE.X - gateHalf, 0, nearZ), { { 0.55, 0.8, 0.45 } })
runWall("WallFront", Vector3.new(CENTRE.X + gateHalf, 0, nearZ), Vector3.new(rightX, 0, nearZ), {})

-- Left wall: breached in the middle. Something came through here.
runWall("WallLeft", Vector3.new(leftX, 0, nearZ), Vector3.new(leftX, 0, farZ), { { 0.38, 0.56, 0 }, { 0.56, 0.7, 0.4 } })

runWall("WallRight", Vector3.new(rightX, 0, nearZ), Vector3.new(rightX, 0, farZ), { { 0.7, 0.82, 0.5 } })
runWall("WallBack", Vector3.new(leftX, 0, farZ), Vector3.new(rightX, 0, farZ), { { 0.2, 0.34, 0.6 } })

--==========================================================================
-- Towers
--==========================================================================
local function tower(name: string, at: Vector3, height: number, lean: number?)
	local body = cylinder(name, TOWER_R, height, Vector3.new(at.X, baseY + height / 2, at.Z), STONE)
	if lean and lean > 0 then
		-- One tower leans. A perfectly upright ruin is not a ruin.
		body.CFrame = CFrame.new(body.Position) * CFrame.Angles(math.rad(lean), 0, math.rad(lean * 0.6)) * CFrame.Angles(0, 0, math.rad(90))
	end

	-- A ring of merlons around the top.
	local crown = baseY + height + 3
	for step = 0, 11 do
		local angle = (math.pi * 2 / 12) * step
		block(
			"Merlon",
			Vector3.new(9, 8, 9),
			CFrame.new(at.X + math.cos(angle) * (TOWER_R - 4), crown, at.Z + math.sin(angle) * (TOWER_R - 4))
				* CFrame.Angles(0, -angle, 0),
			STONE_DARK,
			false
		)
	end
end

tower("TowerNW", Vector3.new(leftX, 0, farZ), TOWER_H)
tower("TowerNE", Vector3.new(rightX, 0, farZ), TOWER_H * 0.72) -- this one fell
tower("TowerSW", Vector3.new(leftX, 0, nearZ), TOWER_H, 4) -- and this one leans
tower("TowerSE", Vector3.new(rightX, 0, nearZ), TOWER_H)

-- Gatehouse: two heavier towers either side of the way in.
tower("GateTowerW", Vector3.new(CENTRE.X - gateHalf - TOWER_R * 0.6, 0, nearZ), TOWER_H * 1.15)
tower("GateTowerE", Vector3.new(CENTRE.X + gateHalf + TOWER_R * 0.6, 0, nearZ), TOWER_H * 1.15)

-- The lintel over the gate, so the opening reads as a doorway and not a hole.
block(
	"GateLintel",
	Vector3.new(GATE_W + 20, 16, WALL_T + 6),
	CFrame.new(CENTRE.X, baseY + 46, nearZ),
	STONE_DARK
)

--==========================================================================
-- The keep
--==========================================================================
local keepZ = CENTRE.Z - COURT * 0.18
block(
	"Keep",
	KEEP,
	CFrame.new(CENTRE.X, baseY + KEEP.Y / 2, keepZ),
	STONE
)

-- Its top corner is gone: the highest point of the kingdom, broken.
block(
	"KeepBreak",
	Vector3.new(KEEP.X * 0.45, KEEP.Y * 0.22, KEEP.Z * 0.5),
	CFrame.new(CENTRE.X + KEEP.X * 0.28, baseY + KEEP.Y - KEEP.Y * 0.09, keepZ + KEEP.Z * 0.24)
		* CFrame.Angles(0, 0, math.rad(6)),
	STONE_DARK
)

for step = 0, 7 do
	local angle = (math.pi * 2 / 8) * step
	block(
		"KeepMerlon",
		Vector3.new(14, 10, 14),
		CFrame.new(
			CENTRE.X + math.cos(angle) * (KEEP.X / 2 - 8),
			baseY + KEEP.Y + 5,
			keepZ + math.sin(angle) * (KEEP.Z / 2 - 8)
		),
		STONE_DARK,
		false
	)
end

--==========================================================================
-- Rubble at the breach
--==========================================================================
for i = 1, 26 do
	local spread = rng:NextNumber(0, 90)
	local angle = rng:NextNumber() * math.pi * 2
	local size = rng:NextNumber(6, 18)
	block(
		"Rubble",
		Vector3.new(size, size * rng:NextNumber(0.4, 0.9), size * rng:NextNumber(0.6, 1.2)),
		CFrame.new(leftX + math.cos(angle) * spread * 0.5, baseY + size / 3, CENTRE.Z + math.sin(angle) * spread)
			* CFrame.Angles(rng:NextNumber(0, 0.4), rng:NextNumber(0, 6), rng:NextNumber(0, 0.4)),
		ROCK,
		false
	)
end

--==========================================================================
root.PrimaryPart = root:FindFirstChild("Keep")

-- Streaming culls distant parts, and this is meant to be seen from the far end
-- of the map. Persistent keeps it on the horizon from the first frame.
pcall(function()
	root.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
end)

print(("[Castle] built %d parts at %s"):format(made, tostring(CENTRE)))
print("[Castle] Keep top reaches y=" .. tostring(math.floor(baseY + KEEP.Y)))
print("[Castle] It lives in Gameplay.Area5_Castle.Structure — edit freely, or re-run to replace it.")
