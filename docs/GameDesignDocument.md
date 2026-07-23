# The Last Kingdom — Game Design Document

Status: **Design / Pre-Phase 1**
Version: 0.1 (living document)
Developer: Cookies11f

> This GDD is the source of truth for the game's vision. Code must serve this document,
> not the other way around. When gameplay decisions are made in code, they are reflected
> back here first.

---

## 1. Vision

**The Last Kingdom** is a medieval co-op survival adventure for up to 8 players. It is
**not** a zombie wave game. It is an atmospheric, story-driven world where combat —
including undead encounters — happens as *significant events inside a larger world*, not
as the entire experience.

The player fantasy: *a small band of survivors venturing out from the last standing
kingdom into cursed, forgotten lands — exploring ruins, uncovering lore, gathering what
they can, surviving what finds them, and returning home changed.*

### 1.1 Design Pillars

1. **Atmosphere first** — dark, medieval, mysterious, immersive. Every system reinforces
   mood before mechanics.
2. **Exploration over grinding** — the world rewards curiosity: secrets, lore, hidden
   locations, optional objectives.
3. **Combat as event, not loop** — fights are punctuation, tension spikes inside a
   quieter journey.
4. **Co-op that matters** — up to 8 players; survival, revival, and shared discovery are
   social by design.
5. **Dynamic pacing** — no fixed match length. The world decides how long you stay.
6. **Replayability** — procedural/varied events, branching objectives, discoverable
   content, and progression that pulls players back.
7. **Fair monetization** — no pay-to-win. Convenience and cosmetics only.

### 1.2 What this game is NOT

- Not a round-based arena survival ("wave 1, wave 2, …" as the whole game).
- Not a fixed 60-minute match.
- Not pay-to-win.
- Not a lobby with a single linear level.

---

## 2. Structure — Two Games, One Experience

The experience is delivered as **two separate Roblox places** under one universe, linked
by `TeleportService`. (Full technical treatment in `Architecture.md`.)

### GAME 1 — Kingdom Hub (the lobby / social hub)

The safe home base. No combat. Persistent, calm, atmospheric.

Players here:
- Prepare before a run (loadout, consumables).
- View and manage **inventory**.
- Spend earned resources on **upgrades**.
- Accept and track **quests**.
- Talk to **NPCs** (vendors, quest givers, lore).
- **Explore** the kingdom itself (there is content and secrets here too).
- Form or join a **party** and choose a mission before deploying.

### GAME 2 — Forgotten Lands (the gameplay world)

The dangerous expedition zone. Where the run actually happens:
- Exploration of a large, dark world.
- Missions and objectives.
- Story events and scripted moments.
- Resource gathering.
- Combat.
- Zombie / undead encounters and **waves** (as events).
- Bosses.
- Rewards, extracted on return.

---

## 3. Core Gameplay Loop

```
        ┌─────────────────────────── KINGDOM HUB ───────────────────────────┐
        │  Prepare → Inventory / Upgrades → Quests → Party → Choose Mission  │
        └───────────────────────────────┬───────────────────────────────────┘
                                         │  Teleport (party carried)
                                         ▼
        ┌────────────────────────── FORGOTTEN LANDS ────────────────────────┐
        │  Enter world                                                       │
        │     → Explore                                                      │
        │        → Discover (locations, resources, NPCs, lore)              │
        │           → Events trigger                                         │
        │              → Zombie invasion / waves (event)                    │
        │                 → Survive                                          │
        │                    → Complete objective                           │
        └───────────────────────────────┬───────────────────────────────────┘
                                         │  Extract / return (rewards carried)
                                         ▼
        ┌─────────────────────────── KINGDOM HUB ───────────────────────────┐
        │  Return with rewards → Upgrade character → (repeat, deeper)        │
        └───────────────────────────────────────────────────────────────────┘
```

The loop is **objective-driven**, not clock-driven. A run ends when the party completes
its objective and extracts, when all players die, or when the party chooses to return.

---

## 4. Session Design & Dynamic Duration

There is **no fixed session timer**.

| Play style | Target duration |
|---|---|
| Average player (main objective, some exploration) | **~90 min – 2 hours** |
| Explorer / completionist (side quests, secrets, achievements, full resource sweep) | **Several hours** |

How dynamic duration is achieved:
- **Main objective** gives a natural "you can leave now" point around the 90–120 min mark.
- **Optional layers** (side quests, hidden locations, lore collectibles, rare resource
  nodes, achievements) extend the run for players who want more.
- **Extraction is player-initiated** — the party decides when to return, once the objective
  is met (or earlier, banking partial rewards).
- Events and encounters are **spaced by progress and exploration**, not by a countdown.

Design rule: *the critical path is ~90–120 min; the world holds many more hours of optional
content on top of it.*

---

## 5. Missions & Objectives

- A **mission** is chosen in the Hub and defines the run's primary objective and the region
  of the Forgotten Lands loaded.
