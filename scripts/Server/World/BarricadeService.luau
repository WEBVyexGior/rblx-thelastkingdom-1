--!strict
--[[
	BarricadeService
	Area 1's mechanic: the passage out of the Outer Ward is barred from the
	inside, and you cut your way through it.

	--------------------------------------------------------------------------
	WHAT IT IS

	Heavy timber lashed across the portcullis, held by THREE rope bindings. Each
	binding takes three cuts. Cut them all and the timber comes down, and only
	then can the gate rise.

	It answers the first thing a player asks in a new game — "what am I supposed
	to do" — with something they can see from across the room and understand
	without a tutorial: a door, a rope, and a prompt that says Cut.

	--------------------------------------------------------------------------
	THE TWO RULES IT WAS BUILT AROUND

	SOLO-FIRST. Three bindings, one pair of hands. Four players cut three
	bindings faster than one player does; one player is never stuck. Nothing here
	needs two people at the same moment, and nothing here ever will.

	PROGRESS IS KEPT. Each completed cut is banked. Break off to fight, come
	back, and the rope is exactly as frayed as you left it — you lose at most the
	1.6 seconds you were part way through. A mechanic that resets when the dead
	arrive is a mechanic that punishes the player for playing the game.

	--------------------------------------------------------------------------
	WHY ProximityPrompt AND NOT A CUSTOM UI

	It is server-owned, it has a real hold-and-fill affordance built in, it shows
	the key on keyboard and a button on touch, and it cannot be spoofed into
	completing early. A hand-rolled version would be more code, worse on mobile,
	and would need trusting the client about when the hold finished.

	Place: Forgotten Lands ONLY (Server/World). Phase: Areas.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local GameService = require(Server.Services.GameService)
local AreaService = require(script.Parent.AreaService)
local Beacon = require(script.Parent.Beacon)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local BarricadeService = {}

BarricadeService.Name = "BarricadeService"

local log = Logger.new("BarricadeService")

--==========================================================================
local AREA = 1

local CUTS_PER_LASHING = 3
local HOLD_SECONDS = 1.6
local REACH = 14

-- Where the timber sits: just in front of the grille, on the side the player
-- arrives from (they always walk -z, so +z is "in front").
local FACE_Z = 4.5
local GAP_W = 46

local PALETTE = {
	timber = Color3.fromRGB(74, 54, 36),
	timberPale = Color3.fromRGB(96, 72, 48),
	rope = Color3.fromRGB(176, 148, 96),
	ropeDark = Color3.fromRGB(132, 108, 68),
	iron = Color3.fromRGB(48, 42, 38),
}

--[[
	The three bindings, as offsets from the middle of the doorway.

	Spread across the width AND the height on purpose. Three ropes in a row at
	waist height read as one object with three handles; staggered, they read as
	three separate things holding three separate beams — which is what they are,
	and which is what makes the barricade come apart rather than vanish.
]]
local LASHINGS = {
	{ x = -14.5, y = 6.5 },
	{ x = 13.0, y = 13.5 },
	{ x = -6.0, y = 20.5 },
}

--==========================================================================
type Lashing = {
	index: number,
	model: Model,
	prompt: ProximityPrompt,
	wraps: { BasePart },
	hook: BasePart,
	cuts: number,
	done: boolean,
}

local built = false
local root: Model? = nil
local beacon: Beacon.Beacon? = nil
local lashings: { Lashing } = {}
local remaining = 0

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

--==========================================================================
--[[
	Builds the timber.

	Nailed up in a hurry by people who were losing: the boards are not level,
	they are not the same length, and two of them are braces jammed in
	diagonally because whoever did this ran out of straight wood. A tidy
	barricade would say the castle was fortified. This one has to say it was
	improvised, and then it did not work.
]]
local function buildTimber(parent: Instance, centre: Vector3): { BasePart }
	local beams: { BasePart } = {}
	local z = centre.Z + FACE_Z

	local boards = {
		{ y = 5.0, len = GAP_W + 4, tilt = 2.5, thick = 2.6 },
		{ y = 9.5, len = GAP_W - 2, tilt = -1.5, thick = 2.2 },
		{ y = 14.0, len = GAP_W + 2, tilt = 1.0, thick = 2.8 },
		{ y = 18.5, len = GAP_W - 5, tilt = -3.0, thick = 2.2 },
		{ y = 22.5, len = GAP_W - 1, tilt = 1.8, thick = 2.4 },
	}

	for i, b in boards do
		local beam = part(
			parent,
			"Beam" .. i,
			Vector3.new(b.len, b.thick, 1.8),
			CFrame.new(centre.X, b.y, z) * CFrame.Angles(0, 0, math.rad(b.tilt)),
			if i % 2 == 0 then PALETTE.timber else PALETTE.timberPale,
			Enum.Material.Wood
		)
		table.insert(beams, beam)
	end

	-- The two braces, jammed corner to corner behind the boards.
	for _, brace in { { a = 34, x = -9 }, { a = -34, x = 10 } } do
		local b = part(
			parent,
			"Brace",
			Vector3.new(34, 2.2, 1.6),
			CFrame.new(centre.X + brace.x, 14, z - 1.6) * CFrame.Angles(0, 0, math.rad(brace.a)),
			PALETTE.timber,
			Enum.Material.WoodPlanks
		)
		table.insert(beams, b)
	end

	return beams
end

--==========================================================================
--[[
	One binding: an iron ring driven into the beam and three turns of rope
	round it.

	The wraps are separate parts because they are the progress bar. A cut takes
	one away, so the player can see how far in they are without a number and
	without looking at a HUD — the rope itself says it.
]]
local function buildLashing(parent: Instance, centre: Vector3, spec: { x: number, y: number }, index: number): Lashing
	local at = Vector3.new(centre.X + spec.x, spec.y, centre.Z + FACE_Z)

	local model = Instance.new("Model")
	model.Name = "Lashing" .. index
	model.Parent = parent

	part(
		model,
		"Ring",
		Vector3.new(1.1, 4.6, 1.1),
		CFrame.new(at + Vector3.new(0, 0, 1.2)),
		PALETTE.iron,
		Enum.Material.Metal
	)

	local wraps: { BasePart } = {}
	for i = 1, CUTS_PER_LASHING do
		local wrap = part(
			model,
			"Wrap" .. i,
			Vector3.new(4.6, 0.85, 4.4),
			CFrame.new(at + Vector3.new(0, (i - 2) * 1.15, 0.4)) * CFrame.Angles(0, 0, math.rad((i - 2) * 7)),
			if i % 2 == 1 then PALETTE.rope else PALETTE.ropeDark,
			Enum.Material.Fabric
		)
		wrap.CanCollide = false
		table.insert(wraps, wrap)
	end

	--[[
		Glows through the timber. This is the answer to "I could not see what I
		was supposed to touch" — a Highlight draws on top of whatever is in
		front of it, so the rope is findable from across the ward and obvious
		once you are close.
	]]
	local glow = Instance.new("Highlight")
	glow.Name = "Glow"
	glow.FillColor = Color3.fromRGB(214, 176, 92)
	glow.FillTransparency = 0.72
	glow.OutlineColor = Color3.fromRGB(242, 216, 142)
	glow.OutlineTransparency = 0.15
	glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	glow.Adornee = model
	glow.Parent = model

	TweenService:Create(glow, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		FillTransparency = 0.9,
	}):Play()

	-- The prompt hangs on its own anchor so it sits in front of the rope rather
	-- than inside the timber, where a player would have to aim at a plank.
	local hook = part(
		model,
		"Hook",
		Vector3.new(1, 1, 1),
		CFrame.new(at + Vector3.new(0, 0, 2.6)),
		PALETTE.rope,
		Enum.Material.Fabric
	)
	hook.Transparency = 1
	hook.CanCollide = false
	hook.CanQuery = false

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Cut"
	prompt.ActionText = "Cut"
	prompt.ObjectText = ("Lashing  0 / %d"):format(CUTS_PER_LASHING)
	prompt.HoldDuration = HOLD_SECONDS
	prompt.MaxActivationDistance = REACH
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = hook

	return {
		index = index,
		model = model,
		prompt = prompt,
		wraps = wraps,
		hook = hook,
		cuts = 0,
		done = false,
	}
end

--==========================================================================
-- The whole thing comes down. Tweened rather than unanchored: real physics
-- here means seven loose planks that can be pushed into the doorway, wedge the
-- portcullis, or be surfed. It has to LOOK like it fell, not BE falling.
local function collapse()
	local model = root
	if not model then
		return
	end

	if beacon then
		beacon:destroy()
		beacon = nil
	end

	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			child.CanCollide = false
			local drop = CFrame.new(0, -math.random(16, 26), math.random(0, 4))
				* CFrame.Angles(math.rad(math.random(50, 90)), 0, math.rad(math.random(-30, 30)))
			TweenService:Create(child, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = child.CFrame * drop,
				Transparency = 1,
			}):Play()
		end
	end

	task.delay(1.1, function()
		if model.Parent then
			model:Destroy()
		end
	end)
	root = nil

	log:info("barricade down — area 1 open")
	AreaService.clear(AREA)
