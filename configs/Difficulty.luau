--!strict
--[[
	Config: Difficulty
	Player-count and difficulty-tier SCALING curves. This is the heart of the
	"balanced, not linear" rule: more players => more/tougher enemies and better
	rewards, but roughly the SAME completion time. 8 players is NOT 8x enemies.

	Read via: Config.get("Difficulty")
	Filled with real values in the Combat/Balance phase. Empty in Phase 1 by design.

	Schema:
		PlayerCount = {
			[count: number] = {
				EnemyCountMult  = number,  -- sub-linear in player count
				EnemyHealthMult = number,
				EliteWeight     = number,  -- 0..1 chance weight for elites
				RewardMult      = number,
			},
		},
		Tiers = { [tierName: string] = { GlobalMult = number } },
]]

local Difficulty = {
	PlayerCount = {},
	Tiers = {},
}

return table.freeze(Difficulty)
