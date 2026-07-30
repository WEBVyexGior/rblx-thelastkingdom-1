--!strict
--[[
	DepartureUI
	The train station's interface: the panel a player gets when they step into a
	wagon.

	Three faces, one screen:
		"create" — this wagon is empty. Pick a party size (1-8), read the mode the
		           game picked for you, and call it.
		"join"   — a party is already forming in this wagon. Take a seat.
		"aboard" — you are on board. One action left: Leave.

	The primary action always lives at the BOTTOM CENTRE of the screen, whatever
	the face — the player's eye never has to go looking for it.

	Each of the four wagons runs its own party, so the panel names the wagon it is
	talking about.

	Presentation only: this module never decides anything. It renders what the
	server sent and reports what the player clicked.

	Location: StarterPlayer.StarterPlayerScripts.Client.UI.DepartureUI
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)

local DepartureUI = {}

export type Status = {
	state: string?,
	count: number?,
	capacity: number?,
	tier: string?,
	seconds: number?,
	wagon: number?,
	members: { string }?,
	leader: string?,
}

export type Callbacks = {
	onCreate: (size: number) -> (),
	onJoin: () -> (),
	onLeave: () -> (),
	onDepartNow: () -> (),
}

local MIN_PARTY = 1
local MAX_PARTY = 8

-- Leave is a smaller commitment than boarding, and its button should read that
-- way: same type, narrower plate, so the label is not marooned in empty space.
local ACTION_WIDE = 340
local ACTION_NARROW = 228

local brand = { Title = "THE LAST KINGDOM", Developer = "by Cookies11f", LogoAssetId = "" }
local callbacks: Callbacks? = nil

local panel: Frame? = nil
local actionButton: TextButton? = nil
local departButton: TextButton? = nil
local chip: TextLabel? = nil
local rosterCard: Frame? = nil
local rosterText: TextLabel? = nil
local notice: TextLabel? = nil
local localName = ""
local isLeader = false

local wagonLabel: TextLabel? = nil
local modeValue: TextLabel? = nil
local subtitle: TextLabel? = nil
local timerLabel: TextLabel? = nil
local stepper: Components.Stepper? = nil
local stepperGroup: Frame? = nil
local modeGroup: Frame? = nil

local face = "hidden"
local lastStatus: Status = {}

--============================================================================
-- Helpers
--============================================================================

local function tierFor(size: number): string
	return if size <= 4 then "NORMAL" else "HARD"
end

local function tierColor(tier: string): Color3
	-- Normal is deliberately grey: it is the absence of danger.
	return if tier:upper() == "HARD" then Theme.Color.BordeauxLight else Theme.Color.Grey
end

local function clock(seconds: number): string
	local whole = math.max(math.floor(seconds), 0)
	return ("%d:%02d"):format(whole // 60, whole % 60)
end

--============================================================================
-- Build
--============================================================================

local function buildPanel(parent: ScreenGui)
	local root = Components.panel({
		Name = "DeparturePanel",
		Size = UDim2.fromOffset(Theme.Size.PanelWidth, 0),
		Position = UDim2.fromScale(0.5, 0.44),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = parent,
	})
	root.AutomaticSize = Enum.AutomaticSize.Y

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(Theme.Size.PanelMin, 0)
	sizeConstraint.MaxSize = Vector2.new(Theme.Size.PanelMax, math.huge)
	sizeConstraint.Parent = root

	Theme.padding(root, Theme.Size.Pad)
	Components.list(root, 12)
	Theme.shadow(root)

	-- Brand. At this size the wordmark carries itself; letter-spacing it would
	-- push it onto two lines.
	if brand.LogoAssetId ~= "" then
		local logo = Instance.new("ImageLabel")
		logo.Name = "Logo"
		logo.Image = brand.LogoAssetId
		logo.BackgroundTransparency = 1
		logo.Size = UDim2.fromOffset(280, 76)
		logo.ScaleType = Enum.ScaleType.Fit
		logo.LayoutOrder = 1
		logo.ZIndex = 3
		logo.Parent = root
	else
		local wordmark = Components.label({
			Name = "Logo",
			Text = brand.Title,
			Role = Theme.Role.Logo,
			TextSize = Theme.TextSize.Logo,
			TextColor = Theme.Color.GoldBright,
			Size = UDim2.new(1, 0, 0, Theme.TextSize.Logo + 12),
			LayoutOrder = 1,
			Gradient = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Theme.Color.GoldBright),
				ColorSequenceKeypoint.new(1, Theme.Color.Gold),
			}),
			Parent = root,
		})
		Theme.thickenText(wordmark, 2)
	end

	Components.label({
		Name = "Developer",
		Text = brand.Developer,
		TextSize = Theme.TextSize.Micro,
		TextColor = Theme.Color.Muted,
		LayoutOrder = 2,
		Parent = root,
	})

	Components.divider(root, 3)

	wagonLabel = Components.label({
		Name = "Wagon",
		Text = "",
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.Gold,
		LayoutOrder = 4,
		Parent = root,
	})

	subtitle = Components.label({
		Name = "Subtitle",
		Text = "Board the train to the Forgotten Lands",
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.Parchment,
		LayoutOrder = 5,
		Parent = root,
	})

	-- Party size.
	stepperGroup = Components.group({
		Name = "PartySize",
		Size = UDim2.new(1, 0, 0, 116),
		LayoutOrder = 6,
		Parent = root,
	})
	Components.list(stepperGroup :: Frame, 4)

	Components.label({
		Name = "PlayersCaption",
		Text = Components.spaced("PLAYERS"),
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.Gold,
		LayoutOrder = 1,
		Parent = stepperGroup,
	})

	stepper = Components.stepper({
		Min = MIN_PARTY,
		Max = MAX_PARTY,
		Value = 4,
		LayoutOrder = 2,
		Parent = stepperGroup,
		OnChanged = function(value)
			DepartureUI.setPreviewTier(tierFor(value))
		end,
	})

	-- Mode, chosen for the player rather than by them.
	modeGroup = Components.group({
		Name = "Mode",
		Size = UDim2.new(1, 0, 0, 70),
		LayoutOrder = 7,
		Parent = root,
	})
	Components.list(modeGroup :: Frame, 2)

	Components.label({
		Name = "ModeCaption",
		Text = "GAME MODE  (AUTOMATED)",
		TextSize = Theme.TextSize.Micro,
		TextColor = Theme.Color.Muted,
		LayoutOrder = 1,
		Parent = modeGroup,
	})

	modeValue = Components.label({
		Name = "ModeValue",
		Text = "NORMAL",
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Heading,
		TextColor = Theme.Color.Grey,
		LayoutOrder = 2,
		Parent = modeGroup,
	})

	Components.divider(root, 8)

	timerLabel = Components.label({
		Name = "Timer",
		Text = "",
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.Muted,
		LayoutOrder = 9,
		Parent = root,
	})

	panel = root
