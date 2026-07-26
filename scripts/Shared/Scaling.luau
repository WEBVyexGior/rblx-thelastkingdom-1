--!strict
--[[
	Scaling
	Reads the player-count difficulty curves from `configs/Difficulty` and returns the
	scaling parameters for a given party size — the "balanced, not linear" rule in one
	place. Shared so rewards/other systems can reuse it; only the server acts on it.

	Location: ReplicatedStorage.Shared.Scaling
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Scaling = {}

export type Params = {
	enemyCountMult: number,
	enemyHealthMult: number,
	eliteWeight: number,
	rewardMult: number,
}

local DEFAULT: Params = {
	enemyCountMult = 1,
	enemyHealthMult = 1,
	eliteWeight = 0,
	rewardMult = 1,
}

-- Scaling params for `playerCount`. Falls back to the largest defined entry <= count
-- (so 8 players uses the [8] row even if only some counts are defined).
function Scaling.forPlayers(playerCount: number): Params
	local difficulty = Config.get("Difficulty")
	local byCount = difficulty.PlayerCount
	local n = math.max(1, playerCount)

	local entry = byCount[n]
	if not entry then
		local bestKey = -1
		for k, v in byCount do
			if k <= n and k > bestKey then
				bestKey = k
				entry = v
			end
		end
	end
	if not entry then
		return DEFAULT
	end

	return {
		enemyCountMult = entry.EnemyCountMult or 1,
		enemyHealthMult = entry.EnemyHealthMult or 1,
		eliteWeight = entry.EliteWeight or 0,
		rewardMult = entry.RewardMult or 1,
	}
end

return Scaling
