--!strict
--[[
	InventoryService
	Server-authoritative owner of player inventories (gear, consumables,
	resources, quest items, relics). Clients only ever request changes; this
	service validates and applies them, backed by DataService for persistence.

	Responsibilities (future phases):
	- Add / remove / move items with server-side validation.
	- Enforce capacity and stacking rules.
	- Replicate inventory state to the owning client.

	Place: shared (Hub manages, World uses).
	Phase: Inventory. NO inventory logic is implemented in Phase 1 by design.
	Status: skeleton.
]]

local InventoryService = {}

InventoryService.Name = "InventoryService"

function InventoryService.Init()
	-- Reserved. No logic in Phase 1.
end

function InventoryService.Start()
	-- Reserved. No logic in Phase 1.
end

return InventoryService
