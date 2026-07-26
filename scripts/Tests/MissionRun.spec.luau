--!strict
--[[
	MissionRun.spec
	Validates the pure MissionRun progression: sequential objective activation, run
	completion after the last objective, current() tracking, and failure.

	Location: TestService.Tests.MissionRun.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MissionRun = require(ServerScriptService.Server.Domain.MissionRun)
local Enums = require(ReplicatedStorage.Shared.Mission.Enums)

local function twoObjectiveDef()
	return {
		id = "m1",
		displayName = "M1",
		region = "r",
		objectives = {
			{ id = "a", type = Enums.ObjectiveType.Reach, description = "d" },
			{ id = "b", type = Enums.ObjectiveType.Kill, description = "d", target = 2 },
		},
	}
end

return function(t: any)
	t.test("new run is Pending with no current objective", function()
		local run = MissionRun.new(twoObjectiveDef())
		assert(run.status == Enums.MissionStatus.Pending, "Pending")
		assert(run:current() == nil, "no current yet")
		assert(#run.objectives == 2, "two objectives")
	end)

	t.test("activateNext walks the objectives then completes the run", function()
		local run = MissionRun.new(twoObjectiveDef())
		local o1 = run:activateNext()
		assert(o1 and o1.id == "a", "first objective a")
		assert(run.status == Enums.MissionStatus.Active, "run Active")
		assert(o1:isActive(), "a is Active")
		local o2 = run:activateNext()
		assert(o2 and o2.id == "b", "second objective b")
		assert(run:activateNext() == nil, "no third objective")
		assert(run:isComplete(), "run Completed")
	end)

	t.test("current() reflects the active objective", function()
		local run = MissionRun.new(twoObjectiveDef())
		run:activateNext()
		local a = run:current()
		assert(a and a.id == "a", "current a")
		run:activateNext()
		local b = run:current()
		assert(b and b.id == "b", "current b")
	end)

	t.test("fail marks the run and its active objective Failed", function()
		local run = MissionRun.new(twoObjectiveDef())
		local o = run:activateNext()
		run:fail()
		assert(run:isFailed(), "run Failed")
		assert(o and o:isFailed(), "active objective Failed")
	end)

	t.test("activateNext after completion is a no-op", function()
		local run = MissionRun.new({
			id = "m",
			displayName = "m",
			region = "r",
			objectives = { { id = "x", type = Enums.ObjectiveType.Reach, description = "d" } },
		})
		run:activateNext() -- x active
		assert(run:activateNext() == nil, "completes after the single objective")
		assert(run:isComplete(), "run Completed")
		assert(run:activateNext() == nil, "no-op once completed")
	end)
end
