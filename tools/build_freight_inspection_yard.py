from pathlib import Path

import bpy


ROOT = Path("/var/home/nick/bounty-hunt")
SOURCE_BLEND = ROOT / "assets/blender_models/Hesperus_Market2_Street.blend"
OUTPUT_BLEND = ROOT / "assets/blender_models/Hesperus_FreightInspectionYard.blend"
OUTPUT_GLB = ROOT / "assets/blender_models/Hesperus_FreightInspectionYard.glb"

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

# 44m x 26m yard replacing Building21. West side stays open around the existing
# Freight Ramp; east side is framed by the retained Building22 industrial mass.
box("FY_YardSlab", (0.0, 0.0, 0.08), (44.0, 26.0, 0.16), "M_Street", 0.03)
box("FY_InspectionLane", (-3.0, 0.0, 0.16), (8.0, 25.0, 0.16), "M_Grate", 0.02)
box("FY_WestRampClearance", (-19.5, -7.0, 0.12), (5.0, 11.0, 0.12), "M_Street", 0.02)

# North gatehouse and dispatch office create a believable staffed edge.
box("FY_GatehouseMass", (-13.5, 7.5, 3.2), (8.5, 8.0, 6.4), "M_WorkConcrete", 0.12)
box("FY_GatehouseRoof", (-13.5, 7.5, 6.65), (9.0, 8.5, 0.5), "M_DarkSteel")
box("FY_ManifestWindow", (-13.5, 3.42, 3.6), (3.8, 0.18, 1.5), "N_WindowWarm", 0.02)
box("FY_ManifestReader", (-10.8, 3.25, 1.45), (0.8, 0.35, 1.5), "N_Cyan", 0.02)
box("FY_DispatchConsole", (-16.2, 3.25, 1.45), (0.8, 0.35, 1.5), "N_Magenta", 0.02)
box("FY_DispatchGlow", (-16.2, 3.04, 2.2), (0.65, 0.12, 0.16), "N_Magenta", 0.01)
box("FY_RouteStatusGlow", (-13.5, 3.02, 5.3), (4.5, 0.12, 0.2), "N_Orange", 0.01)

# Scanner gantry makes the systemic route readable from the central lane.
for x_value in (-7.0, 1.0):
    box(f"FY_ScannerPylon_{x_value}", (x_value, -1.0, 3.3), (0.65, 0.8, 6.6), "M_RustedMetal")
box("FY_ScannerHeader", (-3.0, -1.0, 6.6), (9.0, 0.9, 0.7), "M_DarkSteel")
box("FY_ScannerArm_A", (-6.0, -1.0, 3.8), (2.2, 0.5, 0.35), "N_Magenta", 0.02)
box("FY_ScannerArm_B", (0.0, -1.0, 3.8), (2.2, 0.5, 0.35), "N_Magenta", 0.02)
box("FY_ScannerBypass", (1.65, -1.0, 1.45), (0.4, 0.8, 1.5), "N_Green", 0.02)

# Outbound gate fronts the return-route side of the yard.
box("FY_OutboundGate_L", (-5.2, -12.0, 2.2), (4.8, 0.3, 4.4), "M_DarkSteel", 0.03)
box("FY_OutboundGate_R", (-0.8, -12.0, 2.2), (4.0, 0.3, 4.4), "M_DarkSteel", 0.03)
box("FY_GateHeader", (-3.0, -12.0, 5.3), (10.0, 0.6, 0.8), "M_RustedMetal")

# Container lanes form cover without sealing the force path.
container_data = [
    ("A", 7.0, 7.5, 0.0, "M_TarpRed"),
    ("B", 15.0, 7.5, 0.0, "M_DarkSteel"),
    ("C", 10.0, 0.0, 0.0, "M_RustedMetal"),
    ("D", 17.0, -3.0, 0.0, "M_TarpRed"),
    ("E", 10.0, -9.0, 0.0, "M_DarkSteel"),
]
for suffix, x_value, y_value, z_value, material in container_data:
    box(f"FY_Container_{suffix}", (x_value, y_value, 1.35 + z_value), (6.0, 2.6, 2.7), material, 0.08)
    for rib in (-2.4, 0.0, 2.4):
        box(f"FY_Container_{suffix}_Rib_{rib}", (x_value + rib, y_value - 1.32, 1.35), (0.12, 0.12, 2.5), "M_RustedMetal", 0.01)

# Inspection tower and exposed roof route.
box("FY_TowerMass", (19.0, 8.2, 5.3), (5.0, 5.0, 10.6), "M_WorkConcrete", 0.1)
box("FY_TowerCab", (19.0, 8.2, 10.5), (6.0, 6.0, 3.2), "M_DarkSteel", 0.08)
box("FY_TowerWindow", (15.92, 8.2, 10.5), (0.18, 3.8, 1.7), "N_WindowCool", 0.02)
box("FY_TowerOverride", (15.75, 6.0, 9.3), (0.35, 0.8, 1.5), "N_Green", 0.02)
ladder_x = 16.2
ladder_y = 10.9
box("FY_TowerLadderRail_L", (ladder_x - 0.55, ladder_y, 4.4), (0.14, 0.14, 8.8), "M_DarkSteel", 0.02)
box("FY_TowerLadderRail_R", (ladder_x + 0.55, ladder_y, 4.4), (0.14, 0.14, 8.8), "M_DarkSteel", 0.02)
for index in range(25):
    name = "FY_TowerLadderAnchor" if index == 0 else f"FY_TowerLadderRung_{index:02d}"
    box(name, (ladder_x, ladder_y, 0.35 + index * 0.34), (1.25, 0.16, 0.11), "M_RustedMetal", 0.015)
box("FY_TowerLanding", (17.5, 9.5, 8.6), (4.5, 3.2, 0.3), "M_Grate", 0.04)

# Crane frame and suspended extraction cover.
for x_value in (5.0, 18.0):
    box(f"FY_CraneLeg_{x_value}", (x_value, -8.5, 6.0), (0.7, 0.7, 12.0), "M_RustedMetal")
box("FY_CraneBeam", (11.5, -8.5, 12.0), (14.0, 0.8, 0.8), "M_DarkSteel")
box("FY_CraneTrolley", (11.5, -8.5, 11.2), (1.5, 1.4, 0.8), "M_RustedMetal")
box("FY_CraneCable", (11.5, -8.5, 8.6), (0.12, 0.12, 4.8), "M_DarkSteel", 0.01)
box("FY_SuspendedCoverContainer", (11.5, -8.5, 6.0), (6.0, 2.6, 2.7), "M_TarpRed", 0.08)

# Guard anchors are visible scene markers and collision-excluded in Godot.
box("FY_InspectorPost", (-5.0, 4.8, 0.15), (0.4, 0.4, 0.3), "N_Orange", 0.01)
box("FY_ExtractionGuardPost", (5.0, -5.0, 0.15), (0.4, 0.4, 0.3), "N_Magenta", 0.01)

# Perimeter definition, leaving west ramp and north/south circulation open.
box("FY_EastFence", (22.0, 0.0, 1.4), (0.25, 25.0, 2.8), "M_RustedMetal", 0.02)
for y_value in (-11.5, 11.5):
    box(f"FY_EastFencePost_{y_value}", (22.0, y_value, 2.6), (0.5, 0.5, 5.2), "M_DarkSteel", 0.02)

bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND))
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT_GLB),
    export_format="GLB",
    export_apply=True,
    use_selection=False,
)
print(f"Built {OUTPUT_BLEND}")
print(f"Exported {OUTPUT_GLB}")
