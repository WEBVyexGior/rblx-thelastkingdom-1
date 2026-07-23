--!strict
--[[
	InMemoryStore (domain)
	A mock persistence backend implementing the store interface SaveService uses:
	`get(key)` / `set(key, value)`. It keeps everything in a table for the current
	server only — NOTHING is written to real DataStores in Phase 2.

	A real DataStore-backed store will implement the same `Store` interface and be
	injected via `SaveService.setStore(...)`, so no other code changes when real
	persistence lands.

	Location: ServerScriptService.Server.Domain.InMemoryStore
]]

-- The interface any persistence backend must satisfy.
export type Store = {
	get: (self: any, key: string) -> any,
	set: (self: any, key: string, value: any) -> (),
}

local InMemoryStore = {}
InMemoryStore.__index = InMemoryStore

export type InMemoryStore = typeof(setmetatable(
	{} :: {
		data: { [string]: any },
	},
	InMemoryStore
))

function InMemoryStore.new(): InMemoryStore
	return setmetatable({ data = {} }, InMemoryStore)
end

function InMemoryStore.get(self: InMemoryStore, key: string): any
	return self.data[key]
end

function InMemoryStore.set(self: InMemoryStore, key: string, value: any)
	self.data[key] = value
end

return InMemoryStore
