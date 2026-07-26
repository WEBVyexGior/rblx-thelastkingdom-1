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
		spawnPoints = {
			north = Vector3.new(0, 3, -70),
			east = Vector3.new(12, 3, -66),
			west = Vector3.new(-12, 3, -66),
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
