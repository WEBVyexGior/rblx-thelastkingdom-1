--!strict
--[[
	Health.spec
	Validates the combat Health model: clamping, death latching, healing rules,
	and the Died signal firing exactly once.

	Location: TestService.Tests.Health.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local Health = require(ServerScriptService.Server.Domain.Combat.Health)

return function(t: any)
	t.test("starts full and alive", function()
		local h = Health.new(100)
		assert(h.current == 100 and h.max == 100, "should start at max")
		assert(not h:isDead(), "should start alive")
		assert(h:getPercent() == 1, "percent should be 1 at full")
	end)

	t.test("damage reduces current and clamps at zero", function()
		local h = Health.new(50)
		local removed, killed = h:damage(20)
		assert(removed == 20 and not killed, "20 removed, not killed")
		assert(h.current == 30, "current should be 30")
		removed, killed = h:damage(100)
		assert(killed, "overkill should kill")
		assert(h.current == 0, "current clamps at 0")
		assert(removed == 30, "only the remaining 30 is removed")
	end)

	t.test("dead health ignores further damage and healing", function()
		local h = Health.new(10)
		h:damage(10)
		assert(h:isDead(), "should be dead")
		assert(h:damage(5) == 0, "no damage after death")
		assert(h:heal(5) == 0, "cannot heal the dead")
	end)

	t.test("heal restores up to max", function()
		local h = Health.new(100)
		h:damage(60)
		assert(h:heal(1000) == 60, "heal clamps to max")
		assert(h.current == 100, "back to full")
	end)

	t.test("Died fires exactly once", function()
		local h = Health.new(10)
		local count = 0
		h.Died:connect(function()
			count += 1
		end)
		h:damage(5)
		h:damage(5)
		h:damage(5)
		assert(count == 1, "Died should fire exactly once")
	end)
end
