--!strict
--[[
	Party.spec
	Validates the Party domain rules: membership, capacity, duplicate rejection,
	leader promotion when the leader leaves, and the locked guard.

	The Party module only stores its members, compares them by identity, and runs
	`table.find` on them — it never touches Player-specific API — so plain tables
	stand in for Player instances at runtime.

	Location: TestService.Tests.Party.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local Party = require(ServerScriptService.Server.Domain.Party)

local function fakePlayer(name: string): any
	return { Name = name }
end

return function(t: any)
	t.test("a new party contains only its leader", function()
		local leader = fakePlayer("Leader")
		local p = Party.new("p1", leader, 8)
		assert(#p.members == 1, "a new party should have exactly one member")
		assert(p.members[1] == leader, "the sole member should be the leader")
		assert(p.leader == leader, "the leader should be set")
	end)

	t.test("addMember fills up to capacity, then refuses", function()
		local p = Party.new("p1", fakePlayer("Leader"), 2)
		assert(p:addMember(fakePlayer("A")), "second member should join (capacity 2)")
		assert(p:isFull(), "party should report full at capacity")
		assert(not p:addMember(fakePlayer("B")), "a member beyond capacity must be refused")
	end)

	t.test("addMember refuses a duplicate member", function()
		local p = Party.new("p1", fakePlayer("Leader"), 8)
		local a = fakePlayer("A")
		assert(p:addMember(a), "A should join")
		assert(not p:addMember(a), "adding A twice must be refused")
	end)

	t.test("removeMember promotes a new leader when the leader leaves", function()
		local leader = fakePlayer("Leader")
		local a = fakePlayer("A")
		local p = Party.new("p1", leader, 8)
		p:addMember(a)
		assert(p:removeMember(leader), "the leader should be removed")
		assert(p.leader == a, "a remaining member should be promoted to leader")
	end)

	t.test("a locked party refuses new members", function()
		local p = Party.new("p1", fakePlayer("Leader"), 8)
		p.locked = true
		assert(not p:addMember(fakePlayer("A")), "a locked party must refuse new members")
	end)
end
