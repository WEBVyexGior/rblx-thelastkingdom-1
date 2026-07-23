--!strict
--[[
	DamagePipeline.spec
	Validates the pure damage resolver: identity behaviour with no modifiers,
	modifier adjustment, blocking, and base-amount clamping.

	Location: TestService.Tests.DamagePipeline.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Domain = ServerScriptService.Server.Domain.Combat
local DamagePipeline = require(Domain.DamagePipeline)
local CombatEntity = require(Domain.CombatEntity)
local Enums = require(ReplicatedStorage.Shared.Combat.Enums)

local function makeTarget(): any
	return CombatEntity.new({ id = "t", faction = Enums.Faction.Enemies, maxHealth = 100 })
end

local function request(amount: number): any
	return { targetId = "t", amount = amount, damageType = Enums.DamageType.Physical }
end

return function(t: any)
	t.test("no modifiers returns the base amount", function()
		local amount, blocked = DamagePipeline.resolve(request(25), nil, makeTarget(), {})
		assert(amount == 25 and not blocked, "identity pipeline passes the amount through")
	end)

	t.test("a modifier can adjust the amount", function()
		local halve = function(ctx: any)
			ctx.amount = ctx.amount / 2
		end
		local amount = DamagePipeline.resolve(request(40), nil, makeTarget(), { halve })
		assert(amount == 20, "modifier halved the amount")
	end)

	t.test("a modifier can block the hit", function()
		local block = function(ctx: any)
			ctx.blocked = true
		end
		local amount, blocked = DamagePipeline.resolve(request(40), nil, makeTarget(), { block })
		assert(blocked and amount == 0, "a blocked hit yields zero")
	end)

	t.test("negative base amount clamps to zero", function()
		local amount = DamagePipeline.resolve(request(-10), nil, makeTarget(), {})
		assert(amount == 0, "negative base clamps to 0")
	end)
end
