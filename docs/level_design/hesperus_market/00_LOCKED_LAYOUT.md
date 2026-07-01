# Hesperus Market / Lower Spire Bazaar
## Master Seam Map / Locked Layout

**REFERENCE-ONLY GENERATED BRANCH (reconciled 2026-07-01).** This document is
the source of truth only for `levels/hesperus_market/` graybox generation and
its validator. It is not the source of truth for the live game map. The
canonical map is `scenes/maps/HesperusMarket_Blockout.tscn`; its contract is
`docs/level_design/hesperus_market_blockout/00_LOCKED_LAYOUT_BLOCKOUT.md`.

Do not merge these coordinates or ports into the live map. Preserve this branch
as a historical/reference layout unless Nick explicitly revives it.

---

# 1. Global Rules

## Coordinate / Scale

- 1 Godot unit = 1 meter.
- The level is built as a compact vertical market slice.
- Section placement must follow the locked adjacency rules below.
- Section 5 Upper Walkway is an elevated overlay, not a normal ground-level section.
- Section 7 Return / Utility Strip is the lower under-route connecting the market back toward extraction.

## Route Color Language

- Green = extraction / return
- Yellow = bounty / interactable
- Blue = clue / investigation
- Purple = upper walkway / elevated traversal
- Orange = utility / crawl / vent
- Red = target / capture / danger

## Lock Rules

- No extra sections.
- No extra exits.
- No connector drift.
- No renamed ports.
- No unapproved neighboring connections.
- Every detailed subsection map must obey this document.
- Every generator, validator, and graybox pass must use this document as source of truth.

---

# 2. Locked Sections

There are exactly seven locked sections:

1. `S1_DOCK_BAY`
2. `S2_BOUNTY_BOARD_HUB`
3. `S3_SIDE_ALLEY`
4. `S4_MAIN_BAZAAR_STREET`
5. `S5_UPPER_WALKWAY_OVERLAY`
6. `S6_CAPTURE_COURTYARD`
7. `S7_RETURN_UTILITY_STRIP`

No additional primary sections are allowed.

---

# 3. Locked Global Placement

## Section 1 — Dock Bay

- Position: far west / southwest.
- Purpose: extraction start, dock cargo, customs ramp, first vertical teaching space.
- Direct neighbors:
  - Section 2 Bounty Board Hub
  - Section 5 Upper Walkway Overlay
  - Section 7 Return / Utility Strip

## Section 2 — Bounty Board Hub

- Position: west-center, east of Dock Bay.
- Purpose: mission junction, bounty board terminal, early route hub.
- Direct neighbors:
  - Section 1 Dock Bay
  - Section 3 Side Alley
  - Section 4 Main Bazaar Street
  - Section 5 Upper Walkway Overlay
  - Section 7 Return / Utility Strip

## Section 3 — Side Alley

- Position: below Section 2 and west/southwest of Section 4.
- Purpose: investigation route, witness spot, clue, back shop access, fire escape.
- Direct neighbors:
  - Section 2 Bounty Board Hub
  - Section 4 Main Bazaar Street
  - Section 5 Upper Walkway Overlay
  - Section 6 Capture Courtyard
  - Section 7 Return / Utility Strip

## Section 4 — Main Bazaar Street

- Position: central vertical market canyon.
- Purpose: primary public route, crowd lane, vendor lane, shop/backroom lane.
- Direct neighbors:
  - Section 2 Bounty Board Hub
  - Section 3 Side Alley
  - Section 5 Upper Walkway Overlay
  - Section 6 Capture Courtyard
  - Section 7 Return / Utility Strip

## Section 5 — Upper Walkway Overlay

- Position: elevated overlay across the top/middle of the market.
- Purpose: dock catwalk, upper bounty office access, bazaar awnings, observation route, courtyard balcony.
- This is not a normal ground section.
- Direct neighbors:
  - Section 1 Dock Bay
  - Section 2 Bounty Board Hub
  - Section 3 Side Alley
  - Section 4 Main Bazaar Street
  - Section 6 Capture Courtyard

## Section 6 — Capture Courtyard

- Position: east side of Section 4.
- Purpose: target encounter arena and capture space.
- Direct neighbors:
  - Section 3 Side Alley
  - Section 4 Main Bazaar Street
  - Section 5 Upper Walkway Overlay
  - Section 7 Return / Utility Strip

## Section 7 — Return / Utility Strip

