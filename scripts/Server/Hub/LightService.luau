--!strict
--[[
	LightService
	Tunes every light in the camp from ONE place.

	The lamps, torches, campfires and forge are hand-placed geometry in Studio —
	that is design work and stays design work. What does NOT belong there is
	tuning each light individually: with ninety-odd lights down the lanes,
	changing the mood means editing every one of them by hand and getting them
	subtly out of step with each other.

	So the lights are treated as DATA. On boot this walks the lobby, works out
	which GROUP each light belongs to from the names of the models around it, and
	stamps that group's values onto it. Change a number in
	`configs/Hub.luau -> Lights` and every light of that kind changes together.

	Groups exist because one setting for all of them would flatten the scene: a
	campfire, a smelter and a lane lantern are not the same light.

	It also watches for lights added later, so a lamp copied into the lobby while
	the server is up is tuned like the rest. Lights the game creates for itself
	(the boarding markers) are left alone.

	Place: Kingdom Hub only. Phase: Hub Systems.

	Location: ServerScriptService.Server.Hub.LightService
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local LightService = {}

LightService.Name = "LightService"

local log = Logger.new("LightService")

local cfg: any = nil
local lobbyFolder: string = "Lobby"

local function isLight(instance: Instance): boolean
	return instance:IsA("PointLight") or instance:IsA("SpotLight") or instance:IsA("SurfaceLight")
end

local function ours(light: Instance): boolean
	for _, folderName in cfg.IgnoreFolders do
		if light:FindFirstAncestor(folderName) then
			return true
		end
	end
	return false
end

-- Which group a light belongs to, decided by the names of everything it sits
-- inside up to the lobby root. First match wins; nil means "use the default".
local function groupFor(light: Instance): any
	local names: { string } = {}
	local node: Instance? = light
	while node and node.Name ~= lobbyFolder do
		table.insert(names, string.lower(node.Name))
		node = node.Parent
	end

	for _, group in cfg.Groups do
		for _, needle in group.Match do
			local lowered = string.lower(needle)
			for _, name in names do
				if string.find(name, lowered, 1, true) then
					return group
				end
			end
		end
	end
	return nil
end

local function tune(light: Instance): string
	local group = groupFor(light)
	local spec = group or cfg.Default
	local target = light :: any

	target.Brightness = spec.Brightness
	target.Color = spec.Color
	target.Shadows = spec.Shadows
	if light:IsA("PointLight") or light:IsA("SpotLight") then
		target.Range = spec.Range
	end
	if light:IsA("SpotLight") then
		target.Angle = cfg.SpotAngle
	end

	return if group then group.Name else "Default"
end

function LightService.Init()
	local hub = Config.get("Hub")
	cfg = hub.Lights
	lobbyFolder = hub.Train.LobbyFolder
end

function LightService.Start()
	if not cfg.Enabled then
		log:info("disabled by config")
		return
	end

	local lobby = workspace:FindFirstChild(lobbyFolder)
	if not lobby then
		log:warn(("workspace.%s not found — no lights tuned"):format(lobbyFolder))
		return
	end

	local counts: { [string]: number } = {}
	local total = 0
	for _, descendant in lobby:GetDescendants() do
		if isLight(descendant) and not ours(descendant) then
			local groupName = tune(descendant)
			counts[groupName] = (counts[groupName] or 0) + 1
			total += 1
		end
	end

	-- A light added after boot (copied in while testing) is tuned like the rest.
	lobby.DescendantAdded:Connect(function(descendant)
		if isLight(descendant) and not ours(descendant) then
			tune(descendant)
		end
	end)

	local summary: { string } = {}
	for groupName, count in counts do
		table.insert(summary, ("%s %d"):format(groupName, count))
	end
	table.sort(summary)
	log:info(("tuned %d light(s) — %s"):format(total, table.concat(summary, ", ")))
end

return LightService
