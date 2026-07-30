--!strict
--[[
	TrainController
	The client half of the departure train. It owns nothing: the server decides who
	is standing at the platform, who is aboard and when the train leaves. This
	controller mounts the DepartureUI, relays the player's two intents (call/join a
	party, leave it) and renders whatever state arrives.

	It only comes alive in the Kingdom Hub — the same Client tree boots in both
	places, so it checks the PlaceId and stands down in the Forgotten Lands.

	Place: client (Kingdom Hub only in practice). Phase: Hub Systems.

	Location: StarterPlayer.StarterPlayerScripts.Client.Controllers.TrainController
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = script:FindFirstAncestor("Client")
local DepartureUI = require(Client.UI.DepartureUI)
local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local log = Logger.new("TrainController")

local TrainController = {}

TrainController.Name = "TrainController"

local brand: any = nil

local boardRequest: RemoteEvent
local leaveRequest: RemoteEvent
local departRequest: RemoteEvent

-- Guards the "create a party" offer: it stands for a fixed window, then folds
-- away so an abandoned panel never sits on screen forever.
local windowToken = 0

local function closeWindow()
	windowToken += 1
end

local function startWindow(seconds: number)
	closeWindow()
	local token = windowToken
	task.spawn(function()
		local remaining = seconds
		while remaining > 0 and token == windowToken do
			DepartureUI.setWindow(remaining)
			task.wait(1)
			remaining -= 1
		end
		if token == windowToken then
			DepartureUI.setFace("hidden")
		end
	end)
end

function TrainController.Init()
	brand = Config.get("Hub").Brand
end

function TrainController.Start()
	-- Hub only. In the Forgotten Lands there is no platform to stand on.
	if game.PlaceId ~= 0 and game.PlaceId ~= Constants.PlaceIds.KingdomHub then
		log:info("standing down: not the Kingdom Hub")
		return
	end

	local trainEvent = Net.getEvent("TrainEvent")
	boardRequest = Net.getEvent("RequestTrainBoard")
	leaveRequest = Net.getEvent("RequestTrainLeave")
	departRequest = Net.getEvent("RequestTrainDepart")

	DepartureUI.mount({
		onCreate = function(size)
			closeWindow()
			boardRequest:FireServer(size)
		end,
		onJoin = function()
			closeWindow()
			boardRequest:FireServer()
		end,
		onLeave = function()
			leaveRequest:FireServer()
		end,
		onDepartNow = function()
			departRequest:FireServer()
		end,
	}, brand)

	trainEvent.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local kind = payload.kind

		if kind == "prompt" then
			local mode = payload.mode
			if mode == "create" then
				DepartureUI.setFace("create")
				startWindow(tonumber(payload.windowSeconds) or 20)
			elseif mode == "join" then
				closeWindow()
				DepartureUI.setFace("join")
			else
				-- "full": the billboard already says so; no dead panel.
				closeWindow()
				DepartureUI.setFace("hidden")
			end
		elseif kind == "aboard" then
			closeWindow()
			DepartureUI.setNotice(nil)
			DepartureUI.setFace("aboard")
		elseif kind == "left" or kind == "dismiss" or kind == "departing" then
			closeWindow()
			DepartureUI.setFace("hidden")
		elseif kind == "failed" then
			-- The teleport did not happen. Say so plainly: silence here reads as
			-- the game being broken.
			DepartureUI.setNotice(
				if payload.retrying
					then "The train could not leave. Trying again…"
					else "Departure failed. Please try again."
			)
			if not payload.retrying then
				DepartureUI.setFace("hidden")
			end
		elseif kind == "denied" then
			DepartureUI.setNotice("That wagon is full.")
		elseif kind == "status" then
			DepartureUI.setStatus(payload)
		end
	end)

	log:info("ready")
end

return TrainController
