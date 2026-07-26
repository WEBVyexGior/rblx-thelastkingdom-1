# Changelog

## Version 0.7.0 — Mission & Objective System

Data-driven missions, objectives, and chapters replace the hardcoded Chapter 1 slice — the
former slice is now content, not code. Placeholder text only, no UI/VFX/polish:

- **Data**: `configs/Missions.luau` (ordered objectives + narrative + symbolic reward) and
  `configs/Chapters.luau` (ordered mission ids); shared contract in `Shared/Mission` (Enums:
  Reach/Kill/Survive/Defend/Escort/Interact; Types).
- **Domain (pure, tested)**: `Objective` and `MissionRun` (sequential activation, completion,
  failure) + specs `Objective.spec`, `MissionRun.spec`.
- **World runtime**: `MissionRuntimeService` (mission -> live run, drives a `Match`, streams a
  `MissionEvent` feed), `ObjectiveTrackers` (Reach/Kill/Survive/Interact full; Defend/Escort
  foundational with a neutral NPC), `ChapterService` (auto-plays a chapter; flag `EnableCampaign`).
- **Integration / refactor**: `MissionService` loads + validates the configs (and chapters);
  `EnemyService.spawn(enemyId, position)` generalised from the hardcoded dummy; `Net`
  `SliceNarrative` -> `MissionEvent`; client `NarrativeController` -> `MissionController`.
- **Removed** the hardcoded slice: `ChapterOneSliceService`, `ChapterOneSliceFlow` (+ spec),
  `configs/ChapterOneSlice.luau`, `NarrativeController`. Chapter 1 plays identically, from data.

Resolves slice tech debt: objectives are data (not baked into an orchestrator) and the run
uses the `Match` lifecycle. Reward stays symbolic until the Progression milestone.

## Version 0.6.0 — Chapter 1 Vertical Slice (integration)

The first playable end-to-end loop, proving the foundations connect. DEV/TEST scaffolding
and placeholder text only — no new gameplay systems, no UI/VFX/animations:

- **ChapterOneSliceService** (`Server/World`, Forgotten Lands only): an ORCHESTRATOR over
  existing public APIs (never their internals). Per-player flow: Spawn -> Story Intro ->
  Exploration -> Lore -> Objective -> Undead Encounter -> Combat -> Reward -> End.
- **Pure state machine** extracted to `ChapterOneSliceFlow` (`Server/Domain`) — ordered
  states + legal single-step transitions, validated on every advance. Spec:
  `Tests.ChapterOneSliceFlow.spec`.
- **Exploration**: visible placeholder markers + server-side distance detection.
- **Encounter**: reaching the objective spawns scripted undead via the existing
  `EnemyService` (reuses the `training_dummy` block); the always-on test dummy is now off.
- **Completion**: encounter deaths tracked through `CombatService.EntityDied` -> symbolic
  reward -> end -> marker cleanup. The intro is start-once and survives respawn.
- **Networking / config**: one server->client remote `SliceNarrative` (client
  `NarrativeController` prints beats — no UI); `configs/ChapterOneSlice.luau` (placeholders)
  + `Settings` flag `EnableChapterOneSlice`.

No existing system was modified beyond additive hooks (a `Net` remote, `Settings` flags).
Slice hardening (real reward, multiplayer, Match/Mission integration) is tracked in `Todo`.

## Version 0.5.0 — Phase 5: Enemy AI Foundation

The enemy AI architecture (foundation only — no waves, spawning system, pathfinding, bosses,
abilities, or optimisation):

- **EnemyBrain** (`Server/Domain/AI`): a pure, testable state machine — Idle → Chase → Attack
  → Return → Dead — deciding state from perceived distances only. Easy to extend.
- **EnemyAIService** (`Server/World`): drives each enemy per `Heartbeat` — perceive (nearest
  player via `CombatService`) → decide (brain) → actuate. Movement is simple **kinematic**
  (`PivotTo` toward target/spawn, no pathfinding). Attacks go **through the existing
  `CombatService.applyDamage`** — no duplicate combat logic.
- **Config-driven**: detection / attack / leash / arrival radii, move speed, attack cooldown
  and damage come from a new `AI` block in `configs/Enemies` (placeholder tuning). Nothing is
  hard-coded.
- **EnemyService**: one additive `EnemyAIService.attach(...)` call on spawn (no-op for enemies
  without an `AI` block). The dummy rig is unchanged.
- **Tests**: `EnemyBrain` spec covering every transition.

`CombatService` is untouched; enemy damage reuses the same authoritative path as the player's
melee. The training dummy now detects, chases, and attacks the player (and is still killable).

## Version 0.4.0 — Phase 4: Inventory & Equipment Foundation

The item / inventory / equipment base, wired into the combat slice (no UI, loot, crafting,
shops, or balancing):

- **Items config**: `configs/Items.luau` — the item catalog (structure/metadata). Weapon
  items link to their combat stats in `Weapons.luau` via `WeaponId`.
- **Domain**: `Inventory` (item instances, uids, capacity) and `Equipment` (per-slot equipped
  instances) — pure classes in `Server/Domain/Inventory`.
- **Services** (`Server/Services`, shared): `InventoryService` (fleshed out from its skeleton
  — add/remove/get, item-id validation) and new `EquipmentService` (equip/unequip, plus
  `getEquippedWeaponId` for the combat layer). Per-player in-memory state; profile
  serialization is a deferred follow-up.
