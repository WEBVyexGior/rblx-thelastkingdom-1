--!strict
--[[
	BlacksmithService
	The forge. Owns every weapon upgrade a player buys: what it costs, whether
	they can afford it, and writing the result to their profile.

	Server-authoritative throughout. The client sends only "upgrade this weapon"
	— never a level, never a price. Everything else is looked up here, so a
	tampered client can at worst ask for something it cannot pay for.

	Weapon levels live in `profile.upgrades[weaponId]`, a container the schema
	already carries, so nothing about saving had to change.

	Place: Kingdom Hub only. Phase: Hub Systems.

	Location: ServerScriptService.Server.Hub.BlacksmithService
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local DataService = require(Server.Services.DataService)
local WeaponUpgrade = require(Server.Domain.WeaponUpgrade)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local BlacksmithService = {}

BlacksmithService.Name = "BlacksmithService"

local log = Logger.new("BlacksmithService")

local curve: any = nil
local weapons: any = nil

local forgeEvent: RemoteEvent
local stateRequest: RemoteEvent
local upgradeRequest: RemoteEvent

--============================================================================
-- Reading a player's forge
--============================================================================

local function levelOf(profile: any, weaponId: string): number
	local stored = profile.upgrades[weaponId]
	return if type(stored) == "number" then math.max(1, math.floor(stored)) else 1
end

-- Everything the shop needs to draw itself, computed here so the client never
-- has to know the price curve.
local function stateFor(player: Player): { [string]: any }?
	local profile = DataService.get(player)
	if not profile then
		return nil
	end

	local gold = profile.currency or 0
	local playerLevel = profile.level or 1

	local stock: { any } = {}
	for weaponId, weapon in weapons do
		local level = levelOf(profile, weaponId)
		local requiredLevel = (weapon.Requirements and weapon.Requirements.level) or 0
		local locked = playerLevel < requiredLevel

		table.insert(stock, {
			id = weaponId,
			name = weapon.DisplayName,
			class = weapon.Class,
			level = level,
			maxLevel = WeaponUpgrade.maxLevel(curve),
			maxed = WeaponUpgrade.isMaxed(curve, level),
			damage = WeaponUpgrade.damageAt(curve, weapon.Damage, level),
			baseDamage = weapon.Damage,
			gain = WeaponUpgrade.damageGain(curve, weapon.Damage, level),
			cost = WeaponUpgrade.costToNext(curve, level),
			affordable = WeaponUpgrade.canAfford(curve, level, gold),
			cooldown = weapon.Cooldown,
			range = weapon.Range,
			invested = WeaponUpgrade.investedTo(curve, level),
			locked = locked,
			requiredLevel = requiredLevel,
		})
	end

	-- Cheapest first, so the next affordable purchase is near the top.
	table.sort(stock, function(a, b)
		return a.baseDamage < b.baseDamage
	end)

	return { kind = "state", gold = gold, playerLevel = playerLevel, stock = stock }
end

local function push(player: Player)
	local state = stateFor(player)
	if state then
		forgeEvent:FireClient(player, state)
	end
end

--============================================================================
-- Buying
--============================================================================

local function onUpgradeRequest(player: Player, weaponId: any)
	if type(weaponId) ~= "string" then
		return
	end
	local weapon = weapons[weaponId]
	local profile = DataService.get(player)
	if not weapon or not profile then
		return
	end

	-- Locked weapons cannot be bought at any price: the level gate is the point.
	local requiredLevel = (weapon.Requirements and weapon.Requirements.level) or 0
	if (profile.level or 1) < requiredLevel then
		forgeEvent:FireClient(player, { kind = "denied", reason = "locked", id = weaponId })
		return
	end

	local level = levelOf(profile, weaponId)
	local newLevel, remainingGold = WeaponUpgrade.purchase(curve, level, profile.currency or 0)
	if not newLevel or not remainingGold then
		local reason = if WeaponUpgrade.isMaxed(curve, level) then "maxed" else "gold"
		forgeEvent:FireClient(player, { kind = "denied", reason = reason, id = weaponId })
		return
	end

	profile.upgrades[weaponId] = newLevel
	profile.currency = remainingGold

	local damage = WeaponUpgrade.damageAt(curve, weapon.Damage, newLevel)
	log:info(("%s upgraded %s to +%d (%d damage, %d gold left)"):format(
		player.Name,
		weaponId,
		newLevel,
		damage,
		remainingGold
	))

	forgeEvent:FireClient(player, {
		kind = "upgraded",
		id = weaponId,
		name = weapon.DisplayName,
		level = newLevel,
		damage = damage,
	})
	push(player)
end

--============================================================================
-- Lifecycle
--============================================================================

function BlacksmithService.Init()
	curve = Config.get("Economy").Upgrades.Weapon
	weapons = Config.get("Weapons")
end

function BlacksmithService.Start()
	forgeEvent = Net.getEvent("ForgeEvent")
	stateRequest = Net.getEvent("RequestForgeState")
	upgradeRequest = Net.getEvent("RequestForgeUpgrade")

	stateRequest.OnServerEvent:Connect(push)
	upgradeRequest.OnServerEvent:Connect(onUpgradeRequest)

	local count = 0
	for _ in weapons do
		count += 1
	end
	log:info(("ready (%d weapon(s), max +%d)"):format(count, WeaponUpgrade.maxLevel(curve)))
end

return BlacksmithService
