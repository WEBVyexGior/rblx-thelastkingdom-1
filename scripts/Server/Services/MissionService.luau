--!strict
--[[
	MissionService
	The Mission Framework: a server-authoritative registry of mission definitions.
	Gameplay phases (or a future Missions config) register missions through here;
	MatchService and the Hub read them to start runs.

	Phase 2 ships an EMPTY registry by design — the framework exists, the content
	does not.

	Place: shared. Phase: Core Systems.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local Mission = require(Server.Domain.Mission)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local MissionService = {}

MissionService.Name = "MissionService"

local log = Logger.new("MissionService")
local registry: { [string]: Mission.MissionDefinition } = {}

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

function MissionService.Init() end

function MissionService.Start()
	log:info("ready")
end

return MissionService
