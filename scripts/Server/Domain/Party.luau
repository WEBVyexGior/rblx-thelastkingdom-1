--!strict
--[[
	Party (domain class)
	A group of players that plays a run together. Pure data + rules (capacity,
	membership, leadership). It performs no networking and knows nothing about
	matches or teleporting — PartyService orchestrates those.

	Location: ServerScriptService.Server.Domain.Party
]]

local Party = {}
Party.__index = Party

export type Party = typeof(setmetatable(
	{} :: {
		id: string,
		leader: Player,
		members: { Player },
		maxSize: number,
		locked: boolean,
	},
	Party
))

function Party.new(id: string, leader: Player, maxSize: number): Party
	return setmetatable({
		id = id,
		leader = leader,
		members = { leader },
		maxSize = maxSize,
		locked = false,
	}, Party)
end

function Party.isFull(self: Party): boolean
	return #self.members >= self.maxSize
end

function Party.hasMember(self: Party, player: Player): boolean
	return table.find(self.members, player) ~= nil
end

-- Adds a player. Returns false if locked, full, or already a member.
function Party.addMember(self: Party, player: Player): boolean
	if self.locked or self:isFull() or self:hasMember(player) then
		return false
	end
	table.insert(self.members, player)
	return true
end

-- Removes a player. Promotes a new leader if the leader left and others remain.
function Party.removeMember(self: Party, player: Player): boolean
	local index = table.find(self.members, player)
	if not index then
		return false
	end
	table.remove(self.members, index)
	if self.leader == player and #self.members > 0 then
		self.leader = self.members[1]
	end
	return true
end

return Party
