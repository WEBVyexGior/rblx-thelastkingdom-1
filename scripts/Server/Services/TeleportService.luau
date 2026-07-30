--!strict
--[[
	TeleportService (game wrapper)
	The Teleport Framework. A thin, game-specific wrapper around Roblox's engine
	TeleportService that owns all movement between the two places and the shape of
	the teleport data carried across.

	NOTE: this is OUR service module. It internally uses the engine service via
	game:GetService("TeleportService").

	Safety: every teleport no-ops (with a warning) while the target place is
	unpublished (PlaceId 0), so this is safe to run in Studio and before the games
	are published. Teleport data is untrusted on arrival — the receiving server
	must re-validate it against the persisted profile.

	Place: shared. Phase: Multiplayer.
]]

local EngineTeleport = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local TeleportService = {}

TeleportService.Name = "TeleportService"

local log = Logger.new("TeleportService")

-- Data carried Hub -> Forgotten Lands. `chapterId` / `difficulty` are set once a
-- run is started from the lobby (the departure train); they are absent for the
-- dev flow that boots straight into the World place.
export type OutboundData = {
	matchId: string,
	missionId: string,
	memberUserIds: { number },
	chapterId: string?,
	difficulty: string?,
}

-- Builds the outbound teleport payload. `extra` carries the optional run context.
function TeleportService.buildOutboundData(
	matchId: string,
	missionId: string,
	memberUserIds: { number },
	extra: { chapterId: string?, difficulty: string? }?
): OutboundData
	return {
		matchId = matchId,
		missionId = missionId,
		memberUserIds = memberUserIds,
		chapterId = if extra then extra.chapterId else nil,
		difficulty = if extra then extra.difficulty else nil,
	}
end

-- Reads teleport data for an arriving player (nil if they were not teleported).
function TeleportService.getArrivingData(player: Player): any
	return player:GetJoinData().TeleportData
end

local function teleport(
	placeId: number,
	players: { Player },
	data: any,
	label: string,
	reserve: boolean?
): boolean
	if placeId == 0 then
		log:warn(label .. " skipped: target PlaceId not set")
		return false
	end
	local options = Instance.new("TeleportOptions")
	if data ~= nil then
		options:SetTeleportData(data)
	end

	-- A co-op run belongs to ONE party: reserve a private server so the group is
	-- never matchmade into a stranger's mission. If reserving fails (e.g. Studio
	-- without API access) we degrade to a public server rather than stranding the
	-- party in the lobby.
	if reserve then
		local reserved, accessCode = pcall(function()
			return EngineTeleport:ReserveServer(placeId)
		end)
		if reserved and accessCode then
			options.ReservedServerAccessCode = accessCode
		else
			log:warn(label .. ": ReserveServer failed, falling back to a public server")
		end
	end

	local ok, err = pcall(function()
		EngineTeleport:TeleportAsync(placeId, players, options)
	end)
	if not ok then
		log:warn(label .. " failed: " .. tostring(err))
	end
	return ok
end

-- Sends a party into a fresh private Forgotten Lands server.
function TeleportService.teleportPartyToWorld(players: { Player }, data: OutboundData): boolean
	return teleport(Constants.PlaceIds.ForgottenLands, players, data, "Teleport to world", true)
end

-- Returns players to the Kingdom Hub, optionally carrying run-result data.
function TeleportService.returnToHub(players: { Player }, data: any): boolean
	return teleport(Constants.PlaceIds.KingdomHub, players, data, "Return to hub")
end

function TeleportService.Init() end

function TeleportService.Start() end

return TeleportService
