--!strict
--[[
	BoardingRoster.spec
	Validates the pure boarding rules: ordered membership, duplicate/capacity
	refusal, leader succession, and the player-count -> difficulty tier mapping.

	Location: TestService.Tests.BoardingRoster.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local BoardingRoster = require(ServerScriptService.Server.Domain.BoardingRoster)

local TIERS = {
	{ id = "Normal", maxPlayers = 4 },
	{ id = "Hard", maxPlayers = 8 },
}

return function(t: any)
	t.test("a new roster is empty and has no leader", function()
		local roster = BoardingRoster.new(8)
		assert(roster:isEmpty(), "starts empty")
		assert(roster:count() == 0, "counts zero")
		assert(roster:leader() == nil, "no leader yet")
	end)

	t.test("add appends in boarding order and refuses duplicates", function()
		local roster = BoardingRoster.new(8)
		assert(roster:add("a"), "first boards")
		assert(roster:add("b"), "second boards")
		assert(not roster:add("a"), "already aboard")
		assert(roster:count() == 2, "still two aboard")
		local members = roster:members()
		assert(members[1] == "a" and members[2] == "b", "order preserved")
	end)

	t.test("add refuses once capacity is reached", function()
		local roster = BoardingRoster.new(2)
		assert(roster:add("a") and roster:add("b"), "fills up")
		assert(roster:isFull(), "reports full")
		assert(not roster:add("c"), "refuses the third")
		assert(roster:count() == 2, "capacity held")
	end)

	t.test("remove keeps the order of everyone else", function()
		local roster = BoardingRoster.new(8)
		roster:add("a")
		roster:add("b")
		roster:add("c")
		assert(roster:remove("b"), "b steps off")
		assert(not roster:remove("b"), "removing twice is a no-op")
		local members = roster:members()
		assert(#members == 2 and members[1] == "a" and members[2] == "c", "a then c remain")
	end)

	t.test("the leader is the first aboard, and succeeds when they step off", function()
		local roster = BoardingRoster.new(8)
		roster:add("a")
		roster:add("b")
		assert(roster:leader() == "a", "first aboard leads")
		roster:remove("a")
		assert(roster:leader() == "b", "next in line takes over")
	end)

	t.test("members returns a copy the caller cannot mutate the roster through", function()
		local roster = BoardingRoster.new(8)
		roster:add("a")
		local members = roster:members()
		table.insert(members, "ghost")
		assert(roster:count() == 1, "roster is unaffected")
	end)

	t.test("clear empties the roster", function()
		local roster = BoardingRoster.new(8)
		roster:add("a")
		roster:add("b")
		roster:clear()
		assert(roster:isEmpty(), "emptied")
	end)

	t.test("setCapacity resizes the party but never strands anyone aboard", function()
		local roster = BoardingRoster.new(8)
		roster:add("a")
		roster:add("b")
		roster:add("c")
		roster:setCapacity(5)
		assert(not roster:isFull(), "room for five")
		roster:setCapacity(2)
		assert(roster.capacity == 3, "clamped to the three already aboard")
		assert(roster:isFull(), "and is therefore full")
	end)

	t.test("tierFor maps 1-4 to Normal and 5-8 to Hard", function()
		assert(BoardingRoster.tierFor(1, TIERS) == "Normal", "solo is Normal")
		assert(BoardingRoster.tierFor(4, TIERS) == "Normal", "four is still Normal")
		assert(BoardingRoster.tierFor(5, TIERS) == "Hard", "five flips to Hard")
		assert(BoardingRoster.tierFor(8, TIERS) == "Hard", "eight is Hard")
	end)

	t.test("tierFor handles the edges", function()
		assert(BoardingRoster.tierFor(0, TIERS) == nil, "an empty group has no tier")
		assert(BoardingRoster.tierFor(3, {}) == nil, "no tiers configured")
		assert(BoardingRoster.tierFor(99, TIERS) == "Hard", "clamps to the last tier")
	end)
end
