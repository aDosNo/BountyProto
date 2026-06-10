# Hesperus Market — Blockout Canon Layout
## Source of truth for `scenes/maps/HesperusMarket_Blockout.tscn`

**CANON DECISION (2026-06-09, Nick):** The hand-built blockout at
`scenes/maps/HesperusMarket_Blockout.tscn` is the canonical Hesperus Market map.
The generated graybox at `levels/hesperus_market/scenes/hesperus_market_graybox.tscn`
and its contract (`docs/level_design/hesperus_market/00_LOCKED_LAYOUT.md`) are
**reference material only** — do not extend them, do not merge them, do not treat
their coordinates as authoritative. The blockout was chosen because its scale and
density feel better in playtest.

This document describes the blockout **as it actually exists** (audited 2026-06-09
from the live .tscn), plus explicitly marked TODO route gaps. Any agent (Claude,
Codex, or human) editing the map must read this doc and re-audit the live scene
first — the scene changes between sessions.

---

## Rules

- 1 Godot unit = 1 meter. Coordinates below are world-space.
- Layout decisions belong to Nick. Agents implement; they do not redesign,
  resize, or add zones/exits/routes without an explicit instruction.
- The authoritative gameplay nodes live under `Gameplay/`. The legacy `Markers/`
  and `GameplayRoutePlaceholders/` trees duplicate many of the same positions —
  they are visual/debug aids only. When a position changes, `Gameplay/` wins and
  the duplicates should be re-synced (or deleted in a future cleanup pass).
- `Gameplay/Player` transform is the real spawn. The `Markers/PlayerSpawn`
  marker does NOT drive spawning.
- Update this document whenever geometry, openings, or route affordances change.

## Route color language (inherited from the reference contract)

green = extraction/return · yellow = bounty/interactable · blue = clue/investigation
· purple = upper/elevated · orange = utility/crawl/vent · red = target/capture/danger

---

## The seven zones (as built)

### Z1 — Extraction Dock / Start (far west)
- Footprint: x −71.3 → −59.3, z −21.3 → 3.7. Walk surface y ≈ 3.9 (raised dock).
- `Gameplay/Player` spawn: (−65.92, 4.5, −6.47). `ExtractionZone`: (−65.20, 4.18, 0.07).
- Dressing: dock pylons/ribs, hazard strips, DOCK 07 sign, barrels, neon,
  `SM_DockBay_Floor_ExtractionDock.glb` at (−67.5, 3.9, −6.3).
  `AirShip_Blockout` backdrop mass at x ≈ −89.7.
- Exit east: `DockToBazaarFloor` ramp at (−55.3, 1.38, −13.5) descending toward Z2.

### Z2 — Bounty Board Hub (west-center)
- Centered ≈ (−25, −22). Ground y ≈ −0.15 (top of `AlleyFloor`, a sized
  50×5×100 box at (−29.1, −2.65, 0)).
- `Gameplay/BountyBoard` (scripted, working): (−25.16, 1.25, −22.13), faces south.
  Alcove dressing: side piers, hood, base step, trim, WANTED poster, BOUNTIES → arrow.
- Connections: west ramp up to Z1; south open ground to Z3;
  east `SeamRamp_BoardToStreet` at (0.83, −1.64, −17.3) down to Z4.

### Z3 — Side Alley / Investigation (southwest)
- Roughly x −45 → −25, z 5 → 35. Ground y ≈ −0.15 to 0.15.
- `Clue_02_SideAlley`: (−36.02, 0.15, 28.68). Witness spot/dummy: ≈ (−33, 26).
- Dressing: alley neon, overhead beams, crate stacks, cable bundle,
  `Hesperus_SideAlley_AssembledOnly_WideGap.glb` at (−35.4, 16.8),
  `Hesperus_DockBayCorner_SideAlleyJunction_ModuleSet.glb` at (−32.6, −17.2).

### Z4 — Main Bazaar Street (center)
- Floor plate `BazaarFloor` (sized 50×1×100) at (16.03, −3.33, 0); walk y ≈ −2.83.
  Play space narrowed by `BazaarWestFacade`/`BazaarWestFacade2` (x ≈ −6.75) and
  east facades/buildings; `SM_MarketBuilding.glb`, catwalk kiosk GLB, med-supply
  corner GLB, and the full `hesperus_market_lower_spire_bazaar_blockout.glb`
  street module at (16.9, −2.56, 3.6) carry the street identity.
