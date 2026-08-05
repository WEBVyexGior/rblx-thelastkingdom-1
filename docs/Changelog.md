# Changelog

## Version 0.14.0 — Area 2's winch

- **`Server/World/WinchService`**: the portcullis out of the Stables is down and the
  winch has lost its handle. Nine search points — crates, barrels, bales, sacks,
  chests — are scattered around the stables **at runtime**: the service raycasts for a
  floor, rejects anything above ward level (a ray dropped over the stables lands on the
  roof), rejects anything overlapping existing geometry, and keeps 20 studs off the
  measured road. One holds the handle and which one changes every run.
- **The gate is the progress bar.** `AreaService.setOpenFraction(index, f)` (new) lets a
  mechanic drive the grille directly. Turning the winch raises the real portcullis a
  fraction at a time and letting go lowers it — no bar on screen, and the slip-back
  hurts in a way a number could not. GAIN 0.075 per hold, SLIP 0.022/sec, 0.7s grace.
- **Solo-first**: alone and unbothered it is ~20 seconds of work; a ten-second fight
  costs about three holds. A `ProximityPrompt` is held per player, so two people on the
  same winch produce two turns where one produced one — faster, never the difference
  between possible and not.
- **Plain words** everywhere on screen: "Look around", "Keep going", "Kill them all",
  "Cut the ropes — 2 left", "Find the winch handle", "Turn the winch". The prompt on the
  barricade says Rope, not Lashing.
- **`tools/SurveyArea2`** replaces `tools/BuildStables` (deleted). It measures rather
  than computes: the real road in ten z-slices, the real bounds of the user's own
  `Horse Stable`, and everything else standing in the chamber. The stable range I built
  from `BuildChambers`' constants landed on the road; every position in `WinchService`
  came from this survey instead.

## Version 0.13.0 — The HUD gets quiet, the world gets loud

Playtest feedback, applied. The screen was shouting and the props were greyboxes.

- **Bug**: `ArrivalService` asked `GameService.getPlaceRole()` in **Init**, and the Loader
  runs Init alphabetically — so it asked before GameService had answered, got `Unknown`,
  and did nothing. No log line, and the player kept spawning inside the gatehouse. The
  check is gone: `Server/World` only syncs into the Forgotten Lands, so the file existing
  IS the place check.
- **No more waypoint beams.** `Server/World/Beacon` is deleted. A pillar of light over
  the objective turns a castle into a checklist, and the gold read as neon. The area name
  says where you are, one line at the top says what to do, and the world has to carry the
  rest.
- **`AreaHud` v2** — bottom left, bare screen: white name, 2px black outline, nothing
  else. No panel, no status, no "locked". Two labels swap so a room's name can leave while
  the next arrives, with a hairline rule sweeping under it.
- **`Client/UI/ObjectiveHud`** (new) — one small white line at the top, typed a character
  at a time, no panel behind it. Sources push and clear by name and the newest live one
  shows, so an area mechanic can take the line and the mission's line comes back when it
  finishes. `Net` +`ObjectiveHint`; objective defs gain a short `hint`.
- **`AreaService.onEnter(index, fn)`** — the invisible barrier. An area's content starts
  when a player first walks into it, once per run. No trigger part: the position poll
  already knows, and it catches players who spawn past a line, are put down by a
  checkpoint, or clip a corner at speed.
- **The barricade is built like a barricade.** Rope is now turns of cord passing right
  around the beam — eight tangent segments per turn, jittered, nine turns per lashing,
  falling three at a time as it is cut — with frayed tails and an eight-segment iron ring.
  Boards get a facing plank, six nails each and a split end. The lashing's height is
  DERIVED from its board instead of hand-written; the first version had one wrapping thin
  air a stud above the plank it was holding. The highlight is a pale warm edge, not gold.

## Version 0.12.0 — Area 1's mechanic, and somewhere to land

