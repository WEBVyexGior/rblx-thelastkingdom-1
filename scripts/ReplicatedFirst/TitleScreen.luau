--!strict
--[[
	TitleScreen
	The first thing a player sees: the game's name, a question, and a button.

	It is a title card, not a progress dialog. It does not leave on its own — it
	waits for PLAY. That is the whole trick: the seconds a player spends reading
	"THE LAST KINGDOM · Will you survive?" and reaching for the button are
	seconds the world spends loading behind the blur. They read; the game gets
	ready; nobody watches a bar.

	The lines arrive one at a time, a second apart, because a title card that
	appears all at once is read in half a second and the time is lost.

	WHY THIS FILE REPEATS THE PALETTE instead of using Shared.UI.Theme:
	ReplicatedFirst replicates BEFORE everything else — that is what lets this
	appear on the first frame — so ReplicatedStorage may not exist yet when it
	runs. Waiting for Theme would defeat the entire point. If the palette
	changes, change these too.

	Location: ReplicatedFirst.TitleScreen
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local TitleScreen = {}

--==========================================================================
-- Tuning
--==========================================================================
local BEAT = 1 -- seconds between the title, the question and the button
local BLUR = 28 -- how hard the world behind is hidden

local VOID = Color3.fromRGB(7, 8, 11)
local BORDEAUX = Color3.fromRGB(58, 11, 19)
local GOLD = Color3.fromRGB(198, 158, 66)
local GOLD_BRIGHT = Color3.fromRGB(242, 216, 142)
local GOLD_DIM = Color3.fromRGB(112, 84, 30)
local PARCHMENT = Color3.fromRGB(237, 227, 206)
local MUTED = Color3.fromRGB(146, 130, 118)
local CREAM = Color3.fromRGB(249, 240, 218)
local GREEN = Color3.fromRGB(44, 88, 56)
local GREEN_LIGHT = Color3.fromRGB(74, 132, 84)

local SERIF = "rbxasset://fonts/families/Merriweather.json"
local DISPLAY = "rbxasset://fonts/families/Fondamento.json"

local RISE = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

--==========================================================================
-- Helpers
--==========================================================================
local function font(target: TextLabel | TextButton, family: string, weight: Enum.FontWeight)
	pcall(function()
		target.FontFace = Font.new(family, weight)
	end)
end

--[[
	A fixed-height slot in the list, holding one element that is free to move.

	A UIListLayout owns the Position of its direct children, so animating a
	label's Position inside one does nothing — the layout puts it straight back.
	Giving each beat its own holder keeps the list stable while the element
	inside it slides freely.
]]
local function holder(parent: Instance, order: number, height: number): Frame
	local slot = Instance.new("Frame")
	slot.Name = "Slot" .. order
	slot.Size = UDim2.new(1, 0, 0, height)
	slot.BackgroundTransparency = 1
	slot.LayoutOrder = order
	slot.ZIndex = 3
	slot.Parent = parent
	return slot
end

-- Everything arrives the same way: a little low, invisible, then up and in.
local function reveal(target: GuiObject, delay: number)
	local home = target.Position
	target.Position = home + UDim2.fromOffset(0, 18)

	if target:IsA("TextLabel") or target:IsA("TextButton") then
		target.TextTransparency = 1
	end
	local stroke = target:FindFirstChildOfClass("UIStroke")
	local strokeAlpha = if stroke then stroke.Transparency else 0
	if stroke then
		stroke.Transparency = 1
	end
	local wasBackground = target.BackgroundTransparency
	target.BackgroundTransparency = 1

	task.delay(delay, function()
		if not target.Parent then
			return
		end
		TweenService:Create(target, RISE, { Position = home }):Play()
		if target:IsA("TextLabel") or target:IsA("TextButton") then
			TweenService:Create(target, RISE, { TextTransparency = 0 }):Play()
		end
		if wasBackground < 1 then
			TweenService:Create(target, RISE, { BackgroundTransparency = wasBackground }):Play()
		end
		if stroke then
			TweenService:Create(stroke, RISE, { Transparency = strokeAlpha }):Play()
		end
	end)
end

--==========================================================================
-- Show
--==========================================================================
export type Handle = {
	setProgress: (fraction: number) -> (),
	dismiss: () -> (),
	onPlay: (callback: () -> ()) -> (),
}

function TitleScreen.show(): Handle
	local player = Players.LocalPlayer
	while not player do
		Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
		player = Players.LocalPlayer
	end
	local playerGui = player:WaitForChild("PlayerGui")

	-- Blur rather than a flat cover: the world is still there behind it, which
	-- makes the card feel like part of the game instead of a page in front of it.
	local blur = Instance.new("BlurEffect")
	blur.Name = "TitleBlur"
	blur.Size = BLUR
	blur.Parent = Lighting

	local gui = Instance.new("ScreenGui")
	gui.Name = "TitleScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = BORDEAUX
	backdrop.BackgroundTransparency = 0.06
	backdrop.BorderSizePixel = 0
	backdrop.ZIndex = 1
	backdrop.Parent = gui

	local wash = Instance.new("UIGradient")
	wash.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, VOID),
		ColorSequenceKeypoint.new(0.45, BORDEAUX),
		ColorSequenceKeypoint.new(1, VOID),
	})
	wash.Rotation = 90
	wash.Parent = backdrop

	-- A gold rule inset from the edges, like the border of a printed plate.
	local frame = Instance.new("Frame")
	frame.Name = "Border"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.new(1, -56, 1, -56)
	frame.BackgroundTransparency = 1
	frame.ZIndex = 2
	frame.Parent = gui

	local border = Instance.new("UIStroke")
	border.Color = GOLD
	border.Thickness = 1.5
	border.Transparency = 0.35
	border.Parent = frame

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.AnchorPoint = Vector2.new(0.5, 0.5)
	content.Position = UDim2.fromScale(0.5, 0.47)
	content.Size = UDim2.new(0, 760, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.BackgroundTransparency = 1
	content.ZIndex = 3
	content.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = content

	--------------------------------------------------------------------------
	-- Beat 1: the name
	--------------------------------------------------------------------------
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Text = "THE LAST KINGDOM"
	title.TextSize = 62
	title.TextColor3 = GOLD_BRIGHT
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 1)
	title.ZIndex = 4
	font(title, DISPLAY, Enum.FontWeight.Bold)
	title.Parent = holder(content, 1, 78)

	local titleGradient = Instance.new("UIGradient")
	titleGradient.Color = ColorSequence.new(GOLD_BRIGHT, GOLD)
	titleGradient.Rotation = 90
	titleGradient.Parent = title

	local titleStroke = Instance.new("UIStroke")
	titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	titleStroke.Color = GOLD_BRIGHT
	titleStroke.Thickness = 0.9
	titleStroke.Parent = title

	local credit = Instance.new("TextLabel")
	credit.Name = "Credit"
	credit.Text = "by Cookies11f"
	credit.TextSize = 20
	credit.TextColor3 = MUTED
	credit.BackgroundTransparency = 1
	credit.Size = UDim2.fromScale(1, 1)
	credit.ZIndex = 4
	font(credit, SERIF, Enum.FontWeight.Regular)
	credit.Parent = holder(content, 2, 26)

	--------------------------------------------------------------------------
	-- Beat 2: the question
	--------------------------------------------------------------------------
	local spacer = Instance.new("Frame")
	spacer.Name = "Spacer"
	spacer.Size = UDim2.new(1, 0, 0, 24)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 3
	spacer.Parent = content

	local question = Instance.new("TextLabel")
	question.Name = "Question"
	question.Text = "Will you survive?"
	question.TextSize = 40
	question.TextColor3 = PARCHMENT
	question.BackgroundTransparency = 1
	question.Size = UDim2.fromScale(1, 1)
	question.ZIndex = 4
	font(question, SERIF, Enum.FontWeight.Bold)
	question.Parent = holder(content, 4, 52)

	--------------------------------------------------------------------------
	-- Beat 3: the way in
	--------------------------------------------------------------------------
	local spacer2 = Instance.new("Frame")
	spacer2.Name = "Spacer2"
	spacer2.Size = UDim2.new(1, 0, 0, 28)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 5
	spacer2.Parent = content

	local play = Instance.new("TextButton")
	play.Name = "Play"
	play.Text = "PLAY"
	play.TextSize = 30
	play.TextColor3 = CREAM
	play.AutoButtonColor = false
	play.BackgroundColor3 = GREEN
	play.BorderSizePixel = 0
	play.Size = UDim2.fromOffset(340, 66)
	play.AnchorPoint = Vector2.new(0.5, 0)
	play.Position = UDim2.fromScale(0.5, 0)
	play.ZIndex = 4
	font(play, SERIF, Enum.FontWeight.Bold)
	play.Parent = holder(content, 6, 66)

	local playGradient = Instance.new("UIGradient")
	playGradient.Color = ColorSequence.new(GREEN_LIGHT, GREEN)
	playGradient.Rotation = 90
	playGradient.Parent = play

	local playCorner = Instance.new("UICorner")
	playCorner.CornerRadius = UDim.new(0, 3)
	playCorner.Parent = play

	local playStroke = Instance.new("UIStroke")
	playStroke.Color = GOLD
	playStroke.Thickness = 2
	playStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	playStroke.Parent = play

	local playScale = Instance.new("UIScale")
	playScale.Parent = play
	play.MouseEnter:Connect(function()
		TweenService:Create(playScale, TweenInfo.new(0.12), { Scale = 1.04 }):Play()
	end)
	play.MouseLeave:Connect(function()
		TweenService:Create(playScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)

	--------------------------------------------------------------------------
	-- A thin seam along the bottom edge. Deliberately quiet: it is reassurance
	-- that something is happening, not the thing being looked at.
	--------------------------------------------------------------------------
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.Position = UDim2.new(0.5, 0, 1, -44)
	track.Size = UDim2.fromOffset(420, 2)
	track.BackgroundColor3 = GOLD_DIM
	track.BackgroundTransparency = 0.55
	track.BorderSizePixel = 0
	track.ZIndex = 3
	track.Parent = gui

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = GOLD_BRIGHT
	fill.BorderSizePixel = 0
	fill.ZIndex = 4
	fill.Parent = track

	--------------------------------------------------------------------------
	-- Staging
	--------------------------------------------------------------------------
	reveal(title, 0)
	reveal(credit, 0.15)
	reveal(question, BEAT)
	reveal(play, BEAT * 2)

	--------------------------------------------------------------------------
	-- Handle
	--------------------------------------------------------------------------
	local dismissed = false
	local playCallback: (() -> ())? = nil

	local function dismiss()
		if dismissed then
			return
		end
		dismissed = true

		TweenService:Create(blur, FADE, { Size = 0 }):Play()
		TweenService:Create(backdrop, FADE, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(border, FADE, { Transparency = 1 }):Play()
		for _, item in gui:GetDescendants() do
			if item:IsA("TextLabel") or item:IsA("TextButton") then
				TweenService:Create(item, FADE, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			elseif item:IsA("Frame") then
				TweenService:Create(item, FADE, { BackgroundTransparency = 1 }):Play()
			elseif item:IsA("UIStroke") then
				TweenService:Create(item, FADE, { Transparency = 1 }):Play()
			end
		end

		task.delay(0.8, function()
			gui:Destroy()
			blur:Destroy()
		end)
	end

	play.Activated:Connect(function()
		if playCallback then
			playCallback()
		end
		dismiss()
	end)

	return {
		setProgress = function(fraction: number)
			TweenService:Create(fill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
				Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1),
			}):Play()
		end,
		dismiss = dismiss,
		onPlay = function(callback: () -> ())
			playCallback = callback
		end,
	}
end

return TitleScreen