- `Clue_01_MainStreet`: (29.43, −2.81, 13.93). Ambient sprite NPC at (18.6, −2.45, 9).
- Connections: west seam ramp up to Z2; east `SeamRamp_StreetToEastGround` at
  (43.8, −1.66, 2) up to the East Approach (y ≈ −0.2); north `WalkwayRamp` /
  `BazaarBridge` toward Z5; south `BazaarRamp1`/`BazaarRamp2` at z ≈ 40 toward Z7.

### East Approach (unnumbered connective ground)
- `AlleyFloor2` (sized 100×5×100) at (91.0, −2.7, 0); walk y ≈ −0.2.
  The street between bazaar and courtyard. Patrol guards A/B now genuinely
  patrol here from mission start (sentries, UNAWARE): A paces x 92↔110 at z 2
  (covering the gate approach), B paces (130, 10)↔(124, −14) on the east side
  (its loop brushes the NE corner toward the north-lane entrance). Routes:
  `Gameplay/GuardRoutes/PatrolRoute_A|B` (ordered Marker3D children, same
  contract as KorvaxiEscapeRoute). Courtyard warning neon + courtyard-entry
  neon sign at x ≈ 85.7.

### Z5 — Upper Walkway / Observation (north, elevated)
- Deck y ≈ 11.26. North strip: x −8.6 → 51.4, z ≈ −47 → −42 (`WalkwayNorth`).
  West leg `WalkwayWest` x ≈ −6.4, z −52 → −22. Rails north + inner.
- `Clue_03_UpperWalkway` (reveals target): (12.36, 11.39, −44.58).
  "Target sighting" vantage looks east/southeast toward the courtyard.
- Access: `WalkwayRamp` near (−2.4, −22.2); `WalkwayDescentEast` (31.1, −16.8)
  and `WalkwayDescentEast2` (34.3, −19.5) drop toward bazaar/east side;
  `BazaarBridge` mid-level crossing at y ≈ 6.7, z ≈ −22.3.

### Z6 — Capture Courtyard (east)
- Walled arena: x 86.5 → 137.5, z −24.5 → 16.5. Ground y ≈ 0.05
  (`CaptureFloor2`, sized 52×0.25×42, at (112, −0.075, −4)).
- Gameplay: `KorvaxiTarget` spawn (112.81, 0, −14). Capture zone (112, −4) at the
  fountain. Escape route (ordered Marker3D children under `KorvaxiEscapeRoute`,
  origin x 94.96): world ≈ (104,−13) → (95,−8) → (88.5,0) → (72,1) — i.e. the
  target flees WEST out the front gate toward the bazaar.
  Guards: courtyard (119,−15), balcony (108, 4.8, −22.9), patrols on East Approach.
- Interior: central fountain (collidable base, glow), north stage platform,
  cover ring (5 boxes + 5 PS1 crates), 4 stalls with awnings (retro red/cyan).
- **Entries / im-sim affordances (status matters):**
  | Entry | Where | Status |
  |---|---|---|
  | Front gate + ramp | west wall, z −2 → 2 | WORKS (open, force/social route) |
  | Back door "SHOP BACKROUTE" | west wall, z ≈ 11.5 | VISUAL ONLY — locked StaticBody, no open/lockpick |
  | Utility grate | east wall, (136.9, 2) | VISUAL ONLY — MeshInstance, no opening, no crawl |
  | Roof ladder | east wall, (136.9, −19) | VISUAL ONLY — no climb interaction |
  | Return gate (door+ramp) | south wall, x ≈ 128 | DOOR IS A CLOSED StaticBody — not traversable |
  | North balcony + rope drop | y 4.3, z ≈ −22.9 | **FUNCTIONAL (built 2026-06-09, pending playtest)** — see Balcony access route below |

### Z6 balcony access route (stealth entry, built 2026-06-09)
- Nodes: `WorldGeometry/CourtyardArena/BalconyAccess` (AccessRamp, AccessLanding,
  RampRail_Outer, RampBaseNeon, LandingNeon — purple route markers per color language).
- Path: East Approach → north service lane (between courtyard north wall z −24.5
  and Building13 z −38) → purple-marked scaffold ramp (base x ≈ 125.5, ground
  y −0.2; slope ≈ 22°) → landing at (112, top y 4.55, z −28.6…−25.0) → through the
  pre-existing 4 m gap in the upper north wall (x 110–114) over the lower wall top
  → balcony (top y 4.55) → rail gap (x 110–114) → drop onto stage (y 0.95) → arena.
- One-way by design: no climb back up from the arena side (drop = commitment).
- Existing counterplay: `PressureGuard_Walkway` stands on the balcony at (108, 4.8) —
  now a live UNAWARE sentry facing the arena (back to the wall gap): the stealth
  drop happens behind it, but its 120° cone catches movement on the stage/floor.
