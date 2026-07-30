--!strict
--[[
	DeathGroup (domain)
	PURE helpers over a map of run-participant death statuses. No Roblox, no players —
	just the group rules the DeathService acts on: is the run wiped, can anyone still
	revive teammates, and who is waiting for re-formation. Unit-testable.

	`statuses` is `{ [key]: DeathStatus }` (key is any stable id, e.g. a Player).

	Location: ServerScriptService.Server.Domain.DeathGroup
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage.Shared.Death.Enums)

local DeathGroup = {}

-- Count of participants that are still Alive.
function DeathGroup.aliveCount(statuses: { [any]: string }): number
	local n = 0
	for _, status in statuses do
		if status == Enums.DeathStatus.Alive then
			n += 1
		end
	end
	return n
end

-- A total wipe: at least one participant, and no one is Alive OR still Down (a Down
-- player is still deciding and could self-revive). i.e. everyone has resolved to
-- Waiting or Left, so the run cannot continue.
function DeathGroup.isWipe(statuses: { [any]: string }): boolean
	if next(statuses) == nil then
		return false
	end
	for _, status in statuses do
		if status == Enums.DeathStatus.Alive or status == Enums.DeathStatus.Down then
			return false
		end
	end
	return true
end

-- True if any living player could revive a downed teammate.
function DeathGroup.canReviveTeammates(statuses: { [any]: string }): boolean
	return DeathGroup.aliveCount(statuses) > 0
end

-- Keys that currently hold `status` (e.g. the Waiting survivors to re-form).
function DeathGroup.withStatus(statuses: { [any]: string }, status: string): { any }
	local result: { any } = {}
	for key, s in statuses do
		if s == status then
			table.insert(result, key)
		end
	end
	return result
end

return DeathGroup
