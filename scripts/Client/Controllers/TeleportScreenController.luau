--!strict
--[[
	TeleportScreenController
	Registers the game's own loading screen with Roblox so that every teleport —
	lobby to world and back again — is covered by our art instead of the default
	grey one.

	It must be registered BEFORE any teleport happens, so it is done once at boot
	rather than at the moment of departure.

	Runs in both places: the return trip out of the Forgotten Lands deserves the
	same screen as the trip in.

	Location: StarterPlayer.StarterPlayerScripts.Client.Controllers.TeleportScreenController
]]

local EngineTeleport = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = script:FindFirstAncestor("Client")
local TeleportScreen = require(Client.UI.TeleportScreen)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local TeleportScreenController = {}

TeleportScreenController.Name = "TeleportScreenController"

local log = Logger.new("TeleportScreenController")

function TeleportScreenController.Init() end

function TeleportScreenController.Start()
	local hub = Config.get("Hub")
	local copy = hub.Teleport
	local brand = hub.Brand

	local gui = TeleportScreen.build({
		Title = brand.Title,
		Developer = brand.Developer,
		Headline = copy.Headline,
		Line = copy.Line,
		Footer = copy.Footer,
	})

	local ok, err = pcall(function()
		EngineTeleport:SetTeleportGui(gui)
	end)
	if ok then
		log:info("ready")
	else
		log:warn("could not register the teleport screen: " .. tostring(err))
	end
end

return TeleportScreenController
