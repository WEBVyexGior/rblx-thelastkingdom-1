--!strict
--[[
	MissionController
	The client half of the mission/objective feed. It receives MissionEvents from the
	server and shows them the SIMPLEST possible way — prints to the Output. No UI, no
	VFX: DEV/TEST feedback only. The real diegetic objective HUD is a later (Tier 3)
	phase built on this same event.

	Place: client (boots in both places; only the World server ever sends to it).
	Phase: Missions.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local MissionController = {}

MissionController.Name = "MissionController"

function MissionController.Init() end

function MissionController.Start()
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
		elseif payload.text ~= nil then
			print(("[MISSION:%s] %s"):format(kind, tostring(payload.text)))
		else
			print(("[MISSION:%s] %s"):format(kind, tostring(payload.objectiveId)))
		end
	end)
end

return MissionController
