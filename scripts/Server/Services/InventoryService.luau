--!strict
--[[
	InventoryService
	Server-authoritative owner of player inventories (gear, consumables,
	resources, quest items, relics). Anything that changes an inventory goes
	through here; item ids are validated against the Items config.

	State is per-player, in-memory, and created lazily. Serialization to the
	persistent Profile (see DataService/ProfileSchema) is a deliberate follow-up —
	the foundation establishes the API first; nothing persists across servers yet
	(the store is still the in-memory mock).

	Place: shared (managed in the Hub, used in the World). Phase: Inventory.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local Inventory = require(Server.Domain.Inventory.Inventory)
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Inventory.Types)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local InventoryService = {}

InventoryService.Name = "InventoryService"

local log = Logger.new("InventoryService")
local inventories: { [Player]: Inventory.Inventory } = {}

-- Lazily creates (or returns) a player's inventory, so callers never depend on
-- join-handler ordering.
local function ensure(player: Player): Inventory.Inventory
	local inv = inventories[player]
	if not inv then
		inv = Inventory.new()
		inventories[player] = inv
	end
	return inv
end

function InventoryService.getInventory(player: Player): Inventory.Inventory
	return ensure(player)
end

-- Adds an item by definition id, validated against the Items config. Returns the
-- created instance, or nil if the id is unknown or the inventory is full.
function InventoryService.addItem(player: Player, itemId: string, quantity: number?): Types.ItemInstance?
	local items = Config.get("Items")
	if not items[itemId] then
		log:warn("addItem: unknown item id '" .. itemId .. "'")
		return nil
	end
	return ensure(player):add(itemId, quantity)
end

function InventoryService.removeItem(player: Player, uid: string): boolean
	return ensure(player):remove(uid)
end

function InventoryService.getItem(player: Player, uid: string): Types.ItemInstance?
	return ensure(player):get(uid)
end

function InventoryService.list(player: Player): { Types.ItemInstance }
	return ensure(player):list()
end

function InventoryService.Init() end

function InventoryService.Start()
	Players.PlayerRemoving:Connect(function(player)
		inventories[player] = nil
	end)
	log:info("ready")
end

return InventoryService
