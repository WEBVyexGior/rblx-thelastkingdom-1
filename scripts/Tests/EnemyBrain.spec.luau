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

--[[
	An archer's params: it opens fire at 70 and backs off inside 20. The
	hysteresis band is MinRange * 1.25, so it stops retreating at 25.
]]
local ARCHER = { DetectionRadius = 85, AttackRange = 70, MinRange = 20, LeashRadius = 130, ArrivalRadius = 3 }

-- Perception builder. `targetDistance = nil` means no target in sight.
local function p(targetDistance: number?, distanceFromSpawn: number, isAlive: boolean?): any
	return {
		isAlive = if isAlive == nil then true else isAlive,
		targetDistance = targetDistance,
		distanceFromSpawn = distanceFromSpawn,
		params = PARAMS,
	}
end

-- The same, with the archer's params.
local function a(targetDistance: number?, distanceFromSpawn: number, isAlive: boolean?): any
	return {
		isAlive = if isAlive == nil then true else isAlive,
		targetDistance = targetDistance,
		distanceFromSpawn = distanceFromSpawn,
		params = ARCHER,
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

	--======================================================================
	-- RANGED: MinRange and the retreat
	--
	-- A melee unit has no MinRange and must behave exactly as before — that
	-- is the first test, and it is the one that catches a regression in the
	-- other five types when only the archer was being worked on.
	--======================================================================

	t.test("melee units never Reposition — no MinRange means the branch is dead", function()
		local b = EnemyBrain.new()
		b:update(p(20, 0)) -- Chase
		assert(b:update(p(0.5, 15)) == S.Attack, "point blank is still just Attack")
	end)

	t.test("Attack -> Reposition when the target gets inside MinRange", function()
		local b = EnemyBrain.new()
		b:update(a(60, 0)) -- Chase
		b:update(a(60, 10)) -- Attack (inside AttackRange 70)
		assert(b:update(a(15, 10)) == S.Reposition, "backs off inside MinRange 20")
	end)

	t.test("Chase -> Reposition if the target closes before it ever fires", function()
		local b = EnemyBrain.new()
		b:update(a(80, 0)) -- Chase (detected at 85, outside AttackRange 70)
		assert(b:update(a(9, 10)) == S.Reposition, "closed the gap during the approach")
	end)

	t.test("Reposition HOLDS inside the hysteresis band", function()
		local b = EnemyBrain.new()
		b:update(a(60, 0))
		b:update(a(60, 10))
		b:update(a(15, 10)) -- Reposition
		-- Past MinRange 20 but not yet past the 25 band: it must keep backing off.
		assert(b:update(a(22, 10)) == S.Reposition, "22 is past MinRange but inside the band")
	end)

	t.test("Reposition -> Attack once past the hysteresis band", function()
		local b = EnemyBrain.new()
		b:update(a(60, 0))
		b:update(a(60, 10))
		b:update(a(15, 10)) -- Reposition
		assert(b:update(a(26, 10)) == S.Attack, "26 clears the 25 band, so it fires again")
	end)

	t.test("Reposition -> Chase if it backed off past its own attack range", function()
		local b = EnemyBrain.new()
		b:update(a(60, 0))
		b:update(a(60, 10))
		b:update(a(15, 10)) -- Reposition
		-- Cleared the band, but the target is now beyond AttackRange 70.
		assert(b:update(a(75, 10)) == S.Chase, "too far to shoot, so close back in")
	end)

	t.test("Reposition -> Return when the target is dragged past the leash", function()
		local b = EnemyBrain.new()
		b:update(a(60, 0))
		b:update(a(60, 10))
		b:update(a(15, 10)) -- Reposition
		assert(b:update(a(140, 60)) == S.Return, "beyond LeashRadius 130")
	end)

	t.test("Reposition -> Return when the target vanishes", function()
		local b = EnemyBrain.new()
		b:update(a(60, 0))
		b:update(a(60, 10))
		b:update(a(15, 10)) -- Reposition
		assert(b:update(a(nil, 60)) == S.Return, "no target left to back away from")
	end)

	t.test("Return -> Reposition if the re-aggro is already on top of it", function()
		local b = EnemyBrain.new()
		b:update(a(60, 0))
		b:update(a(nil, 100)) -- Return
		assert(b:update(a(6, 100)) == S.Reposition, "re-aggroed at point blank")
	end)

	t.test("a retreating enemy still counts as attacking", function()
		assert(EnemyBrain.isAttacking(S.Attack), "Attack is attacking")
		assert(EnemyBrain.isAttacking(S.Reposition), "so is Reposition — it shoots while backing off")
		assert(not EnemyBrain.isAttacking(S.Chase), "Chase is not")
		assert(not EnemyBrain.isAttacking(S.Idle), "nor Idle")
	end)
end
