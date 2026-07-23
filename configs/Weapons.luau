--!strict
--[[
	Config: Weapons
	Definitions for weapons (medieval melee first, with room for ranged/utility).

	Read via: Config.get("Weapons")
	Filled with real values in the Combat phase. Empty in Phase 1 by design.

	Schema (per entry):
		[weaponId: string] = {
			DisplayName = string,
			Class       = "Melee" | "Ranged" | "Utility",
			Damage      = number,
			Cooldown    = number,  -- seconds between uses
			Range       = number,
		}
]]

local Weapons = {
	-- Add weapon definitions here.
}

return table.freeze(Weapons)
