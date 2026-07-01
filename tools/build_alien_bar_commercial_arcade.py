from pathlib import Path

import bpy


ROOT = Path("/var/home/nick/bounty-hunt")
SOURCE_BLEND = ROOT / "assets/blender_models/Hesperus_Market2_Street.blend"
OUTPUT_BLEND = ROOT / "assets/blender_models/Hesperus_AlienBar_CommercialArcade.blend"
OUTPUT_GLB = ROOT / "assets/blender_models/Hesperus_AlienBar_CommercialArcade.glb"

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


def stair_run(prefix, start, steps, step_size, rise, material):
    x, y, z = start
    for index in range(steps):
        box(
            f"{prefix}_Step_{index:02d}",
            (x, y + index * step_size, z + index * rise),
            (2.4, step_size, rise),
            material,
            0.02,
        )


bpy.ops.wm.read_factory_settings(use_empty=True)
with bpy.data.libraries.load(str(SOURCE_BLEND), link=False) as (source, target):
    target.materials = [name for name in MATERIALS if name in source.materials]

# Local coordinates deliberately match the existing AlienBar alley export.
# Road/sidewalk ends at y=38.1. Arcade front begins at y=38.25 and extends
# northward, so no street, courier pocket, or upper service catwalk is covered.
box("ABA_BlockFloor", (69.0, 45.5, 0.08), (30.0, 14.5, 0.16), "M_Street", 0.03)
box("ABA_RearServiceWalk", (69.0, 52.2, 0.14), (30.0, 1.1, 0.28), "M_Grate", 0.03)

# Shared structural frame: three ground-floor bays beneath one motel/workshop
# level. Open front-wall gaps are intentional entrances, not painted doors.
for x_value in (54.0, 63.5, 73.5, 84.0):
    box(f"ABA_FramePier_{x_value}", (x_value, 45.5, 4.6), (0.45, 14.2, 9.2), "M_RustedMetal", 0.04)
box("ABA_UpperFloor", (69.0, 45.5, 5.0), (30.0, 14.2, 0.35), "M_Grate", 0.04)
box("ABA_UpperRoof", (69.0, 45.5, 10.5), (30.8, 14.8, 0.55), "M_DarkSteel")
box("ABA_RearWall", (69.0, 52.45, 5.25), (30.0, 0.35, 10.5), "M_WorkConcrete", 0.06)

# ALIEN BAR vestibule / package origin. Package sits just outside this opening.
box("ABA_Bar_LeftWall", (54.2, 45.5, 2.5), (0.35, 14.0, 5.0), "M_WorkConcrete")
box("ABA_Bar_RightWall", (63.3, 45.5, 2.5), (0.35, 14.0, 5.0), "M_WorkConcrete")
box("ABA_Bar_FrontLeft", (56.3, 38.42, 2.5), (4.2, 0.35, 5.0), "M_WorkConcrete")
box("ABA_Bar_FrontRight", (62.0, 38.42, 2.5), (2.6, 0.35, 5.0), "M_WorkConcrete")
box("ABA_Bar_EntranceHeader", (59.25, 38.42, 4.65), (2.0, 0.45, 0.7), "M_RustedMetal")
box("ABA_Bar_RecessFloor", (59.25, 39.6, 0.14), (2.2, 2.7, 0.28), "M_Grate")
box("ABA_Bar_BackCounter", (58.8, 48.8, 1.05), (5.8, 1.0, 2.1), "M_RustedMetal")
box("ABA_BarSign", (59.25, 38.18, 7.2), (4.4, 0.18, 1.2), "N_Magenta", 0.02)
box("ABA_BarAwning", (59.25, 37.5, 4.1), (7.8, 2.0, 0.3), "M_TarpRed")

# Pawn/intel shop: genuinely enterable shell with a clear front door and
# internal counter. Gameplay objects can be added later without rebaking.
box("ABA_Pawn_LeftWall", (63.7, 45.5, 2.5), (0.35, 14.0, 5.0), "M_WorkConcrete")
box("ABA_Pawn_RightWall", (73.3, 45.5, 2.5), (0.35, 14.0, 5.0), "M_WorkConcrete")
box("ABA_Pawn_FrontLeft", (65.8, 38.42, 2.5), (4.0, 0.35, 5.0), "M_WorkConcrete")
box("ABA_Pawn_FrontRight", (71.8, 38.42, 2.5), (3.0, 0.35, 5.0), "M_WorkConcrete")
box("ABA_Pawn_EntranceHeader", (68.8, 38.42, 4.65), (2.0, 0.45, 0.7), "M_RustedMetal")
box("ABA_PawnCounter", (68.5, 49.0, 1.05), (6.0, 1.0, 2.1), "M_RustedMetal")
box("ABA_PawnDisplay_A", (65.2, 45.0, 1.2), (1.0, 3.5, 2.4), "M_DarkSteel")
box("ABA_PawnDisplay_B", (72.0, 45.0, 1.2), (1.0, 3.5, 2.4), "M_DarkSteel")
box("ABA_PawnSign", (68.6, 38.18, 7.0), (4.2, 0.18, 1.0), "N_Orange", 0.02)
box("ABA_PawnAwning", (68.6, 37.5, 4.1), (8.0, 2.0, 0.3), "M_TarpGreen")

