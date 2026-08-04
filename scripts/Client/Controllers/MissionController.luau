--!strict
--[[
	MissionController
	The client half of the mission feed.

	Two jobs:

	  1. The ONE LINE at the top of the screen saying what to do now. Any server
	     system can push to it (`ObjectiveHint`) — the mission does, and so does
	     whatever mechanic the current area is running.

	  2. Printing the rest of the MissionEvent feed to the Output. That is still
	     DEV/TEST feedback: mission start, narrative, rewards and progress have
	     no screen presence yet and are not meant to until the story pass.

	The HUD is created LAZILY, on the first hint that arrives. This controller
	boots in both places and only the Forgotten Lands server ever sends one, so
	the Hub never builds a ScreenGui it would not use — and no place check has to
	be kept in sync with anything.

	Place: client (boots in both places). Phase: Missions.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local ObjectiveHud = require(script.Parent.Parent.UI.ObjectiveHud)

local MissionController = {}

MissionController.Name = "MissionController"

local hud: ObjectiveHud.Handle? = nil

local function ensureHud(): ObjectiveHud.Handle
	local existing = hud
	if existing then
		return existing
	end
	local created = ObjectiveHud.create()
	hud = created
	return created
end

function MissionController.Init() end

function MissionController.Start()
	--------------------------------------------------------------------------
	-- What to do now
	--------------------------------------------------------------------------
	Net.getEvent("ObjectiveHint").OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local source = tostring(payload.source or "mission")
		local text = if typeof(payload.text) == "string" then payload.text else nil
		ensureHud().set(source, text)
	end)

	--------------------------------------------------------------------------
	-- Everything else, to the Output
	--------------------------------------------------------------------------
	local missionEvent = Net.getEvent("MissionEvent")
	missionEvent.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local kind = tostring(payload.kind)
		if kind == "objectiveProgress" then
			print(("[MISSION:progress] %s  %s/%s"):format(
				tostring(payload.objectiveId),
				tostring(payload.current),
				tostring(payload.target)
			))
		elseif kind == "reward" then
			print(("[MISSION:reward] %s  (+%s gold, +%s xp -> level %s%s)"):format(
				tostring(payload.text),
				tostring(payload.currency),
				tostring(payload.xp),
				tostring(payload.level),
				if payload.leveledUp then " — LEVEL UP!" else ""
			))
		elseif payload.text ~= nil then
			print(("[MISSION:%s] %s"):format(kind, tostring(payload.text)))
		else
			print(("[MISSION:%s] %s"):format(kind, tostring(payload.objectiveId)))
		end
	end)
end

return MissionController
