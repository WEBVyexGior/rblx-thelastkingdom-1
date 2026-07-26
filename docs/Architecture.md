# The Last Kingdom — Architecture Document

Status: **Adopted — implemented through Phase 2 (Core Systems)**
Version: 0.2 (living document)

> This document defines *how* the game in `GameDesignDocument.md` is built. The dual-place
> split, the `configs/` sync, and the core backend layout described here are now **applied**:
> `default.project.json` (Kingdom Hub) and `world.project.json` (Forgotten Lands) are live and
> build cleanly, and the Phase 2 core systems below exist as code. Sections still describing
> future work (the real DataStore backend, per-place gameplay systems, combat/inventory logic)
> are wired in the phase that needs them.

---

## 1. Architectural Principles

1. **Server authority** — the server is the single source of truth for all gameplay:
   damage, enemy state, spawning, loot, rewards, inventory, currency, progression. Clients
   send *intent*; the server validates and decides.
2. **Modular systems** — every system is a self-contained `ModuleScript` with a clear
   public API. Systems work independently and communicate through defined interfaces, not
   hidden globals.
3. **ModuleScripts over Scripts/LocalScripts** — thin bootstrap scripts wire up modules;
   logic lives in modules (per `CLAUDE.md`).
4. **Data-driven** — balancing, enemy stats, missions, rewards, and scaling live in
   `configs/` as data, not hard-coded. Designers tune without touching code.
5. **Shared once** — code common to both places (constants, types, utilities, shared
   systems) is written once and reused, never duplicated per place.
6. **Explicit networking** — a small, well-defined set of `RemoteEvents`/`RemoteFunctions`,
   centrally registered, always server-validated. No ad-hoc remotes scattered in scripts.
7. **No premature complexity** — a system is added when the phase needs it, and only as
   complex as that phase requires.

---

## 2. Dual-Place Architecture

The experience is **one Roblox universe with two places**:

| Place | Role | Combat | Persistence |
|---|---|---|---|
| **Kingdom Hub** | Lobby / social / prep | No | Reads & writes profile |
| **Forgotten Lands** | Expedition gameplay | Yes | Reads profile, writes rewards on extract |

### 2.1 Why two places

- The Hub is persistent, safe, and social; the Forgotten Lands is instanced, dangerous, and
  run-scoped. Different server lifecycles, streaming needs, and content.
- Roblox convention: hub-and-instanced-gameplay is cleanly modeled as separate places in one
  universe.

### 2.2 How the places connect — `TeleportService`

```
   KINGDOM HUB place                         FORGOTTEN LANDS place
   ─────────────────                         ─────────────────────
   Party + mission choice
        │
        │  TeleportService:TeleportPartyAsync / reserved server
        │  teleportData = { missionId, party[], loadout, difficultyHint }
        ▼
                                            Run begins with teleportData
                                            Play the run…
                                            On extract / wipe:
        ┌──────────────────────────────────────────┘
        │  teleportData = { runResult, rewards, survivors[] }
        ▼
   Apply rewards → save profile → back in Hub
```

Key mechanisms:
- **`TeleportService:TeleportPartyAsync`** (or reserved servers via
  `TeleportService:ReserveServer`) to move a party together into a private Forgotten Lands
  server.
- **Teleport data** carries intent between places (mission, party roster, loadout on the way
  out; run result, rewards, survivors on the way back).
- **DataStore** is the durable backbone — teleport data is transient and untrusted, so
  anything that must survive is validated server-side and persisted (see §6).
- **Party re-formation** (see `systems/DeathSystem.md`): survivors who chose *Wait for teammates* are
  re-teleported together into a fresh reserved server after the countdown.

> Security note: teleport data is client-adjacent and must be treated as untrusted. The
> receiving server re-validates everything (party membership, loadout legality, reward
> integrity) against the persisted profile.

### 2.3 Shared code strategy

Both places share the same `scripts/Shared` and `scripts/Modules` source. In a dual-project
setup this is achieved by **both place project files pointing at the same shared folders**,
so shared code is authored once and synced into each place identically.

