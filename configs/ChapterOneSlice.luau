--!strict
--[[
	Config: ChapterOneSlice
	Data for the Chapter 1 VERTICAL SLICE — the minimal end-to-end run that proves
	the foundations (combat, enemy AI, mission/match framework) connect into one
	gameplay loop. DEV/TEST scaffolding, not real content.

	All narrative strings are PROVISIONAL placeholders, replaced when the Story Phase
	is authored. All positions/radii/counts are provisional too.

	Read via: Config.get("ChapterOneSlice")
]]

local ChapterOneSlice = {
	-- Provisional mission identity (registered through MissionService).
	MissionId = "chapter_one_slice",
	MissionDisplayName = "[PLACEHOLDER] Chapter 1 - Vertical Slice",
	Region = "forgotten_lands_slice", -- working name

	-- Seconds after a character spawns before the intro is sent, giving the client
	-- narrative handler time to be listening.
	IntroDelaySeconds = 2,

	-- How often (seconds) the server checks player distance to the exploration
	-- markers (STEP 2).
	DetectionInterval = 0.25,

	-- Delay (seconds) between the reward beat and the end beat (STEP 3), so they
	-- read as separate messages.
	RewardToEndDelaySeconds = 2,

	-- PROVISIONAL placeholder narrative — replaced after the Story Phase.
	Narrative = {
		Intro = "[PLACEHOLDER INTRO] Forty years gone. You return, and the land is silent...",
		Lore = "[PLACEHOLDER LORE] A survivor's marker. Something terrible passed through here.",
		Objective = "[PLACEHOLDER OBJECTIVE] Clear the undead ahead.",
		Reward = "[PLACEHOLDER REWARD] The path is clear. (placeholder reward granted)",
		End = "[PLACEHOLDER END] Vertical slice complete.",
	},

	-- Step 2 (exploration + lore): a marker the player walks to. Provisional
	-- position, relative to the world origin.
	LoreZone = {
		Position = Vector3.new(0, 3, -30),
		Radius = 8,
	},

	-- Step 3 (objective + undead encounter): the objective site and the spawn.
	ObjectiveZone = {
		Position = Vector3.new(0, 3, -60),
		Radius = 10,
	},
	Encounter = {
		EnemyCount = 3,
		SpawnCenter = Vector3.new(0, 3, -70),
		SpawnSpread = 6, -- studs between spawned undead
	},
}

return table.freeze(ChapterOneSlice)
