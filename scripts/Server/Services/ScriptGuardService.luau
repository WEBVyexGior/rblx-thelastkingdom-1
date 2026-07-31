--!strict
--[[
	ScriptGuardService
	Keeps foreign code out of the game.

	Toolbox models are how this project gets its scenery, and toolbox models are
	how backdoors travel. A single sweep of the lobby in July 2026 turned up 502
	scripts hidden inside Mesh and Texture objects, several levels deep, under
	names like "CoreTextureSystem" and "cTextureManager" picked to be mistaken for
	engine internals. One of them called `require()` on a remote asset id — remote
	code execution on the server, blocked only because Roblox's newer script
	capability sandbox refused it.

	The rule that makes this safe to automate: NONE of this game's own code lives
	in Workspace. Every line is synced by Rojo into ServerScriptService,
	ReplicatedStorage and StarterPlayer, and the services only ever create parts,
	folders and lights. So a script in Workspace is, by definition, not ours.

	This sweeps Workspace at boot and watches it afterwards, so a model dropped in
	during a live session is cleaned too. Everything it finds is logged with its
	full path — silent removal would hide exactly the information you need when
	something legitimate stops working.

	Set `Settings.Security.GuardAction = "Warn"` to report without deleting.

	Place: shared — both places run it. Phase: Hub Systems.

	Location: ServerScriptService.Server.Services.ScriptGuardService
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local ScriptGuardService = {}

ScriptGuardService.Name = "ScriptGuardService"

local log = Logger.new("ScriptGuardService")

local enabled = false
local remove = true

local function isCode(instance: Instance): boolean
	-- BaseScript covers Script and LocalScript; ModuleScript is separate and is
	-- how the backdoors above stored their payloads.
	return instance:IsA("BaseScript") or instance:IsA("ModuleScript")
end

local function handle(instance: Instance): boolean
	if not isCode(instance) then
		return false
	end
	log:warn(("foreign %s in Workspace: %s"):format(instance.ClassName, instance:GetFullName()))
	if remove then
		instance:Destroy()
	end
	return true
end

function ScriptGuardService.Init()
	local security = Config.get("Settings").Security
	enabled = security.GuardWorkspaceScripts == true
	remove = security.GuardAction ~= "Warn"
end

function ScriptGuardService.Start()
	if not enabled then
		log:info("disabled by config")
		return
	end

	local found = 0
	for _, descendant in workspace:GetDescendants() do
		if handle(descendant) then
			found += 1
		end
	end

	workspace.DescendantAdded:Connect(function(descendant)
		-- Deferred: an instance is parented before its properties are set, and
		-- reading it in the same frame can catch it half-built.
		task.defer(handle, descendant)
	end)

	if found > 0 then
		log:warn(("%s %d foreign script(s) — check where those models came from"):format(
			if remove then "removed" else "found",
			found
		))
	else
		log:info("clean")
	end
end

return ScriptGuardService
