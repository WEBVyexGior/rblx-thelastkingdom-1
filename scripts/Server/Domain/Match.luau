--!strict
--[[
	Match (domain class)
	Represents a single run and owns its lifecycle STATE MACHINE. Transitions are
	validated against an allowed-transitions table so a run can only move through
	legal states (e.g. it can never jump from Created straight to Active).

	This uses a small local transition table rather than the future generic
	Shared/Core.StateMachine primitive; it will migrate to that once it exists.

	Location: ServerScriptService.Server.Domain.Match
]]

local Match = {}
Match.__index = Match

-- The lifecycle states a run moves through.
local STATES = {
	Created = "Created", -- built in the Hub, before teleport
	Loading = "Loading", -- teleporting / world spinning up
	Active = "Active", -- the run is being played
	Completing = "Completing", -- objective met / wrapping up
	Ended = "Ended", -- finished (success, wipe, or return)
}

-- Allowed transitions from each state. "Ended" is terminal.
local TRANSITIONS: { [string]: { string } } = {
	Created = { "Loading", "Ended" },
	Loading = { "Active", "Ended" },
	Active = { "Completing", "Ended" },
	Completing = { "Ended" },
	Ended = {},
}

Match.States = STATES

export type Match = typeof(setmetatable(
	{} :: {
		id: string,
		missionId: string,
		memberUserIds: { number },
		state: string,
		createdAt: number,
	},
	Match
))

function Match.new(id: string, missionId: string, memberUserIds: { number }): Match
	return setmetatable({
		id = id,
		missionId = missionId,
		memberUserIds = memberUserIds,
		state = STATES.Created,
		createdAt = os.time(),
	}, Match)
end

function Match.canTransition(self: Match, target: string): boolean
	local allowed = TRANSITIONS[self.state]
	return allowed ~= nil and table.find(allowed, target) ~= nil
end

-- Attempts a transition. Returns false (and does nothing) if it is not allowed.
function Match.setState(self: Match, target: string): boolean
	if not self:canTransition(target) then
		return false
	end
	self.state = target
	return true
end

return Match
