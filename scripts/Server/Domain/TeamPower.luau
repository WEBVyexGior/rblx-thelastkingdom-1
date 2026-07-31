--!strict
--[[
	TeamPower (domain)
	PURE arithmetic for "how strong is this party, and how hard should their run
	be". No Roblox, no players — levels and curves go in, numbers come out — so
	the whole difficulty contract is unit-testable.

	The design, in one line: a party is rated out of 10 from the weapons it
	fights with, and the enemies scale by HALF of whatever the party gained.

	Why half and not all of it: if enemies matched the party's growth exactly,
	upgrading a weapon would buy nothing — you hit harder, they last longer, net
	zero, and the gold was wasted. At half, the player keeps a real and permanent
	advantage for every level bought, while the run never becomes a walk. This is
	the single most important number in the file.

	Ratings may be fractional (a party of 4.5), so multipliers are interpolated
	between the curve's whole levels.

	Location: ServerScriptService.Server.Domain.TeamPower
]]

local TeamPower = {}

export type Step = { Cost: number, DamageMultiplier: number }
export type Curve = { MaxLevel: number, Levels: { Step } }
export type Tier = { id: string, maxRating: number }

--============================================================================
-- Rating a player
--============================================================================

--[[
	AVERAGE punishes collecting. A player with one +10 sword rates 10; the moment
	they buy an axe at +1 they rate 5.5 — weaker for having acquired something.
	Worse, it is farmable: buy three cheap weapons, sink your rating, and take a
	+10 sword into an easy match.

	BEST rates a player by the weapon they will actually swing, which is both
	honest and unexploitable — no purchase can ever lower it.

	Both are here because the choice is the designer's; `Best` is the safe one.
]]
function TeamPower.playerRating(levels: { number }, mode: string?): number
	if #levels == 0 then
		return 1
	end

	if mode == "Average" then
		local total = 0
		for _, level in levels do
			total += level
		end
		return total / #levels
	end

	local best = levels[1]
	for _, level in levels do
		if level > best then
			best = level
		end
	end
	return best
end

-- The party is the average of its members: four players at 4.3, 7, 2 and 5 make
-- a 4.575 party. One strong player cannot carry the rating, and one weak player
-- cannot sink it.
function TeamPower.partyRating(ratings: { number }): number
	if #ratings == 0 then
		return 1
	end
	local total = 0
	for _, rating in ratings do
		total += rating
	end
	return total / #ratings
end

--============================================================================
-- Turning a rating into difficulty
--============================================================================

-- The damage multiplier at a possibly fractional rating, read off the upgrade
-- curve and interpolated between its whole levels.
function TeamPower.multiplierFor(curve: Curve, rating: number): number
	local top = #curve.Levels
	local clamped = math.clamp(rating, 1, top)
	local lower = math.floor(clamped)
	if lower >= top then
		return curve.Levels[top].DamageMultiplier
	end

	local fraction = clamped - lower
	local from = curve.Levels[lower].DamageMultiplier
	local to = curve.Levels[lower + 1].DamageMultiplier
	return from + ((to - from) * fraction)
end

-- How far above a freshly forged weapon this party hits, as a fraction:
-- 1.0 means "twice as hard as level 1".
function TeamPower.partyGain(curve: Curve, rating: number): number
	return TeamPower.multiplierFor(curve, rating) - 1
end

--[[
	What to multiply an enemy's health, damage and speed by for this party.

	`share` is the fraction of the party's gain the enemies are allowed to match —
	0.5 by default, the number the whole difficulty design rests on. Pass 1/3 for
	a gentler ride, 1 to make upgrading pointless.
]]
function TeamPower.enemyScale(curve: Curve, rating: number, share: number?): number
	return 1 + (TeamPower.partyGain(curve, rating) * (share or 0.5))
end

-- The advantage the party actually keeps after the enemies have scaled. Above
-- 1 means upgrading was worth it; at or below 1 the difficulty curve is broken
-- and this is the number to check when tuning `share`.
function TeamPower.netAdvantage(curve: Curve, rating: number, share: number?): number
	return TeamPower.multiplierFor(curve, rating) / TeamPower.enemyScale(curve, rating, share)
end

-- The label shown in the lobby. Tiers are ascending; the last one catches
-- everything above the final bound.
function TeamPower.tierFor(rating: number, tiers: { Tier }): string?
	if #tiers == 0 then
		return nil
	end
	for _, tier in tiers do
		if rating <= tier.maxRating then
			return tier.id
		end
	end
	return tiers[#tiers].id
end

return TeamPower
