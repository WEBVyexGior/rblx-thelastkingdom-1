--!strict
--[[
	Progression.spec
	Validates the pure XP -> level maths: thresholds, remainder carry, multi-level
	rollover, MaxLevel cap, negative-amount guard, and xpToNext.

	Location: TestService.Tests.Progression.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local Progression = require(ServerScriptService.Server.Domain.Progression)

-- lvl 1->2 = 100, 2->3 = 200, 3->4 = 400; cap at level 4.
local CURVE = { MaxLevel = 4, XpToLevel = { 100, 200, 400 } }

return function(t: any)
	t.test("xp below the threshold does not level up", function()
		local xp, level, gained = Progression.addXp(0, 1, 50, CURVE)
		assert(xp == 50 and level == 1 and gained == 0, "50/100, still level 1")
	end)

	t.test("reaching the threshold levels up and carries the remainder", function()
		local xp, level, gained = Progression.addXp(0, 1, 130, CURVE)
		assert(level == 2 and gained == 1, "level 2, +1")
		assert(xp == 30, "remainder 30 (130 - 100)")
	end)

	t.test("a large amount rolls over multiple levels", function()
		local xp, level, gained = Progression.addXp(0, 1, 350, CURVE)
		assert(level == 3 and gained == 2, "level 3, +2 (100 then 200)")
		assert(xp == 50, "remainder 50")
	end)

	t.test("caps at MaxLevel and keeps leftover xp", function()
		local xp, level, gained = Progression.addXp(0, 1, 99999, CURVE)
		assert(level == 4 and gained == 3, "capped at level 4")
		assert(xp == 99299, "leftover kept (99999 - 100 - 200 - 400), no overflow past cap")
	end)

	t.test("negative amounts are ignored", function()
		local xp, level, gained = Progression.addXp(20, 1, -50, CURVE)
		assert(xp == 20 and level == 1 and gained == 0, "no change on a negative amount")
	end)

	t.test("xpToNext reports remaining xp, and 0 at the cap", function()
		assert(Progression.xpToNext(30, 1, CURVE) == 70, "70 to next level")
		assert(Progression.xpToNext(0, 4, CURVE) == 0, "0 at max level")
	end)
end
