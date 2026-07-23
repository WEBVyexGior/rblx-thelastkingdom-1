--!strict
--[[
	CombatEntity (domain class)
	One combatant. Generic on purpose: a player, undead, animal, boss, NPC, or a
	trap are all CombatEntities — distinguished by `faction` (and, for enemies, a
	config-defined archetype), never by a hard-coded type. Wraps a `Health`, an
	optional world `model` (for hit → entity lookup), an extensible `stats` bag,
	and an invulnerability window (i-frames).

	Location: ServerScriptService.Server.Domain.Combat.CombatEntity
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Health = require(script.Parent.Health)
local Enums = require(ReplicatedStorage.Shared.Combat.Enums)

local CombatEntity = {}
CombatEntity.__index = CombatEntity

export type Config = {
	id: string,
	faction: string,
	maxHealth: number,
	model: Instance?,
	stats: { [string]: number }?,
}

export type CombatEntity = typeof(setmetatable(
	{} :: {
		id: string,
		faction: string,
		health: Health.Health,
		model: Instance?,
		stats: { [string]: number },
		invulnerableUntil: number,
	},
	CombatEntity
))

function CombatEntity.new(config: Config): CombatEntity
	return setmetatable({
		id = config.id,
		faction = config.faction,
		health = Health.new(config.maxHealth),
		model = config.model,
		stats = config.stats or {},
		invulnerableUntil = 0,
	}, CombatEntity)
end

function CombatEntity.isAlive(self: CombatEntity): boolean
	return not self.health:isDead()
end

function CombatEntity.isInvulnerable(self: CombatEntity): boolean
	return os.clock() < self.invulnerableUntil
end

-- Grants (or extends) an i-frame window of `seconds` from now.
function CombatEntity.grantInvulnerability(self: CombatEntity, seconds: number)
	local expiry = os.clock() + math.max(0, seconds)
	if expiry > self.invulnerableUntil then
		self.invulnerableUntil = expiry
	end
end

-- Derived state — never stored redundantly against Health.
function CombatEntity.getState(self: CombatEntity): string
	if self.health:isDead() then
		return Enums.CombatState.Dead
	elseif self:isInvulnerable() then
		return Enums.CombatState.Invulnerable
	end
	return Enums.CombatState.Alive
end

-- Reads a stat, defaulting to 0 when unset.
function CombatEntity.getStat(self: CombatEntity, name: string): number
	return self.stats[name] or 0
end

return CombatEntity
