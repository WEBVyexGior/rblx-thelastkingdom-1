--!strict
--[[
	EquipmentService
	Server-authoritative owner of what each player has equipped, per slot. Equips
	items that already live in the player's inventory (it references, never copies)
	and validates ownership + that an item is actually equippable and which slot it
	belongs to (from the Items config).

	Its `getEquippedWeaponId` is the seam the combat layer uses to resolve the
	player's current weapon — so the melee system reads the EQUIPPED weapon rather
	than a hard-coded id.

	State is per-player, in-memory, lazily created (persistence is a follow-up,
	like InventoryService). Place: shared. Phase: Inventory / Equipment.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local Equipment = require(Server.Domain.Inventory.Equipment)
local InventoryService = require(script.Parent.InventoryService)
local Config = require(ReplicatedStorage.Shared.Config)
local Enums = require(ReplicatedStorage.Shared.Inventory.Enums)
local Types = require(ReplicatedStorage.Shared.Inventory.Types)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local EquipmentService = {}

EquipmentService.Name = "EquipmentService"

local log = Logger.new("EquipmentService")
local equipments: { [Player]: Equipment.Equipment } = {}

local function ensure(player: Player): Equipment.Equipment
	local eq = equipments[player]
	if not eq then
		eq = Equipment.new()
		equipments[player] = eq
	end
	return eq
end

function EquipmentService.getEquipped(player: Player, slot: string): Types.ItemInstance?
	return ensure(player):get(slot)
end

function EquipmentService.getAll(player: Player): { [string]: Types.ItemInstance }
	return ensure(player):getAll()
end

-- Equips an inventory item (by uid) into its definition's slot. Returns true on
-- success. Server-authoritative: the item must be owned and equippable.
function EquipmentService.equip(player: Player, uid: string): boolean
	local instance = InventoryService.getItem(player, uid)
	if not instance then
		return false
	end
	local items = Config.get("Items")
	local def = items[instance.itemId]
	if not def or not def.Slot then
		return false -- not an equippable item
	end
	ensure(player):set(def.Slot, instance)
	return true
end

function EquipmentService.unequip(player: Player, slot: string): boolean
	return ensure(player):clear(slot) ~= nil
end

-- Convenience for the combat layer: the Weapons key of the MainHand weapon, if
-- one is equipped. Returns nil when unarmed.
function EquipmentService.getEquippedWeaponId(player: Player): string?
	local instance = ensure(player):get(Enums.EquipmentSlot.MainHand)
	if not instance then
		return nil
	end
	local items = Config.get("Items")
	local def = items[instance.itemId]
	if def and def.Category == Enums.ItemCategory.Weapon then
		return def.WeaponId
	end
	return nil
end

function EquipmentService.Init() end

function EquipmentService.Start()
	Players.PlayerRemoving:Connect(function(player)
		equipments[player] = nil
	end)
	log:info("ready")
end

return EquipmentService
