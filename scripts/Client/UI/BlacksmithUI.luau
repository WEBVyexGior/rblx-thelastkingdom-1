--!strict
--[[
	BlacksmithUI
	The forge screen: your weapons, what they hit for, and what the next level
	costs.

	Built around one question the player should be able to answer in a second —
	"is this worth my gold?" — so every row states the price and the exact damage
	it buys, side by side. No percentages, no hidden maths.

	Two tabs from the start. Armour is not built yet, but the blacksmith owns it
	too, and adding a second tab later would have meant redesigning the header.

	Presentation only: the server decides every price and every purchase.

	Location: StarterPlayer.StarterPlayerScripts.Client.UI.BlacksmithUI
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)

local BlacksmithUI = {}

export type Entry = {
	id: string,
	name: string,
	level: number,
	maxLevel: number,
	maxed: boolean,
	damage: number,
	baseDamage: number,
	gain: number,
	cost: number,
	affordable: boolean,
	cooldown: number,
	range: number,
	invested: number,
	locked: boolean,
	requiredLevel: number,
}

export type State = { gold: number, playerLevel: number, stock: { Entry } }

local onUpgrade: ((weaponId: string) -> ())? = nil
local onClosed: (() -> ())? = nil

local screen: ScreenGui? = nil
local panel: Frame? = nil
local goldLabel: TextLabel? = nil
local listFrame: Frame? = nil
local noticeLabel: TextLabel? = nil
local tabButtons: { [string]: TextButton } = {}

local activeTab = "Weapons"
local lastState: State? = nil

--============================================================================
-- Rows
--============================================================================

local function clearList()
	local list = listFrame
	if not list then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function statLine(parent: Instance, order: number, text: string)
	Components.label({
		Name = "Stat",
		Text = text,
		TextSize = Theme.TextSize.Micro,
		TextColor = Theme.Color.SteelLight,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Parent = parent,
	})
end

local function buildRow(entry: Entry, order: number)
	local row = Components.panel({
		Name = entry.id,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = order,
		Parent = listFrame,
	})
	row.AutomaticSize = Enum.AutomaticSize.Y
	Theme.padding(row, 14)

	local columns = Instance.new("UIListLayout")
	columns.FillDirection = Enum.FillDirection.Horizontal
	columns.SortOrder = Enum.SortOrder.LayoutOrder
	columns.VerticalAlignment = Enum.VerticalAlignment.Center
	columns.Padding = UDim.new(0, 12)
	columns.Parent = row

	-- Left: the weapon and what it does.
	local details = Components.group({
		Name = "Details",
		Size = UDim2.new(1, -210, 0, 0),
		LayoutOrder = 1,
		Parent = row,
	})
	details.AutomaticSize = Enum.AutomaticSize.Y
	Components.list(details, 2, Enum.HorizontalAlignment.Left)

	Components.label({
		Name = "Name",
		Text = if entry.locked
			then ("%s   —   LOCKED"):format(entry.name:upper())
			else ("%s   +%d"):format(entry.name:upper(), entry.level),
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Small,
		TextColor = if entry.locked then Theme.Color.Muted else Theme.Color.GoldBright,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		Parent = details,
	})

	if entry.locked then
		statLine(details, 2, ("Requires level %d"):format(entry.requiredLevel))
	else
		statLine(details, 2, ("Damage %d      Speed %.2fs      Reach %d"):format(
			entry.damage,
			entry.cooldown,
			entry.range
		))
		statLine(details, 3, ("Forged at %d    ·    %d / %d    ·    %d gold invested"):format(
			entry.baseDamage,
			entry.level,
			entry.maxLevel,
			entry.invested or 0
		))
	end

	-- Right: the one decision.
	local action = Components.group({
		Name = "Action",
		Size = UDim2.fromOffset(196, 76),
		LayoutOrder = 2,
		Parent = row,
	})
	Components.list(action, 4)

	if entry.locked then
		Components.label({
			Name = "Gate",
			Text = "—",
			TextSize = Theme.TextSize.Body,
			TextColor = Theme.Color.Muted,
			LayoutOrder = 1,
			Parent = action,
		})
		return
	end

	if entry.maxed then
		Components.label({
			Name = "Maxed",
			Text = "FULLY FORGED",
			Role = Theme.Role.Heading,
			TextSize = Theme.TextSize.Micro,
			TextColor = Theme.Color.EmberBright,
			LayoutOrder = 1,
			Parent = action,
		})
		return
	end

	-- The gain goes ABOVE the button: what you get, then what it costs.
	Components.label({
		Name = "Gain",
		Text = ("+%d damage"):format(entry.gain),
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Micro,
		TextColor = Theme.Color.EmberBright,
		LayoutOrder = 1,
		Parent = action,
	})

	local button = Components.button({
		Name = "Upgrade",
		Text = ("%d GOLD"):format(entry.cost),
		Variant = if entry.affordable then "ember" else "ghost",
		TextSize = Theme.TextSize.Small,
		Size = UDim2.fromOffset(190, 44),
		LayoutOrder = 2,
		Parent = action,
	})

	if not entry.affordable then
		Components.setTextColor(button, Theme.Color.Muted)
	end

	button.Activated:Connect(function()
		if onUpgrade and entry.affordable then
			onUpgrade(entry.id)
		elseif not entry.affordable then
			BlacksmithUI.setNotice("Not enough gold.")
		end
	end)
end

--============================================================================
-- Build
--============================================================================

local function selectTab(name: string)
	activeTab = name
	for tabName, button in tabButtons do
		local active = tabName == name
		Components.setTextColor(button, if active then Theme.Color.GoldBright else Theme.Color.Muted)
	end
	if lastState then
		BlacksmithUI.setState(lastState)
	end
end

local function build(parent: ScreenGui)
	local root = Components.panel({
		Name = "ForgePanel",
		Size = UDim2.fromOffset(720, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = parent,
	})
	root.AutomaticSize = Enum.AutomaticSize.Y

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(480, 0)
	constraint.MaxSize = Vector2.new(820, 640)
	constraint.Parent = root

	Theme.padding(root, Theme.Size.Pad)
	Components.list(root, 10)
	Theme.shadow(root)

	Components.label({
		Name = "Title",
		Text = Components.spaced("THE FORGE"),
		Role = Theme.Role.Logo,
		TextSize = Theme.TextSize.Heading,
		TextColor = Theme.Color.EmberBright,
		LayoutOrder = 1,
		Parent = root,
	})

	goldLabel = Components.label({
		Name = "Gold",
		Text = "",
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Body,
		TextColor = Theme.Color.GoldBright,
		LayoutOrder = 2,
		Parent = root,
	})

	Components.divider(root, 3)

	-- Tabs. Armour is here from day one so the header never has to be redesigned.
	local tabs = Components.group({
		Name = "Tabs",
		Size = UDim2.new(1, 0, 0, 46),
		LayoutOrder = 4,
		Parent = root,
	})
	Components.row(tabs, 10)

	for index, name in { "Weapons", "Armour" } do
		local button = Components.button({
			Name = name,
			Text = name:upper(),
			Variant = "ghost",
			TextSize = Theme.TextSize.Small,
			Size = UDim2.fromOffset(180, 42),
			LayoutOrder = index,
			Parent = tabs,
		})
		button.Activated:Connect(function()
			selectTab(name)
		end)
		tabButtons[name] = button
	end

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Stock"
	scroller.Size = UDim2.new(1, 0, 0, 340)
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 4
	scroller.ScrollBarImageColor3 = Theme.Color.Gold
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.CanvasSize = UDim2.new()
	scroller.LayoutOrder = 5
	scroller.ZIndex = 3
	scroller.Parent = root
	Components.list(scroller, 8)
	listFrame = scroller :: any

	noticeLabel = Components.label({
		Name = "Notice",
		Text = "",
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.EmberBright,
		LayoutOrder = 6,
		Parent = root,
	})

	local close = Components.button({
		Name = "Close",
		Text = "LEAVE THE FORGE",
		Variant = "ghost",
		TextSize = Theme.TextSize.Small,
		Size = UDim2.new(1, 0, 0, 46),
		LayoutOrder = 7,
		Parent = root,
	})
	close.Activated:Connect(function()
		BlacksmithUI.close()
	end)

	panel = root
	root.Visible = false
end

--============================================================================
-- API
--============================================================================

function BlacksmithUI.mount(handlers: { onUpgrade: (string) -> (), onClose: (() -> ())? })
	onUpgrade = handlers.onUpgrade
	onClosed = handlers.onClose

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "BlacksmithUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 19
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	screen = gui
	build(gui)
	selectTab("Weapons")
end

function BlacksmithUI.setState(state: State)
	lastState = state

	if goldLabel then
		goldLabel.Text = ("%d GOLD        LEVEL %d"):format(state.gold, state.playerLevel)
	end

	clearList()

	if activeTab == "Armour" then
		Components.label({
			Name = "Empty",
			Text = "The armourer's bench is cold. Nothing to fit yet.",
			TextSize = Theme.TextSize.Small,
			TextColor = Theme.Color.Muted,
			LayoutOrder = 1,
			Parent = listFrame,
		})
		return
	end

	for index, entry in state.stock do
		buildRow(entry, index)
	end
end

function BlacksmithUI.setNotice(message: string?)
	local label = noticeLabel
	if not label then
		return
	end
	label.Text = message or ""
end

function BlacksmithUI.open()
	local root = panel
	if not root then
		return
	end
	BlacksmithUI.setNotice(nil)
	root.Visible = true

	local scale = root:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = root
	scale.Scale = 0.94
	TweenService:Create(scale, Theme.Motion.Enter, { Scale = 1 }):Play()
end

function BlacksmithUI.close()
	if panel then
		panel.Visible = false
	end
	if onClosed then
		onClosed()
	end
end

function BlacksmithUI.isOpen(): boolean
	return panel ~= nil and panel.Visible
end

return BlacksmithUI
