--!strict
--[[
	UIController
	Client-side owner of UI screens and their state (show/hide, transitions,
	routing between screens). It coordinates UI modules; it does NOT define the
	actual screens/layouts — those are built later in the UI phase.

	Responsibilities (future phases):
	- Register and manage UI screens (Hub menus, field HUD, death parchment, ...).
	- Route between screens and own UI-level state.
	- Bridge server events to the relevant screen.

	Place: shared client (each place shows its own screens).
	Phase: UI. NO UI is built in Phase 1 by design.
	Status: skeleton.
]]

local UIController = {}

UIController.Name = "UIController"

function UIController.Init()
	-- Reserved. No logic in Phase 1.
end

function UIController.Start()
	-- Reserved. No logic in Phase 1.
end

return UIController
