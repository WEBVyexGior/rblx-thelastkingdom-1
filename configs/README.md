# configs/ — Data-Driven Balancing

This folder holds **balancing data** for The Last Kingdom, kept separate from code so that
tuning happens in data, not in Luau. See `docs/Architecture.md` §5 for how it fits the
architecture, and `docs/GameDesignDocument.md` for the systems these numbers drive.

Synced by both place project files to **`ReplicatedStorage.Config`**, and read through the
`ReplicatedStorage.Shared.Config` accessor.

> **Status: schema skeletons.** The config files exist and document their schema, but hold
> **no real balance values yet** — those are authored in later phases (Combat, Progression,
> Balance). The shapes below are the intended contract, finalized as each system is built.

---

## Principles

- **Code reads config, never the reverse.** Systems call `Config.get("<Name>")`; they never
  `require` a config ModuleScript directly and never hard-code balance numbers.
- **Designer-editable data.** Each config is a small ModuleScript returning a `table.freeze`d
  table — easy to read and edit, self-documenting via its header comment.
- **One file per domain.**
- **Scaling is data.** Player-count / difficulty scaling (GDD §9) lives in `Difficulty.luau`,
  so the future `Scaling` service contains lookup logic only — no magic numbers.

## Format

Phase 1 configs are **`.luau` ModuleScripts** returning a table. This keeps them typed,
inline-documented, and uniform with the rest of the codebase. Pure-data configs that
designers edit heavily may migrate to `.json` later (Rojo can sync JSON as a module) — the
`Config` accessor hides that choice from gameplay code either way.

> **Sensitive data:** `Loot` and `Economy` contain values players should not read (drop odds,
> revive/upgrade tuning). They currently sync to `ReplicatedStorage.Config` for simplicity
> while empty; they are candidates to move to a **server-only** `ServerStorage.Config`
> location before real values land. Flagged for the Phase 2 review.

---

## Files (Phase 1)

| File | Domain | Phase values are authored |
|---|---|---|
| `Enemies.luau` | Enemy/elite/boss base stats | Combat |
| `Weapons.luau` | Weapon definitions | Combat |
| `Economy.luau` | Currencies, upgrade costs, anti-P2W revive | Progression / Monetization |
| `Difficulty.luau` | Player-count & difficulty scaling curves | Combat / Balance |
| `Waves.luau` | Encounter & invasion pacing/composition | Combat |
| `Loot.luau` | Loot & drop tables | Combat / Progression |
| `Experience.luau` | XP curve & level rewards | Progression |
| `Settings.luau` | Global timers & feature flags | Ongoing |

Each file's header comment documents its exact schema. Open the file for the authoritative
shape.

---

## Adding a config

1. Add `configs/<Name>.luau` returning a `table.freeze`d table, with a header comment
   documenting its schema.
2. Access it through `Config.get("<Name>")` — never `require` it directly from gameplay code.
3. If it holds sensitive data, raise moving it to a server-only location.

## Related

- `docs/GameDesignDocument.md` — systems these numbers drive.
- `docs/Architecture.md` §5 — how configs sync and are accessed.
- `scripts/Shared/Config.luau` — the accessor.
