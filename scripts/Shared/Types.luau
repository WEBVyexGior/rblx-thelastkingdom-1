--!strict
--[[
	Types
	Shared Luau type definitions used across systems.

	Only cross-cutting types live here. Domain-specific types (Inventory, Combat,
	etc.) are added by their own systems in later phases and re-exported here only
	if more than one system needs them.

	Usage:
		local Types = require(ReplicatedStorage.Shared.Types)
		local function handle(id: Types.PlayerId) ... end

	Location: ReplicatedStorage.Shared.Types
	Status: skeleton.
]]

-- The lifecycle contract every Service (server) and Controller (client) follows.
-- Both hooks are optional; the framework Loader calls them if present.
export type Lifecycle = {
	Name: string?,
	Init: (() -> ())?,
	Start: (() -> ())?,
	[any]: any,
}

export type Service = Lifecycle
export type Controller = Lifecycle

-- Common primitive aliases (expanded per phase).
export type PlayerId = number
export type PartyId = string
export type MatchId = string
export type MissionId = string

-- A type-only module returns an empty table; consumers use `Types.<Name>`.
return {}
