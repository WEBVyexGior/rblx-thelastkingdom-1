--!strict
--[[
	Config: Economy
	Currency, upgrade costs, and the anti-pay-to-win revive parameters.

	Read via: Config.get("Economy")
	Filled with real values in later phases. Empty in Phase 1 by design.

	NOTE: some of this data is sensitive (revive rules, upgrade costs). It may be
	moved to a server-only config location later; see configs/README.md.

	Schema:
		Currencies = { [currencyId: string] = { DisplayName = string } },
		Upgrades   = { [upgradeId: string] = { Levels = { { Cost = number, Bonus = number } } } },
		Revive     = {
			MaxPaidPerRun            = number,
			CooldownSeconds          = number,
			ReviveHealthPercent      = number,   -- anti-P2W: revive at reduced HP
			RewardPenaltyPercent     = number,   -- anti-P2W: paying costs rewards
			FreeTeammateReviveAlways = boolean,  -- a free co-op revive path always exists
		},
]]

local Economy = {
	Currencies = {
		gold = { DisplayName = "Gold" }, -- the primary run currency
	},
	Upgrades = {},
	-- Anti-P2W revive rules (GDD §15 / systems/Economy.md). Gold-based for now; a Robux
	-- path is a documented follow-up. A FREE teammate revive path always exists.
	Revive = {
		GoldCost = 100, -- self-revive costs earnings (anti-P2W)
		ReviveHealthPercent = 0.5, -- revive at reduced HP (anti-P2W)
		RewardPenaltyPercent = 0, -- reserved: trim end rewards after a paid revive
		CooldownSeconds = 15, -- minimum time between self-revives
		FreeTeammateReviveSeconds = 3, -- proximity-hold time for a free teammate revive
		TeammateReviveRadius = 10, -- studs a living teammate must be within
	},
}

return table.freeze(Economy)
