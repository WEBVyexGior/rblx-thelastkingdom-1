--!strict
--[[
	Theme
	The game's UI design system: the SINGLE source of every colour, font, size and
	motion timing the interface uses. Screens never hard-code a Color3 or a
	TweenInfo — they read them from here, so the whole game restyles from one file.

	Art direction (locked): realistic medieval luxury. Deep navy and near-black
	surfaces, antique gold rules and borders, bordeaux for danger/weight, parchment
	for text. Nothing bright, nothing cartoon, nothing flat — every surface is a
	gradient and every border is metal.

	Location: StarterPlayer.StarterPlayerScripts.Client.UI.Theme
]]

local TweenService = game:GetService("TweenService")

local Theme = {}

--============================================================================
-- Colour
--============================================================================

Theme.Color = {
	-- Surfaces, darkest to lightest. Panels layer these to fake depth.
	Void = Color3.fromRGB(7, 8, 11),
	Ink = Color3.fromRGB(15, 17, 23),
	Navy = Color3.fromRGB(23, 29, 44),
	NavyLight = Color3.fromRGB(35, 44, 64),

	-- Bordeaux: the royal accent. Weight, danger, "Hard".
	Bordeaux = Color3.fromRGB(78, 15, 25),
	BordeauxLight = Color3.fromRGB(126, 30, 43),
	-- A lifted pair for the Leave action: still unmistakably red, but light
	-- enough to read at a glance instead of sinking into the panel behind it.
	BordeauxSoft = Color3.fromRGB(158, 58, 68),
	BordeauxMid = Color3.fromRGB(116, 34, 46),

	-- Gold. Three stops, because one flat yellow never reads as metal.
	GoldDim = Color3.fromRGB(112, 84, 30),
	Gold = Color3.fromRGB(198, 158, 66),
	GoldBright = Color3.fromRGB(242, 216, 142),

	-- Text.
	Parchment = Color3.fromRGB(237, 227, 206),
	-- Warm sand-white for text sitting on strong colour: pure white reads cold
	-- and clinical against the gold and bordeaux.
	Cream = Color3.fromRGB(249, 240, 218),
	White = Color3.fromRGB(255, 255, 255),
	Grey = Color3.fromRGB(154, 160, 166), -- the "Normal" mode grey
	Muted = Color3.fromRGB(120, 118, 112),

	-- The one green: the "go" action. Deep and desaturated — a campaign banner,
	-- not an arcade button.
	Green = Color3.fromRGB(44, 88, 56),
	GreenLight = Color3.fromRGB(74, 132, 84),
	GreenBright = Color3.fromRGB(126, 196, 138),

	Shadow = Color3.fromRGB(0, 0, 0),
}

--============================================================================
-- Contrast
--============================================================================

--[[
	THE RULE, and it is not negotiable: text on a dark surface is mostly WHITE.

	The temptation is to tint a label with the surface's own colour — green text
	on green, red on red — because it looks tasteful in isolation. On a dark
	button it is unreadable, and the darker and richer the surface, the worse it
	gets.

	So a label takes 70-80% white and keeps only a fifth of its colour: enough to
	belong to the button, never enough to disappear into it. `onDark` is how every
	foreground colour in this game is produced — reach for it before typing a
	Color3 for anything sitting on a dark background.
]]
function Theme.onDark(accent: Color3, whiteRatio: number?): Color3
	return accent:Lerp(Theme.Color.White, whiteRatio or 0.8)
end

--============================================================================
-- Type
--============================================================================

-- Merriweather is the closest built-in match to Century Schoolbook / Times: a
-- sturdy, sharp serif that stays legible at a distance. Fondamento is reserved
-- for the logo alone — the wordmark may be calligraphic, the interface may not.
local FAMILY = {
	Serif = "rbxasset://fonts/families/Merriweather.json",
	Display = "rbxasset://fonts/families/Fondamento.json",
}

local FALLBACK = {
	Serif = Enum.Font.Merriweather,
	Display = Enum.Font.Fondamento,
}

Theme.Role = {
	Logo = "Logo",
	Heading = "Heading",
	Body = "Body",
	Strong = "Strong",
}

local ROLES = {
	Logo = { family = FAMILY.Display, fallback = FALLBACK.Display, weight = Enum.FontWeight.Bold },
	Heading = { family = FAMILY.Serif, fallback = FALLBACK.Serif, weight = Enum.FontWeight.Bold },
	Body = { family = FAMILY.Serif, fallback = FALLBACK.Serif, weight = Enum.FontWeight.Regular },
	Strong = { family = FAMILY.Serif, fallback = FALLBACK.Serif, weight = Enum.FontWeight.Bold },
}

-- Applies a type role. FontFace carries real weights (the enum Font property has
-- no bold for these families); if the family asset is ever unavailable we fall
-- back to the plain enum rather than rendering nothing.
function Theme.applyFont(target: TextLabel | TextButton, role: string)
	local spec = ROLES[role] or ROLES.Body
	local ok = pcall(function()
		target.FontFace = Font.new(spec.family, spec.weight)
	end)
	if not ok then
		target.Font = spec.fallback
	end
