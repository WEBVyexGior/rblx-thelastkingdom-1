# Mechanics — Combat Foundation

Status: **Phase 3 — foundation implemented** (no weapons, enemies, or balancing values yet)

This document describes the combat *architecture* built in Phase 3 — the base that later
combat content (melee, ranged, abilities, enemies, bosses, traps) plugs into. It serves
`GameDesignDocument.md` §8 (Combat) and §9 (Scaling) and follows `Architecture.md`.

## Principles

- **Server-authoritative.** All health and damage is resolved on the server by
  `CombatService` (`ServerScriptService.Server.World`). Combat exists only in the Forgotten
  Lands place — the Kingdom Hub has no combat (GDD §2).
- **Generic, not enemy-specific.** The core knows nothing about zombies. A combatant is a
  `CombatEntity`; players, undead, animals, bosses, NPCs, and even traps are the same
  abstraction, distinguished by *faction* and (for enemies) a content-defined archetype.
- **Data-driven & extensible.** Damage flows through a modifier pipeline; weapons, armor,
  resistances, crits, and abilities are added later as data + modifiers without changing the
  core. Numbers live in `configs/`, never in code.
- **Minimal foundation.** Only the machinery + a clean public API + tests. No content.

## Building blocks

| Module | Location | Role |
|---|---|---|
| `Health` | `Server/Domain/Combat` | Current/max HP, `damage`/`heal`/`setMax`, `Changed`/`Died` signals. Source of truth for alive/dead. |
| `CombatEntity` | `Server/Domain/Combat` | A combatant: id, faction, `Health`, optional model, stats, i-frames. |
| `DamagePipeline` | `Server/Domain/Combat` | Pure resolver: base amount → ordered modifiers → final amount. |
| `CombatService` | `Server/World` | Authoritative facade: entity registry, `applyDamage`, modifier registry, `DamageDealt`/`EntityDied` signals. |
| `Signal` | `Shared/Core` | Minimal event primitive used by the health/combat events. |
| `Combat.Enums` | `Shared/Combat` | `DamageType`, `Faction`, `CombatState`. |
| `Combat.Types` | `Shared/Combat` | Shared type contract (`DamageRequest`, `DamageResult`, `EntityConfig`, …). |

`Health`, `CombatEntity`, and `DamagePipeline` live in `Server/Domain` and are **not** booted
by the Loader (they are classes, required on demand). `CombatService` lives in `Server/World`
and boots through the standard `Init` → `Start` lifecycle, only in the Forgotten Lands place.

## Damage flow (authoritative)

```
source system → CombatService.applyDamage(DamageRequest)
                   │  validate:  target exists & alive
                   │  i-frames:  blocked if target invulnerable (unless pierced)
                   │  faction:   no friendly fire unless config/flag allows
                   ▼
                DamagePipeline.resolve(request, source, target, modifiers)
                   │  base amount → modifiers (empty in the foundation) → final
                   ▼
                target.Health:damage(final)  → (removed, killed)
                   ▼
                fire DamageDealt(result)  [+ EntityDied]  → bridged to clients later
```

Any later source — a weapon swing, a projectile, an ability, a trap, an environmental hazard
— simply builds a `DamageRequest` and calls `applyDamage`. The client attack path
(client intent → server-validated `RequestAttack`) and the client-facing replication bridge
(signals → `RemoteEvent` → HUD/VFX) are added when weapons and UI land.

## Enums (minimal, extensible)

- **DamageType**: `Physical`, `Fire`, `Frost`, `Arcane`, `True` (bypasses resistances). Add
  more (Holy, Poison, Lightning, …) as content needs them.
- **Faction**: `Players`, `Enemies` (all hostile PvE — undead / animals / bosses / NPCs),
  `Neutral`, `Environment` (traps / hazards). Enemy *kind* is a config archetype, not a faction.
- **CombatState**: `Alive`, `Invulnerable`, `Dead` — derived from health + i-frames, never
  stored redundantly.

## Configs (structure only — no values yet)

- `configs/Combat.luau` — global rules (friendly fire, crit multiplier, i-frame window,
  resistance matrix, hit-validation tolerances).
- `configs/Weapons.luau` — weapon schema (class, damage type/amount, cooldown, range,
  stamina, knockback, combo, requirements).
- `configs/Enemies.luau` — enemy schema (faction, archetype, health, stats, damage type,
  resistances, tier, abilities).

## Not built yet (by design)

Real weapons, enemies/zombies, waves, abilities, animations, VFX, balancing values, the
client attack/HUD path, and player/enemy Humanoid binding. Tracked in `docs/Todo.md`.
