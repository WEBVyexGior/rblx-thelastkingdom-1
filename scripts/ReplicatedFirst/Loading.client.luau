--!strict
--[[
	Loading
	The first thing a player sees, and the only thing they see until the world is
	actually ready.

	Roblox drops you into the place the moment the server accepts you — before
	meshes, textures and terrain have arrived. Without this you watch the lobby
	assemble itself around you: grey trees popping in, the ground appearing late,
	decorations arriving after the buildings they were meant to hide.

	So: hide it. Cover the screen immediately, preload the lobby's content while
	the player reads, and only then let them in. A Skip appears once half of it
	is through, for anyone who would rather not wait.

	WHY THIS FILE REPEATS THE PALETTE instead of using Shared.UI.Theme:
	ReplicatedFirst is replicated BEFORE everything else — that is the whole
	point of it, and it is what lets this appear instantly. ReplicatedStorage may
	not exist yet when this runs, so waiting for Theme would defeat the purpose.
	The handful of values below are duplicated deliberately. If the palette
	changes, change them here too.

	Location: ReplicatedFirst.Loading (a LocalScript, runs before anything else)
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

--==========================================================================
-- Tuning
--==========================================================================
local SKIP_AT = 0.5 -- fraction preloaded before Skip is offered
local MIN_SECONDS = 2.5 -- never flash past; the wordmark should be read
local MAX_SECONDS = 25 -- never trap anyone, whatever goes wrong

local VOID = Color3.fromRGB(7, 8, 11)
local INK = Color3.fromRGB(15, 17, 23)
local GOLD = Color3.fromRGB(198, 158, 66)
local GOLD_BRIGHT = Color3.fromRGB(242, 216, 142)
local GOLD_DIM = Color3.fromRGB(112, 84, 30)
local PARCHMENT = Color3.fromRGB(237, 227, 206)
local MUTED = Color3.fromRGB(120, 118, 112)
local CREAM = Color3.fromRGB(249, 240, 218)

local SERIF = "rbxasset://fonts/families/Merriweather.json"
local DISPLAY = "rbxasset://fonts/families/Fondamento.json"

--==========================================================================
-- Screen
--==========================================================================
ReplicatedFirst:RemoveDefaultLoadingScreen()

-- ReplicatedFirst runs early enough that LocalPlayer can still be nil.
local player = Players.LocalPlayer
while not player do
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	player = Players.LocalPlayer
end
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000 -- above everything, including the departure panel
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = VOID
backdrop.BorderSizePixel = 0
backdrop.ZIndex = 1
backdrop.Parent = gui

local wash = Instance.new("UIGradient")
wash.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, VOID),
	ColorSequenceKeypoint.new(0.5, INK),
	ColorSequenceKeypoint.new(1, VOID),
})
wash.Rotation = 90
wash.Parent = backdrop

local function label(name: string, text: string, size: number, colour: Color3, family: string, order: number)
	local item = Instance.new("TextLabel")
	item.Name = name
	item.Text = text
	item.TextSize = size
	item.TextColor3 = colour
	item.BackgroundTransparency = 1
	item.Size = UDim2.new(1, 0, 0, size + 12)
	item.LayoutOrder = order
	item.ZIndex = 3
	pcall(function()
		item.FontFace = Font.new(family, Enum.FontWeight.Bold)
	end)
	return item
end

local content = Instance.new("Frame")
content.AnchorPoint = Vector2.new(0.5, 0.5)
content.Position = UDim2.fromScale(0.5, 0.5)
content.Size = UDim2.new(0, 620, 0, 0)
content.AutomaticSize = Enum.AutomaticSize.Y
content.BackgroundTransparency = 1
content.ZIndex = 2
content.Parent = gui

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 14)
layout.Parent = content

local wordmark = label("Logo", "THE LAST KINGDOM", 44, GOLD_BRIGHT, DISPLAY, 1)
wordmark.Parent = content

local wordmarkGradient = Instance.new("UIGradient")
wordmarkGradient.Color = ColorSequence.new(GOLD_BRIGHT, GOLD)
wordmarkGradient.Rotation = 90
wordmarkGradient.Parent = wordmark

local stroke = Instance.new("UIStroke")
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
stroke.Color = GOLD_BRIGHT
stroke.Thickness = 0.8
stroke.Parent = wordmark

local rule = Instance.new("Frame")
rule.Size = UDim2.new(0, 420, 0, 1)
rule.BackgroundColor3 = GOLD
rule.BorderSizePixel = 0
rule.LayoutOrder = 2
rule.ZIndex = 3
rule.Parent = content

local ruleFade = Instance.new("UIGradient")
ruleFade.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0.1),
	NumberSequenceKeypoint.new(1, 1),
})
ruleFade.Parent = rule

