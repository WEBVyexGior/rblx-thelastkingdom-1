--!strict
--[[
	Config: Difficulty
	Player-count SCALING curves — the "balanced, not linear" rule: more players =>
	more/tougher enemies and better rewards, but roughly the SAME completion time.
	8 players is NOT 8x enemies (note EnemyCountMult tops out at 3.0).

	Read via: Config.get("Difficulty"). Values are PROVISIONAL (tuned in the Balance phase).

	Schema:
		PlayerCount[count] = {
			EnemyCountMult  = number,  -- sub-linear in player count
			EnemyHealthMult = number,
			EliteWeight     = number,  -- 0..1 chance a scaled-in extra is an elite
			RewardMult      = number,
		}
]]

local Difficulty = {
	PlayerCount = {
		[1] = { EnemyCountMult = 1.0, EnemyHealthMult = 1.0, EliteWeight = 0.0, RewardMult = 1.0 },
		[2] = { EnemyCountMult = 1.4, EnemyHealthMult = 1.1, EliteWeight = 0.1, RewardMult = 1.3 },
		[3] = { EnemyCountMult = 1.7, EnemyHealthMult = 1.15, EliteWeight = 0.15, RewardMult = 1.6 },
		[4] = { EnemyCountMult = 2.0, EnemyHealthMult = 1.2, EliteWeight = 0.2, RewardMult = 1.9 },
		[5] = { EnemyCountMult = 2.3, EnemyHealthMult = 1.25, EliteWeight = 0.25, RewardMult = 2.2 },
		[6] = { EnemyCountMult = 2.5, EnemyHealthMult = 1.3, EliteWeight = 0.3, RewardMult = 2.5 },
		[7] = { EnemyCountMult = 2.7, EnemyHealthMult = 1.35, EliteWeight = 0.35, RewardMult = 2.8 },
		[8] = { EnemyCountMult = 3.0, EnemyHealthMult = 1.4, EliteWeight = 0.4, RewardMult = 3.1 },
	},
	-- Party-size tiers, in ascending order: a group of `count` players gets the
	-- first tier whose `maxPlayers` it fits into. Shown in the lobby when boarding
	-- and carried across in the teleport payload.
	Tiers = {
		{ id = "Normal", maxPlayers = 4 },
		{ id = "Hard", maxPlayers = 8 },
	},
}

return table.freeze(Difficulty)
