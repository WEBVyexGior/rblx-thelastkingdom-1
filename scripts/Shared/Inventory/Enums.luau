--!strict
--[[
	Inventory.Enums
	Shared vocabulary for items and equipment: identifiers (not balancing data)
	used by the inventory / equipment / combat systems. Small and extensible — add
	members as content grows; tunable numbers live in `configs/`.

	Location: ReplicatedStorage.Shared.Inventory.Enums
]]

local Enums = {}

-- What kind of thing an item is. Drives how it's used (equip, consume, stack, ...).
Enums.ItemCategory = table.freeze({
	Weapon = "Weapon",
	Armor = "Armor",
	Consumable = "Consumable",
	Resource = "Resource",
	QuestItem = "QuestItem",
	Relic = "Relic",
})

-- Equipment slots. Minimal base set; extend (Legs, Feet, Accessory, ...) later.
Enums.EquipmentSlot = table.freeze({
	MainHand = "MainHand",
	OffHand = "OffHand",
	Head = "Head",
	Chest = "Chest",
})

return table.freeze(Enums)
