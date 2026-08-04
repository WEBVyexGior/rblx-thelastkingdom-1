--!strict
--[[
	ArrivalService
	Guarantees there is somewhere to arrive.

	--------------------------------------------------------------------------
	WHY THIS IS CODE AND NOT A PART

	The castle's arrival pad had a SpawnLocation in it. At some point it stopped
	having one — deleted by hand while decorating, most likely, which is easy
	because the thing is invisible and does not collide. Roblox's fallback for a
	place with no SpawnLocation is to drop the character near the world origin,
	and the world origin of this map is the middle of the gatehouse arch. The
	player spawned standing on top of the gate, every time, with nothing in the
	log to say why.

	A part that must exist, must not be deletable. So the pad's spawn is created
	at boot from the pad's own geometry: delete it, move it, never build it —
	the game puts it back where the design says it goes.

	It also SWEEPS the landing box and names anything solid standing in it,
	because "the player spawns inside something" took a playtest and two wrong
	guesses to diagnose the first time, and should take one line of log the next.

	Place: Forgotten Lands ONLY (Server/World). Runs in Init, because
	DeathService owns spawning and starts handing out characters in Start.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local ArrivalService = {}

ArrivalService.Name = "ArrivalService"

local log = Logger.new("ArrivalService")

-- Where the pad is, if the map has not been built at all. Same arithmetic as
-- tools/BuildBattleground: Z_START (20) minus 55.
local FALLBACK = Vector3.new(0, 2.5, -35)

local SPAWN_NAME = "ArrivalSpawn"
local SPAWN_SIZE = Vector3.new(24, 1, 24)

-- The room a character needs: it is about 5 studs tall and drops in from a
-- little above the pad.
local CLEAR_XZ = 12
local CLEAR_Y = 9

--==========================================================================
-- Same OBB-to-AABB projection as everywhere else in this project: Part.Size is
-- measured along the PART's axes, so a rotated part's world extent is the sum
-- of what each local axis contributes.
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

local function boxesOverlap(aMin: Vector3, aMax: Vector3, bMin: Vector3, bMax: Vector3): boolean
	return aMin.X < bMax.X
		and aMax.X > bMin.X
		and aMin.Y < bMax.Y
		and aMax.Y > bMin.Y
		and aMin.Z < bMax.Z
		and aMax.Z > bMin.Z
end

--==========================================================================
-- Reads the arrival point off the pad itself, so moving the pad in Studio moves
-- the spawn with it and nothing has to be edited here.
local function arrivalPoint(battleground: Instance?): (Vector3, Instance?)
	local padModel = battleground and battleground:FindFirstChild("SpawnPad")
	local pad = padModel and padModel:FindFirstChild("Pad")
	if pad and pad:IsA("BasePart") then
		local top = pad.Position.Y + pad.Size.Y / 2
		return Vector3.new(pad.Position.X, top + 0.5, pad.Position.Z), padModel
	end
	return FALLBACK, padModel or battleground
end

--==========================================================================
local function sweep(centre: Vector3, ignore: Instance)
	local root = Workspace:FindFirstChild("Gameplay")
	if not root then
		return
	end

	local lo = Vector3.new(centre.X - CLEAR_XZ, centre.Y - 0.4, centre.Z - CLEAR_XZ)
	local hi = Vector3.new(centre.X + CLEAR_XZ, centre.Y + CLEAR_Y, centre.Z + CLEAR_XZ)

	local found = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d ~= ignore and d.CanCollide then
			local a, b = worldSpan(d)
			if boxesOverlap(a, b, lo, hi) then
				found += 1
				if found <= 6 then
					log:warn(("something solid is in the landing box: %s"):format(d:GetFullName()))
				end
			end
		end
	end

	if found > 0 then
		log:warn(("%d part(s) where the player lands — they will spawn on top of one"):format(found))
	end
end

--==========================================================================
--[[
	NO PLACE-ROLE CHECK HERE, and that is deliberate.

	The first version asked `GameService.getPlaceRole()` and returned early. The
	Loader runs Init on every module in ALPHABETICAL order, so ArrivalService
	asked before GameService had answered, got "Unknown", and quietly did
	nothing — which is why the log had no line from this service at all and the
	player carried on spawning inside the gatehouse.

	It does not need the check anyway: `Server/World` only syncs into the
	Forgotten Lands project, so this file existing IS the place check.
]]
function ArrivalService.Init()
	local gameplay = Workspace:FindFirstChild("Gameplay")
	local battleground = gameplay and gameplay:FindFirstChild("Battleground")

	local at, parent = arrivalPoint(battleground)

	--[[
		Exactly one spawn, and it is this one. A second SpawnLocation anywhere in
		the map makes arrival a coin toss, and a coin toss is the hardest kind of
		bug to be told about — "sometimes I spawn in the wrong place" is where
		this started.
	]]
	local existing = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	while existing do
		if existing.Name ~= SPAWN_NAME then
			log:warn(("removing a stray SpawnLocation: %s"):format(existing:GetFullName()))
		end
		existing:Destroy()
		existing = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = SPAWN_NAME
	spawn.Anchored = true
	spawn.Size = SPAWN_SIZE
	spawn.Position = at
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.CanTouch = false
	spawn.Neutral = true
	spawn.Duration = 0 -- no forcefield: this is a survival map, not a lobby
	spawn.Parent = parent or Workspace

	Players.RespawnTime = 0.5

	log:info(("arrival point at %.0f, %.0f, %.0f"):format(at.X, at.Y, at.Z))
	if at == FALLBACK and not battleground then
		log:warn("no Battleground found — using the design's default arrival point")
	end

	sweep(at, spawn)
end

function ArrivalService.Start() end

return ArrivalService
