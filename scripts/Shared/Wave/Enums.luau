--!strict
--[[
	Wave.Enums
	Shared enum-like tables for the encounter/wave system. String values so they are
	stable across the network and in config data.

	Location: ReplicatedStorage.Shared.Wave.Enums
]]

local Enums = {}

-- Lifecycle of a whole encounter (a structured battle of one or more waves).
Enums.EncounterStatus = table.freeze({
	Pending = "Pending",
	Active = "Active",
	Completed = "Completed",
	Failed = "Failed",
})

-- Lifecycle of a single wave within an encounter.
Enums.WaveStatus = table.freeze({
	Pending = "Pending",
	Active = "Active",
	Cleared = "Cleared",
})

-- How an encounter's waves progress.
Enums.WaveMode = table.freeze({
	Sequential = "Sequential", -- each wave starts when the previous is cleared
	Parallel = "Parallel", -- all waves active at once
})

return table.freeze(Enums)