```
                    ┌────────────────────┐
                    │  scripts/Shared     │  constants, config access,
                    │  scripts/Modules    │  types, utils, shared systems
                    └─────────┬──────────┘
              ┌───────────────┴───────────────┐
              ▼                               ▼
     hub.project.json                world.project.json
     + scripts/Server/Hub            + scripts/Server/World
     + scripts/Client/Hub            + scripts/Client/World
     + Hub ui/models                 + World ui/models
```

---

## 3. Proposed Rojo Project Files

Today there is a single `default.project.json` mapping one place. The proposal is to move to
**two place project files** that share common folders. **This is now applied** — the Kingdom Hub place ships as `default.project.json` (so a bare `rojo serve` targets it) rather than the `hub.project.json` name proposed below.

- `hub.project.json` — builds/serves the **Kingdom Hub** place.
- `world.project.json` — builds/serves the **Forgotten Lands** place.

Both would map the shared folders identically (`scripts/Shared` → `ReplicatedStorage.Shared`,
`scripts/Modules` → `ReplicatedStorage.Modules`, `configs/` → a shared config location), and
each would additionally map its own place-specific server/client/ui/model folders.

Indicative commands after the split:
- `rojo serve hub.project.json` / `rojo serve world.project.json`
- `rojo build hub.project.json -o KingdomHub.rbxlx`
- `rojo build world.project.json -o ForgottenLands.rbxlx`

The existing `default.project.json` can remain as a convenience alias for one place (likely
the Hub) or be retired — decided at approval.

> Alternative considered: keep a single place and instance the world in-place. Rejected —
> it couples two very different server lifecycles, complicates streaming, and fights the
> hub/instanced-gameplay convention. Dual-place is the recommended path.

---

## 4. Proposed Final Folder Structure

Building on the existing scaffold (`scripts/{Client,Server,Shared,Modules,Tests}`, `ui/`,
`models/`, `assets/`, `sound/`), the proposed layout adds **per-place subfolders** and a new
**`configs/`** folder:

```
the-last-kingdom/
├── aftman.toml
├── hub.project.json                 # NEW — Kingdom Hub place  (proposed)
├── world.project.json               # NEW — Forgotten Lands place (proposed)
├── default.project.json             # existing (alias / to be reconciled)
│
├── configs/                         # NEW — data-driven balancing (see configs/README.md)
│   ├── README.md
│   ├── Difficulty/                  # player-count & difficulty scaling curves
│   ├── Enemies/                     # enemy & elite & boss stat data
│   ├── Missions/                    # mission definitions & objectives
│   ├── Rewards/                     # reward tables & multipliers
│   ├── Economy/                     # currency, upgrade costs, revive economy
│   └── World/                       # spawn/event/resource tuning
│
├── scripts/
│   ├── Shared/                      # ReplicatedStorage.Shared — used by BOTH places
│   │   ├── Constants/               #   game-wide constants, enums
│   │   ├── Types/                   #   Luau type definitions
│   │   ├── Config/                  #   typed accessors that read configs/
│   │   ├── Net/                     #   remote definitions / registry (shared contract)
│   │   └── Util/                    #   pure utility modules
│   │
│   ├── Modules/                     # ReplicatedStorage.Modules — reusable systems (both)
│   │   ├── Inventory/               #   inventory system library
│   │   ├── StateMachine/            #   generic state machine
│   │   ├── Signal/                  #   event/signal primitive
│   │   ├── ProfileData/             #   profile schema helpers
│   │   └── ...                      #   (systems added per phase)
│   │
│   ├── Server/                      # ServerScriptService.Server — authoritative
│   │   ├── Core/                    #   bootstrap, service loader (shared server core)
│   │   ├── Hub/                     #   Hub-only server systems
│   │   │   ├── PartySystem/
│   │   │   ├── ShopUpgrades/
│   │   │   ├── QuestGivers/
│   │   │   └── MissionSelect/
│   │   ├── World/                   #   Forgotten Lands server systems
│   │   │   ├── RunManager/          #     run lifecycle & objectives
│   │   │   ├── Combat/              #     authoritative combat resolution
│   │   │   ├── EnemyAI/             #     enemy spawning & behavior
│   │   │   ├── Scaling/             #     player-count / difficulty scaling
│   │   │   ├── Waves/               #     encounter & wave events
│   │   │   ├── Loot/                #     drops & resource nodes
│   │   │   ├── DeathSystem/         #     death choices, spectate, party re-form
│   │   │   └── Extraction/          #     return & reward banking
│   │   └── Data/                    #   DataStore persistence layer (shared server)
│   │
│   ├── Client/                      # StarterPlayerScripts.Client — per-player
│   │   ├── Core/                    #   client bootstrap
│   │   ├── Hub/                     #   Hub UI logic, NPC interaction, menus
│   │   ├── World/                   #   field HUD, input, camera, effects
│   │   │   ├── Camera/
│   │   │   ├── Input/
│   │   │   ├── HUD/
│   │   │   └── DeathUI/             #     medieval death parchment (systems/DeathSystem.md)
│   │   └── Atmosphere/              #   lighting/weather/audio ambiance drivers
│   │
│   └── Tests/                       # TestService.Tests — module test harnesses
│
├── ui/                              # StarterGui.UI — UI layouts/screens
│   ├── Hub/
│   └── World/
│
├── models/                          # ServerStorage.Models
│   ├── Hub/
│   └── World/
│
├── assets/                          # NOT synced by Rojo (raw media → Asset Manager)
│   ├── Animations/  Audio/  Icons/  Images/  VFX/
│
├── sound/                           # NOT synced by Rojo
│
└── docs/                            # design docs (source of truth)
```

