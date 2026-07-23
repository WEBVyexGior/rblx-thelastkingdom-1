--!strict
--[[
	DamagePipeline (domain)
	Resolves how much damage a request deals by running it through an ORDERED
	chain of modifiers. This is the extensibility seam: armor, resistances, crits,
	weapon scaling, buffs, and abilities are added later as modifiers WITHOUT
	touching this core. Pure — it never mutates the entities' health (CombatService
	applies the result).

	The foundation ships ZERO modifiers, so `resolve` returns the base amount.

	Location: ServerScriptService.Server.Domain.Combat.DamagePipeline
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Combat.Types)
local CombatEntity = require(script.Parent.CombatEntity)

local DamagePipeline = {}

-- Mutable working context handed to each modifier. A modifier adjusts `amount`
-- or sets `blocked = true` to fully prevent the hit. Kept intentionally small.
export type Context = {
	request: Types.DamageRequest,
	source: CombatEntity.CombatEntity?,
	target: CombatEntity.CombatEntity,
	amount: number,
	blocked: boolean,
}

export type Modifier = (Context) -> ()

-- Runs the modifier chain over the base amount. Returns (finalAmount, blocked).
-- Stops early once a modifier blocks the hit.
function DamagePipeline.resolve(
	request: Types.DamageRequest,
	source: CombatEntity.CombatEntity?,
	target: CombatEntity.CombatEntity,
	modifiers: { Modifier }
): (number, boolean)
	local context: Context = {
		request = request,
		source = source,
		target = target,
		amount = math.max(0, request.amount),
		blocked = false,
	}

	for _, modifier in modifiers do
		if context.blocked then
			break
		end
		modifier(context)
	end

	if context.blocked then
		return 0, true
	end
	return math.max(0, context.amount), false
end

return DamagePipeline
