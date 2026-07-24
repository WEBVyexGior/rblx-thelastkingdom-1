--!strict
--[[
	Config: Weapons
	Definitions for weapons (medieval melee first, with room for ranged/utility).

	Read via: Config.get("Weapons")
	The only entry is a TEST placeholder for the vertical slice (`starter_sword`) —
	not a balanced or final weapon.

	Schema (per entry):
		[weaponId: string] = {
			DisplayName  = string,
			Class        = "Melee" | "Ranged" | "Utility",
			DamageType   = string,   -- a Shared.Combat.Enums.DamageType value
			Damage       = number,   -- base amount fed into a DamageRequest
			Cooldown     = number,   -- seconds between uses
			Range        = number,   -- studs (melee reach / projectile range)
			Arc          = number,   -- melee swing arc in degrees (server hit detection)
			StaminaCost  = number,
			Knockback    = number,
			ComboSteps   = number,   -- melee combo length (1 = single swing)
			Requirements = { [stat: string]: number },  -- e.g. level/strength gates
		}
]]

local Weapons = {
	-- TEST placeholder for the combat vertical slice — NOT balanced values.
	starter_sword = {
		DisplayName = "Worn Sword",
		Class = "Melee",
		DamageType = "Physical",
		Damage = 25,
		Cooldown = 0.6,
		Range = 8,
		Arc = 90,
		StaminaCost = 0,
		Knockback = 0,
		ComboSteps = 1,
		Requirements = {},
	},
}

return table.freeze(Weapons)
