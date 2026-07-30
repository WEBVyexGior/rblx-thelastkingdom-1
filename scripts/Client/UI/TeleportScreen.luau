--!strict
--[[
	TeleportScreen
	The screen a player sees while they are being moved between the two places.

	Without this, Roblox shows its own grey loading screen — which lands exactly at
	the most cinematic moment in the game and breaks the spell. This replaces it
	with the game's own face.

	IMPORTANT — this screen is FROZEN. Roblox clones the GUI and displays it
	without running any of its scripts, so nothing here can animate: no tweens, no
	shimmer, no spinner. Everything it does must be done with static paint, which
	is why the depth comes from layered gradients and rules rather than motion.

	Built once at boot and handed to TeleportService:SetTeleportGui.

	Location: StarterPlayer.StarterPlayerScripts.Client.UI.TeleportScreen
]]

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)

local TeleportScreen = {}

export type Copy = {
	Headline: string?,
	Line: string?,
	Footer: string?,
	Title: string?,
	Developer: string?,
}

-- A still gold rule. Components.divider is identical in look, but this one is
-- built here so the screen never picks up an animated ancestor by accident.
local function rule(parent: Instance, order: number, width: number)
	local line = Instance.new("Frame")
	line.Name = "Rule"
	line.Size = UDim2.new(0, width, 0, 1)
	line.BackgroundColor3 = Theme.Color.Gold
	line.BorderSizePixel = 0
	line.LayoutOrder = order
	line.ZIndex = 3

	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = line

	line.Parent = parent
end

function TeleportScreen.build(copy: Copy?): ScreenGui
	local text: Copy = copy or {}

	local gui = Instance.new("ScreenGui")
	gui.Name = "TeleportScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Backdrop: near-black, lifted very slightly in the middle so the screen has
	-- a centre rather than reading as a flat void.
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Theme.Color.Void
	backdrop.BorderSizePixel = 0
	backdrop.ZIndex = 1
	backdrop.Parent = gui

	local wash = Instance.new("UIGradient")
	wash.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.Color.Void),
		ColorSequenceKeypoint.new(0.5, Theme.Color.Ink),
		ColorSequenceKeypoint.new(1, Theme.Color.Void),
	})
	wash.Rotation = 90
	wash.Parent = backdrop

	-- Two hairlines across the full width frame the composition like a title card.
	local frame = Instance.new("Frame")
	frame.Name = "Content"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.new(0, 620, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundTransparency = 1
	frame.ZIndex = 2
	frame.Parent = gui

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(320, 0)
	constraint.MaxSize = Vector2.new(680, math.huge)
	constraint.Parent = frame

	Components.list(frame, 16)

	local wordmark = Components.label({
		Name = "Logo",
		Text = text.Title or "THE LAST KINGDOM",
		Role = Theme.Role.Logo,
		TextSize = Theme.TextSize.Logo + 8,
		TextColor = Theme.Color.GoldBright,
		Size = UDim2.new(1, 0, 0, Theme.TextSize.Logo + 22),
		LayoutOrder = 1,
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.Color.GoldBright),
			ColorSequenceKeypoint.new(1, Theme.Color.GoldDim),
		}),
		Parent = frame,
	})
	Theme.thickenText(wordmark, 2.4)

	rule(frame, 2, 420)

	Components.label({
		Name = "Headline",
		Text = Components.spaced(text.Headline or "FORTY YEARS FROM HOME"),
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.Parchment,
		LayoutOrder = 3,
		Parent = frame,
	})

	Components.label({
		Name = "Line",
		Text = text.Line or "The road back begins.",
		TextSize = Theme.TextSize.Body,
		TextColor = Theme.Color.Muted,
		Size = UDim2.new(1, 0, 0, Theme.TextSize.Body + 10),
		LayoutOrder = 4,
		Parent = frame,
	})

	rule(frame, 5, 220)

	Components.label({
		Name = "Footer",
		Text = text.Footer or "Preparing the Forgotten Lands…",
		TextSize = Theme.TextSize.Micro,
		TextColor = Theme.Color.GoldDim,
		LayoutOrder = 6,
		Parent = frame,
	})

	-- The credit sits on the screen edge, not in the stack: it belongs to the
	-- game, not to this moment.
	Components.label({
		Name = "Developer",
		Text = text.Developer or "by Cookies11f",
		TextSize = Theme.TextSize.Micro,
		TextColor = Theme.Color.Muted,
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 1, -36),
		Parent = gui,
	})

	return gui
end

return TeleportScreen
