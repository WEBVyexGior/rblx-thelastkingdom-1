--!strict
--[[
	Progression (domain)
	PURE XP -> level maths. Given a current (xp, level), an XP amount, and an
	experience curve, it returns the new (xp, level) and how many levels were gained.
	No Roblox, no config reads inside — the caller passes the curve — so it is fully
	unit-testable.

	Curve contract: `XpToLevel[level]` is the XP needed to go FROM `level` to level+1.
	`MaxLevel` caps progression (defaults to #XpToLevel + 1).

	Location: ServerScriptService.Server.Domain.Progression
]]

local Progression = {}

export type Curve = {
	MaxLevel: number?,
	XpToLevel: { number },
}

-- Adds `amount` XP starting from (xp, level). Returns (newXp, newLevel, levelsGained).
-- Rolls over as many levels as the total supports; clamps at MaxLevel (leftover XP is
-- kept but never triggers a level past the cap).
function Progression.addXp(xp: number, level: number, amount: number, curve: Curve): (number, number, number)
	local toLevel = curve.XpToLevel
	local maxLevel = curve.MaxLevel or (#toLevel + 1)
	local newXp = xp + math.max(0, amount)
	local newLevel = math.max(1, level)
	local gained = 0

	while newLevel < maxLevel do
		local need = toLevel[newLevel]
		if not need or newXp < need then
			break
		end
		newXp -= need
		newLevel += 1
		gained += 1
	end

	return newXp, newLevel, gained
end

-- XP still needed to reach the next level (0 at max level).
function Progression.xpToNext(xp: number, level: number, curve: Curve): number
	local maxLevel = curve.MaxLevel or (#curve.XpToLevel + 1)
	if level >= maxLevel then
		return 0
	end
	local need = curve.XpToLevel[level]
	if not need then
		return 0
	end
	return math.max(0, need - xp)
end

return Progression
