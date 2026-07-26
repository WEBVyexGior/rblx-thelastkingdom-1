# The Last Kingdom — Multiplayer, Party & Scaling (Design)

**Status:** Frameworks implemented (Phase 2) — `PartyService`, `MatchService`,
`TeleportService`; the player-count **Scaling** service is not built (config schema only).
**Serves:** `../GameDesignDocument.md` §1.2 (Pillar 5 — Co-op Experience, up to 8 players),
§5 (Tier 1 — multiplayer compatibility).
**Source of truth:** the GDD vision; this is the design-of-record for co-op & scaling.

> Migrated here from the old GDD §9 (Difficulty & Player-Count Scaling), §14 (Party &
> Matchmaking), and §13.4 (party re-formation, shared with `DeathSystem.md`).

---

## 1. Co-op

The game supports **up to 8 players** (GDD Pillar 5). Playing with friends improves the
experience through teamwork, reviving (`DeathSystem.md`), protecting NPCs, solving objectives
together, and exploring together.

## 2. Party & matchmaking

- Parties form in the **Hub** (up to 8).
- The party is **carried across the teleport** into the Forgotten Lands and back
  (`../Architecture.md` §2).
- **Re-formation** after death (`DeathSystem.md` §5) creates new party groupings mid-experience.

## 3. Difficulty & player-count scaling

Scaling is **balanced, not linear**. **Explicitly NOT:** 8 players → 8× zombies.

More players scales:
- Enemy **count** (sub-linear growth).
- **Elite** enemy frequency and variety (`EnemyAI.md`).
- Overall **difficulty** (enemy stats, aggression, event intensity).
- **Reward** quality/quantity to match the challenge (`Economy.md`).

**Invariant:** completion time for the primary objective stays **roughly the same** regardless
of party size — a full squad faces a **harder, richer** version, not a **longer** one.

All scaling curves live in `configs/Difficulty.luau` as data (enemy multipliers per player
count, elite weights, reward multipliers), so the future `Scaling` service is **lookup logic,
not magic numbers** (`configs/README.md`, `../Architecture.md` §5).

## 4. Open question

- **Party persistence** — how re-formed parties (`DeathSystem.md` §5) map to Roblox
  servers/teleports (reserved servers, teleport data validation). (Old GDD §21.7.)

## 5. Implementation status

- `PartyService` / `Party`, `MatchService` / `Match` (validated lifecycle state machine),
  `TeleportService` (safely no-ops while places are unpublished) — Phase 2 frameworks.
- `Scaling` service — **not built**; `configs/Difficulty.luau` is a schema skeleton.

## 6. Related

`EnemyAI.md` · `Economy.md` · `DeathSystem.md` · `Missions.md` · `../Architecture.md` (§2 teleport, §5 configs)
