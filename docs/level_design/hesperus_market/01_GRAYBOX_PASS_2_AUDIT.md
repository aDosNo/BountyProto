# Hesperus Market Graybox Pass 2 Audit

Date: 2026-06-09

## Source of Truth

- Locked layout doc: `docs/level_design/hesperus_market/00_LOCKED_LAYOUT.md`
- Machine-readable layout: `levels/hesperus_market/layout/hesperus_market_locked_layout.json`
- Layout validator: `tools/validate_hesperus_market_layout.py`

The locked section IDs, port IDs, port coordinates, route colors, connections, section bounds, and floor heights were not changed.

## Scene and Builder

- Scene path: `levels/hesperus_market/scenes/hesperus_market_graybox.tscn`
- Builder script path: `levels/hesperus_market/scripts/hesperus_market_graybox_builder.gd`
- Bake tool path: `tools/bake_hesperus_market_graybox_scene.gd`

The scene is baked after generation so the graybox sections are visible immediately when opening the `.tscn` in the Godot editor. The builder remains attached to regenerate the scene from JSON when run or rebaked.

## Files Changed

- `levels/hesperus_market/scripts/hesperus_market_graybox_builder.gd`
- `levels/hesperus_market/scenes/hesperus_market_graybox.tscn`
- `tools/bake_hesperus_market_graybox_scene.gd`
- `tools/check_hesperus_market_graybox_scene.gd`
- `docs/level_design/hesperus_market/01_GRAYBOX_PASS_2_AUDIT.md`

## Improvements

- Increased floor thickness, wall thickness, and wall height for clearer FPS-scale blockout reading.
- Added wider, more visible route strips and section readability stripes for the Main Bazaar, Side Alley, and Bounty Board Hub.
- Added visible port threshold pads at every approved port without changing port coordinates or route graph.
- Raised and enlarged section and port debug labels for better in-editor readability.
- Added railings and edge guards to Section 5 while preserving approved upper port openings.
- Added vertical supports under Section 5 so it reads as an elevated overlay at `y=6`.
- Added tunnel/utility framing to Section 7 so it reads as the bottom return / utility under-route at `y=-1`.
- Added debug spawn/reference markers:
  - `DEBUG_SPAWN_DOCK_START`
  - `DEBUG_SPAWN_BOUNTY_HUB`
  - `DEBUG_SPAWN_MAIN_BAZAAR`
  - `DEBUG_SPAWN_SIDE_ALLEY`
  - `DEBUG_SPAWN_UPPER_WALKWAY`
  - `DEBUG_SPAWN_CAPTURE_COURTYARD`
  - `DEBUG_SPAWN_RETURN_UTILITY`
- Added placeholder vertical access labels for approved upper, hatch, grate, vent, and drain ports.
- Preserved simple collision on generated floors, walls, route strips, landmark markers, port markers, threshold pads, railings, supports, and debug spawn markers.

## Intentionally Not Added

- No new sections.
- No new ports.
- No new exits, shortcuts, hatches, or routes.
- No NPCs or enemies.
- No capture logic.
- No quest scripting.
- No shops or economy scripting.
- No final art or decorative art pass.
- No changes to route colors or the locked route graph.

## Validation

Command:

```bash
python3 tools/validate_hesperus_market_layout.py --layout levels/hesperus_market/layout/hesperus_market_locked_layout.json --contract docs/level_design/hesperus_market/00_LOCKED_LAYOUT.md
```

Result:

```text
Hesperus Market locked layout validation PASSED
sections=7
ports=36
physically_adjacent_pairs_checked=17
long_route_pairs_skipped=1
```

## Godot Checks

Scene load command:

```bash
/var/home/nick/Downloads/Godot_v4.6.1-stable_linux.x86_64 --headless --path . levels/hesperus_market/scenes/hesperus_market_graybox.tscn --quit
```

Result: passed with no script/load errors.

Scene structure command:

```bash
/var/home/nick/Downloads/Godot_v4.6.1-stable_linux.x86_64 --headless --path . --script tools/check_hesperus_market_graybox_scene.gd
```

Result:

```text
Hesperus Market graybox scene check PASSED
sections=7
ports=36
port_labels_present=true
section5_elevated=true
section7_under_route=true
```

Bake command:

```bash
/var/home/nick/Downloads/Godot_v4.6.1-stable_linux.x86_64 --headless --path . --script tools/bake_hesperus_market_graybox_scene.gd
```

Result: passed and wrote generated graybox nodes into `levels/hesperus_market/scenes/hesperus_market_graybox.tscn`.

## Remaining Readability / Playtest Concerns

- The vertical access elements are still placeholders; an in-game movement pass should confirm whether the current player controller can climb the placeholder ramps/ladders cleanly or needs dedicated traversal handling later.
- Section 7 is framed as a utility under-route and remains walkable as a debug placeholder; crawl-height behavior is not implemented.
- Long connector routes remain debug guide strips only. This preserves the locked bounds, but playtest may reveal where later graybox connector geometry should be authored without changing the route graph.
- Label readability should be checked in a real editor/game viewport, not only through headless validation.

## Screenshots Needed

- Top-down overview showing all seven sections and route colors.
- Eye-level view from `DEBUG_SPAWN_DOCK_START`.
- Eye-level view from `DEBUG_SPAWN_BOUNTY_HUB`.
- Eye-level view from `DEBUG_SPAWN_UPPER_WALKWAY` proving Section 5 elevation and rail/support readability.
- Eye-level view from `DEBUG_SPAWN_RETURN_UTILITY` proving Section 7 under-route readability.

## Next Recommended Pass

Graybox Pass 3 should be an in-editor/playtest pass focused on actual movement feel: walking the route graph, confirming port openings are obvious from both sides, checking stair/ladder placeholder usability, tuning label visibility, and deciding where authored connector geometry is needed for long routes without altering the locked layout contract.
