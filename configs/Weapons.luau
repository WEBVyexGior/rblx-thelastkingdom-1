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

--[[
	The roster is deliberately melee-only for now.

	RANGED IS NOT IMPLEMENTED. "Ranged" exists in the schema above but no code
	reads it — there is no projectile service. A Hunting Bow and a Hand Cannon
	are both designed and both period-correct (Europe had hand cannons from the
	mid-1300s and matchlocks by ~1450), but listing them here would put weapons
	in the blacksmith that cannot be fired. They arrive with the ranged combat
	system, in the Forgotten Lands phase.

	The four below sit on one axis — SPEED against WEIGHT — so choosing between
	them is a real decision rather than a strictly-better ladder:
	  a sword swings fast and hits moderately;
	  an axe trades speed for bite;
	  a mace is slow and brutal, built to break armour;
	  a spear is quick enough and reaches much further than any of them.

	Numbers are PROVISIONAL and get tuned against real waves.
]]
local Weapons = {
	-- The weapon every player starts with. Forty years of use, and still sharp.
	starter_sword = {
		DisplayName = "Old Blade",
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

	woodsman_axe = {
		DisplayName = "Woodsman's Axe",
		Class = "Melee",
		DamageType = "Physical",
		Damage = 38,
		Cooldown = 0.95,
		Range = 8,
		Arc = 80,
		StaminaCost = 0,
		Knockback = 4,
		ComboSteps = 1,
		Requirements = { level = 3 },
	},

	-- Reach instead of weight: you hold the line rather than close with it.
	footman_spear = {
		DisplayName = "Footman's Spear",
		Class = "Melee",
		DamageType = "Physical",
		Damage = 30,
		Cooldown = 0.8,
		Range = 14,
		Arc = 45,
		StaminaCost = 0,
		Knockback = 6,
		ComboSteps = 1,
		Requirements = { level = 5 },
	},

	-- The flanged mace: a medieval club with metal ridges, made specifically to
	-- break through armour rather than cut it.
	flanged_mace = {
		DisplayName = "Flanged Mace",
		Class = "Melee",
		DamageType = "Physical",
		Damage = 52,
		Cooldown = 1.35,
		Range = 7,
		Arc = 70,
		StaminaCost = 0,
		Knockback = 12,
		ComboSteps = 1,
		Requirements = { level = 8 },
	},
}

return table.freeze(Weapons)