- **`Server/World/ArrivalService`**: the place had **no SpawnLocation at all** — deleted
  by hand at some point, most likely, since it is invisible and non-colliding. Roblox's
  fallback is to drop the character near the world origin, and this map's origin is the
  middle of the gatehouse arch, so the player spawned standing on the gate every time
  with nothing in the log to say why. The spawn is now created at boot from the pad's own
  geometry, so it cannot be deleted again, and the service sweeps the landing box and
  names anything solid standing in it.
  (The previous guess — the fallen gatehouse doors — was wrong; `FixArrival` reported
  `z 8 -> 8`, i.e. it moved nothing. The doors are better placed now regardless.)
- **`Server/World/BarricadeService`** — Area 1 per `systems/AreaPlan.md`: heavy timber
  lashed across the portcullis, **three bindings, three cuts each**, `ProximityPrompt`
  hold-to-cut. Each completed cut is banked and a turn of rope falls away, so breaking
  off to fight costs at most the 1.6s in progress — never the binding. Solo-first: three
  bindings, one pair of hands; more players is faster, never *possible*. Cut all three
  and the timber comes down and `AreaService.clear(1)` raises the gate.
  Each binding wears a `Highlight` (AlwaysOnTop) so it is findable through the timber,
  and the barricade carries a beacon counting down the bindings left.
- **`AreaService`** exposes `passageOf(index)` / `gateModel(index)` so a mechanic can
  build onto the gate instead of keeping its own copy of the castle's dimensions.

## Version 0.11.1 — Wayfinding, and two things the first playtest found

The castle's first real playtest failed on one thing, and it was not combat: the
player did not know where to walk.

- **Bug (silent, and the cause of most of it)**: `MissionRuntimeService` assigned
  `objective.def.position` — which configs write as a marker NAME — straight to
  `Part.Position`, throwing `Vector3 expected, got string` on every objective and
  leaving Chapter 1 with no waypoint at all. It now goes through `Markers.resolve`,
  the same call `ObjectiveTrackers` already used.
- **`Server/World/Beacon`**: a reusable "go here" — a 70-stud neon shaft, two ground
  rings pulsing outward, rising motes, a point light, and a nameplate that draws
  THROUGH walls (`AlwaysOnTop`), so it survives a building being in the way. All
  parts are `CanQuery = false`: a waypoint must never eat an arrow or a sword swing.
  Objectives label it by kind (`GO HERE` / `SEARCH` / `HOLD HERE` / …).
- **`AreaService`** lights a `THE WAY ON` beacon in front of a passage the moment its
  chamber is cleared, and puts it out on `lock`. Deliberately dark while locked — the
  objective owns the player's eye until it is done.
- **Bug (arrival)**: the two gatehouse doors were placed 30 and 46 studs *past* the
  gate, flat across the arrival pad, so the player spawned standing on one. Moved
  into the archway where "off their hinges in the passage" actually means it.
  `tools/BuildBattleground` carries the new numbers; **`tools/FixArrival`** applies
  the same move to an existing place without a rebuild, then sweeps the spawn box
  and names anything else standing in it.

## Version 0.11.0 — Area gates & the corner HUD

The nine decorated chambers become a **run**: the way forward is shut until the room
is done, and the player can always see which room that is.

- **World**: `Server/World/AreaService` builds a real portcullis into each of the first
  eight passages — bars, spikes, ties, guide runners, a threshold sill, and chains that
  shorten into the masonry as the gate rises. The lift is a ~3s smoothstep with a
  decaying judder, not a tween of a part sideways. The visible grille is non-colliding;
  an invisible slab inside it does the stopping, because 2.5-stud bar gaps do not stop a
  Roblox character.
- **API**: `clear(index)` / `lock(index)` / `isCleared` / `areaOf(player)` / `resetAll()`.
  The service owns the gate and the HUD and deliberately **not** the win condition —
  each area's mechanic calls `clear` when its own puzzle is done.
- **Client**: `Client/UI/AreaHud` (bottom-left panel: chamber number, English name, one
  status line; gold rule open, bordeaux shut, a single gold flourish when the gate goes
  up) driven by `Client/Controllers/AreaController`, which stands down outside the
  Forgotten Lands.
