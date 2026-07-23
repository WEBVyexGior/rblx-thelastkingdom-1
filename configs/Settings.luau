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
	FeatureFlags = {},
}

return table.freeze(Settings)
