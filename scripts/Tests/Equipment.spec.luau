--!strict
--[[
	Equipment.spec
	Validates the Equipment domain class: setting/getting a slot, returning the
	previously equipped instance, and clearing.

	Location: TestService.Tests.Equipment.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local Equipment = require(ServerScriptService.Server.Domain.Inventory.Equipment)

local function fakeItem(uid: string, itemId: string): any
	return { uid = uid, itemId = itemId, quantity = 1 }
end

return function(t: any)
	t.test("set then get returns the instance", function()
		local eq = Equipment.new()
		local sword = fakeItem("i1", "starter_sword")
		eq:set("MainHand", sword)
		assert(eq:get("MainHand") == sword, "the equipped item is returned")
		assert(eq:get("OffHand") == nil, "an empty slot returns nil")
	end)

	t.test("set returns the previously equipped instance", function()
		local eq = Equipment.new()
		local first = fakeItem("i1", "a")
		local second = fakeItem("i2", "b")
		assert(eq:set("MainHand", first) == nil, "no previous item on the first set")
		assert(eq:set("MainHand", second) == first, "the second set returns the first")
		assert(eq:get("MainHand") == second, "the slot now holds the second item")
	end)

	t.test("clear empties a slot and returns what was there", function()
		local eq = Equipment.new()
		local sword = fakeItem("i1", "a")
		eq:set("MainHand", sword)
		assert(eq:clear("MainHand") == sword, "clear returns the removed item")
		assert(eq:get("MainHand") == nil, "slot is empty after clear")
		assert(eq:clear("MainHand") == nil, "clearing an empty slot returns nil")
	end)
end
