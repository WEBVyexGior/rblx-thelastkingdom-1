--!strict
--[[
	Inventory (domain class)
	A player's collection of item instances. Pure data + rules (uid generation,
	membership, optional capacity). It performs no networking and knows nothing
	about equipment or persistence — InventoryService orchestrates those.

	Stacking is deliberately NOT implemented here yet: each `add` is a discrete
	instance. Stackable merging is a later concern.

	Location: ServerScriptService.Server.Domain.Inventory.Inventory
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Inventory.Types)

local Inventory = {}
Inventory.__index = Inventory

export type Inventory = typeof(setmetatable(
	{} :: {
		items: { [string]: Types.ItemInstance },
		nextUid: number,
		capacity: number, -- 0 = unlimited
	},
	Inventory
))

function Inventory.new(capacity: number?): Inventory
	return setmetatable({
		items = {},
		nextUid = 1,
		capacity = capacity or 0,
	}, Inventory)
end

function Inventory.count(self: Inventory): number
	local n = 0
	for _ in self.items do
		n += 1
	end
	return n
end

function Inventory.isFull(self: Inventory): boolean
	return self.capacity > 0 and self:count() >= self.capacity
end

-- Adds a new item instance for `itemId`. Returns it, or nil if the inventory is
-- full. The uid is unique within this inventory.
function Inventory.add(self: Inventory, itemId: string, quantity: number?): Types.ItemInstance?
	if self:isFull() then
		return nil
	end
	local uid = "item_" .. self.nextUid
	self.nextUid += 1
	local instance: Types.ItemInstance = {
		uid = uid,
		itemId = itemId,
		quantity = quantity or 1,
	}
	self.items[uid] = instance
	return instance
end

function Inventory.get(self: Inventory, uid: string): Types.ItemInstance?
	return self.items[uid]
end

function Inventory.remove(self: Inventory, uid: string): boolean
	if self.items[uid] then
		self.items[uid] = nil
		return true
	end
	return false
end

function Inventory.list(self: Inventory): { Types.ItemInstance }
	local result: { Types.ItemInstance } = {}
	for _, instance in self.items do
		table.insert(result, instance)
	end
	return result
end

-- First instance matching `itemId`, if any (e.g. an ownership check).
function Inventory.findByItemId(self: Inventory, itemId: string): Types.ItemInstance?
	for _, instance in self.items do
		if instance.itemId == itemId then
			return instance
		end
	end
	return nil
end

return Inventory
