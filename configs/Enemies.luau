--!strict
--[[
	Config: Enemies
	Base stat definitions for every unit the world can spawn — undead, neutral
	NPCs and bosses — BEFORE any difficulty or party scaling is applied.

	Read via: Config.get("Enemies")

	Generic by design: `Archetype` distinguishes undead / animal / boss / npc /
	construct content — it is NOT a faction (all hostiles share the Enemies faction).

	--------------------------------------------------------------------------
	Schema (per entry):
		[enemyId: string] = {
			DisplayName = string,
			Faction     = string,   -- a Shared.Combat.Enums.Faction value
			Archetype   = string,   -- "Undead" | "Animal" | "Boss" | "Npc" | ...
			MaxHealth   = number,
			Stats       = { [stat: string]: number },
			DamageType  = string,
			Resistances = { [damageType: string]: number },
			Tier        = "Standard" | "Elite" | "Boss",
			Abilities   = { string },

			AI = {   -- OPTIONAL; present = this unit uses the AI brain
				DetectionRadius  = number,  -- acquire a target within this
				AttackRange      = number,  -- the FURTHEST it can attack from
				MeleeRange       = number?, -- OPTIONAL: inside this it uses the melee
				                            -- attack instead of the ranged one. Only
				                            -- meaningful with a Ranged block.
				MinRange         = number?, -- OPTIONAL: closer than this it BACKS OFF.
				                            -- This is what makes an archer an archer.
				LeashRadius      = number,
				ArrivalRadius    = number,
				MoveSpeed        = number,
				AttackCooldown   = number,
				AttackDamage     = number,
				AttackDamageType = string,
			},

			Ranged = {  -- OPTIONAL; present = it shoots instead of swinging
				Projectile   = string,  -- "arrow" | "javelin" — a ProjectileService kind
				Speed        = number,  -- studs/second of flight
				Damage       = number,
				DamageType   = string,
				Spread       = number,  -- CONE HALF-ANGLE in radians. Being an angle
				                        -- rather than a distance is what makes long
				                        -- shots naturally less reliable than close
				                        -- ones, with no extra rule for it.
				LeadFactor   = number,  -- 0..1 of target velocity compensated for
				MaxRange     = number,  -- studs before the shot dies in the air
			},
		}

	--------------------------------------------------------------------------
	WHY RANGED ENEMIES MISS

	`Spread` and `LeadFactor` exist so an archer is beatable by MOVING, not by a
	dice roll the player cannot see. A shot can fail three honest ways:

	  1. the aim error put it off line,
	  2. the player moved during the flight time,
	  3. it hit a wall or a house on the way.

	The third is the one that matters most: it makes the map's cover real, and
	every barricade and ruin in the nine chambers suddenly does something. That
	is only possible because the projectile actually travels and is traced —
	see Server/World/ProjectileService.
]]