end

-- Everything the player can act on lives in one column anchored to the bottom of
-- the screen. It is a UIListLayout growing UPWARD, so hiding a row (the leader's
-- Depart Now, say) closes the gap instead of leaving a hole.
local function buildBottomStack(parent: ScreenGui)
	local stack = Components.group({
		Name = "BottomStack",
		Size = UDim2.new(0, 460, 0, 0),
		Position = UDim2.new(0.5, 0, 1, -46),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = parent,
	})
	stack.AutomaticSize = Enum.AutomaticSize.Y
	Components.list(stack, 10)

	notice = Components.label({
		Name = "Notice",
		Text = "",
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.BordeauxSoft,
		LayoutOrder = 1,
		Parent = stack,
	})
	;(notice :: TextLabel).Visible = false

	-- Who you are riding with. In a co-op run boarded with strangers, this is the
	-- first thing a player looks for.
	rosterCard = Components.panel({
		Name = "RosterCard",
		Size = UDim2.new(0, 300, 0, 0),
		LayoutOrder = 2,
		Parent = stack,
	})
	local card = rosterCard :: Frame
	card.AutomaticSize = Enum.AutomaticSize.Y
	Theme.padding(card, 12)
	Components.list(card, 4)

	Components.label({
		Name = "Caption",
		Text = Components.spaced("YOUR PARTY"),
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Micro,
		TextColor = Theme.Color.Gold,
		LayoutOrder = 1,
		Parent = card,
	})

	rosterText = Components.label({
		Name = "Members",
		Text = "",
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.Parchment,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 2,
		Parent = card,
	})
	;(rosterText :: TextLabel).AutomaticSize = Enum.AutomaticSize.Y

	chip = Components.label({
		Name = "PartyChip",
		Text = "",
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Body,
		TextColor = Theme.Color.Gold,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 3,
		Parent = stack,
	})

	departButton = Components.button({
		Name = "DepartNow",
		Text = "DEPART NOW",
		Variant = "gold",
		TextSize = Theme.TextSize.Body,
		Size = UDim2.fromOffset(228, 48),
		LayoutOrder = 4,
		Parent = stack,
	})

	actionButton = Components.button({
		Name = "PrimaryAction",
		Text = "CREATE PARTY",
		Variant = "green",
		TextSize = Theme.TextSize.Heading,
		Size = UDim2.fromOffset(ACTION_WIDE, 58),
		LayoutOrder = 5,
		Parent = stack,
	})

	;(departButton :: TextButton).Activated:Connect(function()
		if callbacks and face == "aboard" and isLeader then
			callbacks.onDepartNow()
		end
	end)

	;(actionButton :: TextButton).Activated:Connect(function()
		local handlers = callbacks
		if not handlers then
			return
		end
		if face == "create" then
			handlers.onCreate(if stepper then stepper.get() else 4)
		elseif face == "join" then
			handlers.onJoin()
		elseif face == "aboard" then
			handlers.onLeave()
		end
	end)
