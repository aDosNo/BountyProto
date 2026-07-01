import math
from pathlib import Path

import bpy


ROOT = Path("/var/home/nick/bounty-hunt")
SOURCE_BLEND = ROOT / "assets/blender_models/Hesperus_Market2_Street.blend"
OUTPUT_BLEND = ROOT / "assets/blender_models/Hesperus_BountyEvidenceAnnex.blend"
OUTPUT_GLB = ROOT / "assets/blender_models/Hesperus_BountyEvidenceAnnex.glb"

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
    "M_Plastic",
]


def box(name, location, dimensions, material, bevel=0.06, rotation_z=0.0):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=(0.0, 0.0, rotation_z))
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


def cylinder(name, location, radius, depth, material):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(bpy.data.materials[material])
    return obj


def add_window_grid(prefix, x_face, y_values, z_values, warm_every=3):
    for row, z_value in enumerate(z_values):
        for column, y_value in enumerate(y_values):
            material = "N_WindowWarm" if (row + column) % warm_every == 0 else "N_WindowCool"
            box(
                f"{prefix}_Window_{row}_{column}",
                (x_face, y_value, z_value),
                (0.18, 1.7, 1.25),
                material,
                0.02,
            )
            box(
                f"{prefix}_Lintel_{row}_{column}",
                (x_face - 0.04, y_value, z_value + 0.78),
                (0.28, 2.05, 0.18),
                "M_RustedMetal",
                0.02,
            )


bpy.ops.wm.read_factory_settings(use_empty=True)
with bpy.data.libraries.load(str(SOURCE_BLEND), link=False) as (source, target):
    target.materials = [name for name in MATERIALS if name in source.materials]

# Footprint: 20m x 22m, replacing the oversized Building15 slab.
box("EA_Forecourt", (-7.4, 0.0, 0.08), (5.2, 12.0, 0.16), "M_Street", 0.03)
box("EA_ServiceApron", (2.5, -8.6, 0.08), (13.0, 4.2, 0.16), "M_Street", 0.03)
box("EA_PublicThreshold", (-9.5, 2.5, 0.14), (1.0, 5.5, 0.28), "M_Grate", 0.03)

# Low, believable annex massing: public records wing + evidence warehouse.
box("EA_RecordsWing_Mass", (-3.0, 3.2, 4.4), (7.5, 12.5, 8.8), "M_WorkConcrete", 0.12)
box("EA_ImpoundHall_Mass", (4.1, 1.0, 5.6), (7.8, 16.5, 11.2), "M_WorkConcrete", 0.12)
box("EA_RecordsWing_RoofCap", (-3.0, 3.2, 9.05), (8.0, 13.0, 0.5), "M_DarkSteel")
box("EA_ImpoundHall_RoofCap", (4.1, 1.0, 11.45), (8.3, 17.0, 0.55), "M_DarkSteel")

# Public records entry on the west face.
box("EA_PublicDoorFrame", (-6.9, 2.4, 2.3), (0.48, 4.1, 4.6), "M_RustedMetal")
box("EA_PublicDoor", (-7.18, 2.4, 2.05), (0.22, 2.7, 4.1), "M_DarkSteel", 0.03)
box("EA_PublicReader", (-7.42, 0.55, 1.5), (0.32, 0.8, 1.5), "N_Cyan", 0.02)
box("EA_PublicAwning", (-7.55, 2.4, 4.9), (2.2, 5.6, 0.3), "M_TarpRed")
box("EA_PublicSign", (-7.62, 4.8, 6.8), (0.22, 2.8, 1.0), "N_Orange", 0.02)

# Vault door is visible from the forecourt so all approaches converge clearly.
box("EA_EvidenceVaultFrame", (-6.95, -2.5, 2.45), (0.55, 4.4, 4.9), "M_RustedMetal")
box("EA_EvidenceVaultDoor", (-7.25, -2.5, 2.2), (0.28, 3.2, 4.4), "M_DarkSteel", 0.03)
box("EA_EvidenceVaultGlow", (-7.42, -2.5, 3.25), (0.12, 2.2, 0.18), "N_Magenta", 0.01)