local Enemies = {
	--======================================================================
	-- THE UNDEAD
	--
	-- Five standing types and a boss. They are introduced across the run
	-- rather than all at once — see configs/Difficulty `Areas`, which is the
	-- single place that says WHEN each one first appears.
	--
	-- The roster is deliberately built around one axis: HOW FAR AWAY can this
	-- thing hurt me. Shambler and runner have to touch you, the brute has to
	-- touch you but ends you when it does, the spearman reaches past your
	-- sword, and the archer does not have to approach at all. That is a
	-- clearer escalation than "more health each area", and the player can read
	-- it at a glance from the silhouette.
	--======================================================================

	--[[
		The baseline dead. Slow, weak, and always in numbers. Everything else in
		the roster is defined against this one: it is what "a zombie" means here,
		and the first area is nothing but these.
	]]
	undead_shambler = {
		DisplayName = "Shambler",
		Faction = "Enemies",
		Archetype = "Undead",
		MaxHealth = 60,
		Stats = {},
		DamageType = "Physical",
		Resistances = {},
		Tier = "Standard",
		Abilities = {},
		AI = {
			DetectionRadius = 45,
			AttackRange = 6,
			LeashRadius = 90,
			ArrivalRadius = 3,
			MoveSpeed = 7,
			AttackCooldown = 1.6,
			AttackDamage = 8,
			AttackDamageType = "Physical",
		},
	},

	--[[
		Fast and fragile. It exists to stop the player treating a crowd as a
		queue: a shambler wall can be backed away from, and a runner is what
		punishes you for doing that too long.
	]]
	undead_runner = {
		DisplayName = "Runner",
		Faction = "Enemies",
		Archetype = "Undead",
		MaxHealth = 40,
		Stats = {},
		DamageType = "Physical",
		Resistances = {},
		Tier = "Standard",
		Abilities = {},
		AI = {
			DetectionRadius = 60,
			AttackRange = 5.5,
			LeashRadius = 110,
			ArrivalRadius = 3,
			MoveSpeed = 15,
			AttackCooldown = 1.1,
			AttackDamage = 6,
			AttackDamageType = "Physical",
		},
	},

	--[[
		The heavy weapon. Slow enough to walk away from, and lethal enough that
		you must. First seen in the graveyard, which is where the run turns.

		Its cooldown is long on purpose: the fight against a brute is about
		spacing and the gap after its swing, not about trading hits.
	]]
	undead_brute_heavy = {
		DisplayName = "Gravedigger",
		Faction = "Enemies",
		Archetype = "Undead",
		MaxHealth = 260,
		Stats = {},
		DamageType = "Physical",
		Resistances = {},
		Tier = "Elite",
		Abilities = {},
		AI = {
			DetectionRadius = 40,
			AttackRange = 8,
			LeashRadius = 80,
			ArrivalRadius = 3,
			MoveSpeed = 6,
			AttackCooldown = 2.6,
			AttackDamage = 30,
			AttackDamageType = "Physical",
		},
	},

	--[[
		Reach. It hits from outside sword range, so it cannot simply be walked
		up to — you close the distance during its cooldown or you do not close
		it at all. First seen at the smithy.

		It does NOT throw the spear. A thrown spear and a bow are the same
		threat wearing two hats, and the range balance falls apart.
	]]
	undead_spearman = {
		DisplayName = "Spearman",
		Faction = "Enemies",
		Archetype = "Undead",
		MaxHealth = 90,
		Stats = {},
		DamageType = "Physical",
		Resistances = {},
		Tier = "Standard",
		Abilities = {},
		AI = {
			DetectionRadius = 55,
			AttackRange = 14,
			LeashRadius = 100,
			ArrivalRadius = 3,
			MoveSpeed = 7,
			AttackCooldown = 2.4,
			AttackDamage = 16,
			AttackDamageType = "Physical",
		},
	},

	--[[
		The archer. It never has to reach you at all, and `MinRange` is what
		makes that true in practice — get inside 22 studs and it BACKS AWAY
		rather than standing there being hit.

		That single number is the whole character: it turns every fight with one
		into a chase, and it is the reason cover in the chambers matters.
	]]
	undead_archer = {
		DisplayName = "Archer",
		Faction = "Enemies",
		Archetype = "Undead",
		MaxHealth = 55,
		Stats = {},
		DamageType = "Physical",
		Resistances = {},
		Tier = "Standard",
		Abilities = {},
		AI = {
			DetectionRadius = 85,
			AttackRange = 70, -- it opens fire from here
			MinRange = 22, -- and retreats if you get inside it
			LeashRadius = 130,
			ArrivalRadius = 3,
			MoveSpeed = 9,
			AttackCooldown = 2.8,
			AttackDamage = 12, -- unused: the arrow carries the damage
			AttackDamageType = "Physical",
		},
		Ranged = {
			Projectile = "arrow",
			Speed = 120,
			Damage = 12,
			DamageType = "Physical",
			Spread = 0.055, -- radians at MaxSpreadRange; ~3 degrees
			LeadFactor = 0.55, -- leads a moving target, but only partly
			MaxRange = 160,
		},
	},

	--======================================================================
	-- THE BOSS
	--======================================================================

	--[[
		THE KING.

		Armour, a shield on his back, a sword, and a bow. He is the only unit
		with BOTH a melee and a ranged attack, and the switch between them is
		the fight: `MeleeRange` says that inside 9 studs he draws the sword, and
		beyond it he uses the bow.

		He has no `MinRange`. He does not retreat — everything else in this
		castle has been running for forty years and he is what they were running
		from.
	]]
	the_king = {
		DisplayName = "The King",
		Faction = "Enemies",
		Archetype = "Boss",
		MaxHealth = 2400,
		Stats = {},
		DamageType = "Physical",
		Resistances = {},
		Tier = "Boss",
		Abilities = {},
		AI = {
			DetectionRadius = 120,
			AttackRange = 80, -- the bow reaches this far
			MeleeRange = 9, -- inside this the sword comes out
			LeashRadius = 220,
			ArrivalRadius = 4,
			MoveSpeed = 11,
			AttackCooldown = 1.9,
			AttackDamage = 45, -- the sword
			AttackDamageType = "Physical",
		},
		Ranged = {
			Projectile = "arrow",
			Speed = 145,
			Damage = 26,
			DamageType = "Physical",
			Spread = 0.035, -- steadier than the common archers
			LeadFactor = 0.8, -- and he leads you properly
			MaxRange = 200,
		},
	},

	--======================================================================
	-- THE CURED — area 3
	--======================================================================

	--[[
		The five in the kitchens, once the recipe has been cooked and fed to
		them. Three fight in melee, two carry bows, and they follow the party
		for the rest of the run.

		They are Players faction, not Neutral: they have to be able to take a
		hit meant for the player, and enemy targeting has to see them as worth
		attacking. A Neutral ally the dead ignore is not an ally.
	]]
	cured_villager = {
		DisplayName = "Villager",
		Faction = "Players",
		Archetype = "Npc",
		MaxHealth = 120,
		Stats = {},
		DamageType = "Physical",
		Resistances = {},
		Tier = "Standard",
		Abilities = {},
		AI = {
			DetectionRadius = 50,
			AttackRange = 6,
			LeashRadius = 200, -- long: they follow the party, they do not go home
			ArrivalRadius = 4,
			MoveSpeed = 12,
			AttackCooldown = 1.5,
			AttackDamage = 10,
			AttackDamageType = "Physical",
		},
	},

	cured_villager_bow = {
		DisplayName = "Villager (bow)",
		Faction = "Players",
		Archetype = "Npc",
		MaxHealth = 90,
		Stats = {},
		DamageType = "Physical",
		Resistances = {},
		Tier = "Standard",
		Abilities = {},
		AI = {
			DetectionRadius = 80,
			AttackRange = 65,
			MinRange = 18,
			LeashRadius = 200,
			ArrivalRadius = 4,
			MoveSpeed = 12,
			AttackCooldown = 2.6,
			AttackDamage = 10,
			AttackDamageType = "Physical",
		},
		Ranged = {
			Projectile = "arrow",
			Speed = 120,
			Damage = 11,
			DamageType = "Physical",
			Spread = 0.05,
			LeadFactor = 0.6,
			MaxRange = 150,
		},
	},

	--======================================================================
	-- PLACEHOLDERS — still referenced by the vertical slice
	--
	-- Kept because configs/Encounters, configs/Missions and ObjectiveTrackers
	-- point at these ids. They are NOT balanced content; the roster above is.
	--======================================================================

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
		AI = {
			DetectionRadius = 30,
			AttackRange = 6,
			LeashRadius = 50,
			ArrivalRadius = 3,
			MoveSpeed = 10,
			AttackCooldown = 1.5,
			AttackDamage = 10,
			AttackDamageType = "Physical",
		},
	},

	-- Neutral NPC placeholder for Defend / Escort objective targets. No AI block,
	-- so it stays passive; Escort movement is driven by the objective tracker.
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
