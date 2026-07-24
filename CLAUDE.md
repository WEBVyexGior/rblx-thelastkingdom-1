# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"The Last Kingdom" — a medieval co-op Roblox adventure game (atmosphere, exploration, survival, story). Built in Roblox Studio using Luau. Developer: Cookies11f.

Status: **Phase 2 — Core Systems (in progress).** Phase 1 (design + the dual-place Rojo split) is done. The core backend now exists as code: a two-phase (`Init`→`Start`) service `Loader`, the player/data/save lifecycle, runtime place detection, and the party / match / mission / teleport frameworks — all booting cleanly in both places. Gameplay content (combat, inventory logic, UI, waves) is deliberately deferred to later phases and currently exists as reserved skeletons. Both places build cleanly via Rojo.

## Rojo

This repo uses [Rojo](https://rojo.space) to sync the filesystem into Roblox Studio. Toolchain is pinned via `aftman.toml`.

### Dual-place structure

The experience is **two Roblox places in one universe**, each with its own project file that
**shares** the common `scripts/Shared`, `scripts/Modules`, and `configs` folders:

- `default.project.json` — **Kingdom Hub** (the lobby place; bare `rojo serve` targets this).
- `world.project.json` — **Forgotten Lands** (the gameplay place).

See `docs/Architecture.md` for the full rationale.

Common commands:
- `aftman install` — install the pinned Rojo version (one-time per machine).
- `rojo serve` — live-sync the **Kingdom Hub** (default project); connect via the Rojo Studio plugin.
- `rojo serve world.project.json` — live-sync the **Forgotten Lands** place.
- `rojo build default.project.json -o KingdomHub.rbxlx` — build the Hub place file.
- `rojo build world.project.json -o ForgottenLands.rbxlx` — build the Forgotten Lands place file.

There is no lint config yet (no `selene`/`stylua`). A minimal, dependency-free **test runner** exists for the pure domain modules: in the Studio command bar (server context) run `require(game:GetService("TestService").Tests.TestRunner).run()` — it executes every `TestService.Tests.*.spec` ModuleScript and prints a PASS/FAIL summary. Add `selene`/`stylua` here once introduced.

### Project mapping

Shared by **both** places:

| Folder | Studio location |
|---|---|
| `scripts/Shared` | `ReplicatedStorage.Shared` |
| `scripts/Modules` | `ReplicatedStorage.Modules` |
| `configs` | `ReplicatedStorage.Config` |
| `scripts/Server/Core` | `ServerScriptService.Server.Core` |
| `scripts/Server/Services` | `ServerScriptService.Server.Services` (lifecycle-booted) |
| `scripts/Server/Domain` | `ServerScriptService.Server.Domain` (classes/data — not booted) |
| `scripts/Client/Core` | `StarterPlayer.StarterPlayerScripts.Client.Core` |
| `scripts/Client/Controllers` | `StarterPlayer.StarterPlayerScripts.Client.Controllers` |
| `scripts/Client/UI` | `StarterPlayer.StarterPlayerScripts.Client.UI` |
| `scripts/Tests` | `TestService.Tests` |

Place-specific:

| Folder | Studio location | Place |
|---|---|---|
| `scripts/Server/Hub` | `ServerScriptService.Server.Hub` | Kingdom Hub only |
| `scripts/Server/World` | `ServerScriptService.Server.World` | Forgotten Lands only |
| `models/Hub` / `models/World` | `ServerStorage.Models` | per place |
| `ui/Hub` / `ui/World` | `StarterGui.UI` | per place |

`assets/` (Animations, Audio, Icons, Images, VFX) and `sound/` are **not** synced by Rojo — they hold raw media/reference files (source images, audio, animation data) that get uploaded to Roblox manually via Studio's Asset Manager. Once uploaded, reference the resulting `rbxassetid://` in a `scripts/Shared` or `scripts/Modules` ModuleScript rather than syncing the raw file as an instance.

## Role & Priorities

When acting on this repo, behave as the Lead Roblox Developer:

- Prioritize clean architecture, performance, readable Luau, modular systems, multiplayer compatibility, and scalability.
- Never rewrite existing systems unless explicitly requested.
- When adding a new script, always state which folder it belongs in and why.
- Prefer ModuleScripts over plain Scripts/LocalScripts wherever possible.
- Avoid unnecessary complexity — every system should work independently of the others.

## Phase Workflow

At the **start** of every phase, state up front which place the work targets and the exact command to test it. The two places must never be synced into the same Studio place:

| Place | Project file | Serve command | Studio place file |
|---|---|---|---|
| **Kingdom Hub** | `default.project.json` | `rojo serve` | its own `KingdomHub.rbxl` |
| **Forgotten Lands** | `world.project.json` | `rojo serve world.project.json` | its own `ForgottenLands.rbxl` |

Use **one dedicated place file per project** — never connect a second project into a place already synced from the other, which duplicates the shared `Server` subfolders (Core/Services/Domain). To repoint a place, build a fresh one (`rojo build <project> -o <place>.rbxl`) and open that.

When a phase is **completed**, follow this checklist in order:

1. **Commit** the phase as its own separate commit (clear message; never mix phases in one commit).
2. **Verify** — `rojo build default.project.json` and `rojo build world.project.json` both build clean; run the type-check when available (`luau-lsp analyze`); and confirm the change syncs correctly in Roblox Studio through the Rojo plugin.
3. **Push** to `origin/main` once verified, then confirm local and remote `main` are in sync.
4. **Restart Rojo** only at major checkpoints or when a sync problem appears — not routinely.

## Intended Architecture

```
scripts/
  Client/   - LocalScripts, run per-player (input, camera, client-side UI logic/effects)
  Server/   - authoritative Server Scripts (combat resolution, spawning, save data)
  Shared/   - ModuleScripts usable by both client and server (constants, config, utilities) — synced to ReplicatedStorage
  Modules/  - reusable ModuleScript systems/libraries (inventory, state machines, etc.) required by Client/Server/Shared
  Tests/    - test harnesses for validating modules in isolation

assets/
  Animations/ - animation IDs/data
  Audio/      - sound asset references
  Icons/      - UI icon images
  Images/     - general images/textures
  VFX/        - particle/visual effects

ui/     - UI screens/layouts
sound/  - sound files/config
models/ - 3D models (weapons, buildings, characters)
```

All of the above directories exist but are currently empty (git does not track empty folders, so they aren't yet reflected in the repo history).

## Design Docs

- `docs/Roadmap.md` — phase plan: Planning → Story/GDD → Core Systems → Combat → Inventory → Multiplayer → Polish → Release.
- `docs/Todo.md` — current backlog (finish Game Design, define Story/Lobby/Gameplay Loop/Inventory/Progression).
- `docs/Changelog.md` — version history.
- `docs/Story.md`, `docs/Mechanics.md` — placeholders, not yet written.
- `ideas/GamePlan.md` — brainstorming doc, not yet written.

Check these docs before designing a new system — `Roadmap.md` and `Todo.md` define what phase the project is in and what's actually in scope right now.

## Tooling

`.vscode/settings.json` enables the `luau-lsp` Studio plugin for in-editor Luau linting/autocomplete synced with Roblox Studio.
