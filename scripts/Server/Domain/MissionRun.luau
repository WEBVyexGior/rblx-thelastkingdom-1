--!strict
--[[
	MissionRun (domain class)
	A running instance of a mission: its objectives and where we are in the sequence.
	PURE — it owns progression rules (activate objectives in order, complete the run
	when the last one completes, fail the run on demand) and nothing about the world.
	Unit-testable in isolation.

	Objectives are SEQUENTIAL here (one active at a time). Parallel objectives are a
	straightforward extension (activate a group instead of one).

	Location: ServerScriptService.Server.Domain.MissionRun
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage.Shared.Mission.Enums)
local Types = require(ReplicatedStorage.Shared.Mission.Types)
local Objective = require(script.Parent.Objective)

local MissionRun = {}
MissionRun.__index = MissionRun

export type MissionRun = typeof(setmetatable(
	{} :: {
		missionId: string,
		def: Types.MissionDef,
		objectives: { Objective.Objective },
		index: number, -- index of the current objective (0 before the first activation)
		status: string,
	},
	MissionRun
))

function MissionRun.new(def: Types.MissionDef): MissionRun
	local objectives: { Objective.Objective } = {}
	for _, odef in def.objectives do
		table.insert(objectives, Objective.new(odef))
	end
	return setmetatable({
		missionId = def.id,
		def = def,
		objectives = objectives,
		index = 0,
		status = Enums.MissionStatus.Pending,
	}, MissionRun)
end

-- The currently active objective, or nil (before start / after completion).
function MissionRun.current(self: MissionRun): Objective.Objective?
	return self.objectives[self.index]
end

-- Advances to and activates the next objective. Returns it, or nil when none
-- remain — in which case the run transitions to Completed. First call moves the
-- run from Pending to Active. No-op (nil) once the run is finished.
function MissionRun.activateNext(self: MissionRun): Objective.Objective?
	if self.status == Enums.MissionStatus.Pending then
		self.status = Enums.MissionStatus.Active
	end
	if self.status ~= Enums.MissionStatus.Active then
		return nil
	end
	self.index += 1
	local obj = self.objectives[self.index]
	if obj then
		obj:activate()
		return obj
	end
	self.status = Enums.MissionStatus.Completed
	return nil
end

-- Fails the whole run (Defend/Escort target lost, party wipe, timeout, …).
function MissionRun.fail(self: MissionRun)
	if self.status == Enums.MissionStatus.Completed or self.status == Enums.MissionStatus.Failed then
		return
	end
	self.status = Enums.MissionStatus.Failed
	local obj = self:current()
	if obj and obj:isActive() then
		obj:fail()
	end
end

function MissionRun.isActive(self: MissionRun): boolean
	return self.status == Enums.MissionStatus.Active
end

function MissionRun.isComplete(self: MissionRun): boolean
	return self.status == Enums.MissionStatus.Completed
end

function MissionRun.isFailed(self: MissionRun): boolean
	return self.status == Enums.MissionStatus.Failed
end

return MissionRun
