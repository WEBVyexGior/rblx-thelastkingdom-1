--!strict
--[[
	Inventory.spec
	Validates the Inventory domain class: add/get/remove, listing & counting,
	lookup by item id, unique uids, and capacity.

	Location: TestService.Tests.Inventory.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local Inventory = require(ServerScriptService.Server.Domain.Inventory.Inventory)

return function(t: any)
	t.test("add creates a retrievable instance", function()
		local inv = Inventory.new()
		local item = inv:add("starter_sword")
		assert(item ~= nil, "add should return an instance")
		assert(item.itemId == "starter_sword", "itemId preserved")
		assert(item.quantity == 1, "default quantity is 1")
		assert(inv:get(item.uid) == item, "get returns the same instance")
	end)

	t.test("uids are unique per add", function()
		local inv = Inventory.new()
		local a = inv:add("x")
		local b = inv:add("x")
		assert(a and b, "adds should succeed")
		assert(a.uid ~= b.uid, "each add gets a distinct uid")
		assert(inv:count() == 2, "count reflects two items")
	end)

	t.test("remove removes only the target", function()
		local inv = Inventory.new()
		local a = inv:add("x")
		local b = inv:add("y")
		assert(a and b, "adds should succeed")
		assert(inv:remove(a.uid), "remove returns true for a present item")
		assert(inv:get(a.uid) == nil, "removed item is gone")
		assert(inv:get(b.uid) == b, "other item remains")
		assert(not inv:remove("missing"), "removing an absent uid returns false")
	end)

	t.test("findByItemId finds a match", function()
		local inv = Inventory.new()
		inv:add("sword")
		assert(inv:findByItemId("sword") ~= nil, "finds an owned item")
		assert(inv:findByItemId("shield") == nil, "returns nil for an unowned item")
	end)

	t.test("capacity blocks adds when full", function()
		local inv = Inventory.new(1)
		assert(inv:add("a") ~= nil, "first add fits")
		assert(inv:isFull(), "inventory is full at capacity")
		assert(inv:add("b") == nil, "add beyond capacity returns nil")
	end)
end
