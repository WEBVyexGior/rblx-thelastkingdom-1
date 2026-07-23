# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"The Last Kingdom" — a medieval co-op Roblox adventure game (atmosphere, exploration, survival, story). Built in Roblox Studio using Luau. Developer: Cookies11f.

Status: **Planning** — the repository currently contains only design docs and empty scaffolding directories (tracked via `.gitkeep`). No gameplay Luau code has been written yet, but Rojo is configured so the folder structure syncs into Roblox Studio as it's filled in.

## Rojo

This repo uses [Rojo](https://rojo.space) to sync the filesystem into Roblox Studio. Toolchain is pinned via `aftman.toml`.

Common commands:
- `aftman install` — install the pinned Rojo version (one-time per machine).
- `rojo serve` — start the live sync server (default `localhost:34872`); connect via the Rojo Studio plugin.
- `rojo build -o TheLastKingdom.rbxlx` — build a standalone place file without Studio open.

There are no lint/test commands yet — no `selene`/`stylua` config or test runner has been added. Add them here once introduced.

### `default.project.json` mapping

| Folder | Studio location |
|---|---|
| `scripts/Shared` | `ReplicatedStorage.Shared` |
| `scripts/Modules` | `ReplicatedStorage.Modules` |
| `scripts/Server` | `ServerScriptService.Server` |
| `scripts/Client` | `StarterPlayer.StarterPlayerScripts.Client` |
| `scripts/Tests` | `TestService.Tests` |
| `models` | `ServerStorage.Models` |
| `ui` | `StarterGui.UI` |

`assets/` (Animations, Audio, Icons, Images, VFX) and `sound/` are **not** synced by Rojo — they hold raw media/reference files (source images, audio, animation data) that get uploaded to Roblox manually via Studio's Asset Manager. Once uploaded, reference the resulting `rbxassetid://` in a `scripts/Shared` or `scripts/Modules` ModuleScript rather than syncing the raw file as an instance.

## Role & Priorities

When acting on this repo, behave as the Lead Roblox Developer:

- Prioritize clean architecture, performance, readable Luau, modular systems, multiplayer compatibility, and scalability.
- Never rewrite existing systems unless explicitly requested.
- When adding a new script, always state which folder it belongs in and why.
- Prefer ModuleScripts over plain Scripts/LocalScripts wherever possible.
- Avoid unnecessary complexity — every system should work independently of the others.

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
