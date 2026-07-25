--!strict
--[[
	Config: Enemies
	Base stat definitions for enemy archetypes (standard, elite, boss), BEFORE any
	difficulty/party scaling is applied.

	Read via: Config.get("Enemies")
	The only entry is a TEST placeholder for the vertical slice (`training_dummy`) —
	not a real or balanced enemy.

	Generic by design: `Archetype` distinguishes undead / animal / boss / npc /
	construct content — it is NOT a faction (all hostiles share the Enemies faction).

	Schema (per entry):
		[enemyId: string] = {
			DisplayName = string,
			Faction     = string,   -- a Shared.Combat.Enums.Faction value (usually Enemies)
			Archetype   = string,   -- "Undead" | "Animal" | "Boss" | "Npc" | ... (content-defined)
			MaxHealth   = number,
			Stats       = { [stat: string]: number },     -- attack/defense/speed/...
			DamageType  = string,   -- default outgoing Shared.Combat.Enums.DamageType
			Resistances = { [damageType: string]: number },  -- resist multipliers
			Tier        = "Standard" | "Elite" | "Boss",
			Abilities   = { string },   -- ability ids (defined in a later phase)
			AI          = {             -- OPTIONAL; present = the enemy uses the AI brain (Phase 5)
				DetectionRadius = number, AttackRange = number, LeashRadius = number,
				ArrivalRadius = number, MoveSpeed = number, AttackCooldown = number,
				AttackDamage = number, AttackDamageType = string,
			},
		}
]]

local Enemies = {
	-- TEST placeholder target for the combat vertical slice — NOT balanced values.
	training_dummy = {
		DisplayName = "Training Dummy",
		Faction = "Enemies",
		Archetype = "Construct",
		MaxHealth = 100,
		Stats = {},
		DamageType = "Physical",
		Resistances = {},
		Tier = "Standard",
		Abilities = {},
		-- AI foundation params (Phase 5) — placeholder tuning, not final balance.
		AI = {
			DetectionRadius = 30, -- studs: acquire the player within this
			AttackRange = 6, -- studs: attack within this
			LeashRadius = 50, -- studs: give up + return when the target is beyond this
			ArrivalRadius = 3, -- studs: "home" when this close to spawn
			MoveSpeed = 10, -- studs/second (kinematic)
			AttackCooldown = 1.5, -- seconds between attacks
			AttackDamage = 10,
			AttackDamageType = "Physical",
		},
	},
}

return table.freeze(Enemies)
