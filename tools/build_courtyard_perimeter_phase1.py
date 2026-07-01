from pathlib import Path

import bpy


ROOT = Path("/var/home/nick/bounty-hunt")
SOURCE_BLEND = ROOT / "assets/blender_models/Hesperus_Market2_Street.blend"
OUTPUT_BLEND = ROOT / "assets/blender_models/Hesperus_CourtyardPerimeter_Phase1.blend"
OUTPUT_GLB = ROOT / "assets/blender_models/Hesperus_CourtyardPerimeter_Phase1.glb"

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


def box(name, location, dimensions, material, bevel=0.06):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        modifier = obj.modifiers.new("EdgeSoftening", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    obj.data.materials.append(bpy.data.materials[material])
    return obj


def inward_window(prefix, x, z, y, material):
    box(f"{prefix}_Window", (x, z, y), (0.18, 1.7, 1.35), material, 0.02)
    box(f"{prefix}_Lintel", (x - 0.04, z, y + 0.82), (0.28, 2.05, 0.18), "M_RustedMetal", 0.02)


def south_window(prefix, x, z, y, material):
    box(f"{prefix}_Window", (x, z, y), (1.7, 0.18, 1.35), material, 0.02)
    box(f"{prefix}_Lintel", (x, z - 0.04, y + 0.82), (2.05, 0.28, 0.18), "M_RustedMetal", 0.02)


bpy.ops.wm.read_factory_settings(use_empty=True)
with bpy.data.libraries.load(str(SOURCE_BLEND), link=False) as (source, target):
    target.materials = [name for name in MATERIALS if name in source.materials]

# EAST SIDE: one conglomerate hab/utility megablock. Its west face sits at
# x=142, leaving the existing x=137-140 crouch route and ladder clear.
box("CP_EastMega_Podium", (151.0, -4.0, 5.2), (18.0, 40.0, 10.4), "M_WorkConcrete", 0.12)
box("CP_EastMega_TowerNorth", (153.5, -14.0, 18.0), (13.0, 19.0, 25.6), "M_WorkConcrete", 0.14)
box("CP_EastMega_TowerSouth", (150.0, 8.0, 15.2), (16.0, 15.0, 20.0), "M_WorkConcrete", 0.14)
box("CP_EastMega_RoofNorth", (153.5, -14.0, 31.1), (13.8, 19.8, 0.6), "M_DarkSteel")
box("CP_EastMega_RoofSouth", (150.0, 8.0, 25.5), (16.8, 15.8, 0.6), "M_DarkSteel")

# Courtyard-facing service band, utility recess, and corporate identity.
box("CP_EastMega_ServiceBand", (141.86, -4.0, 3.8), (0.25, 39.0, 2.0), "M_DarkSteel", 0.03)
box("CP_EastMega_UtilityRecess", (141.7, 2.0, 2.3), (0.45, 5.0, 4.6), "M_RustedMetal", 0.04)
box("CP_EastMega_LadderRecess", (141.7, -19.0, 5.0), (0.45, 4.2, 10.0), "M_DarkSteel", 0.04)
box("CP_EastMega_CorpBand", (141.65, -4.0, 10.2), (0.16, 31.0, 0.22), "N_Magenta", 0.01)
box("CP_EastMega_UtilityGlow", (141.58, 2.0, 3.8), (0.12, 3.5, 0.18), "N_Orange", 0.01)

for row, height in enumerate((7.0, 11.0, 15.0, 19.0, 23.0)):
    for column, z_value in enumerate((-14.0, -9.5, -5.0, 5.5, 10.0)):
        if z_value < -16.0 or (row < 2 and abs(z_value - 2.0) < 3.0):
            continue
        material = "N_WindowWarm" if (row + column) % 4 == 0 else "N_WindowCool"
        inward_window(f"CP_EastMega_{row}_{column}", 141.82, z_value, height, material)

# Fire-escape silhouettes face inward but do not create a new functional route.
for height in (8.4, 13.4, 18.4):
    box(f"CP_EastMega_Balcony_{height}", (141.0, -8.0, height), (2.2, 9.0, 0.3), "M_Grate", 0.04)
    box(f"CP_EastMega_BalconyRail_{height}", (139.95, -8.0, height + 0.65), (0.12, 9.0, 1.3), "M_RustedMetal", 0.02)

for z_value in (-21.0, -13.0, -5.0, 5.0, 13.0):
    box(f"CP_EastMega_Rib_{z_value}", (141.72, z_value, 13.0), (0.35, 0.32, 18.0), "M_RustedMetal", 0.03)

box("CP_EastMega_RoofPlant", (151.0, -3.0, 27.5), (7.0, 5.0, 3.0), "M_DarkSteel")
box("CP_EastMega_Antenna", (154.0, -14.0, 36.0), (0.18, 0.18, 9.0), "M_DarkSteel", 0.02)

# SOUTH SIDE: narrow skid-row tenements. The x=123-133 gap preserves the
# return gate and ramp, making it read as the block's freight/service passage.
south_blocks = [
    ("West", 94.5, 13.0, 18.0, 4),
    ("Middle", 110.5, 15.0, 22.0, 5),
    ("East", 139.0, 11.0, 16.0, 4),
]
for name, x_center, width, height, floors in south_blocks:
    z_center = 27.0
    box(f"CP_South{name}_Mass", (x_center, z_center, height / 2.0), (width, 17.0, height), "M_WorkConcrete", 0.12)
    box(f"CP_South{name}_Roof", (x_center, z_center, height + 0.3), (width + 0.7, 17.7, 0.6), "M_DarkSteel")
    box(f"CP_South{name}_WorkshopBand", (x_center, 18.35, 2.2), (width - 1.0, 0.5, 4.4), "M_RustedMetal", 0.04)

    window_columns = max(2, int(width // 3))
    for floor in range(1, floors):
        y_value = 3.4 + floor * 3.3
        for column in range(window_columns):
            x_value = x_center - (window_columns - 1) * 1.45 + column * 2.9
            material = "N_WindowWarm" if (floor + column) % 3 == 0 else "N_WindowCool"
            south_window(f"CP_South{name}_{floor}_{column}", x_value, 18.38, y_value, material)

    for floor in range(1, floors - 1):
        balcony_y = 4.7 + floor * 3.3
        box(f"CP_South{name}_Balcony_{floor}", (x_center, 17.45, balcony_y), (width - 2.0, 1.6, 0.28), "M_Grate", 0.04)
        box(f"CP_South{name}_Rail_{floor}", (x_center, 16.72, balcony_y + 0.62), (width - 2.0, 0.12, 1.25), "M_RustedMetal", 0.02)

    box(f"CP_South{name}_Awning", (x_center, 17.2, 4.5), (width - 1.8, 2.0, 0.3), "M_TarpRed")

# Street-level doors and informal additions make the row inhabited.
for index, x_value in enumerate((90.5, 97.0, 106.5, 114.5, 138.5)):
    box(f"CP_SouthDoor_{index}", (x_value, 18.0, 2.1), (2.1, 0.35, 4.2), "M_DarkSteel", 0.03)
for index, x_value in enumerate((92.0, 101.0, 109.0, 117.0, 138.0)):
    box(f"CP_SouthLaundryLine_{index}", (x_value, 16.4, 9.8 + (index % 2) * 3.2), (5.0, 0.08, 0.08), "M_RustedMetal", 0.01)

# Return-gate architectural frame and address signage. No collision crosses the
# established x=123-133 passage.
box("CP_ReturnPassage_LeftPier", (121.5, 21.0, 5.0), (1.2, 6.0, 10.0), "M_RustedMetal", 0.05)
box("CP_ReturnPassage_RightPier", (134.0, 21.0, 5.0), (1.2, 6.0, 10.0), "M_RustedMetal", 0.05)
box("CP_ReturnPassage_Header", (127.75, 21.0, 10.0), (13.7, 6.0, 1.0), "M_DarkSteel", 0.05)
box("CP_ReturnPassage_Glow", (127.75, 17.92, 9.9), (8.0, 0.12, 0.22), "N_Green", 0.01)

# Corner stitching prevents the east and south masses reading as unrelated.
box("CP_Southeast_ServiceStack", (145.0, 20.5, 10.0), (8.0, 8.0, 20.0), "M_WorkConcrete", 0.12)
box("CP_Southeast_Roof", (145.0, 20.5, 20.3), (8.7, 8.7, 0.6), "M_DarkSteel")
box("CP_Southeast_Sign", (140.9, 18.0, 7.0), (0.18, 3.2, 1.2), "N_Cyan", 0.02)

bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND))
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT_GLB),
    export_format="GLB",
    export_apply=True,
    use_selection=False,
)
print(f"Built {OUTPUT_BLEND}")
print(f"Exported {OUTPUT_GLB}")
