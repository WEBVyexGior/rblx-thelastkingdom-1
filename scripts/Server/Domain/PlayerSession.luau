--!strict
--[[
	PlayerSession (domain class)
	Runtime, server-only state for one connected player during a session. This is
	NOT persistent data (that is the Profile, owned by DataService/SaveService) —
	it is transient state that only lives while the player is in this server:
	which party/match they are in, whether they are ready, when they joined.

	Location: ServerScriptService.Server.Domain.PlayerSession
]]

local PlayerSession = {}
PlayerSession.__index = PlayerSession

export type PlayerSession = typeof(setmetatable(
	{} :: {
		player: Player,
		joinedAt: number,
		partyId: string?,
		matchId: string?,
		isReady: boolean,
	},
	PlayerSession
))

function PlayerSession.new(player: Player): PlayerSession
	return setmetatable({
		player = player,
		joinedAt = os.time(),
		partyId = nil,
		matchId = nil,
		isReady = false,
	}, PlayerSession)
end

function PlayerSession.destroy(self: PlayerSession)
	self.partyId = nil
	self.matchId = nil
	self.isReady = false
end

return PlayerSession
