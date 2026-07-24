--!strict
--[[
	Equipment (domain class)
	A player's equipped items, one per slot. Pure data + rules; it stores
	ItemInstances that also live in the owning Inventory (equipping references,
	it does not copy or consume). EquipmentService orchestrates validation
	(ownership, whether an item is equippable, which slot it belongs to).

	Location: ServerScriptService.Server.Domain.Inventory.Equipment
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Inventory.Types)

local Equipment = {}
Equipment.__index = Equipment

export type Equipment = typeof(setmetatable(
	{} :: {
		slots: { [string]: Types.ItemInstance },
	},
	Equipment
))

function Equipment.new(): Equipment
	return setmetatable({ slots = {} }, Equipment)
end

function Equipment.get(self: Equipment, slot: string): Types.ItemInstance?
	return self.slots[slot]
end

-- Places `instance` in `slot`, returning whatever was previously there (if any).
function Equipment.set(self: Equipment, slot: string, instance: Types.ItemInstance): Types.ItemInstance?
	local previous = self.slots[slot]
	self.slots[slot] = instance
	return previous
end

-- Empties `slot`, returning what was there (if any).
function Equipment.clear(self: Equipment, slot: string): Types.ItemInstance?
	local previous = self.slots[slot]
	self.slots[slot] = nil
	return previous
end

function Equipment.getAll(self: Equipment): { [string]: Types.ItemInstance }
	return self.slots
end

return Equipment
