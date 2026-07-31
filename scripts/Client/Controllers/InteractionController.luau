--!strict
--[[
	InteractionController
	Routes the lobby's interaction points to the screen each one opens.

	The server says only "this player stepped into `storyteller`". Which panel
	that means is decided here, from the same config the server read — so adding
	the blacksmith later is a config entry plus one line in the router, not a new
	controller.

	Hub only: the same Client tree boots in both places.

	Location: StarterPlayer.StarterPlayerScripts.Client.Controllers.InteractionController
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = script:FindFirstAncestor("Client")
local DialogueUI = require(Client.UI.DialogueUI)
local BlacksmithUI = require(Client.UI.BlacksmithUI)
local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local InteractionController = {}

InteractionController.Name = "InteractionController"

local log = Logger.new("InteractionController")

local byId: { [string]: any } = {}
local activeId: string? = nil

local forgeState: RemoteEvent

local function openFor(point: any)
	if point.Screen == "Dialogue" and point.Dialogue then
		DialogueUI.open(point.Dialogue)
	elseif point.Screen == "Blacksmith" then
		-- Ask for the stock on opening rather than holding a stale copy: gold
		-- changes every time a run pays out.
		forgeState:FireServer()
		BlacksmithUI.open()
	else
		log:warn(("no screen for '%s' (%s)"):format(tostring(point.Id), tostring(point.Screen)))
	end
end

local function closeFor(point: any)
	if point.Screen == "Dialogue" then
		DialogueUI.close()
	elseif point.Screen == "Blacksmith" then
		BlacksmithUI.close()
	end
end

function InteractionController.Init()
	for _, point in Config.get("Interactions").Points do
		byId[point.Id] = point
	end
end

function InteractionController.Start()
	if game.PlaceId ~= 0 and game.PlaceId ~= Constants.PlaceIds.KingdomHub then
		return
	end

	DialogueUI.mount()

	forgeState = Net.getEvent("RequestForgeState")
	local forgeUpgrade = Net.getEvent("RequestForgeUpgrade")
	local forgeEvent = Net.getEvent("ForgeEvent")

	BlacksmithUI.mount({
		onUpgrade = function(weaponId)
			forgeUpgrade:FireServer(weaponId)
		end,
	})

	forgeEvent.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.kind == "state" then
			BlacksmithUI.setState(payload)
		elseif payload.kind == "upgraded" then
			BlacksmithUI.setNotice(("%s is now +%d — %d damage."):format(
				tostring(payload.name),
				tonumber(payload.level) or 0,
				tonumber(payload.damage) or 0
			))
		elseif payload.kind == "denied" then
			local reason = payload.reason
			BlacksmithUI.setNotice(
				if reason == "gold"
					then "Not enough gold."
					elseif reason == "maxed" then "That weapon is already fully forged."
					else "You are not ready to carry that yet."
			)
		end
	end)

	Net.getEvent("InteractionEvent").OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local point = byId[payload.id]
		if not point then
			return
		end

		if payload.kind == "entered" then
			activeId = payload.id
			openFor(point)
		elseif payload.kind == "left" and activeId == payload.id then
			activeId = nil
			closeFor(point)
		end
	end)

	log:info("ready")
end

return InteractionController
