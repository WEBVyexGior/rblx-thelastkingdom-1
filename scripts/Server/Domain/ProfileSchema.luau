--!strict
--[[
	ProfileSchema (domain)
	The SHAPE of a persistent player profile plus a versioned default and migration.
	This is the "Save Architecture" data contract. The `version` field enables safe
	migrations as the schema evolves.

	v2 adds progression fields (`xp`, `level`) owned by the Progression/Reward systems.

	Location: ServerScriptService.Server.Domain.ProfileSchema
]]

export type Profile = {
	version: number,
	currency: number,
	xp: number,
	level: number,
	inventory: { [string]: any },
	upgrades: { [string]: any },
	stats: { [string]: any },
	unlockedLore: { [string]: boolean },
	achievements: { [string]: boolean },
}

local ProfileSchema = {}

ProfileSchema.VERSION = 2

-- Returns a fresh default profile for a brand-new player.
function ProfileSchema.default(): Profile
	return {
		version = ProfileSchema.VERSION,
		currency = 0,
		xp = 0,
		level = 1,
		inventory = {},
		upgrades = {},
		stats = {},
		unlockedLore = {},
		achievements = {},
	}
end

-- Brings an older profile up to VERSION. Idempotent and additive: fills any missing
-- field with its default so a v1 profile becomes a valid v2 profile.
function ProfileSchema.migrate(profile: Profile): Profile
	if (profile.version or 0) < 2 then
		profile.xp = profile.xp or 0
		profile.level = profile.level or 1
	end
	-- Backfill any container that a partial/old save might be missing.
	profile.currency = profile.currency or 0
	profile.inventory = profile.inventory or {}
	profile.upgrades = profile.upgrades or {}
	profile.stats = profile.stats or {}
	profile.unlockedLore = profile.unlockedLore or {}
	profile.achievements = profile.achievements or {}
	profile.version = ProfileSchema.VERSION
	return profile
end

return ProfileSchema
