--!strict
--[[
	DataService
	In-memory authority for each player's loaded Profile during a session. It is
	the fast, always-available cache that gameplay reads and writes.

	It knows NOTHING about DataStores — SaveService loads into and saves out of
	this cache. Splitting runtime access from storage keeps both simple and
	testable.

	Place: shared. Phase: Core Systems (persistence via SaveService).
]]

local DataService = {}

DataService.Name = "DataService"

-- Profile is typed `any` here on purpose: the cache does not care about the
-- shape; ProfileSchema (Domain) owns the shape. Keeps DataService decoupled.
local profiles: { [Player]: any } = {}

function DataService.set(player: Player, profile: any)
	profiles[player] = profile
end

function DataService.get(player: Player): any
	return profiles[player]
end

function DataService.clear(player: Player)
	profiles[player] = nil
end

function DataService.Init() end

function DataService.Start() end

return DataService
