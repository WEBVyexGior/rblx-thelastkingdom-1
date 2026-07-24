--!strict
--[[
	MeleeCombatService
	The first attack "source" wired onto the combat core. It owns the
	server-authoritative melee swing flow:

	  client fires RequestMeleeAttack (intent + aim)
	    -> validate: attacker exists & alive, swing cooldown
	    -> server-side hit detection: enemy entities within range AND swing arc
	    -> CombatService.applyDamage for each valid target
	    -> broadcast a CombatEvent for (minimal) client feedback

	The client never says who was hit or how much — the server decides everything.
	The weapon is a single default/starter (no inventory yet); its stats are TEST
	placeholders read from configs/Weapons.

	Place: Forgotten Lands ONLY (Server/World). Phase: Combat (vertical slice).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local CombatService = require(script.Parent.CombatService)
local CombatEntity = require(Server.Domain.Combat.CombatEntity)
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
local weapon: WeaponStats? = nil
local combatEvent: RemoteEvent? = nil

local function loadDefaultWeapon(): WeaponStats
	local settings = Config.get("Settings")
	local weapons = Config.get("Weapons")
	local def = weapons[settings.Combat.DefaultMeleeWeaponId]
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
	if not weapon or not combatEvent then
		return
	end

	local attacker = CombatService.getEntity(playerEntityId(player))
	if not attacker or not attacker:isAlive() then
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
		hits = results,
	})
end

function MeleeCombatService.Init() end

function MeleeCombatService.Start()
	weapon = loadDefaultWeapon()
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
