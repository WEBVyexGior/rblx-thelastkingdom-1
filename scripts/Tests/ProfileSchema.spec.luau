--!strict
--[[
	ProfileSchema.spec
	Validates the persistent profile contract: a fresh default is stamped with the
	current version, has zeroed currency and empty containers, and migrate() is a
	safe passthrough for an already-current profile.

	Location: TestService.Tests.ProfileSchema.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ProfileSchema = require(ServerScriptService.Server.Domain.ProfileSchema)

return function(t: any)
	t.test("a default profile carries the current version and empty containers", function()
		local p = ProfileSchema.default()
		assert(p.version == ProfileSchema.VERSION, "default should stamp the current schema version")
		assert(p.currency == 0, "default currency should be 0")
		for _, field in { "inventory", "upgrades", "stats", "unlockedLore", "achievements" } do
			local container = (p :: any)[field]
			assert(type(container) == "table", field .. " should be a table")
			assert(next(container) == nil, field .. " should start empty")
		end
	end)

	t.test("migrate is a no-op passthrough for a current profile", function()
		local p = ProfileSchema.default()
		assert(ProfileSchema.migrate(p) == p, "migrate should return the same profile at the current version")
	end)
end
