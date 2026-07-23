--!strict
--[[
	PlayerService
	Authoritative owner of the player lifecycle and the single place that handles
	PlayerAdded / PlayerRemoving. On join it loads the player's profile (via
	SaveService) and creates their runtime PlayerSession; on leave it tears the
	session down and flushes their data. Other services read sessions from here
	instead of each wiring their own join handler.

	Place: shared. Phase: Core Systems.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local PlayerSession = require(Server.Domain.PlayerSession)
local SaveService = require(script.Parent.SaveService)
local DataService = require(script.Parent.DataService)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local PlayerService = {}

PlayerService.Name = "PlayerService"

local log = Logger.new("PlayerService")
local sessions: { [Player]: PlayerSession.PlayerSession } = {}

local function onPlayerAdded(player: Player)
	SaveService.load(player) -- profile in cache before the session is usable
	local session = PlayerSession.new(player)
	session.isReady = true
	sessions[player] = session
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if session then
		session:destroy()
		sessions[player] = nil
	end
	SaveService.save(player)
	DataService.clear(player)
end

function PlayerService.getSession(player: Player): PlayerSession.PlayerSession?
	return sessions[player]
end

function PlayerService.Init() end

function PlayerService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Handle players already present (e.g. Studio playtest starts the server
	-- after the local player has joined).
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	log:info("ready")
end

return PlayerService
