# The Last Kingdom — Encounters & Waves (Design + Implementation)

**Status:** Implemented (Encounter / Wave System) — data-driven encounters run by a World
engine, triggered by the Mission System. See Changelog 0.8.0.
**Serves:** `../GameDesignDocument.md` §6 (Waves as story events), §1.2 (Pillar 4 — Combat).
**Source of truth:** the GDD vision; this is the design-of-record for encounters & waves.

---

## 1. Responsibility split

- **Mission System = WHEN.** A `Clear` objective names an `encounterId`; when the objective
  activates, that encounter starts.
- **Wave System = HOW.** `WaveService.startEncounter(id, ctx)` spawns waves, tracks deaths,
  advances waves, scales by party size, cleans up, and reports progress/completion/failure.

This keeps combat "as events inside a larger world" (GDD §6): missions place encounters; the
framework runs them. Level design drops encounters into data — no code per encounter.

## 2. Data model (`configs/Encounters.luau`, `Shared/Wave/Types`)

- **Encounter** — named **spawn points** + ordered **waves** + a **mode** (Sequential/Parallel).
- **Wave** — a set of **spawn groups** (optional `startDelay`).
- **Spawn group** — N of an `enemyId` (`configs/Enemies`) at a spawn point (with `spread`).

```
chapter_one_ambush (Sequential)
  spawnPoints: north / east / west
  wave_1: 2x training_dummy @ north
  wave_2: 1x training_dummy @ east  +  1x undead_brute (elite) @ west
```

## 3. Runtime

| Module | Role |
|---|---|
| `Server/Domain/EncounterRun` | **Pure** conductor: wave progression (sequential/parallel), wave clearing, completion/fail. Tested (`EncounterRun.spec`). |
| `Server/World/WaveService` | Engine: spawn (via `EnemyService`), track deaths (`CombatService.EntityDied`), advance waves (+rest), scale, cleanup, callbacks. |
| `Shared/Scaling` | Player-count difficulty params from `configs/Difficulty`. |

Flow: `startEncounter` → `EncounterRun.initialWaves` → spawn → on unit death,
`EncounterRun.unitDied` → *(sequential)* rest + spawn next wave / *(all cleared)* `onComplete`.
The returned `stop()` fails the encounter and **despawns survivors**.

## 4. Difficulty scaling (`configs/Difficulty`)

Per player count, **sub-linear** (8 players ≈ 3× enemies, not 8×): `EnemyCountMult`,
`EnemyHealthMult`, `EliteWeight`, `RewardMult`. Extra units scaled in beyond a group's base
count may become the encounter's `eliteEnemyId` with probability `EliteWeight`.

## 5. Elite / boss

Placement is **data**: a group's `enemyId` can be an elite (`undead_brute`) or boss
(`fallen_champion`) from `configs/Enemies` (Tier Elite/Boss, own AI block). Scaling mixes
elites into the extras via `eliteEnemyId`.

## 6. Integration with Missions

`Clear` objective (`Shared/Mission`) → `ObjectiveTrackers.Clear` → `WaveService.startEncounter`.
Encounter complete → objective complete; encounter fail → objective/run fail. Wave starts and
kill progress stream to the client `MissionEvent` feed (no UI).

## 7. Not built yet (later)

Timed/triggered invasions beyond `startDelay` waves, boss abilities/phases, spawn
telegraphs/VFX, enemy pooling/perf, and undead-specific content via `ZombieService` (reserved,
layers over this generic framework). `RewardMult` is computed but applied once Economy lands.

## 8. Related

`EnemyAI.md` · `Missions.md` · `Multiplayer.md` (scaling) · `../Changelog.md` (0.8.0)
