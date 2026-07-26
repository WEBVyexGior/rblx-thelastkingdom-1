# The Last Kingdom — Inventory & Equipment (Design)

**Status:** Foundation implemented (Phase 4) — no UI, loot, crafting, shops, stacking, or
persistence yet.
**Serves:** `../GameDesignDocument.md` §5 (Tier 1 — inventory is critical infrastructure;
Tier 2 — inventory improvements).
**Source of truth:** the GDD vision; this is the design-of-record for inventory & equipment.

> Migrated here from the old GDD §11 (design intent); implementation from `../Mechanics.md`
> and `../Changelog.md` (0.4.0).

---

## 1. Design intent

- Managed primarily in the **Hub**; usable in the **field**.
- Holds **gear, consumables, resources, quest items, relics**.
- **Server-authoritative** and (eventually) **persistent** — see `../Architecture.md` §6.

---

## 2. Implementation — foundation (Phase 4)

The item / inventory / equipment base, wired into the combat slice.

| Layer | Module | Location | Role |
|---|---|---|---|
| Config | `Items.luau` | `configs/` | Item catalog (structure/metadata). A weapon item links to combat stats in `Weapons.luau` via `WeaponId`. |
| Domain | `Inventory` | `Server/Domain/Inventory` | Item instances, uids, capacity. Pure class (+ `Inventory.spec`). |
| Domain | `Equipment` | `Server/Domain/Inventory` | Per-slot equipped instances. Pure class (+ `Equipment.spec`). |
| Service | `InventoryService` | `Server/Services` (shared) | Add/remove/get, item-id validation. |
| Service | `EquipmentService` | `Server/Services` (shared) | Equip/unequip; `getEquippedWeaponId` for the combat layer. |
| Shared | `Inventory.Enums` / `Types` | `Shared/Inventory` | `ItemCategory`, `EquipmentSlot`, type contract. |

### Combat connection

`MeleeCombatService` reads the attacker's **equipped** MainHand weapon (no hard-coded
`starter_sword`); `PlayerCombatService` grants + equips a starter weapon on entering the
World (dev flag). Weapon stats still come from `configs/Weapons`. `CombatService` is untouched
— only the melee weapon **source** moved to equipment. (See `Combat.md` §4.)

State is **per-player in-memory** for now.

---

## 3. Not built yet (by design)

- **Profile persistence** — serialize inventory/equipment into `ProfileSchema` (needs the real
  DataStore backend; see `../Architecture.md` §6 and `Progression.md`).
- **Inventory / equipment UI** + loadout interface (Hub).
- **Loot, crafting, shops, item stacking.**
- Real item content and balance.

## 4. Related

`Combat.md` · `Economy.md` (loot/rewards) · `Progression.md` (gear upgrades) · `../Architecture.md` (persistence) · `../Changelog.md` (0.4.0)
