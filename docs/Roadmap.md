# Roadmap

Legend: ✅ done · 🚧 in progress · ⬜ not started

Phase 1
- Planning ✅
- Story ✅ (core canon locked in `docs/Story.md`; per-chapter scripting is later content work)
- Game Design Document ✅

Phase 2
- Core Systems 🚧 (backend framework, services, and the `TestService` test runner + domain
  specs implemented — see Changelog 0.2.0; the real DataStore backend is still a mock)

Phase 3
- Combat 🚧 (foundation + vertical slice implemented — see Changelog 0.3.0 / 0.3.1;
  real weapons, enemies, AI, waves, and balancing values deferred)

Phase 4
- Inventory 🚧 (foundation: item/inventory/equipment services + equipment→combat wiring —
  see Changelog 0.4.0; UI, loot, crafting, shops, and persistence deferred)

Phase 5
- Enemy AI 🚧 (foundation: state machine + detection / chase / attack / return — see
  Changelog 0.5.0; waves, spawning system, and pathfinding deferred)

Integration Milestone
- Chapter 1 Vertical Slice ✅ — first end-to-end gameplay loop wiring the Phase 2-5
  foundations (Intro → Exploration → Lore → Objective → Undead Encounter → Combat → Reward
  → End). Placeholder content, no UI/polish — see Changelog 0.6.0.
- Mission & Objective System ✅ — data-driven missions / objectives (Reach, Kill, Survive,
  Defend, Escort, Interact) / chapters + a World runtime engine; Chapter 1 is now data,
  replacing the hardcoded slice. See Changelog 0.7.0. Hardening tracked in Todo.

Phase 6
- Multiplayer ⬜

Phase 7
- Polish ⬜

Phase 8
- Release ⬜
