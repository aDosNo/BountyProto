extends SceneTree

const SCENE_PATH := "res://levels/hesperus_market/scenes/hesperus_market_graybox.tscn"
const LAYOUT_PATH := "res://levels/hesperus_market/layout/hesperus_market_locked_layout.json"
const EXPECTED_SECTION_COUNT := 7
const EXPECTED_PORT_COUNT := 36


func _initialize() -> void:
	var errors: Array[String] = []
	var packed_scene: PackedScene = load(SCENE_PATH)
	if packed_scene == null:
		_fail(["Could not load scene: %s" % SCENE_PATH])
		return

	var scene_root: Node = packed_scene.instantiate()
	if scene_root == null:
		_fail(["Could not instantiate scene: %s" % SCENE_PATH])
		return

	if scene_root.has_method("build_graybox"):
		scene_root.call("build_graybox")
	else:
		errors.append("Scene root does not expose build_graybox().")

	var layout := _load_layout(errors)
	var sections: Dictionary = layout.get("sections", {})
	var ports: Dictionary = layout.get("ports", {})

	_check_child_count(scene_root, "Sections", EXPECTED_SECTION_COUNT, errors)
	_check_required_named_children(scene_root, "Ports", ports.keys(), errors)
	_check_required_named_children(scene_root, "IdentityMarkers", [
		"S1_ExtractionStartBeacon",
		"S1_LandingPadSilhouette",
		"S2_BountyBoardTerminal",
		"S3_WitnessSpotMarker",
		"S4_CrowdLaneCenter",
		"S5_AwningBridgeBazaar",
		"S6_TargetAreaMarker",
		"S7_DrainageChannel",
	], errors)
	_check_required_named_children(scene_root, "DebugSpawns", [
		"DEBUG_SPAWN_DOCK_START",
		"DEBUG_SPAWN_BOUNTY_HUB",
		"DEBUG_SPAWN_MAIN_BAZAAR",
		"DEBUG_SPAWN_SIDE_ALLEY",
		"DEBUG_SPAWN_UPPER_WALKWAY",
		"DEBUG_SPAWN_CAPTURE_COURTYARD",
		"DEBUG_SPAWN_RETURN_UTILITY",
	], errors)
	_check_required_named_children(scene_root, "Gameplay", ["Player"], errors)
	_check_world_collision(scene_root, errors)

	var labels_root := scene_root.get_node_or_null("DebugLabels")
	if labels_root == null:
		errors.append("Missing DebugLabels root.")
	else:
		var port_label_count := 0
		for label_node: Node in labels_root.get_children():
			if label_node.name.ends_with("_Label") and str(label_node.name).begins_with("S") and "_Landmark_" not in str(label_node.name):
				port_label_count += 1
		if port_label_count < EXPECTED_PORT_COUNT:
			errors.append("Expected at least %d port debug labels, found %d." % [EXPECTED_PORT_COUNT, port_label_count])
		for section_id: String in sections.keys():
			if labels_root.get_node_or_null("%s_Label" % section_id) == null:
				errors.append("Missing section debug label: %s" % section_id)
		for port_id: String in ports.keys():
			if labels_root.get_node_or_null("%s_Label" % port_id) == null:
				errors.append("Missing port debug label: %s" % port_id)
		var expected_landmark_count := 0
		for section_id: String in sections.keys():
			var required_landmarks: Array = sections[section_id].get("required_landmarks", [])
			expected_landmark_count += required_landmarks.size()
		var landmark_label_count := 0
		for label_node: Node in labels_root.get_children():
			if "_Landmark_" in str(label_node.name):
				landmark_label_count += 1
		if landmark_label_count < expected_landmark_count:
			errors.append("Expected at least %d landmark labels, found %d." % [expected_landmark_count, landmark_label_count])

	var section5_floor := scene_root.get_node_or_null("Sections/S5_UPPER_WALKWAY_OVERLAY_Floor")
	if section5_floor == null:
		errors.append("Missing Section 5 floor node.")
	elif abs(_floor_top_y(section5_floor) - 6.0) > 0.01:
		errors.append("Section 5 floor is not visibly elevated at y=6 floor level.")

	var section7_floor := scene_root.get_node_or_null("Sections/S7_RETURN_UTILITY_STRIP_Floor")
	if section7_floor == null:
		errors.append("Missing Section 7 floor node.")
	elif abs(_floor_top_y(section7_floor) - -1.0) > 0.01:
		errors.append("Section 7 floor is not at the lower under-route y=-1 floor level.")

	if errors.is_empty():
		print("Hesperus Market graybox scene check PASSED")
		print("sections=%d" % EXPECTED_SECTION_COUNT)
		print("ports=%d" % EXPECTED_PORT_COUNT)
		print("port_labels_present=true")
		print("section5_elevated=true")
		print("section7_under_route=true")
		print("player_present=true")
		print("world_collision_present=true")
		scene_root.free()
		quit(0)
	else:
		scene_root.free()
		_fail(errors)


