# The Last Kingdom — Progression, Upgrades & Retention (Design)

**Status:** Implemented (Progression & Rewards + Persistence) — XP/levels, currency rewards,
and real DataStore-backed saves; rewards applied from missions & encounters. See Changelog 0.9.0.
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

## 3. Implementation (Progression & Rewards + Persistence)

Implemented end-to-end (Changelog 0.9.0):

- **Progression (pure, tested)** — `Server/Domain/Progression`: XP → levels from the
  `configs/Experience` curve (`Progression.spec`). The profile gained `xp`/`level`
  (`ProfileSchema` v2 + a v1→v2 migration).
- **Rewards** — `Server/Services/RewardService` grants currency + XP into the persistent
  profile (server-authoritative, with level-ups). Both a **mission's `reward`** (on completion)
  and **any objective's `reward`** (on objective complete — so `Clear` objectives reward the
  encounter) are applied; the result (currency/xp/level-up) streams to the client `MissionEvent`
  feed.
- **Persistence** — `Server/Domain/DataStoreStore` (DataStoreService + pcall/retry) implements
  the `Store` interface and is injected into `SaveService` when enabled + available
  (`FeatureFlags.UseDataStore`), else the in-memory mock is kept (e.g. Studio without API
  access). Load-on-join / save-on-leave / autosave / save-on-close already existed.

Not yet: cross-place **session locking** (dupe protection), applying `RewardMult` scaling, Hub
spend/upgrades, and client HUD replication. See `../Todo.md`.

## 4. Related

`Economy.md` · `Inventory.md` · `Missions.md` · `../Architecture.md` (§6 persistence) · `configs/Experience.luau`
