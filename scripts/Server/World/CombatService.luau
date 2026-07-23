--!strict
--[[
	CombatService
	The authoritative combat facade for the Forgotten Lands. It is the ONLY entry
	point for dealing damage: systems build a DamageRequest and call `applyDamage`;
	the server validates (target alive, i-frames, faction), resolves through the
	DamagePipeline, applies the result to the target's Health, and emits it.

	Generic by design — it knows nothing about zombies, weapons, or abilities. Any
	source (melee swing, projectile, ability, trap, environment) is just a caller.

	Extensibility: register damage modifiers with `registerModifier`. Client-facing
	replication (health bars, hit feedback) subscribes to the signals below; the
	RemoteEvent bridge is added when that client feature lands (no speculative
	remotes now, per Shared.Net's contract).

	Place: Forgotten Lands ONLY (lives in Server/World; the Hub has no combat).
	Phase: Combat (foundation). No weapons, enemies, or balancing values yet.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local CombatEntity = require(Server.Domain.Combat.CombatEntity)
local DamagePipeline = require(Server.Domain.Combat.DamagePipeline)
local Types = require(ReplicatedStorage.Shared.Combat.Types)
local Signal = require(ReplicatedStorage.Shared.Core.Signal)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local CombatService = {}

CombatService.Name = "CombatService"

-- Server-side seams other systems subscribe to.
CombatService.DamageDealt = Signal.new() -- fires (result: DamageResult)
CombatService.EntityDied = Signal.new() -- fires (entity: CombatEntity)

local log = Logger.new("CombatService")

-- Runtime registry, owned here (as PartyService owns parties).
local entities: { [string]: CombatEntity.CombatEntity } = {}
local instanceIndex: { [Instance]: string } = {} -- model -> entity id (target lookup)
local modifiers: { DamagePipeline.Modifier } = {}
local rules: any = nil -- cached configs/Combat data (empty schema this phase)

-- Registers a combatant. Errors on duplicate id.
function CombatService.registerEntity(config: CombatEntity.Config): CombatEntity.CombatEntity
	local existing: CombatEntity.CombatEntity? = entities[config.id]
	assert(existing == nil, "Duplicate combat entity id: " .. config.id)
	local entity = CombatEntity.new(config)
	entities[config.id] = entity
	if config.model then
		instanceIndex[config.model] = config.id
	end
	entity.health.Died:connect(function()
		CombatService.EntityDied:fire(entity)
	end)
	return entity
end

function CombatService.unregisterEntity(id: string)
	local entity = entities[id]
	if not entity then
		return
	end
	if entity.model then
		instanceIndex[entity.model] = nil
	end
	entities[id] = nil
end

function CombatService.getEntity(id: string): CombatEntity.CombatEntity?
	return entities[id]
end

-- Target handling: resolves any hit Instance (a part, accessory, ...) up its
-- ancestry to the CombatEntity whose registered model contains it.
function CombatService.getEntityByInstance(instance: Instance): CombatEntity.CombatEntity?
	local current: Instance? = instance
	while current do
		local id = instanceIndex[current]
		if id then
			return entities[id]
		end
		current = current.Parent
	end
	return nil
end

-- Appends a damage modifier to the pipeline (armor, resistances, crits, ...).
function CombatService.registerModifier(modifier: DamagePipeline.Modifier)
	table.insert(modifiers, modifier)
end

-- THE authoritative damage entry point. Returns a DamageResult describing the
-- outcome (always non-nil; a prevented hit is `blocked = true`, amount 0).
function CombatService.applyDamage(request: Types.DamageRequest): Types.DamageResult
	local target = entities[request.targetId]
	local source = if request.sourceId then entities[request.sourceId] else nil
	local flags = request.flags

	local function blockedResult(): Types.DamageResult
		return {
			targetId = request.targetId,
			sourceId = request.sourceId,
			amount = 0,
			requested = request.amount,
			damageType = request.damageType,
			blocked = true,
			killed = false,
		}
	end

	-- Validate target.
	if not target or not target:isAlive() then
		return blockedResult()
	end

	-- i-frames.
	if target:isInvulnerable() and not (flags and flags.ignoreInvulnerability) then
		return blockedResult()
	end

	-- Faction rule: no friendly fire between same-faction entities unless the
	-- global config allows it or the request explicitly ignores faction.
	if source and source.faction == target.faction then
		local allowFriendly = (rules and rules.FriendlyFire) or (flags and flags.ignoreFaction)
		if not allowFriendly then
			return blockedResult()
		end
	end

	local finalAmount, blocked = DamagePipeline.resolve(request, source, target, modifiers)
	if blocked then
		return blockedResult()
	end

	local removed, killed = target.health:damage(finalAmount)

	local result: Types.DamageResult = {
		targetId = request.targetId,
		sourceId = request.sourceId,
		amount = removed,
		requested = request.amount,
		damageType = request.damageType,
		blocked = false,
		killed = killed,
	}
	CombatService.DamageDealt:fire(result)
	return result
end

function CombatService.Init()
	-- Config is data-only and safe to read at Init. Empty schema this phase.
	rules = Config.get("Combat")
end

function CombatService.Start()
	log:info(("ready (%d modifier(s))"):format(#modifiers))
end

return CombatService
