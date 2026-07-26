--!strict
--[[
	Config: Missions
	Data-driven mission definitions. A mission is an ordered list of objectives plus
	placeholder narrative and a (symbolic) reward. New missions are DATA, not code —
	the World MissionRuntimeService runs whatever is defined here.

	All text is PROVISIONAL placeholder, replaced when the Story Phase is authored.
	Positions/counts/radii are provisional too.

	Schema: see `ReplicatedStorage.Shared.Mission.Types` (MissionDef / ObjectiveDef).
	Read via: Config.get("Missions")
]]

local Missions = {
	-- Chapter 1's mission — the former hardcoded vertical slice, now data.
	chapter_one_return = {
		id = "chapter_one_return",
		displayName = "[PLACEHOLDER] The Return Home",
		region = "forgotten_lands",
		intro = "[PLACEHOLDER INTRO] Forty years gone. You return, and the land is silent...",
		outro = "[PLACEHOLDER END] The path is clear. The return has begun.",
		reward = {
			summary = "[PLACEHOLDER REWARD] placeholder reward granted",
			currency = 0,
			xp = 0,
		},
		objectives = {
			{
				id = "reach_lore",
				type = "Reach",
				description = "[PLACEHOLDER] Explore ahead — reach the survivor's marker.",
				completionText = "[PLACEHOLDER LORE] A survivor's marker. Something terrible passed through here.",
				position = Vector3.new(0, 3, -30),
				radius = 8,
			},
			{
				id = "reach_site",
				type = "Reach",
				description = "[PLACEHOLDER] Press on to the ruined site.",
				position = Vector3.new(0, 3, -60),
				radius = 10,
			},
			{
				id = "clear_undead",
				type = "Clear",
				description = "[PLACEHOLDER] Clear the undead ambush.",
				encounterId = "chapter_one_ambush",
				eliteEnemyId = "undead_brute",
			},
		},
	},
}

return table.freeze(Missions)
