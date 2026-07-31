--!strict
--[[
	Config: Hub
	Data for the Kingdom Hub place: where the lobby's functional instances live and
	how the departure train behaves. Everything a designer might retune (timings,
	party rules, marker look, branding) is DATA here — the TrainService holds only
	logic.

	The station is `workspace.Lobby.TrainStation`: one "Main Train" (the engine),
	four models all named "Wagon", and "Train Tracks". EACH WAGON RUNS ITS OWN
	PARTY — four wagons means four independent departures, not one train.

	Read via: Config.get("Hub")
]]

local Hub = {
	Train = {
		-- Where the station lives: workspace.<LobbyFolder>.<StationFolder>
		LobbyFolder = "Lobby",
		StationFolder = "TrainStation",

		-- All four wagons share ONE name, so they are collected by name and then
		-- ordered along the rails.
		WagonName = "Wagon",

		-- Boarding zones. Place a part per wagon by hand at
		-- `Lobby.<ZoneFolder>.<ZonePrefix><n>` (n = 1..4, front of the rake first)
		-- and the service will use it verbatim — move it, resize it, rotate it, and
		-- both the trigger and its glow follow. Without one, a zone is derived from
		-- the wagon's own bounds as a fallback.
		ZoneFolder = "Interactables",
		ZonePrefix = "BoardingZone",
		AutoZonePadding = Vector3.new(0, 8, 0),

		PollSeconds = 0.4,

		-- Timings.
		PromptWindowSeconds = 20, -- how long the "create a party" offer stands
		DepartureSeconds = 30, -- countdown once a party has been called
		FullDepartureSeconds = 5, -- RESTARTS at this the moment the wagon fills

		-- A teleport can fail for reasons no player caused. Try again quietly
		-- before giving up and telling them.
		DepartureAttempts = 2,
		RetrySeconds = 8,

		-- Where a boarded player is placed: dropped in just above the wagon floor.
		SeatDropHeight = 3,
	},

	-- Nobody is ever left standing on the rails. Stepping off a party, or letting
	-- the boarding offer time out, walks the player back to the camp spawn.
	Spawn = {
		Folder = "Spawn",
		PartName = "SpawnPoint",
		DropHeight = 4,
	},

	-- Once you are in a wagon you are committed: invisible walls hold the party in
	-- so the only way out is the Leave button. They are on their own collision
	-- group, so they exist ONLY for players already aboard — anyone else walks
	-- straight through to join.
	Barrier = {
		Enabled = true,
		Height = 24,
		Thickness = 1,
		Roof = true, -- stops players stacking to climb out
	},

	-- The glowing footprint that tells a player where to stand. Drawn on the
	-- ground beneath each boarding zone, so it always matches the real trigger.
	Marker = {
		Enabled = true,
		Color = Color3.fromRGB(198, 158, 66), -- antique gold, matching the UI
		Thickness = 0.6,
		Height = 0.1,
		LightBrightness = 2,
		LightRange = 22,
		PulseSeconds = 1.6,
	},

	-- EVERY lamp in the camp is driven from here. The lanterns are hand-placed in
	-- Studio, but their light is not tuned there one by one — change a number
	-- below and every lantern in the lobby changes with it on the next run.
	--
	-- Why the defaults are low: a lantern's stock Brightness/Range floods the
	-- scene at low graphics quality, where Roblox falls back to cheaper lighting
	-- and the falloff is much harsher. Tuning at maximum quality is a trap — it
	-- looks right there and blows out for most players.
	Lights = {
		Enabled = true,

		-- Never retune lights the game itself created — the boarding markers and
		-- the interaction rings own their look, and having this service overwrite
		-- them would quietly undo it.
		IgnoreFolders = { "TrainRuntime", "InteractionRuntime" },

		-- A light is matched by the names of the models it sits inside. FIRST
		-- MATCH WINS, so keep specific names above generic ones.
		Groups = {
			{
				-- TEST (2026-07-31): wide, soft throw down the lanes. Sits ABOVE
				-- the generic "Lantern" group so the posts are claimed first.
				Name = "LanternPosts",
				Match = { "Lantern Post" },
				Brightness = 0.8,
				Range = 40,
				Color = Color3.fromRGB(255, 186, 112),
				Shadows = false,
			},
			{
				Name = "Lanterns", -- any other lantern: the camp's baseline light
				Match = { "Lantern" },
				Brightness = 0.9,
				Range = 16,
				Color = Color3.fromRGB(255, 186, 112),
				Shadows = false,
			},
			{
				Name = "Torches", -- shorter throw, hotter colour
				Match = { "Torch" },
				Brightness = 1,
				Range = 13,
				Color = Color3.fromRGB(255, 166, 82),
				Shadows = false,
			},
			{
				Name = "Campfires", -- the one thing allowed to dominate its corner
				Match = { "Campfire", "Fire Pit", "Bonfire" },
				Brightness = 1.5,
				Range = 24,
				Color = Color3.fromRGB(255, 148, 62),
				Shadows = false,
			},
			{
				Name = "Forge", -- ember light: bright but tight, so it reads as heat
				Match = { "Smelter", "Forgable", "Anvil", "Forge" },
				Brightness = 1.2,
				Range = 11,
				Color = Color3.fromRGB(255, 120, 40),
				Shadows = false,
			},
			{
				Name = "Windows", -- warm interiors seen from the lane
				Match = { "House" },
				Brightness = 0.8,
				Range = 14,
				Color = Color3.fromRGB(255, 206, 150),
				Shadows = false,
			},
		},

		-- Everything the groups did not claim — including the 14 lights sitting in
		-- models still called "Model". Rename those in Studio and they can join a
		-- group instead of falling back here.
		Default = {
			Brightness = 0.7,
			Range = 12,
			Color = Color3.fromRGB(255, 196, 130),
			Shadows = false,
		},

		SpotAngle = 90, -- SpotLights only
	},

	-- The loading screen shown while a player is moved between places. It cannot
	-- animate (Roblox freezes it), so the words carry it.
	Teleport = {
		Headline = "FORTY YEARS AWAY FROM HOME",
		Line = "The road back begins...",
		Footer = "Preparing the Forgotten Lands…",
	},

	-- The experience is published under the group, not a personal account.
	--
	-- Group membership is the ONLY social action a game can actually verify
	-- (`player:IsInGroup`), and the only one Roblox permits rewarding. Likes and
	-- favourites are neither checkable nor allowed to be paid for — they may be
	-- asked for politely and nothing more.
	Social = {
		GroupId = 32361153,
		GroupName = "Ancient Guardian Souls",
	},

	-- Shown on the departure panel. LogoAssetId stays empty until the real logo is
	-- uploaded; the panel falls back to an engraved wordmark.
	Brand = {
		Title = "THE LAST KINGDOM",
		Developer = "by Cookies11f",
		LogoAssetId = "",
	},

	-- What a departing party is sent to play. Later this comes from the player's
	-- chapter selection at the Quartermaster instead of a fixed entry.
	Run = {
		ChapterId = "chapter_one",
		MissionId = "chapter_one_return",
	},
}

return table.freeze(Hub)
