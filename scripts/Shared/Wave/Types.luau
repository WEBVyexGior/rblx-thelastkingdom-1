--!strict
--[[
	Wave.Types
	Shared type definitions for the data-driven encounter/wave system. These shapes
	are authored in `configs/Encounters.luau`, validated by `Server.Domain.EncounterRun`,
	and executed at runtime by the World WaveService.

	An ENCOUNTER is a structured battle: named spawn points + one or more WAVES; each
	wave is a set of SPAWN GROUPS (N of an enemy at a spawn point). Waves run either
	sequentially (next starts when the previous clears) or in parallel.

	Location: ReplicatedStorage.Shared.Wave.Types
]]

-- N units of one enemy at a named spawn point.
export type SpawnGroup = {
	enemyId: string, -- key into configs/Enemies
	count: number,
	spawnPoint: string, -- key into EncounterDef.spawnPoints
	spread: number?, -- studs between spawned units (default 0)
}

export type WaveDef = {
	id: string,
	groups: { SpawnGroup },
	startDelay: number?, -- seconds after the wave is triggered before it spawns
}

export type EncounterDef = {
	id: string,
	mode: string?, -- Wave.Enums.WaveMode (default Sequential)
	spawnPoints: { [string]: Vector3 },
	waves: { WaveDef },
	restBetweenWaves: number?, -- override the global default (Sequential only)
	scaled: boolean?, -- apply player-count difficulty scaling (default true)
}

return {}
