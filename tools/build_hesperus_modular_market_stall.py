from pathlib import Path
import math

import bpy
from mathutils import Vector


ROOT = Path("/var/home/nick/bounty-hunt")
OUTPUT_BLEND = ROOT / "assets/blender_models/hesperus_modular_market_stall.blend"
OUTPUT_GLB = ROOT / "assets/blender_models/hesperus_modular_market_stall.glb"

COLLECTIONS = (
    "HMS_FRAME",
    "HMS_CANOPY",
    "HMS_COUNTER",
    "HMS_LIGHTS",
    "HMS_SIGNAGE",
    "HMS_PROPS",
    "HMS_COLLISION",
)

MATERIALS = {
    "mat_hms_dark_frame": ((0.045, 0.06, 0.065, 1.0), 0.72, 0.05),
    "mat_hms_teal_panel": ((0.018, 0.105, 0.115, 1.0), 0.68, 0.02),
    "mat_hms_teal_trim": ((0.025, 0.19, 0.20, 1.0), 0.58, 0.03),
    "mat_hms_orange_canopy": ((0.43, 0.075, 0.012, 1.0), 0.66, 0.02),
    "mat_hms_orange_edge": ((0.70, 0.18, 0.018, 1.0), 0.55, 0.05),
    "mat_hms_yellow_joint": ((0.76, 0.30, 0.025, 1.0), 0.55, 0.08),
    "mat_hms_purple_banner": ((0.20, 0.055, 0.40, 1.0), 0.72, 0.01),
    "mat_hms_amber_light": ((1.0, 0.45, 0.06, 1.0), 0.35, 0.1),
    "mat_hms_blue_crate": ((0.025, 0.17, 0.34, 1.0), 0.64, 0.03),
    "mat_hms_olive_crate": ((0.20, 0.20, 0.09, 1.0), 0.72, 0.01),
    "mat_hms_cream_mark": ((0.9, 0.82, 0.65, 1.0), 0.75, 0.0),
    "mat_hms_collision": ((0.1, 0.8, 0.25, 0.16), 1.0, 0.0),
}


