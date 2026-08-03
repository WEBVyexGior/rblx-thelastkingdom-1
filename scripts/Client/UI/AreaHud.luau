--!strict
--[[
	AreaHud
	The corner of the screen that says where you are: chamber number, its name,
	and whether the way on is still shut.

	--------------------------------------------------------------------------
	IT IS SMALL ON PURPOSE

	This is the only thing on screen for most of a run, so it has to survive
	being looked at for an hour. Everything here serves that: bottom LEFT, out
	of the way of the crosshair and the right hand; low contrast while nothing
	has changed; and no motion at all except when the state actually changes.

	A HUD that moves while nothing is happening is a HUD you learn to ignore,
	and then it cannot tell you the one thing that matters.

	--------------------------------------------------------------------------
	THE THREE THINGS IT ANIMATES, AND ONLY THESE THREE

	1. Arriving in the castle       — fades up.
	2. Crossing into a new chamber  — dips and returns, so a wall registers.
	3. The gate opening             — the one flourish: bordeaux to gold, the
	                                  rule sweeps, the status line says so for
	                                  a few seconds and then settles back.

	Location: StarterPlayerScripts.Client.UI.AreaHud (a library — the
	controller owns it; this module creates nothing on its own).
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)

local AreaHud = {}

local PANEL_W = 272
local PANEL_H = 86
local PAD = 12
local BASE_DIM = 0.18 -- the panel's resting background transparency

--==========================================================================
export type Handle = {
	gui: ScreenGui,
	show: (index: number, label: string, subtitle: string, locked: boolean) -> (),
	hide: () -> (),
	destroy: () -> (),
}

--==========================================================================
--[[
	Builds the panel. One ScreenGui, and every element inside it is created
	once and then only re-worded — rebuilding on each update would restart the
	fade and make the thing flicker every time a player crosses a room.
]]
function AreaHud.create(): Handle
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "AreaHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local root = Instance.new("Frame")
	root.Name = "Panel"
	root.AnchorPoint = Vector2.new(0, 1)
	root.Position = UDim2.new(0, 24, 1, -24)
	root.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
	root.BackgroundColor3 = Theme.Color.Ink
	root.BackgroundTransparency = BASE_DIM
	root.BorderSizePixel = 0
	root.Parent = gui

	Theme.corner(root)
	Theme.surface(root, Theme.Color.Navy, Theme.Color.Void)
	Theme.padding(root, PAD)
	local stroke = Theme.goldStroke(root, 1)
	stroke.Transparency = 0.55

	--[[
		A gold rule down the left edge. It is the cheapest possible way to make
		a rectangle look designed rather than defaulted, and it is the element
		that turns red when the gate is shut — a colour change in the corner of
		the eye, which is all the alert this needs.
	]]
	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.AnchorPoint = Vector2.new(0, 0.5)
	rule.Position = UDim2.new(0, -6, 0.5, 0)
	rule.Size = UDim2.new(0, 3, 1, 2)
	rule.BackgroundColor3 = Theme.Color.Gold
	rule.BorderSizePixel = 0
	rule.Parent = root
	Theme.corner(rule, UDim.new(0, 2))

	-- AREA 3
	local number = Instance.new("TextLabel")
	number.Name = "Number"
	number.BackgroundTransparency = 1
	number.Position = UDim2.fromOffset(0, 0)
	number.Size = UDim2.new(1, 0, 0, 16)
	number.TextXAlignment = Enum.TextXAlignment.Left
	number.TextYAlignment = Enum.TextYAlignment.Center
	number.TextSize = 14
	number.TextColor3 = Theme.Color.Gold
	number.Text = "AREA 1"
	number.Parent = root
	Theme.applyFont(number, Theme.Role.Strong)

	-- KITCHENS
	local name = Instance.new("TextLabel")
	name.Name = "AreaName"
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(0, 18)
	name.Size = UDim2.new(1, 0, 0, 24)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextYAlignment = Enum.TextYAlignment.Center
	name.TextSize = 22
	name.TextColor3 = Theme.Color.Cream
	name.Text = "OUTER WARD"
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Parent = root
	Theme.applyFont(name, Theme.Role.Heading)

	-- The status line: the flavour text, or the fact that you cannot leave.
	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromOffset(0, 45)
	status.Size = UDim2.new(1, 0, 0, 16)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextYAlignment = Enum.TextYAlignment.Center
	status.TextSize = 13
	status.TextColor3 = Theme.Color.Muted
	status.TextTruncate = Enum.TextTruncate.AtEnd
	status.Text = ""
	status.Parent = root
	Theme.applyFont(status, Theme.Role.Body)

	--==========================================================================
	local shownIndex: number? = nil
	local shownLocked: boolean? = nil
	local settleToken = 0

	local function fade(to: number, seconds: number)
		local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad)
		TweenService:Create(root, info, {
			BackgroundTransparency = BASE_DIM + to * (1 - BASE_DIM),
		}):Play()
		for _, label in { number, name, status } do
			TweenService:Create(label, info, { TextTransparency = to }):Play()
		end
		TweenService:Create(stroke, info, { Transparency = 0.55 + to * 0.45 }):Play()
		TweenService:Create(rule, info, { BackgroundTransparency = to }):Play()
	end

	--[[
		The gate came up. Three seconds of gold and one line of text, then it
		puts itself away — the player is already running for the arch and does
		not need a banner following them into the next room.
	]]
	local function announceOpen(subtitle: string)
		settleToken += 1
		local token = settleToken

		status.Text = "THE WAY ON IS OPEN"
		status.TextColor3 = Theme.Color.GoldBright

		rule.Size = UDim2.new(0, 3, 0, 0)
		rule.BackgroundColor3 = Theme.Color.GoldBright
		TweenService:Create(rule, TweenInfo.new(0.55, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 3, 1, 2),
		}):Play()

		TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 0.1 }):Play()

		task.delay(3, function()
			if settleToken ~= token or not gui.Parent then
				return
			end
			status.Text = subtitle
			TweenService:Create(status, TweenInfo.new(0.5), { TextColor3 = Theme.Color.Muted }):Play()
			TweenService:Create(rule, TweenInfo.new(0.5), { BackgroundColor3 = Theme.Color.Gold }):Play()
			TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 0.55 }):Play()
		end)
	end

	local handle: Handle
	handle = {
		gui = gui,

		show = function(index: number, label: string, subtitle: string, locked: boolean)
			local isNewRoom = shownIndex ~= index
			-- The gate of the room you are standing in just went up.
			local justOpened = not isNewRoom and shownLocked == true and not locked

			shownIndex = index
			shownLocked = locked

			number.Text = ("AREA %d"):format(index)
			name.Text = label

			if justOpened then
				announceOpen(subtitle)
			else
				settleToken += 1 -- cancel any flourish still waiting to settle
				status.Text = if locked then "The way on is shut." else subtitle

				--[[
					Shut is bordeaux, open is gold. Not red/green: this palette
					is navy, black, gold and bordeaux, and a stoplight green in
					the corner would be the one thing on screen belonging to
					another game.
				]]
				local accent = if locked then Theme.Color.BordeauxSoft else Theme.Color.Gold
				status.TextColor3 = if locked then Theme.Color.BordeauxSoft else Theme.Color.Muted
				rule.Size = UDim2.new(0, 3, 1, 2)
				TweenService:Create(rule, TweenInfo.new(0.35), { BackgroundColor3 = accent }):Play()
			end

			if not gui.Enabled then
				gui.Enabled = true
				fade(1, 0)
				fade(0, 0.4)
			elseif isNewRoom then
				-- A new room gets a brief dip, so crossing a wall registers
				-- without the panel ever animating while you stand still.
				fade(0.65, 0.12)
				task.delay(0.12, function()
					if gui.Parent then
						fade(0, 0.3)
					end
				end)
			end
		end,

		hide = function()
			if not gui.Enabled then
				return
			end
			shownIndex = nil
			shownLocked = nil
			settleToken += 1
			fade(1, 0.35)
			task.delay(0.35, function()
				if gui.Parent and shownIndex == nil then
					gui.Enabled = false
				end
			end)
		end,

		destroy = function()
			settleToken += 1
			gui:Destroy()
		end,
	}

	return handle
end

return AreaHud