local line = label("Line", "Forty years from home. The road back begins.", 22, PARCHMENT, SERIF, 3)
line.Parent = content

-- The progress bar. A thin gold seam rather than a chunky meter: this screen is
-- a title card that happens to be loading, not a progress dialog.
local track = Instance.new("Frame")
track.Name = "Track"
track.Size = UDim2.new(0, 460, 0, 3)
track.BackgroundColor3 = GOLD_DIM
track.BackgroundTransparency = 0.6
track.BorderSizePixel = 0
track.LayoutOrder = 4
track.ZIndex = 3
track.Parent = content

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = GOLD_BRIGHT
fill.BorderSizePixel = 0
fill.ZIndex = 4
fill.Parent = track

local status = label("Status", "Waking the camp…", 16, MUTED, SERIF, 5)
status.Parent = content

local skip = Instance.new("TextButton")
skip.Name = "Skip"
skip.Text = "ENTER THE CAMP"
skip.TextSize = 20
skip.TextColor3 = CREAM
skip.AutoButtonColor = false
skip.BackgroundColor3 = Color3.fromRGB(44, 88, 56)
skip.BorderSizePixel = 0
skip.Size = UDim2.fromOffset(300, 50)
skip.LayoutOrder = 6
skip.ZIndex = 3
skip.Visible = false
skip.Parent = content
pcall(function()
	skip.FontFace = Font.new(SERIF, Enum.FontWeight.Bold)
end)

local skipCorner = Instance.new("UICorner")
skipCorner.CornerRadius = UDim.new(0, 3)
skipCorner.Parent = skip

local skipStroke = Instance.new("UIStroke")
skipStroke.Color = GOLD
skipStroke.Thickness = 1.5
skipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
skipStroke.Parent = skip

--==========================================================================
-- Preloading
--==========================================================================
local finished = false

local function setProgress(fraction: number, message: string)
	TweenService:Create(fill, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
		Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1),
	}):Play()
	status.Text = message
	if fraction >= SKIP_AT then
		skip.Visible = true
	end
end

local function dismiss()
	if finished then
		return
	end
	finished = true

	local fade = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(backdrop, fade, { BackgroundTransparency = 1 }):Play()
	for _, item in content:GetDescendants() do
		if item:IsA("TextLabel") or item:IsA("TextButton") then
			TweenService:Create(item, fade, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		elseif item:IsA("Frame") then
			TweenService:Create(item, fade, { BackgroundTransparency = 1 }):Play()
		end
	end
	TweenService:Create(wordmark, fade, { TextTransparency = 1 }):Play()

	task.delay(0.7, function()
		gui:Destroy()
	end)
end

skip.Activated:Connect(dismiss)

-- Whatever happens below, nobody is held here forever.
task.delay(MAX_SECONDS, dismiss)

task.spawn(function()
	local started = os.clock()

	setProgress(0.05, "Waking the camp…")
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	setProgress(0.2, "Reading the ledgers…")

	-- Only what the player will actually look at. Preloading the entire
	-- DataModel pulls in things that never appear on screen and makes the wait
	-- longer than the problem it solves.
	local targets: { { instance: Instance, message: string } } = {}
	local lobby = workspace:FindFirstChild("Lobby")
	local wanted = {
		{ name = "Buildings", message = "Raising the palisade…" },
		{ name = "TrainStation", message = "Laying the rails…" },
		{ name = "Nature", message = "Growing the treeline…" },
		{ name = "Decorations", message = "Lighting the lanterns…" },
		{ name = "NPCs", message = "Waking the camp…" },
	}
	if lobby then
		for _, entry in wanted do
			local child = lobby:FindFirstChild(entry.name)
			if child then
				table.insert(targets, { instance = child, message = entry.message })
			end
		end
	end
	if #targets == 0 then
		table.insert(targets, { instance = workspace, message = "Loading…" })
	end

	-- ONE target per call, rather than handing the whole list to PreloadAsync
	-- with a callback. The callback fires once per ASSET and the asset count is
	-- unknowable in advance, so progress computed from it runs off the end of
	-- the bar. Per-target is slower by a hair and always tells the truth.
	local total = #targets
	for index, target in targets do
		setProgress(0.2 + ((index - 1) / total) * 0.75, target.message)
		pcall(function()
			ContentProvider:PreloadAsync({ target.instance })
		end)
	end
	setProgress(0.95, "Almost there…")

	-- Hold briefly even on a fast machine: a title card that flashes past reads
	-- as a glitch rather than a title card.
	local elapsed = os.clock() - started
	if elapsed < MIN_SECONDS then
		task.wait(MIN_SECONDS - elapsed)
	end

	setProgress(1, "Ready.")
	task.wait(0.35)
	dismiss()
end)
