--!strict
--[[
	MissionService
	Server-authoritative registry of mission AND chapter definitions. Loads them from
	`configs/Missions.luau` and `configs/Chapters.luau` at Init (validated through the
	Mission domain), and exposes them to the World runtime and the Hub.

	Content is DATA — adding a mission/chapter is editing config, not code.

	Place: shared. Phase: Core Systems / Missions.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local Mission = require(Server.Domain.Mission)
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Mission.Types)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local MissionService = {}

MissionService.Name = "MissionService"

local log = Logger.new("MissionService")
local registry: { [string]: Mission.MissionDefinition } = {}
local chapters: { [string]: Types.ChapterDef } = {}

-- Registers a validated mission definition. Errors on duplicate ids.
function MissionService.register(def: Mission.MissionDefinition)
	local validated = Mission.define(def)
	assert(registry[validated.id] == nil, "Duplicate mission id: " .. validated.id)
	registry[validated.id] = validated
end

function MissionService.get(id: string): Mission.MissionDefinition?
	return registry[id]
end

function MissionService.getAll(): { [string]: Mission.MissionDefinition }
	return registry
end

function MissionService.getChapter(id: string): Types.ChapterDef?
	return chapters[id]
end

function MissionService.getAllChapters(): { [string]: Types.ChapterDef }
	return chapters
end

function MissionService.Init()
	for _, def in Config.get("Missions") do
		MissionService.register(def)
	end
	for _, chapter in Config.get("Chapters") do
		assert(chapters[chapter.id] == nil, "Duplicate chapter id: " .. chapter.id)
		chapters[chapter.id] = chapter
	end
	-- Fail loudly on a chapter that references a mission that does not exist.
	for _, chapter in chapters do
		for _, missionId in chapter.missions do
			assert(
				registry[missionId] ~= nil,
				("chapter '%s' references unknown mission '%s'"):format(chapter.id, missionId)
			)
		end
	end
end

function MissionService.Start()
	local missionCount, chapterCount = 0, 0
	for _ in registry do
		missionCount += 1
	end
	for _ in chapters do
		chapterCount += 1
	end
	log:info(("ready (%d mission(s), %d chapter(s))"):format(missionCount, chapterCount))
end

return MissionService
