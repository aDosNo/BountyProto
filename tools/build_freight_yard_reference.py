from pathlib import Path
import math

import bpy


ROOT = Path("/var/home/nick/bounty-hunt")
SOURCE_BLEND = ROOT / "assets/blender_models/Hesperus_Market2_Street.blend"
OUTPUT_BLEND = ROOT / "assets/blender_models/Hesperus_FreightYard_ExtractionPrep.blend"
OUTPUT_GLB = ROOT / "assets/blender_models/Hesperus_FreightYard_ExtractionPrep.glb"

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


def ensure_material(name: str, color: tuple[float, float, float, float], emission: bool = False):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        if emission:
            bsdf.inputs["Emission Color"].default_value = color
            bsdf.inputs["Emission Strength"].default_value = 2.5
    return mat


def mat(name: str):
    return bpy.data.materials[name]


def box(name, location, dimensions, material, bevel=0.04, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        modifier = obj.modifiers.new("EdgeSoftening", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    obj.data.materials.append(mat(material))
    return obj


def cylinder(name, location, radius, depth, material, vertices=16, rotation=(0.0, 0.0, 0.0), bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat(material))
    if bevel > 0.0:
        modifier = obj.modifiers.new("EdgeSoftening", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
    return obj


def sign(name, location, text, width, material="N_Orange", rotation=(math.radians(90), 0.0, 0.0)):
    panel = box(f"{name}_Panel", location, (width, 0.12, 0.45), "M_DarkSteel", 0.02)
    bpy.ops.object.text_add(location=(location[0], location[1] - 0.08, location[2] + 0.03), rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.body = text
    obj.data.align_x = "CENTER"
    obj.data.align_y = "CENTER"
    obj.data.size = 0.28
    obj.data.extrude = 0.01
    obj.data.materials.append(mat(material))
    return panel, obj


def container(name, location, rotation_z=0.0, material="M_DarkSteel"):
    box(name, location, (7.2, 2.7, 2.8), material, 0.07, (0.0, 0.0, rotation_z))
    for x in (-3.0, -1.5, 0.0, 1.5, 3.0):
        box(f"{name}_Rib_{x}", (location[0] + math.cos(rotation_z) * x, location[1] + math.sin(rotation_z) * x, location[2]), (0.12, 2.85, 2.65), "M_RustedMetal", 0.01, (0.0, 0.0, rotation_z))
    box(f"{name}_DoorStripe", (location[0], location[1] - 1.42, location[2] + 0.3), (6.2, 0.08, 0.16), "N_Cyan", 0.005, (0.0, 0.0, rotation_z))


def route_strip(name, start, end, material):
    mid = ((start[0] + end[0]) * 0.5, (start[1] + end[1]) * 0.5, 0.19)
    dx = end[0] - start[0]
    dy = end[1] - start[1]
    length = math.sqrt(dx * dx + dy * dy)
    angle = math.atan2(dy, dx)
    box(name, mid, (length, 0.22, 0.035), material, 0.005, (0.0, 0.0, angle))
    # Small arrow ticks, matching the reference-board route language without
    # adding gameplay collision.
    ticks = max(2, int(length // 4))
    for index in range(ticks):
        t = (index + 1) / (ticks + 1)
        x = start[0] + dx * t
        y = start[1] + dy * t
        box(f"{name}_Tick_{index:02d}", (x, y, 0.23), (0.55, 0.08, 0.04), material, 0.004, (0.0, 0.0, angle + math.radians(35)))


bpy.ops.wm.read_factory_settings(use_empty=True)
with bpy.data.libraries.load(str(SOURCE_BLEND), link=False) as (source, target):
    target.materials = [name for name in MATERIALS if name in source.materials]

ensure_material("N_RouteSocial", (0.18, 1.0, 0.18, 1.0), True)
ensure_material("N_RouteUtility", (0.05, 0.7, 1.0, 1.0), True)
ensure_material("N_RouteVertical", (0.65, 0.24, 1.0, 1.0), True)

# Larger, closer-to-reference yard: left gatehouse/manifest, central scanner +
# dispatch, rear inspection tower, right crane and suspended cover container.
box("FY2_YardSlab", (0.0, 0.0, 0.08), (62.0, 34.0, 0.16), "M_Street", 0.025)
box("FY2_WetConcretePlate_A", (-9.0, -1.0, 0.17), (18.0, 10.0, 0.035), "M_WorkConcrete", 0.01)
box("FY2_WetConcretePlate_B", (13.0, -4.0, 0.17), (18.0, 12.0, 0.035), "M_WorkConcrete", 0.01)
for x in range(-28, 29, 7):
    box(f"FY2_LaneStripe_{x}", (x, -14.0, 0.22), (3.8, 0.18, 0.04), "N_Orange", 0.005)
for y in (-16.6, 16.6):
    box(f"FY2_PerimeterRail_{y}", (0.0, y, 1.25), (61.5, 0.2, 2.1), "M_RustedMetal", 0.02)

# Gatehouse block on the southwest / left edge.
box("FY_GatehouseMass", (-24.0, -10.8, 2.6), (8.6, 6.0, 5.2), "M_WorkConcrete", 0.1)
box("FY_GatehouseRoof", (-24.0, -10.8, 5.45), (9.2, 6.6, 0.55), "M_DarkSteel", 0.05)
box("FY_GatehouseAwning", (-24.0, -14.05, 3.05), (9.4, 0.7, 0.35), "M_RustedMetal", 0.025)
box("FY_GatehouseWindow", (-26.2, -13.88, 2.7), (2.6, 0.12, 1.3), "N_WindowWarm", 0.01)
sign("FY2_GatehouseSign", (-24.0, -14.18, 4.0), "FREIGHT ACCESS", 5.2, "N_Green")

# Manifest station, deliberately forward-left like the reference.
box("FY_ManifestStationMass", (-14.5, -6.8, 2.2), (7.0, 5.2, 4.4), "M_WorkConcrete", 0.08)
box("FY_ManifestStationRoof", (-14.5, -6.8, 4.65), (7.7, 5.8, 0.5), "M_DarkSteel", 0.04)
box("FY_ManifestWindow", (-14.5, -9.5, 2.65), (4.4, 0.14, 1.45), "N_WindowWarm", 0.01)
box("FY_ManifestReader", (-12.0, -9.65, 1.35), (0.75, 0.3, 1.35), "N_Cyan", 0.01)
sign("FY2_ManifestSign", (-14.5, -9.76, 3.95), "MANIFEST", 4.4, "N_Magenta")

# Scanner gantry dominates the central-left lane.
for x in (-10.0, 3.0):
    box(f"FY_ScannerPylon_{x}", (x, -1.8, 4.2), (0.75, 0.9, 8.4), "M_RustedMetal", 0.04)
    box(f"FY_ScannerLightStack_{x}", (x, -1.8, 8.8), (0.9, 1.0, 0.4), "N_Orange", 0.01)
box("FY_ScannerHeader", (-3.5, -1.8, 8.45), (14.4, 1.1, 0.8), "M_DarkSteel", 0.04)
box("FY_ScannerHeaderGlow", (-3.5, -2.42, 7.9), (12.0, 0.12, 0.16), "N_Orange", 0.005)
box("FY_ScannerArm_A", (-8.2, -1.8, 4.35), (2.5, 0.5, 0.35), "N_Magenta", 0.01)
box("FY_ScannerArm_B", (1.6, -1.8, 4.35), (2.5, 0.5, 0.35), "N_Magenta", 0.01)
box("FY_ScannerBypass", (4.4, -2.55, 1.35), (0.55, 0.35, 1.55), "N_Green", 0.01)
sign("FY2_ScannerSign", (-3.5, -2.58, 6.95), "SCANNER GANTRY", 5.6)

# Dispatch console in the central open lane.
box("FY_DispatchKiosk", (-3.0, 3.4, 2.0), (5.6, 3.0, 4.0), "M_WorkConcrete", 0.08)
box("FY_DispatchConsole", (-3.0, 1.78, 1.35), (1.7, 0.32, 1.35), "N_Cyan", 0.01)
box("FY_DispatchGlow", (-3.0, 1.58, 2.35), (1.4, 0.1, 0.16), "N_Magenta", 0.005)
box("FY_RouteStatusGlow", (-3.0, 1.54, 3.6), (3.5, 0.1, 0.18), "N_Orange", 0.005)
sign("FY2_DispatchSign", (-3.0, 1.43, 4.35), "DISPATCH", 3.4, "N_Cyan")

# Inspection tower rear-center, taller than the rest of the yard.
box("FY_TowerBase", (8.5, 10.0, 4.0), (6.0, 5.8, 8.0), "M_WorkConcrete", 0.08)
box("FY_TowerCab", (8.5, 10.0, 10.7), (7.2, 6.4, 4.0), "M_DarkSteel", 0.08)
box("FY_TowerWindowFront", (8.5, 6.72, 10.9), (4.6, 0.14, 1.7), "N_WindowCool", 0.01)
box("FY_TowerWindowSide", (4.82, 10.0, 10.9), (0.14, 3.6, 1.7), "N_WindowCool", 0.01)
box("FY_TowerAntennaRack", (8.5, 10.0, 14.3), (5.2, 0.6, 1.0), "M_RustedMetal", 0.03)
for index, x in enumerate((6.6, 8.5, 10.4)):
    cylinder(f"FY_TowerAntenna_{index}", (x, 10.0, 16.0), 0.045, 3.2, "M_DarkSteel", 8)
box("FY_TowerOverride", (4.65, 8.0, 9.2), (0.32, 0.8, 1.45), "N_Green", 0.01)
box("FY_TowerLanding", (5.8, 12.8, 8.4), (4.2, 2.5, 0.28), "M_Grate", 0.03)
ladder_x = 5.4
ladder_y = 13.95
box("FY_TowerLadderRail_L", (ladder_x - 0.5, ladder_y, 4.2), (0.12, 0.12, 8.4), "M_DarkSteel", 0.01)
box("FY_TowerLadderRail_R", (ladder_x + 0.5, ladder_y, 4.2), (0.12, 0.12, 8.4), "M_DarkSteel", 0.01)
for index in range(25):
    name = "FY_TowerLadderAnchor" if index == 0 else f"FY_TowerLadderRung_{index:02d}"
    box(name, (ladder_x, ladder_y, 0.35 + index * 0.33), (1.2, 0.14, 0.1), "M_RustedMetal", 0.006)
sign("FY2_TowerSign", (8.5, 6.55, 13.2), "INSPECTION TOWER", 5.2)

# Crane and suspended container at the right side.
for x in (17.5, 29.0):
    box(f"FY_CraneLeg_{x}", (x, 3.8, 6.0), (0.8, 0.8, 12.0), "M_RustedMetal", 0.035)
box("FY_CraneBeam", (23.3, 3.8, 12.2), (14.2, 0.8, 0.8), "M_DarkSteel", 0.035)
box("FY_CraneJib", (26.8, 5.8, 13.0), (15.5, 0.5, 0.5), "M_RustedMetal", 0.025, (0.0, 0.0, math.radians(18)))
box("FY_CraneTrolley", (22.8, 3.8, 11.3), (1.6, 1.3, 0.8), "M_RustedMetal", 0.02)
box("FY_CraneCable", (22.8, 3.8, 8.4), (0.1, 0.1, 5.2), "M_DarkSteel", 0.003)
box("FY_SuspendedCoverContainer", (22.8, 3.8, 5.55), (7.2, 2.7, 2.8), "M_TarpRed", 0.07)
sign("FY2_CraneSign", (23.0, 1.95, 8.2), "CRANE + COVER", 4.2)

# Outbound route gates on the far east/right edge.
box("FY_OutboundGate_L", (30.4, -7.8, 2.25), (0.35, 5.2, 4.5), "M_DarkSteel", 0.025)
box("FY_OutboundGate_R", (30.4, -2.9, 2.25), (0.35, 4.6, 4.5), "M_DarkSteel", 0.025)
box("FY_GateHeader", (30.4, -5.4, 5.15), (0.6, 10.5, 0.75), "M_RustedMetal", 0.025)
sign("FY2_ExitSign", (30.1, -5.4, 5.9), "EXTRACTION OUT", 4.8, "N_Orange", (math.radians(90), 0.0, math.radians(90)))

# Cover containers preserve the force lane while creating real corners.
container("FY_Container_A", (10.0, -8.6, 1.55), 0.0, "M_DarkSteel")
container("FY_Container_B", (19.0, -9.4, 1.55), math.radians(4), "M_TarpRed")
container("FY_Container_C", (15.5, -1.4, 1.55), math.radians(-8), "M_RustedMetal")
container("FY_Container_D", (25.0, -13.0, 1.55), 0.0, "M_DarkSteel")
container("FY_Container_E", (-24.0, 5.0, 1.55), math.radians(90), "M_RustedMetal")
for i, (x, y) in enumerate([(-20, -2), (-18, 3), (-7, -10), (2, -8), (6, 5), (13, 4)]):
    box(f"FY2_CrateStack_{i}", (x, y, 0.75), (1.8, 1.4, 1.5), "M_RustedMetal", 0.05)

# Route language copied from the reference: social green, utility blue, vertical purple.
route_strip("FY2_SocialRoute_A", (-27.5, -13.0), (-14.0, -9.7), "N_RouteSocial")
route_strip("FY2_SocialRoute_B", (-14.0, -9.7), (-3.0, 1.9), "N_RouteSocial")
route_strip("FY2_UtilityRoute_A", (-22.0, -5.0), (4.4, -2.6), "N_RouteUtility")
route_strip("FY2_UtilityRoute_B", (4.4, -2.6), (-3.0, 1.9), "N_RouteUtility")
route_strip("FY2_VerticalRoute_A", (-27.5, -13.0), (5.4, 14.0), "N_RouteVertical")
route_strip("FY2_VerticalRoute_B", (5.4, 14.0), (-3.0, 1.9), "N_RouteVertical")
route_strip("FY2_ExtractionRoute", (-3.0, 1.9), (30.0, -5.4), "N_Orange")

# Guard/extraction anchors match the existing activity script.
box("FY_InspectorPost", (-4.5, -0.8, 0.22), (0.45, 0.45, 0.32), "N_Orange", 0.006)
box("FY_ExtractionGuardPost", (15.0, -5.5, 0.22), (0.45, 0.45, 0.32), "N_Magenta", 0.006)

# Small practical lamps, signs, and skyline-facing silhouettes.
for i, (x, y) in enumerate([(-27, 12), (-8, 13), (14, 14), (28, 12), (-27, -15), (3, -15), (26, -15)]):
    box(f"FY2_LampPost_{i}", (x, y, 2.6), (0.16, 0.16, 5.2), "M_DarkSteel", 0.01)
    box(f"FY2_LampHead_{i}", (x, y, 5.35), (0.7, 0.35, 0.24), "N_WindowWarm", 0.006)
for i, x in enumerate([-22, -18, -10, -2, 8, 18, 26]):
    box(f"FY2_DistantIndustrialStack_{i}", (x, 18.8, 5.0 + (i % 3)), (1.3, 1.0, 10.0 + (i % 3) * 2.0), "M_DarkSteel", 0.04)
    box(f"FY2_DistantWindowStrip_{i}", (x, 18.22, 7.5 + (i % 3)), (0.9, 0.1, 0.18), "N_WindowCool", 0.004)

bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND))
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT_GLB),
    export_format="GLB",
    export_apply=True,
    use_selection=False,
)
print(f"Built {OUTPUT_BLEND}")
print(f"Exported {OUTPUT_GLB}")