- Position: bottom under-route spanning west to east.
- Purpose: return corridor, service crawl, vents, drains, utility route, post-capture shortcut.
- Direct neighbors:
  - Section 1 Dock Bay
  - Section 2 Bounty Board Hub
  - Section 3 Side Alley
  - Section 4 Main Bazaar Street
  - Section 6 Capture Courtyard

---

# 4. Suggested Section Bounds

These are initial graybox bounds. They can be tuned only if the port contract remains aligned.

Coordinate convention:

- `x` = horizontal west/east axis
- `z` = horizontal north/south axis
- `y` = vertical height

```json
{
  "unit": "meter",
  "sections": {
    "S1_DOCK_BAY": {
      "bounds": { "x": 0, "z": 24, "w": 22, "d": 34 },
      "floor_y": 0,
      "label": "Section 1 — Dock Bay"
    },
    "S2_BOUNTY_BOARD_HUB": {
      "bounds": { "x": 24, "z": 32, "w": 20, "d": 24 },
      "floor_y": 0,
      "label": "Section 2 — Bounty Board Hub"
    },
    "S3_SIDE_ALLEY": {
      "bounds": { "x": 24, "z": 13, "w": 24, "d": 17 },
      "floor_y": 0,
      "label": "Section 3 — Side Alley"
    },
    "S4_MAIN_BAZAAR_STREET": {
      "bounds": { "x": 48, "z": 16, "w": 26, "d": 42 },
      "floor_y": 0,
      "label": "Section 4 — Main Bazaar Street"
    },
    "S5_UPPER_WALKWAY_OVERLAY": {
      "bounds": { "x": 8, "z": 58, "w": 92, "d": 16 },
      "floor_y": 6,
      "label": "Section 5 — Upper Walkway Overlay"
    },
    "S6_CAPTURE_COURTYARD": {
      "bounds": { "x": 78, "z": 22, "w": 28, "d": 36 },
      "floor_y": 0,
      "label": "Section 6 — Capture Courtyard"
    },
    "S7_RETURN_UTILITY_STRIP": {
      "bounds": { "x": 0, "z": 0, "w": 106, "d": 12 },
      "floor_y": -1,
      "label": "Section 7 — Return / Utility Strip"
    }
  }
}
```

---

# 5. Locked Connector Ports

These are the only approved connector ports for Hesperus Market. Subsection maps, graybox generators, route validators, and art passes must preserve these IDs, coordinates, widths, layers, route colors, and reciprocal connections.