- **Contract**: `Net` +`AreaEvent`.
- **Geometry**: `AreaService` duplicates `tools/BuildBattleground`'s numbers (gap width,
  springing height, span underside, passage inset, the east/west serpentine). Changing
  one now requires changing the other.

Nothing calls `clear()` yet — the per-area mechanics land next. `DEV_OPEN_ALL` in
`AreaService`, or `require(...AreaService).clear(n)` from a **server** command bar,
walks the castle in the meantime.

## Version 0.10.0 — Death System

Death = WHAT HAPPENS WHEN YOU FALL. A foundational death/revive loop wired into the mission
run. Placeholder feedback (prints), no UI/camera polish:

- **Contract**: `Shared/Death/Enums` (Choice: Lobby/Revive/Wait; Status); `Net` +`DeathEvent`
  / `RequestDeathChoice`.
- **Domain (pure, tested)**: `DeathGroup` — wipe / reviver-available / waiting-group rules
  (`DeathGroup.spec`).
- **World**: `DeathService` owns respawn (`CharacterAutoLoads` off in the World) + death status;
  detects death via `CombatService.EntityDied` (once per life); drives PARTY-AWARE choices
  (solo: Lobby + Revive; party: also Wait), the spectate window, free teammate proximity revive,
  self-revive (gold, anti-P2W: cost / cooldown / reduced HP), and run-over.
- **Integration**: `MissionRuntimeService` registers the run's players (`DeathService.beginRun`,
  guarded against re-entrant/stale fails via a run id) and fails the mission on a run-over. There
  is NO auto-restart — players respawn idle and a manual Play Again (`RequestPlayAgain`) restarts
  the chapter. Self-revive spends gold from the persistent profile.
- **Client**: minimal `DeathController` (prints choices, keys 1/2/3).
- **Content/config**: `Economy.Revive` + `Settings.Death`; dev starter gold
  (`Settings.Dev.StarterGold`) so solo self-revive is testable.

Resolves slice tech debt: player death now has real consequences and choices. Robux revive,
diegetic UI, and real Hub teleport are follow-ups.

## Version 0.9.0 — Progression & Rewards + Persistence

Progression = WHAT THE PLAYER EARNS. A real reward pipeline over durable saves; missions and
encounters now grant currency and XP. Placeholder values, no UI:

- **Domain (pure, tested)**: `Progression` (XP -> levels from the Experience curve, +
  `Progression.spec`); `ProfileSchema` v2 adds `xp`/`level` with a v1->v2 migration
  (`ProfileSchema.spec` extended); `DataStoreStore` — a real DataStoreService-backed `Store`
  (pcall + retry).
- **Service**: `RewardService` grants currency + XP (via Progression) into the persistent
  profile — server-authoritative, with level-ups.
- **Persistence**: `SaveService` injects `DataStoreStore` when enabled + available
  (`FeatureFlags.UseDataStore`), else keeps the in-memory mock (Studio without API access) —
  same `Store` interface, no other change. Load/save/autosave/close lifecycle already existed.
- **Content**: `configs/Experience` (XP curve, MaxLevel 10), `configs/Economy` (`gold`);
  Chapter 1's mission and its `Clear` objective carry real `reward` values.
- **Integration**: `MissionRuntimeService` applies a mission's `reward` on completion AND any
  objective's `reward` on objective complete (so encounters reward too); results stream to the
  `MissionEvent` feed and print via `MissionController`.

Resolves slice tech debt: rewards are real (currency + XP into the profile) and persistence is
a real DataStore backend, not a mock. Cross-place session locking remains tracked tech debt.

## Version 0.8.0 — Encounter / Wave System

A reusable, data-driven encounter framework: the Mission System decides WHEN an encounter
starts, the Wave System decides HOW it runs. Placeholder content, no UI/VFX:

- **Data**: `configs/Encounters.luau` (spawn points + waves + groups) and `Shared/Wave`
  (Enums, Types); `configs/Difficulty` (player-count scaling) and `configs/Waves` (global
  defaults) filled; `configs/Enemies` +elite (`undead_brute`) +boss (`fallen_champion`).
