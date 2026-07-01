# Hesperus Market — Blockout Canon Layout
## Source of truth for `scenes/maps/HesperusMarket_Blockout.tscn`

**CANON DECISION (2026-06-09, Nick):** The hand-built blockout at
`scenes/maps/HesperusMarket_Blockout.tscn` is the canonical Hesperus Market map.
The generated graybox at `levels/hesperus_market/scenes/hesperus_market_graybox.tscn`
and its contract (`docs/level_design/hesperus_market/00_LOCKED_LAYOUT.md`) are
**reference material only** — do not extend them, do not merge them, do not treat
their coordinates as authoritative. The blockout was chosen because its scale and
density feel better in playtest.

This document describes the blockout **as it actually exists** (reconciled
2026-07-01 from the live `.tscn`), plus explicitly marked TODO route gaps. Any agent (Claude,
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
- Tagged footprint and fiber anchors support runtime evidence variation around
  (−36, 0.15, 28.6) and the witness pocket near (−33, 26).
- Dressing: alley neon, overhead beams, crate stacks, cable bundle. Current live
  scene references use the modular zone GLBs under `assets/blender_models/`,
  with `Hesperus_SideAlley2.glb` superseding the earlier
  `Hesperus_SideAlley_AssembledOnly_WideGap.glb` export. The root-level
  `Hesperus_DockBayCorner_SideAlleyJunction_ModuleSet.glb` remains live at
  (−32.6, −17.2).

### Z4 — Main Bazaar Street (center)
- Floor plate `BazaarFloor` (sized 50×1×100) at (16.03, −3.33, 0); walk y ≈ −2.83.
  Play space narrowed by `BazaarWestFacade`/`BazaarWestFacade2` (x ≈ −6.75) and
  east facades/buildings; `SM_MarketBuilding.glb`, catwalk kiosk GLB, med-supply
  corner GLB, and the full `hesperus_market_lower_spire_bazaar_blockout.glb`
  street module at (16.9, −2.56, 3.6) carry the street identity.
- Tagged trail, fiber, and delivery-counter anchors support runtime evidence
  across the Bazaar. Ambient sprite NPC remains at (18.6, −2.45, 9).
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

### Bazaar Safehouse infill (added 2026-06-22)
- Replaces the opaque `Building24` placeholder near world (50, −0.2, −17)
  without expanding the surrounding footprint.
- Street face: two vendor stalls, broker terminal, visible hunter cache, and
  authored emergency shutters. Rear: utility bypass and service door. Roof:
  exterior ladder, exposed walk, and override terminal.
- Three approaches release one cache: `vendor_staff` at the broker terminal,
  `utility` at the rear bypass, or the unconditional but exposed roof route.
- Cache payoff: heavy-gait bounty intel, 250 CR, and `vendor_staff` access.
- District heat now has visible geometry here: lockdown drops both street
  shutters and removes the broker route while preserving service and roof
  recovery paths.

### North Courtyard Service Street (rebuilt 2026-06-21)
- The former curved courtyard-alley spine was replaced with a straight east-west
  street from x ≈ 52 → 130, centered at z ≈ −32. The primary road is 7 m wide,
  with activity sidewalks on both sides and a south connector near x ≈ 86.
- `Hesperus_AlienBar_CourtyardAlley.glb` retains the established set-piece
  language while using a straight layout: ten detailed multi-story building
  assemblies, stepped rooflines, taller rear towers, windows, awnings, blade
  signs, antennas, cables, an overhead bridge, street floor, sidewalks, the
  alien-bar west gate, and the AccessRamp east threshold. Loose props, NPCs,
  doors, permissions, power state, and traversal remain Godot-owned under
  `EastMicroHub`.
- West→east landmarks: alien bar/package (x ≈ 58), courier/vendor pocket
  (x ≈ 68–80), utility grid room (x ≈ 87), credential checkpoint (x ≈ 104),
  AccessRamp forecourt (x ≈ 126).
- Four approaches share the same destination:
  1. Social: recover the alien-bar package, return it to the courier, receive
     `courtyard_service`, and pass the credential checkpoint.
  2. Stealth/systemic: enter with `utility` access, cut street power, and use
     the checkpoint's fail-open state under reduced lighting.
  3. Vertical: use either western ladder and one continuous exposed upper
     catwalk to reach the existing AccessLanding.
  4. Force: cross the open street through the dedicated guard patrol and cover.
- Six civilians populate the courier pocket; their spacing supports the existing
  two-person crowd-blend rule. Three cover clusters leave a clear central lane.
- The street power grid consistently controls five street lights, the powered
  vendor shutter, and the checkpoint. Cutting power emits noise and therefore
  trades access for guard attention.
- Access tags were normalized to existing project vocabulary:
  `vendor_staff`, `utility`, and earned `courtyard_service`.
- The old procedural freight-catwalk, rear-service, diagonal conduit, and
  multi-roof chain were removed. Their route count was high, but their tactical
  distinctions and spatial readability were weak.

### Holo-Cantina / The Neon Grotto (hero set piece, added 2026-06-30)
- `holo_cantina_arch_shell_v2.glb` replaces the old standalone
  `Hesperus_AlienBar_InteriorHero` at the established north-quarter transform.
  It is now the district's only player-facing bar/cantina.
- The enlarged low-poly asteroid-and-metal shell is deliberately architecture-only:
  public airlock, octagonal combat floor, U-shaped VIP mezzanine, rafter/projector
  grid, full-width basement service layer, rear loading dock/cargo lift, side scaffold/vent
  route, and central coolant rupture line. Furniture, crowds, bottles, posters,
  and movable props remain Godot/sprite-owned future dressing.
- Three route families are spatially explicit: public front airlock, exposed
  scaffold climb into the VIP vent, and rear tech access through the cargo lift
  to the basement. The rock envelope is split around these openings rather than
  serving as decorative route blockers.
- V2 was rebuilt exterior-first in a separate Blender file. Its single connected
  asteroid formation fuses a broad cliff core, asymmetric shoulders, crown
  ridges, rear spine, and front apron before carving the cantina chamber.
- The resulting roughly 57 m-wide shell surrounds the complete metal roof,
  sides, rear wall, and lower level. Three route penetrations are carved through
  it for the facade, dock, and vent.
- The complete stealth scaffold assembly, vertical neon, upper platform, and
  vent frame sit on the visible outer-right asteroid wall.
- Blender exports 46 simple `HC_collision_*` proxy meshes, including an aligned
  walkable ramp over the visible mezzanine stairs. `AutoCollider` now
  supports `collision_proxy_prefixes`, generating physics from those proxies
  while hiding them and excluding visual shell/sign/pipe meshes from collision.
- The existing paid bartender schedule branch is preserved at
  `HC_GAMEPLAY_BAR_CONTACT`; the old arcade bar counter/sign/awning are hidden.
  Structural and live replacement coverage is
  `tools/test_holo_cantina_arch_shell.gd`.

### North Arcade Commercial Arcade (added 2026-06-22)
- Replaces the overlapping north-frontage shells at the western end of the
  service street rather than stacking another building over them. The imported
  alley keeps the road, sidewalks, south frontage and eastern route geometry;
  superseded `ALY_Building_01`, `ALY_Building_02`, `ALY_Shell05_*` and related
  facade pieces are hidden and excluded from generated collision.
- Footprint uses the existing alley-local x≈54–84, y≈38–53 band. Its facade
  begins behind the north sidewalk, keeping the street, courier, powered vendor,
  package and opposite upper-service route clear.
- Ground floor now reads as a generic service vestibule beside the enterable
  pawn/intel shop and implant clinic/courier office. Its former bar counter,
  sign, and awning are hidden so it does not compete with the Holo-Cantina.
- Second floor contains motel/workshop frontage, an overlooking balcony, rear
  corridor, and one complete accessible motel/back-office room reached by an
  internal clinic stair. Other rooms use shallow lit interiors.
- Gameplay pass: the legacy-named
  `HesperusDistrictSystems/AlienBarArcadeActivity` populates the Holo-Cantina
  bar contact plus the arcade pawn shop, clinic, motel office, and service
  circuit with systemic contract-facing interactions. Payoffs include paid
  schedule intel, vendor credentials, scanner-signature intel, target implant
  disruption, roof-route authorization, and an audible service power cut. Covered by
  `tools/test_alien_bar_arcade_activity.gd`; still needs first-person scale,
  readability, and combat-clearance playtest.

### Alien Bar East Backlot (added 2026-06-28)
- Fills the previously empty parcel east/rear of the Alien Bar within
  x≈44..96, z≈−82..−58 without extending the district footprint.
- A worker block, repair/hab block, cantina support annex, and two shallow stalls
  frame an open central court instead of filling it with disconnected slabs.
- Ground circulation remains continuous from the Alien Bar east service side,
  through the backlot court, and east along a marked service lane toward the
  north courtyard-access street.
- A walkable stair at x≈79 rises to y≈4.45 and feeds a narrow bridge along the
  verified-clear z≈−58..−35.5 corridor. It joins
  `EastMicroHub/Generated/ContinuousUpperCatwalk/VendorLanding`, connecting the
  backlot to the courier, utility, credential-ladder, and courtyard routes.
- Structural shell and route geometry are imported from
  `Hesperus_AlienBar_EastBacklot.glb`; mutable gameplay remains Godot-owned.

### Z5 — Upper Walkway / Observation (north, elevated)
- Deck y ≈ 11.26. North strip: x −8.6 → 51.4, z ≈ −47 → −42 (`WalkwayNorth`).
  West leg `WalkwayWest` x ≈ −6.4, z −52 → −22. Rails north + inner.
- The obsolete `UpperWalkwayObservation` evidence anchor was reassigned to a
  visible East Market stall edge. Z5 remains an observation/flank route rather
  than hosting a misleading fiber clue.
- Access: `WalkwayRamp` near (−2.4, −22.2); `WalkwayDescentEast` (31.1, −16.8)
  and `WalkwayDescentEast2` (34.3, −19.5) drop toward bazaar/east side;
  `BazaarBridge` mid-level crossing at y ≈ 6.7, z ≈ −22.3.

### Z6 — Capture Courtyard (east)
- Walled arena: x 86.5 → 137.5, z −24.5 → 16.5. Ground y ≈ 0.05
  (`CaptureFloor2`, sized 52×0.25×42, at (112, −0.075, −4)).
- **Architectural premise (Phases 1–2, completed 2026-06-28):** this is now the
  residual service court of a mixed-use worker block rather than a freestanding
  arena. The preserved user rotation places Phase 1's conglomerate hab/utility
  megablock on the west edge and its skid-row tenements on the south edge.
- The west megablock replaces the visual role of the old detached slabs with a
  blank lower service/security band, inward-facing windows and balconies,
  stepped residential towers, roof plant, and corporate identity lighting. The
  live Phase 1 transform is user-authored and must remain unchanged.
- Three south tenements replace the southeast `Building14` slab. Apartments,
  balconies, laundry lines, ground workshops and inward-facing windows explain
  the courtyard's inhabited edge. A deliberate x≈123–133 break frames the
  existing return gate as the block's freight/service passage.
- `Hesperus_AlienBar_CourtyardAlley` already supplies the dense north building
  wall, road, and sidewalks. Its intact Shell10/security building is functional:
  the south access door leads to `CredentialInteriorLadder`, then the continuous
  upper catwalk and courtyard `AccessLanding`. Phase 2 adds only short ground
  cues outside that real doorway; it does not replace or cut through the shell.
- Phase 2 closes the east edge with split utility/hab masses behind x≈143. Its
  central portal deliberately leaves z≈−5..12 open for the functional ladder,
  steam-valve/service-crawl route, and the escape branch toward (155, 10).
  Cyan/green portal lighting makes that alternate route readable from inside
  the courtyard without adding a new objective.
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
  | Back door "SHOP BACKROUTE" | west wall, z ≈ 11.5 | FUNCTIONAL (built 2026-06-11, pending playtest) — `BackDoor_Locked` LockedDoor instance, slides up after `BackDoor_Breaker` is used |
  | Shell10 south access door → CredentialInteriorLadder → continuous upper catwalk → `AccessLanding` | north wall (Shell10 of `Hesperus_AlienBar_CourtyardAlley`) | FUNCTIONAL per Phase 1/2 architectural premise (added 2026-06-28); ladder + catwalk route lands on the existing `BalconyAccess/AccessLanding` (112, 4.55, −26.8). Pending playtest as a unified social/stealth chain from the North Courtyard Service Street. |
  | East portal — functional ladder | east wall behind Phase 2 split masses, x≈143, z ≈ −5..12 | FUNCTIONAL per Phase 2 (added 2026-06-28); central portal deliberately leaves z≈−5..12 open. Cyan/green portal lighting signals the alternate route from inside the courtyard. Pending playtest. |
  | East portal — steam-valve / service-crawl route | east wall behind Phase 2 split masses, same portal | FUNCTIONAL per Phase 2 (added 2026-06-28); orange-route crawl alternative to the ladder, sharing the portal opening. Pending playtest. |
  | East portal — escape branch toward (155, 10) | east wall, beyond the portal | FUNCTIONAL; the prepared service-crawl chase branch can end in target escape and now emits a readable route cue. Pending first-person chase playtest. |
  | Utility grate / service crawl | east wall, (136.9, 2) | FUNCTIONAL via `HesperusDistrictSystems/CourtyardSystemicTraversal`: paired service hatches remain blocked until the pressure valve clears persistent steam state. The imported grate mesh is the visual shell. |
  | Roof ladder | east wall, (136.9, −19) | FUNCTIONAL via runtime `CourtyardRoofLadderZone`; entering it authorizes the shared rooftop chase/interception route. |
  | Return gate (door+ramp) | south wall, x ≈ 128 | DOOR IS A CLOSED StaticBody — not traversable (opens at extraction via `extraction_unlock` group; not a mission ingress) |
  | North balcony + rope drop | y 4.3, z ≈ −22.9 | **FUNCTIONAL (built 2026-06-09, pending playtest)** — see Balcony access route below |

### Z6 balcony access route (stealth entry, built 2026-06-09)
- Nodes: `WorldGeometry/CourtyardArena/BalconyAccess` (AccessRamp, AccessLanding,
  RampRail_Outer, RampBaseNeon, LandingNeon — purple route markers per color language).
- Path: East Approach or North Courtyard Service Street → purple-marked
  scaffold ramp (base x ≈ 125.5, ground
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

### Freight Inspection Yard infill (added 2026-06-22)
- The oversized `Building21` slab was disabled and replaced by a 44×26 m
  inspection yard centered near world (52, −0.2, 64). `Building22` remains as
  the eastern industrial boundary. The existing Freight Ramp stays exposed on
  the yard's west edge.
- Architecture: staffed gatehouse, manifest and dispatch terminals, cargo
  scanner gantry, outbound gate, container cover lanes, inspection tower with
  ladder, crane, and a suspended container. The central force lane remains open.
- Three approaches authorize dispatch: courtyard/Foremarket courier credentials
  at the manifest booth, `utility` access at the scanner bypass, or the exposed
  tower override.
- Confirming dispatch grants a 200 CR freight advance and schedules a quieter
  extraction. When extraction starts, the normal pressure wave still runs, but
  the yard-specific reinforcement is suppressed and the suspended container
  lowers into usable cover.
- An active inspector guards the yard before extraction. Players can force the
  central lane, use credential/system routes, or climb the tower.

---

## Three-approaches checklist (the im-sim contract per zone)

A zone is DONE only when stealth, social, and force columns are all real.

| Zone | Force | Social | Stealth | Verdict |
|---|---|---|---|---|
| Z6 Courtyard | front gate ✔; disguise Tier 1 supports social approach at range (pending playtest); east-portal force entry via Phase 2 split-mass portal (pending playtest) | front gate + disguise Tier 1 pickup (pending playtest); Shell10 south door → upper catwalk → AccessLanding as social/stealth chain from North Courtyard Service Street (pending playtest) | balcony and back-door routes ✔; Shell10 catwalk drop; runtime east-portal ladder + steam-valve/service-crawl; runtime roof ladder | MULTI-ROUTE FUNCTIONAL, NEEDS UNIFIED PLAYTEST |
| North service street | open force lane + patrol ✔ | courier credential + crowd blend ✔ | power fail-open + upper catwalk ✔ | BUILT, NEEDS PLAYTEST |
| Z4 Bazaar | street ✔ | crowd lane ✔ (NPCs sparse) | upper walkway flank ✔ | PASSABLE |
| Z5 Walkway | n/a (route) | n/a | observation + flank ✔ | DONE for slice |
| Z7 Return | gate route ✔ (opens at extraction) | n/a (route) | catwalk line ✔ BUILT (pending playtest) | BUILT, NEEDS PLAYTEST |

**Priority gate (updated 2026-07-01):** balcony, back-door, disguise, utility
grate/service crawl, roof authorization, Shell10 catwalk, and east-portal route
logic now exist. They need one unified first-person pass for entrance
readability, collision, guard pressure, disguise scrutiny, and chase traversal.
Do not add another courtyard route before that pass.

### North street im-sim reassessment (2026-06-21)

- **Problems, not puzzles:** credentials, power sabotage, vertical traversal,
  and force solve the same courtyard-access problem through existing verbs.
- **Meaningful distinction:** each route changes preparation, visibility,
  permission state, noise, or combat exposure; routes are not cosmetic forks.
- **Consistent simulation:** powered consumers share one grid, restricted
  volumes use project access tags, and noise reaches the existing perceptive
  group.
- **Readable topology:** the alien-bar gate and AccessRamp are visible end
  anchors; utility and security functions divide the street into intermediate
  decisions without curving the main sightline.
- **Spatial economy:** the redesign removes curved residual wedges and redundant
  traversal chains. Remaining open space is assigned to circulation, crowd
  blending, sightlines, patrol exposure, or cover.
- **Known acceptance gate:** structural checks cannot prove route clarity,
  crowd-blend feel, checkpoint readability, or combat pressure. All four
  approaches require an in-game playtest before the street is considered final.

### Bazaar-to-Holo-Cantina transition quarter (2026-06-22)

- Legacy asset `Hesperus_BazaarAlienBar_Transition` explored assigning the former
  negative space between the market street and Holo-Cantina to a continuous
  mixed-use quarter. In the current live scene it is `visible = false` and its
  `AutoCollider.enabled = false`; treat it as reference geometry, not a live
  completed quarter.
- Ground level now has an underwalk noodle shop, weapon repair shop, cyberware
  reseller, open through-passage, and a cantina forecourt with food service,
  security booth, and queue control.
- A stair/elevator tower connects the ground route to `WalkwayWest` and the
  upper frontage. Shallow second-floor shops give the elevated deck a believable
  commercial edge.
- The `UpperWalkwayObservation` evidence bay at x=8..18 remains open for
  observation and trace readability. The main ground route and cantina approach
  also remain open.
- The east mixed-use wedge begins north of `BarEastRamp`, framing that approach
  without occupying its traversal volume.
- Structural coverage lives in `tools/test_bazaar_alienbar_transition.gd`, but
  that test validates the stored reference asset rather than live visibility.
  Re-enable or replace the quarter only under an explicit layout decision.

---

## Known structural debts (do not silently "fix" — surface to Nick first)

1. `WorldGeometry/Floors/DockFloor` uses node scale (12×8×25) on a unit
   BoxShape3D — same fragility as the old WorldFloor issue.
2. Triple-duplicated position data: `Markers/`, `GameplayRoutePlaceholders/`,
   `Gameplay/` — needs a cleanup pass with Gameplay as survivor.
3. `Market_StreetComposition` is an empty Node3D — orphan or placeholder?
4. Many imported buildings still generate runtime collision. Holo-Cantina and
   the Bazaar gallery improved this with coarse proxy meshes, but they remain
   GLB-owned collision pending Godot traversal grayboxes.
5. The Freight Line/Z7 geometry and access exist, but the gap, slopes, gate
   opening, and extraction pressure remain first-person acceptance gates.
6. Three dynamic-evidence anchors still name legacy stall meshes removed by the
   June 30 modular-stall replacement; the director rejects them and falls back.

## Dynamic evidence contract

The fixed live-scene clue chain was removed on 2026-06-29. Hesperus now keeps
tagged evidence anchors under `Gameplay/Investigation/EvidenceAnchors`.
`InvestigationDirector` selects anchors from the contract seed and instantiates
subtle footprint, fiber, delivery, or implant traces from database definitions.
Witnesses create rumors and zone hints; only a physical scan verifies a trait.
The contract now begins with one non-blocking footprint trail. Its prints follow
an authored walkable street alignment instead of cutting directly through
market geometry; verification names the courtyard-side destination, focuses HUD
navigation on it, and activates the delivery trace there without an arrow
overlay. Delivery evidence can then open the clinic-signature follow-up.
The HUD reports current zone, destination zone, compass bearing, and distance.
Player-facing place names reserve `Alien Bar` for the actual bar scene and call
this investigation quarter `North Arcade`. Escape route nodes remain ordered
`Marker3D` children directly under `KorvaxiEscapeRoute`.
