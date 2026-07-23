--!strict
--[[
	Mission (domain)
	Defines the SHAPE of a mission definition and a validating constructor. This
	is the framework only — no missions are defined here. Real missions are
	registered later (by gameplay phases or a future Missions config) through
	MissionService.

	Location: ServerScriptService.Server.Domain.Mission
]]

export type MissionDefinition = {
	id: string,
	displayName: string,
	region: string,
	-- Objective / reward / difficulty hooks are added in later phases.
}

local Mission = {}

-- Validates a raw mission definition and returns it. Errors loudly on a bad
-- shape so authoring mistakes are caught immediately, not at runtime.
function Mission.define(def: MissionDefinition): MissionDefinition
	assert(type(def.id) == "string" and def.id ~= "", "Mission requires a non-empty id")
	assert(type(def.displayName) == "string", "Mission requires a displayName")
	assert(type(def.region) == "string", "Mission requires a region")
	return def
end

return Mission
