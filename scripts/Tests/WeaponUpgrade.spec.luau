--!strict
--[[
	WeaponUpgrade.spec
	Validates the forge arithmetic: costs, gains, affordability, purchases, and
	the behaviour at both ends of the curve (a fresh weapon and a maxed one).

	Location: TestService.Tests.WeaponUpgrade.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local WeaponUpgrade = require(ServerScriptService.Server.Domain.WeaponUpgrade)

-- A short, round curve: the real one lives in configs/Economy.
local CURVE = {
	MaxLevel = 4,
	Levels = {
		{ Cost = 0, DamageMultiplier = 1.0 },
		{ Cost = 100, DamageMultiplier = 1.5 },
		{ Cost = 200, DamageMultiplier = 2.0 },
		{ Cost = 400, DamageMultiplier = 3.0 },
	},
}

return function(t: any)
	t.test("a freshly forged weapon is level 1, costs nothing and multiplies nothing", function()
		assert(WeaponUpgrade.multiplierAt(CURVE, 1) == 1, "no bonus at +1")
		assert(WeaponUpgrade.investedTo(CURVE, 1) == 0, "nothing spent yet")
		assert(WeaponUpgrade.damageAt(CURVE, 40, 1) == 40, "base damage untouched")
	end)

	t.test("costToNext reads the price of the level being bought", function()
		assert(WeaponUpgrade.costToNext(CURVE, 1) == 100, "1 -> 2 costs 100")
		assert(WeaponUpgrade.costToNext(CURVE, 3) == 400, "3 -> 4 costs 400")
	end)

	t.test("damage scales off the weapon's own base", function()
		assert(WeaponUpgrade.damageAt(CURVE, 40, 3) == 80, "40 at x2.0")
		assert(WeaponUpgrade.damageAt(CURVE, 10, 3) == 20, "a weak weapon gains less")
	end)

	t.test("damageGain reports what the next purchase adds", function()
		-- 40 -> 60 at x1.5
		assert(WeaponUpgrade.damageGain(CURVE, 40, 1) == 20, "+20 for the first upgrade")
		assert(WeaponUpgrade.damageGain(CURVE, 40, 3) == 40, "+40 for the last")
	end)

	t.test("affordability is decided by the price of the NEXT level", function()
		assert(not WeaponUpgrade.canAfford(CURVE, 1, 99), "99 gold is not enough for 100")
		assert(WeaponUpgrade.canAfford(CURVE, 1, 100), "exactly enough counts")
	end)

	t.test("purchase advances the level and takes only the price", function()
		local level, gold = WeaponUpgrade.purchase(CURVE, 1, 250)
		assert(level == 2, "moved to +2")
		assert(gold == 150, "paid 100 of 250")
	end)

	t.test("purchase refuses when the gold is short and changes nothing", function()
		local level, gold = WeaponUpgrade.purchase(CURVE, 1, 50)
		assert(level == nil and gold == nil, "no partial purchase")
	end)

	t.test("a maxed weapon cannot be bought further", function()
		assert(WeaponUpgrade.isMaxed(CURVE, 4), "4 is the top")
		assert(WeaponUpgrade.costToNext(CURVE, 4) == 0, "nothing left to buy")
		assert(WeaponUpgrade.damageGain(CURVE, 40, 4) == 0, "no gain to advertise")
		assert(not WeaponUpgrade.canAfford(CURVE, 4, 999999), "gold cannot help")
		local level = WeaponUpgrade.purchase(CURVE, 4, 999999)
		assert(level == nil, "purchase refused at the cap")
	end)

	t.test("investedTo sums every level paid for so far", function()
		assert(WeaponUpgrade.investedTo(CURVE, 3) == 300, "100 + 200")
		assert(WeaponUpgrade.investedTo(CURVE, 4) == 700, "100 + 200 + 400")
	end)

	t.test("levels outside the curve are clamped rather than fatal", function()
		-- An old profile, or a bad write, must never take the forge down.
		assert(WeaponUpgrade.multiplierAt(CURVE, 0) == 1, "below the floor reads as +1")
		assert(WeaponUpgrade.multiplierAt(CURVE, 99) == 3, "above the cap reads as the top")
	end)
end
