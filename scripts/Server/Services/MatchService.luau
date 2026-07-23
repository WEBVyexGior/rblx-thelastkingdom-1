--!strict
--[[
	MatchService
	The Match Lifecycle. Creates a run for a party + mission, drives it through the
	Match state machine, and hands the party to the Teleport Framework. It ties
	together PartyService (who plays), MissionService (what they play), and
	TeleportService (getting them there).

	No gameplay lives here — only run orchestration. The actual teleport no-ops
	while the world place is unpublished, so this is safe to exercise now.

	Place: shared (Hub starts a run; World tracks it). Phase: Multiplayer.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local Match = require(Server.Domain.Match)
local PartyService = require(script.Parent.PartyService)
local MissionService = require(script.Parent.MissionService)
local TeleportService = require(script.Parent.TeleportService)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local MatchService = {}

MatchService.Name = "MatchService"

local log = Logger.new("MatchService")
local matches: { [string]: Match.Match } = {}
local nextId = 0

local function generateId(): string
	nextId += 1
	return "match_" .. nextId
end

-- Starts a run for the leader's party on the given mission. Returns the Match, or
-- nil if the leader has no party.
function MatchService.startMatch(leader: Player, missionId: string): Match.Match?
	local party = PartyService.getParty(leader)
	if not party then
		log:warn("startMatch: no party for " .. leader.Name)
		return nil
	end

	-- Missions may be unregistered in Phase 2 (empty registry) — allowed, noted.
	if not MissionService.get(missionId) then
		log:warn("startMatch: mission not registered: " .. missionId)
	end

	local userIds: { number } = {}
	for _, player in party.members do
		table.insert(userIds, player.UserId)
	end

	local match = Match.new(generateId(), missionId, userIds)
	matches[match.id] = match
	match:setState(Match.States.Loading)

	local data = TeleportService.buildOutboundData(match.id, missionId, userIds)
	TeleportService.teleportPartyToWorld(party.members, data)

	return match
end

function MatchService.getMatch(id: string): Match.Match?
	return matches[id]
end

-- Requests a lifecycle transition for a match. Returns false if not allowed.
function MatchService.setState(id: string, state: string): boolean
	local match = matches[id]
	if not match then
		return false
	end
	return match:setState(state)
end

function MatchService.endMatch(id: string)
	local match = matches[id]
	if match then
		match:setState(Match.States.Ended)
		matches[id] = nil
	end
end

function MatchService.Init() end

function MatchService.Start()
	log:info("ready")
end

return MatchService
