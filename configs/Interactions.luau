--!strict
--[[
	Config: Interactions
	Every place in the lobby a player can walk into and have something open:
	the storyteller, the blacksmith, the merchant, a reward chest.

	They are DATA, not code. Adding one means adding an entry here and placing a
	model with the matching name in Studio — no new script. The server draws the
	marker, notices the player, and tells the client which screen to open.

	The wagons keep their own rectangular zones (they are boxes you stand in);
	everything here gets a RING on the ground, because these are places you walk
	up to rather than climb into.

	Read via: Config.get("Interactions")
]]

local Interactions = {
	-- Shared look of the ground markers. Same gold as the boarding zones, so the
	-- whole lobby teaches one lesson: gold light means "step here".
	Marker = {
		Color = Color3.fromRGB(198, 158, 66),
		Segments = 40, -- pieces the ring is drawn from; higher is rounder
		Thickness = 0.45,
		Height = 0.1,
		LightBrightness = 1.6,
		LightRange = 16,
		PulseSeconds = 1.8,
	},

	PollSeconds = 0.3,

	-- How dialogue is delivered. Lines type themselves out and then hold, so the
	-- scene plays on its own like someone actually talking — the buttons are
	-- there for anyone who would rather set their own pace.
	Dialogue = {
		CharactersPerSecond = 46,
		FirstHoldSeconds = 5, -- the opening line gets longer to land
		HoldSeconds = 3, -- every line after it
		AutoAdvance = true,

		-- A soft tick under the typing. Upload a short, quiet sound and paste its
		-- id here; empty means silence, which is better than a wrong sound.
		TypeSoundId = "",
		TypeSoundEvery = 3, -- characters between ticks
		TypeSoundVolume = 0.25,
	},

	-- Each point: an object in `workspace.Lobby.<Folder>.<Name>` and the screen
	-- that opens when a player steps into its ring.
	Points = {
		{
			Id = "storyteller",
			Screen = "Dialogue",
			Folder = "NPCs",
			Name = "Storyteller",
			Radius = 8,

			-- Build the character from a real Roblox avatar instead of placing a
			-- model. Avatar data is public, so ANY user id works — the person does
			-- not have to be a collaborator, or even know. Set UserId to 0 to use
			-- whatever model is placed at `Folder.Name` instead.
			Avatar = {
				UserId = 2062889722,
				FaceAngle = 180, -- degrees, so he can be turned to face the camp
			},

			Dialogue = {
				Title = "THE VETERAN",
				-- Provisional copy — the story beats are locked, the wording is not.
				Lines = {
					"Forty years we held that line. Forty years of a war that was never ours.",
					"Word came in the spring. The kingdom has gone dark — and they say the king is no longer a king.",
					"I am too old for the road. You are not.",
					"Take a wagon. Take whoever will stand beside you. Go home, and see what is left of it.",
				},
			},
		},
	},
}

return table.freeze(Interactions)
