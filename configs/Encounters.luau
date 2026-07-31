--!strict
--[[
	Config: Encounters
	Data-driven ENCOUNTER definitions — the structured battles the Wave System runs.
	The Mission System decides WHEN to start one (a Clear objective's `encounterId`);
	this data decides WHAT it is. Level design adds encounters here, no code needed.

	Each encounter has named spawn points and one or more waves; a wave is spawn
	groups (N of an enemy at a point). Waves are Sequential by default (next starts
	when the previous clears) or Parallel.

	Schema: see `ReplicatedStorage.Shared.Wave.Types` (EncounterDef / WaveDef / SpawnGroup).
	Read via: Config.get("Encounters"). Positions/counts are PROVISIONAL placeholders.
]]

local Encounters = {
	-- Chapter 1's encounter (replaces the mission's old flat 3-dummy spawn).
	chapter_one_ambush = {
		id = "chapter_one_ambush",
		mode = "Sequential",
		-- Named markers rather than coordinates: place them in Studio, drag them
		-- where the fight should come from, and this needs no edit. See
		-- Shared.World.Markers, and tools/ScaffoldAreas to create them.
		spawnPoints = {
			north = "Area1_Outskirts.Spawns.North",
			east = "Area1_Outskirts.Spawns.East",
			west = "Area1_Outskirts.Spawns.West",
		},
		waves = {
			{
				id = "wave_1",
				groups = {
					{ enemyId = "training_dummy", count = 2, spawnPoint = "north", spread = 5 },
				},
			},
			{
				id = "wave_2",
				groups = {
					{ enemyId = "training_dummy", count = 1, spawnPoint = "east" },
					{ enemyId = "undead_brute", count = 1, spawnPoint = "west" }, -- elite
				},
			},
		},
	},
}

return table.freeze(Encounters)
