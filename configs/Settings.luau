--!strict
--[[
	Config: Settings
	Global, non-balancing game settings and feature toggles (timers, flags) that
	are convenient to tune in one place without touching code.

	Read via: Config.get("Settings")
	Filled as systems come online.
]]

local Settings = {
	FeatureFlags = {
		-- DEV/TEST: grant + equip a starter weapon when a player enters the World,
		-- so melee works via the equipment system without an inventory UI yet.
		GrantStarterWeapon = true,
		-- Auto-run the campaign (ChapterService) in the Forgotten Lands place.
		EnableCampaign = true,
	},

	-- Campaign entry (dev flow). Later the chapter/mission comes from teleport data.
	Campaign = {
		StartChapter = "chapter_one",
	},

	-- TEST placeholders for combat — NOT balanced values.
	Combat = {
		StarterWeaponItemId = "starter_sword", -- item id the starter kit grants + equips
		PlayerMaxHealth = 100,
	},
}

return table.freeze(Settings)
