# The Last Kingdom — Presentation: Art, Audio & UI (Design)

**Status:** **Deferred — Tier 3 polish.** Captured here so the direction is not lost; **not**
worked on until the core gameplay systems are complete (per the project's "gameplay before
polish" rule).
**Serves:** `../GameDesignDocument.md` §1.2 (Pillar 1 — Atmosphere Above Everything), §5
(Tier 3 — Polish).
**Source of truth:** the GDD vision; this is the design-of-record for presentation.

> Migrated here from the old GDD §16 (Art Direction), §17 (Audio), §18 (UI/UX). Atmosphere is
> a **vision pillar** (kept in the GDD); the detailed art/audio/UI **direction** lives here as
> polish-phase work.

---

## 1. Art direction & atmosphere

- **Mood**: dark, medieval, mysterious, immersive.
- Muted, earthy palette; heavy use of light/shadow, fog, weather, and time-of-day for tension.
- The **Hub** feels safe but somber (last kingdom standing); the **Forgotten Lands** feel
  cursed, hostile, and eerie.
- Atmosphere is a **system**, not decoration: lighting, audio, VFX, and pacing designed
  together.

## 2. Audio

- Ambient, atmospheric score; **silence used deliberately** for tension.
- Diegetic sound cues for discovery, danger, and events.
- Wave/boss moments backed by escalating music.
- Audio assets uploaded via Studio Asset Manager, referenced by `rbxassetid://` from config
  modules (per `../../CLAUDE.md`).

## 3. UI / UX

- **Medieval, diegetic UI** throughout (parchment, iron, wax-seal motifs).
- Key screens: Hub menus (inventory, upgrades, quests, party/mission select), field HUD
  (objective, health/stamina — minimal by design for immersion), death parchment
  (`DeathSystem.md` §3), lore codex.
- HUD stays **minimal in the field** to preserve immersion.

## 4. Related

`DeathSystem.md` (death UI) · `Missions.md` (HUD objectives, lore codex) · `../GameDesignDocument.md` (§1.2 Pillar 1)
