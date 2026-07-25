--!strict
--[[
	EnemyBrain.spec
	Validates the pure enemy AI state machine: aggro, chase, attack, return, and
	death transitions — all from perceived distances, no world instances.

	Location: TestService.Tests.EnemyBrain.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local EnemyBrain = require(ServerScriptService.Server.Domain.AI.EnemyBrain)
local S = EnemyBrain.States

local PARAMS = { DetectionRadius = 30, AttackRange = 6, LeashRadius = 50, ArrivalRadius = 3 }

-- Perception builder. `targetDistance = nil` means no target in sight.
local function p(targetDistance: number?, distanceFromSpawn: number, isAlive: boolean?): any
	return {
		isAlive = if isAlive == nil then true else isAlive,
		targetDistance = targetDistance,
		distanceFromSpawn = distanceFromSpawn,
		params = PARAMS,
	}
end

return function(t: any)
	t.test("starts Idle", function()
		assert(EnemyBrain.new().state == S.Idle, "a new brain is Idle")
	end)

	t.test("Idle -> Chase when a target enters detection radius", function()
		assert(EnemyBrain.new():update(p(20, 0)) == S.Chase, "aggro within DetectionRadius")
	end)

	t.test("Idle stays Idle when the target is out of detection", function()
		assert(EnemyBrain.new():update(p(40, 0)) == S.Idle, "no aggro beyond DetectionRadius")
	end)

	t.test("Chase -> Attack within attack range", function()
		local b = EnemyBrain.new()
		b:update(p(20, 0)) -- Chase
		assert(b:update(p(5, 15)) == S.Attack, "attack within AttackRange")
	end)

	t.test("Attack -> Chase when the target leaves attack range (still within leash)", function()
		local b = EnemyBrain.new()
		b:update(p(20, 0)) -- Chase
		b:update(p(5, 15)) -- Attack
		assert(b:update(p(10, 15)) == S.Chase, "re-chase out of AttackRange")
	end)

	t.test("Chase -> Return when the target is beyond leash", function()
		local b = EnemyBrain.new()
		b:update(p(20, 0)) -- Chase
		assert(b:update(p(60, 40)) == S.Return, "give up beyond LeashRadius")
	end)

	t.test("Chase -> Return when the target is lost", function()
		local b = EnemyBrain.new()
		b:update(p(20, 0)) -- Chase
		assert(b:update(p(nil, 40)) == S.Return, "give up when there is no target")
	end)

	t.test("Return -> Idle on arriving home", function()
		local b = EnemyBrain.new()
		b:update(p(20, 0)) -- Chase
		b:update(p(nil, 40)) -- Return
		assert(b:update(p(nil, 2)) == S.Idle, "home within ArrivalRadius")
	end)

	t.test("Return -> Chase re-aggro if the player comes back", function()
		local b = EnemyBrain.new()
		b:update(p(20, 0)) -- Chase
		b:update(p(nil, 40)) -- Return
		assert(b:update(p(15, 40)) == S.Chase, "re-aggro within DetectionRadius")
	end)

	t.test("any state -> Dead when not alive", function()
		local b = EnemyBrain.new()
		b:update(p(5, 10)) -- Chase
		assert(b:update(p(5, 10, false)) == S.Dead, "dead when health is gone")
	end)
end
