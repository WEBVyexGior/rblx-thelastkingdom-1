--!strict
--[[
	PartyService
	Server-authoritative party management: create / join / leave, capacity, and
	leader handling. Pure backend — no UI, no matchmaking. Provides the party data
	that MatchService and (later) party re-formation build on.

	Place: shared. Phase: Multiplayer.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local Party = require(Server.Domain.Party)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local PartyService = {}

PartyService.Name = "PartyService"

local log = Logger.new("PartyService")
local parties: { [string]: Party.Party } = {}
local playerToParty: { [Player]: string } = {}
local nextId = 0

local function generateId(): string
	nextId += 1
	return "party_" .. nextId
end

-- Creates a new party led by `leader`. Returns nil if the player is already in
-- one.
function PartyService.createParty(leader: Player): Party.Party?
	if playerToParty[leader] then
		return nil
	end
	local party = Party.new(generateId(), leader, Constants.MAX_PARTY_SIZE)
	parties[party.id] = party
	playerToParty[leader] = party.id
	return party
end

function PartyService.getParty(player: Player): Party.Party?
	local id = playerToParty[player]
	if not id then
		return nil
	end
	return parties[id]
end

-- Adds a player to an existing party. Returns false on any rule violation.
function PartyService.joinParty(player: Player, partyId: string): boolean
	if playerToParty[player] then
		return false
	end
	local party = parties[partyId]
	if not party or not party:addMember(player) then
		return false
	end
	playerToParty[player] = partyId
	return true
end

-- Removes a player from their party, disbanding it if it becomes empty.
function PartyService.leaveParty(player: Player): boolean
	local id = playerToParty[player]
	if not id then
		return false
	end
	playerToParty[player] = nil
	local party = parties[id]
	if party then
		party:removeMember(player)
		if #party.members == 0 then
			parties[id] = nil
		end
	end
	return true
end

function PartyService.Init() end

function PartyService.Start()
	-- Independent cleanup: a leaving player is removed from their party.
	Players.PlayerRemoving:Connect(function(player)
		PartyService.leaveParty(player)
	end)
	log:info("ready")
end

return PartyService