- **Domain (pure, tested)**: `EncounterRun` — sequential/parallel wave progression, wave
  clearing, completion/fail (+ `EncounterRun.spec`).
- **World runtime**: `WaveService.startEncounter(id, ctx)` spawns via `EnemyService`, tracks
  deaths via `CombatService.EntityDied`, advances waves (rest between), applies difficulty
  scaling (count + health + elite substitution), and cleans up. `Shared/Scaling` reads
  `configs/Difficulty`.
- **Integration**: new `Clear` objective (`encounterId`) -> `ObjectiveTrackers.Clear` ->
  WaveService; wave/kill progress streams to the `MissionEvent` feed. `EnemyService.spawn`
  gained a health-scaling argument.
- **Chapter 1** moved from a flat 3-dummy spawn to a real 2-wave encounter
  (`chapter_one_ambush`, with an elite in wave 2).

Clean seam for level design: drop encounters into `configs/Encounters.luau` and reference them
from missions — no new code. Resolves the "objective spawns call EnemyService directly" debt.

## Version 0.7.0 — Mission & Objective System

Data-driven missions, objectives, and chapters replace the hardcoded Chapter 1 slice — the
former slice is now content, not code. Placeholder text only, no UI/VFX/polish:

- **Data**: `configs/Missions.luau` (ordered objectives + narrative + symbolic reward) and
  `configs/Chapters.luau` (ordered mission ids); shared contract in `Shared/Mission` (Enums:
  Reach/Kill/Survive/Defend/Escort/Interact; Types).
- **Domain (pure, tested)**: `Objective` and `MissionRun` (sequential activation, completion,
  failure) + specs `Objective.spec`, `MissionRun.spec`.
- **World runtime**: `MissionRuntimeService` (mission -> live run, drives a `Match`, streams a
  `MissionEvent` feed), `ObjectiveTrackers` (Reach/Kill/Survive/Interact full; Defend/Escort
  foundational with a neutral NPC), `ChapterService` (auto-plays a chapter; flag `EnableCampaign`).
- **Integration / refactor**: `MissionService` loads + validates the configs (and chapters);
  `EnemyService.spawn(enemyId, position)` generalised from the hardcoded dummy; `Net`
  `SliceNarrative` -> `MissionEvent`; client `NarrativeController` -> `MissionController`.
- **Removed** the hardcoded slice: `ChapterOneSliceService`, `ChapterOneSliceFlow` (+ spec),
  `configs/ChapterOneSlice.luau`, `NarrativeController`. Chapter 1 plays identically, from data.

Resolves slice tech debt: objectives are data (not baked into an orchestrator) and the run
uses the `Match` lifecycle. Reward stays symbolic until the Progression milestone.

## Version 0.6.0 — Chapter 1 Vertical Slice (integration)

The first playable end-to-end loop, proving the foundations connect. DEV/TEST scaffolding
and placeholder text only — no new gameplay systems, no UI/VFX/animations:

- **ChapterOneSliceService** (`Server/World`, Forgotten Lands only): an ORCHESTRATOR over
  existing public APIs (never their internals). Per-player flow: Spawn -> Story Intro ->
  Exploration -> Lore -> Objective -> Undead Encounter -> Combat -> Reward -> End.
- **Pure state machine** extracted to `ChapterOneSliceFlow` (`Server/Domain`) — ordered
  states + legal single-step transitions, validated on every advance. Spec:
  `Tests.ChapterOneSliceFlow.spec`.
- **Exploration**: visible placeholder markers + server-side distance detection.
- **Encounter**: reaching the objective spawns scripted undead via the existing
  `EnemyService` (reuses the `training_dummy` block); the always-on test dummy is now off.
- **Completion**: encounter deaths tracked through `CombatService.EntityDied` -> symbolic
  reward -> end -> marker cleanup. The intro is start-once and survives respawn.
- **Networking / config**: one server->client remote `SliceNarrative` (client
  `NarrativeController` prints beats — no UI); `configs/ChapterOneSlice.luau` (placeholders)
  + `Settings` flag `EnableChapterOneSlice`.

