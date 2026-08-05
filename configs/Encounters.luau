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

--==========================================================================
-- THE CASTLE, ROOM BY ROOM
--
-- One encounter per chamber, started when a player walks in (AreaWaveService)
-- and NOT tied to that room's puzzle. The waves are pressure; the barricade,
-- the winch and the rest are the lock. You can leave the moment the lock is
-- open, whether or not the room is empty.
--
-- TWO RULES THESE OBEY:
--
--   1. `configs/Difficulty.Areas[n].Unlocks` is the single source of truth for
--      which enemies exist yet. Nothing here may introduce a type earlier than
--      that table says — no archers in the outer ward.
--
--   2. Counts are the BASE. WaveService multiplies them by the party curve and
--      the depth curve, so these numbers are what one player meets, and the
--      Areas table does the ramp. Do not pre-ramp them here as well or the
--      curve gets applied twice.
--
-- Reference for tuning: a shambler is 60hp and dies to three hits of the
-- starter sword; a runner is 40hp and dies to two.
--==========================================================================
local function chamber(index: number, waves: { any })
	return {
		id = ("area_%d"):format(index),
		mode = "Sequential",
		spawnPoints = {
			north = ("Battleground.Chamber%d.Spawns.North"):format(index),
			east = ("Battleground.Chamber%d.Spawns.East"):format(index),
			west = ("Battleground.Chamber%d.Spawns.West"):format(index),
		},
		waves = waves,
	}
end

