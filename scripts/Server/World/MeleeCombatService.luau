--!strict
--[[
	MeleeCombatService
	The first attack "source" wired onto the combat core. It owns the
	server-authoritative melee swing flow:

	  client fires RequestMeleeAttack (intent + aim)
	    -> resolve the attacker's EQUIPPED weapon (via EquipmentService)
	    -> validate: attacker exists & alive, swing cooldown
	    -> server-side hit detection: enemy entities within range AND swing arc
	    -> CombatService.applyDamage for each valid target
	    -> broadcast a CombatEvent for (minimal) client feedback

	The client never says who was hit or how much — the server decides everything.
	The weapon is whatever the player has equipped in their MainHand; its stats are
	read from configs/Weapons. There is NO hard-coded weapon here.

	Place: Forgotten Lands ONLY (Server/World). Phase: Combat + Inventory.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local CombatService = require(script.Parent.CombatService)
local CombatEntity = require(Server.Domain.Combat.CombatEntity)
local WeaponVisualService = require(script.Parent.WeaponVisualService)
local EquipmentService = require(Server.Services.EquipmentService)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local MeleeCombatService = {}

MeleeCombatService.Name = "MeleeCombatService"

local log = Logger.new("MeleeCombatService")

type WeaponStats = {
	Damage: number,
	Range: number,
	Arc: number, -- degrees
	Cooldown: number,
	DamageType: string,
}

local lastSwing: { [Player]: number } = {}
local combatEvent: RemoteEvent? = nil

-- Reads combat stats for a weapon definition id from the Weapons config.
local function resolveWeaponStats(weaponId: string): WeaponStats?
	local weapons = Config.get("Weapons")
	local def = weapons[weaponId]
	if not def then
		return nil
	end
	return {
		Damage = def.Damage,
		Range = def.Range,
		Arc = def.Arc,
		Cooldown = def.Cooldown,
		DamageType = def.DamageType,
	}
end

local function playerEntityId(player: Player): string
	return Constants.CombatId.PlayerPrefix .. player.UserId
end

-- Server-authoritative target selection: alive, non-allied entities within the
-- weapon's range AND within its swing arc in front of the attacker.
function MeleeCombatService.resolveHits(
	attacker: CombatEntity.CombatEntity,
	origin: Vector3,
	forward: Vector3,
	stats: WeaponStats
): { CombatEntity.CombatEntity }
	local hits: { CombatEntity.CombatEntity } = {}
	local cosThreshold = math.cos(math.rad(stats.Arc) / 2)
	for _, entity in CombatService.getAllEntities() do
		if entity.faction ~= attacker.faction and entity:isAlive() then
			local model = entity.model
			if model and model:IsA("Model") then
				local offset = model:GetPivot().Position - origin
				local distance = offset.Magnitude
				if distance > 0 and distance <= stats.Range and forward:Dot(offset.Unit) >= cosThreshold then
					table.insert(hits, entity)
				end
			end
		end
	end
	return hits
end

local function onAttack(player: Player, aim: any)
	if not combatEvent then
		return
	end

	local attacker = CombatService.getEntity(playerEntityId(player))
	if not attacker or not attacker:isAlive() then
		return
	end

	-- Weapon comes from the player's equipped MainHand — not a hard-coded id.
	local weaponId = EquipmentService.getEquippedWeaponId(player)
	if not weaponId then
		return -- unarmed
	end
	local weapon = resolveWeaponStats(weaponId)
	if not weapon then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	-- Swing cooldown (server-authoritative anti-spam / anti-cheat).
	local now = os.clock()
	if now - (lastSwing[player] or 0) < weapon.Cooldown then
		return
	end
	lastSwing[player] = now

	--[[
		Swing the arm the moment the cooldown lets the attack through, BEFORE
		hits are resolved. It costs nothing and it means the animation plays on
		exactly the swings the server counted — a whiff looks like a whiff, and
		a swing eaten by the cooldown correctly shows nothing at all.
	]]
	WeaponVisualService.swing(player)

	-- Facing: accept a sane client aim, else the character's look direction. The
	-- server still owns hit resolution regardless of what the client sends.
	local forward = root.CFrame.LookVector
	if typeof(aim) == "Vector3" and aim.Magnitude > 0 then
		forward = aim.Unit
	end

	local results: { any } = {}
	for _, target in MeleeCombatService.resolveHits(attacker, root.Position, forward, weapon) do
		local result = CombatService.applyDamage({
			sourceId = attacker.id,
			targetId = target.id,
			amount = weapon.Damage,
			damageType = weapon.DamageType,
		})
		if not result.blocked then
			table.insert(results, result)
			log:info(("%s hit %s for %s (health %s/%s)"):format(
				attacker.id,
				target.id,
				tostring(result.amount),
				tostring(target.health.current),
				tostring(target.health.max)
			))
		end
	end

	combatEvent:FireAllClients({
		kind = "MeleeSwing",
		attackerId = attacker.id,
		weaponId = weaponId,
		hits = results,
	})
end

function MeleeCombatService.Init() end

function MeleeCombatService.Start()
	combatEvent = Net.getEvent("CombatEvent")

	local requestAttack = Net.getEvent("RequestMeleeAttack")
	requestAttack.OnServerEvent:Connect(function(player, aim)
		onAttack(player, aim)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
	end)

	log:info("ready")
end

return MeleeCombatService