No existing system was modified beyond additive hooks (a `Net` remote, `Settings` flags).
Slice hardening (real reward, multiplayer, Match/Mission integration) is tracked in `Todo`.

## Version 0.5.0 — Phase 5: Enemy AI Foundation

The enemy AI architecture (foundation only — no waves, spawning system, pathfinding, bosses,
abilities, or optimisation):

- **EnemyBrain** (`Server/Domain/AI`): a pure, testable state machine — Idle → Chase → Attack
  → Return → Dead — deciding state from perceived distances only. Easy to extend.
- **EnemyAIService** (`Server/World`): drives each enemy per `Heartbeat` — perceive (nearest
  player via `CombatService`) → decide (brain) → actuate. Movement is simple **kinematic**
  (`PivotTo` toward target/spawn, no pathfinding). Attacks go **through the existing
  `CombatService.applyDamage`** — no duplicate combat logic.
- **Config-driven**: detection / attack / leash / arrival radii, move speed, attack cooldown
  and damage come from a new `AI` block in `configs/Enemies` (placeholder tuning). Nothing is
  hard-coded.
- **EnemyService**: one additive `EnemyAIService.attach(...)` call on spawn (no-op for enemies
  without an `AI` block). The dummy rig is unchanged.
- **Tests**: `EnemyBrain` spec covering every transition.

`CombatService` is untouched; enemy damage reuses the same authoritative path as the player's
melee. The training dummy now detects, chases, and attacks the player (and is still killable).

## Version 0.4.0 — Phase 4: Inventory & Equipment Foundation

The item / inventory / equipment base, wired into the combat slice (no UI, loot, crafting,
shops, or balancing):

- **Items config**: `configs/Items.luau` — the item catalog (structure/metadata). Weapon
  items link to their combat stats in `Weapons.luau` via `WeaponId`.
- **Domain**: `Inventory` (item instances, uids, capacity) and `Equipment` (per-slot equipped
  instances) — pure classes in `Server/Domain/Inventory`.
- **Services** (`Server/Services`, shared): `InventoryService` (fleshed out from its skeleton
  — add/remove/get, item-id validation) and new `EquipmentService` (equip/unequip, plus
  `getEquippedWeaponId` for the combat layer). Per-player in-memory state; profile
  serialization is a deferred follow-up.
- **Shared contract**: `Shared/Inventory` `Enums` (ItemCategory, EquipmentSlot) and `Types`.
- **Combat connection**: `MeleeCombatService` now reads the attacker's **equipped** MainHand
  weapon (no hard-coded `starter_sword`); `PlayerCombatService` grants + equips a starter
  weapon on entering the World (dev flag). Weapon stats still come from `configs/Weapons`.
- **Tests**: `Inventory` and `Equipment` domain specs.

`CombatService` and the authoritative combat flow (validation, hit detection, `applyDamage`)
are unchanged — only the melee weapon *source* moved to equipment.

## Version 0.3.1 — Phase 3: Combat Vertical Slice

Wires the combat foundation to real gameplay end-to-end (player swing → server validation →
enemy damage → death). No inventory, AI, waves, VFX, animations, or balanced values:

- **Player → CombatEntity**: `PlayerCombatService` (World) registers each player's character
  as a CombatEntity on spawn; `HumanoidAdapter` mirrors the authoritative `Health` onto the
  character's `Humanoid` (Health stays source of truth).
- **Enemy → CombatEntity**: `EnemyService` (World, generic for undead/animals/bosses/NPCs)
  spawns and registers enemies; ships a TEST training dummy behind `EnableCombatTestDummies`.
- **Server-authoritative melee**: `MeleeCombatService` validates the swing (attacker alive,
  per-player cooldown), performs server-side range + arc hit detection, and applies damage
  via `CombatService`. The client sends only intent + aim — never targets or damage.
- **First remotes**: `Shared/Net` declares `RequestMeleeAttack` (client→server, validated)
  and `CombatEvent` (server→client feedback); `CombatController` (client) sends the intent.
