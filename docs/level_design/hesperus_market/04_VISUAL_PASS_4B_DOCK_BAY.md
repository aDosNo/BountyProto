# Hesperus Market Visual Blockout Pass 4B - Section 1 Dock Bay

**Historical/reference audit.** This pass affects the generated
`levels/hesperus_market/` scene only, not the canonical live Dock Bay. Its “next
recommended pass” is not a current project priority.

## Scope

Visual blockout dressing was added only for `S1_DOCK_BAY` in the generated Hesperus Market graybox scene.

Scene path:

- `levels/hesperus_market/scenes/hesperus_market_graybox.tscn`

Builder script:

- `levels/hesperus_market/scripts/hesperus_market_graybox_builder.gd`

Visual kit path:

- `levels/hesperus_market/visual_kit/`

## Files Changed

- `levels/hesperus_market/scripts/hesperus_market_graybox_builder.gd`
- `levels/hesperus_market/scenes/hesperus_market_graybox.tscn`
- `tools/bake_hesperus_market_graybox_scene.gd`
- `docs/level_design/hesperus_market/04_VISUAL_PASS_4B_DOCK_BAY.md`

## Visual Modules Placed

S1 uses the global visual kit modules created in Pass 4A:

- `VK_DockWallPanel.tscn`
- `VK_FloorPlateTrim.tscn`
- `VK_PortDoorFrame.tscn`
- `VK_VentHatchFrame.tscn`
- `VK_UtilityGrate.tscn`
- `VK_CrateStack.tscn`
- `VK_HangingSignBlock.tscn`
- `VK_CatwalkRailing.tscn`
- `VK_PipeBundle.tscn`
- `VK_CableBundle.tscn`
- `VK_NeonRouteStrip.tscn`

Additional generated blockout meshes were added for the docked ship / landing pad silhouette, customs booth, customs ramp, extraction beacon, upper catwalk cue deck, and catwalk supports.

## Dock Bay Identity Additions

- Docked ship / landing pad silhouette in the center-left dock area.
- Customs ramp and customs booth near the upper/east side of the dock.
- Cargo/crate pocket using visual kit crate stacks.
- Extraction start marker using green floor and vertical beacon geometry.
- Visible upper catwalk cue toward `S5_UPPER_WALKWAY_OVERLAY`.
- Maintenance hatch cue toward `S7_RETURN_UTILITY_STRIP`.
- Return gate / shortcut cue at the approved south return port.
- Port frames around all approved S1 exits.
- Direction signs for Bounty Board Hub, Upper Walkway, Utility / Return, and Extraction Return.
- Colored guide strips preserving the route color language.

## Preserved Locked Ports

All four locked S1 ports remain present and labeled:

- `S1_EAST_GROUND_A`
- `S1_NORTH_UPPER_A`
- `S1_SOUTH_RETURN_A`
- `S1_LOWER_HATCH_A`

Visual port frames are placed at the existing locked coordinates. Their collision is disabled where they dress an opening, so they do not create new blocking behavior or new traversable exits.

## Approved S1 Neighbors

S1 still connects only to the locked approved neighbors:

- `S2_BOUNTY_BOARD_HUB`
- `S5_UPPER_WALKWAY_OVERLAY`
- `S7_RETURN_UTILITY_STRIP`

No route graph, port ID, port coordinate, section bound, or validator data was changed.

## Intentionally Not Added

- No final art or final textures.
- No NPCs.
- No enemies.
- No mission scripting.
- No capture logic.
- No shops or economy scripting.
- No new exits, routes, hatches, ladders, ports, shortcuts, or sections.
- No changes to other sections except preserving the generated scene root list for baking.

## Validation

Layout validator:

```bash
python3 tools/validate_hesperus_market_layout.py --layout levels/hesperus_market/layout/hesperus_market_locked_layout.json --contract docs/level_design/hesperus_market/00_LOCKED_LAYOUT.md
```

Result:

- Passed.
- `sections=7`
- `ports=36`
- `physically_adjacent_pairs_checked=17`
- `long_route_pairs_skipped=1`

Godot scene/project checks:

```bash
/var/home/nick/Downloads/Godot_v4.6.1-stable_linux.x86_64 --headless --path . levels/hesperus_market/scenes/hesperus_market_graybox.tscn --quit
/var/home/nick/Downloads/Godot_v4.6.1-stable_linux.x86_64 --headless --path . --script tools/bake_hesperus_market_graybox_scene.gd
/var/home/nick/Downloads/Godot_v4.6.1-stable_linux.x86_64 --headless --path . --script tools/check_hesperus_market_graybox_scene.gd
/var/home/nick/Downloads/Godot_v4.6.1-stable_linux.x86_64 --headless --path . --quit
```

Result:

- Scene loaded.
- Scene baked.
- Graybox scene check passed with `sections=7`, `ports=36`, `port_labels_present=true`, `player_present=true`, and `world_collision_present=true`.
- Project headless check exited successfully.
- Some scene-specific headless commands still print existing Godot/player cleanup warnings at process exit.

## Remaining Concerns

- Needs visual review in the editor or in playtest to confirm first-person readability from `DEBUG_SPAWN_DOCK_START`.
- The upper catwalk cue is a placeholder visual cue only; future passes should refine the actual readable vertical access without changing the locked route graph.
- The neon route module currently shows all route color chips as a reusable kit module; the generated guide strip beneath it carries the specific route color.

## Next Recommended Pass

Apply the same visual blockout treatment to `S2_BOUNTY_BOARD_HUB`, focusing on the bounty board terminal, junction readability, and signs toward Dock, Bazaar, Side Alley, Upper Walkway, and Utility.
