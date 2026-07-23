--!strict
--[[
	Signal
	The smallest reusable event primitive: connect a listener, fire all
	listeners, disconnect. No wait / queue / priority — deliberately tiny (this
	is a primitive, not a framework). First consumer is the combat health system.

	Usage:
		local sig = Signal.new()
		local disconnect = sig:connect(function(x) print(x) end)
		sig:fire(42)
		disconnect()

	Location: ReplicatedStorage.Shared.Core.Signal
]]

local Signal = {}
Signal.__index = Signal

export type Signal = typeof(setmetatable(
	{} :: { _listeners: { (...any) -> () } },
	Signal
))

function Signal.new(): Signal
	return setmetatable({ _listeners = {} }, Signal)
end

-- Registers `callback`; returns a function that removes it when called.
function Signal.connect(self: Signal, callback: (...any) -> ()): () -> ()
	table.insert(self._listeners, callback)
	return function()
		local index = table.find(self._listeners, callback)
		if index then
			table.remove(self._listeners, index)
		end
	end
end

-- Invokes every listener with the given arguments. Iterates a copy so a
-- listener disconnecting (or connecting) during the fire is safe.
function Signal.fire(self: Signal, ...: any)
	for _, listener in table.clone(self._listeners) do
		listener(...)
	end
end

function Signal.disconnectAll(self: Signal)
	table.clear(self._listeners)
end

return Signal
