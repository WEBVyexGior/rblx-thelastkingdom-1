--!strict
--[[
	Config: Loot
	Loot and drop tables (resource nodes, enemy drops, rare/relic pools).

	Read via: Config.get("Loot")
	Filled with real values in later phases. Empty in Phase 1 by design.

	NOTE: drop tables are sensitive (players should not read exact odds). This
	config is a candidate to move to a server-only location later; see
	configs/README.md.

	Schema:
		Tables = {
			[tableId: string] = {
				{ Item = string, Weight = number, MinCount = number, MaxCount = number },
			},
		},
]]

local Loot = {
	Tables = {},
}

return table.freeze(Loot)
