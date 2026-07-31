--!strict
--[[
	NpcService
	Builds the lobby's characters from real Roblox avatars.

	An interaction point can name a user id instead of shipping a model. On boot
	this asks Roblox for that user's avatar, stands it on the marker, and freezes
	it in place. Avatar appearance is PUBLIC data, so any user id works: the
	person does not need to be a collaborator on the place, or be told at all.

	That is what makes "put my friend's skin in the game" a one-line config change
	rather than a modelling job — set `Avatar.UserId` in `configs/Interactions`
	and place any part where he should stand.

	If the lookup fails (a bad id, Roblox having a bad day) the placeholder that
	was already there is simply left alone, so the lobby never ends up with a hole
	where a character should be.

	Place: Kingdom Hub only. Phase: Hub Systems.

	Location: ServerScriptService.Server.Hub.NpcService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local NpcService = {}

NpcService.Name = "NpcService"

local log = Logger.new("NpcService")

local cfg: any = nil
local lobbyFolder = "Lobby"

-- Roblox has both a yielding and a legacy form of this call, and which one is
-- present has changed over time. Try the modern one, fall back, and report
-- honestly if neither worked rather than leaving a silent gap.
local function buildAvatar(userId: number): Model?
	local ok, result = pcall(function()
		return (Players :: any):CreateHumanoidModelFromUserIdAsync(userId)
	end)
	if not ok or typeof(result) ~= "Instance" then
		ok, result = pcall(function()
			return (Players :: any):CreateHumanoidModelFromUserId(userId)
		end)
	end
	if ok and typeof(result) == "Instance" and result:IsA("Model") then
		return result
	end
	log:warn(("could not load the avatar for user %d: %s"):format(userId, tostring(result)))
	return nil
end

-- A lobby character is scenery: it must not walk, fall, be pushed, or advertise
-- a health bar over its head.
local function freeze(model: Model)
	-- A statue needs neither an animator nor a heartbeat. Roblox ships Animate
	-- and Health inside every avatar it builds; on a frozen NPC they only burn
	-- cycles and confuse anything auditing scripts in the Workspace.
	for _, name in { "Animate", "Health" } do
		local script_ = model:FindFirstChild(name)
		if script_ and (script_:IsA("BaseScript") or script_:IsA("ModuleScript")) then
			script_:Destroy()
		end
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.NameDisplayDistance = 0
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end
end

local function place(point: any, anchor: Instance): boolean
	local avatar = buildAvatar(point.Avatar.UserId)
	if not avatar then
		return false
	end

	local pivot: CFrame
	if anchor:IsA("Model") then
		pivot = anchor:GetPivot()
	elseif anchor:IsA("BasePart") then
		pivot = anchor.CFrame
	else
		avatar:Destroy()
		return false
	end

	avatar.Name = point.Name .. "Avatar"
	avatar.Parent = anchor.Parent

	--[[
		Stand him ON the ground, not IN it.

		A character's pivot sits at its middle (the HumanoidRootPart), so pivoting
		straight to the marker's position buries everything below the waist — which
		is exactly what happened: a head poking out of the terrain.

		So: find the real ground with a downward cast, then work out how far this
		particular model's pivot sits above its own feet and lift it by that much.
		Measuring the offset rather than assuming it keeps this correct for R6 and
		R15 alike, and for whatever hats and accessories the avatar is wearing.
	]]
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { avatar, anchor }

	local hit = workspace:Raycast(pivot.Position + Vector3.new(0, 60, 0), Vector3.new(0, -300, 0), params)
	local groundY = if hit then hit.Position.Y else pivot.Position.Y

	local boxCFrame, boxSize = avatar:GetBoundingBox()
	local footOffset = avatar:GetPivot().Position.Y - (boxCFrame.Position.Y - (boxSize.Y / 2))

	avatar:PivotTo(
		CFrame.new(pivot.Position.X, groundY + footOffset, pivot.Position.Z)
			* CFrame.Angles(0, math.rad(point.Avatar.FaceAngle or 0), 0)
	)
	freeze(avatar)

	-- The placeholder stays (the interaction ring is drawn from it) but stops
	-- being seen.
	if anchor:IsA("BasePart") then
		anchor.Transparency = 1
		anchor.CanCollide = false
	end

	log:info(("%s is wearing user %d's avatar"):format(point.Name, point.Avatar.UserId))
	return true
end

function NpcService.Init()
	cfg = Config.get("Interactions")
	lobbyFolder = Config.get("Hub").Train.LobbyFolder
end

function NpcService.Start()
	local lobby = workspace:FindFirstChild(lobbyFolder)
	if not lobby then
		return
	end

	for _, point in cfg.Points do
		local avatarCfg = point.Avatar
		if not avatarCfg or (avatarCfg.UserId or 0) <= 0 then
			continue
		end

		local folder = lobby:FindFirstChild(point.Folder)
		local anchor = if folder then folder:FindFirstChild(point.Name) else nil
		if not anchor then
			log:warn(("no anchor for %s at %s.%s"):format(point.Id, point.Folder, point.Name))
			continue
		end

		-- Each avatar is fetched over the network; one slow lookup must not hold
		-- up the rest of the lobby.
		task.spawn(place, point, anchor)
	end

	log:info("ready")
end

return NpcService
