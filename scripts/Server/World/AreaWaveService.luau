--!strict
--[[
	AreaWaveService
	Puts the dead in every room.

	--------------------------------------------------------------------------
	WHY THIS EXISTS

	Areas 1 and 2 both played correctly and both played wrong: you cut three
	ropes, you found a handle, you wound a winch, and nothing ever came. Every
	line written into those mechanics — progress is kept when you break off, the
	winch slips back while you fight — assumes there is something to break off
	FOR. Without it the barricade is a door with a delay on it.

	So: walk into a chamber and that chamber's encounter starts. The waves are
	PRESSURE, not the lock. Clearing them opens nothing; the room's own puzzle
	does that, and you can leave through the gate the moment it is done whether
	the room is empty or not.

	--------------------------------------------------------------------------
	WHY THE OLD ROOMS GET SWITCHED OFF

	Enemies follow you through the arch, which is exactly right and would end up
	with eight rooms' worth of dead behind you by the keep. So when you enter
	chamber N, chamber N-2's encounter is stopped and its stragglers despawn:
	one room of lag, so the thing chasing you through a doorway keeps chasing
	you, and the thing three rooms back does not.

	Place: Forgotten Lands ONLY (Server/World). Phase: Areas.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local GameService = require(Server.Services.GameService)
local AreaService = require(script.Parent.AreaService)
local WaveService = require(script.Parent.WaveService)
local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local AreaWaveService = {}

AreaWaveService.Name = "AreaWaveService"

local log = Logger.new("AreaWaveService")

--==========================================================================
-- Chambers 1..8. The ninth is the King and does not come out of a wave table.
local FIRST_AREA = 1
local LAST_AREA = 8

--[[
	A breath between walking in and being hit.

	Long enough to see the room and read the line at the top of the screen,
	short enough that nobody thinks the area is empty. Everything a player
	decides about a room is decided in these three seconds.
]]
local GRACE_SECONDS = 3

-- How far back the dead are allowed to keep coming. 2 = the room you are in
-- and the one behind it.
local TRAIL = 2

--==========================================================================
local running: { [number]: () -> () } = {} -- area index -> stop function

local function stop(index: number)
	local stopper = running[index]
	if not stopper then
		return
	end
	running[index] = nil
	local ok, err = pcall(stopper)
	if not ok then
		log:warn(("stopping area %d failed: %s"):format(index, tostring(err)))
	else
		log:info(("area %d encounter stopped"):format(index))
	end
end

local function start(index: number)
	if running[index] then
		return
	end

	local encounterId = ("area_%d"):format(index)
	if not Config.get("Encounters")[encounterId] then
		log:info(("no encounter '%s' — area %d stays quiet"):format(encounterId, index))
		return
	end

	--[[
		A placeholder so a second entry cannot start the same encounter twice
		during the grace. It is replaced by the real stop function below, and
		calling it before then is harmless.
	]]
	running[index] = function() end

	task.delay(GRACE_SECONDS, function()
		-- Left again during the grace, or the run ended: do not spawn into an
		-- empty room.
		if not running[index] then
			return
		end

		local stopper = WaveService.startEncounter(encounterId, {
			areaIndex = index,
			onWaveStart = function(wave: number, total: number)
				log:info(("area %d — wave %d of %d"):format(index, wave, total))
			end,
			onComplete = function()
				running[index] = nil
				log:info(("area %d cleared of enemies"):format(index))
			end,
		})

		if running[index] then
			running[index] = stopper
		else
			stopper() -- it was cancelled while we were starting it
		end
	end)

	log:info(("area %d entered — waves in %ds"):format(index, GRACE_SECONDS))
end

--==========================================================================
-- API
--==========================================================================

-- Shuts every room down. For a run restart.
function AreaWaveService.stopAll()
	for index in running do
		stop(index)
	end
end

function AreaWaveService.isRunning(index: number): boolean
	return running[index] ~= nil
end

--==========================================================================
function AreaWaveService.Init() end

function AreaWaveService.Start()
	if GameService.getPlaceRole() ~= Constants.PlaceRole.World then
		return
	end

	for index = FIRST_AREA, LAST_AREA do
		--[[
			Captured per iteration on purpose. `index` is the loop variable and
			every handler registered here outlives the loop, so closing over the
			shared one would give all eight the last value.
		]]
		local area = index
		AreaService.onEnter(area, function()
			start(area)
			stop(area - TRAIL)
		end)
	end

	log:info(("armed — chambers %d to %d"):format(FIRST_AREA, LAST_AREA))
end

return AreaWaveService
