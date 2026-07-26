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

	-- Neutral NPC placeholder for Defend / Escort objective targets. No AI block, so
	-- it stays passive; Escort movement is driven by the objective tracker. Provisional.
	villager_npc = {
		DisplayName = "Villager (placeholder)",
		Faction = "Neutral",
		Archetype = "Npc",
		MaxHealth = 60,
		Stats = {},
		DamageType = "Physical",
		Resistances = {},
		Tier = "Standard",
		Abilities = {},
	},

	-- Elite placeholder (tougher standard undead) for wave composition. Provisional.
	undead_brute = {
		DisplayName = "Undead Brute (placeholder)",
		Faction = "Enemies",
		Archetype = "Undead",
		MaxHealth = 200,
		Stats = {},
		DamageType = "Physical",
		Resistances = {},
		Tier = "Elite",
		Abilities = {},
		AI = {
			DetectionRadius = 35,
			AttackRange = 7,
			LeashRadius = 60,
			ArrivalRadius = 3,
			MoveSpeed = 8,
			AttackCooldown = 2.0,
			AttackDamage = 20,
			AttackDamageType = "Physical",
		},
	},

	-- Boss placeholder for set-piece encounters. Provisional.
	fallen_champion = {
		DisplayName = "Fallen Champion (placeholder boss)",
		Faction = "Enemies",
		Archetype = "Boss",
		MaxHealth = 800,
		Stats = {},
		DamageType = "Physical",
		Resistances = {},
		Tier = "Boss",
		Abilities = {},
		AI = {
			DetectionRadius = 50,
			AttackRange = 8,
			LeashRadius = 100,
			ArrivalRadius = 3,
			MoveSpeed = 9,
			AttackCooldown = 2.5,
			AttackDamage = 35,
			AttackDamageType = "Physical",
		},
	},
}

return table.freeze(Enemies)
