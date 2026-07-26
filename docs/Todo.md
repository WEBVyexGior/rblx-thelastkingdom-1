# TODO

## Done
- [x] Game Design Document authored (`docs/GameDesignDocument.md`)
- [x] Lobby / Kingdom Hub defined (`docs/Architecture.md` §2)
- [x] Gameplay loop defined (`docs/systems/Missions.md`)
- [x] Inventory scope defined (`docs/systems/Inventory.md` — detailed design deferred to the Inventory phase)
- [x] Progression scope defined (`docs/systems/Progression.md`)
- [x] Architecture + dual-place structure implemented (`docs/Architecture.md`)
- [x] Phase 2 core systems implemented (see `docs/Changelog.md` 0.2.0)

## Phase 2 wrap-up
- [x] Expand `docs/Story.md` — story canon locked (Asterfall, the 40-year return, the Fallen King, TLK2 seed).
- [x] Add a test harness for the pure domain modules (Match state machine, Party rules,
      ProfileSchema) — Architecture §10. Uses a dependency-free `TestService.Tests.TestRunner`
      (swappable for TestEZ later); run command documented in `CLAUDE.md`.
- [ ] Decide whether sensitive configs (`Loot`, `Economy`) move to a server-only location
      before real values land (flagged in `configs/README.md`).

## Before gameplay phases
- [ ] Lock the open questions now distributed across the system docs — `docs/systems/Economy.md`
      (revive economy, resource-on-death, extraction), `docs/systems/Combat.md` (combat model),
      `docs/systems/Missions.md` (world structure, hub depth), `docs/systems/EnemyAI.md` (wave
      triggering), `docs/systems/Multiplayer.md` (party persistence).

## Phase 3 — Combat (in progress)
- [x] Combat foundation: server-authoritative core (`CombatService`, `Health`, `CombatEntity`,
      `DamagePipeline`), factions, i-frames, damage types — see Changelog 0.3.0 & `docs/systems/Combat.md`.
- [x] Combat / Weapon / Enemy config *structure* (schemas only, no values).
- [x] Combat vertical slice: player swing → server validation → enemy damage → death
      (`PlayerCombatService`, `EnemyService`, `MeleeCombatService`, `HumanoidAdapter`,
      `CombatController`). TEST placeholders only — see Changelog 0.3.1.
- [ ] Author real combat / weapon / enemy balancing values.
- [ ] Real weapon models/animations (a visible equipped weapon).
- [ ] Client hit/health VFX & HUD (build on the `CombatEvent` bridge).
- [ ] Enemy AI, config-driven spawning, and waves (build on generic `EnemyService`; `ZombieService`).

## Phase 4 — Inventory & Equipment (in progress)
- [x] Item config structure (`configs/Items.luau`) + `Shared/Inventory` Enums/Types.
- [x] `Inventory` & `Equipment` domain classes (+ specs).
- [x] `InventoryService` (fleshed out) & `EquipmentService` (add/remove/equip/unequip).
- [x] Melee reads the equipped weapon (no hard-coded `starter_sword`); starter kit grants + equips it.
- [ ] Serialize inventory/equipment into the persistent Profile (`ProfileSchema`).
- [ ] Inventory/equipment UI + client interface (loadout in the Hub).
- [ ] Loot, crafting, shops, item stacking — later phases.

## Phase 5 — Enemy AI (in progress)
- [x] AI state machine (`EnemyBrain`: Idle/Chase/Attack/Return/Dead) + spec.
- [x] Detection / chase / attack / return, config-driven (`configs/Enemies` AI block).
- [x] Enemy attacks through the existing `CombatService` (no duplicate combat logic).
- [ ] Pathfinding / navmesh (currently straight-line kinematic movement).
- [ ] Enemy spawning system + waves (build on the generic `EnemyService`; `ZombieService`).
- [ ] Animations, ragdoll, and aggro/hit feedback.
- [ ] Multiplayer AI throttling / optimisation.

## Chapter 1 — Vertical Slice (integration milestone)
- [x] `ChapterOneSliceService` orchestrator over existing public APIs (no rewrites).
- [x] Story Intro (start-once per player; survives respawn).
- [x] Exploration flow (visible markers + server distance detection) → Lore → Objective.
- [x] Scripted undead encounter via `EnemyService` (always-on test dummy turned off).
- [x] Completion via `CombatService.EntityDied` → symbolic reward → end → marker cleanup.
- [x] Pure state machine `ChapterOneSliceFlow` (`Server/Domain`) + spec.

### Slice tech debt / refactors (recorded — not scheduled)
- [ ] Reward is symbolic (narrative only) — route real reward through Economy/persistence
      (`DataService`) once they exist (`systems/Economy.md`).
- [ ] Single shared run / single-player assumptions (`encounterSpawned` / `encounterEnemies`
      / `encounterRemaining` are module globals) — needs per-run encapsulation for multiplayer.
- [x] ~~Slice uses its own per-player states instead of `Match`~~ — RESOLVED (0.7.0): the
      Mission System drives a `Match` lifecycle.
- [x] ~~Objective lives in the orchestrator, not as `Mission` data~~ — RESOLVED (0.7.0):
      objectives are data in `configs/Missions.luau`.
- [ ] No player-death UX (respawn far from the encounter, no re-route) — pending DeathSystem.
- [ ] No timeout / failure path if the objective is never reached.

## Mission & Objective System (integration milestone)
- [x] Data-driven missions/objectives/chapters (`configs/Missions.luau`, `configs/Chapters.luau`,
      `Shared/Mission` Enums/Types), validated by `Server/Domain/Mission`.
- [x] Pure domain `Objective` + `MissionRun` (sequential activation/completion/fail) + specs.
- [x] World runtime `MissionRuntimeService` (drives a `Match`, streams `MissionEvent`) +
      `ObjectiveTrackers` (Reach/Kill/Survive/Interact full; Defend/Escort foundational) +
      `ChapterService` (auto-plays a chapter).
- [x] `EnemyService.spawn(enemyId, position)` generalised; client `MissionController` feed.
- [x] Chapter 1 replaced by data (`chapter_one_return`); hardcoded slice removed.

### Mission System tech debt (recorded — not scheduled)
- [ ] Reward is symbolic — grant through Economy/persistence (`systems/Economy.md`) later.
- [ ] Single active run / co-op share one run — multiple concurrent runs + wipe/leave handling.
- [ ] Defend/Escort foundational (minimal NPC; no attacker targeting/pathfinding).
- [ ] Objective HUD is client prints — real diegetic UI is Tier 3 polish.
- [ ] Objective spawns call `EnemyService` directly — the Wave System will structure this.
