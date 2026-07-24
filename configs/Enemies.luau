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
	},
}

return table.freeze(Enemies)
