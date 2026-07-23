--!strict
--[[
	Config: Combat
	Global combat RULES and structure (not weapon- or enemy-specific). Schema
	only — no balancing values are set in this phase.

	Read via: Config.get("Combat")

	NOTE: `Resistances` is sensitive-ish (reveals defensive tuning). It syncs to
	ReplicatedStorage.Config for now while empty; candidate to move server-only
	with the other sensitive configs before real values land (see README).

	Schema:
		FriendlyFire           = boolean,   -- allow same-faction damage (default off/nil)
		CritMultiplier         = number,    -- global crit damage multiplier
		InvulnerabilitySeconds = number,    -- default i-frame window granted after a hit
		Resistances = {                     -- resist multipliers, looked up per faction
			[faction: string] = { [damageType: string]: number },
		},
		HitValidation = {                   -- server-side anti-cheat tolerances
			MaxRangeStuds    = number,
			MaxRatePerSecond = number,
		},
]]

local Combat = {
	Resistances = {},
	HitValidation = {},
}

return table.freeze(Combat)
