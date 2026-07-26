--!strict
--[[
	Config: Chapters
	Data-driven campaign structure: each chapter is an ordered list of mission ids
	(from `configs/Missions.luau`). The World ChapterService plays a chapter's
	missions in order. New chapters are DATA, not code.

	Schema: see `ReplicatedStorage.Shared.Mission.Types` (ChapterDef).
	Read via: Config.get("Chapters")
]]

local Chapters = {
	chapter_one = {
		id = "chapter_one",
		title = "[PLACEHOLDER] Chapter 1 - The Return Home",
		missions = {
			"chapter_one_return",
		},
	},
}

return table.freeze(Chapters)