- **Primary objective**: the main goal (e.g. reach a location, recover a relic, cleanse a
  site, survive to an extraction event). Completing it enables extraction with full reward.
- **Secondary objectives** (optional): side quests, discoveries, bonus challenges — extra
  rewards, no penalty for skipping.
- **Emergent objectives**: events that appear during exploration (a survivor to rescue, a
  sealed vault, an ambush).

Missions are **data-driven** (see `configs/`), so new missions are added as config +
content, not new systems.

---

## 6. Exploration, Discovery & Lore

Exploration is a first-class pillar, not filler between fights.

- **Locations**: ruins, villages, camps, crypts, shrines — each with atmosphere, loot, and
  often lore.
- **Discovery rewards**: finding a location can grant resources, lore entries, map reveals,
  or trigger events.
- **Lore system**: collectible lore (journals, inscriptions, NPC dialogue) that builds the
  story of *why* the kingdom fell and what the Forgotten Lands are. Tracked persistently
  (a codex in the Hub).
- **Secrets**: hidden areas and rewards for observant/curious players — core to replayability.
- **World NPCs**: survivors, hermits, cursed figures — quests, lore, occasional trade.

---

## 7. Resources & Gathering

- Resources are gathered in the Forgotten Lands (harvest nodes, loot, drops).
- Types (indicative, finalized in config): raw materials, crafting components, currency,
  rare/relic items.
- Resources are **carried out on extraction** and spent in the Hub on upgrades/crafting.
- Death handling of carried resources (full loss / partial loss / safe) is a balance
  decision — see Open Questions.

---

## 8. Combat

Combat is an **event layer**, tuned to feel dangerous and meaningful rather than constant.

- **Server-authoritative** — all damage, hit validation, enemy state, and rewards resolved
  on the server (see `Architecture.md`).
- Melee-forward medieval combat (swords, blunt weapons, shields), with room for ranged and
  utility. Exact combat model is a Phase 3 design.
- Enemies telegraph; positioning and stamina/resource management matter.

### 8.1 Enemies

- **Standard undead** — the baseline threat during encounters and waves.
- **Elite enemies** — tougher, special abilities; appear more with higher difficulty /
  more players.
- **Bosses** — set-piece encounters tied to objectives or deep exploration.

### 8.2 Encounters & Waves

- **Encounters**: small, exploration-triggered fights (ambushes, guarded loot).
- **Zombie invasions / waves**: larger scripted or event-driven pressure moments — a spike
  in tension, not the whole game. Triggered by progress, objectives, or entering key areas.

---

## 9. Difficulty & Player-Count Scaling

Supports **up to 8 players**. Scaling is **balanced, not linear**.

**Explicitly NOT:** 8 players → 8× zombies.

More players scales:
- Enemy **count** (sub-linear growth).
- **Elite** enemy frequency and variety.
- Overall **difficulty** (enemy stats, aggression, event intensity).
- **Reward** quality/quantity (to match the increased challenge).

**Invariant:** completion time for the primary objective stays **roughly the same**
regardless of party size. A full 8-player squad should finish the critical path in a
comparable window to a smaller group — they face a harder, richer version, not a longer one.

All scaling curves live in `configs/` as data (enemy multipliers per player count, elite
weights, reward multipliers), so balance is tuned without touching code. Architecture in
`Architecture.md`.

---

## 10. Progression & Upgrades

- Progression happens **in the Hub**, funded by resources/currency earned in runs.
- **Character upgrades**: stats, abilities, survivability, utility.
- **Gear**: weapons, armor, tools — acquired, upgraded, crafted.
- **Account persistence** via DataStore (see `Architecture.md`): inventory, currency,
  upgrades, unlocked lore/achievements.
- Progression is designed for **replayability** — each run feeds the next; the world gets
  more accessible as the character grows, opening deeper content.

---

## 11. Inventory

- Managed primarily in the Hub; usable in the field.
- Holds gear, consumables, resources, quest items, relics.
- Server-authoritative and persistent.
- Detailed design is a dedicated phase (per `Roadmap.md`).

---

## 12. Economy & Rewards

- **Earn** (in runs): resources, currency, gear, lore, rare relics.
- **Spend** (in Hub): upgrades, crafting, gear, cosmetics.
- Rewards scale with difficulty and party size (§9) and with optional-content completion.
- **Extraction = banking**: rewards are secured on return. Risk/reward tension of "push
  deeper vs. extract now" is a core hook.

---

## 13. Player Death System

When a player dies in the Forgotten Lands, they get **three choices**:

1. **Back to Lobby** — teleport back to the Kingdom Hub (leaves the run).
2. **Revive** — a Robux-purchasable revive. **Must remain anti-pay-to-win** (see §15).
3. **Wait for teammates** — stay with the run; the party may revive them, or the player
   waits out the run's resolution.

### 13.1 Death flow

