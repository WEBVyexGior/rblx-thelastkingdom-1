# The Last Kingdom — Player Death System (Design)

**Status:** Implemented (foundation) — death choices, spectate window, self-revive (gold
anti-P2W) + free teammate revive, total-wipe → mission fail (Play Again). See Changelog 0.10.0.
Robux revive, diegetic parchment UI, and real Hub teleport are follow-ups.
**Serves:** `../GameDesignDocument.md` §1.2 (Pillar 5 — Co-op Experience: reviving, playing
with friends).
**Source of truth:** the GDD vision; this is the design-of-record for the death system.

> Migrated here from the old GDD §13 (full section).

---

## 1. Death choices

When a player dies in the Forgotten Lands, they get **three choices**:

1. **Back to Lobby** — teleport back to the Kingdom Hub (leaves the run).
2. **Revive** — a Robux-purchasable revive. **Must remain anti-pay-to-win** — the economy and
   guardrails live in `Economy.md` §3.
3. **Wait for teammates** — stay with the run; the party may revive them, or the player waits
   out the run's resolution.

## 2. Death flow

```
Player dies
   → Spectate teammates (up to 60 seconds)
      → Camera locks / stops
         → Screen darkens → cinematic "death state"
```

## 3. Death UI (medieval, diegetic)

- A **parchment / scroll** panel on the **left** of the screen listing the party.
- **Living players**: shown normally.
- **Dead players**: **skull icon** + **strikethrough** on their name — visibly "fallen in
  battle."
- Must read as diegetic and atmospheric, **not** a generic scoreboard. (Presentation direction
  in `Presentation.md`; this is Tier 3 polish and comes **after** the mechanic works.)

## 4. Total party wipe

- If **all** players die, present a **"Play Again"** option.

## 5. Party re-formation ("Wait for teammates")

Players who chose **Wait for teammates** can, after a **countdown**, start a **new run among
only themselves** — reforming a smaller party from the survivors of the choice.

> Example: a run starts with 5 players. 2 choose *Back to Lobby*. 3 choose *Wait for
> teammates*. After a countdown, those 3 begin a fresh run together.

The party/teleport mechanics of re-formation are shared with `Multiplayer.md`; the persistence
question (**how re-formed parties map to Roblox servers/teleports**, old GDD §21.7) is tracked
there.

## 6. Intended architecture (from `../Architecture.md` §9)

- **DeathSystem** (server, World) owns per-player death state: option chosen, spectate window
  (60 s), then camera-lock/cinematic signal to the client.
- **Client `World/DeathUI`** renders the parchment party list from server death-state
  replication.
- **Revive (Robux)** → `MarketplaceService` purchase → server validates → applies revive with
  the anti-P2W guardrails (`Economy.md`), never client-authoritative.
- **Re-formation** → server groups "Wait" survivors, runs a countdown, issues a fresh
  `ReserveServer` + party teleport for that subgroup.

## 7. Implementation (foundation)

Implemented (Changelog 0.10.0), party-aware:

- **`Server/World/DeathService`** owns respawn (`CharacterAutoLoads` is off in the World) and
  each run participant's death status. Death is detected via `CombatService.EntityDied`
  (players), and a player can only enter Downed once per life.
- **Choices** over `RequestDeathChoice`, offered by party size:
  - *Solo*: **Back to Lobby** (leave — respawn idle at spawn; real Hub teleport is a follow-up)
    and **Revive** (gold — anti-P2W: cost + cooldown + reduced HP).
  - *Party (2+)*: also **Wait for teammates**, with **free teammate revive** (a living run-mate
    holding position near a downed player revives them at no cost).
- **Spectate window** (`Settings.Death.SpectateSeconds`) → an undecided player auto-resolves
  (solo → lobby, party → wait).
- **Run-over** (pure `Server/Domain/DeathGroup`: no one Alive and no one still deciding) → the
  mission FAILS. There is **no auto-restart**: everyone respawns idle at spawn and gets a manual
  **Play Again** prompt (`RequestPlayAgain` → `ChapterService` restarts the chapter).
- **Client `DeathController`**: minimal — prints the offered choices, keys 1/2/(3) and R for
  Play Again (no UI/camera).
- **Config**: `Economy.Revive` (cost/HP/cooldown/teammate) and `Settings.Death`.

Not yet (follow-ups): Robux revive (`MarketplaceService`), diegetic death parchment + spectate
camera (Tier 3), real Hub teleport on Lobby, and cross-place party re-formation.

## 8. Related

`Economy.md` (revive monetization) · `Multiplayer.md` (party re-formation, teleports) · `Presentation.md` (death UI look) · `../Architecture.md` (§9)
