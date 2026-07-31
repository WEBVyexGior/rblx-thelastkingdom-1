--!strict
--[[
	TeamPower.spec
	Validates the difficulty contract: how a player and a party are rated, how
	that becomes an enemy multiplier, and — the test that matters most — that
	upgrading a weapon always leaves the player better off than before.

	Location: TestService.Tests.TeamPower.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local TeamPower = require(ServerScriptService.Server.Domain.TeamPower)

-- Doubling at the top, like the real curve in configs/Economy.
local CURVE = {
	MaxLevel = 10,
	Levels = {
		{ Cost = 0, DamageMultiplier = 1.0 },
		{ Cost = 80, DamageMultiplier = 1.1 },
		{ Cost = 130, DamageMultiplier = 1.21 },
		{ Cost = 205, DamageMultiplier = 1.33 },
		{ Cost = 320, DamageMultiplier = 1.46 },
		{ Cost = 495, DamageMultiplier = 1.61 },
		{ Cost = 760, DamageMultiplier = 1.77 },
		{ Cost = 1150, DamageMultiplier = 1.95 },
		{ Cost = 1720, DamageMultiplier = 2.14 },
		{ Cost = 2600, DamageMultiplier = 2.36 },
	},
}

local TIERS = {
	{ id = "Recruit", maxRating = 3 },
	{ id = "Soldier", maxRating = 7 },
	{ id = "Veteran", maxRating = 9 },
	{ id = "Champion", maxRating = 10 },
}

local function close(a: number, b: number): boolean
	return math.abs(a - b) < 0.001
end

return function(t: any)
	t.test("a player with no weapons rates 1, not 0", function()
		assert(TeamPower.playerRating({}) == 1, "an unarmed player is still level 1")
	end)

	t.test("Best rates a player by the weapon they will actually swing", function()
		assert(TeamPower.playerRating({ 10, 1, 1 }) == 10, "the sword, not the average")
		assert(TeamPower.playerRating({ 1, 4, 8 }) == 8, "the bow")
	end)

	t.test("Best cannot be lowered by acquiring another weapon", function()
		local before = TeamPower.playerRating({ 10 })
		local after = TeamPower.playerRating({ 10, 1 })
		assert(after >= before, "buying a weak axe must never make you weaker")
	end)

	t.test("Average is the alternative, and does drop when a weapon is added", function()
		assert(close(TeamPower.playerRating({ 1, 4, 8 }, "Average"), 13 / 3), "13 over 3")
		assert(TeamPower.playerRating({ 10, 1 }, "Average") == 5.5, "collecting costs rating")
	end)

	t.test("a party is the average of its members", function()
		assert(close(TeamPower.partyRating({ 4.3, 7, 2, 5 }), 18.3 / 4), "18.3 over 4")
		assert(TeamPower.partyRating({}) == 1, "an empty party still has a floor")
	end)

	t.test("multipliers interpolate between whole levels", function()
		assert(close(TeamPower.multiplierFor(CURVE, 1), 1.0), "level 1 is the base")
		assert(close(TeamPower.multiplierFor(CURVE, 2), 1.1), "level 2 reads exactly")
		-- Half way between 1.1 and 1.21
		assert(close(TeamPower.multiplierFor(CURVE, 2.5), 1.155), "2.5 sits between")
	end)

	t.test("ratings outside the curve are clamped", function()
		assert(close(TeamPower.multiplierFor(CURVE, 0), 1.0), "below the floor")
		assert(close(TeamPower.multiplierFor(CURVE, 99), 2.36), "above the cap")
	end)

	t.test("enemies scale by half of what the party gained", function()
		-- At +10 the party hits 2.36x, i.e. +136%. Enemies take half: +68%.
		assert(close(TeamPower.enemyScale(CURVE, 10), 1.68), "half of 1.36")
		assert(close(TeamPower.enemyScale(CURVE, 1), 1.0), "a fresh party fights the baseline")
	end)

	t.test("share controls how much of the gain enemies are allowed", function()
		assert(close(TeamPower.enemyScale(CURVE, 10, 1 / 3), 1 + 1.36 / 3), "a gentler third")
		assert(close(TeamPower.enemyScale(CURVE, 10, 1), 2.36), "matching exactly cancels out")
	end)

	t.test("THE RULE: upgrading always leaves the party ahead", function()
		-- If this ever fails, gold buys nothing and the whole economy is pointless.
		local previous = 0
		for rating = 1, 10 do
			local advantage = TeamPower.netAdvantage(CURVE, rating)
			assert(advantage >= 1, "never worse off than a fresh party")
			assert(advantage > previous, "every level must be a real gain")
			previous = advantage
		end
	end)

	t.test("matching the gain exactly makes upgrading pointless", function()
		-- The failure mode the half-share exists to prevent.
		assert(close(TeamPower.netAdvantage(CURVE, 10, 1), 1), "all that gold bought nothing")
	end)

	t.test("tiers bucket a rating into a lobby label", function()
		assert(TeamPower.tierFor(1, TIERS) == "Recruit", "fresh")
		assert(TeamPower.tierFor(4.5, TIERS) == "Soldier", "the worked example")
		assert(TeamPower.tierFor(8.2, TIERS) == "Veteran", "high")
		assert(TeamPower.tierFor(10, TIERS) == "Champion", "the top")
		assert(TeamPower.tierFor(99, TIERS) == "Champion", "clamps")
	end)
end
