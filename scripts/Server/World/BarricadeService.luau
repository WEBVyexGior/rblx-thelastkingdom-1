--!strict
--[[
	BarricadeService
	Area 1's mechanic: the passage out of the Outer Ward is barred from the
	inside, and you cut your way through it.

	--------------------------------------------------------------------------
	WHAT IT IS

	Heavy timber nailed across the portcullis and held by THREE rope lashings.
	Each lashing takes three cuts. Cut them all and the timber comes down, and
	only then can the gate rise.

	It answers the first thing a player asks in a new game — "what am I supposed
	to do" — with something they can see and understand without a tutorial: a
	door, a rope, and a prompt that says Cut.

	--------------------------------------------------------------------------
	THE ROPE IS BUILT LIKE ROPE

	The first pass used three flat boxes and the note back was, correctly, that
	they did not look like anything. A lashing here is now what one actually is:
	turns of cord passing right around the beam, each turn made of eight short
	segments laid tangent to an ellipse, every segment jittered off true so no
	two turns sit alike — plus frayed tails hanging under it and an iron ring of
	its own eight segments driven into the wood.

	That is roughly 70 parts per lashing and it is worth every one. Detail at
	arm's length is the whole difference between a castle and a greybox, and
	this is the first thing in the game the player puts their hands on.

	--------------------------------------------------------------------------
	THE TWO RULES IT WAS BUILT AROUND

	SOLO-FIRST. Three lashings, one pair of hands. Four players cut three
	lashings faster than one player does; one player is never stuck. Nothing
	here needs two people at the same moment.

	PROGRESS IS KEPT. Each completed cut is banked and takes a turn of rope with
	it. Break off to fight, come back, and the lashing is exactly as frayed as
	you left it — you lose at most the 1.6 seconds you were part way through.

	Place: Forgotten Lands ONLY (Server/World). Phase: Areas.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local GameService = require(Server.Services.GameService)
local AreaService = require(script.Parent.AreaService)
local Net = require(ReplicatedStorage.Shared.Net)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local BarricadeService = {}

BarricadeService.Name = "BarricadeService"

local log = Logger.new("BarricadeService")

--==========================================================================
local AREA = 1

local CUTS_PER_LASHING = 3
local TURNS_PER_CUT = 3 -- turns of cord that fall away with each cut
local SEGMENTS_PER_TURN = 8
local HOLD_SECONDS = 1.6
local REACH = 13

-- Where the timber sits: just in front of the grille, on the side the player
-- arrives from (they always walk -z, so +z is "in front").
local FACE_Z = 4.5
local GAP_W = 46

local PALETTE = {
	oak = Color3.fromRGB(71, 52, 35),
	oakPale = Color3.fromRGB(94, 71, 47),
	oakGrey = Color3.fromRGB(83, 74, 62), -- weathered, the boards that were outside
	rope = Color3.fromRGB(163, 138, 96),
	ropePale = Color3.fromRGB(184, 160, 118),
	ropeDark = Color3.fromRGB(128, 105, 70),
	iron = Color3.fromRGB(52, 45, 41),
	ironPale = Color3.fromRGB(74, 66, 60),
}

--[[
	The three lashings: which board each one binds, and where along it.

	Only `x` is written down. The HEIGHT is derived from the board, because a
	hand-written y is a number that silently stops being true the moment a board
	moves — the first version had exactly that, with a lashing sitting a stud
	and a half above the plank it was supposed to be holding, wrapping thin air.

	Boards 1, 3 and 5 on purpose: staggered across the width and the height, so
	they read as three separate bindings on three separate beams rather than as
	one object with three handles. That is what makes the barricade come apart
	rather than vanish.
]]
local LASHINGS = {
	{ x = -14.5, beam = 1 },
	{ x = 13.0, beam = 3 },
	{ x = -6.0, beam = 5 },
}

--==========================================================================
type Lashing = {
	index: number,
	model: Model,
	prompt: ProximityPrompt,
	glow: Highlight?,
	turns: { { BasePart } }, -- one bundle per cut, oldest first
	cuts: number,
	done: boolean,
}

local root: Model? = nil
local lashings: { Lashing } = {}
local remaining = 0
local started = false
local hintEvent: RemoteEvent? = nil

local rng = Random.new(20477)

--==========================================================================
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
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
	A cylinder Part's axis runs along its LOCAL X, so its Size reads
	(length, diameter, diameter) — not (x, y, z) as seen on screen. Getting that
	backwards produces a disc lying on its side, which is exactly what it looks
	like.
]]
local function cord(parent: Instance, name: string, length: number, dia: number, cf: CFrame, colour: Color3): Part
	local p = part(parent, name, Vector3.new(length, dia, dia), cf, colour, Enum.Material.Fabric)
	p.Shape = Enum.PartType.Cylinder
	p.CastShadow = false
	return p