- Known polish TODOs: rope drop remains decorative; no guard patrol covers the
  lane itself (PatrolRoute_B brushes the NE corner but does not enter the lane).
  Lane lighting added 2026-06-09 (purple omni at the ramp).

### Z7 — Return Route "The Freight Line" (south band, BUILT 2026-06-09)
- An elevated smuggler's catwalk, gated behind securing the bounty: at extraction
  phase the courtyard ReturnGate door (group `extraction_unlock`) sinks open
  (BountyManager `_open_return_routes()`); its green neon header always signaled it.
- Route (east→west): ReturnGate (128, z 16.5) → existing exterior ramp to ground
  (−0.2) → southwest across the band → FreightRamp (3 wide, ~25°) climbing
  Building21's west face from (24.7, −0.2, 51) to (24.7, 10.43, 73.5) → east
  catwalk strip (x 17–23, y 10.43) → **3.9 m gap jump** (green lip neons both
  sides, slightly downhill westbound; a missed jump drops ~10.6 m onto the new
  SouthBandFloor — time cost, not death) → main corridor (38 m, y 10.21, passes
  over Building8's roof with ~2.5 m clearance) → WestDescentRamp (~25°) down to
  (−47, −0.2, 71.3) → north onto AlleyFloor at Z3's south flank → hub → dock.
- Value: bypasses the bazaar street and East Approach (where alerted guards are).
- New nodes: `WorldGeometry/ReturnRouteZ7` (SouthBandFloor 130×28 top −0.2,
  FreightRamp, WestDescentRamp, 4 green neon markers, RouteLights — 6 green
  omnis along the line + 1 purple lane light for the balcony ramp).
- `ReturnSouthWall` is now VISIBLE (was an invisible active collider — debt
  cleared); bazaar connects south around its ends via BazaarRamp1/2.
- FLAGGED for Nick: legacy red `EscapeNeon` at (22.45, 3.4, 57.5) sits right on
  the climb — red (danger) on a green (return) route; recolor or relocate?
- Playtest: gap-jump distance feel, ramp slopes, whether extraction needs a
  guard posted on the catwalk for pressure.

---

## Three-approaches checklist (the im-sim contract per zone)

A zone is DONE only when stealth, social, and force columns are all real.

| Zone | Force | Social | Stealth | Verdict |
|---|---|---|---|---|
| Z6 Courtyard | front gate ✔ | front gate (disguise TODO) | balcony route ✔ BUILT (pending playtest); door / grate / ladder still visual only | STEALTH ROUTE IN |
| Z4 Bazaar | street ✔ | crowd lane ✔ (NPCs sparse) | upper walkway flank ✔ | PASSABLE |
| Z5 Walkway | n/a (route) | n/a | observation + flank ✔ | DONE for slice |
| Z7 Return | gate route ✔ (opens at extraction) | n/a (route) | catwalk line ✔ BUILT (pending playtest) | BUILT, NEEDS PLAYTEST |

**Priority gap (updated 2026-06-09):** balcony stealth entry is built; needs a
playtest pass (slope feel, drop feel, guard pressure on the balcony). Remaining
visual-only entries: back door (needs lock/key system), utility grate (needs
crawl), roof ladder (needs climb). Next-highest leverage after playtest: disguise
ruling for the social column, or Z7 layout decision.

---

## Known structural debts (do not silently "fix" — surface to Nick first)

1. `WorldGeometry/Floors/DockFloor` uses node scale (12×8×25) on a unit
   BoxShape3D — same fragility as the old WorldFloor issue.
2. Triple-duplicated position data: `Markers/`, `GameplayRoutePlaceholders/`,
   `Gameplay/` — needs a cleanup pass with Gameplay as survivor.
3. `Market_StreetComposition` is an empty Node3D — orphan or placeholder?
4. Bazaar Phase 1 floor dressing (lane dashes, sidewalk pads, manholes, counters)
   from earlier sessions is no longer in the scene — superseded by the GLB street
   module. `HesperusMarket_Blockout.codexbak.tscn` exists if recovery is wanted.
5. Z7 return corridor floats at y ≈ 10.2 with no verified access.

## Clue chain contract (unchanged, verified in scene)

`clue_01_market_trace` (Z4) → `clue_02_side_alley_residue` (Z3) →
`clue_03_upper_walkway_residue` (Z5, `reveals_target = true`).
Escape route nodes: ordered `Marker3D` children directly under `KorvaxiEscapeRoute`.
