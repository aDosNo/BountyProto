# PROJECT MANIFEST — read this instead of grepping .tscn files
Updated: 2026-06-10 (sprint day 1). Godot 4.6.1, Jolt physics. Main scene: `scenes/maps/HesperusMarket_Blockout.tscn`.

## Scene tree (map) — key paths
- `Gameplay/Player` (Player.tscn) — **node transform IS the spawn point** (Markers/PlayerSpawn does nothing)
- `Gameplay/BountyManager` — target_path/reward_screen_path/extraction_zone_path wired; auto_accept=false
- `Gameplay/BountyBoard` (bounty_board.gd) — interact starts contract
- `Gameplay/KorvaxiTarget` — escape_route_parent=`KorvaxiEscapeRoute` (4 EscapeNode markers, root at x=94.96)
- `Gameplay/ExtractionZone`, `Gameplay/Clues/Clue_01..03`, `Gameplay/PressureEnemies/*` (4 GangGuards, sentry=true), `Gameplay/GuardRoutes/PatrolRoute_A|B`, `Gameplay/AmbientDummies/*` (TargetDummy)
- `Gameplay/CrowdNPCs/*` — funnel crowd (CrowdNPC.tscn, added day 1; placement provisional, Nick owns layout)
- `UI/RewardLayer/RewardScreen`; HUD lives inside Player.tscn (group "hud")
- `WorldGeometry/...` — Floors, WallsAndFacades (Building1-24), RampsAndCatwalk, CourtyardArena (PerimeterWalls/Exits/BalconyNorth/Fountain/Stage/CoverRing/Stalls), ReturnRouteZ7, RetroVisualPass
- GLB set-pieces instanced at root: CatwalkKiosk2, MedSupplyAlleyCorner2, ExtractionDock2, bazaar_blockout, SideAlley_WideGap, DockBayCorner junction

## Groups
`bounty_manager`, `bounty_target`, `scanner_clue`, `scannable_npc`, `extraction_zone`, `extraction_unlock` (ReturnGate_Door — sinks open on secure), `pressure_enemy`, `reward_screen`, `hud`, `target_dummies`

## Signals / contracts
- ClueObject: `clue_scanned(clue_id, next_clue_id, reveals_target)` → BountyManager.on_clue_scanned
- KorvaxiTarget: `killed, captured, stunned, stun_expired, flee_started, reached_final_node`
- ExtractionZone: `extraction_reached` → complete_contract_at_extraction
- CrowdNPC: `npc_scanned(npc)` ; BountyIntel (autoload): `intel_updated(category, value, source)`
- BountyManager.MissionState: INACTIVE→ACCEPTED→TRACKING→TARGET_IDENTIFIED→TARGET_NEUTRALIZED→EXTRACTING→COMPLETE/FAILED
- HUD methods: set_objective, show_toast(text,dur), set_scanner_active/text, set_scan_progress, set_interaction_prompt, set_capture_prompt/progress, set_health, set_ammo, flash_damage, show_hit_marker

## Clue IDs (legacy linear chain — being superseded by funnel)
`clue_01_market_trace` → `clue_02_side_alley_residue` → `clue_03_upper_walkway_residue` (reveals_target=true). first_clue_id export on BountyManager.

## Funnel system (locked design — see userMemories / day-1 build)
- `scripts/bounty_intel.gd` — autoload **BountyIntel**. known traits dict; `learn(category, value, source)`, `match_report(npc)`, `build_readout(npc)`. Categories: `build, appearance, movement_tell, location_habit, scanner_signature`
- `scripts/crowd_npc.gd` / `scenes/npcs/CrowdNPC.tscn` — CharacterBody3D, group `scannable_npc`, per-instance trait exports + is_candidate/is_target. Hold-scan like clues; completion reports to BountyIntel.
- scanner.gd handles BOTH `scanner_clue` and `scannable_npc` targets (clue path unchanged).

## Input actions
WASD, jump=Space, sprint=Shift, fire=LMB, scan=RMB(hold), interact=E, reload=R, weapon_primary=1, weapon_capture=2, ui_cancel=Esc. F3 toggles retro overlay.

## Gotchas
- `.tscn` edits: full-file write_file only for big changes; edit_file OK for short unique anchors. Map .tscn header has NO load_steps (fine).
- Floors/walls share unit `Mesh_box`/`Shape_box` scaled via node transform (fragile but consistent; no node named WorldFloor exists). Defer refactor.
- filesystem:write_file is text-only — PNGs/binaries must be manually copied by Nick.
- godot:run_project exits without a handle; validate structurally with Python instead.
- Subscenes: Player, BountyManager, KorvaxiTarget, ClueObject, ExtractionZone, GangGuard, TargetDummy, RewardScreen, CrowdNPC + ps1_market props (NeonGlyphSign, Crate, Barrel, CableBundle, BillboardCivilian).
- Texture pipeline: `tools/texture_gen.py` (PIL; run locally: `python3 tools/texture_gen.py` → art/textures_generated/).
