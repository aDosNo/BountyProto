# Hesperus Market Graybox Pass 3 Landmark Audit

Date: 2026-06-09

## Files Changed

- `levels/hesperus_market/scripts/hesperus_market_graybox_builder.gd`
- `levels/hesperus_market/scenes/hesperus_market_graybox.tscn`
- `tools/bake_hesperus_market_graybox_scene.gd`
- `tools/check_hesperus_market_graybox_scene.gd`
- `docs/level_design/hesperus_market/02_GRAYBOX_PASS_3_LANDMARK_AUDIT.md`

## Scene and Builder

- Scene path: `levels/hesperus_market/scenes/hesperus_market_graybox.tscn`
- Builder script path: `levels/hesperus_market/scripts/hesperus_market_graybox_builder.gd`
- Bake tool path: `tools/bake_hesperus_market_graybox_scene.gd`

The locked layout JSON and locked layout contract were not changed.

## Landmark Markers Added Per Section

### S1_DOCK_BAY

- Extraction start beacon.
- Docked ship / landing pad silhouette.
- Customs ramp marker.
- Cargo / crate pocket.
- Catwalk cue to `S1_NORTH_UPPER_A`.
- Maintenance hatch cue to `S1_LOWER_HATCH_A`.
- Return gate cue to `S1_SOUTH_RETURN_A`.

### S2_BOUNTY_BOARD_HUB

- Large bounty board terminal block.
- Terminal base.
- Mission junction floor cross.
- Upper bounty office cue to `S2_NORTH_UPPER_A`.
- Utility hatch cue to `S2_LOWER_HATCH_A`.
- Route signs toward Dock, Main Bazaar, and Side Alley.

### S3_SIDE_ALLEY

- Witness spot marker.
- Clue 2 marker.
- Narrow alley framing blocks.
- Back shop access cue to `S3_EAST_BACKROOM_A`.
- Hidden backroute cue to `S3_EAST_BACKROUTE_A`.
- Fire escape cue to `S3_UPPER_FIREESCAPE_A`.
- Drain hatch cue to `S3_SOUTH_DRAIN_A`.

### S4_MAIN_BAZAAR_STREET

- Center crowd lane marker.
- Side vendor lane markers.
- Clue 1 marker.
- Repeating stall block silhouettes.
- Backroom lane cue to `S4_WEST_BACKROOM_A`.
- Awning / upper route cue to `S4_NORTH_UPPER_A`.
- Utility vent cue to `S4_SOUTH_VENT_A`.
- Front gate cue to `S4_EAST_GATE_A`.

### S5_UPPER_WALKWAY_OVERLAY

- Elevated route identity totem.
- Awning bridge silhouette over bazaar.
- Observation point marker.
- Hanging cable placeholders.
- Dock catwalk connector cue.
- Upper bounty office connector cue.
- Side alley fire escape connector cue.
- Bazaar awning connector cue.
- East balcony connector cue.

### S6_CAPTURE_COURTYARD

- Target area marker.
- Capture zone ring made from simple debug blocks.
- Arena cover/blockout silhouettes.
- Front gate entry cue.
- Back door entry cue.
- Balcony entry cue.
- Lower grate access cue.
- Return shortcut cue.

### S7_RETURN_UTILITY_STRIP

- Lower under-route identity totem.
- Drainage channel marker.
- Return corridor marker.
- Vent shaft placeholders.
- West return cue to Dock.
- Service hatch cues.
- Alley drain cue.
- Bazaar vent cue.
- East return cue from Courtyard.
- Court utility grate cue.

## Route Readability Improvements

- Added route direction arrows and labels for:
  - Dock to Bounty Hub.
  - Bounty Hub to Main Bazaar.
  - Bounty Hub to Side Alley.
  - Side Alley to Backrooms.
  - Main Bazaar to Capture Courtyard.
  - Main Bazaar to Utility Vent.
  - Upper Walkway to Courtyard Balcony.
  - Capture Courtyard to Return.
  - Utility Strip to Dock Return.
- Added route arch/cue geometry at approved ports without adding new ports or exits.
- Added a generated `IdentityMarkers` root to separate landmark silhouettes from locked data markers.
- Added explicit debug material resource names:
  - `DBG_Route_Return_Green`
  - `DBG_Route_Bounty_Yellow`
  - `DBG_Route_Investigation_Blue`
  - `DBG_Route_Upper_Purple`
  - `DBG_Route_Utility_Orange`
  - `DBG_Route_Target_Red`
  - `DBG_Section_Floor_Neutral`
  - `DBG_Wall_Neutral`
  - `DBG_Landmark_White`

## Intentionally Not Added

- No new sections.
- No new ports.
- No new exits, shortcuts, routes, hatches, or ladders.
- No final art.
- No NPCs or enemies.
- No mission, capture, quest, shop, economy, or interactable behavior.
- No route graph changes.
- No section or port renames.

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

Result: passed and wrote the landmark identity pass into the editor-visible scene.

## Unresolved Issues

- Route identity is still graybox-only; silhouettes need viewport review for overlap and readability from player eye level.
- Some long route arrows remain debug guide geometry rather than authored traversal geometry, preserving the locked section bounds.
- Placeholder vertical access still needs a later movement pass to decide whether ramps/ladders require gameplay traversal support.

## Recommended Next Pass

Graybox Pass 4 should be an in-editor route walk. Start from each debug spawn, capture screenshots, verify that section identity and objective direction are readable at eye level, and tune only marker placement, label height, and sightline blockers without changing the locked layout contract.
