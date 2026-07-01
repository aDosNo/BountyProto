from pathlib import Path
import math

import bmesh
import bpy
from mathutils import Vector


ROOT = Path("/var/home/nick/bounty-hunt")
OUTPUT_BLEND = ROOT / "assets/blender_models/holo_cantina_arch_shell_v2.blend"
OUTPUT_GLB = ROOT / "assets/blender_models/holo_cantina_arch_shell_v2.glb"
SCALE_X = 1.45
SCALE_Y = 1.25
SCALE_Z = 1.20

COLLECTION_NAMES = [
    "HC_ARCH_Shell",
    "HC_ARCH_Floors",
    "HC_ARCH_Entrances",
    "HC_ARCH_Routes",
    "HC_ARCH_Coolant",
    "HC_ARCH_SignagePlanes",
    "HC_ARCH_CollisionProxy",
    "HC_ARCH_ReferenceLabels",
]

MATERIAL_SPECS = {
    "mat_asteroid_dark_rock": ((0.075, 0.065, 0.075, 1.0), 0.95, 0.0),
    "mat_dark_metal_wall": ((0.055, 0.065, 0.075, 1.0), 0.82, 0.0),
    "mat_panel_metal": ((0.13, 0.15, 0.17, 1.0), 0.68, 0.0),
    "mat_floor_grate": ((0.095, 0.11, 0.12, 1.0), 0.75, 0.0),
    "mat_airlock_trim": ((0.24, 0.20, 0.22, 1.0), 0.55, 0.0),
    "mat_neon_pink": ((1.0, 0.04, 0.42, 1.0), 0.35, 5.0),
    "mat_neon_blue": ((0.02, 0.55, 1.0, 1.0), 0.35, 5.0),
    "mat_neon_green": ((0.12, 0.9, 0.28, 1.0), 0.35, 4.0),
    "mat_coolant_pipe_blue": ((0.035, 0.22, 0.55, 1.0), 0.4, 1.0),
    "mat_warning_yellow_black": ((0.9, 0.55, 0.025, 1.0), 0.6, 0.0),
    "mat_interior_shadow": ((0.012, 0.014, 0.018, 1.0), 1.0, 0.0),
    "mat_collision_transparent": ((0.1, 0.8, 0.3, 0.1), 1.0, 0.0),
}


def clear_holo_cantina_scene():
    # Direct removal also clears objects hidden during viewport cutaway reviews;
    # Blender's select-all/delete leaves hidden objects behind.
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for collection in list(bpy.data.collections):
        if collection.name in COLLECTION_NAMES or collection.name.startswith("HC_PREVIEW"):
            bpy.data.collections.remove(collection)
    for material in list(bpy.data.materials):
        if material.name in MATERIAL_SPECS:
            bpy.data.materials.remove(material)
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    for curve in list(bpy.data.curves):
        if curve.users == 0:
            bpy.data.curves.remove(curve)


def make_collections():
    result = {}
    for name in COLLECTION_NAMES:
        collection = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(collection)
        result[name] = collection
    return result


def make_materials():
    result = {}
    for name, (color, roughness, emission_strength) in MATERIAL_SPECS.items():
        material = bpy.data.materials.new(name)
        material.diffuse_color = color
        material.use_nodes = True
        bsdf = material.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = roughness
        if emission_strength > 0.0:
            emission_input = (
                bsdf.inputs.get("Emission Color")
                or bsdf.inputs.get("Emission")
            )
            if emission_input is not None:
                emission_input.default_value = color
            strength_input = bsdf.inputs.get("Emission Strength")
            if strength_input is not None:
                strength_input.default_value = emission_strength
        if name == "mat_collision_transparent":
            bsdf.inputs["Alpha"].default_value = 0.1
            if hasattr(material, "surface_render_method"):
                material.surface_render_method = "DITHERED"
            elif hasattr(material, "blend_method"):
                material.blend_method = "BLEND"
            material.show_transparent_back = True
        result[name] = material
    return result


