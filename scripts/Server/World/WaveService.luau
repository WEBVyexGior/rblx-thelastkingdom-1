--!strict
--[[
	WaveService
	The engine that RUNS an encounter (the "HOW"). Given an encounter id + a context,
	it spawns waves through the generic EnemyService, tracks unit deaths via
	CombatService.EntityDied, advances waves (sequential with rest, or parallel) via the
	pure EncounterRun, applies player-count difficulty scaling (count + health + elite
	substitution), and cleans up. It reports progress/completion/failure through the
	context callbacks — it knows nothing about missions.

	The Mission System decides WHEN to call startEncounter; WaveService owns HOW it runs.
	Level design adds encounters in `configs/Encounters.luau` — no code per encounter.

	Place: Forgotten Lands ONLY (Server/World). Phase: Waves.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local EncounterRun = require(Server.Domain.EncounterRun)
local EnemyService = require(script.Parent.EnemyService)
local CombatService = require(script.Parent.CombatService)
local Scaling = require(ReplicatedStorage.Shared.Scaling)
local Markers = require(ReplicatedStorage.Shared.World.Markers)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local WaveService = {}

WaveService.Name = "WaveService"

local log = Logger.new("WaveService")

export type Context = {
	playerCount: number?, -- party size for scaling (default: live player count)
	areaIndex: number?, -- which chamber this is, for the DEPTH curve (optional)
	eliteEnemyId: string?, -- substitute for scaled-in extra units (optional)
	onWaveStart: ((waveIndex: number, totalWaves: number) -> ())?,
	onProgress: ((killed: number, total: number) -> ())?,
	onComplete: (() -> ())?,
	onFail: (() -> ())?,
}

-- Starts encounter `encounterId`. Returns a `stop` function (cleans up + fails the
-- encounter if it was still running). Asserts on an unknown encounter id.
function WaveService.startEncounter(encounterId: string, ctx: Context): () -> ()
	local encounters = Config.get("Encounters")
	local def = encounters[encounterId]
	assert(def, "Unknown encounter: " .. tostring(encounterId))

	local playerCount = ctx.playerCount or #Players:GetPlayers()

	--[[
		Both curves, multiplied. Party size decides how much the room can chew
		through; depth decides what the castle is willing to send. An encounter
		with no `areaIndex` gets the party curve alone, exactly as before.
	]]
	local scale = Scaling.forPlayers(playerCount)
	if ctx.areaIndex then
		scale = Scaling.combine(scale, Scaling.forArea(ctx.areaIndex))
	end
	local doScale = def.scaled ~= false
	local restSeconds = def.restBetweenWaves or Config.get("Waves").Defaults.RestBetweenWavesSeconds or 2

	local run = EncounterRun.new(def)
	local unitWave: { [string]: number } = {} -- entity id -> wave index
	local killed = 0
	local total = 0
	local stopped = false
	local diedDisconnect: (() -> ())? = nil

	local function scaledCount(base: number): number
		if doScale then
			return math.max(1, math.round(base * scale.enemyCountMult))
		end
		return base
	end

	-- Precompute the total (scaled) enemy count for progress reporting.
	for _, wave in def.waves do
		for _, group in wave.groups do
			total += scaledCount(group.count)
		end
	end

	local function cleanup()
		if diedDisconnect then
			diedDisconnect()
			diedDisconnect = nil
		end
		for id in unitWave do
			if CombatService.getEntity(id) then
				EnemyService.despawn(id)
			end
		end
		unitWave = {}
	end

	local function finish(success: boolean)
		if stopped then
			return
		end
		stopped = true
		cleanup()
		if success then
			if ctx.onComplete then
				ctx.onComplete()
			end
		elseif ctx.onFail then
			ctx.onFail()
		end
	end

	local function spawnWave(waveIndex: number)
		if stopped then
			return
		end
		local wave = def.waves[waveIndex]
		if not wave then
			return
		end
		if ctx.onWaveStart then
			ctx.onWaveStart(waveIndex, #def.waves)
		end
		local spawnedCount = 0
		for _, group in wave.groups do
			-- A spawn point is coordinates, or the name of a marker in the map
			-- (see Shared.World.Markers) so a designer can drag it.
			local pos = Markers.resolve(def.spawnPoints[group.spawnPoint])
			if not pos then
				log:warn(("encounter '%s': spawn point '%s' could not be resolved (%s)"):format(
					tostring(def.id),
					tostring(group.spawnPoint),
					tostring(def.spawnPoints[group.spawnPoint])
				))
			end
			if pos then
				local count = scaledCount(group.count)
				local spread = group.spread or 0
				for i = 1, count do
					local offset = (i - 1) * spread - ((count - 1) * spread) / 2
					-- Scaled-in extras (beyond the base count) may become elites.
					local enemyId = group.enemyId
					if
						i > group.count
						and ctx.eliteEnemyId
						and scale.eliteWeight > 0
						and math.random() < scale.eliteWeight
					then
						enemyId = ctx.eliteEnemyId
					end
					local healthMult = if doScale then scale.enemyHealthMult else nil
					local id = EnemyService.spawn(enemyId, pos + Vector3.new(offset, 0, 0), healthMult)
					unitWave[id] = waveIndex
					spawnedCount += 1
				end
			end
		end
		run:markSpawned(waveIndex, spawnedCount)
	end

	diedDisconnect = CombatService.EntityDied:connect(function(entity: any)
		if stopped then
			return
		end
		local waveIndex = unitWave[entity.id]
		if not waveIndex then
			return
		end
		unitWave[entity.id] = nil
		killed += 1
		if ctx.onProgress then
			ctx.onProgress(killed, total)
		end
		local _, nextWave, done = run:unitDied(waveIndex)
		if done then
			finish(true)
		elseif nextWave then
			task.delay(restSeconds, function()
				if not stopped then
					spawnWave(nextWave)
				end
			end)
		end
	end)

	for _, index in run:initialWaves() do
		spawnWave(index)
	end

	log:info(("encounter '%s' started (%d players, x%.2f count, ~%d enemies)"):format(
		encounterId,
		playerCount,
		scale.enemyCountMult,
		total
	))

	return function()
		finish(false)
	end
end

function WaveService.Init() end

function WaveService.Start()
	log:info("ready")
end

return WaveService
