# The Last Kingdom — Economy, Resources & Monetization (Design)

**Status:** Design only — `configs/Economy.luau` and `configs/Loot.luau` exist as schema
skeletons with **no values**.
**Serves:** `../GameDesignDocument.md` §2 (NOT pay-to-win), §5 (Tier 2 — economy depth).
**Source of truth:** the GDD vision; this is the design-of-record for the economy.

> Migrated here from the old GDD §7 (Resources), §12 (Economy & Rewards), §15 (Monetization).

---

## 1. Resources & gathering

- Resources are gathered in the **Forgotten Lands** (harvest nodes, loot, drops).
- Types (indicative, finalized in config): raw materials, crafting components, currency,
  rare/relic items.
- Resources are **carried out on extraction** and spent in the Hub on upgrades/crafting
  (see `Progression.md`).

## 2. Economy & rewards

- **Earn** (in runs): resources, currency, gear, lore, rare relics.
- **Spend** (in Hub): upgrades, crafting, gear, cosmetics.
- Rewards scale with difficulty and party size (see `Multiplayer.md`) and with optional-content
  completion.
- **Extraction = banking**: rewards are secured on return.

> ⚠️ **Reconcile with GDD.** The old design framed a roguelite *"push deeper vs. extract now"*
> risk/reward hook built on repeatable runs. The current GDD (§3, §4) is a **story campaign**
> across five chapters. Keep extraction-as-banking as a mechanic, but the "endless deeper runs"
> framing must be re-read as **chapter/mission progression**. Confirm the intended model before
> authoring economy values.

## 3. Monetization — anti pay-to-win

Guiding rule (GDD §2): **money buys convenience and cosmetics, never power or unfair
advantage.**

- **Revive (Robux)** is the primary monetized mechanic (see `DeathSystem.md`) and must not
  become pay-to-win. Candidate guardrails (finalized in balance pass):
  - Cooldown / limited uses per run.
  - Diminishing benefit (reduced HP or a temporary penalty on revive).
  - Reward penalty on paid revive (paying trades power for time, not for winning).
  - A **free co-op revive path always exists** (teammates can revive) — paying is a shortcut,
    not a requirement.
- **Cosmetics**: purely visual (medieval skins, banners, emotes) — always allowed.
- **No** purchasable stats, gear power, or resource shortcuts that trivialize progression.

> Sensitive economy data (`Economy.luau`, `Loot.luau`) should move to a **server-only** config
> location before real values land (`configs/README.md`).

## 4. Open questions (lock before real values)

- **Revive economy** — exact anti-P2W formula (cooldown, penalty, reward reduction). (old GDD §21.1)
- **Resource-on-death** — do carried resources drop / partially drop / stay safe on death
  before extraction? (old GDD §21.2)
- **Extraction mechanic** — extraction points, an extraction event, or free return — under the
  story-campaign framing above. (old GDD §21.6)

## 5. Related

`Inventory.md` · `Progression.md` · `DeathSystem.md` (revive) · `Multiplayer.md` (reward scaling) · `../Architecture.md` (§6 persistence)
