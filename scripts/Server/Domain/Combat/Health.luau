--!strict
--[[
	Health (domain class)
	The server-authoritative health model for one combatant. Pure logic (numbers
	+ signals) with no dependency on Humanoids or replication — a later adapter
	can mirror it to a Humanoid or replicate a snapshot. Source of truth for
	whether an entity is alive.

	Location: ServerScriptService.Server.Domain.Combat.Health
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Shared.Core.Signal)

local Health = {}
Health.__index = Health

export type Health = typeof(setmetatable(
	{} :: {
		current: number,
		max: number,
		dead: boolean,
		Changed: Signal.Signal, -- fires (current: number, max: number)
		Died: Signal.Signal, -- fires ()
	},
	Health
))

function Health.new(maxHealth: number): Health
	local capped = math.max(0, maxHealth)
	return setmetatable({
		current = capped,
		max = capped,
		dead = capped <= 0,
		Changed = Signal.new(),
		Died = Signal.new(),
	}, Health)
end

function Health.isDead(self: Health): boolean
	return self.dead
end

function Health.getPercent(self: Health): number
	if self.max <= 0 then
		return 0
	end
	return self.current / self.max
end

function Health.snapshot(self: Health): { current: number, max: number }
	return { current = self.current, max = self.max }
end

-- Removes up to `amount` (>= 0) health. Returns how much was actually removed
-- and whether THIS call killed the entity. No-op once dead.
function Health.damage(self: Health, amount: number): (number, boolean)
	if self.dead or amount <= 0 then
		return 0, false
	end
	local before = self.current
	self.current = math.max(0, self.current - amount)
	local removed = before - self.current
	self.Changed:fire(self.current, self.max)
	if self.current <= 0 then
		self.dead = true
		self.Died:fire()
		return removed, true
	end
	return removed, false
end

-- Restores up to `amount` (>= 0), clamped to max. Returns amount restored.
-- No-op while dead — revival is a separate concern (the death system).
function Health.heal(self: Health, amount: number): number
	if self.dead or amount <= 0 then
		return 0
	end
	local before = self.current
	self.current = math.min(self.max, self.current + amount)
	local restored = self.current - before
	if restored > 0 then
		self.Changed:fire(self.current, self.max)
	end
	return restored
end

-- Adjusts the maximum. `fill` refills to the new max (e.g. on a buff/level);
-- otherwise current is only clamped down if it now exceeds max.
function Health.setMax(self: Health, newMax: number, fill: boolean?)
	self.max = math.max(0, newMax)
	if fill then
		self.current = self.max
	else
		self.current = math.min(self.current, self.max)
	end
	self.Changed:fire(self.current, self.max)
end

return Health
