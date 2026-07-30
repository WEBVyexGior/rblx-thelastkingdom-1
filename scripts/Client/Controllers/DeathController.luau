--!strict
--[[
	DeathController
	The client half of the death system's feedback. It receives DeathEvents and shows
	them the SIMPLEST possible way (prints), and lets a player pick a choice with number
	keys. No UI, no camera work — the diegetic death parchment and spectate camera are
	later Tier 3 polish.

	Keys while downed: [1] Back to Lobby, [2] Revive, [3] Wait (only offered in a party).
	After a total wipe: [R] Play Again.

	Place: client (boots in both places; only the World server ever sends to it).
	Phase: Death System.
]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local DeathController = {}

DeathController.Name = "DeathController"

local downed = false
local canWait = false
local canPlayAgain = false

function DeathController.Init() end

function DeathController.Start()
	local deathEvent = Net.getEvent("DeathEvent")
	local requestChoice = Net.getEvent("RequestDeathChoice")
	local requestPlayAgain = Net.getEvent("RequestPlayAgain")

	deathEvent.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local kind = payload.kind
		if kind == "downed" then
			downed = true
			canWait = payload.canWait == true
			print(("[DEATH] You fell. Choose: [1] Lobby  [2] Revive (%s gold%s)%s"):format(
				tostring(payload.reviveCost),
				if payload.canAfford then "" else ", not enough",
				if canWait then "  [3] Wait for teammates" else ""
			))
		elseif kind == "revived" then
			downed = false
			print("[DEATH] Revived.")
		elseif kind == "waiting" then
			downed = false
			print("[DEATH] Waiting for teammates…")
		elseif kind == "leftRun" then
			downed = false
			print("[DEATH] Left the run.")
		elseif kind == "reviveDenied" then
			print("[DEATH] Revive denied: " .. tostring(payload.reason) .. ".")
		elseif kind == "wiped" then
			downed = false
			canPlayAgain = true
			print("[DEATH] The party has fallen. Press [R] to Play Again.")
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		local key = input.KeyCode
		if downed then
			if key == Enum.KeyCode.One then
				requestChoice:FireServer("Lobby")
			elseif key == Enum.KeyCode.Two then
				requestChoice:FireServer("Revive") -- server validates gold/cooldown
			elseif key == Enum.KeyCode.Three and canWait then
				requestChoice:FireServer("Wait")
			end
		elseif canPlayAgain and key == Enum.KeyCode.R then
			canPlayAgain = false
			requestPlayAgain:FireServer()
		end
	end)
end

return DeathController
