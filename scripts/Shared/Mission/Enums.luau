--!strict
--[[
	Mission.Enums
	Shared enum-like tables for the mission/objective system. String values so they
	are stable across the network and in config data.

	Location: ReplicatedStorage.Shared.Mission.Enums
]]

local Enums = {}

-- The kind of an objective. Determines which World tracker drives its progress.
Enums.ObjectiveType = table.freeze({
	Reach = "Reach", -- get any player within a target radius
	Kill = "Kill", -- defeat N enemies
	Survive = "Survive", -- stay alive for N seconds
	Defend = "Defend", -- keep a target alive for N seconds
	Escort = "Escort", -- bring an NPC to a destination
	Interact = "Interact", -- interact with a target
})

-- Lifecycle of a single objective within a run.
Enums.ObjectiveStatus = table.freeze({
	Inactive = "Inactive", -- not yet started
	Active = "Active", -- currently being pursued
	Completed = "Completed",
	Failed = "Failed",
})

-- Lifecycle of a whole mission run.
Enums.MissionStatus = table.freeze({
	Pending = "Pending",
	Active = "Active",
	Completed = "Completed",
	Failed = "Failed",
})

return table.freeze(Enums)
