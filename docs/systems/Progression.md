# The Last Kingdom — Progression, Upgrades & Retention (Design)

**Status:** Design only — `configs/Experience.luau` exists as a schema skeleton with no values;
no progression service yet.
**Serves:** `../GameDesignDocument.md` §5 (Tier 1 — map/character progression; Tier 2 — depth),
§1.2 (Pillar 4 — meaningful combat progression).
**Source of truth:** the GDD vision; this is the design-of-record for progression.

> Migrated here from the old GDD §10 (Progression & Upgrades) and §19 (Replayability &
> Retention).

---

## 1. Progression & upgrades

- Progression happens **in the Hub**, funded by resources/currency earned in runs
  (`Economy.md`).
- **Character upgrades** — stats, abilities, survivability, utility.
- **Gear** — weapons, armor, tools: acquired, upgraded, crafted (`Inventory.md`).
- **Account persistence** via DataStore (`../Architecture.md` §6): inventory, currency,
  upgrades, unlocked lore/achievements.
- Designed so **each run feeds the next**; as the character grows, deeper content opens.

> ⚠️ **Reconcile with GDD.** The old "each run makes the world more accessible" framing is
> roguelite-flavoured. Under the current story-campaign GDD (§4), progression should primarily
> serve **advancing the five-chapter campaign** (and post-campaign completion), not endless
> power-farming. Confirm the intended progression curve before authoring `Experience.luau`.

## 2. Replayability & retention

- Varied missions and regions (data-driven; `Missions.md`).
- Emergent/variable events per run (`EnemyAI.md`).
- Deep optional content — secrets, lore, achievements (`Missions.md` §4).
- Meaningful **persistent progression** between runs.
- Co-op social hooks — parties, shared discovery, revival (`Multiplayer.md`, `DeathSystem.md`).
- Extraction risk/reward decisions (`Economy.md`).

## 3. Implementation status

Nothing implemented beyond the persistence **framework** (`ProfileSchema`, `DataService`,
`SaveService` over a **mocked** in-memory store — real DataStore deferred; see
`../Architecture.md` §6). Progression/upgrade services are a later phase.

## 4. Related

`Economy.md` · `Inventory.md` · `Missions.md` · `../Architecture.md` (§6 persistence) · `configs/Experience.luau`
