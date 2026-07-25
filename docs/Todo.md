# TODO

## Done
- [x] Game Design Document authored (`docs/GameDesignDocument.md`)
- [x] Lobby / Kingdom Hub defined (GDD §2)
- [x] Gameplay loop defined (GDD §3)
- [x] Inventory scope defined (GDD §11 — detailed design deferred to the Inventory phase)
- [x] Progression scope defined (GDD §10)
- [x] Architecture + dual-place structure implemented (`docs/Architecture.md`)
- [x] Phase 2 core systems implemented (see `docs/Changelog.md` 0.2.0)

## Phase 2 wrap-up
- [ ] Expand `docs/Story.md` (currently only the vision in GDD §1)
- [x] Add a test harness for the pure domain modules (Match state machine, Party rules,
      ProfileSchema) — Architecture §10. Uses a dependency-free `TestService.Tests.TestRunner`
      (swappable for TestEZ later); run command documented in `CLAUDE.md`.
- [ ] Decide whether sensitive configs (`Loot`, `Economy`) move to a server-only location
      before real values land (flagged in `configs/README.md`).

## Before gameplay phases
- [ ] Lock the GDD §21 open questions (revive economy, resource-on-death, combat model, world
      structure, wave triggering, extraction, party persistence, hub depth).

## Phase 3 — Combat (in progress)
- [x] Combat foundation: server-authoritative core (`CombatService`, `Health`, `CombatEntity`,
      `DamagePipeline`), factions, i-frames, damage types — see Changelog 0.3.0 & `Mechanics.md`.
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
