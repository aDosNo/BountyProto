from pathlib import Path

import bpy


ROOT = Path("/var/home/nick/bounty-hunt")
SOURCE_BLEND = ROOT / "assets/blender_models/Hesperus_Market2_Street.blend"
OUTPUT_BLEND = ROOT / "assets/blender_models/Hesperus_BazaarAlienBar_Transition.blend"
OUTPUT_GLB = ROOT / "assets/blender_models/Hesperus_BazaarAlienBar_Transition.glb"

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
    # This module is authored in Godot world coordinates. Blender exports
    # (x, y, z) as Godot (x, z, -y), so convert once at the construction edge.
    godot_x, godot_y, godot_z = location
    godot_width, godot_height, godot_depth = dimensions
    blender_location = (godot_x, -godot_z, godot_y)
    blender_dimensions = (godot_width, godot_depth, godot_height)
    bpy.ops.mesh.primitive_cube_add(location=blender_location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = blender_dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        modifier = obj.modifiers.new("EdgeSoftening", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    obj.data.materials.append(bpy.data.materials[material])
    return obj


def stairs_x(name, start, count, run, rise, width, material):
    x, y, z = start
    for index in range(count):
        box(
            f"{name}_Step_{index:02d}",
            (x + index * run, y + index * rise, z),
            (run, rise, width),
            material,
            0.015,
        )


def shop_shell(prefix, x_center, width, z_front, depth, height, sign_material):
    z_center = z_front - depth * 0.5
    box(f"{prefix}_Floor", (x_center, -2.7, z_center), (width, 0.22, depth), "M_Street", 0.03)
    box(f"{prefix}_Rear", (x_center, height * 0.5 - 2.8, z_front - depth), (width, height, 0.3), "M_WorkConcrete")
    box(f"{prefix}_Left", (x_center - width * 0.5, height * 0.5 - 2.8, z_center), (0.3, height, depth), "M_WorkConcrete")
    box(f"{prefix}_Right", (x_center + width * 0.5, height * 0.5 - 2.8, z_center), (0.3, height, depth), "M_WorkConcrete")
    box(f"{prefix}_FrontLeft", (x_center - width * 0.31, height * 0.5 - 2.8, z_front), (width * 0.38, height, 0.3), "M_WorkConcrete")
    box(f"{prefix}_FrontRight", (x_center + width * 0.31, height * 0.5 - 2.8, z_front), (width * 0.38, height, 0.3), "M_WorkConcrete")
    box(f"{prefix}_Header", (x_center, height - 3.15, z_front), (width * 0.24, 0.7, 0.45), "M_RustedMetal")
    box(f"{prefix}_Counter", (x_center, -1.72, z_front - depth + 1.2), (width * 0.58, 1.0, 1.8), "M_RustedMetal")
    box(f"{prefix}_Sign", (x_center, height + 0.1, z_front + 0.2), (width * 0.55, 0.18, 0.9), sign_material, 0.02)


bpy.ops.wm.read_factory_settings(use_empty=True)
with bpy.data.libraries.load(str(SOURCE_BLEND), link=False) as (source, target):
    target.materials = [name for name in MATERIALS if name in source.materials]

# Ground seam from the north end of the bazaar toward the Alien Bar forecourt.
box("BAT_MainPassage", (18.0, -2.76, -49.0), (44.0, 0.18, 31.0), "M_Street", 0.02)
box("BAT_WalkwayUnderlay", (18.0, -2.68, -44.4), (44.0, 0.16, 9.0), "M_Grate", 0.02)

# UNDERWALK MARKET: shops occupy side bays and keep x=8..20 open beneath the
# clue position. Roofs stop below y=8.5, preserving the elevated walkway.
shop_shell("BAT_NoodleShop", 2.5, 8.0, -39.8, 7.0, 10.5, "N_Orange")
shop_shell("BAT_WeaponRepair", 28.0, 12.0, -39.8, 7.0, 10.5, "N_Magenta")
shop_shell("BAT_CyberReseller", 40.0, 9.0, -39.8, 7.0, 10.5, "N_Cyan")

# Shop roofs remain beneath WalkwayNorth (top y≈11.76).
for x_center, width in ((2.5, 8.5), (28.0, 12.5), (40.0, 9.5)):
    box(f"BAT_UnderwalkRoof_{x_center}", (x_center, 8.25, -43.3), (width, 0.4, 7.4), "M_DarkSteel")
    box(f"BAT_UnderwalkAwning_{x_center}", (x_center, 1.0, -39.0), (width - 1.0, 2.0, 0.3), "M_TarpRed")

# Structural columns explain the elevated route and create cover rhythm.
for x_value in (-3.0, 8.0, 20.0, 35.0, 47.0):
    box(f"BAT_WalkwayColumn_{x_value}", (x_value, 4.0, -44.5), (0.75, 13.5, 0.75), "M_RustedMetal")
    box(f"BAT_ColumnFoot_{x_value}", (x_value, -2.35, -44.5), (1.6, 0.7, 1.6), "M_DarkSteel")

# VERTICAL CONNECTOR: a narrow stair/elevator tower beside WalkwayWest.
# The staircase reaches the existing upper deck without crossing Clue 03.
box("BAT_ConnectorTower", (-1.0, 4.0, -55.0), (8.0, 13.5, 9.0), "M_WorkConcrete", 0.1)
box("BAT_ConnectorRoof", (-1.0, 11.0, -55.0), (8.6, 0.55, 9.6), "M_DarkSteel")
box("BAT_ElevatorDoor", (3.15, 0.0, -55.0), (0.3, 4.0, 2.8), "M_DarkSteel")
box("BAT_ElevatorGlow", (3.33, 2.2, -55.0), (0.12, 0.18, 2.2), "N_Cyan", 0.01)
stairs_x("BAT_ConnectorStair", (-5.6, -2.55, -50.0), 28, 0.34, 0.48, 2.4, "M_Grate")
box("BAT_ConnectorUpperLanding", (4.2, 10.78, -50.0), (4.0, 0.3, 2.8), "M_Grate")
box("BAT_ConnectorBridge", (1.5, 10.78, -46.8), (6.5, 0.3, 3.6), "M_Grate")
box("BAT_ConnectorRail", (1.5, 11.45, -48.5), (6.5, 1.3, 0.12), "M_RustedMetal")

# UPPER SHOP FRONTAGE: shallow businesses attach to the north edge of the
# walkway. The Clue 03 bay x=8..18 remains open with no shop in front of it.
for name, x_center, width, material in [
    ("BAT_UpperTeaHouse", 0.0, 8.0, "N_Orange"),
    ("BAT_UpperTailor", 25.0, 10.0, "N_Green"),
    ("BAT_UpperBroker", 39.0, 9.0, "N_Magenta"),
]:
    box(f"{name}_Mass", (x_center, 14.2, -53.0), (width, 7.0, 7.0), "M_WorkConcrete", 0.08)
    box(f"{name}_Window", (x_center, 14.4, -49.42), (width * 0.5, 2.0, 0.16), "N_WindowWarm", 0.02)
    box(f"{name}_Door", (x_center - width * 0.28, 13.2, -49.4), (1.6, 3.8, 0.25), "M_DarkSteel")
    box(f"{name}_Sign", (x_center + width * 0.28, 16.0, -49.3), (width * 0.28, 0.8, 0.16), material, 0.02)
    box(f"{name}_Roof", (x_center, 17.9, -53.0), (width + 0.6, 0.5, 7.6), "M_DarkSteel")

# ALIEN BAR FORECOURT: intentionally open center with services at the edges.
box("BAT_ForecourtFloor", (17.0, -2.7, -60.0), (24.0, 0.22, 10.0), "M_Street", 0.03)
box("BAT_FoodCounter", (5.5, -1.7, -59.5), (3.0, 2.0, 5.0), "M_RustedMetal")
box("BAT_FoodAwning", (5.5, 1.3, -59.5), (4.0, 0.3, 6.0), "M_TarpGreen")
box("BAT_SecurityBooth", (28.0, -0.3, -59.5), (4.0, 5.0, 5.0), "M_WorkConcrete")
box("BAT_SecurityWindow", (25.9, 0.2, -59.5), (0.16, 1.8, 2.0), "N_WindowCool", 0.02)
box("BAT_QueueRail_A", (11.0, -1.9, -57.0), (8.0, 0.12, 0.12), "M_RustedMetal", 0.01)
box("BAT_QueueRail_B", (20.0, -1.9, -57.0), (8.0, 0.12, 0.12), "M_RustedMetal", 0.01)
box("BAT_ForecourtSign", (17.0, 5.0, -64.0), (10.0, 1.2, 0.3), "N_Magenta", 0.02)

# EAST MIXED-USE WEDGE: set north of BarEastRamp's z≈-55 edge. Two wings
# frame the approach without occupying the ramp volume.
box("BAT_EastWedgeWest", (32.5, 2.5, -60.5), (5.0, 10.5, 7.0), "M_WorkConcrete", 0.1)
box("BAT_EastWedgeEast", (46.0, 4.0, -60.5), (7.0, 13.5, 7.0), "M_WorkConcrete", 0.1)
box("BAT_EastWedgeBridge", (39.2, 8.5, -60.5), (8.5, 0.35, 3.0), "M_Grate")
box("BAT_EastWedgeFireEscape", (43.0, 3.0, -57.2), (5.0, 0.3, 2.0), "M_Grate")
for row, height in enumerate((1.5, 5.0, 8.5)):
    for x_value in (31.0, 45.0, 47.0):
        box(f"BAT_EastWedgeWindow_{row}_{x_value}", (x_value, height, -57.05), (1.5, 1.3, 0.14), "N_WindowWarm" if row % 2 == 0 else "N_WindowCool", 0.02)
box("BAT_EastWedge_LaundrySign", (46.0, 5.5, -56.9), (3.5, 0.9, 0.16), "N_Cyan", 0.02)

# Overhead signs/cables visually bind bazaar and bar without blocking movement.
box("BAT_OverheadSignFrame_L", (8.0, 5.2, -52.0), (0.2, 8.0, 0.2), "M_RustedMetal")
box("BAT_OverheadSignFrame_R", (25.0, 5.2, -52.0), (0.2, 8.0, 0.2), "M_RustedMetal")
box("BAT_OverheadSign", (16.5, 8.0, -52.0), (11.0, 2.2, 0.3), "N_Orange", 0.02)

bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND))
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT_GLB),
    export_format="GLB",
    export_apply=True,
    use_selection=False,
)
print(f"Built {OUTPUT_BLEND}")
print(f"Exported {OUTPUT_GLB}")
