--!strict
--[[
	Config
	Typed accessor for the data-driven balancing configs synced from `configs/`
	into ReplicatedStorage.Config.

	Gameplay code NEVER requires config ModuleScripts directly — it goes through
	this accessor. That keeps a single choke point: caching, validation, and any
	future schema changes live here instead of being scattered across systems.

	Usage:
		local Config = require(ReplicatedStorage.Shared.Config)
		local enemies = Config.get("Enemies")

	Location: ReplicatedStorage.Shared.Config
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local configRoot = ReplicatedStorage:WaitForChild("Config")

local Config = {}
local cache: { [string]: any } = {}

-- Returns the config table for `name` (e.g. "Enemies", "Economy"). Cached after
-- first access. Errors clearly if the config does not exist.
function Config.get(name: string): any
	local cached = cache[name]
	if cached ~= nil then
		return cached
	end

	local module = configRoot:FindFirstChild(name)
	assert(module and module:IsA("ModuleScript"), "Unknown config: " .. name)

	local value = require(module)
	cache[name] = value
	return value
end

return Config
