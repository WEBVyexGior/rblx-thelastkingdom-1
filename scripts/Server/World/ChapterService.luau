--!strict
--[[
	ChapterService
	Plays a CHAPTER (an ordered list of mission ids, from `configs/Chapters.luau`) by
	feeding its missions to the MissionRuntimeService one after another. This is the
	thin driver that replaced the old hardcoded Chapter 1 slice — Chapter 1 is now
	pure data.

	In the Forgotten Lands it auto-starts the configured chapter once a player is
	present (dev flow, no Hub teleport yet). Later the Hub/teleport path will pass the
	chapter/mission via teleport data instead of a config default.

	Place: Forgotten Lands ONLY (Server/World). Phase: Missions.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local GameService = require(Server.Services.GameService)
local MissionRuntimeService = require(script.Parent.MissionRuntimeService)
local Net = require(ReplicatedStorage.Shared.Net)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local ChapterService = {}

ChapterService.Name = "ChapterService"

local log = Logger.new("ChapterService")

-- Seconds to let a joining player's client load before the first mission starts.
local START_DELAY = 2

local activeChapterId: string? = nil
local lastChapterId: string? = nil -- the chapter to retry after a run-over (Play Again)
local missionQueue: { string } = {}

local function startNextMission()
	local missionId = table.remove(missionQueue, 1)
	if not missionId then
		log:info("chapter complete: " .. tostring(activeChapterId))
		activeChapterId = nil
		return
	end
	MissionRuntimeService.startMission(missionId, Players:GetPlayers(), function(completed)
		if completed then
			task.wait(START_DELAY)
			startNextMission()
		else
			-- Run-over: HALT (no auto-restart). Remember the chapter so players can
			-- Play Again on request; DeathService has respawned them idle at spawn.
			log:info("mission failed; chapter halted (awaiting Play Again): " .. tostring(activeChapterId))
			lastChapterId = activeChapterId
			activeChapterId = nil
		end
	end)
end

-- Starts a chapter by id (its missions play in order).
function ChapterService.startChapter(chapterId: string)
	if activeChapterId then
		log:warn("a chapter is already active: " .. tostring(activeChapterId))
		return
	end
	local chapters = Config.get("Chapters")
	local chapter = chapters[chapterId]
	if not chapter then
		log:warn("unknown chapter: " .. tostring(chapterId))
		return
	end
	activeChapterId = chapterId
	missionQueue = table.clone(chapter.missions)
	log:info("starting chapter: " .. chapterId)
	startNextMission()
end

function ChapterService.Init() end

function ChapterService.Start()
	local settings = Config.get("Settings")
	if settings.FeatureFlags.EnableCampaign ~= true then
		log:info("disabled (FeatureFlags.EnableCampaign = false)")
		return
	end
	if GameService.getPlaceRole() ~= Constants.PlaceRole.World then
		log:info("not the Forgotten Lands place; campaign inactive")
		return
	end

	local startChapter: string = (settings.Campaign and settings.Campaign.StartChapter) or "chapter_one"

	local function tryStart()
		if activeChapterId or MissionRuntimeService.isBusy() then
			return
		end
		if #Players:GetPlayers() > 0 then
			ChapterService.startChapter(startChapter)
		end
	end

	Players.PlayerAdded:Connect(function()
		task.wait(START_DELAY)
		tryStart()
	end)
	if #Players:GetPlayers() > 0 then
		task.delay(START_DELAY, tryStart)
	end

	-- Play Again after a run-over: restart the remembered chapter (once, if idle).
	Net.getEvent("RequestPlayAgain").OnServerEvent:Connect(function()
		if not activeChapterId and lastChapterId then
			local chapter = lastChapterId
			lastChapterId = nil
			log:info("Play Again -> restarting chapter " .. chapter)
			ChapterService.startChapter(chapter)
		end
	end)

	log:info("ready")
end

return ChapterService
