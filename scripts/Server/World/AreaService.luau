--!strict
--[[
	AreaService
	The thing that turns nine decorated rooms into a run: it knows which chamber
	each player is standing in, it SHUTS the way forward until that chamber's
	work is done, and it tells the client enough to draw the corner of the
	screen.

	--------------------------------------------------------------------------
	WHY A GATE AND NOT A TELEPORT

	The alternative — sensing "objective complete" and warping the party on — is
	less code and much worse. A castle you are moved through is a corridor; a
	castle whose doors you open is a place. The gate also does the teaching for
	free: a player who walks into a shut portcullis, turns round, and finds the
	room still full of the dead has understood the rule without being told it.

	So every chamber gets a real portcullis in its existing arch, it starts
	down, and it grinds UP when the chamber is cleared. Nothing else moves.

	--------------------------------------------------------------------------
	WHAT COUNTS AS "CLEARED" IS NOT DECIDED HERE

	This service owns the gate and the HUD; it does not own the puzzle. Area 1's
	barricade, area 3's recipe and area 5's forge all finish by calling
	`AreaService.clear(index)`. Keeping the condition out of here is what lets
	nine different mechanics share one gate.

	--------------------------------------------------------------------------
	TESTING IT BEFORE THE MECHANICS EXIST

	Nothing calls `clear()` yet. To walk the castle in the meantime, Play, set
	the command bar to **Server**, and run:

		require(game.ServerScriptService.Server.World.AreaService).clear(1)

	or flip DEV_OPEN_ALL below to start a session with every gate up.

	Place: Forgotten Lands ONLY (Server/World). Phase: Areas.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Server = script.Parent.Parent
local GameService = require(Server.Services.GameService)
local Net = require(ReplicatedStorage.Shared.Net)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local AreaService = {}

AreaService.Name = "AreaService"

local log = Logger.new("AreaService")

-- Start a session with every gate already up. For walking the map while the
-- per-area mechanics are still being written; never true in a real build.
local DEV_OPEN_ALL = false

--==========================================================================
-- THE CASTLE'S NUMBERS
--
-- Every value below is copied from tools/BuildBattleground. The castle is
-- built by a tool and gated by a service, and the ONLY thing tying the two
-- together is that these agree — so they are grouped here, named the same, and
-- derived the same way rather than being re-measured by eye.
--
-- From the tool:
--     gapX  = HALF_W - GAP_W / 2 - 12        (odd chambers east, even west)
--     zFar  = Z_START - index * CHAMBER_D
--     voussoirs sweep a half-circle of radius GAP_W/2 from y = SPRING_Y
--     Span (the mass over the arch) sits at y = 55, 14 tall  ->  48 .. 62
--     terrain is filled to y = 0
--==========================================================================
local HALF_W = 150
local Z_START = 20
local CHAMBERS = 9
local CHAMBER_D = 200
local GAP_W = 46 -- the opening in each cross-wall
local GAP_INSET = 12 -- how far the opening sits in from the curtain
local WALL_T = 14

local FLOOR_Y = 0
local SPRING_Y = 26 -- where the arch starts curving
local SPAN_BOTTOM = 48 -- underside of the masonry over the arch

--==========================================================================
-- THE PORTCULLIS
--==========================================================================
local GRILLE_H = 30 -- floor to four studs into the arch
local TRAVEL = 26 -- lifted, its feet rest level with the springing
local LIFT_SECONDS = 3.2

local BARS = 11
local BAR_T = 1.6
local BAR_SPAN = GAP_W - 5 -- so the outer bars clear the jambs

local SPIKE_H = 2.4

--[[
	Where the chains hang from, and how far apart.

	Both numbers are dictated by the arch, not by taste. The voussoirs sweep a
	half-circle of radius 23 from y = SPRING_Y, so the void the chains fall
	through narrows fast: at x = 14 the stone is already down at y ~= 44, and a
	chain out there would run straight through the arch ring. At x = 8 the void
	reaches y ~= 47.6, which is where the masonry over the arch begins — so the
	chains disappear INTO stone rather than through it.
]]
local CHAIN_X = 8
local CHAIN_TOP = SPAN_BOTTOM + 4

-- The runners stop below the springing course. Above that the doorway is no
-- longer a rectangle, and a channel carried any higher clips the first
-- voussoir on each side.
local RUNNER_H = SPRING_Y - 3

-- How often a player's chamber is recomputed. Twenty times a second would be
-- free and pointless: a player crosses a 200-stud room in seconds, and the HUD
-- only changes when they pass a wall.
local POLL_SECONDS = 0.35

--==========================================================================
local PALETTE = {
	iron = Color3.fromRGB(56, 48, 44),
	ironDark = Color3.fromRGB(38, 33, 31),
	rust = Color3.fromRGB(92, 54, 34),
}

--[[
	The nine, in the order the player meets them. Labels are ENGLISH because
	they are shown in game; the Greek names live in the tools and the docs.
]]
local AREAS = {
	{ label = "OUTER WARD", subtitle = "Barricaded from the inside." },
	{ label = "STABLES", subtitle = "Whatever left did not use the door." },
	{ label = "KITCHENS", subtitle = "Cold ovens. A boarded well." },
	{ label = "GRAVEYARD", subtitle = "More graves than the ground was meant for." },
	{ label = "SMITHY", subtitle = "It was still working when it stopped." },
	{ label = "GREAT HALL", subtitle = "The roof is gone. The table is not." },
	{ label = "THE ROWS", subtitle = "The only cheerful place in the castle." },
	{ label = "INNER WARD", subtitle = "The line broke here." },
	{ label = "KEEP STEPS", subtitle = "Whatever it was, it went in there." },
}

--==========================================================================
--[[
	`offset` is how far the grille sits above where it was built: 0 is fully
	down, TRAVEL is fully withdrawn.

	An offset rather than an absolute Y, because the grille is a Model of many
	parts at many heights whose pivot is one bar and not the doorway. "Move to
	y = 45" has no single right answer; "sit 12 above your home" always does.
	`home` is captured once at build time so repeated moves can never drift.
]]
type Gate = {
	index: number,
	model: Model,
	grille: Model,
	home: CFrame,
	chains: { BasePart },
	offset: number,
	open: boolean,
	token: number,
}

local gates: { [number]: Gate } = {}
local cleared: { [number]: boolean } = {}
local lastArea: { [number]: number } = {} -- keyed by UserId

local areaEvent: RemoteEvent? = nil

--==========================================================================
-- Geometry
--==========================================================================

-- The z range of chamber `index`, near edge first (the player walks -z).
local function chamberBounds(index: number): (number, number)
	local zNear = Z_START - (index - 1) * CHAMBER_D
	return zNear, zNear - CHAMBER_D
end

-- Where chamber `index` lets you through to the next one. Odd chambers open on
-- the east, even on the west — the serpentine.
local function passageCentre(index: number): Vector3
	local _, zFar = chamberBounds(index)
	local gapX = HALF_W - GAP_W / 2 - GAP_INSET
	local x = if index % 2 == 1 then gapX else -gapX
	return Vector3.new(x, FLOOR_Y, zFar)
end

--[[
	Which chamber is this position in? Returns nil outside the castle — the
	approach, the moat, the spawn pad — so the HUD can hide rather than claim
	the player is in chamber 1 while they are still on the road.
]]
local function areaAt(position: Vector3): number?
	if position.Z > Z_START or position.Z < Z_START - CHAMBERS * CHAMBER_D then
		return nil
	end
	if math.abs(position.X) > HALF_W then
		return nil
	end
	local index = math.floor((Z_START - position.Z) / CHAMBER_D) + 1
	if index < 1 or index > CHAMBERS then
		return nil
	end
	return index
end

--==========================================================================
-- Building one gate
--==========================================================================
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

--[[
	The tool already leaves a row of thin static bars in the arch head — the
	rusted remains of the portcullis that used to hang there. Now that a real
	one hangs there instead, the remains are two grilles in one doorway. They go.
]]
local function clearRemnantBars(chamber: Instance?)
	local structure = chamber and chamber:FindFirstChild("Structure")
	local passage = structure and structure:FindFirstChild("Passage")
	if not passage then
		return
	end
	for _, child in passage:GetChildren() do
		if child.Name == "Bar" then
			child:Destroy()
		end
	end
end

--[[
	Builds one portcullis into the arch of chamber `index`.

	A grille rather than a slab, for two reasons that are both gameplay: the
	player can SEE the next chamber through it, so the gate reads as a door and
	not as the end of the map — and the dead on the far side are visible while
	still being unreachable, which is most of the dread this castle has to
	offer.

	The bars are 2.5 studs apart, which looks right and does NOT stop a
	character: Roblox collision would happily walk a player through a gap that
	size. So a single invisible slab rides inside the grille and does the actual
	stopping. The visible thing and the solid thing are separate on purpose —
	the day the art changes, the rule does not.
]]
local function buildGate(index: number, parent: Instance): Gate?
	local centre = passageCentre(index)

	local model = Instance.new("Model")
	model.Name = ("Gate%d"):format(index)

	--------------------------------------------------------------------------
	-- The runners it slides in, and the slot its feet drop into. Two iron-shod
	-- channels against the jambs and a sill across the threshold: they are what
	-- makes a grille hanging in a hole read as a mechanism instead of a prop.
	--------------------------------------------------------------------------
	for side = -1, 1, 2 do
		part(
			model,
			"Runner",
			Vector3.new(1.8, RUNNER_H, WALL_T - 3),
			CFrame.new(centre + Vector3.new(side * (GAP_W / 2 - 0.9), RUNNER_H / 2, 0)),
			PALETTE.ironDark,
			Enum.Material.Metal
		)
	end

	part(
		model,
		"Threshold",
		Vector3.new(GAP_W - 2, 0.5, 3.2),
		CFrame.new(centre + Vector3.new(0, 0.15, 0)),
		PALETTE.ironDark,
		Enum.Material.Metal
	)

	--------------------------------------------------------------------------
	-- The grille, in its own Model so the whole thing moves as one.
	--------------------------------------------------------------------------
	local grille = Instance.new("Model")
	grille.Name = "Grille"

	local first: BasePart? = nil
	local barBody = GRILLE_H - SPIKE_H

	for i = 0, BARS - 1 do
		local x = -BAR_SPAN / 2 + BAR_SPAN * (i / (BARS - 1))

		local bar = part(
			grille,
			"Bar",
			Vector3.new(BAR_T, barBody, BAR_T),
			CFrame.new(centre + Vector3.new(x, SPIKE_H + barBody / 2, 0)),
			PALETTE.iron,
			Enum.Material.CorrodedMetal
		)
		bar.CanCollide = false -- the Barrier below does the stopping
		if not first then
			first = bar
		end

		--[[
			The foot. Two diamond-plan blocks, wide then narrow, which taper to
			something that reads as a point from any angle a player will ever
			see it from. A wedge would be a truer spike and a worse bet: its
			slope faces one way, and half of these would end up pointing at the
			wall.
		]]
		local a = part(
			grille,
			"Spike",
			Vector3.new(BAR_T * 1.1, SPIKE_H * 0.55, BAR_T * 1.1),
			CFrame.new(centre + Vector3.new(x, SPIKE_H * 0.72, 0)) * CFrame.Angles(0, math.rad(45), 0),
			PALETTE.iron,
			Enum.Material.CorrodedMetal
		)
		a.CanCollide = false
		local b = part(
			grille,
			"SpikeTip",
			Vector3.new(BAR_T * 0.55, SPIKE_H * 0.6, BAR_T * 0.55),
			CFrame.new(centre + Vector3.new(x, SPIKE_H * 0.3, 0)) * CFrame.Angles(0, math.rad(45), 0),
			PALETTE.ironDark,
			Enum.Material.CorrodedMetal
		)
		b.CanCollide = false
	end

	-- Horizontal ties. Rust-coloured, because on a real portcullis these are
	-- the straps that hold it together and they are the first thing to go.
	for _, frac in { 0.2, 0.54, 0.87 } do
		local tie = part(
			grille,
			"Tie",
			Vector3.new(BAR_SPAN + BAR_T, 1.3, BAR_T * 0.9),
			CFrame.new(centre + Vector3.new(0, GRILLE_H * frac, 0)),
			PALETTE.rust,
			Enum.Material.CorrodedMetal
		)
		tie.CanCollide = false
	end

	-- The thing that actually stops you.
	local barrier = part(
		grille,
		"Barrier",
		Vector3.new(GAP_W - 2, GRILLE_H, 2.4),
		CFrame.new(centre + Vector3.new(0, GRILLE_H / 2, 0)),
		PALETTE.iron,
		Enum.Material.Metal
	)
	barrier.Transparency = 1
	barrier.CanCollide = true
	barrier.CastShadow = false

	if not first then
		model:Destroy()
		return nil
	end

	grille.PrimaryPart = first
	grille.Parent = model

	--------------------------------------------------------------------------
	-- The chains. Anchored high inside the masonry and shortening as the gate
	-- comes up, so the lift has something to be caused BY. A gate that rises
	-- with nothing attached to it is a floating prop.
	--------------------------------------------------------------------------
	local chains: { BasePart } = {}
	for side = -1, 1, 2 do
		local chain = part(
			model,
			"Chain",
			Vector3.new(0.9, CHAIN_TOP - GRILLE_H, 0.9),
			CFrame.new(centre + Vector3.new(side * CHAIN_X, (CHAIN_TOP + GRILLE_H) / 2, 0)),
			PALETTE.ironDark,
			Enum.Material.CorrodedMetal
		)
		chain.CanCollide = false
		table.insert(chains, chain)
	end

	model.Parent = parent

	return {
		index = index,
		model = model,
		grille = grille,
		home = grille:GetPivot(),
		chains = chains,
		offset = 0,
		open = false,
		token = 0,
	}
end

--==========================================================================
-- Moving it
--==========================================================================

-- Puts the grille and its chains at `value` studs above home. Absolute, never
-- incremental: an interrupted lift resumes from wherever it actually is
-- instead of accumulating a per-frame rounding error into a crooked gate.
local function applyOffset(gate: Gate, value: number)
	gate.offset = value
	gate.grille:PivotTo(gate.home + Vector3.new(0, value, 0))

	local top = GRILLE_H + value
	local length = math.max(CHAIN_TOP - top, 0.2)
	for _, chain in gate.chains do
		local at = chain.Position
		chain.Size = Vector3.new(chain.Size.X, length, chain.Size.Z)
		chain.Position = Vector3.new(at.X, CHAIN_TOP - length / 2, at.Z)
	end
end

--[[
	Raises or drops the grille.

	Slow, and not linear. A portcullis is a ton of iron on a hand winch: it
	starts hard, finds its rhythm, and is eased down at the end rather than
	arriving. The judder is the winch biting — it decays to nothing so the gate
	still lands exactly where the maths says, and it is the whole difference
	between a machine and a part being moved right-to-left.
]]
local function animate(gate: Gate, opening: boolean)
	local from = gate.offset
	local target = if opening then TRAVEL else 0
	local distance = math.abs(target - from)

	gate.token += 1
	local token = gate.token

	if distance < 0.01 then
		gate.open = opening
		applyOffset(gate, target)
		return
	end

	task.spawn(function()
		local duration = LIFT_SECONDS * (distance / TRAVEL)
		local elapsed = 0

		while elapsed < duration do
			local dt = RunService.Heartbeat:Wait()
			if gate.token ~= token then
				return -- something newer took over; leave the gate where it is
			end
			elapsed = math.min(elapsed + dt, duration)

			local a = elapsed / duration
			local eased = a * a * (3 - 2 * a) -- smoothstep: heavy start, soft stop
			local judder = math.sin(elapsed * 17) * 0.28 * (1 - a)
			applyOffset(gate, from + (target - from) * eased + judder)
		end

		applyOffset(gate, target)
		gate.open = opening
	end)
end

--==========================================================================
-- Telling the client
--==========================================================================

-- Chamber 9 has no passage onward: the way out of the Keep Steps is the tower,
-- so it must never be described as shut.
local function hasGate(index: number): boolean
	return index < CHAMBERS
end

local function payloadFor(index: number?)
	if not index then
		return { kind = "outside" }
	end
	local meta = AREAS[index]
	return {
		kind = "area",
		index = index,
		label = if meta then meta.label else ("AREA " .. index),
		subtitle = if meta then meta.subtitle else "",
		locked = hasGate(index) and not cleared[index],
	}
end

local function tell(player: Player, index: number?)
	if areaEvent then
		areaEvent:FireClient(player, payloadFor(index))
	end
end

local function tellEveryoneIn(index: number)
	for _, player in Players:GetPlayers() do
		if lastArea[player.UserId] == index then
			tell(player, index)
		end
	end
end

--==========================================================================
-- API — the mechanics call these
--==========================================================================

--[[
	The chamber's work is done: raise its gate and let the party through.
	Idempotent, so a mechanic that fires twice does not re-run the lift.
]]
function AreaService.clear(index: number)
	if cleared[index] then
		return
	end
	cleared[index] = true

	local gate = gates[index]
	if gate then
		animate(gate, true)
	end
	log:info(("area %d cleared — gate rising"):format(index))
	tellEveryoneIn(index)
end

-- Shuts a chamber again. Used when a run restarts, and by any mechanic that
-- wants to trap the party in a room they have already walked through.
function AreaService.lock(index: number)
	if not cleared[index] then
		return
	end
	cleared[index] = false

	local gate = gates[index]
	if gate then
		animate(gate, false)
	end
	tellEveryoneIn(index)
end

function AreaService.isCleared(index: number): boolean
	return cleared[index] == true
end

-- Which chamber is this player standing in? nil outside the castle.
function AreaService.areaOf(player: Player): number?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	return areaAt(root.Position)
end

-- Puts every gate back down. Called at the start of a run.
function AreaService.resetAll()
	for index = 1, CHAMBERS do
		AreaService.lock(index)
	end
end

--==========================================================================
function AreaService.Init() end

function AreaService.Start()
	if GameService.getPlaceRole() ~= Constants.PlaceRole.World then
		log:info("not the Forgotten Lands place; no gates")
		return
	end

	--[[
		Gates are only built where the castle actually is. In a place that has
		never had BuildBattleground run, Workspace.Gameplay.Battleground is
		missing and there is nothing to gate — build nothing rather than
		scattering eight portcullises across an empty baseplate.
	]]
	local gameplay = Workspace:FindFirstChild("Gameplay")
	local battleground = gameplay and gameplay:FindFirstChild("Battleground")
	if not battleground then
		log:info("no Battleground in this place — no gates built")
		return
	end

	areaEvent = Net.getEvent("AreaEvent")

	local built = 0
	-- Chambers 1..8 only; the ninth is closed by the tower, not by iron.
	for index = 1, CHAMBERS - 1 do
		local chamber = battleground:FindFirstChild(("Chamber%d"):format(index))
		clearRemnantBars(chamber)

		local gate = buildGate(index, chamber or battleground)
		if gate then
			gates[index] = gate
			built += 1
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		lastArea[player.UserId] = nil
	end)

	--[[
		Poll rather than use trigger volumes. A part at each wall is more
		precise and much more fragile: it misses a player who spawns past it, a
		player put down by a checkpoint, and anyone who clips the corner.
		Reading a position answers "where are you" for all three without a
		special case.
	]]
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < POLL_SECONDS then
			return
		end
		accumulator = 0

		for _, player in Players:GetPlayers() do
			local index = AreaService.areaOf(player)
			local key = player.UserId
			if lastArea[key] ~= index then
				lastArea[key] = index
				tell(player, index)
			end
		end
	end)

	if DEV_OPEN_ALL then
		for index = 1, CHAMBERS - 1 do
			AreaService.clear(index)
		end
		log:warn("DEV_OPEN_ALL is on — every gate starts up")
	end

	log:info(("ready — %d gates, all shut"):format(built))
end

return AreaService
