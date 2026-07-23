--!strict
--[[
	AudioController
	Client-side audio playback and ambience manager (music, SFX, atmospheric
	beds). Audio playback is inherently client-side, so this lives as a Controller
	rather than a server Service; the server only ever tells clients WHAT to play.

	(Named AudioController, not "AudioService", to follow the project convention:
	server singletons are Services, client singletons are Controllers.)

	Responsibilities (future phases):
	- Manage music/ambience layers and transitions for atmosphere.
	- Play SFX cues requested by gameplay/UI.
	- Respect the player's audio settings.

	Place: shared client.
	Phase: Polish / Atmosphere.
	Status: skeleton.
]]

local AudioController = {}

AudioController.Name = "AudioController"

function AudioController.Init()
	-- Reserved. No logic in Phase 1.
end

function AudioController.Start()
	-- Reserved. No logic in Phase 1.
end

return AudioController
