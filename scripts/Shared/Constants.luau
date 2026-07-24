--!strict
--[[
	Constants
	Game-wide constant values shared by client and server.

	This is the single source of truth for values that never change at runtime
	(place ids, folder names, tuning-independent identifiers). Balancing numbers
	do NOT belong here — those live in `configs/` and are read via `Shared.Config`.

	Location: ReplicatedStorage.Shared.Constants
	Status: skeleton — extended as systems come online.
]]

local Constants = {}

Constants.GAME_NAME = "The Last Kingdom"

-- Maximum party size supported by the experience (design pillar).
Constants.MAX_PARTY_SIZE = 8

-- Published PlaceIds for cross-place teleporting between the two games.
-- Filled in once each place is published in Roblox.
Constants.PlaceIds = table.freeze({
	KingdomHub = 0, -- TODO: set to the published Kingdom Hub PlaceId
	ForgottenLands = 0, -- TODO: set to the published Forgotten Lands PlaceId
})

-- Which of the two places a given server is running (detected at runtime).
Constants.PlaceRole = table.freeze({
	Hub = "Hub",
	World = "World",
	Unknown = "Unknown",
})

-- How often SaveService flushes cached profiles to the persistence backend.
Constants.AUTOSAVE_INTERVAL_SECONDS = 120

-- Stable id prefixes for combat entities (identifiers, not balancing).
Constants.CombatId = table.freeze({
	PlayerPrefix = "player_",
	EnemyPrefix = "enemy_",
})

return table.freeze(Constants)
