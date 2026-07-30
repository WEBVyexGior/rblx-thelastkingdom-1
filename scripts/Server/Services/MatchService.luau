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

-- Starts a run for the leader's party on the given mission. `context` carries the
-- optional run details chosen in the lobby (chapter, difficulty tier).
--
-- Returns the Match and whether the party actually got moved. The two are
-- separate on purpose: the match exists the moment it is created, but the
-- teleport can still fail (a full reserved server, an outage, Studio), and the
-- caller has to be able to tell its players so rather than leaving them standing
-- in the lobby wondering.
function MatchService.startMatch(
	leader: Player,
	missionId: string,
	context: { chapterId: string?, difficulty: string? }?
): (Match.Match?, boolean)
	local party = PartyService.getParty(leader)
	if not party then
		log:warn("startMatch: no party for " .. leader.Name)
		return nil, false
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

	local data = TeleportService.buildOutboundData(match.id, missionId, userIds, context)
	local sent = TeleportService.teleportPartyToWorld(party.members, data)
	if not sent then
		-- The run never began. Drop it rather than leaving a phantom match
		-- occupying an id that nothing will ever end.
		match:setState(Match.States.Ended)
		matches[match.id] = nil
	end

	return match, sent
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
