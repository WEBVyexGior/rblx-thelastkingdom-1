# The Forgotten Lands — layout

**The map is inside the castle.** Not a road toward it: the walls are already
around you when you spawn, and everything that happens, happens in here.

## Shape

A **300 × 1800** enclosure, sealed on all four sides, divided into **nine
chambers** by cross-walls. Each cross-wall has ONE gap, and the gap alternates
side to side, so the route runs forward, cross right, forward, cross left,
forward — a serpentine you cannot get lost in and cannot leave.

```
   gate ──►  [1]═╗
                 ║      ╔═[3]  ──►
             ╔═[2]      ║
             ║          ╚═[4]
             ...              ...   [9] the end
```

There are **no invisible walls anywhere**. The castle is the boundary, which is
the only kind of boundary a player ever accepts.

Each chamber is roughly **300 × 190** — an arena, sized for a wave — and its
interior is deliberately left empty. Houses, rubble and set dressing go in by
hand; the walls, gates and towers are generated.

## Markers

Every chamber carries the markers the gameplay systems already read, so a wave
can be pointed at a room without anyone typing a coordinate:

| Marker | Used by |
|---|---|
| `Spawns.North` / `East` / `West` | Encounter spawn points |
| `Objectives.Centre` | Reach / Defend / Interact objectives |
| `Checkpoint` | Where a rejoining player returns to |
| `Storyteller` | Where a story NPC stands |

Referenced from config by name, e.g. `Battleground.Chamber3.Spawns.North`.

## Pacing

Story first, then fighting.

1. **Arrival** — black screen, the title, then the player is standing inside the
   gate with the castle already around them.
2. **Chambers 1–2** — storyteller NPCs. What happened here, told by people who
   were here. No enemies yet.
3. **Chambers 3–8** — waves. Another storyteller every third or fourth wave, so
   the story keeps arriving instead of being front-loaded.
4. **Chamber 9** — the last of the story, and where it ends.

## Towers

The towers are generated with full medieval anatomy — batter, machicolations,
bartizans, stair turrets, cross loops, garderobes. See
[TowerAnatomy.md](TowerAnatomy.md) for what each piece is and why it is there.
No two are alike: heights, ruin, roofs and turret positions vary per chamber, so
the two flanks never match and the eye has something to follow.
