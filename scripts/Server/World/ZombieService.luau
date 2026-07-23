--!strict
--[[
	ZombieService
	Future home of the undead/enemy systems for the Forgotten Lands: spawning,
	AI, and hooks into encounters and waves. This is where combat-adjacent enemy
	logic will live — as EVENTS inside the larger world, never the whole game.

	Responsibilities (future phases):
	- Spawn and pool enemies (standard / elite / boss).
	- Drive enemy AI and hand off damage resolution to the (future) combat system.
	- Feed off the Scaling data so party size changes difficulty, not run length.

	Place: Forgotten Lands ONLY (not present in the Kingdom Hub).
	Phase: Combat. NO zombie, combat, or wave logic exists in Phase 1 by design.
	Status: skeleton.
]]

local ZombieService = {}

ZombieService.Name = "ZombieService"

function ZombieService.Init()
	-- Reserved. No logic in Phase 1.
end

function ZombieService.Start()
	-- Reserved. No logic in Phase 1.
end

return ZombieService
