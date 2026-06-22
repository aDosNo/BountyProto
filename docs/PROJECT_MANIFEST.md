# PROJECT MANIFEST — read this instead of grepping .tscn files
Updated: 2026-06-10 (sprint day 1). Godot 4.6.1, Jolt physics. Main scene: `scenes/maps/HesperusMarket_Blockout.tscn`.

## Scene tree (map) — key paths
- `Gameplay/Player` (Player.tscn) — **node transform IS the spawn point** (Markers/PlayerSpawn does nothing)
- `Gameplay/BountyManager` — target_path/reward_screen_path/extraction_zone_path wired; auto_accept=false
- `Gameplay/BountyBoard` (bounty_board.gd) — interact starts contract
- `Gameplay/KorvaxiTarget` — escape_route_parent=`KorvaxiEscapeRoute` (4 EscapeNode markers, root at x=94.96). CHASE (built 6/10 eve, untested): Marker3D children = single route (legacy, current scene); Node3D children w/ markers = alternate routes, target picks farthest-from-player at flee start. Stamina sprint (drains when player <pressure_range, recovers when clear), wound slowdown (speed scales w/ health), panic serpentine <juke_distance. All tunables exported under "Chase" group.
- `Gameplay/ExtractionZone`, `Gameplay/Clues/Clue_01..03`, `Gameplay/PressureEnemies/*` (4 GangGuards, sentry=true / `sentry_enemy`), `Gameplay/GuardRoutes/PatrolRoute_A|B`, `Gameplay/AmbientDummies/*` (TargetDummy)
- `Gameplay/CrowdNPCs/*` — funnel crowd (CrowdNPC.tscn). CROWD OVERHAUL (6/11, partially playtested): 5 spawn corridors under `Gameplay/CrowdNPCs/CrowdSpawns` (Spawn_Street x8, Spawn_Plaza x6, Spawn_Alley x5, Spawn_DockCorner x3, Spawn_DockBay x2 markers); distribution via `spawn_quotas` in data JSON (Street 13 / Plaza 11 / Alley 2 / DockCorner 3 / DockBay 1); min_spawn_separation 2.6 w/ rejection sampling; per-NPC speed/pause/loiter variance + route direction flips. REACTIONS: PANIC state — runs from player w/ drawn weapon inside scare_radius 9 (recovers when holstered/clear); player push-aside inside push_radius 1.0; NPCs damageable (50hp) — shooting one alerts guards (on_ally_alert) + panics nearby crowd, death = squash tween + cleanup.
- `UI/RewardLayer/RewardScreen`; HUD lives inside Player.tscn (group "hud"). INTEL PANEL (built 6/11, untested): top-right, built in code by hud.gd (HUD.tscn untouched) — 5 trait slots (unknown dimmed, learned bright + yellow flash), counter reads BountyManager.intel_required_to_confirm live, flips to CONFRONT AUTHORIZED at threshold. Listens to BountyIntel.intel_updated.
- `WorldGeometry/...` — Floors, WallsAndFacades (Building1-24), RampsAndCatwalk, CourtyardArena (PerimeterWalls/Exits/BalconyNorth/Fountain/Stage/CoverRing/Stalls), ReturnRouteZ7, RetroVisualPass
- GLB set-pieces instanced (verified on disk 6/10 eve): SM_MarketBuilding, SM_BazaarBuilding_CatwalkKiosk, SM_BazaarBuilding_MedSupplyAlleyCorner, DockBayCorner_SideAlleyJunction + zone dressing GLBs: Hesperus_Market2_Street, Hesperus_DockBay, Hesperus_SideAlley2, Hesperus_DockCornerHub, Hesperus_SouthPlaza, Hesperus_Courtyard. (ExtractionDock / bazaar_blockout / SideAlley_WideGap GLBs are NO LONGER in ext_resources.)
- NEW 6/11 eve: `Hesperus_Apartment_Small.glb` (+source .blend) — enterable 3-floor apartment, placed in the main scene at root as `Hesperus_Apartment_Small` around (62.24, -0.05, 29.67). Still needs in-game placement/collision playtest. 10×8m, ~11m tall; floor tops local y 0 / 3.45 / 6.9, roof 10.35 w/ parapet + railed stair hole. Front door faces local +Z (lobby, neon sign, ajar door panel); back service door -Z side. Switchback stairwell NE corner ground→roof; STAIR COLLISION: `-colonly` ramp wedges over every flight — Godot importer strips them to invisible collision (player walks, treads stay visual). Emissive window panes (N_Window*), partitioned room per upper floor (clue spots), crates lobby/L1/roof. Building-frame UV projection (continuous wall texture).
- NEW 6/11: `Hesperus_AlleyCorner_PlazaJunction.glb` (+source .blend). Bespoke L-connector SideAlley2→SouthPlaza built in WORLD COORDS, instanced at identity transform w/ autocol script. Entry mouth flush at alley open end (x-35.39, z28.82), bend at z40, 37m east arm w/ 12m ramp descending 2.9m into plaza RampGap (z36-44). Chamfered bend corner w/ door+N_Magenta neon (future LockedDoor spot). UVs: per-object box projection, 4m/tile (matches BK kit density).

