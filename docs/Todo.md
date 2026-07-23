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

## Next (Phase 3 — Combat)
- [ ] Author `configs` values (Enemies, Weapons, Waves, Difficulty).
- [ ] Design the combat model (GDD §8).
