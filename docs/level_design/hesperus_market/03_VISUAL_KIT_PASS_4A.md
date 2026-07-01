# Hesperus Market Visual Kit Pass 4A

**Historical/reference audit.** This kit belongs to the generated
`levels/hesperus_market/` branch. It remains reusable reference material but is
not evidence that these modules are present in the canonical live map.

Date: 2026-06-09

## Files Created

- `levels/hesperus_market/visual_kit/VK_HesperusMarket_KitCatalog.tscn`
- `levels/hesperus_market/visual_kit/modules/VK_MarketWallPanel.tscn`
- `levels/hesperus_market/visual_kit/modules/VK_ServiceWallPanel.tscn`
- `levels/hesperus_market/visual_kit/modules/VK_DockWallPanel.tscn`
- `levels/hesperus_market/visual_kit/modules/VK_FloorPlateTrim.tscn`
- `levels/hesperus_market/visual_kit/modules/VK_PortDoorFrame.tscn`
- `levels/hesperus_market/visual_kit/modules/VK_VentHatchFrame.tscn`
- `levels/hesperus_market/visual_kit/modules/VK_CrateStack.tscn`
- `levels/hesperus_market/visual_kit/modules/VK_VendorStallBlock.tscn`
- `levels/hesperus_market/visual_kit/modules/VK_HangingSignBlock.tscn`
- `levels/hesperus_market/visual_kit/modules/VK_CableBundle.tscn`
- `levels/hesperus_market/visual_kit/modules/VK_AwningCanopyBlock.tscn`
- `levels/hesperus_market/visual_kit/modules/VK_CatwalkRailing.tscn`
- `levels/hesperus_market/visual_kit/modules/VK_PipeBundle.tscn`
- `levels/hesperus_market/visual_kit/modules/VK_UtilityGrate.tscn`
- `levels/hesperus_market/visual_kit/modules/VK_NeonRouteStrip.tscn`
- Shared material resources under `levels/hesperus_market/visual_kit/materials/`

## Available Visual Modules

- Market wall panel
- Service wall panel
- Dock wall panel
- Floor plate trim
- Port / door frame
- Vent / hatch frame
- Crate stack
- Vendor stall block
- Hanging sign block
- Cable bundle
- Awning / canopy block
- Catwalk railing
- Pipe bundle
- Utility grate
- Neon route strip

## Material Language

Route materials:

- `DBG_Route_Return_Green`
- `DBG_Route_Bounty_Yellow`
- `DBG_Route_Investigation_Blue`
- `DBG_Route_Upper_Purple`
- `DBG_Route_Utility_Orange`
- `DBG_Route_Target_Red`

Neutral materials:

- `DBG_Market_Metal`
- `DBG_Dock_Metal`
- `DBG_Service_ConcreteMetal`
- `DBG_Dark_Trim`
- `DBG_Emissive_Sign`
- `DBG_Landmark_White`

## Intended Section Usage

- `S1_DOCK_BAY`: dock wall panels, crate stacks, floor trim, port frames, green return strips.
- `S2_BOUNTY_BOARD_HUB`: market wall panels, hanging signs, bounty/yellow route strips, port frames.
- `S3_SIDE_ALLEY`: service wall panels, cable bundles, pipe bundles, utility grates, blue/orange route strips.
- `S4_MAIN_BAZAAR_STREET`: market wall panels, vendor stall blocks, awnings, hanging signs, yellow/blue/red route strips.
- `S5_UPPER_WALKWAY_OVERLAY`: catwalk railings, awning blocks, cable bundles, purple route strips.
- `S6_CAPTURE_COURTYARD`: port frames, target/red route strips, crate/cover blocks, service wall panels.
- `S7_RETURN_UTILITY_STRIP`: service wall panels, pipe bundles, utility grates, vent/hatch frames, orange/green route strips.

## Intentionally Not Added

- No final textures or final art.
- No NPCs, enemies, quests, shops, economy systems, capture logic, or interactable behavior.
- No new sections, ports, exits, routes, shortcuts, hatches, or ladders.
- No changes to section bounds, port coordinates, port names, route colors, route graph, validator data, or locked layout JSON.

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

## Next Recommended Section Pass

Visual Blockout Pass 4B should apply this kit to `S1_DOCK_BAY` only. The pass should replace some generic identity boxes with dock wall panels, crate stacks, dock trim, port frames, and route strips while preserving all locked ports and openings.