# South service bypass, deliberately separate from the public entrance.
box("EA_ServiceBayFrame", (1.8, -7.45, 2.35), (5.4, 0.5, 4.7), "M_RustedMetal")
box("EA_ServiceBayDoor", (1.8, -7.72, 2.05), (4.3, 0.22, 4.1), "M_DarkSteel", 0.03)
box("EA_ServiceBreaker", (-1.1, -7.95, 1.45), (0.8, 0.38, 1.5), "N_Green", 0.02)
box("EA_ServicePipe", (5.9, -7.75, 3.7), (0.65, 0.65, 7.0), "M_RustedMetal")

# Exterior ladder and roof inspection route.
ladder_x = 7.4
ladder_y = -7.8
box("EA_RoofLadderRail_L", (ladder_x - 0.55, ladder_y, 4.4), (0.14, 0.14, 8.8), "M_DarkSteel", 0.02)
box("EA_RoofLadderRail_R", (ladder_x + 0.55, ladder_y, 4.4), (0.14, 0.14, 8.8), "M_DarkSteel", 0.02)
for index in range(25):
    rung_name = "EA_RoofLadderAnchor" if index == 0 else f"EA_RoofLadderRung_{index:02d}"
    box(rung_name, (ladder_x, ladder_y, 0.35 + index * 0.34), (1.25, 0.16, 0.11), "M_RustedMetal", 0.015)
box("EA_RoofLanding", (6.0, -6.8, 8.55), (4.0, 3.0, 0.3), "M_Grate", 0.04)
box("EA_RoofWalk", (3.3, -4.5, 8.55), (2.3, 7.0, 0.3), "M_Grate", 0.04)
box("EA_RoofOverride", (3.3, -1.4, 9.55), (1.2, 0.8, 1.7), "N_Green", 0.03)
for x_value in (4.1, 7.7):
    box(f"EA_RoofRailPost_{x_value}", (x_value, -7.9, 9.1), (0.14, 0.14, 1.3), "M_DarkSteel", 0.02)
box("EA_RoofOuterRail", (5.9, -7.9, 9.55), (4.0, 0.14, 0.16), "M_DarkSteel", 0.02)

# Roof equipment and readable silhouette.
box("EA_RoofArchiveUnit", (-3.0, 3.2, 10.15), (3.4, 3.0, 1.7), "M_DarkSteel")
cylinder("EA_RoofDishBase", (4.2, 3.0, 12.35), 0.9, 1.0, "M_RustedMetal")
box("EA_RoofAntenna", (4.2, 3.0, 14.4), (0.16, 0.16, 4.0), "M_DarkSteel", 0.02)

# Windows and facade rhythm, avoiding the entry openings.
add_window_grid("EA_RecordsWing", -6.82, [5.5, 3.0, -0.3], [6.3])
add_window_grid("EA_ImpoundHall", 8.08, [6.0, 2.5, -1.0, -4.5], [4.2, 7.3])

# Street-facing trim and security language.
for y_value in (-5.5, 0.0, 5.5):
    box(f"EA_FacadeRib_{y_value}", (-6.72, y_value, 5.5), (0.35, 0.3, 6.2), "M_RustedMetal", 0.03)
box("EA_SecurityBand", (-7.05, -0.2, 7.85), (0.2, 10.5, 0.18), "N_Magenta", 0.01)
box("EA_RecordsBand", (-7.08, 4.1, 5.9), (0.18, 3.0, 0.16), "N_Cyan", 0.01)

bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND))
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT_GLB),
    export_format="GLB",
    export_apply=True,
    use_selection=False,
)
print(f"Built {OUTPUT_BLEND}")
print(f"Exported {OUTPUT_GLB}")