end

--==========================================================================
--[[
	One turn of cord, right around the beam.

	Eight segments on an ellipse in the YZ plane, each laid along the tangent at
	its own angle. `CFrame.lookAt` points a part's LOOK vector at a target, so
	the frame is then turned 90 degrees about Y to swing the cylinder's axis
	onto that line. The explicit up vector matters: the tangent passes through
	straight-up twice per turn, and lookAt cannot resolve a direction parallel
	to its up.

	`lean` tilts the whole turn slightly along the beam, which is what makes a
	stack of these read as cord spiralling round rather than as identical rings.
]]
local function buildTurn(
	parent: Instance,
	centre: Vector3,
	ry: number,
	rz: number,
	dia: number,
	lean: number,
	colour: Color3
): { BasePart }
	local made: { BasePart } = {}
	local step = (math.pi * 2) / SEGMENTS_PER_TURN

	for i = 0, SEGMENTS_PER_TURN - 1 do
		local a = i * step
		local nextA = a + step

		local p1 = Vector3.new(0, math.cos(a) * ry, math.sin(a) * rz)
		local p2 = Vector3.new(0, math.cos(nextA) * ry, math.sin(nextA) * rz)
		local mid = centre + (p1 + p2) / 2 + Vector3.new(lean * (i / SEGMENTS_PER_TURN), 0, 0)
		local span = (p2 - p1)

		-- A hair longer than the gap it spans, so neighbouring segments overlap
		-- and the turn has no visible joints.
		local length = span.Magnitude * 1.18
		local frame = CFrame.lookAt(mid, mid + span.Unit, Vector3.new(1, 0, 0))
			* CFrame.Angles(0, math.rad(90), 0)
			* CFrame.Angles(0, 0, math.rad(rng:NextNumber(-6, 6)))

		local segment = cord(parent, "Cord", length, dia * rng:NextNumber(0.9, 1.08), frame, colour)
		table.insert(made, segment)
	end

	return made
end

-- The frayed tail left hanging where the cord was tied off. Three strands,
-- each drooping a little more than the last.
local function buildTail(parent: Instance, at: Vector3, colour: Color3): { BasePart }
	local made: { BasePart } = {}
	for strand = 1, 3 do
		local drop = at + Vector3.new(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.2, 0.4))
		local length = rng:NextNumber(1.6, 2.6)
		for link = 1, 3 do
			local lean = math.rad(rng:NextNumber(4, 16)) * link
			drop -= Vector3.new(0, length * 0.9, 0)
			local seg = cord(
				parent,
				"Fray",
				length,
				0.22,
				CFrame.new(drop + Vector3.new(0, length / 2, 0))
					* CFrame.Angles(0, 0, math.rad(90) + lean * (if strand == 2 then -1 else 1)),
				colour
			)
			seg.Color = colour:Lerp(PALETTE.ropeDark, link / 4)
			table.insert(made, seg)
		end
	end
	return made
end

-- An iron ring driven into the beam: eight segments round a circle in the XY
-- plane, which is the plane facing the player.
local function buildRing(parent: Instance, at: Vector3, radius: number)
	local segments = 8
	local step = (math.pi * 2) / segments
	for i = 0, segments - 1 do
		local a = i * step
		local p1 = Vector3.new(math.cos(a) * radius, math.sin(a) * radius, 0)
		local p2 = Vector3.new(math.cos(a + step) * radius, math.sin(a + step) * radius, 0)
		local mid = at + (p1 + p2) / 2
		local span = p2 - p1
		local frame = CFrame.lookAt(mid, mid + span.Unit, Vector3.new(0, 0, 1))
			* CFrame.Angles(0, math.rad(90), 0)
		local seg = part(
			parent,
			"Ring",
			Vector3.new(span.Magnitude * 1.2, 0.42, 0.42),
			frame,
			if i % 2 == 0 then PALETTE.iron else PALETTE.ironPale,
			Enum.Material.Metal
		)
		seg.Shape = Enum.PartType.Cylinder
	end

	-- The spike through the middle, into the wood.
	local spike = part(
		parent,
		"Spike",
		Vector3.new(0.55, 0.55, 3.4),
		CFrame.new(at - Vector3.new(0, 0, 1.1)),
		PALETTE.iron,
		Enum.Material.Metal
	)
	spike.CanCollide = false