def build() -> None:
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for collection in list(bpy.data.collections):
        if collection.name != "Collection":
            bpy.data.collections.remove(collection)

    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0

    collections = {}
    for name in COLLECTIONS:
        collection = bpy.data.collections.new(name)
        scene.collection.children.link(collection)
        collections[name] = collection

    materials = {}
    for name, (color, roughness, metallic) in MATERIALS.items():
        material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        material.diffuse_color = color
        material.use_nodes = True
        bsdf = material.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
        if name == "mat_hms_amber_light":
            bsdf.inputs["Emission Color"].default_value = (1.0, 0.16, 0.01, 1.0)
            bsdf.inputs["Emission Strength"].default_value = 4.0
        if name == "mat_hms_collision":
            bsdf.inputs["Alpha"].default_value = 0.16
            material.surface_render_method = "DITHERED"
        materials[name] = material

    def move_to(obj: bpy.types.Object, collection_name: str) -> None:
        for collection in list(obj.users_collection):
            collection.objects.unlink(obj)
        collections[collection_name].objects.link(obj)

    def box(
        name: str,
        location,
        dimensions,
        material_name: str,
        collection_name: str,
        bevel_width: float = 0.0,
        rotation=(0.0, 0.0, 0.0),
    ):
        bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
        obj = bpy.context.object
        obj.name = name
        obj.dimensions = dimensions
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        obj.data.materials.append(materials[material_name])
        move_to(obj, collection_name)
        if bevel_width > 0.0:
            modifier = obj.modifiers.new(f"{name}_bevel", "BEVEL")
            modifier.width = bevel_width
            modifier.segments = 1
        return obj

    def cylinder(
        name: str,
        location,
        radius: float,
        depth: float,
        material_name: str,
        collection_name: str,
        vertices: int = 8,
    ):
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=vertices,
            radius=radius,
            depth=depth,
            location=location,
        )
        obj = bpy.context.object
        obj.name = name
        obj.data.materials.append(materials[material_name])
        move_to(obj, collection_name)
        return obj

    def beam_between(
        name: str,
        start,
        end,
        thickness: float,
        material_name: str,
        collection_name: str,
    ):
        start_v = Vector(start)
        end_v = Vector(end)
        vector = end_v - start_v
        midpoint = (start_v + end_v) * 0.5
        obj = box(
            name,
            midpoint,
            (thickness, thickness, vector.length),
            material_name,
            collection_name,
            thickness * 0.12,
        )
        obj.rotation_mode = "QUATERNION"
        obj.rotation_quaternion = vector.to_track_quat("Z", "Y")
        return obj

    # ------------------------------------------------------------------
    # Structural frame and 0.5m-grid footings.
    # ------------------------------------------------------------------
    box(
        "HMS_frame_base_plinth",
        (0.0, 0.0, 0.07),
        (5.2, 2.15, 0.14),
        "mat_hms_dark_frame",
        "HMS_FRAME",
        0.035,
    )
    post_positions = (
        ("front_left", -2.3, -0.82),
        ("front_right", 2.3, -0.82),
        ("rear_left", -2.3, 0.82),
        ("rear_right", 2.3, 0.82),
    )
    for label, x_value, y_value in post_positions:
        box(
            f"HMS_frame_foot_{label}",
            (x_value, y_value, 0.18),
            (0.52, 0.52, 0.34),
            "mat_hms_dark_frame",
            "HMS_FRAME",
            0.055,
        )
        box(
            f"HMS_frame_foot_orange_{label}",
            (x_value, y_value - 0.18, 0.20),
            (0.34, 0.12, 0.20),
            "mat_hms_yellow_joint",
            "HMS_FRAME",
            0.025,
        )
        box(
            f"HMS_frame_post_{label}",
            (x_value, y_value, 1.58),
            (0.22, 0.22, 2.55),
            "mat_hms_dark_frame",
            "HMS_FRAME",
            0.025,
        )
        for z_value in (0.55, 1.55, 2.65):
            box(
                f"HMS_frame_post_collar_{label}_{z_value:.2f}",
                (x_value, y_value, z_value),
                (0.34, 0.34, 0.22),
                "mat_hms_dark_frame",
                "HMS_FRAME",
                0.035,
            )
        box(
            f"HMS_frame_joint_gold_{label}",
            (x_value, y_value - 0.12, 2.67),
            (0.20, 0.08, 0.12),
            "mat_hms_yellow_joint",
            "HMS_FRAME",
            0.018,
        )

    for label, y_value in (("front", -0.82), ("rear", 0.82)):
        box(
            f"HMS_frame_upper_rail_{label}",
            (0.0, y_value, 2.78),
            (4.85, 0.24, 0.24),
            "mat_hms_dark_frame",
            "HMS_FRAME",
            0.035,
        )
        beam_between(
            f"HMS_frame_brace_{label}_left",
            (-2.12, y_value, 2.58),
            (-1.45, y_value, 2.78),
            0.12,
            "mat_hms_dark_frame",
            "HMS_FRAME",
        )
        beam_between(
            f"HMS_frame_brace_{label}_right",
            (2.12, y_value, 2.58),
            (1.45, y_value, 2.78),
            0.12,
            "mat_hms_dark_frame",
            "HMS_FRAME",
        )
    for label, x_value in (("left", -2.3), ("right", 2.3)):
        box(
            f"HMS_frame_upper_side_{label}",
            (x_value, 0.0, 2.78),
            (0.24, 1.85, 0.24),
            "mat_hms_dark_frame",
            "HMS_FRAME",
            0.035,
        )

    # ------------------------------------------------------------------
    # Orange canopy: broad, shallow, segmented and visibly detachable.
    # ------------------------------------------------------------------
    box(
        "HMS_canopy_main",
        (0.0, 0.0, 3.02),
        (5.25, 2.32, 0.24),
        "mat_hms_orange_canopy",
        "HMS_CANOPY",
        0.08,
    )
    for x_value in (-1.78, 1.78):
        box(
            f"HMS_canopy_top_seam_{x_value:+.2f}",
            (x_value, 0.0, 3.155),
            (0.10, 2.12, 0.07),
            "mat_hms_dark_frame",
            "HMS_CANOPY",
            0.018,
        )
    for x_value in (-2.18, 2.18):
        for y_value in (-0.86, 0.86):
            box(
                f"HMS_canopy_patch_{x_value:+.2f}_{y_value:+.2f}",
                (x_value, y_value, 3.165),
                (0.40, 0.24, 0.075),
                "mat_hms_dark_frame",
                "HMS_CANOPY",
                0.018,
            )
            box(
                f"HMS_canopy_patch_fastener_{x_value:+.2f}_{y_value:+.2f}",
                (x_value, y_value, 3.207),
                (0.13, 0.09, 0.025),
                "mat_hms_yellow_joint",
                "HMS_CANOPY",
                0.006,
            )
    for label, x_value in (("left", -2.48), ("right", 2.48)):
        box(
            f"HMS_canopy_end_cap_{label}",
            (x_value, 0.0, 3.03),
            (0.28, 2.2, 0.32),
            "mat_hms_orange_edge",
            "HMS_CANOPY",
            0.055,
        )
    for label, y_value in (("front", -1.08), ("rear", 1.08)):
        box(
            f"HMS_canopy_edge_{label}",
            (0.0, y_value, 2.98),
            (4.8, 0.17, 0.30),
            "mat_hms_orange_edge",
            "HMS_CANOPY",
            0.035,
        )
        for x_value in (-1.9, 0.0, 1.9):
            box(
                f"HMS_canopy_latch_{label}_{x_value:+.1f}",
                (x_value, y_value - (0.07 if y_value < 0 else -0.07), 2.91),
                (0.30, 0.12, 0.18),
                "mat_hms_dark_frame",
                "HMS_CANOPY",
                0.025,
            )

    # Simple pale market glyph on the canopy.
    for rotation in (math.radians(45.0), math.radians(-45.0)):
        box(
            f"HMS_canopy_market_glyph_{rotation:+.2f}",
            (0.0, -0.05, 3.155),
            (1.0, 0.16, 0.025),
            "mat_hms_cream_mark",
            "HMS_SIGNAGE",
            0.01,
            rotation=(0.0, 0.0, rotation),
        )

    # ------------------------------------------------------------------
    # Enclosed teal counter body with replaceable face panels.
    # ------------------------------------------------------------------
    box(
        "HMS_counter_body",
        (0.0, 0.10, 0.58),
        (4.15, 1.10, 0.88),
        "mat_hms_teal_panel",
        "HMS_COUNTER",
        0.055,
    )
    box(
        "HMS_counter_top",
        (0.0, 0.02, 1.08),
        (4.42, 1.34, 0.16),
        "mat_hms_orange_canopy",
        "HMS_COUNTER",
        0.045,
    )
    box(
        "HMS_counter_top_edge",
        (0.0, -0.63, 1.07),
        (4.50, 0.12, 0.22),
        "mat_hms_teal_trim",
        "HMS_COUNTER",
        0.025,
    )
    for index, x_value in enumerate((-1.38, 0.0, 1.38), start=1):
        box(
            f"HMS_counter_front_panel_{index:02d}",
            (x_value, -0.465, 0.58),
            (1.28, 0.08, 0.66),
            "mat_hms_teal_panel",
            "HMS_COUNTER",
            0.025,
        )
        for corner_x in (-0.54, 0.54):
            cylinder(
                f"HMS_counter_panel_bolt_{index:02d}_{corner_x:+.2f}",
                (x_value + corner_x, -0.515, 0.80),
                0.035,
                0.04,
                "mat_hms_yellow_joint",
                "HMS_COUNTER",
                8,
            )
    box(
        "HMS_counter_front_vent",
        (0.0, -0.525, 0.52),
        (0.76, 0.06, 0.30),
        "mat_hms_dark_frame",
        "HMS_COUNTER",
        0.025,
    )
    for z_value in (0.44, 0.52, 0.60):
        box(
            f"HMS_counter_front_vent_slit_{z_value:.2f}",
            (0.0, -0.565, z_value),
            (0.58, 0.025, 0.025),
            "mat_hms_yellow_joint",
            "HMS_COUNTER",
            0.006,
        )
    for x_value in (-1.38, 1.38):
        for angle in (45.0, -45.0):
            box(
                f"HMS_counter_hazard_{x_value:+.2f}_{angle:+.0f}",
                (x_value, -0.57, 0.58),
                (0.34, 0.025, 0.055),
                "mat_hms_orange_edge",
                "HMS_SIGNAGE",
                0.008,
                rotation=(0.0, math.radians(angle), 0.0),
            )

    # ------------------------------------------------------------------
    # Detachable hanging lights and side banner.
    # ------------------------------------------------------------------
    for index, x_value in enumerate((-1.25, 1.25), start=1):
        cylinder(
            f"HMS_light_drop_stem_{index:02d}",
            (x_value, -0.15, 2.58),
            0.035,
            0.40,
            "mat_hms_dark_frame",
            "HMS_LIGHTS",
            8,
        )
        box(
            f"HMS_light_housing_{index:02d}",
            (x_value, -0.15, 2.34),
            (0.42, 0.34, 0.18),
            "mat_hms_dark_frame",
            "HMS_LIGHTS",
            0.035,
        )
        cylinder(
            f"HMS_light_amber_{index:02d}",
            (x_value, -0.15, 2.19),
            0.17,
            0.20,
            "mat_hms_amber_light",
            "HMS_LIGHTS",
            8,
        )
    box(
        "HMS_banner_left",
        (-2.44, -0.25, 2.02),
        (0.06, 0.78, 1.20),
        "mat_hms_purple_banner",
        "HMS_SIGNAGE",
        0.018,
    )
    box(
        "HMS_banner_left_bottom_trim",
        (-2.47, -0.25, 1.43),
        (0.08, 0.82, 0.08),
        "mat_hms_orange_edge",
        "HMS_SIGNAGE",
        0.015,
    )

    # ------------------------------------------------------------------
    # Separate placeholder cargo modules shown in the reference.
    # ------------------------------------------------------------------
    crate_specs = (
        ("teal_large", -1.30, 0.05, 0.76, 0.62, 0.62, "mat_hms_teal_panel"),
        ("blue_small", 0.55, -0.05, 0.60, 0.52, 0.48, "mat_hms_blue_crate"),
        ("olive_small", 1.30, 0.04, 0.62, 0.55, 0.52, "mat_hms_olive_crate"),
    )
    for name, x_value, y_value, width, depth, height, material_name in crate_specs:
        box(
            f"HMS_prop_crate_{name}",
            (x_value, y_value, 1.10 + height * 0.5),
            (width, depth, height),
            material_name,
            "HMS_PROPS",
            0.055,
        )
        box(
            f"HMS_prop_crate_lid_{name}",
            (x_value, y_value, 1.10 + height + 0.035),
            (width + 0.08, depth + 0.08, 0.07),
            "mat_hms_dark_frame",
            "HMS_PROPS",
            0.018,
        )

    # Godot-friendly collision proxies.
    collision_specs = (
        ("counter", (0.0, 0.10, 0.58), (4.45, 1.35, 1.05)),
        ("canopy", (0.0, 0.0, 3.02), (5.3, 2.4, 0.28)),
        ("post_front_left", (-2.3, -0.82, 1.50), (0.42, 0.42, 2.9)),
        ("post_front_right", (2.3, -0.82, 1.50), (0.42, 0.42, 2.9)),
        ("post_rear_left", (-2.3, 0.82, 1.50), (0.42, 0.42, 2.9)),
        ("post_rear_right", (2.3, 0.82, 1.50), (0.42, 0.42, 2.9)),
    )
    for name, location, dimensions in collision_specs:
        proxy = box(
            f"HMS_collision_{name}",
            location,
            dimensions,
            "mat_hms_collision",
            "HMS_COLLISION",
        )
        proxy.display_type = "WIRE"
        proxy.hide_render = True

    for obj in scene.objects:
        if obj.type != "MESH":
            continue
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        obj.select_set(False)

    scene["asset_name"] = "Hesperus Modular Market Stall"
    scene["asset_role"] = "modular_market_stall"
    scene["dimensions_m"] = (5.3, 2.4, 3.2)
    scene["front_direction"] = "-Y"
    scene["godot_units"] = "1 Blender unit = 1 meter"

    OUTPUT_BLEND.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND))
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT_GLB),
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_extras=True,
        use_selection=False,
    )
    print(f"Built {OUTPUT_BLEND}")
    print(f"Exported {OUTPUT_GLB}")
    print(f"Object count: {len(scene.objects)}")


build()
