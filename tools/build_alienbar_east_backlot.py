from pathlib import Path

import bpy


ROOT = Path("/var/home/nick/bounty-hunt")
SOURCE_BLEND = ROOT / "assets/blender_models/Hesperus_CourtyardPerimeter_Phase1.blend"
OUTPUT_BLEND = ROOT / "assets/blender_models/Hesperus_AlienBar_EastBacklot.blend"
OUTPUT_GLB = ROOT / "assets/blender_models/Hesperus_AlienBar_EastBacklot.glb"

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


def south_window(prefix, x, y, z, material):
    box(f"{prefix}_Window", (x, y, z), (1.7, 1.35, 0.18), material, 0.02)
    box(f"{prefix}_Lintel", (x, y + 0.82, z - 0.04), (2.05, 0.18, 0.28), "M_RustedMetal", 0.02)


def west_window(prefix, x, y, z, material):
    box(f"{prefix}_Window", (x, y, z), (0.18, 1.35, 1.7), material, 0.02)
    box(f"{prefix}_Lintel", (x - 0.04, y + 0.82, z), (0.28, 0.18, 2.05), "M_RustedMetal", 0.02)


bpy.ops.wm.read_factory_settings(use_empty=True)
with bpy.data.libraries.load(str(SOURCE_BLEND), link=False) as (source, target):
    target.materials = [name for name in MATERIALS if name in source.materials]

# NORTH WORKER BLOCK: closes the distant blockout-wall gap without consuming
# the central backlot. Its inhabited south face keeps the court socially legible.
box("ABL_NorthWorker_Mass", (66.0, 10.0, -79.0), (26.0, 20.0, 7.0), "M_WorkConcrete", 0.12)
box("ABL_NorthWorker_Roof", (66.0, 20.3, -79.0), (26.8, 0.6, 7.8), "M_DarkSteel")
box("ABL_NorthWorker_ServiceBand", (66.0, 2.6, -75.38), (23.5, 5.2, 0.28), "M_RustedMetal", 0.03)
box("ABL_NorthWorker_CorpGlow", (66.0, 6.0, -75.18), (20.0, 0.2, 0.12), "N_Magenta", 0.01)

for index, x_value in enumerate((56.0, 62.5, 69.0, 75.5)):
    box(f"ABL_NorthWorker_Door_{index}", (x_value, 2.2, -75.18), (3.0, 4.4, 0.35), "M_DarkSteel", 0.03)
for row, height in enumerate((8.2, 12.4, 16.6)):
    for column, x_value in enumerate((56.0, 61.0, 66.0, 71.0, 76.0)):
        material = "N_WindowWarm" if (row + column) % 3 == 0 else "N_WindowCool"
        south_window(f"ABL_NorthWorker_{row}_{column}", x_value, height, -75.28, material)

box("ABL_NorthWorker_RoofPlant", (69.0, 22.0, -79.0), (8.0, 3.0, 4.0), "M_DarkSteel")
box("ABL_NorthWorker_Antenna", (75.0, 27.0, -79.0), (0.18, 10.0, 0.18), "M_DarkSteel", 0.02)

# EAST REPAIR/HAB BLOCK: creates a dense edge while leaving x>=98 open for the
# ground lane toward the courtyard service street.
box("ABL_EastRepair_Mass", (90.0, 8.5, -73.0), (12.0, 17.0, 14.0), "M_WorkConcrete", 0.12)
box("ABL_EastRepair_Roof", (90.0, 17.3, -73.0), (12.8, 0.6, 14.8), "M_DarkSteel")
box("ABL_EastRepair_WorkshopBand", (83.88, 2.8, -70.0), (0.28, 5.6, 7.0), "M_RustedMetal", 0.03)
box("ABL_EastRepair_Door", (83.68, 2.5, -70.0), (0.35, 5.0, 3.8), "M_DarkSteel", 0.03)
box("ABL_EastRepair_DoorGlow", (83.45, 5.2, -70.0), (0.12, 0.2, 2.8), "N_Orange", 0.01)

for row, height in enumerate((8.0, 12.0)):
    for column, z_value in enumerate((-77.0, -73.0, -69.0)):
        material = "N_WindowWarm" if (row + column) % 2 == 0 else "N_WindowCool"
        west_window(f"ABL_EastRepair_{row}_{column}", 83.86, height, z_value, material)

box("ABL_EastRepair_Sign", (83.45, 8.0, -65.8), (0.12, 2.2, 4.0), "N_Cyan", 0.02)
box("ABL_EastRepair_RoofTank", (91.0, 19.0, -74.0), (4.0, 2.8, 4.0), "M_DarkSteel")