end

--==========================================================================
--[[
	The timber.

	Nailed up in a hurry by people who were losing: the boards are not level,
	not the same length, and two of them are braces jammed in diagonally because
	whoever did this ran out of straight wood. Every board is nailed at both
	ends and one of them is split. A tidy barricade would say the castle was
	fortified; this one has to say it was improvised, and then that it did not
	work.
]]
local BOARDS = {
	{ y = 5.0, len = GAP_W + 4, tilt = 2.5, thick = 2.7, tone = 1 },
	{ y = 9.6, len = GAP_W - 2, tilt = -1.5, thick = 2.2, tone = 2 },
	{ y = 14.0, len = GAP_W + 2, tilt = 1.0, thick = 2.9, tone = 3 },
	{ y = 18.6, len = GAP_W - 5, tilt = -3.0, thick = 2.3, tone = 1 },
	{ y = 22.6, len = GAP_W - 1, tilt = 1.8, thick = 2.5, tone = 2 },
}

local TONES = { PALETTE.oak, PALETTE.oakPale, PALETTE.oakGrey }

local function boardCFrame(centre: Vector3, i: number): CFrame
	local b = BOARDS[i]
	return CFrame.new(centre.X, b.y, centre.Z + FACE_Z) * CFrame.Angles(0, 0, math.rad(b.tilt))
end

local function buildTimber(parent: Instance, centre: Vector3)
	for i, b in BOARDS do
		local frame = boardCFrame(centre, i)
		local beam = part(
			parent,
			"Board" .. i,
			Vector3.new(b.len, b.thick, 1.9),
			frame,
			TONES[b.tone],
			Enum.Material.Wood
		)
		beam.CanCollide = true

		-- A second, thinner board face-fixed over the first, offset a touch.
		-- Two planes of wood at slightly different depths is what stops a board
		-- reading as a single flat brick.
		local skin = part(
			parent,
			"Facing" .. i,
			Vector3.new(b.len * rng:NextNumber(0.72, 0.92), b.thick * 0.55, 0.5),
			frame * CFrame.new(rng:NextNumber(-3, 3), rng:NextNumber(-0.4, 0.4), 1.2),
			TONES[b.tone]:Lerp(Color3.fromRGB(0, 0, 0), 0.14),
			Enum.Material.WoodPlanks
		)
		skin.CastShadow = false

		-- Nails, at both ends and in the middle where a hurried carpenter would
		-- put them.
		for _, at in { -b.len / 2 + 3, 0, b.len / 2 - 3 } do
			for _, dy in { -b.thick / 4, b.thick / 4 } do
				local nail = part(
					parent,
					"Nail",
					Vector3.new(0.42, 0.42, 2.6),
					frame * CFrame.new(at + rng:NextNumber(-0.6, 0.6), dy, 1.1),
					PALETTE.iron,
					Enum.Material.Metal
				)
				nail.Shape = Enum.PartType.Cylinder
				nail.CFrame = nail.CFrame * CFrame.Angles(0, math.rad(90), 0)
				nail.CastShadow = false
			end
		end
	end

	-- The two braces, jammed corner to corner behind the boards.
	for _, brace in { { a = 34, x = -9 }, { a = -34, x = 10 } } do
		local b = part(
			parent,
			"Brace",
			Vector3.new(34, 2.3, 1.7),
			CFrame.new(centre.X + brace.x, 14, centre.Z + FACE_Z - 1.7) * CFrame.Angles(0, 0, math.rad(brace.a)),
			PALETTE.oak,
			Enum.Material.WoodPlanks
		)
		b.CanCollide = true
	end

	-- One board split where it was forced. Two short wedges left proud of the
	-- break, because a plank that snapped does not leave a clean edge.
	for i = 1, 2 do
		local splinter = part(
			parent,
			"Splinter",
			Vector3.new(rng:NextNumber(2.5, 4.5), 0.5, 0.9),
			boardCFrame(centre, 4) * CFrame.new(BOARDS[4].len / 2 - 1, (i - 1.5) * 0.9, 0.5)
				* CFrame.Angles(0, 0, math.rad(rng:NextNumber(-22, 22))),
			PALETTE.oakPale,
			Enum.Material.Wood
		)
		splinter.CastShadow = false
	end
