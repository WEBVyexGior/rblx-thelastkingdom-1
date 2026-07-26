--!strict
--[[
	Mission (domain)
	Defines the SHAPE of a mission definition and a validating constructor. The
	framework only — real missions are DATA in `configs/Missions.luau`, registered
	through MissionService. `define` fails loudly on a bad shape so authoring
	mistakes surface immediately.

	Location: ServerScriptService.Server.Domain.Mission
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage.Shared.Mission.Enums)
local Types = require(ReplicatedStorage.Shared.Mission.Types)

export type MissionDefinition = Types.MissionDef

local Mission = {}

local function validateObjective(o: any, i: number)
	assert(type(o) == "table", ("objective #%d must be a table"):format(i))
	assert(type(o.id) == "string" and o.id ~= "", ("objective #%d requires a non-empty id"):format(i))
	assert(
		type(o.type) == "string" and Enums.ObjectiveType[o.type] ~= nil,
		("objective '%s' has an invalid type '%s'"):format(tostring(o.id), tostring(o.type))
	)
	assert(type(o.description) == "string", ("objective '%s' requires a description"):format(o.id))
	if o.target ~= nil then
		assert(type(o.target) == "number" and o.target > 0, ("objective '%s' target must be > 0"):format(o.id))
	end
	if o.type == Enums.ObjectiveType.Clear then
		assert(
			type(o.encounterId) == "string" and o.encounterId ~= "",
			("objective '%s' (Clear) requires an encounterId"):format(o.id)
		)
	end
end

-- Validates a raw mission definition and returns it.
function Mission.define(def: MissionDefinition): MissionDefinition
	assert(type(def.id) == "string" and def.id ~= "", "Mission requires a non-empty id")
	assert(type(def.displayName) == "string", "Mission requires a displayName")
	assert(type(def.region) == "string", "Mission requires a region")
	assert(
		type(def.objectives) == "table" and #def.objectives > 0,
		("Mission '%s' requires at least one objective"):format(def.id)
	)
	local seen: { [string]: boolean } = {}
	for i, o in def.objectives do
		validateObjective(o, i)
		assert(not seen[o.id], ("Mission '%s' has a duplicate objective id '%s'"):format(def.id, o.id))
		seen[o.id] = true
	end
	return def
end

return Mission