def build():
    clear_holo_cantina_scene()
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    collections = make_collections()
    materials = make_materials()

    def move_to_collection(obj, collection_name):
        for collection in list(obj.users_collection):
            collection.objects.unlink(obj)
        collections[collection_name].objects.link(obj)
        return obj

    def bevel(obj, width=0.06):
        if width > 0.0:
            modifier = obj.modifiers.new("HC_SimpleBevel", "BEVEL")
            modifier.width = width
            modifier.segments = 1
        return obj

    def box(
        name,
        location,
        dimensions,
        material_name,
        collection_name,
        bevel_width=0.06,
        rotation=(0.0, 0.0, 0.0),
    ):
        bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
        obj = bpy.context.object
        obj.name = name
        obj.dimensions = dimensions
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        obj.data.materials.append(materials[material_name])
        move_to_collection(obj, collection_name)
        bevel(obj, bevel_width)
        return obj

    def cylinder(
        name,
        location,
        radius,
        depth,
        material_name,
        collection_name,
        vertices=12,
        rotation=(0.0, 0.0, 0.0),
        bevel_width=0.03,
    ):
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=vertices,
            radius=radius,
            depth=depth,
            location=location,
            rotation=rotation,
        )
        obj = bpy.context.object
        obj.name = name
        obj.data.materials.append(materials[material_name])
        move_to_collection(obj, collection_name)
        bevel(obj, bevel_width)
        return obj

    def cylinder_between(
        name,
        point_a,
        point_b,
        radius,
        material_name,
        collection_name,
        vertices=12,
    ):
        point_a = Vector(point_a)
        point_b = Vector(point_b)
        direction = point_b - point_a
        obj = cylinder(
            name,
            (point_a + point_b) * 0.5,
            radius,
            direction.length,
            material_name,
            collection_name,
            vertices=vertices,
            bevel_width=0.025,
        )
        obj.rotation_mode = "QUATERNION"
        obj.rotation_quaternion = direction.to_track_quat("Z", "Y")
        return obj

    def octagonal_prism(
        name,
        location,
        radius,
        depth,
        material_name,
        collection_name,
        bevel_width=0.04,
    ):
        return cylinder(
            name,
            location,
            radius,
            depth,
            material_name,
            collection_name,
            vertices=8,
            rotation=(0.0, 0.0, math.radians(22.5)),
            bevel_width=bevel_width,
        )

    def annulus(
        name,
        location,
        outer_radius,
        inner_radius,
        depth,
        material_name,
        collection_name,
        segments=8,
    ):
        vertices = []
        faces = []
        angle_offset = math.radians(22.5)
        for z in (-depth * 0.5, depth * 0.5):
            for radius in (outer_radius, inner_radius):
                for index in range(segments):
                    angle = 2.0 * math.pi * index / segments + angle_offset
                    vertices.append(
                        (
                            radius * math.cos(angle),
                            radius * math.sin(angle),
                            z,
                        )
                    )
        for index in range(segments):
            next_index = (index + 1) % segments
            bottom_outer = index
            bottom_outer_next = next_index
            bottom_inner = segments + index
            bottom_inner_next = segments + next_index
            top_outer = 2 * segments + index
            top_outer_next = 2 * segments + next_index
            top_inner = 3 * segments + index
            top_inner_next = 3 * segments + next_index
            faces.extend(
                [
                    (top_outer, top_outer_next, top_inner_next, top_inner),
                    (
                        bottom_outer,
                        bottom_inner,
                        bottom_inner_next,
                        bottom_outer_next,
                    ),
                    (
                        bottom_outer,
                        bottom_outer_next,
                        top_outer_next,
                        top_outer,
                    ),
                    (
                        bottom_inner,
                        top_inner,
                        top_inner_next,
                        bottom_inner_next,
                    ),
                ]
            )
        mesh = bpy.data.meshes.new(f"{name}_mesh")
        mesh.from_pydata(vertices, [], faces)
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        collections[collection_name].objects.link(obj)
        obj.location = location
        obj.data.materials.append(materials[material_name])
        bevel(obj, 0.025)
        return obj

    def rock(
        name,
        location,
        dimensions,
        rotation=(0.0, 0.0, 0.0),
    ):
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=1,
            radius=1.0,
            location=location,
            rotation=rotation,
        )
        obj = bpy.context.object
        obj.name = name
        obj.dimensions = dimensions
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        obj.data.materials.append(materials["mat_asteroid_dark_rock"])
        move_to_collection(obj, "HC_ARCH_Shell")
        for polygon in obj.data.polygons:
            polygon.use_smooth = False
        return obj

    def asteroid_monolith():
        # Exterior-first construction: one broad cliff core is fused with
        # deeply-overlapping shoulders, crown ridges, rear spine, and base apron.
        # Voxel remeshing turns those forms into one continuous formation before
        # the cantina chamber is carved from it.
        bpy.ops.mesh.primitive_cube_add(location=(0.0, 2.0, 5.5))
        core = bpy.context.object
        core.name = "HC2_TEMP_cliff_core"
        core.dimensions = (32.0, 23.0, 19.0)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        bevel_modifier = core.modifiers.new("HC2_CliffCoreBevel", "BEVEL")
        bevel_modifier.width = 5.0
        bevel_modifier.segments = 2
        bpy.context.view_layer.objects.active = core
        bpy.ops.object.modifier_apply(modifier=bevel_modifier.name)
        core.data.materials.append(materials["mat_asteroid_dark_rock"])
        rock_forms = [core]
        exterior_forms = (
            ("left_buttress", (-14.0, -1.0, 3.5), (11.0, 18.0, 14.0), (0.02, 0.12, -0.10)),
            ("right_buttress", (14.0, 1.0, 4.5), (12.0, 19.0, 16.0), (-0.05, -0.10, 0.08)),
            ("crown_left", (-6.0, 2.0, 13.5), (18.0, 17.0, 8.5), (0.10, 0.05, -0.04)),
            ("crown_right", (7.0, 3.0, 14.5), (19.0, 16.0, 9.5), (-0.08, -0.04, 0.06)),
            ("rear_spine", (0.0, 9.5, 9.5), (25.0, 9.0, 14.0), (0.03, 0.0, 0.02)),
            ("front_apron", (0.0, -10.0, -1.4), (34.0, 8.0, 4.2), (0.0, 0.0, 0.01)),
        )
        for form_index, (name, location, dimensions, rotation) in enumerate(exterior_forms):
            bpy.ops.mesh.primitive_ico_sphere_add(
                subdivisions=2,
                radius=1.0,
                location=location,
                rotation=rotation,
            )
            form = bpy.context.object
            form.name = f"HC2_TEMP_{name}"
            form.dimensions = dimensions
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            for vertex in form.data.vertices:
                noise = (
                    math.sin((vertex.index + form_index * 19) * 1.37) * 0.5
                    + math.cos((vertex.index + form_index * 7) * 0.71) * 0.3
                )
                vertex.co += vertex.co.normalized() * noise
            form.data.materials.append(materials["mat_asteroid_dark_rock"])
            rock_forms.append(form)

        for form in rock_forms:
            form.select_set(True)
        bpy.context.view_layer.objects.active = core
        bpy.ops.object.join()
        asteroid = bpy.context.object
        asteroid.name = "HC_shell_asteroid_monolith"
        asteroid.data.remesh_voxel_size = 0.65
        asteroid.data.remesh_voxel_adaptivity = 0.25
        bpy.context.view_layer.objects.active = asteroid
        bpy.ops.object.voxel_remesh()
        decimate = asteroid.modifiers.new("HC2_AsteroidExteriorDecimate", "DECIMATE")
        decimate.ratio = 0.13
        decimate.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=decimate.name)
        move_to_collection(asteroid, "HC_ARCH_Shell")
        for polygon in asteroid.data.polygons:
            polygon.use_smooth = False

        cutter_specs = (
            # The chamber remains enclosed by substantial rock on every outer
            # side. Separate cuts connect it to the three gameplay routes.
            ("HC_TEMP_asteroid_main_cavity", (0.0, 0.0, 2.9), (23.0, 19.2, 15.0)),
            # Broad front grotto exposes the facade while retaining a deep,
            # continuous rock arch and side masses.
            ("HC_TEMP_asteroid_front_facade_cut", (0.0, -10.8, 5.4), (24.0, 5.5, 10.8)),
            # Rear loading-dock and cargo-lift approach connects to the chamber.
            ("HC_TEMP_asteroid_rear_dock_cut", (5.5, 10.8, 1.5), (9.0, 6.0, 8.0)),
            # Left-side VIP vent penetration behind the scaffold.
            ("HC_TEMP_asteroid_vent_cut", (15.3, 0.0, 6.2), (9.4, 3.4, 4.2)),
        )
        for cutter_name, location, dimensions in cutter_specs:
            bpy.ops.mesh.primitive_cube_add(location=location)
            cutter = bpy.context.object
            cutter.name = cutter_name
            cutter.dimensions = dimensions
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            if cutter_name == "HC_TEMP_asteroid_main_cavity":
                cutter_bevel = cutter.modifiers.new("HC_CarvedOpeningFacets", "BEVEL")
                cutter_bevel.width = 1.5
                cutter_bevel.segments = 1
                bpy.context.view_layer.objects.active = cutter
                bpy.ops.object.modifier_apply(modifier=cutter_bevel.name)
            modifier = asteroid.modifiers.new(cutter_name, "BOOLEAN")
            modifier.operation = "DIFFERENCE"
            modifier.solver = "EXACT"
            modifier.object = cutter
            bpy.context.view_layer.objects.active = asteroid
            bpy.ops.object.modifier_apply(modifier=modifier.name)
            bpy.data.objects.remove(cutter, do_unlink=True)

        triangulate = asteroid.modifiers.new("HC_AsteroidTriangulation", "TRIANGULATE")
        bpy.context.view_layer.objects.active = asteroid
        bpy.ops.object.modifier_apply(modifier=triangulate.name)

        # Boolean cuts can leave tiny detached chips at tangent intersections.
        # Keep only the dominant connected body so the export remains one
        # believable asteroid rather than a monolith plus floating fragments.
        edit_mesh = bmesh.new()
        edit_mesh.from_mesh(asteroid.data)
        remaining = set(edit_mesh.verts)
        components = []
        while remaining:
            seed = remaining.pop()
            component = {seed}
            frontier = [seed]
            while frontier:
                vertex = frontier.pop()
                for edge in vertex.link_edges:
                    neighbor = edge.other_vert(vertex)
                    if neighbor in remaining:
                        remaining.remove(neighbor)
                        component.add(neighbor)
                        frontier.append(neighbor)
            components.append(component)
        dominant_component = max(components, key=len)
        bmesh.ops.delete(
            edit_mesh,
            geom=[vertex for vertex in edit_mesh.verts if vertex not in dominant_component],
            context="VERTS",
        )
        edit_mesh.to_mesh(asteroid.data)
        edit_mesh.free()
        asteroid.data.update()

        asteroid.data.materials.clear()
        asteroid.data.materials.append(materials["mat_asteroid_dark_rock"])
        return asteroid

    def text_mesh(
        name,
        body,
        location,
        size,
        material_name,
        rotation=(math.radians(90.0), 0.0, 0.0),
        extrude=0.025,
    ):
        curve = bpy.data.curves.new(f"{name}_curve", "FONT")
        curve.body = body
        curve.align_x = "CENTER"
        curve.align_y = "CENTER"
        curve.size = size
        curve.extrude = extrude
        curve.bevel_depth = 0.006
        curve.bevel_resolution = 0
        obj = bpy.data.objects.new(name, curve)
        collections["HC_ARCH_SignagePlanes"].objects.link(obj)
        obj.location = location
        obj.rotation_euler = rotation
        obj.data.materials.append(materials[material_name])
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.convert(target="MESH")
        obj.select_set(False)
        return obj

    def reference_label(name, location):
        obj = bpy.data.objects.new(name, None)
        collections["HC_ARCH_ReferenceLabels"].objects.link(obj)
        obj.location = location
        obj.empty_display_type = "CUBE"
        obj.empty_display_size = 0.45
        obj["hc_reference_only"] = True
        return obj

    def collision_box(name, location, dimensions):
        obj = box(
            name,
            location,
            dimensions,
            "mat_collision_transparent",
            "HC_ARCH_CollisionProxy",
            bevel_width=0.0,
        )
        obj.display_type = "WIRE"
        obj["godot_collision_proxy"] = True
        return obj

    # ------------------------------------------------------------------
    # Main metal shell: a readable industrial insert with real openings.
    # ------------------------------------------------------------------
    shell_parent = bpy.data.objects.new("HC_shell_main_metal_volume", None)
    collections["HC_ARCH_Shell"].objects.link(shell_parent)
    shell_parent["dimensions_m"] = (22.0, 18.0, 10.0)

    roof = box(
        "HC_shell_roof_service_cap",
        (0.0, 0.0, 10.0),
        (22.0, 18.0, 0.45),
        "mat_dark_metal_wall",
        "HC_ARCH_Shell",
        0.12,
    )
    roof.parent = shell_parent

    # Front wall leaves the five-meter airlock opening clear.
    for name, x_value, width in (
        ("HC_shell_front_facade_panels_left", -6.75, 8.5),
        ("HC_shell_front_facade_panels_right", 6.75, 8.5),
    ):
        obj = box(
            name,
            (x_value, -9.0, 4.8),
            (width, 0.45, 9.6),
            "mat_dark_metal_wall",
            "HC_ARCH_Shell",
            0.09,
        )
        obj.parent = shell_parent
    box(
        "HC_shell_front_facade_panels_header",
        (0.0, -9.0, 7.2),
        (5.0, 0.45, 5.2),
        "mat_dark_metal_wall",
        "HC_ARCH_Shell",
        0.09,
    ).parent = shell_parent

    # Left wall is segmented around the high stealth vent.
    left_wall_specs = (
        ("HC_shell_side_panel_left_lower", (-10.85, 0.0, 2.35), (0.4, 18.0, 4.7)),
        ("HC_shell_side_panel_left_upper_front", (-10.85, -5.5, 7.35), (0.4, 7.0, 5.3)),
        ("HC_shell_side_panel_left_upper_rear", (-10.85, 5.5, 7.35), (0.4, 7.0, 5.3)),
        ("HC_shell_side_panel_left_vent_header", (-10.85, 0.0, 8.75), (0.4, 4.0, 2.5)),
    )
    for name, location, dimensions in left_wall_specs:
        box(
            name,
            location,
            dimensions,
            "mat_dark_metal_wall",
            "HC_ARCH_Shell",
            0.08,
        ).parent = shell_parent

    box(
        "HC_shell_side_panel_right",
        (10.85, 0.0, 5.0),
        (0.4, 18.0, 10.0),
        "mat_dark_metal_wall",
        "HC_ARCH_Shell",
        0.08,
    ).parent = shell_parent

    # Rear wall leaves a four-meter loading-dock opening below and three
    # genuine VIP lounge openings at mezzanine height.
    rear_segments = (
        ("HC_shell_rear_service_wall_lower_left", (-3.75, 9.0, 2.25), (14.5, 0.45, 4.5)),
        ("HC_shell_rear_service_wall_lower_right", (9.25, 9.0, 2.25), (3.5, 0.45, 4.5)),
        ("HC_shell_rear_service_wall_dock_header", (5.5, 9.0, 4.0), (4.0, 0.45, 1.0)),
        ("HC_shell_rear_service_wall_vip_left", (-8.5, 9.0, 5.75), (5.0, 0.45, 2.5)),
        ("HC_shell_rear_service_wall_vip_mid_left", (-2.5, 9.0, 5.75), (3.0, 0.45, 2.5)),
        ("HC_shell_rear_service_wall_vip_mid_right", (2.5, 9.0, 5.75), (3.0, 0.45, 2.5)),
        ("HC_shell_rear_service_wall_vip_right", (8.5, 9.0, 5.75), (5.0, 0.45, 2.5)),
        ("HC_shell_rear_service_wall_upper", (0.0, 9.0, 8.5), (22.0, 0.45, 3.0)),
    )
    for name, location, dimensions in rear_segments:
        box(
            name,
            location,
            dimensions,
            "mat_dark_metal_wall",
            "HC_ARCH_Shell",
            0.08,
        ).parent = shell_parent

    # Structural floor bands and columns sell the inserted metal volume.
    for z_value in (0.0, 4.5, 9.5):
        for y_value in (-8.8, 8.8):
            box(
                f"HC_shell_horizontal_band_y{y_value:+.0f}_z{z_value:.1f}",
                (0.0, y_value, z_value),
                (21.5, 0.35, 0.35),
                "mat_panel_metal",
                "HC_ARCH_Shell",
                0.04,
            )
    for x_value in (-10.5, -5.25, 0.0, 5.25, 10.5):
        for y_value in (-8.7, 8.7):
            box(
                f"HC_shell_support_x{x_value:+.2f}_y{y_value:+.1f}",
                (x_value, y_value, 5.0),
                (0.42, 0.42, 10.0),
                "mat_panel_metal",
                "HC_ARCH_Shell",
                0.04,
            )

    # ------------------------------------------------------------------
    # Cohesive faceted asteroid body, carved around the inserted cantina.
    # ------------------------------------------------------------------
    asteroid_monolith()

    # ------------------------------------------------------------------
    # Playable floor tiers.
    # ------------------------------------------------------------------
    box(
        "HC_floor_ground_main",
        (0.0, -2.5, -0.15),
        (20.0, 11.0, 0.3),
        "mat_floor_grate",
        "HC_ARCH_Floors",
        0.03,
    )
    box(
        "HC_floor_ground_front_lobby_strip",
        (0.0, -9.8, -0.12),
        (5.0, 4.0, 0.28),
        "mat_panel_metal",
        "HC_ARCH_Floors",
        0.03,
    )
    box(
        "HC_floor_ground_rear_service_strip",
        (-2.75, 6.0, -0.15),
        (14.5, 6.0, 0.3),
        "mat_floor_grate",
        "HC_ARCH_Floors",
        0.03,
    )
    for name, location, dimensions in (
        ("HC_floor_ground_lift_right_strip", (8.75, 6.0, -0.15), (2.5, 6.0, 0.3)),
        ("HC_floor_ground_lift_front_strip", (6.0, 4.0, -0.15), (3.0, 2.0, 0.3)),
        ("HC_floor_ground_lift_rear_strip", (6.0, 8.5, -0.15), (3.0, 1.0, 0.3)),
    ):
        box(
            name,
            location,
            dimensions,
            "mat_floor_grate",
            "HC_ARCH_Floors",
            0.03,
        )

    octagonal_prism(
        "HC_floor_ground_ring_octagon",
        (0.0, 0.0, 0.02),
        3.55,
        0.18,
        "mat_dark_metal_wall",
        "HC_ARCH_Floors",
    )
    annulus(
        "HC_floor_ground_ring_outer_trim",
        (0.0, 0.0, 0.15),
        4.1,
        3.55,
        0.18,
        "mat_airlock_trim",
        "HC_ARCH_Floors",
    )

    # Full-width basement/service tier, proportioned like the reference cutaway.
    box(
        "HC_floor_basement_service_room",
        (0.0, 3.5, -4.15),
        (20.0, 11.0, 0.3),
        "mat_floor_grate",
        "HC_ARCH_Floors",
        0.03,
    )
    for name, location, dimensions in (
        ("HC_shell_basement_left_wall", (-9.85, 3.5, -2.0), (0.3, 11.0, 4.0)),
        ("HC_shell_basement_right_wall", (9.85, 3.5, -2.0), (0.3, 11.0, 4.0)),
        ("HC_shell_basement_front_wall", (0.0, -1.85, -2.0), (20.0, 0.3, 4.0)),
        ("HC_shell_basement_rear_left", (-3.0, 8.85, -2.0), (14.0, 0.3, 4.0)),
        ("HC_shell_basement_rear_right", (9.0, 8.85, -2.0), (2.0, 0.3, 4.0)),
    ):
        box(
            name,
            location,
            dimensions,
            "mat_interior_shadow",
            "HC_ARCH_Shell",
            0.04,
        )

    # U-shaped VIP mezzanine.
    mezzanine_specs = (
        ("HC_floor_mezzanine_left_walkway", (-8.65, 0.0, 4.5), (2.7, 16.0, 0.3)),
        ("HC_floor_mezzanine_rear_walkway", (0.0, 6.65, 4.5), (17.3, 2.7, 0.3)),
        ("HC_floor_mezzanine_right_walkway", (8.65, 0.0, 4.5), (2.7, 16.0, 0.3)),
    )
    for name, location, dimensions in mezzanine_specs:
        box(
            name,
            location,
            dimensions,
            "mat_floor_grate",
            "HC_ARCH_Floors",
            0.035,
        )

    # Railings remain chunky and low-poly.
    for name, location, dimensions in (
        ("HC_route_mezzanine_railing_left", (-7.28, -0.3, 5.15), (0.14, 15.4, 1.3)),
        ("HC_route_mezzanine_railing_rear", (0.0, 5.28, 5.15), (14.5, 0.14, 1.3)),
        ("HC_route_mezzanine_railing_right", (7.28, -0.3, 5.15), (0.14, 15.4, 1.3)),
    ):
        box(
            name,
            location,
            dimensions,
            "mat_panel_metal",
            "HC_ARCH_Routes",
            0.025,
        )

    # Three shallow, genuinely open VIP lounge alcoves.
    for index, x_value in enumerate((-5.0, 0.0, 5.0), start=1):
        box(
            f"HC_entry_vip_lounge_{index:02d}",
            (x_value, 10.25, 5.72),
            (3.8, 0.18, 2.4),
            "mat_interior_shadow",
            "HC_ARCH_Entrances",
            0.02,
        )
        for side in (-1.0, 1.0):
            box(
                f"HC_entry_vip_lounge_{index:02d}_jamb_{'L' if side < 0 else 'R'}",
                (x_value + side * 1.08, 8.62, 5.72),
                (0.18, 0.36, 2.65),
                "mat_airlock_trim",
                "HC_ARCH_Entrances",
                0.025,
            )
        box(
            f"HC_entry_vip_lounge_{index:02d}_header",
            (x_value, 8.62, 7.0),
            (2.35, 0.36, 0.22),
            "mat_airlock_trim",
            "HC_ARCH_Entrances",
            0.025,
        )
        box(
            f"HC_floor_vip_alcove_{index:02d}",
            (x_value, 9.65, 4.48),
            (3.8, 1.3, 0.26),
            "mat_panel_metal",
            "HC_ARCH_Floors",
            0.03,
        )

    # Public stair to mezzanine, tucked into the right rear edge.
    for index in range(12):
        box(
            f"HC_route_mezzanine_stair_step_{index:02d}",
            (8.2, 2.2 + index * 0.43, 0.19 + index * 0.37),
            (2.1, 0.46, 0.38),
            "mat_floor_grate",
            "HC_ARCH_Routes",
            0.02,
        )
    box(
        "HC_route_mezzanine_stair_outer_rail",
        (9.2, 4.55, 2.55),
        (0.12, 5.4, 4.8),
        "mat_panel_metal",
        "HC_ARCH_Routes",
        0.02,
    )

    # ------------------------------------------------------------------
    # Rafter and holo-projector grid.
    # ------------------------------------------------------------------
    box(
        "HC_shell_rafter_grid_main",
        (0.0, 0.0, 9.2),
        (18.0, 0.32, 0.35),
        "mat_panel_metal",
        "HC_ARCH_Shell",
        0.035,
    )
    for index, y_value in enumerate((-5.2, -1.75, 1.75, 5.2), start=1):
        box(
            f"HC_shell_rafter_crossbeam_{index:02d}",
            (0.0, y_value, 9.15),
            (18.0, 0.28, 0.4),
            "mat_panel_metal",
            "HC_ARCH_Shell",
            0.035,
        )
    for x_value in (-6.0, 0.0, 6.0):
        box(
            f"HC_shell_rafter_longbeam_{x_value:+.0f}",
            (x_value, 0.0, 9.35),
            (0.3, 13.5, 0.32),
            "mat_panel_metal",
            "HC_ARCH_Shell",
            0.035,
        )
    projector_locations = (
        (-2.7, -2.7, 8.55),
        (2.7, -2.7, 8.55),
        (-2.7, 2.7, 8.55),
        (2.7, 2.7, 8.55),
    )
    for index, location in enumerate(projector_locations, start=1):
        box(
            f"HC_shell_holo_projector_mount_{index:02d}",
            location,
            (0.8, 0.8, 0.8),
            "mat_dark_metal_wall",
            "HC_ARCH_Shell",
            0.07,
        )
        cylinder(
            f"HC_shell_holo_projector_lens_{index:02d}",
            (location[0], location[1], location[2] - 0.48),
            0.22,
            0.08,
            "mat_neon_blue",
            "HC_ARCH_Shell",
            vertices=12,
        )

    # ------------------------------------------------------------------
    # Front public route.
    # ------------------------------------------------------------------
    lobby_parent = bpy.data.objects.new("HC_entry_front_lobby_tunnel", None)
    collections["HC_ARCH_Entrances"].objects.link(lobby_parent)
    for name, location, dimensions in (
        ("HC_entry_front_lobby_left_wall", (-2.62, -10.1, 2.0), (0.25, 3.0, 4.0)),
        ("HC_entry_front_lobby_right_wall", (2.62, -10.1, 2.0), (0.25, 3.0, 4.0)),
        ("HC_entry_front_lobby_ceiling", (0.0, -10.1, 4.0), (5.5, 3.0, 0.25)),
    ):
        piece = box(
            name,
            location,
            dimensions,
            "mat_interior_shadow",
            "HC_ARCH_Entrances",
            0.04,
        )
        piece.parent = lobby_parent
    for name, location, dimensions in (
        ("HC_entry_front_airlock_frame_left", (-2.75, -11.25, 2.0), (0.55, 0.75, 4.4)),
        ("HC_entry_front_airlock_frame_right", (2.75, -11.25, 2.0), (0.55, 0.75, 4.4)),
        ("HC_entry_front_airlock_frame_header", (0.0, -11.25, 4.15), (6.05, 0.75, 0.55)),
        ("HC_entry_front_airlock_frame_sill", (0.0, -11.25, -0.05), (6.05, 0.75, 0.2)),
    ):
        box(
            name,
            location,
            dimensions,
            "mat_airlock_trim",
            "HC_ARCH_Entrances",
            0.08,
        )
    # Door leaves are visibly retracted, keeping the route navigable.
    box(
        "HC_entry_front_airlock_left_door_panel",
        (-2.38, -11.2, 2.0),
        (0.32, 0.32, 3.75),
        "mat_panel_metal",
        "HC_ARCH_Entrances",
        0.04,
    )
    box(
        "HC_entry_front_airlock_right_door_panel",
        (2.38, -11.2, 2.0),
        (0.32, 0.32, 3.75),
        "mat_panel_metal",
        "HC_ARCH_Entrances",
        0.04,
    )
    for side, x_value in (("left", -4.05), ("right", 4.05)):
        box(
            f"HC_entry_front_bouncer_pad_{side}",
            (x_value, -11.0, 0.12),
            (2.0, 2.1, 0.24),
            "mat_panel_metal",
            "HC_ARCH_Entrances",
            0.04,
        )
        box(
            f"HC_entry_front_bouncer_alcove_{side}",
            (x_value, -9.2, 1.5),
            (2.1, 0.4, 3.0),
            "mat_interior_shadow",
            "HC_ARCH_Entrances",
            0.03,
        )

    # ------------------------------------------------------------------
    # Right-side scaffold stealth route and high vent, matching the reference
    # exterior elevation.
    # ------------------------------------------------------------------
    for x_value in (19.2, 17.3):
        for y_value in (-6.2, -3.2):
            box(
                f"HC_route_stealth_signage_scaffold_post_x{x_value:+.2f}_y{y_value:+.1f}",
                (x_value, y_value, 3.25),
                (0.22, 0.22, 6.5),
                "mat_panel_metal",
                "HC_ARCH_Routes",
                0.025,
            )
    for index, z_value in enumerate((0.65, 2.9, 5.25), start=1):
        box(
            f"HC_route_stealth_platform_{('low', 'mid', 'high')[index - 1]}",
            (18.2, -4.7, z_value),
            (2.5, 3.4, 0.24),
            "mat_floor_grate",
            "HC_ARCH_Routes",
            0.035,
        )
    # Ladder rungs are intentionally chunky.
    for index in range(12):
        box(
            f"HC_route_stealth_signage_scaffold_rung_{index:02d}",
            (19.3, -4.7, 0.45 + index * 0.48),
            (0.18, 1.35, 0.12),
            "mat_panel_metal",
            "HC_ARCH_Routes",
            0.015,
        )
    for name, location, dimensions in (
        ("HC_entry_stealth_vip_vent_frame_lower", (18.6, 0.0, 5.38), (0.55, 2.5, 0.22)),
        ("HC_entry_stealth_vip_vent_frame_upper", (18.6, 0.0, 7.02), (0.55, 2.5, 0.22)),
        ("HC_entry_stealth_vip_vent_frame_front", (18.6, -1.15, 6.2), (0.55, 0.22, 1.85)),
        ("HC_entry_stealth_vip_vent_frame_rear", (18.6, 1.15, 6.2), (0.55, 0.22, 1.85)),
    ):
        box(
            name,
            location,
            dimensions,
            "mat_airlock_trim",
            "HC_ARCH_Entrances",
            0.035,
        )
    box(
        "HC_entry_stealth_vip_vent_grate",
        (18.72, 0.0, 6.2),
        (0.12, 2.0, 1.5),
        "mat_floor_grate",
        "HC_ARCH_Entrances",
        0.02,
    )
    reference_label("HC_ROUTE_STEALTH_VENT_ENTRY", (19.0, 0.0, 6.2))

    # ------------------------------------------------------------------
    # Rear loading dock and basement cargo-lift tech route.
    # ------------------------------------------------------------------
    for name, location, dimensions in (
        ("HC_entry_rear_loading_dock_frame_left", (3.25, 9.3, 1.75), (0.5, 0.7, 3.8)),
        ("HC_entry_rear_loading_dock_frame_right", (7.75, 9.3, 1.75), (0.5, 0.7, 3.8)),
        ("HC_entry_rear_loading_dock_frame_header", (5.5, 9.3, 3.65), (5.0, 0.7, 0.55)),
    ):
        box(
            name,
            location,
            dimensions,
            "mat_airlock_trim",
            "HC_ARCH_Entrances",
            0.07,
        )
    box(
        "HC_entry_rear_loading_dock_door",
        (5.5, 9.1, 3.85),
        (4.0, 0.28, 0.25),
        "mat_warning_yellow_black",
        "HC_ARCH_Entrances",
        0.025,
    )
    box(
        "HC_route_tech_loading_dock_corridor",
        (5.5, 10.6, 0.12),
        (6.0, 4.0, 0.24),
        "mat_floor_grate",
        "HC_ARCH_Routes",
        0.04,
    )
    # Four posts define the open lift shaft from basement to ground.
    for x_value in (4.45, 7.55):
        for y_value in (4.95, 8.05):
            box(
                f"HC_route_tech_cargo_lift_shaft_x{x_value:.2f}_y{y_value:.2f}",
                (x_value, y_value, -1.85),
                (0.18, 0.18, 4.3),
                "mat_panel_metal",
                "HC_ARCH_Routes",
                0.02,
            )
    box(
        "HC_route_tech_cargo_lift_platform",
        (6.0, 6.5, -3.85),
        (3.0, 3.0, 0.25),
        "mat_warning_yellow_black",
        "HC_ARCH_Routes",
        0.035,
    )
    box(
        "HC_route_tech_lift_control_terminal_block",
        (8.15, 8.75, 1.0),
        (0.65, 0.5, 1.6),
        "mat_panel_metal",
        "HC_ARCH_Routes",
        0.05,
    )
    box(
        "HC_route_tech_basement_service_entry",
        (3.4, 6.5, -3.9),
        (2.2, 2.0, 0.18),
        "mat_floor_grate",
        "HC_ARCH_Routes",
        0.025,
    )
    box(
        "HC_route_tech_ground_floor_exit",
        (6.0, 4.8, 1.25),
        (3.4, 0.25, 2.5),
        "mat_airlock_trim",
        "HC_ARCH_Routes",
        0.035,
    )
    reference_label("HC_ROUTE_TECH_LOADING_DOCK", (5.5, 11.2, 1.0))

    # ------------------------------------------------------------------
    # Central coolant system.
    # ------------------------------------------------------------------
    cylinder_between(
        "HC_pipe_central_coolant_vertical_riser",
        (0.0, 7.4, -3.7),
        (0.0, 7.4, 9.0),
        0.33,
        "mat_coolant_pipe_blue",
        "HC_ARCH_Coolant",
        vertices=12,
    )
    cylinder_between(
        "HC_pipe_central_coolant_main",
        (0.0, 7.4, 9.0),
        (0.0, -1.2, 9.0),
        0.33,
        "mat_coolant_pipe_blue",
        "HC_ARCH_Coolant",
        vertices=12,
    )
    for z_value in (-1.8, 1.0, 4.0, 6.8):
        cylinder(
            f"HC_pipe_central_coolant_riser_clamp_{z_value:+.1f}",
            (0.0, 7.4, z_value),
            0.43,
            0.16,
            "mat_panel_metal",
            "HC_ARCH_Coolant",
            vertices=12,
        )
    cylinder(
        "HC_pipe_central_coolant_rupture_valve",
        (0.0, 7.05, 6.4),
        0.62,
        0.2,
        "mat_warning_yellow_black",
        "HC_ARCH_Coolant",
        vertices=8,
        rotation=(math.radians(90.0), 0.0, 0.0),
    )
    box(
        "HC_pipe_central_coolant_rupture_node",
        (0.0, 7.0, 6.4),
        (1.15, 0.7, 1.15),
        "mat_coolant_pipe_blue",
        "HC_ARCH_Coolant",
        0.06,
    )
    annulus(
        "HC_pipe_coolant_ring_floor_channel",
        (0.0, 0.0, 0.20),
        4.45,
        4.18,
        0.08,
        "mat_coolant_pipe_blue",
        "HC_ARCH_Coolant",
    )

    # ------------------------------------------------------------------
    # Signage planes and legibility accents.
    # ------------------------------------------------------------------
    box(
        "HC_sign_front_holo_cantina_large",
        (0.0, -11.02, 7.55),
        (11.5, 0.24, 2.25),
        "mat_neon_pink",
        "HC_ARCH_SignagePlanes",
        0.12,
    )
    box(
        "HC_sign_front_holo_cantina_inset",
        (0.0, -11.17, 7.55),
        (10.8, 0.08, 1.65),
        "mat_interior_shadow",
        "HC_ARCH_SignagePlanes",
        0.04,
    )
    text_mesh(
        "HC_sign_front_holo_cantina_text",
        "HOLO-CANTINA",
        (0.0, -11.23, 7.8),
        1.0,
        "mat_neon_pink",
    )
    text_mesh(
        "HC_sign_front_neon_grotto_subsign",
        "THE NEON GROTTO",
        (0.0, -11.24, 7.0),
        0.42,
        "mat_neon_blue",
    )
    box(
        "HC_sign_side_vertical_neon",
        (19.35, -4.7, 4.9),
        (0.18, 2.7, 4.5),
        "mat_neon_pink",
        "HC_ARCH_SignagePlanes",
        0.07,
    )
    for index, z_value in enumerate((3.55, 4.85, 6.15)):
        box(
            f"HC_sign_side_vertical_neon_bar_{index:02d}",
            (19.47, -4.7, z_value),
            (0.08, 2.2, 0.16),
            "mat_neon_blue",
            "HC_ARCH_SignagePlanes",
            0.015,
        )
    box(
        "HC_sign_rear_loading_dock_label",
        (5.5, 9.48, 4.45),
        (4.6, 0.12, 0.65),
        "mat_neon_green",
        "HC_ARCH_SignagePlanes",
        0.035,
    )
    for index, x_value in enumerate((-5.0, 0.0, 5.0), start=1):
        box(
            f"HC_sign_vip_label_{index:02d}",
            (x_value, 8.38, 7.35),
            (1.8, 0.1, 0.4),
            "mat_neon_pink" if index != 2 else "mat_neon_blue",
            "HC_ARCH_SignagePlanes",
            0.025,
        )
    box(
        "HC_sign_warning_coolant_line",
        (0.0, 7.0, 5.1),
        (1.7, 0.12, 0.45),
        "mat_warning_yellow_black",
        "HC_ARCH_SignagePlanes",
        0.025,
    )
    annulus(
        "HC_sign_cargo_lift_warning_stripes",
        (6.0, 6.5, -3.68),
        2.05,
        1.6,
        0.06,
        "mat_warning_yellow_black",
        "HC_ARCH_SignagePlanes",
    )

    # Route labels are empties so gameplay integration has stable anchors.
    reference_label("HC_ROUTE_PUBLIC_FRONT_AIRLOCK", (0.0, -12.0, 1.0))
    reference_label("HC_ROUTE_COMBAT_RING_CENTER", (0.0, 0.0, 0.5))
    reference_label("HC_ROUTE_VIP_MEZZANINE", (0.0, 6.0, 5.0))
    reference_label("HC_SYSTEM_COOLANT_RUPTURE", (0.0, 6.8, 6.4))
    reference_label("HC_GAMEPLAY_BAR_CONTACT", (-5.0, 3.0, 1.0))

    # ------------------------------------------------------------------
    # Deliberately simple proxy collision, split around all route openings.
    # ------------------------------------------------------------------
    collision_box("HC_collision_ground_front", (0.0, -2.5, -0.2), (20.0, 11.0, 0.4))
    collision_box("HC_collision_ground_rear_left", (-2.75, 6.0, -0.2), (14.5, 6.0, 0.4))
    collision_box("HC_collision_ground_rear_right", (8.75, 6.0, -0.2), (2.5, 6.0, 0.4))
    collision_box("HC_collision_basement_floor", (0.0, 3.5, -4.2), (20.0, 11.0, 0.4))
    for index, (location, dimensions) in enumerate(
        (
            ((-9.85, 3.5, -2.0), (0.4, 11.0, 4.0)),
            ((9.85, 3.5, -2.0), (0.4, 11.0, 4.0)),
            ((0.0, -1.85, -2.0), (20.0, 0.4, 4.0)),
            ((-3.0, 8.85, -2.0), (14.0, 0.4, 4.0)),
            ((9.0, 8.85, -2.0), (2.0, 0.4, 4.0)),
        ),
        start=1,
    ):
        collision_box(f"HC_collision_basement_wall_{index:02d}", location, dimensions)
    for index, (location, dimensions) in enumerate(
        (
            ((-8.65, 0.0, 4.45), (2.7, 16.0, 0.4)),
            ((0.0, 6.65, 4.45), (17.3, 2.7, 0.4)),
            ((8.65, 0.0, 4.45), (2.7, 16.0, 0.4)),
        ),
        start=1,
    ):
        collision_box(f"HC_collision_mezzanine_{index:02d}", location, dimensions)
    for index, (location, dimensions) in enumerate(
        (
            ((-7.28, -0.3, 5.15), (0.18, 15.4, 1.3)),
            ((0.0, 5.28, 5.15), (14.5, 0.18, 1.3)),
            ((7.28, -0.3, 5.15), (0.18, 15.4, 1.3)),
        ),
        start=1,
    ):
        collision_box(f"HC_collision_mezzanine_railing_{index:02d}", location, dimensions)
    collision_box(
        "HC_collision_mezzanine_stair_walkable_ramp",
        (8.2, 4.56, 2.22),
        (2.1, 6.6, 0.3),
    ).rotation_euler.x = math.radians(37.0)
    for index, (location, dimensions) in enumerate(
        (
            ((-6.75, -9.0, 4.8), (8.5, 0.5, 9.6)),
            ((6.75, -9.0, 4.8), (8.5, 0.5, 9.6)),
            ((0.0, -9.0, 7.2), (5.0, 0.5, 5.2)),
            ((10.85, 0.0, 5.0), (0.5, 18.0, 10.0)),
            ((-10.85, 0.0, 2.35), (0.5, 18.0, 4.7)),
            ((-10.85, -5.5, 7.35), (0.5, 7.0, 5.3)),
            ((-10.85, 5.5, 7.35), (0.5, 7.0, 5.3)),
            ((-3.75, 9.0, 2.25), (14.5, 0.5, 4.5)),
            ((9.25, 9.0, 2.25), (3.5, 0.5, 4.5)),
            ((5.5, 9.0, 4.0), (4.0, 0.5, 1.0)),
            ((-8.5, 9.0, 5.75), (5.0, 0.5, 2.5)),
            ((-2.5, 9.0, 5.75), (3.0, 0.5, 2.5)),
            ((2.5, 9.0, 5.75), (3.0, 0.5, 2.5)),
            ((8.5, 9.0, 5.75), (5.0, 0.5, 2.5)),
            ((0.0, 9.0, 8.5), (22.0, 0.5, 3.0)),
        ),
        start=1,
    ):
        collision_box(f"HC_collision_main_wall_{index:02d}", location, dimensions)
    for index, (location, dimensions) in enumerate(
        (
            # Outer asteroid side masses.
            ((-15.0, 0.0, 4.5), (4.0, 24.0, 16.0)),
            ((15.0, -6.5, 4.5), (4.0, 11.0, 16.0)),
            ((15.0, 7.0, 4.5), (4.0, 10.0, 16.0)),
            ((15.0, 0.0, -3.2), (4.0, 6.0, 2.4)),
            ((15.0, 0.0, 12.0), (4.0, 6.0, 5.0)),
            # Rear asteroid wall split around the loading-dock cut.
            ((-7.0, 12.5, 4.5), (18.0, 4.0, 16.0)),
            ((13.0, 12.5, 4.5), (5.0, 4.0, 16.0)),
            ((5.5, 12.5, 10.0), (9.0, 4.0, 8.0)),
            # Front grotto side masses and overhead arch.
            ((-14.5, -12.0, 4.5), (5.0, 6.0, 16.0)),
            ((14.5, -12.0, 4.5), (5.0, 6.0, 16.0)),
            ((0.0, -12.0, 13.0), (24.0, 6.0, 5.0)),
            # Continuous upper cap.
            ((0.0, 1.0, 14.0), (28.0, 21.0, 3.0)),
        ),
        start=1,
    ):
        collision_box(f"HC_collision_asteroid_shell_{index:02d}", location, dimensions)
    for index, z_value in enumerate((0.65, 2.9, 5.25), start=1):
        collision_box(
            f"HC_collision_scaffold_platform_{index:02d}",
            (18.2, -4.7, z_value),
            (2.5, 3.4, 0.3),
        )

    # Heroic-set-piece expansion. Unparent first so the world-axis scale is
    # applied exactly once to every object and all exported transforms can be
    # baked cleanly.
    for obj in list(bpy.context.scene.objects):
        if obj.parent is None:
            continue
        world_transform = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = world_transform
    for obj in bpy.context.scene.objects:
        obj.location.x *= SCALE_X
        obj.location.y *= SCALE_Y
        obj.location.z *= SCALE_Z
        if obj.type == "MESH":
            obj.scale.x *= SCALE_X
            obj.scale.y *= SCALE_Y
            obj.scale.z *= SCALE_Z

    # Apply mesh transforms while preserving intentionally simple modifiers.
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        obj.select_set(False)

    # Useful scene metadata for import validation.
    scene["asset_name"] = "The Holo-Cantina / The Neon Grotto"
    scene["asset_role"] = "heroic_architecture_shell"
    scene["dimensions_m"] = (51.0, 37.0, 28.0)
    scene["basement_floor_z_m"] = -5.0
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
    print(f"Object count: {len(bpy.context.scene.objects)}")


build()
