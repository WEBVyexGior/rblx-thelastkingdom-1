--!strict
--[[
	WeaponVisualService
	Puts the weapon in the player's hand, and swings it.

	--------------------------------------------------------------------------
	WHY THIS EXISTS

	Combat has worked numerically since the vertical slice — twenty-five damage
	a swing, cooldowns, arcs, server-authoritative hit resolution. What it has
	never had is a weapon. The player punched the air and things died, which is
	unreadable: you cannot tell what your reach is, you cannot tell whether a
	swing came out, and you cannot tell you are armed at all.

	So this service builds the equipped weapon out of parts, welds it to the
	right hand, and animates the arm when the server resolves a swing.

	--------------------------------------------------------------------------
	NO ANIMATION ASSETS, ON PURPOSE

	A Roblox Animation needs an uploaded asset id and this project cannot upload
	one yet. So the swing is PROCEDURAL: the right shoulder's Motor6D C0 is
	driven through a wind-up, a strike and a recovery over about half a second.

	C0 rather than the Animator's Transform channel, for two reasons. C0 changes
	made on the server replicate to every client, which Transform does not; and
	because the joint's world CFrame is `Part0 * C0 * Transform * C1:Inverse()`,
	an offset written into C0 composes ON TOP of whatever idle or walk animation
	is playing rather than fighting it. The character keeps breathing while the
	arm swings.

	--------------------------------------------------------------------------
	IF THE SWORD SITS WRONG IN THE HAND

	`GRIP` below is the one number to change. Everything else is derived from
	it. There is no way to be sure of a grip offset without looking at it, so it
	is a single named constant instead of arithmetic spread across the file.

	Place: Forgotten Lands ONLY (Server/World). Phase: Combat.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local EquipmentService = require(Server.Services.EquipmentService)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local WeaponVisualService = {}

WeaponVisualService.Name = "WeaponVisualService"

local log = Logger.new("WeaponVisualService")

--==========================================================================
--[[
	How the hilt sits in the fist.

	Adjusted from a playtest: it was rotated a quarter turn about X and pointing
	down and forward, and the correction never survived a respawn because the
	sword is rebuilt from this constant every time a character loads. Baked in
	now, so it survives dying.

	If it is still wrong, this is the ONE value to change. Print the truth with:

	    local c = game.Players.<name>.Character
	    local a = c.RightHand.RightGripAttachment
	    print(a.CFrame:Inverse() * c.RightHand.WeaponGrip.C0)
]]
local GRIP = CFrame.new(0, -0.55, 0)

--[[
	And where it rides when it is put away: across the back, hilt up over the
	left shoulder, which is where a sword that big goes and where it is out of
	the way of everything the camera wants to see.
]]
local SHEATH = CFrame.new(-0.4, 0.2, 1.1) * CFrame.Angles(math.rad(15), 0, math.rad(-150))

--==========================================================================
-- The swing, as three poses and the time between them.
--
-- Angles are applied to the right shoulder in TORSO space. They were written
-- for a horizontal slash rather than an overhead chop because a slash reads
-- clearly from any camera angle and does not clip through the character's own
-- head at the top of the arc.
--==========================================================================
local NEUTRAL = CFrame.new()
local WIND_UP = CFrame.Angles(math.rad(-25), math.rad(-55), math.rad(-20))
local STRIKE = CFrame.Angles(math.rad(-75), math.rad(45), math.rad(10))

local T_WIND = 0.13 -- back
local T_STRIKE = 0.12 -- through
local T_RECOVER = 0.22 -- and down

local PALETTE = {
	steel = Color3.fromRGB(168, 176, 186),
	steelDark = Color3.fromRGB(104, 112, 124),
	edge = Color3.fromRGB(206, 214, 224),
	guard = Color3.fromRGB(92, 84, 66),
	grip = Color3.fromRGB(58, 40, 28),
	pommel = Color3.fromRGB(112, 96, 62),
}

--==========================================================================
local swinging: { [Player]: number } = {} -- Player -> animation token
local drawn: { [Player]: boolean } = {} -- is the weapon in hand, or on the back

--[[
	The shoulder's REST pose, remembered the first time each joint is seen.

	Reading `joint.C0` at the start of every swing looks equivalent and is not:
	interrupt a swing half way and the next one captures a half-raised arm as
	its home, and the one after that captures a worse one. Within a dozen
	swings the arm is somewhere behind the character's head and never comes
	down. A fresh character has a fresh Motor6D, so the first read is always
	the true rest pose.

	Weak keys, so a dead character's joints do not sit in here for the session.
]]
local restPose: { [Motor6D]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

local function homeOf(joint: Motor6D): CFrame
	local cached = restPose[joint]
	if not cached then
		cached = joint.C0
		restPose[joint] = cached
	end
	return cached
end

--==========================================================================
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Everything in the sword is welded to the hilt, so moving the hilt moves the
-- weapon and nothing has to be positioned again at runtime.
local function weldTo(root: BasePart, piece: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = piece
	weld.Parent = piece
end

--==========================================================================
--[[
	The blade.

	Built along +Y out of the hilt, which is how a Roblox tool handle is
	oriented, so the same GRIP works whether this ends up welded by hand or
	handed to the engine as a Tool later.
]]
local function buildSword(): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "OldBlade"

	local hilt = part(model, "Hilt", Vector3.new(0.32, 1.5, 0.32), CFrame.new(), PALETTE.grip, Enum.Material.Fabric)
	model.PrimaryPart = hilt

	-- Leather binding: three turns, so the grip is not one smooth stick.
	for i = -1, 1 do
		local band = part(
			model,
			"Binding",
			Vector3.new(0.4, 0.16, 0.4),
			CFrame.new(0, i * 0.42, 0),
			PALETTE.guard,
			Enum.Material.Fabric
		)
		weldTo(hilt, band)
	end

	local pommel = part(model, "Pommel", Vector3.new(0.52, 0.4, 0.52), CFrame.new(0, -0.9, 0), PALETTE.pommel, Enum.Material.Metal)
	pommel.Shape = Enum.PartType.Ball
	weldTo(hilt, pommel)

	-- The crossguard, with a slight droop toward the blade.
	local guard = part(model, "Guard", Vector3.new(2.6, 0.26, 0.5), CFrame.new(0, 0.85, 0), PALETTE.guard, Enum.Material.Metal)
	weldTo(hilt, guard)
	for _, side in { -1, 1 } do
		local tip = part(
			model,
			"GuardTip",
			Vector3.new(0.5, 0.24, 0.44),
			CFrame.new(side * 1.4, 0.78, 0) * CFrame.Angles(0, 0, math.rad(side * 18)),
			PALETTE.guard,
			Enum.Material.Metal
		)
		weldTo(hilt, tip)
	end

	--------------------------------------------------------------------------
	-- Blade: a body, a bright edge either side, a fuller down the middle, and a
	-- point. Five parts, and the difference between a sword and a grey plank.
	--------------------------------------------------------------------------
	local blade = part(model, "Blade", Vector3.new(0.62, 4.6, 0.2), CFrame.new(0, 3.3, 0), PALETTE.steel, Enum.Material.Metal)
	weldTo(hilt, blade)

	local fuller = part(model, "Fuller", Vector3.new(0.2, 3.9, 0.24), CFrame.new(0, 3.2, 0), PALETTE.steelDark, Enum.Material.Metal)
	weldTo(hilt, fuller)

	for _, side in { -1, 1 } do
		local edge = part(
			model,
			"Edge",
			Vector3.new(0.12, 4.6, 0.14),
			CFrame.new(side * 0.28, 3.3, 0),
			PALETTE.edge,
			Enum.Material.Metal
		)
		weldTo(hilt, edge)
	end

	local point = part(model, "Point", Vector3.new(0.6, 0.9, 0.2), CFrame.new(0, 5.9, 0) * CFrame.Angles(0, 0, math.rad(45)), PALETTE.edge, Enum.Material.Metal)
	weldTo(hilt, point)

	--------------------------------------------------------------------------
	-- The trail. Two attachments along the edge and a Trail between them, off
	-- until the blade is actually moving — a sword that streaks while you stand
	-- still looks enchanted, and this one is meant to look old.
	--------------------------------------------------------------------------
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailStart"
	a0.Position = Vector3.new(0, 1.2, 0)
	a0.Parent = hilt

	local a1 = Instance.new("Attachment")
	a1.Name = "TrailEnd"
	a1.Position = Vector3.new(0, 5.9, 0)
	a1.Parent = hilt

	local trail = Instance.new("Trail")
	trail.Name = "Swing"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.16
	trail.MinLength = 0.1
	trail.LightEmission = 0.35
	trail.LightInfluence = 0
	trail.FaceCamera = false
	trail.Enabled = false
	trail.Color = ColorSequence.new(Color3.fromRGB(226, 232, 240), Color3.fromRGB(150, 160, 175))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Parent = hilt

	return model, hilt
end

--==========================================================================
-- Finding the joint. R15 keeps the shoulder inside RightUpperArm and R6 inside
-- Torso under a different name, and there is no reason for the rest of this
-- file to know which rig it got.
local function rightShoulder(character: Model): Motor6D?
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") and (d.Name == "RightShoulder" or d.Name == "Right Shoulder") then
			return d
		end
	end
	return nil
end

local function rightHand(character: Model): BasePart?
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	return if hand and hand:IsA("BasePart") then hand else nil
end

-- Where a sheathed weapon hangs. R15 has an UpperTorso; R6 calls it Torso.
local function back(character: Model): BasePart?
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	return if torso and torso:IsA("BasePart") then torso else nil
end

--==========================================================================
local function clearWeapon(character: Model)
	local old = character:FindFirstChild("OldBlade")
	if old then
		old:Destroy()
	end
end

--[[
	Builds and attaches whatever the player has equipped.

	Only one weapon exists so far, so the config is consulted for the NAME and
	the model is the one built above. When there is a second weapon this is
	where the switch goes; nothing else changes.
]]
--[[
	A hand-made model for this weapon, if one has been put in ServerStorage.

	PARTS ARE THE WRONG TOOL FOR A SWORD, and this is the door out of that. A
	castle is straight pieces — walls, beams, planks, rope turns — and building
	those out of primitives looks right because that is what they are. A blade
	is not: it has a taper, a fuller, a wrapped grip and a rounded pommel, and
	two hundred boxes approximating those still looks like two hundred boxes. A
	single MeshPart beats it and always will.

	So: drop ANYTHING at `ServerStorage.Models.Weapons.<weaponId>` — from the
	toolbox, from Blender, from anywhere. Nothing else changes: the same grip,
	the same swing, the same trail if it has one.

	IT TAKES WHAT IT IS GIVEN. The first version demanded a Model with a part
	called `Hilt`, so a perfectly good single-MeshPart sword was silently
	ignored and the built one kept turning up instead. A weapon arrives as one
	of three things and all three are now accepted:

	    Part / MeshPart   the whole sword IS the hilt
	    Tool              its Handle is the hilt, which is what a Handle is
	    Model             a part called Hilt, else its PrimaryPart, else the
	                      biggest part in it — because the biggest part of a
	                      sword is the blade, and a blade welded at its centre
	                      is a better guess than nothing at all
]]
local function biggestPart(root: Instance): BasePart?
	local best: BasePart? = nil
	local bestVolume = -1
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > bestVolume then
				best, bestVolume = d, v
			end
		end
	end
	return best
end

local function suppliedModel(weaponId: string): (Instance?, BasePart?)
	local models = ServerStorage:FindFirstChild("Models")
	local weapons = models and models:FindFirstChild("Weapons")
	local source = weapons and weapons:FindFirstChild(weaponId)
	if not source then
		return nil, nil
	end

	--[[
		A bare Part cannot be parented to the character and then moved as a
		unit, so it is wrapped in a Model. Everything downstream then has one
		shape to deal with instead of three.
	]]
	local clone: Instance
	local hilt: BasePart?

	if source:IsA("BasePart") then
		local wrapper = Instance.new("Model")
		local part = source:Clone()
		part.Parent = wrapper
		wrapper.PrimaryPart = part
		clone, hilt = wrapper, part
	elseif source:IsA("Tool") then
		local wrapper = source:Clone()
		hilt = wrapper:FindFirstChild("Handle") :: BasePart?
		if not hilt then
			hilt = biggestPart(wrapper)
		end
		-- A Tool is not a Model; re-house its parts so the character gets
		-- something it can hold rather than something it can equip.
		local model = Instance.new("Model")
		for _, child in wrapper:GetChildren() do
			child.Parent = model
		end
		wrapper:Destroy()
		model.PrimaryPart = if hilt and hilt:IsDescendantOf(model) then hilt else nil
		clone = model
	elseif source:IsA("Model") then
		clone = source:Clone()
		local found = (clone :: Model):FindFirstChild("Hilt") or (clone :: Model).PrimaryPart or biggestPart(clone)
		hilt = if found and found:IsA("BasePart") then found else nil
	else
		log:warn(("weapon '%s' is a %s — expected a Part, Tool or Model"):format(weaponId, source.ClassName))
		return nil, nil
	end

	if not hilt then
		clone:Destroy()
		log:warn(("weapon '%s' has no parts in it"):format(weaponId))
		return nil, nil
	end

	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			-- Nothing on a held weapon may collide, be queried, or weigh
			-- anything: it would push the player around, eat their own sword
			-- swing, and slow them down.
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d.Anchored = false
		elseif d:IsA("LuaSourceContainer") then
			--[[
				SCRIPTS COME OUT. A toolbox model is somebody else's code, and
				this one gets cloned into a live character on the SERVER on
				every spawn — the most privileged place it could possibly run.
				ScriptGuardService sweeps the Workspace and would never see a
				script sitting in ServerStorage waiting to be copied in.

				A weapon is geometry. It does not need a script, and one that
				has one is not getting it.
			]]
			log:warn(("stripped a %s from weapon model '%s'"):format(d.ClassName, weaponId))
			d:Destroy()
		end
	end

	return clone, hilt
end

local function attachWeapon(player: Player, character: Model)
	clearWeapon(character)

	local weaponId = EquipmentService.getEquippedWeaponId(player)
	if not weaponId then
		return
	end
	local def = Config.get("Weapons")[weaponId]
	if not def or def.Class ~= "Melee" then
		return
	end

	local hand = rightHand(character)
	if not hand then
		log:warn(("no right hand on %s's character"):format(player.Name))
		return
	end

	local model, hilt = suppliedModel(weaponId)
	if model and hilt then
		log:info(("using the supplied model for '%s'"):format(weaponId))
	else
		model, hilt = buildSword()
	end
	model.Name = "OldBlade"
	model.Parent = character

	local motor = Instance.new("Motor6D")
	motor.Name = "WeaponGrip"
	motor.Part1 = hilt
	motor.C1 = CFrame.new()
	motor.Parent = hand

	drawn[player] = true
	WeaponVisualService.setDrawn(player, drawn[player])

	log:info(("armed %s with %s"):format(player.Name, tostring(def.DisplayName or weaponId)))
end

--==========================================================================
--[[
	Moves the weapon between the hand and the back.

	One Motor6D, re-parented and re-based, rather than two welds or two models.
	The sword is the same instance either way, so nothing has to be rebuilt, the
	trail keeps its attachments, and there is no frame where the player has two
	swords or none.
]]
function WeaponVisualService.setDrawn(player: Player, wantDrawn: boolean)
	local character = player.Character
	if not character then
		return
	end
	local weapon = character:FindFirstChild("OldBlade")
	local hilt = weapon and weapon:FindFirstChild("Hilt")
	if not hilt or not hilt:IsA("BasePart") then
		return
	end

	local motor = character:FindFirstChild("WeaponGrip", true)
	if not motor or not motor:IsA("Motor6D") then
		return
	end

	if wantDrawn then
		local hand = rightHand(character)
		if not hand then
			return
		end
		-- The grip attachment if the rig has one (R15 does), else straight off
		-- the hand's own centre.
		local gripAt = hand:FindFirstChild("RightGripAttachment")
		local base = if gripAt and gripAt:IsA("Attachment") then gripAt.CFrame else CFrame.new(0, -0.9, 0)
		motor.Part0 = hand
		motor.C0 = base * GRIP
		motor.Parent = hand
	else
		local torso = back(character)
		if not torso then
			return
		end
		motor.Part0 = torso
		motor.C0 = SHEATH
		motor.Parent = torso
	end

	drawn[player] = wantDrawn
end

function WeaponVisualService.isDrawn(player: Player): boolean
	return drawn[player] == true
end

-- Draw if sheathed, sheathe if drawn. What the 1 key does.
function WeaponVisualService.toggle(player: Player)
	WeaponVisualService.setDrawn(player, not WeaponVisualService.isDrawn(player))
end

--==========================================================================
--[[
	Plays one swing.

	Token-guarded rather than queued: a second swing during the first replaces
	it. Attack speed is already limited by the weapon's cooldown on the server,
	so anything that gets here is a legitimate swing and the newest one is the
	one the player means.
]]
function WeaponVisualService.swing(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local joint = rightShoulder(character)
	if not joint then
		return
	end

	local weapon = character:FindFirstChild("OldBlade")
	local trail = weapon and weapon:FindFirstChild("Hilt") and (weapon :: any).Hilt:FindFirstChild("Swing")

	local token = (swinging[player] or 0) + 1
	swinging[player] = token

	local home = homeOf(joint)

	task.spawn(function()
		local function pose(from: CFrame, to: CFrame, seconds: number, ease: (number) -> number)
			local t = 0
			while t < seconds do
				local dt = RunService.Heartbeat:Wait()
				if swinging[player] ~= token or not joint.Parent then
					return false
				end
				t = math.min(t + dt, seconds)
				joint.C0 = home * from:Lerp(to, ease(t / seconds))
			end
			return true
		end

		local easeOut = function(a: number)
			return 1 - (1 - a) ^ 3
		end
		local easeIn = function(a: number)
			return a * a
		end

		if not pose(NEUTRAL, WIND_UP, T_WIND, easeOut) then
			return
		end

		if trail and trail:IsA("Trail") then
			trail.Enabled = true
		end
		if not pose(WIND_UP, STRIKE, T_STRIKE, easeIn) then
			if trail and trail:IsA("Trail") then
				trail.Enabled = false
			end
			return
		end
		if trail and trail:IsA("Trail") then
			trail.Enabled = false
		end

		if not pose(STRIKE, NEUTRAL, T_RECOVER, easeOut) then
			return
		end

		-- Hand the joint back exactly as it was found, so a swing interrupted
		-- by a respawn or a rig change cannot leave an arm stuck out.
		if swinging[player] == token and joint.Parent then
			joint.C0 = home
			swinging[player] = nil
		end
	end)
end

--==========================================================================
--[[
	Arms a character as it spawns.

	The starter weapon is granted on PlayerAdded and the first character can
	arrive before that has finished — an unarmed-looking player who is in fact
	armed is the worst of both. So it tries again a second later, and only if
	the first attempt found nothing to attach.
]]
local function onCharacter(player: Player, character: Model)
	swinging[player] = nil

	local function tryAttach()
		if player.Character ~= character or not character.Parent then
			return false
		end
		attachWeapon(player, character)
		return character:FindFirstChild("OldBlade") ~= nil
	end

	task.defer(function()
		if tryAttach() then
			return
		end
		task.wait(1)
		tryAttach()
	end)
end

--==========================================================================
function WeaponVisualService.Init() end

function WeaponVisualService.Start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	--[[
		The 1 key. Draw or put away.

		Server-owned, like everything else here: the client asks, the server
		decides and moves the joint, and every other client sees it because a
		Motor6D change replicates. A client that spams the key just re-parents
		one Motor6D, which is why this needs no rate limit.
	]]
	Net.getEvent("RequestToggleWeapon").OnServerEvent:Connect(function(player: Player)
		WeaponVisualService.toggle(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		swinging[player] = nil
		drawn[player] = nil
	end)

	log:info("ready")
end

-- Re-reads what the player has equipped and rebuilds it. For the day the forge
-- can hand over a different blade mid-run.
function WeaponVisualService.refresh(player: Player)
	local character = player.Character
	if character then
		attachWeapon(player, character)
	end
end

return WeaponVisualService
