--!strict
--[[
	MissionRuntimeService
	The World engine that RUNS a mission: it turns a MissionDef (data) into a live
	run. It builds a pure MissionRun, drives a Match through its lifecycle, activates
	objectives in order, starts the matching ObjectiveTracker for each, and streams
	MissionEvents to the run's players. On the last objective it completes the run
	(reward + outro); a Defend/Escort failure fails it.

	It is generic — it knows nothing about Chapter 1 specifically. ChapterService
	feeds it mission ids. Single active run for now (single-player / co-op share one
	run); multiple concurrent runs are a later concern.

	Place: Forgotten Lands ONLY (Server/World). Phase: Missions.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local MissionService = require(Server.Services.MissionService)
local MissionRun = require(Server.Domain.MissionRun)
local Match = require(Server.Domain.Match)
local ObjectiveTrackers = require(script.Parent.ObjectiveTrackers)
local RewardService = require(Server.Services.RewardService)
local DeathService = require(script.Parent.DeathService)
local Net = require(ReplicatedStorage.Shared.Net)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local MissionRuntimeService = {}

MissionRuntimeService.Name = "MissionRuntimeService"

local log = Logger.new("MissionRuntimeService")

local missionEvent: RemoteEvent? = nil
local hintEvent: RemoteEvent? = nil

-- Single active run.
local activeRun: MissionRun.MissionRun? = nil
local activeMatch: Match.Match? = nil
local activeStop: (() -> ())? = nil -- the current objective's tracker stop
local runPlayers: { Player } = {}
local onFinishedCb: ((completed: boolean) -> ())? = nil
local finishing = false -- guards finishRun against re-entrancy (stop -> onFail -> fail -> finishRun)
local runId = 0 -- identifies the active run; a stale wipe callback from an old run is ignored
local nextMatchId = 0

local function fire(payload: any)
	if not missionEvent then
		return
	end
	for _, player in runPlayers do
		missionEvent:FireClient(player, payload)
	end
end

local function getRunPlayers(): { Player }
	return runPlayers
end

--[[
	The hint line at the top of the screen: one short sentence saying what to do
	now. Replaces the world waypoint entirely.

	THERE ARE NO "GO HERE" BEAMS. A pillar of light over the objective is the
	fastest way to make a castle feel like a checklist — the player stops
	looking at the building and starts looking at the marker. The area tells you
	where you are (bottom left), this tells you what it wants (top), and the
	world itself has to be legible enough to do the rest. That is a higher bar
	for the level and the right one.
]]
local function sayHint(text: string?)
	if not hintEvent then
		return
	end
	for _, player in runPlayers do
		hintEvent:FireClient(player, { source = "mission", text = text })
	end
end

local function stopTracker()
	if activeStop then
		activeStop()
		activeStop = nil
	end
end

-- Grants `reward` to every run player (server-authoritative, via RewardService) and
-- tells each player their result (currency / xp / level-up) over the mission feed.
local function applyReward(reward: any)
	local granted = RewardService.apply(runPlayers, reward)
	if not missionEvent then
		return
	end
	for player, applied in granted do
		missionEvent:FireClient(player, {
			kind = "reward",
			text = reward.summary,
			currency = applied.currency,
			xp = applied.xp,
			level = applied.newLevel,
			leveledUp = applied.levelsGained > 0,
		})
	end
end

local function finishRun(completed: boolean)
	-- Non-re-entrant: stopTracker() below can bubble a tracker onFail -> ctx.fail ->
	-- finishRun again; ignore that (and any double external call).
	if finishing or not activeRun then
		return
	end
	finishing = true
	stopTracker()
	sayHint(nil)
	DeathService.endRun()
	local match = activeMatch
	if match then
		match:setState(Match.States.Completing)
		match:setState(Match.States.Ended)
	end
	local run = activeRun
	local def = run and run.def
	if def then
		if completed then
			fire({ kind = "missionComplete", missionId = def.id })
			if def.reward then
				applyReward(def.reward)
			end
			if def.outro then
				fire({ kind = "narrative", missionId = def.id, text = def.outro })
			end
		else
			fire({ kind = "missionFailed", missionId = def.id, text = "[PLACEHOLDER] Mission failed." })
		end
	end
	log:info(("mission '%s' %s"):format(def and def.id or "?", if completed then "completed" else "failed"))

	local cb = onFinishedCb
	activeRun = nil
	activeMatch = nil
	runPlayers = {}
	onFinishedCb = nil
	finishing = false -- cleared before the callback so a fresh run (Play Again) can finish later
	if cb then
		cb(completed)
	end
end

local function activateNext()
	local run = activeRun
	if not run then
		return
	end

	local objective = run:activateNext()
	if not objective then
		finishRun(true) -- all objectives complete
		return
	end

	-- What to do now, at the top of the screen. `hint` is the short imperative
	-- written for the player; `description` is the long form kept for the log
	-- and for anywhere a full sentence is wanted.
	sayHint(objective.def.hint or objective.def.description)

	fire({
		kind = "objectiveActive",
		missionId = run.missionId,
		objectiveId = objective.id,
		text = objective.def.description,
		current = 0,
		target = objective.target,
	})

	local function onObjectiveDone()
		stopTracker()
		fire({ kind = "objectiveComplete", missionId = run.missionId, objectiveId = objective.id })
		if objective.def.completionText then
			fire({
				kind = "narrative",
				missionId = run.missionId,
				objectiveId = objective.id,
				text = objective.def.completionText,
			})
		end
		if objective.def.reward then
			applyReward(objective.def.reward)
		end
		activateNext()
	end

	local function reportProgress()
		fire({
			kind = "objectiveProgress",
			missionId = run.missionId,
			objectiveId = objective.id,
			current = objective.current,
			target = objective.target,
		})
	end

	local ctx: ObjectiveTrackers.Context = {
		players = getRunPlayers,
		addProgress = function(amount: number)
			local justDone = objective:addProgress(amount)
			reportProgress()
			if justDone then
				onObjectiveDone()
			end
		end,
		setProgress = function(value: number)
			local justDone = objective:setProgress(value)
			reportProgress()
			if justDone then
				onObjectiveDone()
			end
		end,
		complete = function()
			if objective:complete() then
				onObjectiveDone()
			end
		end,
		fail = function()
			objective:fail()
			run:fail()
			finishRun(false)
		end,
		emit = function(payload: any)
			payload.missionId = run.missionId
			payload.objectiveId = objective.id
			fire(payload)
		end,
	}

	activeStop = ObjectiveTrackers.start(objective, ctx)
end

-- Starts `missionId` for `players`. `onFinished(completed)` fires when the run ends.
-- Returns false if a run is already active or the mission is unknown.
function MissionRuntimeService.startMission(
	missionId: string,
	players: { Player },
	onFinished: ((completed: boolean) -> ())?
): boolean
	if activeRun then
		log:warn("startMission: a run is already active")
		return false
	end
	local def = MissionService.get(missionId)
	if not def then
		log:warn("startMission: unknown mission " .. tostring(missionId))
		return false
	end

	runPlayers = table.clone(players)
	onFinishedCb = onFinished
	activeRun = MissionRun.new(def)

	nextMatchId += 1
	runId += 1
	local myRunId = runId
	local match = Match.new("match_world_" .. nextMatchId, missionId, {})
	match:setState(Match.States.Loading)
	match:setState(Match.States.Active)
	activeMatch = match

	-- The DeathService tracks this run's players and calls back on a total wipe. The
	-- runId check ignores a stale wipe callback fired from a previous (already-ended) run.
	DeathService.beginRun(runPlayers, function()
		if runId == myRunId and activeRun then
			finishRun(false)
		end
	end)

	log:info(("starting mission '%s' for %d player(s)"):format(missionId, #runPlayers))
	fire({ kind = "missionStart", missionId = def.id, text = def.intro })
	activateNext()
	return true
end

function MissionRuntimeService.isBusy(): boolean
	return activeRun ~= nil
end

function MissionRuntimeService.Init() end

function MissionRuntimeService.Start()
	missionEvent = Net.getEvent("MissionEvent")
	hintEvent = Net.getEvent("ObjectiveHint")
	log:info("ready")
end

return MissionRuntimeService
