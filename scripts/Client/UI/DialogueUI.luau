--!strict
--[[
	DialogueUI
	The panel an NPC speaks through. One screen serves every character in the
	lobby — the storyteller now, the blacksmith and merchant next — because what
	changes between them is words, not interface.

	The text is typed out rather than dropped in: a wall of text appearing at once
	reads as a sign, and these are meant to read as somebody talking. Clicking
	while it types finishes the line instead of skipping it, so an impatient
	player is never punished.

	Built from the same Theme as everything else: dark panel, gold rules, serif
	type, action at the bottom.

	Location: StarterPlayer.StarterPlayerScripts.Client.UI.DialogueUI
]]

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)

local DialogueUI = {}

export type Script = {
	Title: string?,
	Lines: { string },
}

local cfg: any = nil
local typeSound: Sound? = nil

local panel: Frame? = nil
local titleLabel: TextLabel? = nil
local bodyLabel: TextLabel? = nil
local hintLabel: TextLabel? = nil
local nextButton: TextButton? = nil
local closeButton: TextButton? = nil

local lines: { string } = {}
local index = 0
local typing = false
local typeToken = 0
local onClosed: (() -> ())? = nil

--============================================================================
-- Typing
--============================================================================

local function stopTyping()
	typeToken += 1
	typing = false
end

local showLine: (position: number) -> ()

local function typeLine(text: string)
	local label = bodyLabel
	if not label then
		return
	end

	stopTyping()
	typeToken += 1
	local token = typeToken
	typing = true
	label.Text = ""

	task.spawn(function()
		-- Step by unicode character, not by byte: a multi-byte character revealed
		-- half way through renders as rubbish.
		local shown = ""
		local since = 0
		for _, code in utf8.codes(text) do
			if token ~= typeToken then
				return
			end
			shown ..= utf8.char(code)
			label.Text = shown

			since += 1
			if typeSound and since >= cfg.TypeSoundEvery then
				since = 0
				typeSound:Play()
			end

			task.wait(1 / cfg.CharactersPerSecond)
		end
		if token ~= typeToken then
			return
		end
		typing = false
		if hintLabel then
			hintLabel.Visible = true
		end

		-- The scene plays itself: hold on the finished line, then move on. The
		-- opening line gets longer, because it is the one that has to land.
		if cfg.AutoAdvance and index < #lines then
			local hold = if index == 1 then cfg.FirstHoldSeconds else cfg.HoldSeconds
			task.wait(hold)
			if token == typeToken and not typing then
				showLine(index + 1)
			end
		end
	end)
end

function showLine(position: number)
	index = position
	if hintLabel then
		hintLabel.Visible = false
	end
	typeLine(lines[index] or "")

	local isLast = index >= #lines
	if nextButton then
		-- The last line waits: the player leaves when they are ready, not when a
		-- timer decides they have read enough.
		Components.setText(nextButton, if isLast then "FAREWELL" else "CONTINUE")
	end
end

--============================================================================
-- Build
--============================================================================

local function build(parent: ScreenGui)
	local root = Components.panel({
		Name = "DialoguePanel",
		Size = UDim2.fromOffset(640, 0),
		Position = UDim2.new(0.5, 0, 1, -60),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = parent,
	})
	root.AutomaticSize = Enum.AutomaticSize.Y

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(420, 0)
	constraint.MaxSize = Vector2.new(760, math.huge)
	constraint.Parent = root

	Theme.padding(root, Theme.Size.Pad)
	Components.list(root, 10)
	Theme.shadow(root)

	titleLabel = Components.label({
		Name = "Title",
		Text = "",
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.Gold,
		LayoutOrder = 1,
		Parent = root,
	})

	Components.divider(root, 2)

	bodyLabel = Components.label({
		Name = "Body",
		Text = "",
		TextSize = Theme.TextSize.Body,
		TextColor = Theme.Color.Parchment,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 3,
		Parent = root,
	})
	local body = bodyLabel :: TextLabel
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.TextXAlignment = Enum.TextXAlignment.Left
	-- Room for the longest line, so the panel does not jump height as it types.
	local bodyMin = Instance.new("UISizeConstraint")
	bodyMin.MinSize = Vector2.new(0, 76)
	bodyMin.Parent = body

	hintLabel = Components.label({
		Name = "Hint",
		Text = "",
		TextSize = Theme.TextSize.Micro,
		TextColor = Theme.Color.Muted,
		LayoutOrder = 4,
		Parent = root,
	})
	;(hintLabel :: TextLabel).Visible = false

	local actions = Components.group({
		Name = "Actions",
		Size = UDim2.new(1, 0, 0, 54),
		LayoutOrder = 5,
		Parent = root,
	})
	Components.row(actions, 12)

	closeButton = Components.button({
		Name = "Close",
		Text = "LEAVE",
		Variant = "ghost",
		TextSize = Theme.TextSize.Body,
		Size = UDim2.fromOffset(180, 50),
		LayoutOrder = 1,
		Parent = actions,
	})

	nextButton = Components.button({
		Name = "Next",
		Text = "CONTINUE",
		Variant = "gold",
		TextSize = Theme.TextSize.Body,
		Size = UDim2.fromOffset(240, 50),
		LayoutOrder = 2,
		Parent = actions,
	})

	;(nextButton :: TextButton).Activated:Connect(function()
		if typing then
			-- Impatience finishes the line; it never skips it.
			stopTyping()
			if bodyLabel then
				bodyLabel.Text = lines[index] or ""
			end
			if hintLabel then
				hintLabel.Visible = true
			end
			return
		end
		if index >= #lines then
			DialogueUI.close()
		else
			showLine(index + 1)
		end
	end)

	;(closeButton :: TextButton).Activated:Connect(function()
		DialogueUI.close()
	end)

	panel = root
	root.Visible = false
end

--============================================================================
-- API
--============================================================================

function DialogueUI.mount()
	cfg = Config.get("Interactions").Dialogue

	-- Only built if a sound has actually been uploaded. A missing asset id would
	-- otherwise mean a silent Sound object ticking away for nothing.
	if cfg.TypeSoundId ~= "" then
		local sound = Instance.new("Sound")
		sound.SoundId = cfg.TypeSoundId
		sound.Volume = cfg.TypeSoundVolume
		sound.Parent = SoundService
		typeSound = sound
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "DialogueUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 18
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	build(gui)
end

function DialogueUI.open(script_: Script, closed: (() -> ())?)
	local root = panel
	if not root then
		return
	end

	lines = script_.Lines
	onClosed = closed

	if titleLabel then
		titleLabel.Text = Components.spaced(script_.Title or "")
	end
	if hintLabel then
		hintLabel.Text = "Click CONTINUE to hear the rest"
	end

	root.Visible = true
	local scale = root:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = root
	scale.Scale = 0.94
	TweenService:Create(scale, Theme.Motion.Enter, { Scale = 1 }):Play()

	showLine(1)
end

function DialogueUI.close()
	stopTyping()
	if panel then
		panel.Visible = false
	end
	local callback = onClosed
	onClosed = nil
	if callback then
		callback()
	end
end

function DialogueUI.isOpen(): boolean
	return panel ~= nil and panel.Visible
end

return DialogueUI