end

-- Thickens glyphs beyond what a font weight can give. A display face like
-- Fondamento has no heavy cut, so the wordmark is weighted by outlining the text
-- in its own colour — which also works on any font, whatever weights it ships.
function Theme.thickenText(target: TextLabel, thickness: number?, color: Color3?)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = color or target.TextColor3
	stroke.Thickness = thickness or 1.6
	stroke.Parent = target
	return stroke
end

-- Sized up across the board after the first playtest read too small on screen.
-- Every step moved by the same proportion, so the hierarchy is unchanged.
Theme.TextSize = {
	Logo = 40,
	Micro = 18, -- the developer credit
	Small = 22,
	Body = 26,
	Heading = 32,
	Display = 64, -- the player-count numeral
}

Theme.Size = {
	Corner = UDim.new(0, 4), -- medieval reads square; just enough to soften
	CornerSmall = UDim.new(0, 3),
	Stroke = 1.5,
	StrokeHeavy = 2.5,
	Pad = 22,
	PanelWidth = 520,
	PanelMin = 430,
	PanelMax = 600,
}

--============================================================================
-- Motion
--============================================================================

Theme.Motion = {
	Fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Normal = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Enter = TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Exit = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	-- Looping ambience: gold catching the light, and an urgent countdown beat.
	Shimmer = TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	Pulse = TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
}

--============================================================================
-- Primitives
--============================================================================

function Theme.corner(parent: GuiObject, radius: UDim?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or Theme.Size.Corner
	corner.Parent = parent
	return corner
end

function Theme.padding(parent: GuiObject, amount: number?): UIPadding
	local value = UDim.new(0, amount or Theme.Size.Pad)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = value
	padding.PaddingBottom = value
	padding.PaddingLeft = value
	padding.PaddingRight = value
	padding.Parent = parent
	return padding
end

-- A vertical surface gradient: lighter at the top, sinking to near-black. This
-- is what stops a Frame from looking like flat coloured paper.
function Theme.surface(parent: GuiObject, top: Color3, bottom: Color3): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = 90
	gradient.Parent = parent
	return gradient
end

-- A gold border that actually looks like metal: a gradient runs along the stroke
-- so its edges are dim and its middle catches light.
function Theme.goldStroke(parent: GuiObject, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Color.Gold
	stroke.Thickness = thickness or Theme.Size.Stroke
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.Color.GoldDim),
		ColorSequenceKeypoint.new(0.5, Theme.Color.GoldBright),
		ColorSequenceKeypoint.new(1, Theme.Color.GoldDim),
	})
	gradient.Rotation = 25
	gradient.Parent = stroke

	return stroke
end

-- Slides a gradient back and forth forever — the shimmer that sells the gold.
-- Returns the tween so a caller can stop it when the screen closes.
function Theme.shimmer(gradient: UIGradient): Tween
	gradient.Offset = Vector2.new(-1, 0)
	local tween = TweenService:Create(gradient, Theme.Motion.Shimmer, { Offset = Vector2.new(1, 0) })
	tween:Play()
	return tween
end

-- A soft drop shadow built from stacked translucent frames — no image asset, so
-- it can never fail to load.
--
-- The frames are SIBLINGS of the target, not children: Roblox's default
-- ZIndexBehavior.Sibling draws a child in front of its parent whatever its
-- ZIndex, so a shadow parented inside would sit on top of the very panel it is
-- meant to sit behind. `target` must therefore live somewhere without a layout.
function Theme.shadow(target: GuiObject, layers: number?)
	local container = target.Parent
	if not container then
		return
	end

	local count = layers or 4
	local shades: { Frame } = {}
	for i = count, 1, -1 do
		local shade = Instance.new("Frame")
		shade.Name = target.Name .. "Shadow" .. i
		shade.BackgroundColor3 = Theme.Color.Shadow
		shade.BackgroundTransparency = 0.7 + (i * 0.07)
		shade.BorderSizePixel = 0
		shade.ZIndex = target.ZIndex - 1
		shade.Parent = container
		Theme.corner(shade, UDim.new(0, 8))
		shades[i] = shade
	end

	-- The target may be AutomaticSize and may be shown/hidden, so the shadow
	-- tracks it rather than copying its geometry once at build time.
	local function sync()
		local absolute = target.AbsoluteSize
		for i, shade in shades do
			local spread = i * 4
			shade.AnchorPoint = target.AnchorPoint
			shade.Position = target.Position + UDim2.fromOffset(0, 3)
			shade.Size = UDim2.fromOffset(absolute.X + spread * 2, absolute.Y + spread * 2)
			shade.Visible = target.Visible
		end
	end

	sync()
	target:GetPropertyChangedSignal("AbsoluteSize"):Connect(sync)
	target:GetPropertyChangedSignal("Position"):Connect(sync)
	target:GetPropertyChangedSignal("Visible"):Connect(sync)
end

return Theme
