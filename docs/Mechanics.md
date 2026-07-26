# Mechanics — moved

The combat and enemy-AI mechanics that used to live here have moved into the per-system design
docs under **`docs/systems/`**:

- **Combat** → [`systems/Combat.md`](systems/Combat.md) — server-authoritative combat core +
  vertical slice + equipment→combat link (Phases 3–4).
- **Enemies & AI** → [`systems/EnemyAI.md`](systems/EnemyAI.md) — enemy roster, encounters &
  waves-as-events, and the AI state machine (Phase 5).

See [`systems/README.md`](systems/README.md) for the full index of system design docs.
