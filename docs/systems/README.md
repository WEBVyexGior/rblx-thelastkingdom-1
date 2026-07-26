# The Last Kingdom — System Design Docs

These are the **per-system design documents**. Responsibilities are split three ways:

- `../GameDesignDocument.md` — the game's **vision** (identity, pillars, story, campaign,
  priorities). The **source of truth**.
- `docs/systems/` (this folder) — the **detailed design** of each gameplay system.
- `../Architecture.md` — the **technical** architecture (dual-place, networking, persistence).

| Doc | System | GDD vision link | Status |
|---|---|---|---|
| `Combat.md` | Melee/ranged combat, damage, factions | §1.2 Pillar 4 · §6 | Foundation implemented (Phase 3) |
| `EnemyAI.md` | Enemies, encounters, waves-as-events, AI | §6 · §1.2 Pillar 4 | Foundation implemented (Phase 5) |
| `Encounters.md` | Data-driven encounters, waves, spawn groups, scaling | §6 · §1.2 Pillar 4 | Implemented (Wave System) |
| `Inventory.md` | Items, equipment, loadout | §5 | Foundation implemented (Phase 4) |
| `Economy.md` | Resources, rewards, monetization (anti-P2W) | §2 | Design only |
| `Missions.md` | Core loop, missions, objectives, exploration | §4 · §3 · §1.2 Pillar 3 | Design only |
| `DeathSystem.md` | Death choices, spectate, party re-formation | §1.2 Pillar 5 | Design only |
| `Progression.md` | Upgrades, gear progression, retention | §5 | Design only |
| `Multiplayer.md` | Co-op, party/matchmaking, player-count scaling | §1.2 Pillar 5 | Design only |
| `Presentation.md` | Art direction, audio, UI/UX | §1.2 Pillar 1 | **Deferred — Tier 3 polish** |

> The **GDD is the source of truth for vision**. These docs must not contradict it. Where a
> doc adds detail beyond the GDD, that detail is the **design-of-record** for that system.
> Where migrated detail tensions with the current vision, it is marked **⚠️ Reconcile with GDD**.

## Open questions (distributed from the old GDD §21)

Each open question now lives in the system it belongs to:

| Question | Home |
|---|---|
| Revive economy (anti-P2W formula) | `Economy.md` |
| Resource-on-death handling | `Economy.md` |
| Combat model (melee/ranged/stamina) | `Combat.md` |
| World structure (region vs zones, procedural vs handcrafted) | `Missions.md` |
| Wave triggering | `EnemyAI.md` |
| Extraction mechanic | `Economy.md` |
| Party persistence across teleports | `Multiplayer.md` |
| Hub content depth | `Missions.md` |

## Related

`../GameDesignDocument.md` · `../Story.md` · `../Architecture.md` · `../Roadmap.md` · `../Todo.md` · `../Changelog.md`
