# The nine areas — what actually happens in each

The decisions, as taken. `ChamberThemes.md` says what each chamber *is*;
this says what the player *does* there.

## The law every mechanic obeys

**Solo-first.** The game must be completable by one player. Never a task that
needs two pairs of hands at the same moment.

Scale by **count**, not by **role**:

- Right: four oil jars, six braziers, N waves. One player does four trips; four
  players do one each. Same mechanic.
- Wrong: a capstan two people must turn together. A forge needing a
  bellows-pumper and a striker at once.

Two supporting rules:

- **Progress persists** when the player breaks off to fight. Deliberate
  slip-back is allowed only as tuned pressure one player can still beat.
- **More players = faster, never = possible.** Co-op emerges because it is
  quicker, not because the design forces it.

---

## What all nine share — the gate and the corner

*Built. `Server/World/AreaService`, `Client/UI/AreaHud`,
`Client/Controllers/AreaController`.*

Every chamber already has an arched passage in its cross-wall. A **portcullis**
now hangs in each of the first eight, down at the start of the run and raised
when that chamber's work is done. The ninth has no gate: the way out of the
Keep Steps is the tower.

Why a gate rather than a teleport on completion: a castle you are moved through
is a corridor, a castle whose doors you open is a place. It also teaches the
rule for free — walk into shut iron, turn round, find the room still occupied.

- **The gate is one thing; the condition is nine things.** `AreaService` owns
  the iron and the HUD and nothing else. Each mechanic ends by calling
  `AreaService.clear(index)`. That is what lets nine unrelated puzzles share one
  door.
- **The lift is animated, not switched.** ~3s, smoothstep, with a judder that
  decays to nothing as it lands, and chains that shorten into the masonry above.
  Per the standing requirement: weight, not a part sliding.
- **The visible grille does not collide.** Bars 2.5 studs apart look right and
  would let a character walk straight through, so an invisible slab rides inside
  the grille and does the stopping. Art and rule are separate on purpose.
- **The HUD is bottom-left and nearly silent**: chamber number, its English
  name, one line of flavour. It moves in exactly three cases — arriving,
  crossing a wall, and the gate opening. The left rule is gold when the way is
  open, bordeaux when it is shut.

Geometry is duplicated from `tools/BuildBattleground` (gap 46 wide, springing at
y 26, masonry over the arch from y 48, passage inset 12 from the curtain,
alternating east/west). **If the tool's numbers change, `AreaService`'s copy
must change with them** — nothing else ties the builder to the runtime.

---

## 1 — Έξω Περίβολος · The introduction

The player must be eased in, not dropped into a fight.

**The arrival.** On teleport into the Forgotten Lands the story plays: the
party stands at a distance, sees the castle, and talks about it. Solo, the
single player talks to themselves. Nobody starts swinging before they know
where they are.

**The mechanic.** The passage is barricaded from the inside. Three lash points,
hold-to-cut, and the progress on each one is **kept** when you break off.

**Enemy load.** Not two or three. A real number from the start — enough to
matter, tuned so one player still clears it.

## 2 — Στάβλοι · The winch

*Built. `Server/World/WinchService`.*

The portcullis is down and the crank handle is missing — search the stalls.
Then raise it: it **slips back slowly** when you let go. The slip rate is tuned
so one player beats it by alternating; a second player just makes it quicker.

Slightly harder than area 1. Not much.

**As built:** nine search points (crates, barrels, bales, sacks, chests) scattered
around the stables by the game itself — it raycasts for a floor and rejects
anything already occupied, so nothing is ever placed inside the scenery. One of
them holds the handle and **which one changes every run**. The winch stands at
x −88, z −364: clear of the flanking tower and of the measured road, and 30
studs from the arch, with its rope running up to it.

**The gate is the progress bar.** Turning does not fill a bar on screen — it
raises the actual portcullis, and letting go lowers it. GAIN 0.075 per completed
hold, SLIP 0.022/sec, 0.7s grace after a turn. Alone and unbothered that is
about twenty seconds of work; a ten-second fight costs roughly three holds.
A ProximityPrompt is held per-player, so two people on the same winch make two
turns where one made one — faster, never the difference between possible and
not.

## 3 — Μαγειρεία · The recipe, and the five

Not just oil and fire. A real kitchen, built as a **house** with a cauldron and
heavy detail, and inside it a **papyrus**.

