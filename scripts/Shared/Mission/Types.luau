--!strict
--[[
	Mission.Types
	Shared type definitions for the data-driven mission/objective system. These
	shapes are authored in `configs/Missions.luau` and `configs/Chapters.luau`,
	validated by `Server.Domain.Mission`, and driven at runtime by the World
	MissionRuntimeService.

	Location: ReplicatedStorage.Shared.Mission.Types
]]

-- Enemies (or NPCs) an objective spawns when it becomes active. The Wave System
-- will later replace this simple form with structured waves behind the same field.
export type EnemySpawn = {
	enemyId: string, -- key into configs/Enemies
	count: number,
	center: Vector3,
	spread: number?, -- studs between spawned units (default 0)
}

-- One objective in a mission. `type` selects the tracker; the other fields are the
-- parameters that tracker reads (all optional — each type uses what it needs).
export type ObjectiveDef = {
	id: string,
	type: string, -- Mission.Enums.ObjectiveType
	description: string, -- placeholder text shown when the objective is active
	completionText: string?, -- optional placeholder text on completion (e.g. lore)
	target: number?, -- Kill = count; Survive/Defend = seconds; default 1
	position: Vector3?, -- Reach / Escort destination / Interact / Defend spot
	radius: number?, -- Reach / Interact / arrival radius
	spawns: { EnemySpawn }?, -- units to spawn when this objective activates (Kill/Defend/Escort)
	encounterId: string?, -- Clear objective: the encounter (configs/Encounters) to run
	eliteEnemyId: string?, -- Clear objective: elite substitute for scaled-in extra units
	reward: RewardDef?, -- optional reward granted when THIS objective completes
	timeLimit: number?, -- optional fail timer (seconds)
}

-- Symbolic reward for now; real granting plugs into Economy/persistence later.
export type RewardDef = {
	summary: string, -- placeholder text announced on completion
	currency: number?,
	xp: number?,
}

export type MissionDef = {
	id: string,
	displayName: string,
	region: string,
	intro: string?, -- narrative on mission start
	outro: string?, -- narrative on mission completion
	reward: RewardDef?,
	objectives: { ObjectiveDef },
}

export type ChapterDef = {
	id: string,
	title: string,
	missions: { string }, -- ordered mission ids
}

-- Server -> client update for the (no-UI) mission feed.
export type MissionEventPayload = {
	kind: string, -- "missionStart" | "objectiveActive" | "objectiveProgress"
	-- | "objectiveComplete" | "missionComplete" | "missionFailed" | "narrative"
	missionId: string?,
	objectiveId: string?,
	text: string?,
	current: number?,
	target: number?,
}

return {}
