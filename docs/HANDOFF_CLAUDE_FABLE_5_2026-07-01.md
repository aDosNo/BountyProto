# Claude Fable 5 handoff — 2026-07-01

## Start here

Canonical project path: `/var/home/nick/bounty-hunt`.

Canonical map and project main scene:
`scenes/maps/HesperusMarket_Blockout.tscn`.

Read `README.md`, `PROJECT_MANIFEST.md`, `SESSION_PROTOCOL.md`,
`SYSTEMS_IMSIM.md`, and
`level_design/hesperus_market_blockout/00_LOCKED_LAYOUT_BLOCKOUT.md` before
editing. Re-audit the live files; this handoff records a moving dirty checkout.

## Repository state

- HEAD: `cddef1a` (`update`, 2026-06-21).
- There are no commits for the June 22–30 work.
- Audit snapshot: 34 modified tracked entries, 3 deleted tracked entries, and
  364 untracked porcelain entries.
- Tracked diff: 37 files, 2274 additions, 914 deletions before today's doc pass.
- Do not reset or broadly clean. The dirty tree includes intended Blender, GLB,
  sprite, generated-material, scene, script, and test work.

## Work completed since HEAD

- Connected district state and activity layer:
  `DistrictState`, `HesperusDistrictSystems`, North Arcade activity, Foremarket
  Cold Chain, Evidence Annex, Bazaar Safehouse, East Micro-Hub, and Freight
  Inspection Yard.
- Dynamic investigation:
  seeded evidence definitions, tagged placement anchors, witness rumors,
  provenance-backed verification, authored footprint trails, HUD zone/bearing/
  distance navigation, and explicit follow-up focus.
- Hybrid scanner:
  tap sweep, held analysis, LOS/cone filtering, analysis suspicion cost,
  scanner-signature confrontation gate, and chase reacquisition.
- Chase contract:
  prepared public/roof/service branches, persistent route outcome, target escape
  as a real failure state, stamina/wound behavior, and route cues.
- District consequence work:
  persistent heat and vendor lockdown, activity reward rehydration, and prepared
  extraction state.
- Architecture:
  Foremarket, Evidence Annex, Safehouse, Freight Yard, North Arcade, courtyard
  perimeter phases, east backlot, and connected upper-route work.
- June 30:
  `holo_cantina_arch_shell_v2.glb` replaced the old bar interior, and five
  Bazaar gallery stalls were replaced with modular assemblies.

## Verified today

Normal headless project boot passed.

These targeted tests passed:

- golden investigation
- dynamic evidence
- hybrid scanner
- contract persistence boundary
- Korvaxi chase contract
- Holo-Cantina architecture/live replacement
- Bazaar gallery modular-stall replacement

ObjectDB leak warnings still appear in some tests and remain non-fatal.

## First defect to address

The June 30 modular-stall replacement removed landmark mesh names still used by
three evidence anchors:

- `bazaar_stall_fiber` → missing `Stall_PostR_005`
- `east_market_stall_fiber` → missing `Stall_PostL_004`
- `bazaar_delivery_counter` → missing `Stall_CounterTop_004`

`InvestigationDirector` rejects those placements and falls back, so the dynamic
evidence test passes while placement variety silently shrinks. Update the live
anchor landmark references to stable names from the new
`GAL_ModularStall_*`/`GAL_MS*` export, then rerun
`tools/test_dynamic_evidence_system.gd` and require zero rejection warnings.

## Required first-person gates

Automated tests do not prove player readability. Before expanding systems:

1. Play the footprint start from the dock and verify the route leads forward,
   not back toward Side Alley.
2. Verify the Courtyard Threshold handoff and HUD bearing/distance are readable
   without an arrow overlay.
3. Tune evidence visibility and RMB tap-versus-hold recognition.
4. Walk all Holo-Cantina route openings and validate scale, stair/ramp collision,
   combat clearance, and exterior silhouette.
5. Walk all five new Bazaar stalls and confirm counters, canopies, collision,
   sightlines, and crowd clearance.
6. Run public, rooftop, and service-crawl chase branches and judge LOS grace,
   reacquisition, stamina catch window, and escape fairness.

## Contradictions resolved in today's docs

- The generated `levels/hesperus_market/` layout is reference-only; the hand-built
  blockout is canonical.
- The old fixed Clue_01–03 chain is not the active investigation path.
- The staged courtyard Korvaxi is the target; no crowd actor becomes the chase
  target in the current contract.
- The Holo-Cantina is the only player-facing bar. North Arcade retains legacy
  `AlienBar` identifiers but its bar facade is hidden.
- `Hesperus_BazaarAlienBar_Transition` is hidden/disabled, not a live completed
  quarter.
- GLB collision separation is a target workflow, not current reality. Many GLBs
  still generate collision; Holo-Cantina and the gallery use explicit proxies.
- Nemesis registry code and escape hooks exist, but recording stays disabled
  until the target profile exposes the registry's canonical identity shape.

## Scope discipline

- Preserve the live Phase 1 courtyard transform.
- Do not treat generated graybox coordinates as live-map coordinates.
- Do not add new routes or zones without Nick's instruction.
- Keep Blender for architectural shells/major permanent forms; keep interactions,
  state, NPCs, rewards, and mutable props in Godot.
- Treat every new space as a gameplay system with bounty-loop utility, route
  distinction, and visible state consequences—not visual filler.

## Claude cross-check — 2026-07-01

Independently verified against the live filesystem (not just this doc) before
Fable resumes: every script this handoff names exists on disk, the described
failure mode in `evidence_anchor.gd::resolve_placement()` matches the stale-
landmark defect exactly, the scene file's mtime matches the claimed 6/30 stall
replacement, and `PROJECT_MANIFEST.md` / `SYSTEMS_IMSIM.md` (both dated
2026-07-01) independently agree with this handoff's state. No fabrication
detected. `VISION.md`'s 2026-07-01 implementation-boundary note confirms the
new connected activities (Foremarket, Safehouse, Freight Yard, East Micro-Hub)
are sub-systems of the one locked Hesperus district, not scope creep into
Docks/District 3 — consistent with the original lock.

**One item this handoff doesn't cover:** `docs/level_design/hesperus_market/`
(the deprecated pre-blockout doc set) is still unarchived. It's been on the
pending doc-audit backlog since 2026-06-29 alongside four other stale-doc
items (PROJECT_MANIFEST reference/log split — since resolved by this handoff's
rewrite; VERTICALITY_PLAN built-since-lock subsection; VISION roadmap restate
— partially resolved by the implementation-boundary note; 05-doc pattern
rollout across design docs). Low priority relative to the defect below, but
cheap to close in a spare 10 minutes.

**Suggested order for this window**, highest-leverage first:
1. Fix the three stale landmark references (`bazaar_stall_fiber`,
   `east_market_stall_fiber`, `bazaar_delivery_counter`) against the new
   `GAL_ModularStall_*`/`GAL_MS*` names — small, isolated, unblocks full
   evidence variety, rerun `test_dynamic_evidence_system.gd` for zero
   rejections.
2. Required first-person gates above — these need Nick in-engine; be ready to
   fix immediately on his reports rather than batching.
3. Archive `hesperus_market/` + remaining doc-audit backlog, if time remains.
4. Do not start the contract generator, new districts, or economy systems —
   `VISION.md` still scopes those out of current runtime regardless of how
   much scaffolding (`nemesis_registry.gd`, etc.) already exists for them.