end

--============================================================================
-- Faces
--============================================================================

function DepartureUI.setPreviewTier(tier: string)
	if modeValue then
		modeValue.Text = tier:upper()
		modeValue.TextColor3 = tierColor(tier)
	end
end

local function setPanelVisible(visible: boolean)
	local root = panel
	if not root then
		return
	end
	root.Visible = visible
	if visible then
		local scale = root:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		scale.Parent = root
		scale.Scale = 0.92
		TweenService:Create(scale, Theme.Motion.Enter, { Scale = 1 }):Play()
	end
end

local function setAction(text: string, variant: string, visible: boolean)
	local button = actionButton
	if not button then
		return
	end
	button.Visible = visible
	button.Text = text

	-- Repaint and resize for the variant without rebuilding the button. The label
	-- is warm sand-white in both states — the one thing that must never be hard
	-- to read, and pure white looks cold against these colours.
	local gradient = button:FindFirstChildOfClass("UIGradient")
	if gradient then
		if variant == "green" then
			gradient.Color = ColorSequence.new(Theme.Color.GreenLight, Theme.Color.Green)
		else
			gradient.Color = ColorSequence.new(Theme.Color.BordeauxSoft, Theme.Color.BordeauxMid)
		end
	end
	button.TextColor3 = Theme.Color.Cream

	local width = if variant == "green" then ACTION_WIDE else ACTION_NARROW
	TweenService:Create(button, Theme.Motion.Normal, {
		Size = UDim2.fromOffset(width, 58),
	}):Play()
end

local function setBottom(showRoster: boolean, showChip: boolean)
	if rosterCard then
		rosterCard.Visible = showRoster
	end
	if chip then
		chip.Visible = showChip
	end
	if departButton then
		-- Only the person who called the party may cut the wait short.
		departButton.Visible = face == "aboard" and isLeader
	end