## Groups
`bounty_manager`, `bounty_target`, `scanner_clue`, `scannable_npc`, `extraction_zone`, `extraction_unlock` (ReturnGate_Door — sinks open on secure), `sentry_enemy` (always active), `pressure_enemy` (mission activated), `reward_screen`, `hud`, `target_dummies`

## Signals / contracts
- ClueObject: `clue_scanned(clue_id, next_clue_id, reveals_target)` → BountyManager.on_clue_scanned
- KorvaxiTarget: `killed, captured, stunned, stun_expired, flee_started, reached_final_node`
- ExtractionZone: `extraction_reached` → complete_contract_at_extraction
- CrowdNPC: `npc_scanned(npc)` ; re-scannable (intel-comparison tool); interact contract = CONFRONT → call_group("bounty_manager", "on_npc_accused", self) ; BountyIntel (autoload): `intel_updated(category, value, source)`
- ACCUSATION: BountyManager.on_npc_accused — gated on intel_required_to_confirm (export, default 3 known traits). Correct → crowd target runs `resolve_as_target_handoff()` and the staged `Gameplay/KorvaxiTarget` reveals/flees on the authored chase route. Wrong → mark_confronted, guards within shout_radius of NPC go hostile (on_ally_alert), crowd_director.spook_target() makes real target wary/mobile. Mission transforms, never fails.
- WITNESSES (built 6/11, untested): ~40% of civilians (witness_hint_chance + witness_categories in data JSON) dealt one target trait at spawn — appearance/movement_tell/location_habit only (never scanner_signature or build). Interact = "Ask about the bounty" → one-liner toast + BountyIntel.learn, one-shot. Candidates = confront, civilians = canvass.
- ECONOMY SPINE (built 6/11, untested): autoload **HunterLedger** (scripts/hunter_ledger.gd) — persistent credits, survives reloads + restarts (user://hunter_ledger.json). API: add/spend/can_afford/total, `credits_changed` signal. Payout: reward_dead 3000 / reward_alive 7000 (already existed); wrong accusations now fined (wrong_accusation_penalty export, 500 ea, capped at half payout); reward screen shows bonus/fines breakdown + account total. Post-sprint verb purchases call HunterLedger.spend().
- DISTRICT HEAT / VENDOR LOCKDOWN (built 6/11, untested): BountyManager owns `_district_heat` with exported thresholds. `CrowdNPC.take_damage` reports civilian wound/death; wrong accusations and target kills also add heat. At threshold, `vendor_lockdown` nodes run `set_lockdown(reason)`. First responders: `WorldGeometry/StallsAndCover` and `WorldGeometry/CourtyardArena/Stalls`, both using `scripts/vendor_lockdown.gd` to drop red shutter panels and tint awnings.
- BountyManager.MissionState: INACTIVE→ACCEPTED→TRACKING→TARGET_IDENTIFIED→TARGET_NEUTRALIZED→EXTRACTING→COMPLETE/FAILED
- HUD methods: set_objective, show_toast(text,dur), set_scanner_active/text, set_scan_progress, set_interaction_prompt, set_capture_prompt/progress, set_health, set_ammo, flash_damage, show_hit_marker

## Clue IDs (legacy linear chain — being superseded by funnel)
`clue_01_market_trace` → `clue_02_side_alley_residue` → `clue_03_upper_walkway_residue` (reveals_target=true). first_clue_id export on BountyManager.

## Funnel system (locked design — see userMemories / day-1 build)
- `scripts/bounty_intel.gd` — autoload **BountyIntel**. known traits dict; `learn(category, value, source)`, `match_report(npc)`, `build_readout(npc)`. Categories: `build, appearance, movement_tell, location_habit, scanner_signature`
- `scripts/crowd_npc.gd` / `scenes/npcs/CrowdNPC.tscn` — CharacterBody3D, group `scannable_npc`, per-instance trait exports + is_candidate/is_target. Hold-scan like clues; completion reports to BountyIntel.
- scanner.gd handles BOTH `scanner_clue` and `scannable_npc` targets (clue path unchanged).

## Input actions
WASD, jump=Space, sprint=Shift, fire=LMB, scan=RMB(hold), interact=E, reload=R, weapon_primary=1, weapon_capture=2 (pressing the equipped weapon's key again HOLSTERS — built 6/10 eve), throw_lure=G (built 6/10 eve), ui_cancel=Esc. F3 toggles retro overlay.

## Noise lure (built 6/10 eve, untested)
`scenes/props/NoiseLure.tscn` + `scripts/noise_lure.gd` — RigidBody3D thrown from camera (G, player export lure_count=3). One noise event on first impact, loudness 14 (below gunfire 25 → guards INVESTIGATE, never alert; Korvaxi not spooked). Ignores brushing the thrower; flashes yellow on pop; despawns.

## Lock/bypass kit (FIRST PLACEMENT 6/11: courtyard SHOP BACKROUTE is now functional — `Exits/BackDoor_Locked` (LockedDoor instance, slides up) + `Exits/BackDoor_Breaker` on the OUTER west wall 6m north at (86.2, 1.1, 17.5); breaker clunk noise can pull nearby guards)
- `scenes/props/LockedDoor.tscn` (locked_door.gd, group `locked_door`): interact while locked = refusal toast; `unlock()` public hook (BypassSwitch, future lockpick item, mission scripts); unlocked interact slides door along slide_axis export (default up, ReturnGate pattern), collision off. Signals: `unlocked`, `opened`.
- `scenes/props/BypassSwitch.tscn` (bypass_switch.gd): target_door NodePath → unlock(); emits small noise (10m, breaker clunk) by default; one-shot, turns green.

## Crowd blending (built 6/10 eve, untested)
- Player: `is_blended()` = holstered + ≤walk speed + ≥2 scannable_npc within blend_radius (export, 4.0m). State-change toast + print. `is_holstered()` also public.
- DISGUISE TIER 1 (built 6/11, untested): `scenes/props/DisguisePickup.tscn` (disguise_pickup.gd, interact to don; one placed: `Gameplay/DisguisePickup_Connector` at (-6, -2.9, 42.3) on the connector lower arm). Worn disguise = PORTABLE BLENDING (player counts blended w/o crowd proximity; still requires holstered + walk pace). Guards: disguised+blended beyond disguise_scrutiny_range (export 4.5m) → rate ×0.08 cap 0.4; INSIDE scrutiny range disguise thins (×0.6, no cap — guards up close see through it). Drawn weapon voids everything via the blend gate. `player.equip_disguise(name)` / `is_disguised()` public.
- GangGuard `_update_vision`: blended → detection rate ×0.15, detection capped at 0.45 (never reaches suspicion from sight; ducking into a crowd sheds built-up detection — intentional). Once ALERTED, blending does nothing (combat path skips vision).
- SUSPICION-BEAT RULE (added 6/11): vision can NEVER jump straight to ALERTED — always a yellow beat first (min_suspicious_beat export, 0.5s; detect_time_close raised 0.35→0.7). Gunfire <15m and ally shouts still insta-alert.
- Korvaxi flee anti-stuck (added 6/11): wall-slide steering replaces juke when is_on_wall(); watchdog skips to next route node after 0.8s of no progress; node reach is HORIZONTAL-only (markers at old blockout heights vs new GLB floors caused instant skip-cascade); gravity applied in flee; node_reach_distance default 0.75→1.4 (check scene instance for a stale override).
- FUNNEL RULE (6/11): clue reveals_target NO LONGER auto-identifies — final clue completes the trail, identification only via confront.
- Disguise tiers (post-sprint economy) strengthen this — same hook.

## Gotchas
- `.tscn` edits: full-file write_file only for big changes; edit_file OK for short unique anchors. Map .tscn header has NO load_steps (fine).
- Floors/walls share unit `Mesh_box`/`Shape_box` scaled via node transform (fragile but consistent; no node named WorldFloor exists). Defer refactor.
- filesystem:write_file is text-only — PNGs/binaries must be manually copied by Nick.
- godot:run_project exits without a handle; validate structurally with Python instead.
- Subscenes: Player, BountyManager, KorvaxiTarget, ClueObject, ExtractionZone, GangGuard, TargetDummy, RewardScreen, CrowdNPC + ps1_market props (NeonGlyphSign, Crate, Barrel, CableBundle, BillboardCivilian).
- Texture pipeline: `tools/texture_gen.py` (PIL; run locally: `python3 tools/texture_gen.py` → art/textures_generated/). 8 textures + 7 M_Gen_* materials exist; 5 applied in main scene.
- `HesperusMarket_Blockout.codexbak.tscn` = Codex backup — do not edit.
- Hand-written .tscn gotcha: `unique_name_in_owner` is a PROPERTY LINE (`unique_name_in_owner = true` under the node header), NOT a header attribute — header form is silently ignored and `%Name` lookups fail at runtime. Prefer `$Child` paths in flat prop scenes.

## Design vision
See `docs/VISION.md` (locked 6/10): 2–3 districts, procedural contract generation, verb economy, nemesis-lite.
- Trait pools now DATA-DRIVEN: `data/crowd_traits_hesperus.json` (crowd_director loads via trait_data_path export; consts remain as fallback only). Add districts by adding data files.
- Accusation/threshold + wrong-accusation consequences built 6/10 eve — needs playtest.