Notes:
- **`Shared` vs `Modules`**: `Shared` = game-specific constants/config/types/net/util that
  both places need; `Modules` = reusable system libraries (inventory, state machine, signal)
  that are more portable. Both sync to `ReplicatedStorage` and are available client + server.
- **`Server/Hub` vs `Server/World`**: place-specific server systems. Each place's project
  file syncs `Server/Core` + `Server/Data` + its own subfolder. (Exact per-place inclusion is
  finalized when the project files are authored in Phase 1.)
- Subfolders are created as their phase begins — the tree above is the *target*, not files to
  create now.

---

## 5. Configs — Data-Driven Balancing

- `configs/` holds **balancing data** as files that Rojo syncs into a shared config location
  (e.g. `ReplicatedStorage.Config` or `ServerStorage.Config`, decided at approval).
- Format: **`.json`** (Rojo can sync JSON files as modules returning a table) or `.luau`
  ModuleScripts returning a table. Recommendation: `.json` for pure data so it stays
  designer-editable and code-agnostic; `.luau` where a value needs computation.
- Access is mediated by `scripts/Shared/Config` typed accessors — code never reads raw files
  directly, so schema changes are localized.
- Full schema of each config file: **`configs/README.md`**.

Scaling system (see `systems/Multiplayer.md`) is fully config-driven: enemy count/HP/elite-weight/reward
multipliers are looked up per player count and difficulty from `configs/Difficulty` and
`configs/Enemies`, so `Server/World/Scaling` contains logic, not magic numbers.

---

## 6. Data Persistence

- **DataStore** (via a wrapper — e.g. a ProfileStore/DataStore2-style session-locked layer,
  chosen in Phase 2) stores the durable **player profile**: inventory, currency, upgrades,
  unlocked lore/achievements, stats.
- **`scripts/Server/Data`** is the only place that touches DataStore. Everything else goes
  through its API — no scattered `GetDataStore` calls.
- **Cross-place flow**: profile is authoritative in the DataStore. Teleport data is a
  transient hint; the receiving place loads/validates the real profile from the DataStore.
  Rewards from a run are validated and written on extraction, then read back in the Hub.
- Session locking prevents duplication exploits across the two places.

---

## 7. Networking

- **Central remote registry** in `scripts/Shared/Net`: a single definition of every
  `RemoteEvent`/`RemoteFunction` name and its payload type, shared as the contract between
  client and server.
- **Server validates everything** — never trust client-sent positions, damage, purchases,
  or reward claims.
- **Pattern**: client sends intent (`RequestAttack`, `RequestPurchase`, `ChooseDeathOption`);
  server validates against authoritative state and replicates results.
