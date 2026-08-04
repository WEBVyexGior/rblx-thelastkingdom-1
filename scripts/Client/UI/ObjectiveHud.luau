--!strict
--[[
	ObjectiveHud
	One line at the top of the screen saying what to do. "Cut the barricade."
	"Find the recipe." "Cook five meals."

	--------------------------------------------------------------------------
	NO PANEL

	Small white letters with a thin black edge, typed out a character at a time,
	and nothing behind them. The brief was explicit and it is the right call: a
	box at the top of the screen eats the sky, and the sky is most of what this
	game has to look at. Subtitles have worked this way forever for the same
	reason.

	The typing is the same effect the NPC dialogue uses, deliberately — it is
	how this game says "read this" — but with no bubble and no name plate, so it
	reads as the game thinking out loud rather than as somebody talking.

	--------------------------------------------------------------------------
	SOURCES, AND WHY IT IS A STACK

	More than one system wants this line. The mission has an objective; the area
	mechanic has a more immediate instruction ("three lashings left") that should
	win while it is up, and when it finishes the mission's line should come BACK
	rather than the screen going blank.

	So each system pushes under its own name and clears under its own name, and
	the newest live one is shown. Nobody has to know what else is on screen.

	Location: StarterPlayerScripts.Client.UI.ObjectiveHud (a library).
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)

local ObjectiveHud = {}

local CHARS_PER_SECOND = 34
local TOP_MARGIN = 54

export type Handle = {
	gui: ScreenGui,
	set: (source: string, text: string?) -> (),
	clearAll: () -> (),
	destroy: () -> (),
}

--==========================================================================
function ObjectiveHud.create(): Handle
	local player = Players.LocalPlayer

	local gui = Instance.new("ScreenGui")
	gui.Name = "ObjectiveHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 4
	gui.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Name = "Line"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, TOP_MARGIN)
	label.Size = UDim2.new(0.8, 0, 0, 22)
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextSize = 17
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextTransparency = 1
	label.TextWrapped = true
	label.Text = ""
	label.Parent = gui
	Theme.applyFont(label, Theme.Role.Body)

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 2
	stroke.Transparency = 0.4
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label

	--==========================================================================
	-- Newest live source wins; clearing one falls back to the one under it.
	local order: { string } = {}
	local texts: { [string]: string } = {}

	local typeToken = 0
	local shownText: string? = nil

	local function topText(): string?
		for i = #order, 1, -1 do
			local source = order[i]
			if texts[source] then
				return texts[source]
			end
		end
		return nil
	end

	--[[
		Types the line out. Steps by UNICODE character rather than by byte —
		the same lesson the dialogue box learned: half a multi-byte character
		renders as rubbish for one frame, and there are accented characters in
		this game's text.
	]]
	local function typeOut(text: string)
		typeToken += 1
		local token = typeToken

		label.Text = ""
		label.TextTransparency = 0
		TweenService:Create(stroke, TweenInfo.new(0.2), { Transparency = 0.4 }):Play()

		task.spawn(function()
			local shown = ""
			for _, code in utf8.codes(text) do
				if token ~= typeToken then
					return
				end
				shown ..= utf8.char(code)
				label.Text = shown
				task.wait(1 / CHARS_PER_SECOND)
			end
		end)
	end

	local function fadeOut()
		typeToken += 1
		TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
			TextTransparency = 1,
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
			Transparency = 1,
		}):Play()
	end

	--[[
		Re-reads the stack and shows whatever is on top. Doing nothing when the
		top line has not changed is what stops a mechanic that updates its
		counter from retyping an identical sentence every second.
	]]
	local function refresh()
		local want = topText()
		if want == shownText then
			return
		end
		shownText = want
		if want then
			typeOut(want)
		else
			fadeOut()
		end
	end

	--==========================================================================
	local handle: Handle
	handle = {
		gui = gui,

		set = function(source: string, text: string?)
			if text == nil then
				texts[source] = nil
			else
				if texts[source] == nil then
					table.insert(order, source)
				end
				texts[source] = text
			end
			refresh()
		end,

		clearAll = function()
			order = {}
			texts = {}
			refresh()
		end,

		destroy = function()
			typeToken += 1
			gui:Destroy()
		end,
	}

	return handle
end

return ObjectiveHud
