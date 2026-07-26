# The Last Kingdom — Enemies & AI (Design)

**Status:** AI foundation implemented (Phase 5) — no waves, spawning system, pathfinding,
bosses, abilities, or optimisation yet.
**Serves:** `../GameDesignDocument.md` §6 (Waves and Zombie System Philosophy), §1.2
(Pillar 4 — Combat), §5 (Tier 1 — enemy AI).
**Source of truth:** the GDD vision; this is the design-of-record for enemies & AI.

> Migrated here from the old GDD §8.1 / §8.2 (design intent) and `../Mechanics.md`
> (implementation).

---

## 1. Design intent

### 1.1 Enemy roster

- **Standard undead** — the baseline threat during encounters and events.
- **Elite enemies** — tougher, with special abilities; appear more with higher difficulty /
  more players (scaling lives in `Multiplayer.md`).
- **Bosses** — set-piece encounters tied to objectives or deep exploration; the campaign
  climax is **The Fallen King** (see `../Story.md`).

### 1.2 Encounters & waves — **as story events, not a loop**

This is a hard vision rule (GDD §6): **zombie waves are NOT the main game loop.** The game
does **not** use `Wave 1 → Wave 2 → … → Wave 100` as its structure.

- **Encounters**: small, exploration-triggered fights (ambushes, guarded loot).
- **Invasions / waves**: larger scripted or event-driven pressure moments — a spike in
  tension, not the whole game. Triggered by **progress, objectives, or entering key areas**.
  Each should feel unique ("*the village was attacked while we were there*", not "*we
  completed wave 34*").

---

## 2. Implementation — AI foundation (Phase 5)

Enemies think through a small, pure state machine driven each frame by a service.

| Module | Location | Role |
|---|---|---|
| `EnemyBrain` | `Server/Domain/AI` | Pure FSM (Idle/Chase/Attack/Return/Dead) — decides state from perceived distances only; fully testable (`EnemyBrain.spec`). |
| `EnemyAIService` | `Server/World` | Per-`Heartbeat`: perceive (nearest player via `CombatService`) → decide (brain) → actuate (kinematic move / attack). |

```
enemy tick ─► nearest player (CombatService) ─► EnemyBrain.update(distances)

  Idle ──(player within DetectionRadius)──► Chase ──(within AttackRange)──► Attack
    ▲                                         │                              │
    └──(within ArrivalRadius)── Return ◄──────┴──(target lost / > LeashRadius)
                                                Attack ─► CombatService.applyDamage(enemy → player)
```

- Movement is **straight-line kinematic** (`PivotTo`), **no pathfinding** — the anchored
  dummy is translated toward its target/spawn at `MoveSpeed`.
- Enemy attacks reuse **`CombatService.applyDamage`** (the same authoritative path as player
  melee): the enemy is `source`, the player is `target`. **No combat logic is duplicated.**
- All ranges / speed / cooldown / damage come from the enemy's `AI` block in
  `configs/Enemies` (placeholder tuning, not final balance).
- `EnemyService.attach(...)` wires an enemy to the AI on spawn (no-op for enemies without an
  `AI` block). `CombatService` is untouched.

---

## 3. Configs

- `configs/Enemies.luau` — enemy schema (faction, archetype, health, stats, damage type,
  resistances, tier, abilities) **+ the `AI` block** (detection / attack / leash / arrival
  radii, move speed, attack cooldown, damage).
- `configs/Waves.luau` — encounter & invasion pacing/composition (schema only, no values).

## 4. Open question (lock before content)

- **Wave triggering** — purely event/progress-driven, timed pressure, or hybrid? This must
  stay consistent with GDD §6 (events, not an endless loop). (Old GDD §21.5.)

## 5. Not built yet (by design)

Enemy **spawning system**, waves/invasions, **pathfinding / navmesh** (currently straight-line
kinematic), bosses, abilities, real enemy content & balance, animations/ragdoll, aggro/hit
feedback, and multiplayer AI throttling/optimisation.

> `ZombieService` (`Server/World`) stays the future undead-content layer built **over** the
> generic `EnemyService` — undead are content, not a special case in the core.

## 6. Related

`Combat.md` · `Multiplayer.md` (scaling) · `Missions.md` (event triggers) · `../Story.md` (the Fallen King) · `../Changelog.md` (0.5.0)