end

--==========================================================================
local function cut(lashing: Lashing, player: Player)
	if lashing.done then
		return
	end

	lashing.cuts += 1

	-- One turn of rope goes with each cut, so the progress lives on the object
	-- and not only in a label.
	local wrap = lashing.wraps[lashing.cuts]
	if wrap then
		TweenService:Create(wrap, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = wrap.CFrame * CFrame.new(0, -6, 1) * CFrame.Angles(math.rad(70), 0, 0),
			Transparency = 1,
		}):Play()
		task.delay(0.5, function()
			if wrap.Parent then
				wrap:Destroy()
			end
		end)
	end

	if lashing.cuts < CUTS_PER_LASHING then
		lashing.prompt.ObjectText = ("Lashing  %d / %d"):format(lashing.cuts, CUTS_PER_LASHING)
		return
	end

	--------------------------------------------------------------------------
	lashing.done = true
	lashing.prompt.Enabled = false

	local glow = lashing.model:FindFirstChildWhichIsA("Highlight")
	if glow then
		glow:Destroy()
	end

	remaining -= 1
	log:info(("%s cut lashing %d — %d left"):format(player.Name, lashing.index, remaining))

	if remaining <= 0 then
		collapse()
	elseif beacon then
		beacon:setLabel(("BARRICADE — %d LEFT"):format(remaining))
	end
end

--==========================================================================
function BarricadeService.Init() end

function BarricadeService.Start()
	if GameService.getPlaceRole() ~= Constants.PlaceRole.World then
		return
	end

	--[[
		Built into the gate's own Model, so it is torn down with the gate and a
		mis-ordered boot can never leave a barricade floating in an empty
		chamber. No gate means no castle in this place: build nothing.
	]]
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

		lashing.prompt.Triggered:Connect(function(player: Player)
			cut(lashing, player)
		end)
	end

	beacon = Beacon.create(
		centre + Vector3.new(0, 0, FACE_Z + 12),
		("BARRICADE — %d LEFT"):format(remaining),
		model
	)

	built = true
	log:info(("ready — %d lashings, %d cuts each"):format(remaining, CUTS_PER_LASHING))
end

-- Whether the barricade is still up. For a run restart, and for tests.
function BarricadeService.isStanding(): boolean
	return built and root ~= nil
end

-- Development shortcut: bring it down without cutting.
function BarricadeService.forceOpen()
	if root then
		collapse()
	end
end

return BarricadeService
