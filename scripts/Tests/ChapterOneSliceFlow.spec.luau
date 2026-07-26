--!strict
--[[
	ChapterOneSliceFlow.spec
	Validates the Chapter 1 slice flow state machine: the full sequence advances one
	step at a time, skips/backwards/unknown transitions are rejected, next() is
	correct, and Ended is terminal.

	Location: TestService.Tests.ChapterOneSliceFlow.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local Flow = require(ServerScriptService.Server.Domain.ChapterOneSliceFlow)

return function(t: any)
	t.test("the full sequence advances one step at a time", function()
		local order = Flow.Order
		for i = 1, #order - 1 do
			assert(
				Flow.canAdvance(order[i], order[i + 1]),
				("expected %s -> %s to be allowed"):format(order[i], order[i + 1])
			)
		end
	end)

	t.test("next() returns the following state, nil at the end", function()
		assert(Flow.next(Flow.States.Intro) == Flow.States.Exploring, "Intro -> Exploring")
		assert(Flow.next(Flow.States.Encounter) == Flow.States.Reward, "Encounter -> Reward")
		assert(Flow.next(Flow.States.Ended) == nil, "Ended has no next")
	end)

	t.test("rejects skipping a state", function()
		assert(not Flow.canAdvance(Flow.States.Intro, Flow.States.Objective), "Intro -> Objective must be rejected")
		assert(not Flow.canAdvance(Flow.States.Exploring, Flow.States.Encounter), "Exploring -> Encounter must be rejected")
	end)

	t.test("rejects going backwards", function()
		assert(not Flow.canAdvance(Flow.States.Objective, Flow.States.Exploring), "Objective -> Exploring must be rejected")
		assert(not Flow.canAdvance(Flow.States.Reward, Flow.States.Intro), "Reward -> Intro must be rejected")
	end)

	t.test("rejects an unknown state", function()
		assert(not Flow.canAdvance("Bogus", Flow.States.Intro), "unknown 'from' must be rejected")
		assert(Flow.next("Bogus") == nil, "unknown state has no next")
	end)

	t.test("Ended is terminal", function()
		assert(Flow.isTerminal(Flow.States.Ended), "Ended is terminal")
		assert(not Flow.isTerminal(Flow.States.Intro), "Intro is not terminal")
		assert(not Flow.canAdvance(Flow.States.Ended, Flow.States.Intro), "no step out of Ended")
	end)
end
