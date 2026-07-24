--!strict
--[[
	CombatController
	The client half of the combat vertical slice. It turns player input into a
	melee-swing INTENT (never damage) and sends it to the server, and reacts to
	server CombatEvents. All validation and hit resolution live on the server.

	Feedback here is intentionally minimal (a log) — hit VFX, damage numbers, and
	the health HUD are a later phase and build on the same CombatEvent.

	Note: client Controllers boot in both places; melee only matters in the
	Forgotten Lands, where the server handles it. In the Hub the request has no
	server handler and is harmlessly ignored.

	Place: client. Phase: Combat (vertical slice).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local CombatController = {}

CombatController.Name = "CombatController"

local log = Logger.new("CombatController")

-- The local character's facing, if available (server re-validates it anyway).
local function currentAim(): Vector3?
	local character = Players.LocalPlayer.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.CFrame.LookVector
	end
	return nil
end

function CombatController.Init() end

function CombatController.Start()
	local requestAttack = Net.getEvent("RequestMeleeAttack")
	local combatEvent = Net.getEvent("CombatEvent")

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- Intent only; the server owns validation and hit resolution.
			requestAttack:FireServer(currentAim())
		end
	end)

	-- Minimal end-to-end confirmation of the loop (no VFX in this slice).
	combatEvent.OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" then
			log:info("combat event: " .. tostring(payload.kind))
		end
	end)

	log:info("ready")
end

return CombatController
