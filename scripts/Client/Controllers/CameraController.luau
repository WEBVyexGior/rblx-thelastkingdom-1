--!strict
--[[
	CameraController
	Client-side camera foundation. Owns custom camera behaviour used for
	atmosphere and for special states (e.g. the cinematic death camera and the
	60-second spectate window described in the design).

	Responsibilities (future phases):
	- Drive gameplay camera behaviour.
	- Handle special camera states (spectate, death cinematic, cutscenes).

	Place: shared client.
	Phase: Core Systems / Polish.
	Status: skeleton.
]]

local CameraController = {}

CameraController.Name = "CameraController"

function CameraController.Init()
	-- Reserved. No logic in Phase 1.
end

function CameraController.Start()
	-- Reserved. No logic in Phase 1.
end

return CameraController
