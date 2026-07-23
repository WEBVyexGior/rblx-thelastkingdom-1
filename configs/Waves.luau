--!strict
--[[
	Config: Waves
	Tuning for encounters and zombie invasions/waves — pacing, composition, and
	what triggers them. Waves are EVENTS inside the world, not the whole game.

	Read via: Config.get("Waves")
	Filled with real values in the Combat phase. Empty in Phase 1 by design.

	Schema:
		Encounter = { MinEnemies = number, MaxEnemies = number, TriggeredBy = string },
		Invasion  = {
			Waves                   = number,
			EnemiesPerWave          = { number },
			ElitesPerWave           = { number },
			RestBetweenWavesSeconds = number,
			TriggeredBy             = string,   -- e.g. "objective_progress"
		},
]]

local Waves = {
	Encounter = {},
	Invasion = {},
}

return table.freeze(Waves)
