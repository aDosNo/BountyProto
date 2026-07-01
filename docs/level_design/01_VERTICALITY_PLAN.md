# 01 — VERTICALITY PLAN (Hesperus Market)

Originally locked 2026-06-12; status reconciled against the live scene on
2026-07-01. Layout decisions remain Nick's.

## Vertical bands

| Band | Approx. world y | Current role |
|---|---:|---|
| Bazaar street | −2.83 | crowds, public investigation loop |
| Service/back streets | −0.2 to 0.0 | Side Alley, East Approach, North Arcade/service routes |
| Balcony | 3.5 to 4.6 | East Balcony Run, courtyard balcony/access landing, connected service catwalk |
| Rooftop | 6.7 to 10.4 | Bazaar bridge, apartment roof, chase/interception links |
| Overlook | ≈11.3 | North Walkway and Freight Line observation/return band |

These bands are guidance, not a license to move the locked live layout.

## Completed since the original plan

- Low mantle is implemented in `player_controller.gd`.
- `WorldGeometry/EastBalconyRun` now exists with a deck, south ramp, rails, and
  route lighting.
- The North Arcade/service-street upper route connects through
  `EastMicroHub/Generated/ContinuousUpperCatwalk` to the courtyard
  `AccessLanding`.
- Courtyard balcony drop, back-door bypass, roof authorization, and
  steam-valve/service-crawl routes are functional in code/scene.
- The east backlot adds a stair and bridge into the continuous upper route.
- The Holo-Cantina has public, exposed scaffold/vent, and rear cargo-lift/
  basement route architecture.
- The Freight Line return route exists and the Freight Inspection Yard can
  prepare extraction.

## Current debts and playtest gates

- `EastBalconyRun` overlaps the newer gallery workflow conceptually. Do not
  remove it until the gallery's route and collision are verified first-person.
- `Hesperus_Market2_Street_gallery` and `HoloCantina` still derive collision
  from named GLB proxies; the target pipeline is Godot-owned traversal graybox.
- Apartment_Small has useful internal bands but still needs a clearly validated
  connection into the live route network.
- Walk the service-street ladder/catwalk/courtyard chain as one route; structural
  tests do not prove readable entrances or safe transitions.
- Walk all chase height changes and verify Korvaxi/player share each prepared
  route without skips, falls, or unfair LOS breaks.
- Validate the Freight Line gap, ramp slopes, return-gate opening, and pressure
  during extraction.

## Rules retained

- Every visible route affordance must become functional or be removed.
- Design routes in cheap gameplay geometry before committing expensive art.
- Apply density and route-readability rules per node, not as a map-wide average.
- Do not add a new vertical route merely to fill space; it must change access,
  information, exposure, target behavior, or extraction.