```
Player dies
   → Spectate teammates (up to 60 seconds)
      → Camera locks / stops
         → Screen darkens → cinematic "death state"
```

### 13.2 Death UI (medieval)

- A **parchment / scroll** panel on the **left** of the screen listing the party.
- **Living players**: shown normally.
- **Dead players**: **skull icon** + **strikethrough** on their name — visibly "fallen in
  battle."
- The UI must read as diegetic and atmospheric, not as a generic scoreboard.

### 13.3 Total party wipe

- If **all** players die, present a **"Play Again"** option.

### 13.4 Party re-formation ("Wait for teammates")

Players who chose **Wait for teammates** can, after a **countdown**, start a **new run
among only themselves** — reforming a smaller party from the survivors of the choice.

> Example: run starts with 5 players. 2 choose *Back to Lobby*. 3 choose *Wait for
> teammates*. After a countdown, those 3 can begin a fresh run together.

---

## 14. Party & Matchmaking

- Parties form in the Hub (up to 8).
- The party is **carried across the teleport** into the Forgotten Lands and back.
- Re-formation after death (§13.4) creates new party groupings mid-experience.

---

## 15. Monetization (Anti Pay-to-Win)

Guiding rule: **money buys convenience and cosmetics, never power or unfair advantage.**

- **Revive (Robux)** is the primary monetized mechanic and must be balanced so it does not
  become pay-to-win. Candidate guardrails (to be finalized in balance pass):
  - Cooldown / limited uses per run.
  - Diminishing benefit (e.g. reduced HP or a temporary penalty on revive).
  - Reward penalty on paid revive (so paying trades power for time, not for winning).
  - Free co-op revive path always exists (teammates can revive), so paying is a shortcut,
    not a requirement.
- Cosmetics: purely visual (medieval skins, banners, emotes) — always allowed.
- No purchasable stats, gear power, or resource shortcuts that trivialize progression.

Exact revive economy is an **Open Question** locked before implementation.

---

## 16. Art Direction & Atmosphere

- **Mood**: dark, medieval, mysterious, immersive.
- Muted, earthy palette; heavy use of light/shadow, fog, weather, and time-of-day for
  tension.
- The Hub feels safe but somber (last kingdom standing); the Forgotten Lands feel cursed,
  hostile, and eerie.
- Atmosphere is a system, not decoration: lighting, audio, VFX, and pacing are designed
  together.

---

## 17. Audio

- Ambient, atmospheric score; silence used deliberately for tension.
- Diegetic sound cues for discovery, danger, and events.
- Wave/boss moments backed by escalating music.
- Audio assets uploaded via Studio Asset Manager, referenced by `rbxassetid://` from config
  modules (per `CLAUDE.md`).

---

## 18. UI / UX

- **Medieval, diegetic UI** throughout (parchment, iron, wax-seal motifs).
- Key screens: Hub menus (inventory, upgrades, quests, party/mission select), field HUD
  (objective, health/stamina, minimal by design for immersion), death parchment (§13.2),
  lore codex.
- HUD stays minimal in the field to preserve immersion.

---

## 19. Replayability & Retention

- Varied missions and regions (data-driven).
- Emergent/variable events per run.
- Deep optional content (secrets, lore, achievements).
- Meaningful persistent progression between runs.
- Co-op social hooks (parties, shared discovery, revival).
- Extraction risk/reward decisions.

---

## 20. Technical Summary

- Two Roblox places (Hub, Forgotten Lands), one universe, linked via `TeleportService`.
- Server-authoritative gameplay; `RemoteEvents`/`RemoteFunctions` for client/server comms.
- Modular `ModuleScript`-based systems; shared code reused across both places.
- Data-driven balancing via `configs/`.
- Persistence via DataStore.

Full detail in **`Architecture.md`**.

---

## 21. Open Questions (lock before Phase 1 implementation)

1. **Revive economy** — exact anti-P2W formula (cooldown, penalty, reward reduction).
2. **Resource-on-death** — do carried resources drop / partially drop / stay safe on death
   before extraction?
3. **Combat model** — melee/ranged/stamina specifics (Phase 3).
4. **World structure** — single large region per mission vs. connected zones; procedural vs.
   handcrafted vs. hybrid.
5. **Wave triggering** — purely event/progress-driven, timed pressure, or hybrid.
6. **Extraction mechanic** — extraction points, extraction event, or free return.
7. **Party persistence** — how re-formed parties (§13.4) map to Roblox servers/teleports.
8. **Hub content depth** — how much explorable/secret content lives in the Hub itself.

---

## 22. Related Documents

- `docs/Architecture.md` — technical architecture, dual-place structure, folder layout.
- `docs/Roadmap.md` — phase plan.
- `docs/Todo.md` — current backlog.
- `docs/Story.md`, `docs/Mechanics.md` — to be expanded from this GDD.
- `configs/README.md` — balancing data schema.
