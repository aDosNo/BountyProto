from pathlib import Path

import bpy


ROOT = Path("/var/home/nick/bounty-hunt")
SOURCE_BLEND = ROOT / "assets/blender_models/Hesperus_Market2_Street.blend"
OUTPUT_BLEND = ROOT / "assets/blender_models/Hesperus_BazaarSafehouse.blend"
OUTPUT_GLB = ROOT / "assets/blender_models/Hesperus_BazaarSafehouse.glb"

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


bpy.ops.wm.read_factory_settings(use_empty=True)
with bpy.data.libraries.load(str(SOURCE_BLEND), link=False) as (source, target):
    target.materials = [name for name in MATERIALS if name in source.materials]

# A compact 20m x 22m infill replacing Building24. The west face addresses the
# bazaar/east-approach seam; service and ladder routes remain readable outside.
box("BS_StreetApron", (-7.5, 0.0, 0.08), (5.0, 15.0, 0.16), "M_Street", 0.03)
box("BS_RearServiceApron", (2.8, -8.7, 0.08), (12.5, 4.0, 0.16), "M_Street", 0.03)

box("BS_MarketHall_Mass", (-1.7, 1.2, 5.2), (10.8, 16.5, 10.4), "M_WorkConcrete", 0.12)
box("BS_ServiceTower_Mass", (5.1, -1.0, 7.0), (5.2, 12.0, 14.0), "M_WorkConcrete", 0.12)
box("BS_MarketHall_RoofCap", (-1.7, 1.2, 10.65), (11.4, 17.1, 0.5), "M_DarkSteel")
box("BS_ServiceTower_RoofCap", (5.1, -1.0, 14.25), (5.7, 12.5, 0.5), "M_DarkSteel")

# Two active street stalls make district heat physically visible.
for index, y_value in enumerate((-3.5, 4.0)):
    box(f"BS_Stall_{index}_Counter", (-7.0, y_value, 1.05), (1.6, 4.8, 2.1), "M_RustedMetal")
    box(f"BS_Stall_{index}_Awning", (-7.8, y_value, 3.7), (2.2, 5.5, 0.3), "M_TarpRed")
    box(f"BS_StreetShutter_{'A' if index == 0 else 'B'}", (-8.15, y_value, 6.2), (0.22, 4.5, 3.0), "M_DarkSteel", 0.03)

box("BS_BrokerReader", (-8.35, 0.15, 1.5), (0.32, 0.8, 1.5), "N_Cyan", 0.02)
box("BS_BrokerGlow", (-8.45, 0.15, 2.2), (0.12, 0.7, 0.16), "N_Cyan", 0.01)
box("BS_PublicSign", (-8.25, 5.7, 6.8), (0.2, 3.0, 1.0), "N_Orange", 0.02)

# Shared cache remains visible from the street between the two stalls.
box("BS_HunterCacheFrame", (-6.95, 0.15, 2.45), (0.55, 3.2, 4.9), "M_RustedMetal")
box("BS_HunterCacheDoor", (-7.25, 0.15, 2.2), (0.28, 2.3, 4.4), "M_DarkSteel", 0.03)
box("BS_CacheGlow", (-7.42, 0.15, 3.25), (0.12, 1.5, 0.18), "N_Magenta", 0.01)

# Rear utility route is spatially separate from the public street.
box("BS_ServiceDoorFrame", (1.8, -7.45, 2.4), (5.2, 0.5, 4.8), "M_RustedMetal")
box("BS_ServiceDoor", (1.8, -7.72, 2.1), (4.2, 0.22, 4.2), "M_DarkSteel", 0.03)
box("BS_ServiceBypass", (-1.0, -7.95, 1.45), (0.8, 0.38, 1.5), "N_Green", 0.02)
box("BS_ServicePipe", (6.5, -6.4, 4.0), (0.65, 0.65, 7.5), "M_RustedMetal")

# Exposed vertical route to a roof override.
ladder_x = 7.45
ladder_y = -6.8
box("BS_RoofLadderRail_L", (ladder_x - 0.55, ladder_y, 4.4), (0.14, 0.14, 8.8), "M_DarkSteel", 0.02)
box("BS_RoofLadderRail_R", (ladder_x + 0.55, ladder_y, 4.4), (0.14, 0.14, 8.8), "M_DarkSteel", 0.02)
for index in range(25):
    name = "BS_RoofLadderAnchor" if index == 0 else f"BS_RoofLadderRung_{index:02d}"
    box(name, (ladder_x, ladder_y, 0.35 + index * 0.34), (1.25, 0.16, 0.11), "M_RustedMetal", 0.015)
box("BS_RoofLanding", (5.7, -5.8, 8.55), (4.4, 3.2, 0.3), "M_Grate", 0.04)
box("BS_RoofWalk", (2.2, -3.5, 8.55), (3.0, 7.5, 0.3), "M_Grate", 0.04)
box("BS_RoofOverride", (2.2, -0.2, 9.55), (1.2, 0.8, 1.7), "N_Green", 0.03)

# Windows, facade rhythm, and a readable market/security silhouette.
for row, z_value in enumerate((5.0, 7.6)):
    for column, y_value in enumerate((-5.0, -2.0, 3.0, 6.0)):
        material = "N_WindowWarm" if (row + column) % 3 == 0 else "N_WindowCool"
        box(f"BS_Window_{row}_{column}", (-7.18, y_value, z_value), (0.18, 1.6, 1.2), material, 0.02)
for y_value in (-6.0, 0.0, 6.0):
    box(f"BS_FacadeRib_{y_value}", (-7.05, y_value, 6.0), (0.32, 0.3, 6.8), "M_RustedMetal", 0.03)
box("BS_SecurityBand", (-7.25, 0.0, 8.7), (0.18, 12.5, 0.18), "N_Magenta", 0.01)
box("BS_RoofAntenna", (5.1, 0.0, 17.0), (0.16, 0.16, 5.0), "M_DarkSteel", 0.02)

bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND))
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT_GLB),
    export_format="GLB",
    export_apply=True,
    use_selection=False,
)
print(f"Built {OUTPUT_BLEND}")
print(f"Exported {OUTPUT_GLB}")
