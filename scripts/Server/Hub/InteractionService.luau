--!strict
--[[
	InteractionService
	The lobby's "walk up to it and something opens" system: the storyteller, the
	blacksmith, the merchant, a reward chest.

	One engine, many points. Each point is a row in `configs/Interactions.luau`
	naming an object in the lobby; this draws a glowing ring on the ground beneath
	it, watches who steps inside, and tells that player's client which screen to
	open. Adding the next NPC or chest is a config entry and a model — no script.

	Rings, not boxes: the wagons are containers you climb into, these are places
	you walk up to. The colour is the same gold, so the whole lobby teaches one
	lesson — gold light means "step here".

	Server-authoritative in the same way the train is: the server decides who is
	standing where. The client only renders what it is told.

	Place: Kingdom Hub only. Phase: Hub Systems.

	Location: ServerScriptService.Server.Hub.InteractionService
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local InteractionService = {}

InteractionService.Name = "InteractionService"

local log = Logger.new("InteractionService")

type Point = {
	id: string,
	screen: string,
	radius: number,
	origin: Vector3, -- ground centre of the ring
}

local cfg: any = nil
local markerCfg: any = nil
local lobbyFolder = "Lobby"

local points: { Point } = {}
local inside: { [Player]: string } = {}
local interactionEvent: RemoteEvent

--============================================================================
-- Marker
--============================================================================

-- A ring drawn from short straight pieces laid end to end. At forty segments the
-- eye reads a circle, and it costs nothing next to a mesh.
local function buildRing(parent: Instance, centre: Vector3, radius: number)
	local segments = markerCfg.Segments
	local step = (math.pi * 2) / segments
	-- Chord length between neighbours, plus a hair so the seams close.
	local length = (2 * radius * math.sin(step / 2)) + 0.05

	local parts: { Part } = {}
	for index = 1, segments do
		local angle = step * index
		local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)

		local piece = Instance.new("Part")
		piece.Name = "RingSegment" .. index
		piece.Anchored = true
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.Material = Enum.Material.Neon
		piece.Color = markerCfg.Color
		piece.Size = Vector3.new(markerCfg.Thickness, markerCfg.Height, length)
		-- Face each piece along the circle's tangent.
		piece.CFrame = CFrame.new(centre + offset) * CFrame.Angles(0, -angle, 0)
		piece.Parent = parent
		table.insert(parts, piece)
	end

	local light = Instance.new("PointLight")
	light.Color = markerCfg.Color
	light.Brightness = markerCfg.LightBrightness
	light.Range = markerCfg.LightRange
	light.Shadows = false
	light.Parent = parts[1]

	local info = TweenInfo.new(markerCfg.PulseSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	for _, piece in parts do
		piece.Transparency = 0.55
		TweenService:Create(piece, info, { Transparency = 0.1 }):Play()
	end
	TweenService:Create(light, info, { Brightness = markerCfg.LightBrightness * 2 }):Play()
end

--============================================================================
-- Resolution
--============================================================================

-- Where an interaction object actually stands, and what the ground under it is.
local function groundUnder(target: Instance, ignore: Instance): Vector3?
	local pivot: CFrame
	local height = 0
	if target:IsA("Model") then
		local boxCFrame, boxSize = target:GetBoundingBox()
		pivot = boxCFrame
		height = boxSize.Y / 2
	elseif target:IsA("BasePart") then
		pivot = target.CFrame
		height = target.Size.Y / 2
	else
		return nil
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { target, ignore }
	local origin = pivot.Position - Vector3.new(0, height - 0.5, 0)
	local hit = workspace:Raycast(origin, Vector3.new(0, -200, 0), params)

	return if hit then hit.Position + Vector3.new(0, 0.05, 0) else Vector3.new(pivot.X, origin.Y, pivot.Z)
end

local function resolve(): boolean
	local lobby = workspace:FindFirstChild(lobbyFolder)
	if not lobby then
		log:warn(("workspace.%s not found — interactions disabled"):format(lobbyFolder))
		return false
	end

	local runtime = Instance.new("Folder")
	runtime.Name = "InteractionRuntime"
	runtime.Parent = lobby:FindFirstChild("Invisible") or workspace

	local missing: { string } = {}
	for _, point in cfg.Points do
		local folder = lobby:FindFirstChild(point.Folder)
		local target = if folder then folder:FindFirstChild(point.Name) else nil
		if not target then
			table.insert(missing, ("%s.%s"):format(point.Folder, point.Name))
			continue
		end

		local centre = groundUnder(target, runtime)
		if not centre then
			table.insert(missing, ("%s (not a model or part)"):format(point.Name))
			continue
		end

		local container = Instance.new("Folder")
		container.Name = point.Id
		container.Parent = runtime
		buildRing(container, centre, point.Radius)

		table.insert(points, {
			id = point.Id,
			screen = point.Screen,
			radius = point.Radius,
			origin = centre,
		})
	end

	if #missing > 0 then
		-- Not an error: the models are placed by hand, and a point simply waits
		-- until its model exists.
		log:warn("waiting for: " .. table.concat(missing, ", "))
	end
	log:info(("%d of %d point(s) live"):format(#points, #cfg.Points))
	return #points > 0
end

--============================================================================
-- Presence
--============================================================================

local function pointAt(player: Player): Point?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil
	end

	for _, point in points do
		-- Horizontal distance only: standing on a crate beside the chest still
		-- counts, and the ring is a footprint rather than a sphere.
		local offset = root.Position - point.origin
		if (Vector2.new(offset.X, offset.Z)).Magnitude <= point.radius then
			return point
		end
	end
	return nil
end

local function poll()
	for _, player in Players:GetPlayers() do
		local point = pointAt(player)
		local currentId = if point then point.id else nil
		if currentId ~= inside[player] then
			if inside[player] then
				interactionEvent:FireClient(player, { kind = "left", id = inside[player] })
			end
			inside[player] = currentId
			if point then
				interactionEvent:FireClient(player, {
					kind = "entered",
					id = point.id,
					screen = point.screen,
				})
			end
		end
	end
end

--============================================================================
-- Lifecycle
--============================================================================

function InteractionService.Init()
	cfg = Config.get("Interactions")
	markerCfg = cfg.Marker
	lobbyFolder = Config.get("Hub").Train.LobbyFolder
end

function InteractionService.Start()
	interactionEvent = Net.getEvent("InteractionEvent")

	if not resolve() then
		return
	end

	Players.PlayerRemoving:Connect(function(player)
		inside[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(cfg.PollSeconds)
			local ok, err = pcall(poll)
			if not ok then
				log:warn("poll failed: " .. tostring(err))
			end
		end
	end)

	log:info("ready")
end

return InteractionService
