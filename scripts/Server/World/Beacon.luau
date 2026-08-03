--!strict
--[[
	Beacon
	A place in the world the player is meant to go to, made impossible to miss.

	--------------------------------------------------------------------------
	WHY THIS EXISTS

	The first playtest of the castle failed on one thing, and it was not the
	combat: the player did not know where to walk. There was an objective, there
	was a gate, and there was nothing on screen connecting either to a direction.
	Telling someone "the east side" is not level design — it assumes they carry a
	compass and a floor plan.

	So anything the player must reach gets one of these: a shaft of light tall
	enough to clear the buildings, a ring pulsing outward on the ground under it,
	motes drifting up, and a name floating above that draws THROUGH walls. From
	anywhere in a 200-stud chamber you can see it; from the far side of a
	building you can still see the name.

	--------------------------------------------------------------------------
	IT IS A LIBRARY, NOT A SERVICE

	No Init/Start — the Loader will require it and move on. Callers own their
	beacons and destroy them; nothing here keeps a registry, because a beacon
	that outlives its objective is worse than no beacon at all.

	Location: ServerScriptService.Server.World.Beacon
]]

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Beacon = {}

--==========================================================================
--[[
	Gold and cream, matching Client/UI/Theme's `Gold` and `Cream`.

	Duplicated rather than required: Theme lives in StarterPlayerScripts and the
	server cannot see it. If the palette ever moves to Shared, these two go with
	it — until then they are the only copy and they are marked as such.
]]
local GOLD = Color3.fromRGB(198, 158, 66)
local GOLD_BRIGHT = Color3.fromRGB(242, 216, 142)
local CREAM = Color3.fromRGB(249, 240, 218)
local BORDEAUX = Color3.fromRGB(158, 58, 68)

local BEAM_H = 70
local BEAM_DIA = 2.2
local RING_MAX = 34
local LABEL_Y = 7

export type Beacon = {
	model: Model,
	label: TextLabel,
	beam: BasePart,
	rings: { BasePart },
	light: PointLight,
	setLabel: (self: Beacon, text: string) -> (),
	setColor: (self: Beacon, colour: Color3) -> (),
	moveTo: (self: Beacon, position: Vector3) -> (),
	destroy: (self: Beacon) -> (),
}

