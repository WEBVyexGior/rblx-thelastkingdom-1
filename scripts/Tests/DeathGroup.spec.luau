--!strict
--[[
	DeathGroup.spec
	Validates the pure group rules: alive counting, total-wipe detection (needs at
	least one participant), reviver availability, and status filtering.

	Location: TestService.Tests.DeathGroup.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DeathGroup = require(ServerScriptService.Server.Domain.DeathGroup)
local Enums = require(ReplicatedStorage.Shared.Death.Enums)

local S = Enums.DeathStatus

return function(t: any)
	t.test("aliveCount counts only Alive", function()
		local statuses = { a = S.Alive, b = S.Down, c = S.Alive, d = S.Waiting }
		assert(DeathGroup.aliveCount(statuses) == 2, "two alive")
	end)

	t.test("isWipe is true only when everyone has resolved to Waiting/Left", function()
		assert(not DeathGroup.isWipe({}), "empty is not a wipe")
		assert(not DeathGroup.isWipe({ a = S.Alive, b = S.Waiting }), "one alive: not a wipe")
		assert(not DeathGroup.isWipe({ a = S.Down, b = S.Left }), "someone still deciding: not a wipe")
		assert(DeathGroup.isWipe({ a = S.Waiting, b = S.Left }), "all resolved down: wipe")
	end)

	t.test("canReviveTeammates needs a living player", function()
		assert(DeathGroup.canReviveTeammates({ a = S.Alive, b = S.Down }), "an alive teammate can revive")
		assert(not DeathGroup.canReviveTeammates({ a = S.Down, b = S.Waiting }), "no reviver when all down")
	end)

	t.test("withStatus returns the matching keys", function()
		local statuses = { a = S.Waiting, b = S.Alive, c = S.Waiting }
		local waiting = DeathGroup.withStatus(statuses, S.Waiting)
		table.sort(waiting)
		assert(#waiting == 2 and waiting[1] == "a" and waiting[2] == "c", "a and c are waiting")
	end)
end