end

--==========================================================================
local function buildLashing(parent: Instance, centre: Vector3, spec: { x: number, beam: number }, index: number): Lashing
	local board = BOARDS[spec.beam]

	--[[
		Where the board actually IS at this point along its length. Every board
		is tilted a degree or three, so a binding 14 studs off centre sits over
		half a stud off the board's nominal height — small, and the difference
		between rope biting wood and rope floating beside it.
	]]
	local tilt = math.rad(board.tilt)
	local at = Vector3.new(
		centre.X + spec.x,
		board.y + spec.x * math.sin(tilt),
		centre.Z + FACE_Z
	)

	local model = Instance.new("Model")
	model.Name = "Lashing" .. index
	model.Parent = parent

	buildRing(model, at + Vector3.new(0, 0, 1.6), 1.5)

	--[[
		The turns, bundled by cut. `turns[1]` falls with the first cut, and the
		bundle IS the progress bar — the player reads how far in they are off
		the rope itself, without a number and without looking at a HUD.
	]]
	local turns: { { BasePart } } = {}
	local ry = board.thick / 2 + 0.45
	local rz = 1.9 / 2 + 0.45
	local spread = 3.4

	for cutIndex = 1, CUTS_PER_LASHING do
		local bundle: { BasePart } = {}
		for t = 1, TURNS_PER_CUT do
			local n = (cutIndex - 1) * TURNS_PER_CUT + t
			local slide = -spread + (spread * 2) * ((n - 1) / (CUTS_PER_LASHING * TURNS_PER_CUT - 1))
			-- Follow the board's tilt as the turns march along it, for the same
			-- reason the lashing's own height is derived rather than written.
			local along = Vector3.new(slide, slide * math.sin(tilt), 0)
			local colour = if n % 2 == 0 then PALETTE.rope else PALETTE.ropePale
			for _, segment in buildTurn(model, at + along, ry, rz, 0.42, 0.5, colour) do
				table.insert(bundle, segment)
			end
		end
		table.insert(turns, bundle)
	end

	buildTail(model, at + Vector3.new(spread, -ry + 0.2, rz), PALETTE.rope)

	--[[
		Glows through the timber so it is findable, and quietly. The first
		version of this game's wayfinding was a pillar of gold light and the
		note back was that it was far too loud — so this is a pale warm edge and
		almost no fill, which says "you can touch this" without saying anything
		else.
	]]
	local glow = Instance.new("Highlight")
	glow.Name = "Glow"
	glow.FillColor = Color3.fromRGB(226, 208, 170)
	glow.FillTransparency = 0.93
	glow.OutlineColor = Color3.fromRGB(238, 226, 198)
	glow.OutlineTransparency = 0.45
	glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	glow.Adornee = model
	glow.Parent = model

	TweenService:Create(glow, TweenInfo.new(2.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		OutlineTransparency = 0.72,
	}):Play()

	-- The prompt hangs on its own anchor in front of the rope, so the player
	-- aims at the binding and not at a plank.
	local hook = part(
		model,
		"Hook",
		Vector3.new(1, 1, 1),
		CFrame.new(at + Vector3.new(0, 0, 3)),
		PALETTE.rope,
		Enum.Material.Fabric
	)
	hook.Transparency = 1
	hook.CanQuery = false

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Cut"
	prompt.ActionText = "Cut"
	prompt.ObjectText = "Lashing"
	prompt.HoldDuration = HOLD_SECONDS
	prompt.MaxActivationDistance = REACH
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = hook

	return {
		index = index,
		model = model,
		prompt = prompt,
		glow = glow,
		turns = turns,
		cuts = 0,
		done = false,
	}
end

--==========================================================================
local function hint(text: string?)
	if not hintEvent then
		return
	end
	hintEvent:FireAllClients({ source = "area", text = text })
end

