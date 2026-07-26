--!strict
--[[
	EncounterRun (domain class)
	The PURE conductor for a running encounter: which waves are spawned when, and when
	the encounter is done. No Roblox instances, no spawning — the World WaveService
	does that and reports unit deaths back here; this class owns the wave-progression
	rules (sequential vs parallel, wave clearing, encounter completion). Unit-testable.

	Location: ServerScriptService.Server.Domain.EncounterRun
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage.Shared.Wave.Enums)
local Types = require(ReplicatedStorage.Shared.Wave.Types)

local EncounterRun = {}
EncounterRun.__index = EncounterRun

type WaveState = { def: Types.WaveDef, alive: number, status: string }

export type EncounterRun = typeof(setmetatable(
	{} :: {
		id: string,
		def: Types.EncounterDef,
		mode: string,
		waves: { WaveState },
		status: string,
	},
	EncounterRun
))

function EncounterRun.new(def: Types.EncounterDef): EncounterRun
	local waves: { WaveState } = {}
	for _, wdef in def.waves do
		table.insert(waves, { def = wdef, alive = 0, status = Enums.WaveStatus.Pending })
	end
	return setmetatable({
		id = def.id,
		def = def,
		mode = def.mode or Enums.WaveMode.Sequential,
		waves = waves,
		status = Enums.EncounterStatus.Pending,
	}, EncounterRun)
end

-- Indices of the waves to spawn first, and sets the encounter Active. Sequential =>
-- just wave 1; Parallel => all waves.
function EncounterRun.initialWaves(self: EncounterRun): { number }
	self.status = Enums.EncounterStatus.Active
	if self.mode == Enums.WaveMode.Parallel then
		local all: { number } = {}
		for i = 1, #self.waves do
			table.insert(all, i)
		end
		return all
	end
	return if #self.waves > 0 then { 1 } else {}
end

-- Records that wave `index` has spawned `count` live units.
function EncounterRun.markSpawned(self: EncounterRun, index: number, count: number)
	local wave = self.waves[index]
	if wave then
		wave.alive = count
		wave.status = Enums.WaveStatus.Active
	end
end

local function nextPending(self: EncounterRun): number?
	for i, wave in self.waves do
		if wave.status == Enums.WaveStatus.Pending then
			return i
		end
	end
	return nil
end

local function allCleared(self: EncounterRun): boolean
	for _, wave in self.waves do
		if wave.status ~= Enums.WaveStatus.Cleared then
			return false
		end
	end
	return true
end

-- Records a unit death in wave `index`. Returns:
--   waveCleared      - true if this death cleared the wave,
--   nextWaveToSpawn  - the next Sequential wave index to spawn (nil otherwise),
--   encounterDone    - true if the whole encounter is now Completed.
function EncounterRun.unitDied(self: EncounterRun, index: number): (boolean, number?, boolean)
	local wave = self.waves[index]
	if not wave or wave.status ~= Enums.WaveStatus.Active then
		return false, nil, false
	end
	wave.alive = math.max(0, wave.alive - 1)
	if wave.alive > 0 then
		return false, nil, false
	end
	wave.status = Enums.WaveStatus.Cleared
	local nextIndex: number? = nil
	if self.mode == Enums.WaveMode.Sequential then
		nextIndex = nextPending(self)
	end
	local done = allCleared(self)
	if done then
		self.status = Enums.EncounterStatus.Completed
	end
	return true, nextIndex, done
end

function EncounterRun.fail(self: EncounterRun)
	if self.status == Enums.EncounterStatus.Completed or self.status == Enums.EncounterStatus.Failed then
		return
	end
	self.status = Enums.EncounterStatus.Failed
end

function EncounterRun.isComplete(self: EncounterRun): boolean
	return self.status == Enums.EncounterStatus.Completed
end

function EncounterRun.isFailed(self: EncounterRun): boolean
	return self.status == Enums.EncounterStatus.Failed
end

return EncounterRun
