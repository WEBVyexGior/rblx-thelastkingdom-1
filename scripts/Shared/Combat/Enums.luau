--!strict
--[[
	Combat.Enums
	The shared combat vocabulary: identifiers (not balancing data) used by both
	the server combat systems and, later, the client. Deliberately small and
	extensible — add members as content grows; never put tunable numbers here
	(those live in `configs/`).

	Location: ReplicatedStorage.Shared.Combat.Enums
]]

local Enums = {}

-- How a hit is categorised. Minimal base set; extend with new kinds (Holy,
-- Poison, Lightning, ...) when content needs them. `True` bypasses resistances.
Enums.DamageType = table.freeze({
	Physical = "Physical",
	Fire = "Fire",
	Frost = "Frost",
	Arcane = "Arcane",
	True = "True",
})

-- Combat allegiance, used for friendly-fire and targeting rules. Deliberately
-- broad and NOT enemy-type-specific: undead, animals, bosses, and NPC enemies
-- all share `Enemies` — their *kind* is a config archetype, not a faction.
-- `Environment` (traps/hazards) can damage anyone.
Enums.Faction = table.freeze({
	Players = "Players",
	Enemies = "Enemies",
	Neutral = "Neutral",
	Environment = "Environment",
})

-- Runtime combat state of an entity. Derived from health + i-frames, not stored
-- redundantly. Extend later (e.g. Staggered, Channeling) without breaking callers.
Enums.CombatState = table.freeze({
	Alive = "Alive",
	Invulnerable = "Invulnerable",
	Dead = "Dead",
})

return table.freeze(Enums)
