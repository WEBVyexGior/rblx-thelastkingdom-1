# scripts/Shared/Core — general-purpose primitives (RESERVED)

Reserved home for **low-level, dependency-free, reusable primitives** used anywhere by both
client and server. Synced (as part of `scripts/Shared`) to `ReplicatedStorage.Shared.Core`.

Planned contents (added in the phases that first need them — **empty by design for now**):

| Module | Purpose |
|---|---|
| `Signal` | Lightweight event object (connect/fire/disconnect) — replaces ad-hoc callback lists. |
| `Timer` | Interval/timeout scheduling helper. |
| `StateMachine` | Generic, reusable finite state machine. |
| `Promise` | Async/deferred value handling. |
| `ResourceManager` | Cleanup/lifetime management (Maid/Trove-style) for connections & instances. |

### How this differs from the neighbouring folders

- **`Shared/Core`** (this) — generic primitives, no game knowledge (Signal, Timer, ...).
- **`Shared/Util`** — tiny app-specific helpers (e.g. `Logger`).
- **`Shared/Framework`** — the app bootstrap framework (`Loader`).
- **`Modules`** — larger game-oriented system libraries (inventory data structures, ...).

Until these primitives exist, Phase 2 backend services use minimal local patterns (direct
service references, small transition tables). Those are intended to migrate onto the
primitives above once implemented.

_(This README is ignored by Rojo; it only documents and reserves the folder.)_
