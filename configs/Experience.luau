--!strict
--[[
	Config: Experience
	Character progression curve: XP required per level and level-up rewards.
	("Experience" here means XP/levels — distinct from the Roblox "experience".)

	Read via: Config.get("Experience")
	Filled with real values in the Progression phase. Empty in Phase 1 by design.

	Schema:
		MaxLevel   = number,
		XpToLevel  = { number },                 -- index = level, value = XP needed
		LevelRewards = { [level: number] = { ... } },
]]

local Experience = {
	XpToLevel = {},
	LevelRewards = {},
}

return table.freeze(Experience)
