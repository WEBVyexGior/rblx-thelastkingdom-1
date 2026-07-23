--!strict
--[[
	Loader
	Generic module loader that boots a set of singleton modules (Services on the
	server, Controllers on the client) through a two-phase lifecycle.

	Boot order:
		1. Require every ModuleScript found under the given root(s).
		2. Call `.Init()` on each (dependency wiring — no cross-module calls yet).
		3. Call `.Start()` on each (runtime begins — safe to talk to others).

	The two phases guarantee that when any module's `Start` runs, every other
	module has already finished `Init`. Errors in one module are isolated (pcall)
	so a single failure never takes down the whole boot.

	This module is shared so both the server and client bootstraps use the exact
	same, tested loading logic.

	Location: ReplicatedStorage.Shared.Framework.Loader
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Util.Logger)

type Module = { [string]: any }

local Loader = {}

-- Gathers every ModuleScript under the provided roots, sorted by name so boot
-- order is deterministic across sessions and machines.
local function collectModules(roots: { Instance }): { ModuleScript }
	local found: { ModuleScript } = {}
	for _, root in roots do
		for _, descendant in root:GetDescendants() do
			if descendant:IsA("ModuleScript") then
				table.insert(found, descendant)
			end
		end
	end
	table.sort(found, function(a, b)
		return a.Name < b.Name
	end)
	return found
end

-- Boots all modules found under `roots`. `context` is a label for logging
-- (e.g. "Server" or "Client").
function Loader.boot(roots: { Instance }, context: string)
	local log = Logger.new(context)
	local modules: { Module } = {}

	-- Phase 0: require.
	for _, moduleScript in collectModules(roots) do
		local ok, result = pcall(require, moduleScript)
		if ok then
			if type(result) == "table" then
				table.insert(modules, result)
			end
		else
			log:warn(("Failed to require '%s': %s"):format(moduleScript.Name, tostring(result)))
		end
	end

	-- Phase 1: Init.
	for _, module in modules do
		if type(module.Init) == "function" then
			local ok, err = pcall(module.Init)
			if not ok then
				log:warn(("Init failed for '%s': %s"):format(tostring(module.Name), tostring(err)))
			end
		end
	end

	-- Phase 2: Start.
	for _, module in modules do
		if type(module.Start) == "function" then
			local ok, err = pcall(module.Start)
			if not ok then
				log:warn(("Start failed for '%s': %s"):format(tostring(module.Name), tostring(err)))
			end
		end
	end

	log:info(("Booted %d module(s)"):format(#modules))
end

return Loader
