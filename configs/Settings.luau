--!strict
--[[
	Config: Settings
	Global, non-balancing game settings and feature toggles (timers, flags) that
	are convenient to tune in one place without touching code.

	Read via: Config.get("Settings")
	Filled as systems come online.
]]

local Settings = {
	-- Free models carry backdoors. In July 2026 a single sweep of this lobby found
	-- 502 foreign scripts hidden inside Mesh and Texture objects under toolbox
	-- decorations, under names like "CoreTextureSystem" chosen to look like engine
	-- internals — one of them calling require() on a remote asset id.
	--
	-- NONE of this game's own code lives in Workspace: everything is synced by
	-- Rojo into ServerScriptService, ReplicatedStorage and StarterPlayer. That
	-- makes the rule simple and safe to enforce automatically — a script in
	-- Workspace is, by definition, not ours.
	Security = {
		GuardWorkspaceScripts = true,
		-- "Remove" deletes them, "Warn" only reports. Warn first if you ever add a
		-- toolbox model whose script you actually want.
		GuardAction = "Remove",
	},

	FeatureFlags = {
		-- DEV/TEST: grant + equip a starter weapon when a player enters the World,
		-- so melee works via the equipment system without an inventory UI yet.
		GrantStarterWeapon = true,
		-- Auto-run the campaign (ChapterService) in the Forgotten Lands place.
		EnableCampaign = true,
		-- Use real DataStore persistence when available; falls back to the in-memory
		-- mock (e.g. Studio without API access) so gameplay always works.
		UseDataStore = true,
	},

	-- Campaign entry (dev flow). Later the chapter/mission comes from teleport data.
	Campaign = {
		StartChapter = "chapter_one",
	},

	-- Death system timings.
	Death = {
		SpectateSeconds = 60, -- window before a downed player is auto-resolved to Wait
	},

	-- DEV/TEST conveniences (remove/zero before real content).
	Dev = {
		StarterGold = 200, -- grant on join so self-revive is testable solo
	},

	-- TEST placeholders for combat — NOT balanced values.
	Combat = {
		StarterWeaponItemId = "starter_sword", -- item id the starter kit grants + equips
		PlayerMaxHealth = 100,
	},
}

return table.freeze(Settings)
