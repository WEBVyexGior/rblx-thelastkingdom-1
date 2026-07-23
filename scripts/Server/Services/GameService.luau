--!strict
--[[
	GameService
	High-level coordinator. In Phase 2 its concrete job is to detect which of the
	two places this server is (Hub or Forgotten Lands) and expose that to the
	other services, so shared services can behave place-appropriately without
	hard-coding place ids.

	Place: shared. Phase: Core Systems.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local GameService = {}

GameService.Name = "GameService"

local log = Logger.new("GameService")
local placeRole = Constants.PlaceRole.Unknown

-- Detects the place from which place-specific server folder was synced in.
local function detectPlaceRole(): string
	local server = ServerScriptService:FindFirstChild("Server")
	if server then
		if server:FindFirstChild("World") then
			return Constants.PlaceRole.World
		elseif server:FindFirstChild("Hub") then
			return Constants.PlaceRole.Hub
		end
	end
	return Constants.PlaceRole.Unknown
end

function GameService.getPlaceRole(): string
	return placeRole
end

function GameService.Init()
	placeRole = detectPlaceRole()
end

function GameService.Start()
	log:info("running as " .. placeRole)
end

return GameService
