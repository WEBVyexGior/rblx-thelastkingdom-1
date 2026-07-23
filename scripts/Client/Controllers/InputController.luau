--!strict
--[[
	InputController
	Client-side input foundation. Central place to bind and route player input
	(keyboard/mouse/gamepad/touch) into intents that other controllers consume,
	so input handling is not scattered across unrelated scripts.

	Responsibilities (future phases):
	- Bind input via ContextActionService / UserInputService.
	- Expose high-level input signals (e.g. "Interact", "Attack") to controllers.
	- Support rebinding and multiple input devices.

	Place: shared client.
	Phase: Core Systems.
	Status: skeleton.
]]

local InputController = {}

InputController.Name = "InputController"

function InputController.Init()
	-- Reserved. No logic in Phase 1.
end

function InputController.Start()
	-- Reserved. No logic in Phase 1.
end

return InputController