func _check_child_count(scene_root: Node, root_name: String, expected_count: int, errors: Array[String]) -> void:
	var root_node := scene_root.get_node_or_null(root_name)
	if root_node == null:
		errors.append("Missing %s root." % root_name)
		return
	var actual_count := root_node.get_child_count()
	if actual_count != expected_count:
		errors.append("Expected %d %s children, found %d." % [expected_count, root_name, actual_count])


func _check_required_named_children(scene_root: Node, root_name: String, expected_names: Array, errors: Array[String]) -> void:
	var root_node := scene_root.get_node_or_null(root_name)
	if root_node == null:
		errors.append("Missing %s root." % root_name)
		return

	for expected_name in expected_names:
		if root_node.get_node_or_null(str(expected_name)) == null:
			errors.append("Missing %s child: %s" % [root_name, str(expected_name)])


func _load_layout(errors: Array[String]) -> Dictionary:
	if not FileAccess.file_exists(LAYOUT_PATH):
		errors.append("Missing layout JSON: %s" % LAYOUT_PATH)
		return {}
	var file := FileAccess.open(LAYOUT_PATH, FileAccess.READ)
	if file == null:
		errors.append("Could not open layout JSON: %s" % LAYOUT_PATH)
		return {}
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("Layout JSON did not parse as a Dictionary.")
		return {}
	return data


func _floor_top_y(floor_node: Node) -> float:
	var collision := floor_node.get_node_or_null("Collision") as CollisionShape3D
	if collision == null or collision.shape == null:
		return float(floor_node.position.y)
	var box := collision.shape as BoxShape3D
	if box == null:
		return float(floor_node.position.y)
	return float(floor_node.position.y) + box.size.y * 0.5


func _check_world_collision(scene_root: Node, errors: Array[String]) -> void:
	var floor_collision_count := _count_collision_shapes(scene_root.get_node_or_null("Sections"))
	var wall_collision_count := _count_collision_shapes(scene_root.get_node_or_null("Walls"))
	var player_collision_count := _count_collision_shapes(scene_root.get_node_or_null("Gameplay/Player"))
	if floor_collision_count < EXPECTED_SECTION_COUNT:
		errors.append("Expected walkable floor collision for all sections, found %d floor collision shapes." % floor_collision_count)
	if wall_collision_count <= 0:
		errors.append("Expected wall collision shapes, found none.")
	if player_collision_count <= 0:
		errors.append("Expected Player collision shape, found none.")


func _count_collision_shapes(root_node: Node) -> int:
	if root_node == null:
		return 0
	var count := 0
	var pending: Array[Node] = [root_node]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is CollisionShape3D:
			count += 1
		for child: Node in node.get_children():
			pending.append(child)
	return count


func _fail(errors: Array[String]) -> void:
	print("Hesperus Market graybox scene check FAILED")
	for error: String in errors:
		print("- %s" % error)
	quit(1)
