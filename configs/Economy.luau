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
	-- Weapon upgrading at the blacksmith. ONE track per weapon, +1 through +10,
	-- paid in gold. A single number the player can read at a glance beats three
	-- competing stat lines they have to model in their head.
	--
	-- Level 1 is the weapon as forged, so it costs nothing. Each step after it
	-- multiplies the weapon's BASE damage, so a strong weapon gains more per
	-- level than a weak one — upgrading a great sword should feel different from
	-- upgrading a worn one.
	--
	-- The curve roughly doubles damage at +10 for about 7,500 gold total, so the
	-- last levels are a real goal rather than a formality. PROVISIONAL — tuned
	-- once we know what a run actually pays.
	Upgrades = {
		Weapon = {
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
		},
	},
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
