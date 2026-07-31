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

local Players = game:GetService("Players")
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

-- The nearest Model ancestor that holds a Humanoid: a player's character, or an
-- NPC rig.
local function characterOf(instance: Instance): Model?
	local model = instance:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function isPlayerCharacter(model: Model): boolean
	if Players:GetPlayerFromCharacter(model) then
		return true
	end
	-- `player.Character` is assigned a moment after the model is parented, so a
	-- script arriving in that window would otherwise look ownerless. Falling back
	-- to the name closes the race — characters are named after their player.
	local named = Players:FindFirstChild(model.Name)
	return named ~= nil and named:IsA("Player")
end

local function handle(instance: Instance): boolean
	if not isCode(instance) then
		return false
	end

	-- Already on its way out. Checks here are deferred by a frame, which is long
	-- enough for something else — NpcService stripping Animate off an avatar, say
	-- — to have removed it first. Without this the guard warns about scripts the
	-- game itself just deleted, and reports them with no path because they no
	-- longer have a parent to name.
	if not instance.Parent then
		return false
	end

	local character = characterOf(instance)
	if character then
		-- Roblox puts its OWN scripts inside every character — Animate drives the
		-- walk and idle animations, Health drives regeneration. Deleting those
		-- breaks the player, and they come back on every single respawn.
		if isPlayerCharacter(character) then
			return false
		end
		-- An NPC rig is not automatically trustworthy, but silently gutting one
		-- would break it just as thoroughly. Report and leave it alone.
		log:warn(("script inside NPC rig (left in place): %s"):format(instance:GetFullName()))
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
