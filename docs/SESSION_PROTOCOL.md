# bounty-hunt — Agent Session Protocol

Applies to any agent (Claude, Codex) touching the project. Purpose: keep work
precise across sessions when the scene changes between them.

Current-state entry point: `docs/README.md`. Last reconciled 2026-07-01.

## Roles
- Layout and design decisions: Nick. Course-corrections arrive via top-down
  renders and first-person screenshots mid-session — build, then adjust.
- Implementation, wiring, structural scene work, bug fixes: agent.
- Agents never add zones, exits, routes, or redesign spaces unprompted.

## Every-session loop
1. **AUDIT** — read the live `.tscn` (and relevant scripts) before building.
   Never trust memory or prior-session summaries; the scene drifts
   (Codex edits, editor re-saves regenerating UIDs/unique_id/float rounding).
2. **DIFF** — compare reality against
   `docs/level_design/hesperus_market_blockout/00_LOCKED_LAYOUT_BLOCKOUT.md`
   and `docs/SYSTEMS_IMSIM.md`. Surface discrepancies to Nick before building.
3. **BUILD the delta only.** Match `docs/STYLE.md` conventions.
4. **VALIDATE** — headless load the scene and run tests for the touched slice.
   If a text scene declares `load_steps`, verify
   `load_steps == ext_resources + sub_resources + 1`; the live Hesperus scene
   currently omits `load_steps`, which Godot permits. Use the locked-layout
   validator only for the generated reference branch.
5. **REVIEW** — Nick validates with renders / playtest.
6. **WRITE BACK** — corrections and new geometry get reflected into the docs
   in the same session. Stale docs are worse than no docs.

## Canon pointers
- Canonical map: `scenes/maps/HesperusMarket_Blockout.tscn` (also the
  project main scene).
- Reference-only: everything under `levels/hesperus_market/` and
  `docs/level_design/hesperus_market/` (the generated graybox line).
- Current implementation: `docs/PROJECT_MANIFEST.md`.
- Project-wide contracts: `docs/SYSTEMS_IMSIM.md`, `docs/STYLE.md`,
  `docs/PIPELINE.md`.

## Tooling constraints (hard-won — do not relearn these)
- Re-read the exact `.tscn` region before a text edit. Editor re-saves can change
  UIDs, unique IDs, ordering, and float formatting, invalidating stale patches.
- If `load_steps` is present, it must equal ext-resource count plus sub-resource
  count plus one. Do not add it merely to satisfy a checker.
- Tool filesystem visibility varies by session. Confirm access to
  `/var/home/nick/bounty-hunt/` instead of assuming a specific sandbox layout.
- Prefer headless scene loads and targeted scripts for repeatable validation;
  runtime feel and visibility still require Nick's first-person playtest.
- Correct project path for filesystem MCP: `/var/home/nick/bounty-hunt/`.
- `Gameplay/Player` transform is the real spawn; `Markers/PlayerSpawn` is not.
- Preserve the dirty tree. Do not delete or reset generated/source assets merely
  because they are untracked.
