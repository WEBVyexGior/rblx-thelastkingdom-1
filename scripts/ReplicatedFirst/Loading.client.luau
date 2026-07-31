--!strict
--[[
	Loading
	Puts the title card up on the first frame and loads the world behind it.

	Roblox drops a player into the place the moment the server accepts them —
	before meshes, textures and terrain arrive — so without this they watch the
	lobby assemble around them: grey trees popping in, ground appearing late,
	decorations arriving after the buildings they were meant to hide.

	The card does not leave on its own. It waits for PLAY, and the seconds the
	player spends reading the name, the question and reaching for the button are
	the seconds the world spends loading. Nobody has to be told to wait.

	Everything here is best-effort: each preload is wrapped, and the player can
	press PLAY at any moment whether loading finished or not. Their time is
	theirs.

	Location: ReplicatedFirst.Loading (a LocalScript, runs before anything else)
]]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local TitleScreen = require(script.Parent.TitleScreen)

ReplicatedFirst:RemoveDefaultLoadingScreen()

local screen = TitleScreen.show()

task.spawn(function()
	screen.setProgress(0.05)
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	screen.setProgress(0.2)

	-- Only what the player will actually be standing in. Preloading the whole
	-- DataModel drags in things that never reach the screen and makes the wait
	-- longer than the problem it solves.
	local targets: { Instance } = {}
	local lobby = workspace:FindFirstChild("Lobby")
	if lobby then
		for _, name in { "Buildings", "TrainStation", "Nature", "Decorations", "NPCs" } do
			local child = lobby:FindFirstChild(name)
			if child then
				table.insert(targets, child)
			end
		end
	end
	if #targets == 0 then
		table.insert(targets, workspace)
	end

	-- ONE folder per call rather than handing PreloadAsync the whole list with a
	-- progress callback: that callback fires once per ASSET, and the asset count
	-- cannot be known in advance, so progress derived from it runs off the end
	-- of the bar before the first folder is done.
	local total = #targets
	for index, target in targets do
		pcall(function()
			ContentProvider:PreloadAsync({ target })
		end)
		screen.setProgress(0.2 + (index / total) * 0.8)
	end

	screen.setProgress(1)
end)