**The papyrus** glows and has an idle animation so the eye finds it. Touch it
or click it and it opens as a UI panel. Papyrus and parchment are a recurring
visual language across the whole game — use them everywhere text is given.

**What it says:** a recipe. Gather the ingredients around the area, cook the
dish, and feed it to the **five zombies** penned nearby. They turn back into
villagers.

**The five.** Three fight in melee, two carry bows. Once cured they **follow
the party for the rest of the run**, through areas 4, 5 and 6, until they die.

When they turn, a villager speaks on screen — the recipe was what they were
trying to save, hoping someone would come who could use it.

## 4 — Κοιμητήριο · Where it turns

Graves open and the dead climb out. Light the braziers; each one lit shuts a
section down for good.

**This is where the game gets harder and more aggressive.** The first zombies
carrying **heavy weapons** appear here.

## 5 — Σιδηρουργείο · The spike

The sharpest jump in the game, and the richest.

**New enemies, first appearance:**

- **Spear zombies** — long reach, slow, on a cooldown. They hit from outside
  sword range.
- **Bow zombies** — the arrow flies fast but **can miss**. Not hitscan. Like a
  Minecraft skeleton: if it hits you, it hit you.

**The forge.** Bellows → the heat gauge fills and **decays over 50 seconds** →
chain in → strike. Three rounds. The only permanent weapon upgrade in the run.
If 50s proves too tight, go to 80.

**The mine**, in one corner: rocks, broken rails, a mine cart, and **gold** on
the ground. Picking it up sends it straight to the backpack.

**The backpack.** Every player has one. Valuables collect into it
automatically. **You only keep what is in it if you win the run.**

**Randomised loot** — area 5 generates different spoils every run.

**The door.** Find oil → find an unlit torch → equip it → carry it to a fire →
it lights → set it by the oil → the door burns open. A prompt near each object
tells you what to do with it.

**Trees and an axe**, also here: chop them for **planks**, which go to the
backpack and are spent in area 6.

## 6 — Μεγάλη Αίθουσα · The siege

**Roof the hall.** The castle currently has no ceiling anywhere; this room gets
one, so it reads as interior.

Very hard. Many more archers and spearmen than anywhere before. They do **not**
throw their spears — melee reach only, or the range balance falls apart.

Board the doors with the **planks carried from area 5**. There is a short
cooldown before the mass spawn, which is the window to board.

## 7 — Τα Σοκάκια · The prisoner

Very hard.

The villager is **tied to a chair**. Untying takes **20 seconds** of held
interaction. If they survive to the end of the run alongside the party, the
whole team gets **+5% gold**.

## 8 — Έσω Περίβολος · The line

The passage is buried; clear it under heavy pressure. The fallen tower is the
only high ground and the dead have to funnel up to it.

This one lives or dies on the AI quality.

## 9 — Σκαλιά · The King, and the way out

**The boss: The King.** Armour, a shield on his back, a sword, and a bow with
arrows. A nameplate above him reads **"The King"** so there is no doubt who
this is. He must feel like a real opponent, not a health bar.

**The tower is sealed** until he dies. When he falls it opens, and an arrow
appears on the ground pointing the way in.

**Inside**, the door to the roof is **locked**. The scribe NPC gives the key —
but only after the player has heard the whole dialogue. Then the door opens and
everyone leaves together.

**The way out.** No gate. A stair inside the tower connects up to the castle's
wall-walk, and a second stair runs down the **back** of the castle into a small
courtyard. That courtyard is where *The Last Kingdom 2* begins.

### Why this does not reopen the escape route

Walls have been sealed from the start: no stair anywhere reaches the wall-walk,
because a player on the wall is a player out of the map. The ending breaks that
rule **deliberately and only at the end**, and it is safe because it is gated
twice over: the tower will not open until the boss is dead, and the roof door
will not open until the dialogue has played. By the time either stair exists,
the run is over.

---

## Standing requirements

**Door mechanisms need real animation.** Not parts sliding sideways. Weight,
movement, a sense that something heavy is shifting.

**Everything matches the castle.** Same stone, same dark timber, same
proportions. Anything new must look like it was always there.

**Length.** The castle currently plays short — under an hour for someone who
knows it. The area mechanics are what turn a walk into a run; each one has to
carry real time, not just a button press.