```json
{
  "ports": {
    "S1_EAST_GROUND_A": {
      "section": "S1_DOCK_BAY",
      "position": { "x": 22, "z": 43, "y": 0 },
      "width": 4,
      "layer": "ground",
      "route_color": "green",
      "connects_to": "S2_WEST_GROUND_A"
    },
    "S1_NORTH_UPPER_A": {
      "section": "S1_DOCK_BAY",
      "position": { "x": 12, "z": 58, "y": 6 },
      "width": 3,
      "layer": "upper",
      "route_color": "purple",
      "connects_to": "S5_WEST_UPPER_A"
    },
    "S1_SOUTH_RETURN_A": {
      "section": "S1_DOCK_BAY",
      "position": { "x": 10, "z": 24, "y": 0 },
      "width": 4,
      "layer": "return",
      "route_color": "green",
      "connects_to": "S7_WEST_RETURN_A"
    },
    "S1_LOWER_HATCH_A": {
      "section": "S1_DOCK_BAY",
      "position": { "x": 6, "z": 24, "y": -1 },
      "width": 2,
      "layer": "utility",
      "route_color": "orange",
      "connects_to": "S7_WEST_UTILITY_A"
    },

    "S2_WEST_GROUND_A": {
      "section": "S2_BOUNTY_BOARD_HUB",
      "position": { "x": 24, "z": 43, "y": 0 },
      "width": 4,
      "layer": "ground",
      "route_color": "green",
      "connects_to": "S1_EAST_GROUND_A"
    },
    "S2_EAST_GROUND_A": {
      "section": "S2_BOUNTY_BOARD_HUB",
      "position": { "x": 44, "z": 43, "y": 0 },
      "width": 5,
      "layer": "ground",
      "route_color": "yellow",
      "connects_to": "S4_WEST_GROUND_A"
    },
    "S2_SOUTH_GROUND_A": {
      "section": "S2_BOUNTY_BOARD_HUB",
      "position": { "x": 34, "z": 32, "y": 0 },
      "width": 3,
      "layer": "ground",
      "route_color": "blue",
      "connects_to": "S3_NORTH_GROUND_A"
    },
    "S2_NORTH_UPPER_A": {
      "section": "S2_BOUNTY_BOARD_HUB",
      "position": { "x": 34, "z": 56, "y": 6 },
      "width": 3,
      "layer": "upper",
      "route_color": "purple",
      "connects_to": "S5_BOUNTY_UPPER_A"
    },
    "S2_LOWER_HATCH_A": {
      "section": "S2_BOUNTY_BOARD_HUB",
      "position": { "x": 30, "z": 32, "y": -1 },
      "width": 2,
      "layer": "utility",
      "route_color": "orange",
      "connects_to": "S7_BOUNTY_UTILITY_A"
    },

    "S3_NORTH_GROUND_A": {
      "section": "S3_SIDE_ALLEY",
      "position": { "x": 34, "z": 30, "y": 0 },
      "width": 3,
      "layer": "ground",
      "route_color": "blue",
      "connects_to": "S2_SOUTH_GROUND_A"
    },
    "S3_EAST_BACKROOM_A": {
      "section": "S3_SIDE_ALLEY",
      "position": { "x": 48, "z": 24, "y": 0 },
      "width": 3,
      "layer": "backroom",
      "route_color": "blue",
      "connects_to": "S4_WEST_BACKROOM_A"
    },
    "S3_EAST_BACKROUTE_A": {
      "section": "S3_SIDE_ALLEY",
      "position": { "x": 48, "z": 18, "y": 0 },
      "width": 3,
      "layer": "backroute",
      "route_color": "blue",
      "connects_to": "S6_WEST_BACKDOOR_A"
    },
    "S3_UPPER_FIREESCAPE_A": {
      "section": "S3_SIDE_ALLEY",
      "position": { "x": 28, "z": 30, "y": 6 },
      "width": 2,
      "layer": "upper",
      "route_color": "purple",
      "connects_to": "S5_SIDE_FIREESCAPE_A"
    },
    "S3_SOUTH_DRAIN_A": {
      "section": "S3_SIDE_ALLEY",
      "position": { "x": 36, "z": 13, "y": -1 },
      "width": 2,
      "layer": "utility",
      "route_color": "orange",
      "connects_to": "S7_ALLEY_DRAIN_A"
    },

    "S4_WEST_GROUND_A": {
      "section": "S4_MAIN_BAZAAR_STREET",
      "position": { "x": 48, "z": 43, "y": 0 },
      "width": 5,
      "layer": "ground",
      "route_color": "yellow",
      "connects_to": "S2_EAST_GROUND_A"
    },
    "S4_WEST_BACKROOM_A": {
      "section": "S4_MAIN_BAZAAR_STREET",
      "position": { "x": 48, "z": 24, "y": 0 },
      "width": 3,
      "layer": "backroom",
      "route_color": "blue",
      "connects_to": "S3_EAST_BACKROOM_A"
    },
    "S4_NORTH_UPPER_A": {
      "section": "S4_MAIN_BAZAAR_STREET",
      "position": { "x": 61, "z": 58, "y": 6 },
      "width": 4,
      "layer": "upper",
      "route_color": "purple",
      "connects_to": "S5_BAZAAR_AWNING_A"
    },
    "S4_EAST_GATE_A": {
      "section": "S4_MAIN_BAZAAR_STREET",
      "position": { "x": 74, "z": 40, "y": 0 },
      "width": 5,
      "layer": "target",
      "route_color": "red",
      "connects_to": "S6_WEST_FRONTGATE_A"
    },
    "S4_SOUTH_VENT_A": {
      "section": "S4_MAIN_BAZAAR_STREET",
      "position": { "x": 61, "z": 16, "y": -1 },
      "width": 2,
      "layer": "utility",
      "route_color": "orange",
      "connects_to": "S7_BAZAAR_UTILITY_A"
    },

    "S5_WEST_UPPER_A": {
      "section": "S5_UPPER_WALKWAY_OVERLAY",
      "position": { "x": 12, "z": 58, "y": 6 },
      "width": 3,
      "layer": "upper",
      "route_color": "purple",
      "connects_to": "S1_NORTH_UPPER_A"
    },
    "S5_BOUNTY_UPPER_A": {
      "section": "S5_UPPER_WALKWAY_OVERLAY",
      "position": { "x": 34, "z": 58, "y": 6 },
      "width": 3,
      "layer": "upper",
      "route_color": "purple",
      "connects_to": "S2_NORTH_UPPER_A"
    },
    "S5_SIDE_FIREESCAPE_A": {
      "section": "S5_UPPER_WALKWAY_OVERLAY",
      "position": { "x": 28, "z": 58, "y": 6 },
      "width": 2,
      "layer": "upper",
      "route_color": "purple",
      "connects_to": "S3_UPPER_FIREESCAPE_A"
    },
    "S5_BAZAAR_AWNING_A": {
      "section": "S5_UPPER_WALKWAY_OVERLAY",
      "position": { "x": 61, "z": 58, "y": 6 },
      "width": 4,
      "layer": "upper",
      "route_color": "purple",
      "connects_to": "S4_NORTH_UPPER_A"
    },
    "S5_EAST_BALCONY_A": {
      "section": "S5_UPPER_WALKWAY_OVERLAY",
      "position": { "x": 92, "z": 58, "y": 6 },
      "width": 4,
      "layer": "upper",
      "route_color": "purple",
      "connects_to": "S6_NORTH_BALCONY_A"
    },

    "S6_WEST_FRONTGATE_A": {
      "section": "S6_CAPTURE_COURTYARD",
      "position": { "x": 78, "z": 40, "y": 0 },
      "width": 5,
      "layer": "target",
      "route_color": "red",
      "connects_to": "S4_EAST_GATE_A"
    },
    "S6_WEST_BACKDOOR_A": {
      "section": "S6_CAPTURE_COURTYARD",
      "position": { "x": 78, "z": 26, "y": 0 },
      "width": 3,
      "layer": "backroute",
      "route_color": "blue",
      "connects_to": "S3_EAST_BACKROUTE_A"
    },
    "S6_NORTH_BALCONY_A": {
      "section": "S6_CAPTURE_COURTYARD",
      "position": { "x": 92, "z": 58, "y": 6 },
      "width": 4,
      "layer": "upper",
      "route_color": "purple",
      "connects_to": "S5_EAST_BALCONY_A"
    },
    "S6_SOUTH_RETURN_A": {
      "section": "S6_CAPTURE_COURTYARD",
      "position": { "x": 92, "z": 22, "y": 0 },
      "width": 4,
      "layer": "return",
      "route_color": "green",
      "connects_to": "S7_COURT_RETURN_A"
    },
    "S6_LOWER_GRATE_A": {
      "section": "S6_CAPTURE_COURTYARD",
      "position": { "x": 100, "z": 22, "y": -1 },
      "width": 2,
      "layer": "utility",
      "route_color": "orange",
      "connects_to": "S7_COURT_UTILITY_A"
    },

    "S7_WEST_RETURN_A": {
      "section": "S7_RETURN_UTILITY_STRIP",
      "position": { "x": 10, "z": 12, "y": 0 },
      "width": 4,
      "layer": "return",
      "route_color": "green",
      "connects_to": "S1_SOUTH_RETURN_A"
    },
    "S7_WEST_UTILITY_A": {
      "section": "S7_RETURN_UTILITY_STRIP",
      "position": { "x": 6, "z": 12, "y": -1 },
      "width": 2,
      "layer": "utility",
      "route_color": "orange",
      "connects_to": "S1_LOWER_HATCH_A"
    },
    "S7_BOUNTY_UTILITY_A": {
      "section": "S7_RETURN_UTILITY_STRIP",
      "position": { "x": 30, "z": 12, "y": -1 },
      "width": 2,
      "layer": "utility",
      "route_color": "orange",
      "connects_to": "S2_LOWER_HATCH_A"
    },
    "S7_ALLEY_DRAIN_A": {
      "section": "S7_RETURN_UTILITY_STRIP",
      "position": { "x": 36, "z": 12, "y": -1 },
      "width": 2,
      "layer": "utility",
      "route_color": "orange",
      "connects_to": "S3_SOUTH_DRAIN_A"
    },
    "S7_BAZAAR_UTILITY_A": {
      "section": "S7_RETURN_UTILITY_STRIP",
      "position": { "x": 61, "z": 12, "y": -1 },
      "width": 2,
      "layer": "utility",
      "route_color": "orange",
      "connects_to": "S4_SOUTH_VENT_A"
    },
    "S7_COURT_RETURN_A": {
      "section": "S7_RETURN_UTILITY_STRIP",
      "position": { "x": 92, "z": 12, "y": 0 },
      "width": 4,
      "layer": "return",
      "route_color": "green",
      "connects_to": "S6_SOUTH_RETURN_A"
    },
    "S7_COURT_UTILITY_A": {
      "section": "S7_RETURN_UTILITY_STRIP",
      "position": { "x": 100, "z": 12, "y": -1 },
      "width": 2,
      "layer": "utility",
      "route_color": "orange",
      "connects_to": "S6_LOWER_GRATE_A"
    }
  }
}
```