end

-- `mode` is one of "hidden" | "create" | "join" | "aboard".
function DepartureUI.setFace(mode: string)
	face = mode

	if mode == "hidden" then
		setPanelVisible(false)
		setAction("", "green", false)
		setBottom(false, false)
		DepartureUI.setNotice(nil)
		return
	end

	if mode == "create" then
		setPanelVisible(true)
		if stepperGroup then
			stepperGroup.Visible = true
		end
		if subtitle then
			subtitle.Text = "Board the train to the Forgotten Lands"
		end
		if stepper then
			DepartureUI.setPreviewTier(tierFor(stepper.get()))
		end
		setAction("CREATE PARTY", "green", true)
		setBottom(false, false)
	elseif mode == "join" then
		setPanelVisible(true)
		if stepperGroup then
			-- The leader already chose the size; a joiner only accepts it.
			stepperGroup.Visible = false
		end
		if subtitle then
			subtitle.Text = "A party is forming in this wagon"
		end
		setAction("JOIN PARTY", "green", true)
		setBottom(true, false)
	elseif mode == "aboard" then
		setPanelVisible(false)
		setAction("LEAVE", "danger", true)
		setBottom(true, true)
	end

	DepartureUI.setStatus(lastStatus)
end

-- A one-line message under the panel: departure failures, mostly. Passing nil
-- clears it.
function DepartureUI.setNotice(message: string?)
	local label = notice
	if not label then
		return
	end
	label.Text = message or ""
	label.Visible = message ~= nil
end

-- Feeds the live server state into whichever face is showing.
function DepartureUI.setStatus(status: Status)
	lastStatus = status

	local count = status.count or 0
	local capacity = status.capacity or 0
	local tier = status.tier or "Normal"
	local seconds = status.seconds or 0

	-- Boarding order is party order, so the first name is the leader.
	local members = if typeof(status.members) == "table" then status.members else {}
	isLeader = status.leader ~= nil and status.leader == localName

	if rosterText then
		local lines: { string } = {}
		for index, name in members do
			table.insert(lines, if index == 1 then ("%s  (leader)"):format(name) else name)
		end
		rosterText.Text = if #lines > 0 then table.concat(lines, "\n") else "—"
	end
	if departButton then
		departButton.Visible = face == "aboard" and isLeader
	end

	if wagonLabel then
		wagonLabel.Text = if status.wagon then ("WAGON %d"):format(status.wagon) else ""
	end

	if face == "join" or face == "aboard" then
		DepartureUI.setPreviewTier(tier)
	end

	if timerLabel then
		if face == "join" then
			timerLabel.Text = ("%d / %d aboard  ·  departing in %s"):format(count, capacity, clock(seconds))
		elseif face == "create" then
			timerLabel.Text = "Choose your party size"
		end
	end

	if chip then
		chip.Text = ("%d / %d  ·  %s  ·  %s"):format(count, capacity, tier:upper(), clock(seconds))
	end
end

-- Countdown on the create panel's own window (how long the offer stands).
function DepartureUI.setWindow(seconds: number)
	if face == "create" and timerLabel then
		timerLabel.Text = ("Closing in %ds"):format(math.max(math.floor(seconds), 0))
	end
end

--============================================================================
-- Lifecycle
--============================================================================

function DepartureUI.mount(handlers: Callbacks, brandConfig: { Title: string?, Developer: string?, LogoAssetId: string? }?)
	callbacks = handlers
	if brandConfig then
		brand.Title = brandConfig.Title or brand.Title
		brand.Developer = brandConfig.Developer or brand.Developer
		brand.LogoAssetId = brandConfig.LogoAssetId or brand.LogoAssetId
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "DepartureUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	localName = Players.LocalPlayer.Name

	buildPanel(gui)
	buildBottomStack(gui)
	DepartureUI.setFace("hidden")
end

return DepartureUI
