--!strict
--[[
	Logger
	Tiny scoped logging utility used by the framework and (later) by systems.

	Keeps log output consistent and greppable by prefixing every message with a
	scope, e.g. "[Server] Booted 9 modules". This is infrastructure, not gameplay.

	Usage:
		local Logger = require(ReplicatedStorage.Shared.Util.Logger)
		local log = Logger.new("PlayerService")
		log:info("ready")

	Location: ReplicatedStorage.Shared.Util.Logger
]]

local Logger = {}
Logger.__index = Logger

export type Logger = typeof(setmetatable({} :: { scope: string }, Logger))

function Logger.new(scope: string): Logger
	return setmetatable({ scope = scope }, Logger)
end

function Logger.info(self: Logger, message: string)
	print(("[%s] %s"):format(self.scope, message))
end

function Logger.warn(self: Logger, message: string)
	warn(("[%s] %s"):format(self.scope, message))
end

return Logger
