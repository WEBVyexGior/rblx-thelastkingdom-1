--!strict
--[[
	SaveService
	Persistence orchestration — the "Save Architecture". Bridges the in-memory
	DataService and a pluggable persistence backend (Store interface):
	  - load(player):  read the backend (or create a default) -> DataService cache
	  - save(player):  DataService cache -> backend
	  - autosave + save-on-close for safety

	Phase 2 uses an in-memory mock Store, so NOTHING touches real DataStores yet.
	A real DataStore-backed Store (with session locking for the two-place setup)
	implements the same interface and is injected via `setStore` — no other code
	changes. This keeps the architecture in place while deferring risky DataStore
	logic to the persistence phase.

	Place: shared. Phase: Multiplayer / Persistence.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local DataService = require(script.Parent.DataService)
local ProfileSchema = require(Server.Domain.ProfileSchema)
local InMemoryStore = require(Server.Domain.InMemoryStore)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local SaveService = {}

SaveService.Name = "SaveService"

local log = Logger.new("SaveService")

-- Default backend is the in-memory mock. Typed `any` so a real DataStore-backed
-- Store can be injected without structural-typing friction.
local store: any = InMemoryStore.new()

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

-- Injects a different persistence backend (e.g. a real DataStore-backed Store).
function SaveService.setStore(newStore: any)
	store = newStore
end

-- Loads (or creates) a player's profile into the DataService cache.
function SaveService.load(player: Player)
	local saved = store:get(keyFor(player))
	local profile
	if saved then
		profile = ProfileSchema.migrate(saved)
	else
		profile = ProfileSchema.default()
	end
	DataService.set(player, profile)
end

-- Flushes a player's cached profile to the backend.
function SaveService.save(player: Player)
	local profile = DataService.get(player)
	if profile then
		store:set(keyFor(player), profile)
	end
end

function SaveService.saveAll()
	for _, player in Players:GetPlayers() do
		SaveService.save(player)
	end
end

function SaveService.Init() end

function SaveService.Start()
	-- Periodic autosave. Safe with the mock backend; real backend injected later.
	task.spawn(function()
		while true do
			task.wait(Constants.AUTOSAVE_INTERVAL_SECONDS)
			SaveService.saveAll()
		end
	end)

	game:BindToClose(function()
		SaveService.saveAll()
	end)

	log:info("ready")
end

return SaveService
