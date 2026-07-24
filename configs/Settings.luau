--!strict
--[[
	Config: Settings
	Global, non-balancing game settings and feature toggles (timers, flags) that
	are convenient to tune in one place without touching code.

	Read via: Config.get("Settings")
	Filled as systems come online. Mostly empty in Phase 1 by design.

	Schema (examples of what will live here):
		SpectateSeconds        = number,   -- death spectate window (design: 60)
		ReformCountdownSeconds = number,   -- "wait for teammates" re-form countdown
		FeatureFlags           = { [flag: string]: boolean },
]]

local Settings = {
	FeatureFlags = {
		-- DEV/TEST: auto-spawn a training dummy in the World place so the combat
		-- vertical slice is immediately playable. Turn off before real content.
		EnableCombatTestDummies = true,
		-- DEV/TEST: grant + equip a starter weapon when a player enters the World,
		-- so melee works via the equipment system without an inventory UI yet.
		GrantStarterWeapon = true,
	},

	-- TEST placeholders for the combat vertical slice — NOT balanced values.
	Combat = {
		StarterWeaponItemId = "starter_sword", -- item id the starter kit grants + equips
		PlayerMaxHealth = 100,
		TestDummy = {
			Count = 1,
			SpawnOffset = 12, -- studs in front of the origin
		},
	},
}

return table.freeze(Settings)
