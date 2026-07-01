from pathlib import Path

import bpy


ROOT = Path("/var/home/nick/bounty-hunt")
SOURCE_BLEND = ROOT / "assets/blender_models/Hesperus_CourtyardPerimeter_Phase1.blend"
OUTPUT_BLEND = ROOT / "assets/blender_models/Hesperus_CourtyardPerimeter_Phase2.blend"
OUTPUT_GLB = ROOT / "assets/blender_models/Hesperus_CourtyardPerimeter_Phase2.glb"

MATERIALS = [
    "M_WorkConcrete",
    "M_Street",
    "M_RustedMetal",
    "M_Grate",
    "M_DarkSteel",
    "N_WindowWarm",
    "N_Cyan",
    "N_Orange",
    "N_Magenta",
    "N_WindowCool",
    "N_Green",
    "M_TarpRed",
    "M_TarpGreen",
]


def godot_to_blender(location):
    x, y, z = location
    return (x, -z, y)


def godot_dimensions_to_blender(dimensions):
    width, height, depth = dimensions
    return (width, depth, height)


def box(name, location, dimensions, material, bevel=0.06):
    bpy.ops.mesh.primitive_cube_add(location=godot_to_blender(location))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = godot_dimensions_to_blender(dimensions)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        modifier = obj.modifiers.new("EdgeSoftening", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    obj.data.materials.append(bpy.data.materials[material])
    return obj


def west_facing_window(prefix, x, y, z, material):
    box(f"{prefix}_Window", (x, y, z), (0.18, 1.35, 1.7), material, 0.02)
    box(f"{prefix}_Lintel", (x - 0.04, y + 0.82, z), (0.28, 0.18, 2.05), "M_RustedMetal", 0.02)


bpy.ops.wm.read_factory_settings(use_empty=True)
with bpy.data.libraries.load(str(SOURCE_BLEND), link=False) as (source, target):
    target.materials = [name for name in MATERIALS if name in source.materials]

# NORTH EDGE: AlienBar_CourtyardAlley already supplies the complete security
# building. Its access door leads to EastMicroHub's CredentialInteriorLadder
# and the upper walkway, so Phase 2 must not replace or cut through that shell.
# These short ground cues terminate at the real south-facing door.
box("CP2_CredentialApproachCue_West", (110.3, 0.08, -27.0), (0.16, 0.05, 4.0), "N_Magenta", 0.01)
box("CP2_CredentialApproachCue_East", (114.3, 0.08, -27.0), (0.16, 0.05, 4.0), "N_Magenta", 0.01)

# EAST EDGE: two utility/hab masses stay behind x=143. The deliberate central
# portal leaves z=-5..12 open from the courtyard service grate to the exterior
# escape branch at (155, 10).
box("CP2_EastNorth_Podium", (152.0, 5.5, -15.0), (18.0, 11.0, 14.0), "M_WorkConcrete", 0.12)
box("CP2_EastNorth_Tower", (153.5, 17.0, -15.0), (15.0, 23.0, 14.0), "M_WorkConcrete", 0.14)
box("CP2_EastNorth_Roof", (153.5, 28.8, -15.0), (15.8, 0.6, 14.8), "M_DarkSteel")

box("CP2_EastSouth_Workshop", (152.5, 7.0, 19.0), (17.0, 14.0, 12.0), "M_WorkConcrete", 0.12)
box("CP2_EastSouth_Roof", (152.5, 14.3, 19.0), (17.8, 0.6, 12.8), "M_DarkSteel")
box("CP2_EastSouth_WorkshopBand", (143.86, 3.0, 19.0), (0.28, 4.8, 10.0), "M_RustedMetal", 0.03)

for row, height in enumerate((8.5, 13.0, 17.5, 22.0)):
    for column, z_value in enumerate((-19.0, -14.5, -10.0)):
        material = "N_WindowWarm" if (row * 2 + column) % 4 == 0 else "N_WindowCool"
        west_facing_window(f"CP2_EastNorth_{row}_{column}", 143.88, height, z_value, material)

for index, z_value in enumerate((16.0, 21.0)):
    box(f"CP2_EastSouth_Door_{index}", (143.68, 2.4, z_value), (0.35, 4.8, 3.6), "M_DarkSteel", 0.03)
    box(f"CP2_EastSouth_DoorGlow_{index}", (143.46, 5.0, z_value), (0.12, 0.2, 2.6), "N_Orange", 0.01)

# Route-readable service portal. The piers sit outside the z=-5..12 traversal
# band; only the high header spans it.
box("CP2_ServicePortal_NorthPier", (143.6, 5.0, -6.4), (1.2, 10.0, 2.0), "M_RustedMetal", 0.05)
box("CP2_ServicePortal_SouthPier", (143.6, 5.0, 13.4), (1.2, 10.0, 2.0), "M_RustedMetal", 0.05)
box("CP2_ServicePortal_Header", (143.6, 10.0, 3.5), (1.2, 1.2, 21.8), "M_DarkSteel", 0.05)
box("CP2_ServicePortal_Glow", (142.92, 9.8, 3.5), (0.12, 0.24, 15.0), "N_Cyan", 0.01)
box("CP2_ServicePortal_Sign", (142.8, 7.4, 8.8), (0.12, 2.0, 5.0), "N_Green", 0.02)

# Fire-escape silhouette above the east crouch route. It is visual context, not
# a new climb path, and remains outside the route's ground clearance.
for index, height in enumerate((9.0, 14.0, 19.0)):
    box(f"CP2_East_Balcony_{index}", (142.8, height, -15.0), (2.2, 0.3, 9.0), "M_Grate", 0.04)
    box(f"CP2_East_BalconyRail_{index}", (141.72, height + 0.65, -15.0), (0.12, 1.3, 9.0), "M_RustedMetal", 0.02)

for z_value in (-21.0, -15.0, -9.0, 15.0, 21.0):
    box(f"CP2_East_Rib_{z_value}", (143.78, 12.0, z_value), (0.35, 18.0, 0.32), "M_RustedMetal", 0.03)

box("CP2_East_RoofPlant", (153.0, 31.0, -15.0), (7.0, 3.0, 5.0), "M_DarkSteel")

bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND))
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT_GLB),
    export_format="GLB",
    export_apply=True,
    use_selection=False,
)
print(f"Built {OUTPUT_BLEND}")
print(f"Exported {OUTPUT_GLB}")
