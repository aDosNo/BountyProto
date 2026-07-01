# Documentation map

Updated: 2026-07-01.

## Read first

1. `PROJECT_MANIFEST.md` — current implementation and known defects.
2. `HANDOFF_CLAUDE_FABLE_5_2026-07-01.md` — current-session handoff.
3. `SESSION_PROTOCOL.md` — how to audit, change, validate, and write back.
4. `SYSTEMS_IMSIM.md` — current systemic rules and playtest gates.
5. `level_design/hesperus_market_blockout/00_LOCKED_LAYOUT_BLOCKOUT.md` — the
   canonical live map's geometry and route status.

## Authority by document

- `VISION.md`: product direction, not a claim that future districts/generator
  work already exists.
- `STYLE.md`: visual language.
- `PIPELINE.md`: target asset workflow plus explicitly documented migration debt.
- `design/01_TRAIT_FUNNEL_MATRIX.md`: locked funnel design; partly implemented.
- `design/05_INVESTIGATION_LAYER_BRIDGE.md`: current implemented bridge.
- `design/02_CONTRACT_GENERATOR.md`, `03_NEMESIS_LITE.md`, and `04_ECONOMY.md`:
  future-system designs with current hooks/status called out.
- `level_design/01_VERTICALITY_PLAN.md`: current verticality status and remaining
  playtest work.

## Reference-only branch

Everything under `docs/level_design/hesperus_market/` documents the generated
seven-section graybox branch under `levels/hesperus_market/`. It is retained as
design/reference history and for its validator, but it is not the live map and
its coordinates are not authoritative.

If documentation conflicts, the live scene/scripts win. Update the current-state
docs in the same session; preserve dated audit records as historical snapshots.
