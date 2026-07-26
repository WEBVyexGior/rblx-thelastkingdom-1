--!strict
--[[
	EncounterRun.spec
	Validates the pure encounter conductor: sequential wave progression, wave clearing
	on the last unit death, encounter completion, parallel mode, and failure.

	Location: TestService.Tests.EncounterRun.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EncounterRun = require(ServerScriptService.Server.Domain.EncounterRun)
local Enums = require(ReplicatedStorage.Shared.Wave.Enums)

local function twoWaveDef()
	return {
		id = "e1",
		mode = "Sequential",
		spawnPoints = { a = Vector3.zero },
		waves = {
			{ id = "w1", groups = { { enemyId = "x", count = 2, spawnPoint = "a" } } },
			{ id = "w2", groups = { { enemyId = "x", count = 1, spawnPoint = "a" } } },
		},
	}
end

return function(t: any)
	t.test("new encounter is Pending with its waves", function()
		local e = EncounterRun.new(twoWaveDef())
		assert(e.status == Enums.EncounterStatus.Pending, "Pending")
		assert(#e.waves == 2, "two waves")
	end)

	t.test("sequential starts with wave 1 only and goes Active", function()
		local e = EncounterRun.new(twoWaveDef())
		local initial = e:initialWaves()
		assert(#initial == 1 and initial[1] == 1, "only wave 1")
		assert(e.status == Enums.EncounterStatus.Active, "Active")
	end)

	t.test("clearing wave 1 triggers wave 2, then completes", function()
		local e = EncounterRun.new(twoWaveDef())
		e:initialWaves()
		e:markSpawned(1, 2)
		local cleared, nxt, done = e:unitDied(1)
		assert(not cleared and not done, "1/2 dead: wave not cleared")
		cleared, nxt, done = e:unitDied(1)
		assert(cleared, "2/2 dead: wave 1 cleared")
		assert(nxt == 2, "next wave is 2")
		assert(not done, "encounter not done yet")
		e:markSpawned(2, 1)
		local c2, _, done2 = e:unitDied(2)
		assert(c2 and done2, "wave 2 cleared -> encounter done")
		assert(e:isComplete(), "encounter Completed")
	end)

	t.test("parallel spawns all waves at once", function()
		local d = twoWaveDef()
		d.mode = "Parallel"
		local e = EncounterRun.new(d)
		local initial = e:initialWaves()
		assert(#initial == 2, "both waves spawn at start")
	end)

	t.test("deaths in an unspawned wave are ignored", function()
		local e = EncounterRun.new(twoWaveDef())
		e:initialWaves()
		local cleared = e:unitDied(2) -- wave 2 not spawned yet
		assert(not cleared, "no effect on a non-active wave")
	end)

	t.test("fail marks the encounter Failed", function()
		local e = EncounterRun.new(twoWaveDef())
		e:initialWaves()
		e:fail()
		assert(e:isFailed(), "Failed")
	end)
end