# ALIEN BAR SERVICE ANNEX: stitches the bar's east wall into the backlot without
# sealing the west entrance at x=43..52.
box("ABL_BarAnnex_Mass", (47.0, 5.5, -76.0), (6.0, 11.0, 10.0), "M_WorkConcrete", 0.1)
box("ABL_BarAnnex_Roof", (47.0, 11.3, -76.0), (6.8, 0.6, 10.8), "M_DarkSteel")
box("ABL_BarAnnex_ServiceDoor", (50.08, 2.3, -72.5), (0.28, 4.6, 3.4), "M_DarkSteel", 0.03)
box("ABL_BarAnnex_Glow", (50.28, 4.9, -72.5), (0.12, 0.2, 2.5), "N_Magenta", 0.01)

# SOUTH EDGE SHOPS: shallow frontage keeps the service-street threshold visible.
for name, x_value, material in [
    ("Food", 61.0, "M_TarpRed"),
    ("Parts", 70.0, "M_Grate"),
]:
    box(f"ABL_{name}Stall_Mass", (x_value, 2.5, -62.0), (7.0, 5.0, 4.0), "M_WorkConcrete", 0.08)
    box(f"ABL_{name}Stall_Counter", (x_value, 1.2, -59.9), (5.5, 1.2, 0.5), "M_RustedMetal", 0.03)
    box(f"ABL_{name}Stall_Awning", (x_value, 4.2, -59.3), (6.2, 0.28, 2.0), material, 0.04)
    box(f"ABL_{name}Stall_Sign", (x_value, 5.3, -59.0), (4.0, 0.9, 0.12), "N_Orange", 0.02)

# GROUND LOOP: paired cues expose the L-shaped route from the bar's east service
# edge through the backlot and east toward the courtyard-access street.
box("ABL_GroundCue_Bar", (48.0, 0.08, -68.0), (8.0, 0.05, 0.16), "N_Magenta", 0.01)
box("ABL_GroundCue_CourtWest", (62.0, 0.08, -68.0), (18.0, 0.05, 0.16), "N_Cyan", 0.01)
box("ABL_GroundCue_CourtEast", (77.0, 0.08, -66.0), (14.0, 0.05, 0.16), "N_Cyan", 0.01)
box("ABL_GroundCue_ServiceLane", (99.0, 0.08, -62.0), (30.0, 0.05, 0.16), "N_Green", 0.01)
box("ABL_BacklotRouteSign", (82.0, 6.4, -63.5), (0.18, 2.0, 5.5), "N_Green", 0.02)

# WALKABLE UPPER LINK: a short stair reaches y=4.45, then a bridge follows the
# verified-clear x=79 corridor to EastMicroHub's VendorLanding at z≈-35.3.
step_count = 12
for index in range(step_count):
    ratio = index / (step_count - 1)
    z_value = -67.0 + ratio * 9.0
    top_height = (index + 1) * (4.45 / step_count)
    box(
        f"ABL_UpperStair_{index:02d}",
        (79.0, top_height / 2.0, z_value),
        (3.2, top_height, 0.9),
        "M_Grate",
        0.025,
    )
    box(
        f"ABL_UpperStairRailL_{index:02d}",
        (77.36, top_height + 0.55, z_value),
        (0.12, 1.1, 0.9),
        "M_RustedMetal",
        0.015,
    )
    box(
        f"ABL_UpperStairRailR_{index:02d}",
        (80.64, top_height + 0.55, z_value),
        (0.12, 1.1, 0.9),
        "M_RustedMetal",
        0.015,
    )

box("ABL_UpperBridgeDeck", (79.0, 4.45, -46.7), (2.2, 0.25, 22.6), "M_Grate", 0.04)
box("ABL_UpperBridgeRailL", (77.94, 5.1, -46.7), (0.12, 1.3, 22.6), "M_RustedMetal", 0.02)
box("ABL_UpperBridgeRailR", (80.06, 5.1, -46.7), (0.12, 1.3, 22.6), "M_RustedMetal", 0.02)
box("ABL_UpperRouteGlow", (79.0, 4.64, -46.7), (0.16, 0.05, 20.0), "N_Magenta", 0.01)
box("ABL_UpperRouteSign", (80.18, 6.3, -57.0), (0.12, 1.5, 4.0), "N_Cyan", 0.02)

# Overhead utility lines tie the court together without adding ground collision.
box("ABL_OverheadPipe", (68.0, 7.0, -70.0), (32.0, 0.18, 0.18), "M_RustedMetal", 0.02)
box("ABL_OverheadCable", (68.0, 8.0, -65.0), (38.0, 0.08, 0.08), "N_Cyan", 0.01)

bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND))
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT_GLB),
    export_format="GLB",
    export_apply=True,
    use_selection=False,
)
print(f"Built {OUTPUT_BLEND}")
print(f"Exported {OUTPUT_GLB}")