- **Shared contract**: `Shared/Inventory` `Enums` (ItemCategory, EquipmentSlot) and `Types`.
- **Combat connection**: `MeleeCombatService` now reads the attacker's **equipped** MainHand
  weapon (no hard-coded `starter_sword`); `PlayerCombatService` grants + equips a starter
  weapon on entering the World (dev flag). Weapon stats still come from `configs/Weapons`.
- **Tests**: `Inventory` and `Equipment` domain specs.

`CombatService` and the authoritative combat flow (validation, hit detection, `applyDamage`)
are unchanged — only the melee weapon *source* moved to equipment.

## Version 0.3.1 — Phase 3: Combat Vertical Slice

Wires the combat foundation to real gameplay end-to-end (player swing → server validation →
enemy damage → death). No inventory, AI, waves, VFX, animations, or balanced values:

- **Player → CombatEntity**: `PlayerCombatService` (World) registers each player's character
  as a CombatEntity on spawn; `HumanoidAdapter` mirrors the authoritative `Health` onto the
  character's `Humanoid` (Health stays source of truth).
- **Enemy → CombatEntity**: `EnemyService` (World, generic for undead/animals/bosses/NPCs)
  spawns and registers enemies; ships a TEST training dummy behind `EnableCombatTestDummies`.
- **Server-authoritative melee**: `MeleeCombatService` validates the swing (attacker alive,
  per-player cooldown), performs server-side range + arc hit detection, and applies damage
  via `CombatService`. The client sends only intent + aim — never targets or damage.
- **First remotes**: `Shared/Net` declares `RequestMeleeAttack` (client→server, validated)
  and `CombatEvent` (server→client feedback); `CombatController` (client) sends the intent.
- **Additive only**: `CombatService` gained one read accessor (`getAllEntities`); `Net` now
  waits for the Remotes folder on the client so lookups are replication-safe.
- **TEST placeholders**: `starter_sword` (Weapons), `training_dummy` (Enemies), and the
  `Combat` block/flags (Settings) — not balanced values.

`ZombieService` untouched (stays the future undead-content layer over the generic `EnemyService`).

## Version 0.3.0 — Phase 3: Combat Foundation

The server-authoritative combat core for the Forgotten Lands (no weapons, enemies, or
balancing values — foundation only):

- **CombatService** (`Server/World`, Forgotten Lands only): the single authoritative damage
  entry point. Owns an entity registry (id ↔ entity, model ↔ entity for hit lookup),
  validates every hit (alive / i-frames / faction), resolves through the pipeline, applies it,
  and emits `DamageDealt` / `EntityDied` signals.
- **Damage system**: `DamagePipeline` — a pure, ordered modifier chain (empty by default) so
  armor, resistances, crits, and abilities extend it later without touching the core.
- **Entity / target handling**: `CombatEntity` — a generic combatant (players, undead,
  animals, bosses, NPCs, traps all share it) with faction, stats, and i-frames; instance→entity
  resolution walks a hit part up to its registered model.
- **Health system**: `Health` — server-authoritative current/max with clamping, latched death,
  and `Changed` / `Died` signals; decoupled from Humanoids/replication.
- **Shared contract**: `Combat.Enums` (DamageType, Faction, CombatState) and `Combat.Types`;
  plus a minimal `Core/Signal` primitive.
- **Config structure** (schemas only, no values): new `Combat.luau`; enriched `Weapons.luau`
  and `Enemies.luau` schemas (generic — enemy *archetype* is data, not a faction).
- **Tests**: `Health`, `CombatEntity`, `DamagePipeline` specs via the existing runner.

No new remotes this phase — the client-facing bridge is added with the HUD/VFX feature. No
Phase 2 systems changed.

## Version 0.2.0 — Phase 2: Core Systems

The server/client backend framework is implemented (no gameplay content yet — see the
reserved skeletons at the end):

- **Boot framework**: a shared, two-phase (`Init` → `Start`) `Loader` that boots modules
  deterministically and isolates failures; a scoped `Logger`.
- **Server core**: a place-aware server `Bootstrap` that boots the shared Services plus the
  place-specific `Hub`/`World` folder, and a per-player client `Bootstrap`.
- **Player & persistence ("Save Architecture")**: `PlayerService` (join/leave lifecycle +
  runtime `PlayerSession`), `DataService` (in-memory profile cache), `SaveService` (autosave +
  save-on-close over a pluggable `Store` — an `InMemoryStore` mock, so **no real DataStore is
  touched yet**), and a versioned `ProfileSchema`.
- **Run frameworks**: `PartyService`/`Party`, `MatchService`/`Match` (validated lifecycle
  state machine), `MissionService`/`Mission` (empty registry by design), and `TeleportService`
  (safely no-ops while the places are unpublished). `GameService` detects Hub vs. Forgotten
  Lands at runtime.
- **Shared contracts**: `Net` remote registry (zero remotes declared by design), the typed
  `Config` accessor, `Constants`, and `Types`.
- **Reserved skeletons for later phases**: `InventoryService`, `QuestService`, `ZombieService`,
  and the `Input` / `Camera` / `UI` / `Audio` client controllers.

Both places build cleanly (`rojo build default.project.json` and `world.project.json`).

## Version 0.1.0 — Phase 1: Design & Structure

- Authored the Game Design Document and the Architecture document.
- Applied the dual-place Rojo structure: `default.project.json` (Kingdom Hub) and
  `world.project.json` (Forgotten Lands), sharing `scripts/Shared`, `scripts/Modules`, and
  `configs`.
- Added the `configs/` data-driven balancing scaffold (schema skeletons documented in their
  headers; no balance values yet).

## Version 0.0.1

Project initialized.