- Remotes are created/owned server-side and looked up by clients through the shared registry,
  never hard-coded by path in scattered scripts.

---

## 8. System Boundaries (per place)

**Kingdom Hub (server):** PartySystem, ShopUpgrades, QuestGivers, MissionSelect, Data
(profile read/write), teleport-out orchestration.

**Forgotten Lands (server):** RunManager (objective/state), Combat, EnemyAI, Scaling, Waves,
Loot, DeathSystem (choices, spectate timer, wipe → Play Again, party re-formation),
Extraction (reward banking + teleport-back), Data (reward write).

**Shared (both):** Constants, Types, Config accessors, Net registry, Util; Modules
(Inventory, StateMachine, Signal, ProfileData, …).

Each system is independent: e.g. Scaling exposes "give me spawn parameters for N players at
difficulty D" and knows nothing about how Waves or EnemyAI use it.

---

## 9. Death & Party Re-formation Architecture (design: `systems/DeathSystem.md`)

- **DeathSystem** (server, World) owns death state per player: option chosen (Lobby / Revive /
  Wait), spectate window (60 s), then camera-lock/cinematic signal to the client.
- **Client `World/DeathUI`** renders the medieval parchment party list (living normal; dead =
  skull + strikethrough) driven by server death-state replication.
- **Total wipe** → server signals Play Again.
- **Re-formation**: server groups "Wait for teammates" survivors, runs a countdown, and
  issues a fresh `ReserveServer` + party teleport for just that subgroup.
- **Revive (Robux)** goes through a `MarketplaceService` purchase → server validates →
  applies revive with the anti-P2W guardrails from `systems/Economy.md` §3 (never client-authoritative).

---

## 10. Testing Strategy

- `scripts/Tests` (TestService) holds isolated harnesses that validate modules independently
  (e.g. Scaling curves produce expected outputs for player counts 1–8; Inventory operations;
  StateMachine transitions).
- No test runner is configured yet; a lightweight runner (e.g. TestEZ) is added when the first
  testable module lands (record it in `CLAUDE.md` when introduced).

---

## 11. Naming & Conventions

- **Modules**: `PascalCase` ModuleScripts, one system per folder with an `init.luau` (or
  `<Name>.luau`) entry returning the public API.
- **Constants/enums**: `Shared/Constants`, `SCREAMING_SNAKE` for constant values, `PascalCase`
  for enum-like tables.
- **Remotes**: named by intent (`RequestX`, `NotifyX`), defined once in `Shared/Net`.
- **Configs**: `PascalCase` filenames grouped by domain folder under `configs/`.
- **Luau strict mode** (`--!strict`) for new modules where practical; types live in
  `Shared/Types`.

---

## 12. What Changes vs. Today (summary for review)

| Area | Today | Proposed |
|---|---|---|
| Places | 1 (`default.project.json`) | 2 (`hub.project.json`, `world.project.json`) sharing Shared/Modules |
| Server split | flat `scripts/Server` | `Server/{Core,Hub,World,Data}` |
| Client split | flat `scripts/Client` | `Client/{Core,Hub,World,Atmosphere}` |
| Balancing | none | `configs/` data + `Shared/Config` accessors |
| ui / models | flat | `Hub/` + `World/` subfolders |
| Networking | none | central `Shared/Net` registry, server-validated |
| Persistence | none | `Server/Data` DataStore layer, session-locked |

**The table above is now applied.** `default.project.json` (Kingdom Hub) and
`world.project.json` (Forgotten Lands) implement this split, both sharing `scripts/Shared`,
`scripts/Modules`, and `configs`. The Networking and Persistence rows exist as their Phase 2
framework form (empty `Net` registry; `SaveService` over an in-memory `Store`), with the real
DataStore backend injected in the persistence phase.

---

## 13. Related Documents

- `docs/GameDesignDocument.md` — the vision this architecture serves.
- `configs/README.md` — config schema.
- `CLAUDE.md` — repo conventions & Rojo mapping (updated when the dual-project split lands).
- `docs/Roadmap.md` — phase plan.