- **Additive only**: `CombatService` gained one read accessor (`getAllEntities`); `Net` now
  waits for the Remotes folder on the client so lookups are replication-safe.
- **TEST placeholders**: `starter_sword` (Weapons), `training_dummy` (Enemies), and the
  `Combat` block/flags (Settings) — not balanced values.

`ZombieService` untouched (stays the future undead-content layer over the generic `EnemyService`).

## Version 0.3.0 — Phase 3: Combat Foundation

The server-authoritative combat core for the Forgotten Lands (no weapons, enemies, or
balancing values — foundation only):

- **CombatService** (`Server/World`, Forgotten Lands only): the single authoritative damage
  entry point. Owns an entity registry (id ↔ entity, model ↔ entity for hit lookup),
  validates every hit (alive / i-frames / faction), resolves through the pipeline, applies it,
  and emits `DamageDealt` / `EntityDied` signals.
- **Damage system**: `DamagePipeline` — a pure, ordered modifier chain (empty by default) so
  armor, resistances, crits, and abilities extend it later without touching the core.
- **Entity / target handling**: `CombatEntity` — a generic combatant (players, undead,
  animals, bosses, NPCs, traps all share it) with faction, stats, and i-frames; instance→entity
  resolution walks a hit part up to its registered model.
- **Health system**: `Health` — server-authoritative current/max with clamping, latched death,
  and `Changed` / `Died` signals; decoupled from Humanoids/replication.
- **Shared contract**: `Combat.Enums` (DamageType, Faction, CombatState) and `Combat.Types`;
  plus a minimal `Core/Signal` primitive.
- **Config structure** (schemas only, no values): new `Combat.luau`; enriched `Weapons.luau`
  and `Enemies.luau` schemas (generic — enemy *archetype* is data, not a faction).
- **Tests**: `Health`, `CombatEntity`, `DamagePipeline` specs via the existing runner.

No new remotes this phase — the client-facing bridge is added with the HUD/VFX feature. No
Phase 2 systems changed.

## Version 0.2.0 — Phase 2: Core Systems

The server/client backend framework is implemented (no gameplay content yet — see the
reserved skeletons at the end):

- **Boot framework**: a shared, two-phase (`Init` → `Start`) `Loader` that boots modules
  deterministically and isolates failures; a scoped `Logger`.
- **Server core**: a place-aware server `Bootstrap` that boots the shared Services plus the
  place-specific `Hub`/`World` folder, and a per-player client `Bootstrap`.
- **Player & persistence ("Save Architecture")**: `PlayerService` (join/leave lifecycle +
  runtime `PlayerSession`), `DataService` (in-memory profile cache), `SaveService` (autosave +
  save-on-close over a pluggable `Store` — an `InMemoryStore` mock, so **no real DataStore is
  touched yet**), and a versioned `ProfileSchema`.
- **Run frameworks**: `PartyService`/`Party`, `MatchService`/`Match` (validated lifecycle
  state machine), `MissionService`/`Mission` (empty registry by design), and `TeleportService`
  (safely no-ops while the places are unpublished). `GameService` detects Hub vs. Forgotten
  Lands at runtime.
- **Shared contracts**: `Net` remote registry (zero remotes declared by design), the typed
  `Config` accessor, `Constants`, and `Types`.
- **Reserved skeletons for later phases**: `InventoryService`, `QuestService`, `ZombieService`,
  and the `Input` / `Camera` / `UI` / `Audio` client controllers.

Both places build cleanly (`rojo build default.project.json` and `world.project.json`).

## Version 0.1.0 — Phase 1: Design & Structure

- Authored the Game Design Document and the Architecture document.
- Applied the dual-place Rojo structure: `default.project.json` (Kingdom Hub) and
  `world.project.json` (Forgotten Lands), sharing `scripts/Shared`, `scripts/Modules`, and
  `configs`.
- Added the `configs/` data-driven balancing scaffold (schema skeletons documented in their
  headers; no balance values yet).

## Version 0.0.1

Project initialized.
