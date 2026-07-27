--!strict
--[[
	RewardService
	Progression = WHAT THE PLAYER EARNS. The single, server-authoritative place that
	grants rewards into a player's persistent profile: currency and XP (which rolls
	into levels via the pure Progression maths). Missions and encounters call this on
	completion; it writes to the DataService cache, which SaveService persists.

	It never spawns, fights, or tracks objectives — it only applies earnings.

	Place: shared (server). Phase: Progression.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local DataService = require(script.Parent.DataService)
local Progression = require(Server.Domain.Progression)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local RewardService = {}

RewardService.Name = "RewardService"

local log = Logger.new("RewardService")

export type Reward = { summary: string?, currency: number?, xp: number? }
export type Applied = { currency: number, xp: number, levelsGained: number, newLevel: number }

-- Applies `reward` to one player's cached profile. Returns what was granted, or nil if
-- the player has no loaded profile.
function RewardService.applyTo(player: Player, reward: Reward): Applied?
	local profile = DataService.get(player)
	if not profile then
		return nil
	end

	local currency = math.max(0, reward.currency or 0)
	local xpAmount = math.max(0, reward.xp or 0)

	profile.currency = (profile.currency or 0) + currency
	local newXp, newLevel, gained =
		Progression.addXp(profile.xp or 0, profile.level or 1, xpAmount, Config.get("Experience"))
	profile.xp = newXp
	profile.level = newLevel

	log:info(("%s +%d gold +%d xp -> level %d (total %d gold)%s"):format(
		player.Name,
		currency,
		xpAmount,
		newLevel,
		profile.currency,
		if gained > 0 then (" [+" .. gained .. " level(s)]") else ""
	))

	return { currency = currency, xp = xpAmount, levelsGained = gained, newLevel = newLevel }
end

-- Applies `reward` to many players. Returns a map of player -> what was granted.
function RewardService.apply(players: { Player }, reward: Reward): { [Player]: Applied }
	local result: { [Player]: Applied } = {}
	for _, player in players do
		local applied = RewardService.applyTo(player, reward)
		if applied then
			result[player] = applied
		end
	end
	return result
end

function RewardService.Init() end

function RewardService.Start()
	log:info("ready")
end

return RewardService
