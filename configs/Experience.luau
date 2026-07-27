--!strict
--[[
	Config: Experience
	Character progression curve: XP required per level and (later) level-up rewards.
	("Experience" here means XP/levels — distinct from the Roblox "experience".)

	Read via: Config.get("Experience"). Values are PROVISIONAL (tuned in the Balance phase).

	Schema:
		MaxLevel     = number,
		XpToLevel    = { number },              -- XpToLevel[level] = XP to reach level+1
		LevelRewards = { [level: number] = { ... } },
]]

local Experience = {
	MaxLevel = 10,
	-- XP to go FROM this level to the next (index = level).
	XpToLevel = { 100, 150, 220, 320, 460, 660, 940, 1340, 1900 },
	LevelRewards = {},
}

return table.freeze(Experience)
