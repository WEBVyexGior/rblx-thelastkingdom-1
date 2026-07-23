--!strict
--[[
	Config: Enemies
	Base stat definitions for enemy archetypes (standard, elite, boss), BEFORE any
	difficulty/party scaling is applied.

	Read via: Config.get("Enemies")
	Filled with real values in the Combat phase. Empty in Phase 1 by design.

	Schema (per entry):
		[enemyId: string] = {
			Health = number,
			Damage = number,
			Speed  = number,
			Tier   = "Standard" | "Elite" | "Boss",
		}
]]

local Enemies = {
	-- Add enemy definitions here.
}

return table.freeze(Enemies)
