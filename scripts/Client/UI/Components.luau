--!strict
--[[
	Components
	Reusable UI widgets built from Theme tokens: panels, labels, rules, buttons and
	the numeric stepper. Screens compose these instead of building raw Instances, so
	every surface in the game shares one look and one set of interactions.

	Every widget takes a props table and returns the Instance it created (the
	stepper returns a small handle, since it owns state).

	Location: StarterPlayer.StarterPlayerScripts.Client.UI.Components
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Components = {}

export type PanelProps = {
	Name: string?,
	Parent: Instance?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	ZIndex: number?,
	Translucent: boolean?,
}

export type LabelProps = {
	Name: string?,
	Parent: Instance?,
	Text: string?,
	Role: string?, -- Theme.Role.*
	TextSize: number?,
	TextColor: Color3?,
	TextXAlignment: Enum.TextXAlignment?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	RichText: boolean?,
	Gradient: ColorSequence?,
}

export type ButtonProps = {
	Name: string?,
	Parent: Instance?,
	Text: string?,
	Variant: string?, -- "gold" | "green" | "ghost"
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	TextSize: number?,
}

export type StepperProps = {
	Parent: Instance?,
	Min: number,
	Max: number,
	Value: number,
	LayoutOrder: number?,
	OnChanged: ((value: number) -> ())?,
}

export type Stepper = {
	instance: Frame,
	get: () -> number,
	set: (value: number) -> (),
}

-- Widens a word into a letter-spaced inscription. Roblox has no letter-spacing,
-- and the logo has to read as engraved rather than typed.
function Components.spaced(text: string): string
	local letters = {}
	for _, code in utf8.codes(text) do
		table.insert(letters, utf8.char(code))
	end
	return table.concat(letters, " ")
end

--============================================================================
-- Surfaces
--============================================================================

function Components.panel(props: PanelProps): Frame
	local frame = Instance.new("Frame")
	frame.Name = props.Name or "Panel"
	frame.Size = props.Size or UDim2.fromScale(1, 1)
	frame.Position = props.Position or UDim2.fromScale(0, 0)
	frame.AnchorPoint = props.AnchorPoint or Vector2.zero
	frame.BackgroundColor3 = Theme.Color.Navy
	frame.BackgroundTransparency = if props.Translucent then 0.12 else 0
	frame.BorderSizePixel = 0
	frame.LayoutOrder = props.LayoutOrder or 0
	frame.ZIndex = props.ZIndex or 2

	Theme.surface(frame, Theme.Color.NavyLight, Theme.Color.Void)
	Theme.corner(frame)

	local stroke = Theme.goldStroke(frame, Theme.Size.StrokeHeavy)
	local gradient = stroke:FindFirstChildOfClass("UIGradient")
	if gradient then
		Theme.shimmer(gradient)
	end

	frame.Parent = props.Parent
	return frame
end

-- A transparent row/column container. Layout only — no paint.
function Components.group(props: PanelProps): Frame
	local frame = Instance.new("Frame")
	frame.Name = props.Name or "Group"
	frame.Size = props.Size or UDim2.new(1, 0, 0, 0)
	frame.Position = props.Position or UDim2.fromScale(0, 0)
	frame.AnchorPoint = props.AnchorPoint or Vector2.zero
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.LayoutOrder = props.LayoutOrder or 0
	frame.ZIndex = props.ZIndex or 2
	frame.Parent = props.Parent
	return frame
end

function Components.list(parent: GuiObject, padding: number, alignment: Enum.HorizontalAlignment?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = alignment or Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, padding)
	layout.Parent = parent
	return layout
end

function Components.row(parent: GuiObject, padding: number): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, padding)
	layout.Parent = parent
	return layout
end

--============================================================================
-- Text
--============================================================================

function Components.label(props: LabelProps): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = props.Name or "Label"
	label.Text = props.Text or ""
	Theme.applyFont(label, props.Role or Theme.Role.Body)
	label.TextSize = props.TextSize or Theme.TextSize.Body
	label.TextColor3 = props.TextColor or Theme.Color.Parchment
	label.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center
	label.TextWrapped = true
	label.RichText = props.RichText == true
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Size = props.Size or UDim2.new(1, 0, 0, (props.TextSize or Theme.TextSize.Body) + 6)
	label.Position = props.Position or UDim2.fromScale(0, 0)
	label.AnchorPoint = props.AnchorPoint or Vector2.zero
	label.LayoutOrder = props.LayoutOrder or 0
	label.ZIndex = 3

	if props.Gradient then
		local gradient = Instance.new("UIGradient")
		gradient.Color = props.Gradient
		gradient.Rotation = 90
		gradient.Parent = label
	end

	label.Parent = props.Parent
	return label
end

-- A hairline gold rule that fades out at both ends, like a tooled edge.
function Components.divider(parent: Instance, layoutOrder: number?): Frame
	local rule = Instance.new("Frame")
	rule.Name = "Divider"
	rule.Size = UDim2.new(1, 0, 0, 1)
	rule.BackgroundColor3 = Theme.Color.Gold
	rule.BorderSizePixel = 0
	rule.LayoutOrder = layoutOrder or 0
	rule.ZIndex = 3

	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = rule

	rule.Parent = parent
	return rule
end

--============================================================================
-- Buttons
--============================================================================

local VARIANTS = {
	gold = { top = Theme.Color.GoldDim, bottom = Theme.Color.Void, text = Theme.Color.GoldBright },
	green = { top = Theme.Color.GreenLight, bottom = Theme.Color.Green, text = Theme.Color.Cream },
	ghost = { top = Theme.Color.Navy, bottom = Theme.Color.Ink, text = Theme.Color.Parchment },
	-- Pure white glyphs: the stepper's +/- read as grey against the panel
	-- otherwise, and they are the control the player uses most.
	light = { top = Theme.Color.NavyLight, bottom = Theme.Color.Navy, text = Theme.Color.White },
	danger = { top = Theme.Color.BordeauxSoft, bottom = Theme.Color.BordeauxMid, text = Theme.Color.Cream },
}

function Components.button(props: ButtonProps): TextButton
	local variant = VARIANTS[props.Variant or "ghost"] or VARIANTS.ghost

	local button = Instance.new("TextButton")
	button.Name = props.Name or "Button"
	button.Text = props.Text or ""
	Theme.applyFont(button, Theme.Role.Heading)
	button.TextSize = props.TextSize or Theme.TextSize.Body
	button.TextColor3 = variant.text
	button.AutoButtonColor = false
	button.BackgroundColor3 = variant.bottom
	button.BorderSizePixel = 0
	button.Size = props.Size or UDim2.new(1, 0, 0, 44)
	button.Position = props.Position or UDim2.fromScale(0, 0)
	button.AnchorPoint = props.AnchorPoint or Vector2.zero
	button.LayoutOrder = props.LayoutOrder or 0
	button.ZIndex = 3

	Theme.surface(button, variant.top, variant.bottom)
	Theme.corner(button, Theme.Size.CornerSmall)

	-- Every button carries a metal border, per the art direction.
	local stroke = Theme.goldStroke(button, Theme.Size.Stroke)

	-- Scale (not Size) drives hover/press, so a button inside a UIListLayout
	-- never nudges its neighbours while animating.
	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = button

	local function tweenTo(target: number, thickness: number)
		TweenService:Create(scale, Theme.Motion.Fast, { Scale = target }):Play()
		TweenService:Create(stroke, Theme.Motion.Fast, { Thickness = thickness }):Play()
	end

	button.MouseEnter:Connect(function()
		tweenTo(1.03, Theme.Size.StrokeHeavy)
	end)
	button.MouseLeave:Connect(function()
		tweenTo(1, Theme.Size.Stroke)
	end)
	button.MouseButton1Down:Connect(function()
		tweenTo(0.97, Theme.Size.StrokeHeavy)
	end)
	button.MouseButton1Up:Connect(function()
		tweenTo(1.03, Theme.Size.StrokeHeavy)
	end)

	button.Parent = props.Parent
	return button
end

--============================================================================
-- Stepper
--============================================================================

-- The [-] N [+] control. Minus sits left, plus sits right.
function Components.stepper(props: StepperProps): Stepper
	local value = math.clamp(props.Value, props.Min, props.Max)

	local frame = Components.group({
		Name = "Stepper",
		Size = UDim2.new(1, 0, 0, 78),
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
	})
	Components.row(frame, 20)

	local minus = Components.button({
		Name = "Minus",
		Text = "–",
		Variant = "light",
		Size = UDim2.fromOffset(62, 62),
		TextSize = Theme.TextSize.Heading,
		LayoutOrder = 1,
		Parent = frame,
	})

	local readout = Components.label({
		Name = "Value",
		Text = tostring(value),
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Display,
		TextColor = Theme.Color.GoldBright,
		Size = UDim2.fromOffset(110, 74),
		LayoutOrder = 2,
		Parent = frame,
	})

	local plus = Components.button({
		Name = "Plus",
		Text = "+",
		Variant = "light",
		Size = UDim2.fromOffset(62, 62),
		TextSize = Theme.TextSize.Heading,
		LayoutOrder = 3,
		Parent = frame,
	})

	local function apply(next: number)
		local clamped = math.clamp(next, props.Min, props.Max)
		if clamped == value then
			return
		end
		value = clamped
		readout.Text = tostring(value)

		-- A small kick on change, so the number feels physical.
		local scale = readout:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		scale.Parent = readout
		scale.Scale = 1.25
		TweenService:Create(scale, Theme.Motion.Normal, { Scale = 1 }):Play()

		if props.OnChanged then
			props.OnChanged(value)
		end
	end

	minus.Activated:Connect(function()
		apply(value - 1)
	end)
	plus.Activated:Connect(function()
		apply(value + 1)
	end)

	return {
		instance = frame,
		get = function(): number
			return value
		end,
		set = apply,
	}
end

return Components
