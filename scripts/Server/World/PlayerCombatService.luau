--!strict
--[[
	PlayerCombatService
	Makes players combatants in the Forgotten Lands: on each character spawn it
	registers a CombatEntity (faction Players) and binds its authoritative Health
	to the character's Humanoid; on death / respawn / leave it tears that down.

	It uses the generic CombatService — it never reaches into combat internals — so
	players and enemies register through exactly the same path.

	Place: Forgotten Lands ONLY (Server/World). Does not touch the shared
	PlayerService (which runs in both places). Phase: Combat (vertical slice).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local CombatService = require(script.Parent.CombatService)
local HumanoidAdapter = require(Server.Domain.Combat.HumanoidAdapter)
local Enums = require(ReplicatedStorage.Shared.Combat.Enums)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local PlayerCombatService = {}

PlayerCombatService.Name = "PlayerCombatService"

local log = Logger.new("PlayerCombatService")
local bindings: { [Player]: HumanoidAdapter.Binding } = {}

local function entityIdFor(player: Player): string
	return Constants.CombatId.PlayerPrefix .. player.UserId
end

local function unbind(player: Player)
	local binding = bindings[player]
	if binding then
		binding.disconnect()
		bindings[player] = nil
	end
	CombatService.unregisterEntity(entityIdFor(player))
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		log:warn("no Humanoid for " .. player.Name)
		return
	end

	-- Clear any binding left by a previous character before rebinding.
	unbind(player)

	local settings = Config.get("Settings")
	local entity = CombatService.registerEntity({
		id = entityIdFor(player),
		faction = Enums.Faction.Players,
		maxHealth = settings.Combat.PlayerMaxHealth, -- TEST placeholder
		model = character,
	})

	bindings[player] = HumanoidAdapter.bind(entity.health, humanoid)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
	player.CharacterRemoving:Connect(function()
		unbind(player)
	end)
end

function PlayerCombatService.Init() end

function PlayerCombatService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(unbind)
	log:info("ready")
end

return PlayerCombatService
