--!strict
--[[
	DataStoreStore (domain)
	A REAL persistence backend implementing the same `Store` interface as InMemoryStore
	(`get(key)` / `set(key, value)`), backed by Roblox DataStoreService. Injected into
	SaveService via `setStore` when DataStores are available; otherwise the in-memory
	mock is kept (e.g. Studio without API access), so gameplay always works.

	Robustness: every call is pcall-wrapped with a few retries. Full session locking
	(cross-place duplication protection via UpdateAsync + a lock token) is deferred and
	tracked as tech debt; this gives working durable saves now.

	Location: ServerScriptService.Server.Domain.DataStoreStore
]]

local DataStoreService = game:GetService("DataStoreService")

local RETRIES = 3
local RETRY_DELAY = 1

local DataStoreStore = {}
DataStoreStore.__index = DataStoreStore

export type DataStoreStore = typeof(setmetatable(
	{} :: {
		store: GlobalDataStore,
	},
	DataStoreStore
))

function DataStoreStore.new(name: string): DataStoreStore
	return setmetatable({ store = DataStoreService:GetDataStore(name) }, DataStoreStore)
end

-- Retries `fn` up to RETRIES times; returns (ok, resultOrError).
local function withRetry(fn: () -> any): (boolean, any)
	local ok, result
	for attempt = 1, RETRIES do
		ok, result = pcall(fn)
		if ok then
			return true, result
		end
		if attempt < RETRIES then
			task.wait(RETRY_DELAY)
		end
	end
	return false, result
end

function DataStoreStore.get(self: DataStoreStore, key: string): any
	local ok, result = withRetry(function()
		return self.store:GetAsync(key)
	end)
	if not ok then
		warn(("[DataStoreStore] get('%s') failed: %s"):format(key, tostring(result)))
		return nil
	end
	return result
end

function DataStoreStore.set(self: DataStoreStore, key: string, value: any)
	local ok, err = withRetry(function()
		self.store:SetAsync(key, value)
		return true
	end)
	if not ok then
		warn(("[DataStoreStore] set('%s') failed: %s"):format(key, tostring(err)))
	end
end

-- True if DataStores are usable here (published place, or Studio with API access on).
-- Does one guarded probe so callers can pick the backend at boot.
function DataStoreStore.isAvailable(): boolean
	local ok = pcall(function()
		DataStoreService:GetDataStore("__tlk_probe"):GetAsync("__ping")
	end)
	return ok
end

return DataStoreStore
