--!strict
--[[
	Combat.Types
	The shared type contract for combat. A type-only module (returns an empty
	table); consumers use `CombatTypes.<Name>`. Keeping these here means the
	server combat systems and any future client feature agree on one shape.

	Values for these string aliases come from `Combat.Enums`.

	Location: ReplicatedStorage.Shared.Combat.Types
]]

export type EntityId = string
export type Faction = string
export type DamageType = string
export type CombatState = string

-- Arbitrary, extensible per-entity stat bag (attack, defense, ...). No fixed
-- keys by design — systems read what they need, absent stats read as 0.
export type Stats = { [string]: number }

export type HealthSnapshot = {
	current: number,
	max: number,
}

-- Optional per-hit modifiers on a damage request.
export type DamageFlags = {
	critical: boolean?,
	unblockable: boolean?,
	ignoreFaction: boolean?, -- allow same-faction damage for this hit
	ignoreInvulnerability: boolean?, -- pierce i-frames for this hit
}

-- What a system asks CombatService to apply. Intent + data; the server decides.
export type DamageRequest = {
	sourceId: EntityId?, -- attacker (nil for environment/traps)
	targetId: EntityId,
	amount: number, -- base amount before the pipeline
	damageType: DamageType,
	flags: DamageFlags?,
}

-- The authoritative outcome of a resolved hit.
export type DamageResult = {
	targetId: EntityId,
	sourceId: EntityId?,
	amount: number, -- actually applied
	requested: number, -- base amount before the pipeline
	damageType: DamageType,
	blocked: boolean, -- fully prevented (faction / i-frames / dead / modifier)
	killed: boolean, -- this hit reduced the target to 0
}

-- What CombatService.registerEntity expects.
export type EntityConfig = {
	id: EntityId,
	faction: Faction,
	maxHealth: number,
	model: Instance?,
	stats: Stats?,
}

return {}
