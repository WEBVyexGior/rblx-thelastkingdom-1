# The Last Kingdom — Missions, Loop & Exploration (Design)

**Status:** Design only — `MissionService` exists as an **empty registry** (Phase 2 framework);
no mission content yet.
**Serves:** `../GameDesignDocument.md` §4 (Campaign Structure), §3 (Story Overview), §1.2
(Pillar 3 — Exploration), §5 (Tier 1 — mission system & objectives).
**Source of truth:** the GDD vision; this is the design-of-record for missions & the loop.

> Migrated here from the old GDD §3 (Core Loop), §4 (Session Design), §5 (Missions &
> Objectives), §6 (Exploration, Discovery & Lore).

---

## 1. Core gameplay loop

```
        ┌─────────────────────────── KINGDOM HUB ───────────────────────────┐
        │  Prepare → Inventory / Upgrades → Quests → Party → Choose Mission  │
        └───────────────────────────────┬───────────────────────────────────┘
                                         │  Teleport (party carried)
                                         ▼
        ┌────────────────────────── FORGOTTEN LANDS ────────────────────────┐
        │  Enter world → Explore → Discover (locations, resources, NPCs,     │
        │  lore) → Events trigger → Encounter/invasion (event) → Survive →   │
        │  Complete objective                                                │
        └───────────────────────────────┬───────────────────────────────────┘
                                         │  Extract / return (rewards carried)
                                         ▼
        ┌─────────────────────────── KINGDOM HUB ───────────────────────────┐
        │  Return with rewards → Upgrade → (advance the campaign)            │
        └───────────────────────────────────────────────────────────────────┘
```

The loop is **objective-driven**, not clock-driven. A run ends when the party completes its
objective and extracts, when all players die (`DeathSystem.md`), or when the party returns.

> ⚠️ **Reconcile with GDD.** The old loop ended with *"repeat, deeper"* (roguelite). The
> current GDD (§4) is a **five-chapter story campaign**. The loop still holds, but "repeat" is
> **campaign/chapter progression**, not endless identical runs. Confirm before building mission
> content.

## 2. Session design & pacing

There is **no fixed session timer** — pacing is by **progress and exploration**, not a
countdown. Optional layers (side quests, hidden locations, lore, rare nodes, achievements)
extend a run for players who want more.

> ⚠️ **Reconcile with GDD.** The old target was ~90–120 min **per run**. The current GDD §4
> targets **2.5–3 h main story / 5+ h full completion** for the whole **campaign**. These are
> different scopes (per-run vs. whole-game) — reconcile how many missions/chapters make up the
> campaign and their individual length.

## 3. Missions & objectives

- A **mission** is chosen in the Hub and defines the run's primary objective and the region of
  the Forgotten Lands loaded. Missions are **data-driven** (`configs/`) — new missions are
  config + content, not new systems.
- **Primary objective** — the main goal (reach a location, recover a relic, cleanse a site,
  survive to an extraction event). Completing it enables extraction with full reward.
- **Secondary objectives** (optional) — side quests, discoveries, bonus challenges; extra
  rewards, no penalty for skipping.
- **Emergent objectives** — events during exploration (a survivor to rescue, a sealed vault,
  an ambush; encounter triggers live in `EnemyAI.md`).

The five story chapters (GDD §4) are delivered **through** missions — see `../Story.md` §10 for
the per-chapter story beats each mission serves.

## 4. Exploration, discovery & lore

Exploration is a first-class pillar (GDD Pillar 3), not filler between fights.

- **Locations** — ruins, villages, camps, crypts, shrines: atmosphere, loot, and often lore.
- **Discovery rewards** — finding a location can grant resources, lore, map reveals, or trigger
  events.
- **Lore system** — collectible lore (journals, inscriptions, NPC dialogue) that builds *why*
  the kingdom fell (the central mystery, `../Story.md`). Tracked persistently (a codex in the
  Hub).
- **Secrets** — hidden areas/rewards for curious players.
- **World NPCs** — survivors, hermits, cursed figures: quests, lore, occasional trade.

## 5. Open questions

- **World structure** — single large region per mission vs. connected zones; procedural vs.
  handcrafted vs. hybrid. (old GDD §21.4)
- **Hub content depth** — how much explorable/secret content lives in the Hub itself. (old GDD §21.8)

## 6. Implementation status

- `MissionService` / `Mission` (`Server/Services`, `Server/Domain`) — lifecycle framework with
  an **empty mission registry by design** (Phase 2). No mission definitions yet.
- `MatchService` / `PartyService` / `TeleportService` — run/party/teleport frameworks exist
  (see `Multiplayer.md`).

## 7. Related

`EnemyAI.md` (encounter triggers) · `Economy.md` (rewards/extraction) · `Multiplayer.md` (party/teleport) · `../Story.md` (campaign beats) · `../GameDesignDocument.md` (§4)
