# scripts/Server/Hub

Server Services that run **only in the Kingdom Hub** place (e.g. future NPC/shop/party-lobby
services). Synced to `ServerScriptService.Server.Hub` by `default.project.json` (the Hub
place) only.

The server Bootstrap auto-detects this folder and boots whatever Services it contains, so
adding a Hub-only service is just dropping a `*Service.luau` here.

**Empty in Phase 1 by design.** (This README is ignored by Rojo.)
