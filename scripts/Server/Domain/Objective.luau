--!strict
--[[
	Objective (domain class)
	One objective inside a mission run. PURE data + rules — no Roblox instances, no
	world events. A World "tracker" reads its `def` and pushes progress in; this
	class only owns the count/target/status transitions, so it is unit-testable.

	Progress model (type-agnostic): current advances toward target; reaching target
	completes it. `target` defaults to 1, so one-shot objectives (Reach, Interact)
	just complete on a single step.

	Location: ServerScriptService.Server.Domain.Objective
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage.Shared.Mission.Enums)
local Types = require(ReplicatedStorage.Shared.Mission.Types)

local Objective = {}
Objective.__index = Objective

export type Objective = typeof(setmetatable(
	{} :: {
		id: string,
		type: string,
		target: number,
		current: number,
		status: string,
		def: Types.ObjectiveDef,
	},
	Objective
))

function Objective.new(def: Types.ObjectiveDef): Objective
	return setmetatable({
		id = def.id,
		type = def.type,
		target = def.target or 1,
		current = 0,
		status = Enums.ObjectiveStatus.Inactive,
		def = def,
	}, Objective)
end

-- Inactive -> Active. Returns false if not currently Inactive.
function Objective.activate(self: Objective): boolean
	if self.status ~= Enums.ObjectiveStatus.Inactive then
		return false
	end
	self.status = Enums.ObjectiveStatus.Active
	return true
end

-- Adds `amount` progress (clamped). Returns true if this call completed it.
function Objective.addProgress(self: Objective, amount: number): boolean
	return self:setProgress(self.current + amount)
end

-- Sets absolute progress (clamped to [0, target]). Returns true if it just
-- completed. No-op unless Active.
function Objective.setProgress(self: Objective, value: number): boolean
	if self.status ~= Enums.ObjectiveStatus.Active then
		return false
	end
	self.current = math.clamp(value, 0, self.target)
	if self.current >= self.target then
		self.status = Enums.ObjectiveStatus.Completed
		return true
	end
	return false
end

-- Forces completion (one-shot objectives like Reach/Interact). Returns true if it
-- transitioned to Completed.
function Objective.complete(self: Objective): boolean
	if self.status ~= Enums.ObjectiveStatus.Active then
		return false
	end
	self.current = self.target
	self.status = Enums.ObjectiveStatus.Completed
	return true
end

-- Marks it Failed (e.g. a Defend target died). Returns true if it transitioned.
function Objective.fail(self: Objective): boolean
	if self.status == Enums.ObjectiveStatus.Completed or self.status == Enums.ObjectiveStatus.Failed then
		return false
	end
	self.status = Enums.ObjectiveStatus.Failed
	return true
end

function Objective.isActive(self: Objective): boolean
	return self.status == Enums.ObjectiveStatus.Active
end

function Objective.isComplete(self: Objective): boolean
	return self.status == Enums.ObjectiveStatus.Completed
end

function Objective.isFailed(self: Objective): boolean
	return self.status == Enums.ObjectiveStatus.Failed
end

return Objective