--==========================================================================
--[[
	A cylinder Part's axis runs along its LOCAL X, so every round piece here is
	rotated 90 degrees about Z to stand it up — and its Size is then
	(length, diameter, diameter), not (x, y, z) as read on screen. Getting this
	backwards produces a disc lying on its side, which is exactly what it looks
	like: a bug.
]]
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local function cylinder(parent: Instance, name: string, length: number, dia: number, at: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(length, dia, dia)
	p.CFrame = at * UPRIGHT
	p.Anchored = true
	p.CanCollide = false
	-- Raycasts must pass straight through. A beam that stops an arrow, or eats a
	-- sword swing aimed at something standing on the objective, is a trap.
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = GOLD
	p.Parent = parent
	return p
end

--==========================================================================
--[[
	Builds a beacon at `position`.

	`label` is shown above it in English, upper case — it is a signpost, and a
	signpost that needs reading twice has failed.
]]
function Beacon.create(position: Vector3, label: string, parent: Instance?): Beacon
	local model = Instance.new("Model")
	model.Name = "Beacon"

	--------------------------------------------------------------------------
	-- The shaft. Tall enough to clear the houses, thin enough not to be a wall.
	--------------------------------------------------------------------------
	local beam = cylinder(model, "Beam", BEAM_H, BEAM_DIA, CFrame.new(position + Vector3.new(0, BEAM_H / 2, 0)))
	beam.Transparency = 0.62

	-- A wider, fainter sheath around it, so the shaft has an edge that glows
	-- instead of a hard cylinder wall.
	local halo = cylinder(model, "Halo", BEAM_H * 0.8, BEAM_DIA * 3.4, CFrame.new(position + Vector3.new(0, BEAM_H * 0.4, 0)))
	halo.Transparency = 0.9

	--------------------------------------------------------------------------
	-- Two rings pulsing outward on the ground, half a beat apart, so the
	-- ground reads as the SOURCE rather than as somewhere a beam happens to
	-- land.
	--------------------------------------------------------------------------
	local rings: { BasePart } = {}
	for i = 1, 2 do
		local ring = cylinder(model, "Ring" .. i, 0.4, 6, CFrame.new(position + Vector3.new(0, 0.35, 0)))
		ring.Transparency = 0.35
		table.insert(rings, ring)
	end

	--------------------------------------------------------------------------
	-- Motes drifting up the shaft. No texture asset — the default particle is
	-- a soft square, which at this size and colour reads as dust in a light
	-- shaft and cannot fail to load.
	--------------------------------------------------------------------------
	local anchor = Instance.new("Part")
	anchor.Name = "Anchor"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(position + Vector3.new(0, 1, 0))
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Parent = model

	local emitAt = Instance.new("Attachment")
	emitAt.Parent = anchor

	local motes = Instance.new("ParticleEmitter")
	motes.Name = "Motes"
	motes.Color = ColorSequence.new(GOLD_BRIGHT)
	motes.LightEmission = 0.8
	motes.LightInfluence = 0
	motes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.4, 0.42),
		NumberSequenceKeypoint.new(1, 0),
	})
	motes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	motes.Lifetime = NumberRange.new(2.2, 3.6)
	motes.Rate = 14
	motes.Speed = NumberRange.new(5, 9)
	motes.SpreadAngle = Vector2.new(9, 9)
	motes.Acceleration = Vector3.new(0, 1.5, 0)
	motes.Rotation = NumberRange.new(0, 360)
	motes.Parent = emitAt

	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Color = GOLD
	light.Brightness = 2.4
	light.Range = 26
	light.Shadows = false
	light.Parent = anchor

	--------------------------------------------------------------------------
	-- The name. AlwaysOnTop is the whole point: a beam is useless the moment a
	-- house is between you and it, and a house is between you and it most of
	-- the time.
	--------------------------------------------------------------------------
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Nameplate"
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromOffset(260, 46)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, LABEL_Y, 0)
	billboard.MaxDistance = 900
	billboard.Parent = anchor

	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.TextScaled = false
	text.TextSize = 17
	text.TextColor3 = CREAM
	text.Text = string.upper(label)
	text.Parent = billboard

	local ok = pcall(function()
		text.FontFace = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
	end)
	if not ok then
		text.Font = Enum.Font.Merriweather
	end

	-- Outlined rather than shadowed: this label has to stay readable against
	-- sky, stone and fire without a panel behind it.
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(0, 0, 0)
	outline.Thickness = 2.5
	outline.Transparency = 0.35
	outline.Parent = text

	model.PrimaryPart = anchor
	model.Parent = parent or Workspace

	--------------------------------------------------------------------------
	-- Motion. Every loop below is a repeating Tween rather than a Heartbeat
	-- connection: the engine drives them, they cost nothing per frame in Luau,
	-- and destroying the instance ends them. A beacon should never be a script
	-- that has to be remembered.
	--------------------------------------------------------------------------
	TweenService:Create(beam, TweenInfo.new(1.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Transparency = 0.8,
	}):Play()

	local self: Beacon
	local ringTweens: { Tween } = {}

	for i, ring in rings do
		local pulse = TweenService:Create(
			ring,
			TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, -1, false),
			{ Size = Vector3.new(0.4, RING_MAX, RING_MAX), Transparency = 1 }
		)
		--[[
			The offset is a delayed START, not TweenInfo's DelayTime. DelayTime
			is inserted before every repetition, so the second ring would reset
			to small-and-bright and then SIT there for a beat before moving.
			Delaying the first Play staggers them and nothing else.
		]]
		if i == 1 then
			pulse:Play()
		else
			task.delay((i - 1) * 1.2, function()
				if ring.Parent then
					pulse:Play()
				end
			end)
		end
		table.insert(ringTweens, pulse)
	end

	--==========================================================================
	self = {
		model = model,
		label = text,
		beam = beam,
		rings = rings,
		light = light,

		setLabel = function(_, value: string)
			text.Text = string.upper(value)
		end,

		--[[
			Recolours the whole beacon at once. The gate uses this: gold when
			the way is open, bordeaux when it is not — the same two colours the
			corner HUD uses, so one language covers the screen and the world.
		]]
		setColor = function(_, colour: Color3)
			beam.Color = colour
			halo.Color = colour
			light.Color = colour
			for _, ring in rings do
				ring.Color = colour
			end
			motes.Color = ColorSequence.new(colour:Lerp(Color3.fromRGB(255, 255, 255), 0.45))
		end,

		-- The anchor IS the PrimaryPart and sits one stud above the marked
		-- point, so the whole model follows from a single absolute pivot.
		moveTo = function(_, to: Vector3)
			model:PivotTo(CFrame.new(to + Vector3.new(0, 1, 0)))
		end,

		destroy = function()
			for _, tween in ringTweens do
				tween:Cancel()
			end
			model:Destroy()
		end,
	}

	return self
end

-- The two colours a beacon is ever allowed to be, so callers do not invent a
-- third. Open/reachable is gold; blocked/hostile is bordeaux.
Beacon.Gold = GOLD
Beacon.Bordeaux = BORDEAUX

return Beacon
