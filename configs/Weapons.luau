--!strict
--[[
	Config: Weapons
	Definitions for weapons (medieval melee first, with room for ranged/utility).

	Read via: Config.get("Weapons")
	Structure below is the Combat-phase schema; NO real weapons or values yet.

	Schema (per entry):
		[weaponId: string] = {
			DisplayName  = string,
			Class        = "Melee" | "Ranged" | "Utility",
			DamageType   = string,   -- a Shared.Combat.Enums.DamageType value
			Damage       = number,   -- base amount fed into a DamageRequest
			Cooldown     = number,   -- seconds between uses
			Range        = number,   -- studs (melee reach / projectile range)
			StaminaCost  = number,
			Knockback    = number,
			ComboSteps   = number,   -- melee combo length (1 = single swing)
			Requirements = { [stat: string]: number },  -- e.g. level/strength gates
		}
]]

local Weapons = {
	-- Add weapon definitions here.
}

return table.freeze(Weapons)
