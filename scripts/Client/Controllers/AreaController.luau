--!strict
--[[
	AreaController
	The client half of the area system: listens for AreaEvent and drives the
	corner HUD.

	It stands down in the Kingdom Hub. The controller folder boots in BOTH
	places, and only the Forgotten Lands server ever sends an AreaEvent — but a
	HUD that says "AREA 1" while the player is standing on a station platform
	is worse than no HUD, so this checks rather than relying on the server
	staying silent.

	The gate itself lives on the server (Server/World/AreaService); this half
	owns nothing but the corner of the screen.

	Place: client (boots in both places; active only in the Forgotten Lands).
	Phase: Areas.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Constants = require(ReplicatedStorage.Shared.Constants)
local AreaHud = require(script.Parent.Parent.UI.AreaHud)

local AreaController = {}

AreaController.Name = "AreaController"

local hud: AreaHud.Handle? = nil

function AreaController.Init() end

function AreaController.Start()
	--[[
		Stand down anywhere that is definitely not the Forgotten Lands. The
		`~= 0` half matters: an unpublished local .rbxl reports PlaceId 0, and a
		controller that refused to run there would be dead for every Studio
		playtest — which is where all of them happen.
	]]
	if game.PlaceId ~= 0 and game.PlaceId ~= Constants.PlaceIds.ForgottenLands then
		return
	end

	hud = AreaHud.create()

	Net.getEvent("AreaEvent").OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or not hud then
			return
		end
		if payload.kind == "area" and typeof(payload.index) == "number" then
			-- The name and nothing else. `locked` and `subtitle` still arrive
			-- and are still ignored here: the gate says whether it is shut by
			-- being shut, which is a better teacher than a caption.
			hud.show(payload.index, tostring(payload.label))
		else
			-- "outside": the approach, the moat, the spawn pad.
			hud.hide()
		end
	end)
end

return AreaController