local function hintForRemaining()
	if remaining <= 0 then
		hint(nil)
	elseif remaining == 1 then
		hint("Cut the last lashing")
	else
		hint(("Cut the barricade  —  %d lashings left"):format(remaining))
	end
end

--==========================================================================
-- The whole thing comes down. Tweened rather than unanchored: real physics
-- here means a dozen loose planks that can be pushed into the doorway, wedge
-- the portcullis, or be surfed. It has to LOOK like it fell, not BE falling.
local function collapse()
	local model = root
	if not model then
		return
	end
	root = nil

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			local drop = CFrame.new(0, -rng:NextNumber(16, 26), rng:NextNumber(0, 4))
				* CFrame.Angles(
					math.rad(rng:NextNumber(50, 90)),
					0,
					math.rad(rng:NextNumber(-30, 30))
				)
			TweenService:Create(d, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = d.CFrame * drop,
				Transparency = 1,
			}):Play()
		elseif d:IsA("Highlight") then
			d:Destroy()
		end
	end

	task.delay(1.1, function()
		if model.Parent then
			model:Destroy()
		end
	end)

	hint(nil)
	log:info("barricade down — area 1 open")
	AreaService.clear(AREA)
end

--==========================================================================
local function cut(lashing: Lashing, player: Player)
	if lashing.done then
		return
	end

	lashing.cuts += 1

	-- One bundle of turns goes with each cut: the rope unwinds, drops and is
	-- gone, so the progress lives on the object and not only in a counter.
	local bundle = lashing.turns[lashing.cuts]
	if bundle then
		for _, segment in bundle do
			local fall = CFrame.new(rng:NextNumber(-1.5, 1.5), -rng:NextNumber(5, 9), rng:NextNumber(0, 2))
				* CFrame.Angles(math.rad(rng:NextNumber(-90, 90)), 0, math.rad(rng:NextNumber(-90, 90)))
			TweenService:Create(segment, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = segment.CFrame * fall,
				Transparency = 1,
			}):Play()
		end
		task.delay(0.6, function()
			for _, segment in bundle do
				if segment.Parent then
					segment:Destroy()
				end
			end
		end)
	end

	if lashing.cuts < CUTS_PER_LASHING then
		return
	end

	--------------------------------------------------------------------------
	lashing.done = true
	lashing.prompt.Enabled = false
	if lashing.glow then
		lashing.glow:Destroy()
		lashing.glow = nil
	end

	remaining -= 1
	log:info(("%s cut lashing %d — %d left"):format(player.Name, lashing.index, remaining))

	if remaining <= 0 then
		collapse()
	else
		hintForRemaining()
	end
end

--==========================================================================
--[[
	Builds the barricade the first time somebody walks into the Outer Ward.

	Not at boot. Every area's content starts when the player arrives in it —
	that is the rule now, and it is what makes the instruction at the top of the
	screen land at the moment it means something rather than while the player is
	still reading the intro.
]]
local function begin(player: Player)
	if started then
		return
	end
	started = true

	local parent = AreaService.gateModel(AREA)
	if not parent then
		log:info("no gate for area 1 — nothing to barricade")
		return
	end

	local centre = AreaService.passageOf(AREA)

	local model = Instance.new("Model")
	model.Name = "Barricade"
	model.Parent = parent
	root = model

	buildTimber(model, centre)

	remaining = 0
	lashings = {}
	for i, spec in LASHINGS do
		local lashing = buildLashing(model, centre, spec, i)
		table.insert(lashings, lashing)
		remaining += 1

		lashing.prompt.Triggered:Connect(function(who: Player)
			cut(lashing, who)
		end)
	end

	hintForRemaining()
	log:info(("%s entered — barricade up, %d lashings, %d cuts each"):format(
		player.Name,
		remaining,
		CUTS_PER_LASHING
	))
end

--==========================================================================
function BarricadeService.Init() end

function BarricadeService.Start()
	if GameService.getPlaceRole() ~= Constants.PlaceRole.World then
		return
	end

	hintEvent = Net.getEvent("ObjectiveHint")
	AreaService.onEnter(AREA, begin)

	log:info("armed — waits for a player to enter area 1")
end

-- Whether the barricade is still up. For a run restart, and for tests.
function BarricadeService.isStanding(): boolean
	return root ~= nil
end

-- Development shortcut: bring it down without cutting.
function BarricadeService.forceOpen()
	if root then
		collapse()
	end
end

return BarricadeService