# Implant clinic / courier office bay. The street courier remains outside and
# unobstructed; this room gives that service pocket a believable tenant.
box("ABA_Clinic_LeftWall", (73.7, 45.5, 2.5), (0.35, 14.0, 5.0), "M_WorkConcrete")
box("ABA_Clinic_RightWall", (83.8, 45.5, 2.5), (0.35, 14.0, 5.0), "M_WorkConcrete")
box("ABA_Clinic_FrontLeft", (76.0, 38.42, 2.5), (4.2, 0.35, 5.0), "M_WorkConcrete")
box("ABA_Clinic_FrontRight", (82.4, 38.42, 2.5), (2.8, 0.35, 5.0), "M_WorkConcrete")
box("ABA_Clinic_EntranceHeader", (79.2, 38.42, 4.65), (2.2, 0.45, 0.7), "M_RustedMetal")
box("ABA_ClinicPartition", (78.3, 47.0, 2.5), (0.3, 8.0, 5.0), "M_DarkSteel")
box("ABA_ClinicDesk", (80.7, 48.8, 1.05), (4.0, 1.0, 2.1), "M_RustedMetal")
box("ABA_ClinicSign", (79.2, 38.18, 7.0), (4.5, 0.18, 1.0), "N_Cyan", 0.02)
box("ABA_ClinicAwning", (79.1, 37.5, 4.1), (8.2, 2.0, 0.3), "M_TarpRed")

# Second-floor motel/workshop corridor overlooking the street. Front rooms use
# shallow interior depth and lit windows; one east room is fully reachable.
box("ABA_UpperRearCorridor", (69.0, 50.8, 7.55), (29.0, 2.4, 0.3), "M_Grate")
box("ABA_UpperBalcony", (69.0, 37.2, 5.15), (29.0, 1.8, 0.3), "M_Grate")
box("ABA_UpperBalconyRail", (69.0, 36.38, 5.85), (29.0, 0.12, 1.4), "M_RustedMetal", 0.02)

for room_index, x_center in enumerate((57.8, 64.0, 70.2, 76.4)):
    box(f"ABA_UpperRoom_{room_index}_Rear", (x_center, 49.7, 7.75), (5.7, 0.3, 5.0), "M_WorkConcrete")
    box(f"ABA_UpperRoom_{room_index}_Left", (x_center - 2.85, 46.0, 7.75), (0.3, 7.4, 5.0), "M_WorkConcrete")
    box(f"ABA_UpperRoom_{room_index}_Front", (x_center, 38.55, 7.75), (5.7, 0.3, 5.0), "M_WorkConcrete")
    window_material = "N_WindowWarm" if room_index % 2 == 0 else "N_WindowCool"
    box(f"ABA_UpperRoom_{room_index}_Window", (x_center, 38.35, 8.0), (2.2, 0.12, 1.5), window_material, 0.02)

# East upper room is a full accessible motel/back-office interior.
box("ABA_UpperOffice_RightWall", (83.8, 46.0, 7.75), (0.3, 7.4, 5.0), "M_WorkConcrete")
box("ABA_UpperOffice_BackWall", (80.8, 49.7, 7.75), (6.0, 0.3, 5.0), "M_WorkConcrete")
box("ABA_UpperOffice_FrontLeft", (79.4, 38.55, 7.75), (3.2, 0.3, 5.0), "M_WorkConcrete")
box("ABA_UpperOffice_FrontRight", (83.0, 38.55, 7.75), (1.6, 0.3, 5.0), "M_WorkConcrete")
box("ABA_UpperOfficeDoorHeader", (81.3, 38.55, 9.85), (1.8, 0.4, 0.8), "M_RustedMetal")
box("ABA_UpperOfficeDesk", (81.0, 47.7, 5.85), (3.2, 1.0, 1.4), "M_RustedMetal")

# Internal stairwell in the clinic bay avoids consuming sidewalk or courier
# space. It climbs from the rear of the ground floor to the upper corridor.
stair_run("ABA_InternalStair", (81.8, 45.0, 0.22), 12, 0.42, 0.4, "M_Grate")
box("ABA_StairLanding", (81.8, 50.1, 5.0), (2.8, 2.0, 0.3), "M_Grate")
box("ABA_StairRail", (83.05, 47.4, 2.8), (0.12, 5.8, 5.4), "M_RustedMetal", 0.02)

# Roof rhythm and signage keep the arcade from reading as one featureless slab.
for x_center, height in ((58.0, 12.2), (68.5, 13.8), (79.0, 12.8)):
    box(f"ABA_RoofMass_{x_center}", (x_center, 46.5, height - 1.0), (6.5, 5.0, 2.0), "M_DarkSteel")
box("ABA_RoofSignFrame", (58.5, 40.0, 12.2), (0.3, 4.0, 3.2), "M_RustedMetal")
box("ABA_RoofSignGlow", (58.3, 40.0, 12.2), (0.12, 3.2, 2.4), "N_Magenta", 0.01)

bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND))
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT_GLB),
    export_format="GLB",
    export_apply=True,
    use_selection=False,
)
print(f"Built {OUTPUT_BLEND}")
print(f"Exported {OUTPUT_GLB}")
