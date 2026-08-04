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
			summary = "[PLACEHOLDER] Mission reward",
			currency = 50,
			xp = 120,
		},
		objectives = {
			--[[
				`hint` is the line the PLAYER reads, at the top of the screen.

				PLAIN WORDS. Three or four of them, the ones a twelve-year-old
				uses. "Look around", not "Search the outer ward"; "Kill them
				all", not "Clear the undead ambush". The story can be written
				however it likes — the instruction is a road sign, and a road
				sign nobody parses instantly has failed.

				`description` keeps the long form for the log.
			]]
			{
				id = "reach_lore",
				type = "Reach",
				hint = "Look around",
				description = "[PLACEHOLDER] Explore ahead — reach the survivor's marker.",
				completionText = "[PLACEHOLDER LORE] A survivor's marker. Something terrible passed through here.",
				-- Named, not coordinates: drag the marker in Studio and the
				-- objective follows it. See Shared.World.Markers, and
				-- tools/BuildBattleground for where these markers come from.
				position = "Battleground.Chamber1.Objectives.Centre",
				radius = 14,
			},
			{
				id = "reach_site",
				type = "Reach",
				hint = "Keep going",
				description = "[PLACEHOLDER] Press on to the ruined site.",
				position = "Battleground.Chamber2.Objectives.Centre",
				radius = 14,
			},
			{
				id = "clear_undead",
				type = "Clear",
				hint = "Kill them all",
				description = "[PLACEHOLDER] Clear the undead ambush.",
				encounterId = "chapter_one_ambush",
				eliteEnemyId = "undead_brute",
				reward = { summary = "[PLACEHOLDER] Ambush cleared", currency = 25, xp = 60 },
			},
		},
	},
}

return table.freeze(Missions)
