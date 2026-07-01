# PROJECT MANIFEST

Updated: 2026-07-01. This is the current-state index. Design intent belongs in
`VISION.md`; system rules belong in `SYSTEMS_IMSIM.md`; exact live-map geometry
belongs in `level_design/hesperus_market_blockout/00_LOCKED_LAYOUT_BLOCKOUT.md`.

## Runtime entry points

- Engine: Godot 4.6.1, Forward Plus, Jolt physics.
- Main and canonical map: `scenes/maps/HesperusMarket_Blockout.tscn`.
- The generated scene under `levels/hesperus_market/` is reference-only.
- Real player spawn: `Gameplay/Player`; `Markers/PlayerSpawn` is only a marker.
- Autoloads: `BountyIntel`, `HunterLedger`, `NemesisRegistry`, `DistrictState`.
- HUD is instanced inside `Player.tscn` and is found through group `hud`.

## Current vertical slice

The live slice is one authored Korvaxi contract:

1. Accept at `Gameplay/BountyBoard`.
2. `Gameplay/Investigation` starts a seeded dynamic-evidence contract.
3. Witnesses create rumors; physical evidence verifies intel.
4. Tap RMB sweeps; held RMB analyzes a focused subject or evidence trace.
5. A confrontation requires enough intel, scanner-signature intel, and completed
   analysis of that subject.
6. Correct confrontation reveals the staged `Gameplay/KorvaxiTarget`.
7. Korvaxi selects an authored chase route. Some prepared branches can end in
   target escape; public Bazaar pursuit corners him.
8. Kill or stun/capture, then return to `Gameplay/ExtractionZone`.

The target is the staged courtyard Korvaxi, not a procedural crowd NPC.
`data/crowd_traits_hesperus.json` sets `target_in_crowd: false`. The crowd is an
authored candidate/decoy field plus civilians.

## Investigation stack

- Definitions: `data/investigation_clues_hesperus.json`.
- Legal placements: `Gameplay/Investigation/EvidenceAnchors`.
- Director: `scripts/investigation_director.gd`.
- Evidence actor: `scenes/props/ScanEvidence3D.tscn`.
- Intel provenance: `scripts/bounty_intel.gd`.
- Scanner input and shortlist/analysis behavior: `scripts/scanner.gd`.
- HUD navigation: current zone plus focused lead zone, bearing, and distance.
- Player-facing location name is `North Arcade`; `AlienBar` remains in some
  legacy asset/script identifiers.

The old `Gameplay/Clues` node remains as an empty compatibility root. The fixed
`Clue_01..03` chain and `first_clue_id` fallback are not the active contract path.

## Gameplay and persistence

- `scripts/bounty_manager.gd`: mission state, accusations, heat, chase outcome,
  extraction, payout, and contract-scoped persistence.
- `scripts/hesperus_district_systems.gd`: connected district activities and
  systemic traversal.
- `scripts/district_state.gd`: `user://district_state.json`. New contracts clear
  `hesperus.contract.*`; access, activity completion, and heat persist.
- `scripts/hunter_ledger.gd`: persistent CR wallet with working `add`,
  `spend`, and `can_afford`.
- `scripts/nemesis_registry.gd`: persistent roster implementation exists, and
  target-escape hooks exist, but `BountyManager.nemesis_recording_enabled` is
  intentionally false until generated targets expose the registry's canonical
  `scanner_sig`/trait-kit shape.

## Implemented Hesperus systems

- Hybrid scanner, evidence provenance, authored candidate funnel, signature
  confrontation gate, and chase reacquisition.
- Guard suspicion/alert behavior, noise response, panic occlusion, crowd panic,
  disguises, crowd blending, wrong-accusation consequences, district heat, and
  vendor lockdown.
- Courtyard force, disguise, balcony/back-door, roof, and service-crawl routes.
- Persistent connected activities: North Arcade, Foremarket Cold Chain, Bounty
  Evidence Annex, Bazaar Safehouse, East Micro-Hub, and Freight Inspection Yard.
- Prepared chase/extraction route state and visible district consequences.

## Current art and map integration

- Holo-Cantina: `assets/blender_models/holo_cantina_arch_shell_v2.glb`, instanced
  as root node `HoloCantina`.
- North Arcade: `Hesperus_AlienBar_CommercialArcade.glb`; the former bar facade
  pieces are hidden so it does not compete with the Holo-Cantina.
- Bazaar gallery: `Hesperus_Market2_Street_gallery.glb`; on 2026-06-30 its five
  legacy stalls were replaced with modular stall assemblies.
- `Hesperus_BazaarAlienBar_Transition` is currently present but hidden and
  `enabled = false`; it is reference geometry, not a live quarter.
- Many legacy and recent GLBs still generate runtime collision. Holo-Cantina and
  the Bazaar gallery use named coarse collision proxies. This is transitional
  debt relative to `PIPELINE.md`, not proof that the visual/collision separation
  is complete.

## Input

WASD move · Space jump/mantle · Shift sprint · Ctrl crouch · LMB fire · RMB
tap sweep / hold analysis · E interact/capture · R reload · 1 pistol · 2 stun
net · G noise lure · binocular action as configured in `project.godot` · F3
retro-overlay toggle.

## Validation

Current targeted tests:

- `tools/test_golden_investigation.gd`
- `tools/test_dynamic_evidence_system.gd`
- `tools/test_scanner_hybrid.gd`
- `tools/test_contract_persistence.gd`
- `tools/test_korvaxi_chase_contract.gd`
- `tools/test_holo_cantina_arch_shell.gd`
- `tools/test_market_gallery_modular_stalls.gd`

All passed on 2026-07-01. `test_dynamic_evidence_system.gd` also exposed stale
landmark references for three evidence anchors after the modular-stall
replacement: `bazaar_stall_fiber`, `east_market_stall_fiber`, and
`bazaar_delivery_counter`. They are rejected and fallback anchors keep the test
green. This is the first current integration defect to fix.

## Worktree warning

The project is intentionally very dirty and most work since commit `cddef1a`
(2026-06-21) is uncommitted. Preserve user-authored `.blend`, GLB, generated
texture, sprite, and scene work. Do not reset, delete, stage, or broadly clean
assets based only on git status.
