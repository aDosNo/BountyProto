# 01 — VERTICALITY PLAN (Hesperus Market)
Locked 6/12 from the immersive-sim route-stack analysis. Measured against the
live scene; street level = BazaarFloor top **y ≈ −2.83**. Post-sprint work
except where marked. Layout decisions remain Nick's — this doc records the
agreed structure and the numbers so they don't drift.

## Vertical bands (canonical heights, world y over street)
| Band | World y | +Street | What lives there |
|---|---|---|---|
| Service/back | −0.05 (alley) | +2.8 | Side alley + stall-backs. NOTE: our "service layer" is *uphill*, not sunken — lean into it, do NOT dig basements. |
| Street | −2.83 | 0 | Bazaar, crowds, public loop |
| Balcony | ≈ +0.7 | **+3.5** | DOES NOT EXIST YET over market. Canonical spacing = Apartment_Small floor pitch (3.45m). Courtyard already has it (BalconyNorth y4.3). |
| Rooftop | ≈ +6.7 | +9.5 | BazaarBridge (exists, y 6.71, z −22.3) — best mid-route anchor |
| Overlook | ≈ +11.3 | +14 | North Walkway ring + Freight Line. Observation band, NOT traversal — above doc's rooftop ceiling. |

## Measured findings
- Street corridor is ~38m wall-to-wall (facade x −0.75 → 38) vs 5–8m target.
  Fix by FILLING east margin (stall row + balcony structure), not moving walls.
- Crowd corridors occupy only x 15.5–18.3; ~15m dead margin each side.
- Jump apex is 0.63m (v²/2g) — 1m crates were unreachable until mantle.
- Apartment_Small (62.2, −0.05, 29.7): floors 0/3.45/6.9, roof 10.35 — all four
  bands in one enterable GLB. Isolated; needs one link to matter.
- RoofLadder (courtyard, 136.9) is decorative — make functional or remove.
  Rule: every visible route must be real.

## Build order (dependency-sorted)
1. **DONE 6/12 — Low mantle** (player_controller.gd, "Mantle" export group).
   ≤1.2m ledges only: crates, counters, stage lips. Keystone for everything below.
2. **East Balcony Run** — continuous strip y ≈ +0.7, east side, z +15 → −20,
   over new stall row eating the dead margin. Access: stairs at plaza mouth,
   CatwalkKiosk mid-street (inspect in-engine first — may already carry
   structure), one-way drop from BazaarBridge north end.
   Result: street → balcony → bridge → walkway chain exists end-to-end.
3. **Apartment link** — plank/awning from Apartment 3.45m floor west to balcony
   run north end. Upper rooms = clue interiors (6/21).
4. **Service loop via lock kit, zero new geometry** — 2 stall-back LockedDoors
   on west street edge (open from alley side, BypassSwitch behind) + 1 shutter
   alley → connector lower arm. Candidate for 6/17 disguise pass (door placement).
5. **Affordance cadence** — street z −18→+19 needs 3–4 route teases per the
   10–15m rule (balcony stairs, locked shutter, hatch prop).

## Rules adopted
- Apply density rules PER NODE (street/alley/plaza/courtyard), not map-wide —
  the district is a chain of compressed nodes, ~200m dock→courtyard is fine.
- No Layer 0 digging. Slab floors are 1–5m thick; thread behind, not under.
- 6/21 density-pass street section = the balcony-run section (dress what stays).

## Mantle test targets (current map)
Mantleable now: StageStep (0.5m), StagePlatform (0.95m), CoverBox_Mid (0.95m),
courtyard crates (0.85–1.15m). Intentionally NOT mantleable: CoverBox_N (1.45m),
CrateAlley (1.45m) — these gate the balcony band until step 2 builds real access.
