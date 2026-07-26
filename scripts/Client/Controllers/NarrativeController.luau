--!strict
--[[
	NarrativeController
	The client half of the Chapter 1 vertical slice's feedback. It receives the
	slice's placeholder narrative beats (intro/lore/objective/reward/end) from the
	server and shows them the SIMPLEST possible way — a print to the Output.

	No UI, no VFX: DEV/TEST feedback only, per the slice's "no polish" rule. The real
	diegetic UI is a later (Tier 3) phase.

	Place: client (boots in both places; only the World server ever sends to it).
	Phase: Chapter 1 integration slice.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local NarrativeController = {}

NarrativeController.Name = "NarrativeController"

function NarrativeController.Init() end

function NarrativeController.Start()
	local narrative = Net.getEvent("SliceNarrative")
	narrative.OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" and payload.text ~= nil then
			-- Simplest possible feedback (NO UI in this slice).
			print(("[STORY:%s] %s"):format(tostring(payload.kind), tostring(payload.text)))
		end
	end)
end

return NarrativeController
