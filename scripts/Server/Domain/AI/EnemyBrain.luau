--!strict
--[[
	EnemyBrain (domain class)
	A clean, pure AI state machine for one enemy. It decides only the STATE from
	perceived distances — it never moves anything or deals damage (that actuation
	is EnemyAIService's job). Being pure (numbers in, state out) it is fully
	unit-testable and easy to extend: add a state and its transitions here.

	States (extensible):
		Idle   — at rest; acquires a target when one enters DetectionRadius
		Chase  — moving toward the target
		Attack — target within AttackRange
		Return — target lost / chased past LeashRadius; heading back to spawn
		Dead   — health depleted (terminal)

	Location: ServerScriptService.Server.Domain.AI.EnemyBrain
]]

local EnemyBrain = {}
EnemyBrain.__index = EnemyBrain

local STATES = {
	Idle = "Idle",
	Chase = "Chase",
	Attack = "Attack",
	Return = "Return",
	Dead = "Dead",
}

EnemyBrain.States = STATES

-- Tunable ranges (all from config, never hard-coded — see configs/Enemies AI).
export type Params = {
	DetectionRadius: number, -- acquire a target within this distance
	AttackRange: number, -- attack within this distance
	LeashRadius: number, -- give up (return) when the target is beyond this
	ArrivalRadius: number, -- "back home" when within this of spawn
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

	if state == STATES.Idle then
		if d ~= nil and d <= params.DetectionRadius then
			state = STATES.Chase
		end
	elseif state == STATES.Chase then
		if d == nil or d > params.LeashRadius then
			state = STATES.Return
		elseif d <= params.AttackRange then
			state = STATES.Attack
		end
	elseif state == STATES.Attack then
		if d == nil or d > params.LeashRadius then
			state = STATES.Return
		elseif d > params.AttackRange then
			state = STATES.Chase
		end
	elseif state == STATES.Return then
		if d ~= nil and d <= params.DetectionRadius then
			state = STATES.Chase -- re-aggro on the way home
		elseif p.distanceFromSpawn <= params.ArrivalRadius then
			state = STATES.Idle
		end
	end
	-- Dead is terminal (reached only via the isAlive check above).

	self.state = state
	return state
end

return EnemyBrain
