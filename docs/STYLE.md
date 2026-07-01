# bounty-hunt — Style Bible (GZDoom / Build-engine retro sci-fi)

Status: current visual contract, reconciled 2026-07-01.

Aesthetic target: cancelled-Prey-2-inspired bounty district rendered like a
late-90s Build/GZDoom game in true 3D: simple geometry, strong vertical facades,
billboarded sprite NPCs, neon emissive signage, modular reusable blocks.

## Geometry
- Simple primitives and low-poly Blender modules. Detail comes from silhouette,
  signage, and light — not mesh density.
- Strong verticals: facades read tall (20–55u building masses in scene already
  set this language). Street canyons, overhead beams, cables.
- Modular blocks: prefer instancing `PS1_*` subscenes and `VK_*`/GLB modules
  over bespoke one-off meshes. New repeated props become subscenes.
- Blender-linked modular assemblies are acceptable for architectural sets that
  must export as one shell. The June 30 Bazaar stalls are the current example;
  keep gameplay, mutable props, and stateful interactions in Godot.

## Canonical materials
- Authoritative retro set (ext_resource .tres, reuse these):
  `M_Retro_HazardYellow`, `M_Retro_Black`, `M_Retro_CyanGlow`,
  `M_Retro_MagentaGlow`, `M_Retro_AlarmRed`, `M_Retro_WallBlue`
  (under `assets/materials/retro/`).
- The blockout also carries scene-local sub_resource materials
  (Material_wall_dark, Material_neon_*, Material_terminal_*, etc.).
  TODO: promote recurring ones to `.tres` so they're shareable; until then,
  match existing scene-local materials rather than inventing near-duplicates.

## Decal vs. solid rule (established convention — keep it)
- FLAT graphics on floors/walls (strips, dashes, decals, painted signs):
  plain `MeshInstance3D`, thin box ≈ 0.04–0.06u, NO collision.
- RAISED solids the player can touch (curbs, counters, steps, cover):
  `StaticBody3D` + Mesh + CollisionShape3D.

## Emissive / neon language
- Neon = thin emissive box (0.08–0.12u deep) or `PS1_NeonGlyphSign` instance.
- Route/zone color meaning is gameplay information, not decoration:
  green extraction · yellow bounty · blue investigation · purple elevated ·
  orange utility · red target/danger. Don't spend a route color on flavor.
- Per-zone light color language (already in scene — preserve):
  dock cyan-blue · bazaar warm orange · alley cool blue · walkway purple ·
  courtyard red · fountain cyan glow · lanterns warm.

## Sprite NPCs (Build/Doom directional billboards)
- `Sprite3D`, billboard mode, per-angle texture swap driven by camera→NPC angle.
- Source: character turnaround sheets (multi-angle reference art) sliced into
  directional frames. Mirror right-side frames to fake left-side views.
- Pixel-crisp filtering (nearest), consistent pixel density across NPC set.

## Text in world
- `Label3D` on emissive panels for diegetic signage (DOCK 07, WANTED, BOUNTIES →).
  Dark text on bright panel. Debug labels stay in `DebugLabels/` and ship hidden.

## Art discipline
- Graybox first: no sprite/art production until stealth, social, and force are
  all fun in playtest. Art grows lazily from what the blockout proves it needs.
