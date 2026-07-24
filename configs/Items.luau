--!strict
--[[
	Config: Items
	The item catalog — static definitions for every item type (weapons, armor,
	consumables, resources, quest items, relics). This is item STRUCTURE/metadata,
	not combat balancing: a weapon item points at its combat stats in Weapons.luau
	via `WeaponId`, keeping "what an item is" separate from "how a weapon fights".

	Read via: Config.get("Items")

	Schema (per entry):
		[itemId: string] = {
			DisplayName = string,
			Category    = string,    -- a Shared.Inventory.Enums.ItemCategory value
			Stackable   = boolean,
			MaxStack    = number?,   -- for stackables
			Slot        = string?,   -- equippables: a Shared.Inventory.Enums.EquipmentSlot value
			WeaponId    = string?,   -- weapons: a configs/Weapons key for combat stats
		}
]]

local Items = {
	-- TEST placeholder item for the combat/equipment slice. Links to the
	-- starter_sword combat stats in Weapons.luau. Not final content.
	starter_sword = {
		DisplayName = "Worn Sword",
		Category = "Weapon",
		Stackable = false,
		Slot = "MainHand",
		WeaponId = "starter_sword",
	},
}

return table.freeze(Items)
