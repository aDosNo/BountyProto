# bounty-hunt — Agent Session Protocol

Applies to any agent (Claude, Codex) touching the project. Purpose: keep work
precise across sessions when the scene changes between them.

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
4. **VALIDATE** — headless load the scene; for structural edits verify
   `load_steps == ext_resources + sub_resources + 1`; Python in a sandbox for
   text-level structure checks where available.
5. **REVIEW** — Nick validates with renders / playtest.
6. **WRITE BACK** — corrections and new geometry get reflected into the docs
   in the same session. Stale docs are worse than no docs.

## Canon pointers
- Canonical map: `scenes/maps/HesperusMarket_Blockout.tscn` (also the
  project main scene).
- Reference-only: everything under `levels/hesperus_market/` and
  `docs/level_design/hesperus_market/00..04_*.md` (the generated graybox line).
- Project-wide contracts: `docs/SYSTEMS_IMSIM.md`, `docs/STYLE.md`.

## Tooling constraints (hard-won — do not relearn these)
- `.tscn` editing: `str_replace`/`edit_file` with large oldText blocks is
  UNRELIABLE (editor re-saves break matches). Only reliable method:
  **full-file write_file** via filesystem MCP.
- `load_steps` header must equal ext_resource count + sub_resource count + 1.
- Claude's bash sandbox is ISOLATED from `/var/home/nick/` — use it only for
  computation/code generation; write results through filesystem MCP.
- `godot:run_project` exits without a process handle — unreliable for runtime
  logs. Prefer headless scene loads + structural validation + Nick playtesting.
- Correct project path for filesystem MCP: `/var/home/nick/bounty-hunt/`.
- `Gameplay/Player` transform is the real spawn; `Markers/PlayerSpawn` is not.
