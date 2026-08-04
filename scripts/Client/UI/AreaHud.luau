--!strict
--[[
	AreaHud
	The name of the room you are standing in, bottom left. That is all it is and
	all it will ever be.

	--------------------------------------------------------------------------
	WHAT IT LOOKS LIKE, AND WHY

	Antique gold letters and a thin black outline on bare screen. No panel, no
	border, no background, no status line, no "locked". It says the name and
	nothing else: this thing is on screen for an hour and every extra pixel is
	something the player has to keep ignoring.

	Gold rather than white because it is the game's colour — the wordmark, the
	buttons, the borders — and a white readout in the corner reads as a debug
	overlay somebody forgot to take out.

	The outline is what lets the panel be dropped: gold on lit stone is
	unreadable, gold with a 2px black edge is readable on anything, which is how
	subtitles have always worked.

	--------------------------------------------------------------------------
	THE ONLY MOTION

	Crossing into a new room. The old name lifts and fades out, a hairline rule
	sweeps in under the new one, the new name rises into place, and the rule
	fades. Under a second, and nothing moves at any other time.

	Location: StarterPlayerScripts.Client.UI.AreaHud (a library — the controller
	owns it; this module creates nothing on its own).
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)

local AreaHud = {}

local MARGIN = 28
local RISE = 14 -- how far a name travels as it arrives or leaves
local STROKE_BASE = 0.3 -- the outline's opacity when the name is fully up
local OUT = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local IN = TweenInfo.new(0.46, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

export type Handle = {
	gui: ScreenGui,
	show: (index: number, label: string) -> (),
	hide: () -> (),
	destroy: () -> (),
}

--==========================================================================
--[[
	A label and its outline, kept together.

	They are ONE thing and have to be faded as one. The first version tweened
	only `TextTransparency`, so a room's name left the screen and its black
	outline stayed behind — the player crossed into the Stables and the words
	OUTER WARD were still sitting there as a dark smear under the new name.
	Anything that fades a label from here on fades the pair.
]]
type Slot = {
	label: TextLabel,
	stroke: UIStroke,
}

local function setAlpha(slot: Slot, alpha: number, info: TweenInfo?)
	if info then
		TweenService:Create(slot.label, info, { TextTransparency = alpha }):Play()
		TweenService:Create(slot.stroke, info, { Transparency = STROKE_BASE + alpha * (1 - STROKE_BASE) }):Play()
	else
		slot.label.TextTransparency = alpha
		slot.stroke.Transparency = STROKE_BASE + alpha * (1 - STROKE_BASE)
	end
end

--==========================================================================
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

	--[[
		A container anchored to the bottom-left corner. Everything inside is
		positioned relative to it, so the whole readout can be nudged by moving
		one frame — and it has no background of its own, so there is nothing to
		see except the letters.
	]]
	local root = Instance.new("Frame")
	root.Name = "Area"
	root.AnchorPoint = Vector2.new(0, 1)
	root.Position = UDim2.new(0, MARGIN, 1, -MARGIN)
	root.Size = UDim2.fromOffset(420, 46)
	root.BackgroundTransparency = 1
	root.ClipsDescendants = false
	root.Parent = gui

	--[[
		TWO labels, not one. A name that changes has to be able to leave while
		the next one arrives — swapping the text on a single label makes the old
		room's name visibly turn into the new one's, which reads as a glitch
		rather than a transition.
	]]
	local function makeSlot(): Slot
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0, 1)
		label.Position = UDim2.new(0, 0, 1, 0)
		label.Size = UDim2.new(1, 0, 0, 34)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Bottom
		label.TextSize = 30
		label.TextColor3 = Theme.Color.Gold
		label.TextTransparency = 1
		label.Text = ""
		label.Parent = root
		Theme.applyFont(label, Theme.Role.Heading)

		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.Color = Color3.fromRGB(0, 0, 0)
		stroke.Thickness = 2
		stroke.Transparency = 1
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = label

		return { label = label, stroke = stroke }
	end

	local slotA, slotB = makeSlot(), makeSlot()
	local front = slotA

	--[[
		The rule that sweeps in under a new name. It is the whole reason the
		change reads as deliberate rather than as a label being overwritten, and
		it costs one Frame.
	]]
	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.AnchorPoint = Vector2.new(0, 1)
	rule.Position = UDim2.new(0, 0, 1, 4)
	rule.Size = UDim2.new(0, 0, 0, 1)
	rule.BackgroundColor3 = Theme.Color.Gold
	rule.BackgroundTransparency = 0.25
	rule.BorderSizePixel = 0
	rule.Parent = root

	--==========================================================================
	local shownIndex: number? = nil

	local function sweepRule()
		rule.Size = UDim2.new(0, 0, 0, 1)
		rule.BackgroundTransparency = 0.2
		TweenService:Create(rule, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 168, 0, 1),
		}):Play()
		TweenService:Create(rule, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		}):Play()
	end

	local function swapTo(text: string, animate: boolean)
		local leaving = front
		local arriving = if front == slotA then slotB else slotA
		front = arriving

		arriving.label.Text = text

		if not animate then
			arriving.label.Position = UDim2.new(0, 0, 1, 0)
			setAlpha(arriving, 0)
			setAlpha(leaving, 1)
			return
		end

		-- Out: lift and fade. Text AND outline, together — see the note on Slot.
		setAlpha(leaving, 1, OUT)
		TweenService:Create(leaving.label, OUT, {
			Position = UDim2.new(0, 0, 1, -RISE),
		}):Play()

		-- In: rise from below into place.
		arriving.label.Position = UDim2.new(0, 0, 1, RISE)
		setAlpha(arriving, 1)
		setAlpha(arriving, 0, IN)
		TweenService:Create(arriving.label, IN, {
			Position = UDim2.new(0, 0, 1, 0),
		}):Play()

		sweepRule()
	end

	--==========================================================================
	local handle: Handle
	handle = {
		gui = gui,

		--[[
			`index` is taken and ignored on purpose: the server still sends it,
			the design says the player is shown the NAME and nothing else, and
			the day that changes this signature does not have to.
		]]
		show = function(index: number, label: string)
			local firstTime = not gui.Enabled
			if shownIndex == index and not firstTime then
				return
			end
			shownIndex = index

			if firstTime then
				gui.Enabled = true
				swapTo(label, false)
				-- Even the first appearance gets the rule, so arriving in the
				-- castle feels like arriving somewhere.
				setAlpha(front, 1)
				setAlpha(front, 0, IN)
				sweepRule()
			else
				swapTo(label, true)
			end
		end,

		hide = function()
			if not gui.Enabled then
				return
			end
			shownIndex = nil
			local leaving = front
			setAlpha(leaving, 1, OUT)
			TweenService:Create(leaving.label, OUT, {
				Position = UDim2.new(0, 0, 1, -RISE),
			}):Play()
			task.delay(0.3, function()
				if gui.Parent and shownIndex == nil then
					gui.Enabled = false
				end
			end)
		end,

		destroy = function()
			gui:Destroy()
		end,
	}

	return handle
end

return AreaHud
