--!strict
--[[
	CombatEntity.spec
	Validates the combatant wrapper: liveness derived from Health, derived combat
	state, i-frame window, and stat defaults.

	Location: TestService.Tests.CombatEntity.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatEntity = require(ServerScriptService.Server.Domain.Combat.CombatEntity)
local Enums = require(ReplicatedStorage.Shared.Combat.Enums)

return function(t: any)
	t.test("a new entity is alive with a full Health", function()
		local e = CombatEntity.new({ id = "e1", faction = Enums.Faction.Players, maxHealth = 80 })
		assert(e:isAlive(), "should be alive")
		assert(e.health.max == 80, "health max should match config")
		assert(e:getState() == Enums.CombatState.Alive, "state should be Alive")
	end)

	t.test("dies when Health is depleted", function()
		local e = CombatEntity.new({ id = "e1", faction = Enums.Faction.Enemies, maxHealth = 10 })
		e.health:damage(10)
		assert(not e:isAlive(), "should be dead")
		assert(e:getState() == Enums.CombatState.Dead, "state should be Dead")
	end)

	t.test("i-frames report invulnerable within the window", function()
		local e = CombatEntity.new({ id = "e1", faction = Enums.Faction.Players, maxHealth = 10 })
		assert(not e:isInvulnerable(), "not invulnerable by default")
		e:grantInvulnerability(5)
		assert(e:isInvulnerable(), "invulnerable right after the grant")
		assert(e:getState() == Enums.CombatState.Invulnerable, "state reflects invulnerability")
	end)

	t.test("getStat returns 0 for unset stats", function()
		local e = CombatEntity.new({
			id = "e1",
			faction = Enums.Faction.Players,
			maxHealth = 10,
			stats = { attack = 3 },
		})
		assert(e:getStat("attack") == 3, "returns a set stat")
		assert(e:getStat("missing") == 0, "returns 0 for an unset stat")
	end)
end
