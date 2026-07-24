--!strict
--[[
	Inventory.Types
	Shared type contract for items, inventory, and equipment. A type-only module
	(returns an empty table); consumers use `InventoryTypes.<Name>`.

	Values for the string aliases come from `Inventory.Enums`.

	Location: ReplicatedStorage.Shared.Inventory.Types
]]

export type ItemId = string
export type Uid = string
export type ItemCategory = string
export type EquipmentSlot = string

-- A concrete owned item (a runtime instance, distinct from its definition). A
-- weapon "instance" is one of these whose definition is a Weapon.
export type ItemInstance = {
	uid: Uid,
	itemId: ItemId,
	quantity: number,
}

-- The static definition of an item type (mirrors an entry in configs/Items).
export type ItemDefinition = {
	DisplayName: string,
	Category: ItemCategory,
	Stackable: boolean,
	MaxStack: number?,
	Slot: EquipmentSlot?, -- present on equippable items
	WeaponId: string?, -- present on weapons -> configs/Weapons key
}

return {}
