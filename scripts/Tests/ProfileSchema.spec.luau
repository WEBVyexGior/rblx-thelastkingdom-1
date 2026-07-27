--!strict
--[[
	ProfileSchema.spec
	Validates the persistent profile contract: a fresh default is stamped with the
	current version, zeroed currency/xp/level and empty containers; migrate() is
	idempotent for a current profile and upgrades a v1 profile to v2.

	Location: TestService.Tests.ProfileSchema.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ProfileSchema = require(ServerScriptService.Server.Domain.ProfileSchema)

return function(t: any)
	t.test("a default profile has the current version, zeroed currency/xp/level, empty containers", function()
		local p = ProfileSchema.default()
		assert(p.version == ProfileSchema.VERSION, "default should stamp the current schema version")
		assert(p.currency == 0, "default currency should be 0")
		assert(p.xp == 0, "default xp should be 0")
		assert(p.level == 1, "default level should be 1")
		for _, field in { "inventory", "upgrades", "stats", "unlockedLore", "achievements" } do
			local container = (p :: any)[field]
			assert(type(container) == "table", field .. " should be a table")
			assert(next(container) == nil, field .. " should start empty")
		end
	end)

	t.test("migrate is idempotent for a current profile", function()
		local p = ProfileSchema.default()
		local migrated = ProfileSchema.migrate(p)
		assert(migrated == p, "migrate returns the same profile")
		assert(migrated.version == ProfileSchema.VERSION, "stays at the current version")
	end)

	t.test("migrate upgrades a v1 profile (no xp/level) to v2, preserving data", function()
		local old: any = {
			version = 1,
			currency = 42,
			inventory = {},
			upgrades = {},
			stats = {},
			unlockedLore = {},
			achievements = {},
		}
		local migrated = ProfileSchema.migrate(old)
		assert(migrated.version == ProfileSchema.VERSION, "bumped to the current version")
		assert(migrated.xp == 0, "xp backfilled to 0")
		assert(migrated.level == 1, "level backfilled to 1")
		assert(migrated.currency == 42, "existing data preserved")
	end)
end
