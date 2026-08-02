--!strict
--[[
	EnemyBrain (domain class)
	A clean, pure AI state machine for one enemy. It decides only the STATE from
	perceived distances — it never moves anything or deals damage (that actuation
	is EnemyAIService's job). Being pure (numbers in, state out) it is fully
	unit-testable and easy to extend: add a state and its transitions here.

	States (extensible):
		Idle       — at rest; acquires a target when one enters DetectionRadius
		Chase      — moving toward the target
		Attack     — target within AttackRange
		Reposition — target is INSIDE MinRange; backing off to shooting distance
		Return     — target lost / chased past LeashRadius; heading back to spawn
		Dead       — health depleted (terminal)

	Location: ServerScriptService.Server.Domain.AI.EnemyBrain
]]

local EnemyBrain = {}
EnemyBrain.__index = EnemyBrain

local STATES = {
	Idle = "Idle",
	Chase = "Chase",
	Attack = "Attack",
	Reposition = "Reposition",
	Return = "Return",
	Dead = "Dead",
}

EnemyBrain.States = STATES

--[[
	How far past MinRange an enemy must get before it stops backing away.

	Without this an archer sitting exactly on its MinRange flickers between
	Reposition and Attack every frame — stepping back, deciding it is far
	enough, stepping in, deciding it is too close. The player sees a shuffling
	twitch instead of an archer. One shared hysteresis band fixes it: retreat
	begins at MinRange and does not end until MinRange * 1.25.
]]
local BACKOFF_HYSTERESIS = 1.25

-- Tunable ranges (all from config, never hard-coded — see configs/Enemies AI).
export type Params = {
	DetectionRadius: number, -- acquire a target within this distance
	AttackRange: number, -- attack within this distance
	LeashRadius: number, -- give up (return) when the target is beyond this
	ArrivalRadius: number, -- "back home" when within this of spawn
	MinRange: number?, -- OPTIONAL: closer than this, back away instead of fighting
}

-- What the brain perceives this tick. Distances only — no world instances.
export type Perception = {
	isAlive: boolean,
	targetDistance: number?, -- to the nearest valid target; nil if none
	distanceFromSpawn: number,
	params: Params,
}

export type EnemyBrain = typeof(setmetatable(
	{} :: { state: string },
	EnemyBrain
))

function EnemyBrain.new(): EnemyBrain
	return setmetatable({ state = STATES.Idle }, EnemyBrain)
end

-- Pure transition. Returns (and stores) the next state.
function EnemyBrain.update(self: EnemyBrain, p: Perception): string
	if not p.isAlive then
		self.state = STATES.Dead
		return self.state
	end

	local d = p.targetDistance
	local params = p.params
	local state = self.state

	-- Is the target uncomfortably close for something that fights at range?
	-- Melee units have no MinRange, so this is always false for them and the
	-- Reposition branch never fires.
	local tooClose = params.MinRange ~= nil and d ~= nil and d < params.MinRange

	if state == STATES.Idle then
		if d ~= nil and d <= params.DetectionRadius then
			state = if tooClose then STATES.Reposition else STATES.Chase
		end
	elseif state == STATES.Chase then
		if d == nil or d > params.LeashRadius then
			state = STATES.Return
		elseif tooClose then
			state = STATES.Reposition
		elseif d <= params.AttackRange then
			state = STATES.Attack
		end
	elseif state == STATES.Attack then
		if d == nil or d > params.LeashRadius then
			state = STATES.Return
		elseif tooClose then
			state = STATES.Reposition
		elseif d > params.AttackRange then
			state = STATES.Chase
		end
	elseif state == STATES.Reposition then
		--[[
			Backing away. Note it keeps SHOOTING while it does — the actuator
			treats Reposition as a firing state — because an archer that stops
			attacking the moment you approach is one the player beats by simply
			walking forward, which is not a fight.

			It leaves only once past the hysteresis band, or if the target is
			gone or has been dragged out past the leash.
		]]
		if d == nil or d > params.LeashRadius then
			state = STATES.Return
		elseif params.MinRange == nil or d >= params.MinRange * BACKOFF_HYSTERESIS then
			state = if d <= params.AttackRange then STATES.Attack else STATES.Chase
		end
	elseif state == STATES.Return then
		if d ~= nil and d <= params.DetectionRadius then
			-- Re-aggro on the way home, and straight into a retreat if the
			-- thing that re-aggroed it is already on top of it.
			state = if tooClose then STATES.Reposition else STATES.Chase
		elseif p.distanceFromSpawn <= params.ArrivalRadius then
			state = STATES.Idle
		end
	end
	-- Dead is terminal (reached only via the isAlive check above).

	self.state = state
	return state
end

--[[
	Does this state mean "currently trying to hurt the target"?

	Reposition counts. The actuator asks this rather than comparing against
	`Attack` directly, so a retreating archer keeps loosing arrows over its
	shoulder and the caller does not have to know which states those are.
]]
function EnemyBrain.isAttacking(state: string): boolean
	return state == STATES.Attack or state == STATES.Reposition
end

return EnemyBrain
