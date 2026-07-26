--!strict
--[[
	Objective.spec
	Validates the pure Objective progress/status rules: activation gating, progress
	counting/clamping, one-shot completion, and failure.

	Location: TestService.Tests.Objective.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Objective = require(ServerScriptService.Server.Domain.Objective)
local Enums = require(ReplicatedStorage.Shared.Mission.Enums)

local function kill3()
	return Objective.new({ id = "o1", type = Enums.ObjectiveType.Kill, description = "d", target = 3 })
end

return function(t: any)
	t.test("new objective starts Inactive with 0 progress", function()
		local o = kill3()
		assert(o.status == Enums.ObjectiveStatus.Inactive, "expected Inactive")
		assert(o.current == 0, "expected 0 progress")
		assert(o.target == 3, "expected target 3")
	end)

	t.test("target defaults to 1", function()
		local o = Objective.new({ id = "r", type = Enums.ObjectiveType.Reach, description = "d" })
		assert(o.target == 1, "default target should be 1")
	end)

	t.test("progress is ignored until activated", function()
		local o = kill3()
		assert(not o:addProgress(1), "no progress before activate")
		assert(o.current == 0, "still 0 before activate")
		assert(o:activate(), "activate ok")
		assert(not o:addProgress(1), "1/3 not complete")
		assert(o.current == 1, "current 1")
	end)

	t.test("completes when progress reaches target", function()
		local o = kill3()
		o:activate()
		o:addProgress(2)
		assert(o:addProgress(1), "third progress completes")
		assert(o:isComplete(), "status Completed")
		assert(o.current == 3, "current 3")
	end)

	t.test("progress clamps at target", function()
		local o = kill3()
		o:activate()
		assert(o:addProgress(10), "overshoot completes")
		assert(o.current == 3, "clamped to 3")
	end)

	t.test("setProgress completes at/above target", function()
		local o = Objective.new({ id = "s", type = Enums.ObjectiveType.Survive, description = "d", target = 5 })
		o:activate()
		assert(not o:setProgress(3), "3/5 not done")
		assert(o:setProgress(5), "5/5 done")
		assert(o:isComplete(), "completed")
	end)

	t.test("complete() one-shots an active objective", function()
		local o = Objective.new({ id = "r", type = Enums.ObjectiveType.Reach, description = "d" })
		o:activate()
		assert(o:complete(), "reach completes")
		assert(o:isComplete(), "completed")
	end)

	t.test("fail marks Failed and blocks further progress/completion", function()
		local o = kill3()
		o:activate()
		assert(o:fail(), "should fail")
		assert(o:isFailed(), "status Failed")
		assert(not o:addProgress(1), "no progress after fail")
		assert(not o:complete(), "cannot complete a failed objective")
	end)

	t.test("cannot activate twice", function()
		local o = kill3()
		assert(o:activate(), "first activate ok")
		assert(not o:activate(), "second activate rejected")
	end)
end
