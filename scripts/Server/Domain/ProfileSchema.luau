--!strict
--[[
	ProfileSchema (domain)
	The SHAPE of a persistent player profile plus a versioned default. This is the
	"Save Architecture" data contract — structure only, no gameplay values. The
	`version` field enables safe migrations as the schema evolves.

	Fields like inventory/upgrades are intentionally empty containers here; the
	systems that own them (Inventory, Progression) populate their contents later.

	Location: ServerScriptService.Server.Domain.ProfileSchema
]]

export type Profile = {
	version: number,
	currency: number,
	inventory: { [string]: any },
	upgrades: { [string]: any },
	stats: { [string]: any },
	unlockedLore: { [string]: boolean },
	achievements: { [string]: boolean },
}

local ProfileSchema = {}

ProfileSchema.VERSION = 1

-- Returns a fresh default profile for a brand-new player.
function ProfileSchema.default(): Profile
	return {
		version = ProfileSchema.VERSION,
		currency = 0,
		inventory = {},
		upgrades = {},
		stats = {},
		unlockedLore = {},
		achievements = {},
	}
end

-- Reserved migration hook: brings an older profile up to VERSION. No-op for now.
function ProfileSchema.migrate(profile: Profile): Profile
	-- Future: step-migrate based on profile.version.
	return profile
end

return ProfileSchema
