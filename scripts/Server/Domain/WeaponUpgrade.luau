--!strict
--[[
	WeaponUpgrade (domain)
	PURE arithmetic of the blacksmith's forge: what a level costs, what it gives,
	and whether a purse can pay for it. No Roblox, no player, no inventory — the
	curve is passed in — so every rule here is unit-testable.

	Levels are 1-based and level 1 is the weapon as forged: it costs nothing and
	multiplies nothing. "Upgrading to +N" therefore means paying the cost stored
	at level N.

	Location: ServerScriptService.Server.Domain.WeaponUpgrade
]]

local WeaponUpgrade = {}

export type Step = { Cost: number, DamageMultiplier: number }
export type Curve = { MaxLevel: number, Levels: { Step } }

-- Levels below 1 or beyond the curve are clamped rather than rejected: a profile
-- written by an older build must never crash the forge.
local function clamp(curve: Curve, level: number): number
	return math.clamp(math.floor(level), 1, #curve.Levels)
end

function WeaponUpgrade.maxLevel(curve: Curve): number
	return math.min(curve.MaxLevel, #curve.Levels)
end

function WeaponUpgrade.isMaxed(curve: Curve, level: number): boolean
	return clamp(curve, level) >= WeaponUpgrade.maxLevel(curve)
end

-- Gold to go from `level` to `level + 1`. Zero once there is nowhere left to go,
-- so callers never have to special-case the top of the curve.
function WeaponUpgrade.costToNext(curve: Curve, level: number): number
	local current = clamp(curve, level)
	if WeaponUpgrade.isMaxed(curve, current) then
		return 0
	end
	return curve.Levels[current + 1].Cost
end

function WeaponUpgrade.multiplierAt(curve: Curve, level: number): number
	return curve.Levels[clamp(curve, level)].DamageMultiplier
end

-- What the weapon actually hits for at this level. Rounded, because damage the
-- player sees and damage the server deals must be the same number.
function WeaponUpgrade.damageAt(curve: Curve, baseDamage: number, level: number): number
	return math.floor((baseDamage * WeaponUpgrade.multiplierAt(curve, level)) + 0.5)
end

-- The number the shop puts next to the price: what this purchase adds.
function WeaponUpgrade.damageGain(curve: Curve, baseDamage: number, level: number): number
	if WeaponUpgrade.isMaxed(curve, level) then
		return 0
	end
	local current = clamp(curve, level)
	return WeaponUpgrade.damageAt(curve, baseDamage, current + 1)
		- WeaponUpgrade.damageAt(curve, baseDamage, current)
end

function WeaponUpgrade.canAfford(curve: Curve, level: number, gold: number): boolean
	if WeaponUpgrade.isMaxed(curve, level) then
		return false
	end
	return gold >= WeaponUpgrade.costToNext(curve, level)
end

-- Attempts the purchase. Returns the new level and the gold left, or nil when it
-- cannot be made — the caller never has to re-derive why.
function WeaponUpgrade.purchase(curve: Curve, level: number, gold: number): (number?, number?)
	if not WeaponUpgrade.canAfford(curve, level, gold) then
		return nil, nil
	end
	local current = clamp(curve, level)
	return current + 1, gold - WeaponUpgrade.costToNext(curve, current)
end

-- Total gold spent to reach `level` from a freshly forged weapon. Used by the
-- shop to show what a weapon has cost so far.
function WeaponUpgrade.investedTo(curve: Curve, level: number): number
	local total = 0
	for index = 2, clamp(curve, level) do
		total += curve.Levels[index].Cost
	end
	return total
end

return WeaponUpgrade
