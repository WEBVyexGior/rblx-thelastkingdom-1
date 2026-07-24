--!strict
--[[
	HumanoidAdapter (domain)
	Binds a combat `Health` to a character's `Humanoid`, with the server `Health`
	as the source of truth: Health changes mirror onto the Humanoid, and a
	non-combat Humanoid death (fall / void) is reflected back into Health so the
	authoritative state stays consistent.

	Returns a `Binding` whose `disconnect()` tears the connections down.

	Location: ServerScriptService.Server.Domain.Combat.HumanoidAdapter
]]

local Health = require(script.Parent.Health)

local HumanoidAdapter = {}

export type Binding = {
	disconnect: () -> (),
}

function HumanoidAdapter.bind(health: Health.Health, humanoid: Humanoid): Binding
	humanoid.MaxHealth = health.max
	humanoid.Health = health.current

	-- (current, max) numbers from Health.Changed.
	local disconnectChanged = health.Changed:connect(function(current, max)
		humanoid.MaxHealth = max
		humanoid.Health = current
	end)

	local diedConnection = humanoid.Died:Connect(function()
		if not health:isDead() then
			health:damage(math.huge)
		end
	end)

	return {
		disconnect = function()
			disconnectChanged()
			diedConnection:Disconnect()
		end,
	}
end

return HumanoidAdapter
