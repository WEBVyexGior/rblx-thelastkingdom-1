--!strict
--[[
	BoardingRoster (domain)
	PURE ordered roster of who is currently aboard the departure train, plus the
	party-size rules TrainService acts on: capacity, emptiness, and which difficulty
	tier the current group falls into. No Roblox API and no Players — keys are any
	stable id — so it is unit-testable.

	Order matters: boarding order is preserved, and the FIRST key aboard becomes the
	party leader on departure (and the next one along if that player steps off).

	Location: ServerScriptService.Server.Domain.BoardingRoster
]]

local BoardingRoster = {}
BoardingRoster.__index = BoardingRoster

export type BoardingRoster = typeof(setmetatable(
	{} :: { capacity: number, keys: { any } },
	BoardingRoster
))

-- A difficulty tier applies to groups up to `maxPlayers` (see configs/Difficulty).
export type Tier = { id: string, maxPlayers: number }

function BoardingRoster.new(capacity: number): BoardingRoster
	return setmetatable({ capacity = capacity, keys = {} }, BoardingRoster)
end

local function indexOf(self: BoardingRoster, key: any): number?
	for i, existing in self.keys do
		if existing == key then
			return i
		end
	end
	return nil
end

function BoardingRoster.has(self: BoardingRoster, key: any): boolean
	return indexOf(self, key) ~= nil
end

function BoardingRoster.count(self: BoardingRoster): number
	return #self.keys
end

function BoardingRoster.isEmpty(self: BoardingRoster): boolean
	return #self.keys == 0
end

function BoardingRoster.isFull(self: BoardingRoster): boolean
	return #self.keys >= self.capacity
end

-- The party leader picks the size when they call the party, so capacity is set
-- per departure. Never drops below the number already aboard — a size chosen for
-- a smaller group must not strand anyone.
function BoardingRoster.setCapacity(self: BoardingRoster, capacity: number)
	self.capacity = math.max(capacity, #self.keys)
end

-- Appends `key`. Returns false if it is already aboard or the train is full.
function BoardingRoster.add(self: BoardingRoster, key: any): boolean
	if BoardingRoster.has(self, key) or BoardingRoster.isFull(self) then
		return false
	end
	table.insert(self.keys, key)
	return true
end

-- Removes `key`, preserving the order of everyone else. Returns false if absent.
function BoardingRoster.remove(self: BoardingRoster, key: any): boolean
	local index = indexOf(self, key)
	if not index then
		return false
	end
	table.remove(self.keys, index)
	return true
end

-- The party leader on departure: whoever boarded first and is still aboard.
function BoardingRoster.leader(self: BoardingRoster): any?
	return self.keys[1]
end

-- A copy, so callers cannot mutate the roster through it.
function BoardingRoster.members(self: BoardingRoster): { any }
	return table.clone(self.keys)
end

function BoardingRoster.clear(self: BoardingRoster)
	table.clear(self.keys)
end

-- Maps a group size onto its difficulty tier (1-4 Normal, 5-8 Hard by default).
-- Returns nil for an empty group; clamps to the last tier above the final bound.
function BoardingRoster.tierFor(count: number, tiers: { Tier }): string?
	if count <= 0 or #tiers == 0 then
		return nil
	end
	for _, tier in tiers do
		if count <= tier.maxPlayers then
			return tier.id
		end
	end
	return tiers[#tiers].id
end

return BoardingRoster
