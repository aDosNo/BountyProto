extends SceneTree

const ASSET_PATH := "res://assets/blender_models/holo_cantina_arch_shell_v2.glb"
const MAP_PATH := "res://scenes/maps/HesperusMarket_Blockout.tscn"


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load(ASSET_PATH) as PackedScene
	_expect(packed != null, "cantina GLB imports as a PackedScene", failures)
	if packed == null:
		_finish(failures)
		return

	var asset := packed.instantiate()
	root.add_child(asset)
	await process_frame

	for object_name in [
		"HC_floor_ground_main",
		"HC_floor_ground_ring_octagon",
		"HC_floor_mezzanine_left_walkway",
		"HC_floor_mezzanine_rear_walkway",
		"HC_floor_mezzanine_right_walkway",
		"HC_entry_front_airlock_frame_left",
		"HC_entry_stealth_vip_vent_frame_lower",
		"HC_route_stealth_platform_high",
		"HC_entry_rear_loading_dock_frame_left",
		"HC_route_tech_cargo_lift_platform",
		"HC_collision_mezzanine_stair_walkable_ramp",
		"HC_pipe_central_coolant_main",
		"HC_pipe_central_coolant_vertical_riser",
		"HC_shell_asteroid_monolith",
		"HC_shell_rafter_grid_main",
		"HC_sign_front_holo_cantina_large",
		"HC_GAMEPLAY_BAR_CONTACT",
	]:
		_expect(asset.find_child(object_name, true, false) != null,
			"required architecture exists: %s" % object_name, failures)

	var visual_bounds := _mesh_bounds(asset, false)
	_expect(visual_bounds.size.x >= 52.0 and visual_bounds.size.x <= 58.0,
		"outer asteroid substantially encloses the heroic footprint", failures)
	_expect(visual_bounds.position.z <= -4.8,
		"basement reaches the expanded -5m tier", failures)
	_expect(visual_bounds.end.z <= 25.0,
		"outer asteroid stays within the expanded vertical envelope", failures)
	_expect(_count_prefix(asset, "HC_collision_") >= 35,
		"simple collision proxy set is exported", failures)
	var side_vent := asset.find_child(
		"HC_entry_stealth_vip_vent_grate", true, false
	) as Node3D
	var scaffold_platform := asset.find_child(
		"HC_route_stealth_platform_high", true, false
	) as Node3D
	_expect(
		side_vent != null
			and scaffold_platform != null
			and side_vent.position.x >= 26.0
			and scaffold_platform.position.x >= 25.0,
		"stealth vent and scaffold sit on the outer-right asteroid wall",
		failures
	)

	asset.queue_free()
	await process_frame

	var map_packed := load(MAP_PATH) as PackedScene
	_expect(map_packed != null, "Hesperus map loads", failures)
	if map_packed != null:
		var map := map_packed.instantiate()
		root.add_child(map)
		await process_frame
		var cantina := map.get_node_or_null("HoloCantina")
		_expect(cantina != null, "live map instances the Holo-Cantina", failures)
		if cantina != null:
			var public_entry := cantina.find_child(
				"HC_ROUTE_PUBLIC_FRONT_AIRLOCK", true, false
			) as Node3D
			var bar_contact := cantina.find_child(
				"HC_GAMEPLAY_BAR_CONTACT", true, false
			) as Node3D
			var proxy_matches := cantina.find_children(
				"HC_collision_ground_front*", "MeshInstance3D", true, false
			)
			var proxy := (
				proxy_matches[0] as MeshInstance3D
				if not proxy_matches.is_empty()
				else null
			)
			_expect(public_entry != null and public_entry.global_position.z > -63.0,
				"public airlock faces back toward the North Arcade", failures)
			_expect(bar_contact != null,
				"bartender branch has a non-visual anchor inside the cantina", failures)
			_expect(proxy != null and not proxy.visible,
				"collision proxies are hidden after generating physics", failures)
			_expect(
				proxy != null
				and not proxy.find_children("*", "StaticBody3D", true, false).is_empty(),
				"collision proxies generate runtime static bodies",
				failures
			)
		_expect(map.get_node_or_null("Hesperus_AlienBar_InteriorHero") == null,
			"superseded standalone Alien Bar is removed", failures)
		var arcade := map.get_node_or_null("Hesperus_AlienBar_CommercialArcade")
		if arcade != null:
			var hidden: PackedStringArray = arcade.get("hidden_mesh_prefixes")
			_expect(hidden.has("ABA_Bar_BackCounter")
					and hidden.has("ABA_BarSign")
					and hidden.has("ABA_BarAwning"),
				"duplicate arcade bar dressing is hidden", failures)
		map.queue_free()

	_finish(failures)


func _mesh_bounds(node: Node, include_collision: bool) -> AABB:
	var found := false
	var result := AABB()
	for mesh_value in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_value as MeshInstance3D
		if not include_collision and String(mesh.name).begins_with("HC_collision_"):
			continue
		var bounds := mesh.global_transform * mesh.get_aabb()
		if not found:
			result = bounds
			found = true
		else:
			result = result.merge(bounds)
	return result


func _count_prefix(node: Node, prefix: String) -> int:
	var count := 0
	for child in node.find_children("%s*" % prefix, "", true, false):
		if String(child.name).begins_with(prefix):
			count += 1
	return count


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("Holo-Cantina architecture, routes, collision proxies, and live replacement: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("Holo-Cantina test: %s" % failure)
	quit(1)
