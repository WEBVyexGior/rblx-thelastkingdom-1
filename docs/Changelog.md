# Changelog

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
