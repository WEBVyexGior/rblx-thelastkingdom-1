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
	Currencies = {},
	Upgrades = {},
	Revive = {},
}

return table.freeze(Economy)
