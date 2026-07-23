--!strict
--[[
	Match.spec
	Validates the Match domain lifecycle state machine: legal transitions are
	allowed, illegal ones are rejected without mutating state, and Ended is
	terminal.

	Location: TestService.Tests.Match.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local Match = require(ServerScriptService.Server.Domain.Match)

return function(t: any)
	t.test("a new match starts in Created", function()
		local m = Match.new("m1", "mission1", { 1, 2 })
		assert(m.state == Match.States.Created, "expected Created, got " .. tostring(m.state))
	end)

	t.test("walks Created -> Loading -> Active -> Completing -> Ended", function()
		local m = Match.new("m1", "mission1", {})
		assert(m:setState(Match.States.Loading), "Created -> Loading should be allowed")
		assert(m:setState(Match.States.Active), "Loading -> Active should be allowed")
		assert(m:setState(Match.States.Completing), "Active -> Completing should be allowed")
		assert(m:setState(Match.States.Ended), "Completing -> Ended should be allowed")
		assert(m.state == Match.States.Ended, "final state should be Ended")
	end)

	t.test("rejects an illegal transition and leaves state unchanged", function()
		local m = Match.new("m1", "mission1", {})
		assert(not m:setState(Match.States.Active), "Created -> Active must be rejected")
		assert(m.state == Match.States.Created, "state must be unchanged after a rejected transition")
	end)

	t.test("Ended is terminal", function()
		local m = Match.new("m1", "mission1", {})
		m:setState(Match.States.Loading)
		m:setState(Match.States.Ended)
		assert(not m:setState(Match.States.Active), "no transition is allowed out of Ended")
	end)
end
