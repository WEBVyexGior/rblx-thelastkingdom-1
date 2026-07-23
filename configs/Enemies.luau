--!strict
--[[
	Config: Enemies
	Base stat definitions for enemy archetypes (standard, elite, boss), BEFORE any
	difficulty/party scaling is applied.

	Read via: Config.get("Enemies")
	Structure below is the Combat-phase schema; NO real enemies or values yet.

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
	-- Add enemy definitions here.
}

return table.freeze(Enemies)
