# The Last Kingdom — Combat (Design)

**Status:** Foundation + vertical slice implemented (Phase 3) — no real weapons, balanced
values, VFX, or animations yet.
**Serves:** `../GameDesignDocument.md` §1.2 (Pillar 4 — Combat), §6 (waves as story events),
§5 (Tier 1 — Critical).
**Source of truth:** the GDD vision; this is the design-of-record for combat.

> Migrated here from the old GDD §8 (design intent) and `../Mechanics.md` (implementation).

---

## 1. Design intent

Combat is an **event layer**, tuned to feel dangerous and meaningful rather than constant
(GDD Pillar 4: *the player should remember important battles, not thousands of identical
fights*).

- **Server-authoritative** — all damage, hit validation, enemy state, and rewards resolve on
  the server (`../Architecture.md`). Combat exists **only in the Forgotten Lands** place; the
  Kingdom Hub has no combat.
- **Melee-forward medieval** combat (swords, blunt weapons, shields), with room for ranged
  and utility.
- Enemies **telegraph**; positioning and stamina/resource management matter.

---

## 2. Implementation — foundation (Phase 3)

Server-authoritative core. **Generic, not enemy-specific**: a combatant is a `CombatEntity`;
players, undead, animals, bosses, NPCs, and traps are the same abstraction, distinguished by
**faction** and (for enemies) a content-defined archetype.

| Module | Location | Role |
|---|---|---|
| `Health` | `Server/Domain/Combat` | Current/max HP, `damage`/`heal`/`setMax`, `Changed`/`Died` signals. Source of truth for alive/dead. |
| `CombatEntity` | `Server/Domain/Combat` | A combatant: id, faction, `Health`, optional model, stats, i-frames. |
| `DamagePipeline` | `Server/Domain/Combat` | Pure resolver: base amount → ordered modifiers → final amount. |
| `CombatService` | `Server/World` | Authoritative facade: entity registry, `applyDamage`, modifier registry, `DamageDealt`/`EntityDied` signals. |
| `Signal` | `Shared/Core` | Minimal event primitive. |
| `Combat.Enums` / `Combat.Types` | `Shared/Combat` | Shared contract. |

`Health`, `CombatEntity`, `DamagePipeline` are **classes** in `Server/Domain` (required on
demand, not booted). `CombatService` boots via `Init`→`Start` **only in the Forgotten Lands**.

### Damage flow (authoritative)

```
source system → CombatService.applyDamage(DamageRequest)
                   │ validate:  target exists & alive
                   │ i-frames:  blocked if invulnerable (unless pierced)
                   │ faction:   no friendly fire unless config/flag allows
                   ▼
                DamagePipeline.resolve(request, source, target, modifiers)
                   │ base amount → modifiers (empty in foundation) → final
                   ▼
                target.Health:damage(final)
                   ▼
                fire DamageDealt(result) [+ EntityDied]
```

Any later source — a weapon swing, projectile, ability, trap, hazard — builds a
`DamageRequest` and calls `applyDamage`. Numbers live in `configs/`, never in code.

### Enums (minimal, extensible)

- **DamageType**: `Physical`, `Fire`, `Frost`, `Arcane`, `True` (bypasses resistances).
- **Faction**: `Players`, `Enemies` (all hostile PvE), `Neutral`, `Environment` (traps/hazards).
  Enemy *kind* is a config archetype, not a faction.
- **CombatState**: `Alive`, `Invulnerable`, `Dead` — derived, never stored redundantly.

---

## 3. Implementation — vertical slice (Phase 3)

Wired end-to-end: **player swings → server validates → enemy takes damage → dies**.

| Module | Location | Role |
|---|---|---|
| `PlayerCombatService` | `Server/World` | Registers each player's character as a CombatEntity (Players) on spawn; unbinds on death/leave. |
| `EnemyService` | `Server/World` | Generic enemy layer: spawns/registers enemies; ships a TEST training dummy behind a flag. |
| `MeleeCombatService` | `Server/World` | First attack source: validates the swing, runs server-side range + arc hit detection. |
| `HumanoidAdapter` | `Server/Domain/Combat` | Mirrors authoritative `Health` onto a character `Humanoid` (Health stays source of truth). |
| `CombatController` | `Client/Controllers` | Sends the swing intent; reacts to `CombatEvent`. |

```
client click ─► RequestMeleeAttack (intent + aim) ─► MeleeCombatService
                                                       │ attacker alive? swing cooldown?
                                                       │ hit detection: range + arc (server)
                                                       ▼
                                                     CombatService.applyDamage(...)  (core unchanged)
                                                       ▼
                                     CombatEvent ◄──── DamageDealt ─► client feedback (minimal)
```

The client sends **only** intent (+ an aim direction the server re-validates); it never picks
targets or damage. `Shared/Net` declares its first two remotes here — `RequestMeleeAttack`
(client→server, validated) and `CombatEvent` (server→client).

**TEST placeholders** (not balance): `starter_sword` (Weapons), `training_dummy` (Enemies),
the `Combat` block + `EnableCombatTestDummies` flag (Settings).

---

## 4. Equipment → combat (Phase 4 link)

Melee no longer hard-codes a weapon. On attack it resolves the attacker's **equipped** weapon
and reads its stats from `configs/Weapons` (see `Inventory.md`):

```
MeleeCombatService.onAttack(player)
  └─ EquipmentService.getEquippedWeaponId(player)   -- MainHand item -> WeaponId
       └─ configs/Weapons[weaponId]                 -- Damage / Range / Arc / Cooldown / DamageType
            └─ (same validation -> hit detection -> CombatService.applyDamage)
```

---

## 5. Configs (structure only — no values yet)

- `configs/Combat.luau` — global rules (friendly fire, crit multiplier, i-frame window,
  resistance matrix, hit-validation tolerances).
- `configs/Weapons.luau` — weapon schema (class, damage type/amount, cooldown, range,
  stamina, knockback, combo, requirements).
- `configs/Enemies.luau` — enemy schema (see `EnemyAI.md`).

## 6. Open question (lock before real values)

- **Combat model** — melee/ranged/stamina specifics: swing/combo timing, stamina cost model,
  block/parry, ranged handling. (Old GDD §21.3.)

## 7. Not built yet (by design)

Real weapon/enemy content and balanced values, ranged combat, abilities, block/parry/stamina,
weapon models/animations, hit/health VFX & HUD.

## 8. Related

`EnemyAI.md` · `Inventory.md` · `../Architecture.md` · `../GameDesignDocument.md` (§1.2 Pillar 4) · `../Changelog.md` (0.3.0, 0.3.1)