local Encounters = {
	--======================================================================
	-- 1 — Outer Ward. Shamblers only. A real number from the start: fifteen
	-- of them, in three waves, which is about a minute of work for one player
	-- and is meant to be felt while three ropes are still uncut.
	--======================================================================
	area_1 = chamber(1, {
		{ id = "w1", groups = { { enemyId = "undead_shambler", count = 4, spawnPoint = "north", spread = 8 } } },
		{
			id = "w2",
			groups = {
				{ enemyId = "undead_shambler", count = 3, spawnPoint = "east", spread = 8 },
				{ enemyId = "undead_shambler", count = 2, spawnPoint = "west", spread = 6 },
			},
		},
		{
			id = "w3",
			groups = {
				{ enemyId = "undead_shambler", count = 4, spawnPoint = "north", spread = 10 },
				{ enemyId = "undead_shambler", count = 2, spawnPoint = "west", spread = 6 },
			},
		},
	}),

	--======================================================================
	-- 2 — Stables. Runners arrive. Four waves rather than three, because the
	-- winch takes longer than the ropes did and the room has to keep coming
	-- for as long as the job lasts.
	--======================================================================
	area_2 = chamber(2, {
		{ id = "w1", groups = { { enemyId = "undead_shambler", count = 5, spawnPoint = "west", spread = 8 } } },
		{
			id = "w2",
			groups = {
				{ enemyId = "undead_shambler", count = 3, spawnPoint = "north", spread = 8 },
				{ enemyId = "undead_runner", count = 3, spawnPoint = "east", spread = 8 },
			},
		},
		{
			id = "w3",
			groups = {
				{ enemyId = "undead_runner", count = 4, spawnPoint = "west", spread = 10 },
				{ enemyId = "undead_shambler", count = 3, spawnPoint = "east", spread = 8 },
			},
		},
		{
			id = "w4",
			groups = {
				{ enemyId = "undead_shambler", count = 4, spawnPoint = "north", spread = 10 },
				{ enemyId = "undead_runner", count = 4, spawnPoint = "west", spread = 10 },
			},
		},
	}),

	--======================================================================
	-- 3 — Kitchens. No new type; the mix just gets meaner while you are busy
	-- reading a recipe and feeding five of them.
	--======================================================================
	area_3 = chamber(3, {
		{
			id = "w1",
			groups = {
				{ enemyId = "undead_shambler", count = 5, spawnPoint = "north", spread = 8 },
				{ enemyId = "undead_runner", count = 2, spawnPoint = "east", spread = 6 },
			},
		},
		{
			id = "w2",
			groups = {
				{ enemyId = "undead_runner", count = 5, spawnPoint = "west", spread = 10 },
				{ enemyId = "undead_shambler", count = 3, spawnPoint = "east", spread = 8 },
			},
		},
		{
			id = "w3",
			groups = {
				{ enemyId = "undead_shambler", count = 6, spawnPoint = "north", spread = 12 },
				{ enemyId = "undead_runner", count = 4, spawnPoint = "west", spread = 10 },
			},
		},
	}),

	--======================================================================
	-- 4 — Graveyard. THE TURN. The heavy arrives, and the graveyard keeps
	-- producing: four waves, and the last one has two of them.
	--======================================================================
	area_4 = chamber(4, {
		{
			id = "w1",
			groups = {
				{ enemyId = "undead_shambler", count = 6, spawnPoint = "north", spread = 12 },
				{ enemyId = "undead_runner", count = 3, spawnPoint = "east", spread = 8 },
			},
		},
		{
			id = "w2",
			groups = {
				{ enemyId = "undead_brute_heavy", count = 1, spawnPoint = "north" },
				{ enemyId = "undead_runner", count = 5, spawnPoint = "west", spread = 10 },
			},
		},
		{
			id = "w3",
			groups = {
				{ enemyId = "undead_shambler", count = 7, spawnPoint = "east", spread = 12 },
				{ enemyId = "undead_runner", count = 4, spawnPoint = "west", spread = 10 },
			},
		},
		{
			id = "w4",
			groups = {
				{ enemyId = "undead_brute_heavy", count = 2, spawnPoint = "north", spread = 8 },
				{ enemyId = "undead_shambler", count = 5, spawnPoint = "west", spread = 10 },
			},
		},
	}),

	--======================================================================
	-- 5 — Smithy. THE SPIKE. Reach and range in the same room, on top of a
	-- count multiplier that jumps by 0.55 where every other step is 0.15-0.30.
	-- This is the room that is supposed to nearly take you apart.
	--======================================================================
	area_5 = chamber(5, {
		{
			id = "w1",
			groups = {
				{ enemyId = "undead_spearman", count = 3, spawnPoint = "north", spread = 8 },
				{ enemyId = "undead_shambler", count = 5, spawnPoint = "east", spread = 10 },
			},
		},
		{
			id = "w2",
			groups = {
				{ enemyId = "undead_archer", count = 3, spawnPoint = "west", spread = 12 },
				{ enemyId = "undead_runner", count = 5, spawnPoint = "east", spread = 10 },
			},
		},
		{
			id = "w3",
			groups = {
				{ enemyId = "undead_brute_heavy", count = 2, spawnPoint = "north", spread = 8 },
				{ enemyId = "undead_spearman", count = 4, spawnPoint = "west", spread = 10 },
			},
		},
		{
			id = "w4",
			groups = {
				{ enemyId = "undead_archer", count = 4, spawnPoint = "east", spread = 12 },
				{ enemyId = "undead_runner", count = 6, spawnPoint = "north", spread = 12 },
				{ enemyId = "undead_shambler", count = 4, spawnPoint = "west", spread = 10 },
			},
		},
	}),

	--======================================================================
	-- 6 — Great Hall. Under a roof you built yourself, so the archers matter
	-- less and the press at the doors matters more.
	--======================================================================
	area_6 = chamber(6, {
		{
			id = "w1",
			groups = {
				{ enemyId = "undead_shambler", count = 7, spawnPoint = "north", spread = 12 },
				{ enemyId = "undead_runner", count = 4, spawnPoint = "east", spread = 10 },
			},
		},
		{
			id = "w2",
			groups = {
				{ enemyId = "undead_spearman", count = 4, spawnPoint = "west", spread = 10 },
				{ enemyId = "undead_brute_heavy", count = 1, spawnPoint = "north" },
			},
		},
		{
			id = "w3",
			groups = {
				{ enemyId = "undead_runner", count = 7, spawnPoint = "east", spread = 12 },
				{ enemyId = "undead_archer", count = 3, spawnPoint = "west", spread = 12 },
			},
		},
		{
			id = "w4",
			groups = {
				{ enemyId = "undead_brute_heavy", count = 2, spawnPoint = "west", spread = 8 },
				{ enemyId = "undead_shambler", count = 6, spawnPoint = "north", spread = 12 },
				{ enemyId = "undead_spearman", count = 3, spawnPoint = "east", spread = 8 },
			},
		},
	}),

	--======================================================================
	-- 7 — The Rows. Narrow, so fewer at once and more of them behind.
	--======================================================================
	area_7 = chamber(7, {
		{
			id = "w1",
			groups = {
				{ enemyId = "undead_runner", count = 6, spawnPoint = "north", spread = 10 },
				{ enemyId = "undead_spearman", count = 3, spawnPoint = "east", spread = 8 },
			},
		},
		{
			id = "w2",
			groups = {
				{ enemyId = "undead_archer", count = 4, spawnPoint = "west", spread = 12 },
				{ enemyId = "undead_shambler", count = 6, spawnPoint = "east", spread = 12 },
			},
		},
		{
			id = "w3",
			groups = {
				{ enemyId = "undead_brute_heavy", count = 2, spawnPoint = "north", spread = 8 },
				{ enemyId = "undead_runner", count = 6, spawnPoint = "west", spread = 12 },
			},
		},
		{
			id = "w4",
			groups = {
				{ enemyId = "undead_spearman", count = 5, spawnPoint = "north", spread = 10 },
				{ enemyId = "undead_archer", count = 4, spawnPoint = "east", spread = 12 },
				{ enemyId = "undead_shambler", count = 6, spawnPoint = "west", spread = 12 },
			},
		},
	}),

	--======================================================================
	-- 8 — Inner Ward. Where the line broke. Five waves and no let-up.
	--======================================================================
	area_8 = chamber(8, {
		{
			id = "w1",
			groups = {
				{ enemyId = "undead_shambler", count = 8, spawnPoint = "north", spread = 14 },
				{ enemyId = "undead_runner", count = 5, spawnPoint = "east", spread = 12 },
			},
		},
		{
			id = "w2",
			groups = {
				{ enemyId = "undead_spearman", count = 5, spawnPoint = "west", spread = 10 },
				{ enemyId = "undead_archer", count = 4, spawnPoint = "east", spread = 12 },
			},
		},
		{
			id = "w3",
			groups = {
				{ enemyId = "undead_brute_heavy", count = 3, spawnPoint = "north", spread = 10 },
				{ enemyId = "undead_runner", count = 7, spawnPoint = "west", spread = 14 },
			},
		},
		{
			id = "w4",
			groups = {
				{ enemyId = "undead_archer", count = 5, spawnPoint = "west", spread = 14 },
				{ enemyId = "undead_spearman", count = 5, spawnPoint = "east", spread = 12 },
				{ enemyId = "undead_shambler", count = 6, spawnPoint = "north", spread = 14 },
			},
		},
		{
			id = "w5",
			groups = {
				{ enemyId = "undead_brute_heavy", count = 3, spawnPoint = "west", spread = 10 },
				{ enemyId = "undead_runner", count = 8, spawnPoint = "north", spread = 14 },
				{ enemyId = "undead_archer", count = 4, spawnPoint = "east", spread = 12 },
			},
		},
	}),

	--======================================================================
	-- 9 is deliberately absent. The Keep Steps are the King, and a boss is
	-- not a wave table — it gets its own service when it is built.
	--======================================================================

	-- Chapter 1's encounter (replaces the mission's old flat 3-dummy spawn).
	chapter_one_ambush = {
		id = "chapter_one_ambush",
		mode = "Sequential",
		-- Named markers rather than coordinates: place them in Studio, drag them
		-- where the fight should come from, and this needs no edit. See
		-- Shared.World.Markers, and tools/ScaffoldAreas to create them.
		spawnPoints = {
			north = "Battleground.Chamber1.Spawns.North",
			east = "Battleground.Chamber1.Spawns.East",
			west = "Battleground.Chamber1.Spawns.West",
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
