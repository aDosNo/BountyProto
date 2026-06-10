extends Node3D

const LAYOUT_PATH := "res://levels/hesperus_market/layout/hesperus_market_locked_layout.json"
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/Player.tscn")
const VK_DOCK_WALL_PANEL: PackedScene = preload("res://levels/hesperus_market/visual_kit/modules/VK_DockWallPanel.tscn")
const VK_FLOOR_PLATE_TRIM: PackedScene = preload("res://levels/hesperus_market/visual_kit/modules/VK_FloorPlateTrim.tscn")
const VK_PORT_DOOR_FRAME: PackedScene = preload("res://levels/hesperus_market/visual_kit/modules/VK_PortDoorFrame.tscn")
const VK_VENT_HATCH_FRAME: PackedScene = preload("res://levels/hesperus_market/visual_kit/modules/VK_VentHatchFrame.tscn")
const VK_CRATE_STACK: PackedScene = preload("res://levels/hesperus_market/visual_kit/modules/VK_CrateStack.tscn")
const VK_HANGING_SIGN_BLOCK: PackedScene = preload("res://levels/hesperus_market/visual_kit/modules/VK_HangingSignBlock.tscn")
const VK_CABLE_BUNDLE: PackedScene = preload("res://levels/hesperus_market/visual_kit/modules/VK_CableBundle.tscn")
const VK_CATWALK_RAILING: PackedScene = preload("res://levels/hesperus_market/visual_kit/modules/VK_CatwalkRailing.tscn")
const VK_PIPE_BUNDLE: PackedScene = preload("res://levels/hesperus_market/visual_kit/modules/VK_PipeBundle.tscn")
const VK_UTILITY_GRATE: PackedScene = preload("res://levels/hesperus_market/visual_kit/modules/VK_UtilityGrate.tscn")
const VK_NEON_ROUTE_STRIP: PackedScene = preload("res://levels/hesperus_market/visual_kit/modules/VK_NeonRouteStrip.tscn")

const FLOOR_THICKNESS := 0.3
const WALL_THICKNESS := 0.45
const WALL_HEIGHT := 3.4
const ROUTE_HEIGHT := 0.12
const ROUTE_WIDTH := 1.35
const PORT_MARKER_SIZE := Vector3(0.8, 0.8, 0.8)
const PORT_THRESHOLD_DEPTH := 1.1
const LANDMARK_MARKER_SIZE := Vector3(1.0, 1.0, 1.0)
const SECTION_LABEL_HEIGHT := 2.35
const PORT_LABEL_HEIGHT := 1.55
const RAIL_HEIGHT := 1.15
const RAIL_THICKNESS := 0.18
const SUPPORT_SIZE := 0.45
const PLAYER_MARKER_HEIGHT := 1.8
const PLAYER_MARKER_RADIUS := 0.35
const EDGE_EPSILON := 0.05

const SECTION_ORDER := [
	"S1_DOCK_BAY",
	"S2_BOUNTY_BOARD_HUB",
	"S3_SIDE_ALLEY",
	"S4_MAIN_BAZAAR_STREET",
	"S5_UPPER_WALKWAY_OVERLAY",
	"S6_CAPTURE_COURTYARD",
	"S7_RETURN_UTILITY_STRIP",
]

const GENERATED_ROOT_NAMES := [
	"Sections",
	"Walls",
	"Ports",
	"Routes",
	"Landmarks",
	"IdentityMarkers",
	"VisualDressing",
	"DebugLabels",
	"DebugSpawns",
	"Gameplay",
]

const ROUTE_COLORS := {
	"green": Color(0.1, 0.95, 0.32, 1.0),
	"yellow": Color(1.0, 0.78, 0.12, 1.0),
	"blue": Color(0.08, 0.45, 1.0, 1.0),
	"purple": Color(0.62, 0.32, 1.0, 1.0),
	"orange": Color(1.0, 0.48, 0.08, 1.0),
	"red": Color(1.0, 0.12, 0.08, 1.0),
}

const DEBUG_MATERIAL_NAMES := {
	"green": "DBG_Route_Return_Green",
	"yellow": "DBG_Route_Bounty_Yellow",
	"blue": "DBG_Route_Investigation_Blue",
	"purple": "DBG_Route_Upper_Purple",
	"orange": "DBG_Route_Utility_Orange",
	"red": "DBG_Route_Target_Red",
	"floor": "DBG_Section_Floor_Neutral",
	"wall": "DBG_Wall_Neutral",
	"landmark": "DBG_Landmark_White",
}

const SECTION_COLORS := {
	"S1_DOCK_BAY": Color(0.16, 0.33, 0.28, 1.0),
	"S2_BOUNTY_BOARD_HUB": Color(0.38, 0.32, 0.13, 1.0),
	"S3_SIDE_ALLEY": Color(0.12, 0.23, 0.4, 1.0),
	"S4_MAIN_BAZAAR_STREET": Color(0.28, 0.24, 0.19, 1.0),
	"S5_UPPER_WALKWAY_OVERLAY": Color(0.26, 0.16, 0.42, 1.0),
	"S6_CAPTURE_COURTYARD": Color(0.42, 0.13, 0.12, 1.0),
	"S7_RETURN_UTILITY_STRIP": Color(0.36, 0.2, 0.08, 1.0),
}

var sections_root: Node3D
var walls_root: Node3D
var ports_root: Node3D
var routes_root: Node3D
var landmarks_root: Node3D
var identity_root: Node3D
var visual_dressing_root: Node3D
var labels_root: Node3D
var debug_spawns_root: Node3D
var gameplay_root: Node3D

var _materials: Dictionary = {}


func _ready() -> void:
	build_graybox()


func build_graybox() -> void:
	_clear_generated_children()
	_create_roots()
	var layout := _load_layout()
	if layout.is_empty():
		push_error("Hesperus Market graybox could not load layout data.")
		return

	var sections: Dictionary = layout.get("sections", {})
	var ports: Dictionary = layout.get("ports", {})

	for section_id: String in SECTION_ORDER:
		if not sections.has(section_id):
			push_error("Missing locked section in layout data: %s" % section_id)
			continue
		var section: Dictionary = sections[section_id]
		_add_section_floor(section_id, section)
		_add_section_walls(section_id, section, ports)
		_add_section_label(section_id, section)
		_add_section_landmarks(section_id, section)

	_add_ports(ports)
	_add_routes(ports)
	_add_upper_walkway_readability(sections, ports)
	_add_under_route_readability(sections)
	_add_landmark_identity_pass(sections, ports)
	_add_route_identity_signs(ports)
	_add_visual_blockout_pass_4b(sections, ports)
	_add_debug_spawns(sections)
	_add_required_vertical_markers(sections, ports)
	_add_playtest_player(sections)


func _clear_generated_children() -> void:
	for child: Node in get_children():
		if child.name in GENERATED_ROOT_NAMES:
			remove_child(child)
			child.free()


func _create_roots() -> void:
	sections_root = _add_root("Sections")
	walls_root = _add_root("Walls")
	ports_root = _add_root("Ports")
	routes_root = _add_root("Routes")
	landmarks_root = _add_root("Landmarks")
	identity_root = _add_root("IdentityMarkers")
	visual_dressing_root = _add_root("VisualDressing")
	labels_root = _add_root("DebugLabels")
	debug_spawns_root = _add_root("DebugSpawns")
	gameplay_root = _add_root("Gameplay")


func _add_root(root_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = root_name
	add_child(root)
	return root


func _load_layout() -> Dictionary:
	if not FileAccess.file_exists(LAYOUT_PATH):
		push_error("Missing layout JSON: %s" % LAYOUT_PATH)
		return {}

	var file := FileAccess.open(LAYOUT_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open layout JSON: %s" % LAYOUT_PATH)
		return {}

	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Layout JSON did not parse to a Dictionary: %s" % LAYOUT_PATH)
		return {}
	return data


func _add_section_floor(section_id: String, section: Dictionary) -> void:
	var bounds: Dictionary = section["bounds"]
	var floor_y := float(section["floor_y"])
	var color: Color = SECTION_COLORS.get(section_id, Color(0.25, 0.25, 0.25, 1.0))
	var mesh_name := "%s_Floor" % section_id
	var center := Vector3(
		float(bounds["x"]) + float(bounds["w"]) * 0.5,
		floor_y - FLOOR_THICKNESS * 0.5,
		float(bounds["z"]) + float(bounds["d"]) * 0.5
	)
	var size := Vector3(float(bounds["w"]), FLOOR_THICKNESS, float(bounds["d"]))
	_add_box(mesh_name, sections_root, center, size, _material(DEBUG_MATERIAL_NAMES["floor"], color))

	if section_id == "S4_MAIN_BAZAAR_STREET":
		_add_lane_readability_stripe(section_id, bounds, floor_y, Color(1.0, 0.78, 0.12, 1.0), 2.4)
	elif section_id == "S3_SIDE_ALLEY":
		_add_lane_readability_stripe(section_id, bounds, floor_y, Color(0.08, 0.45, 1.0, 1.0), 1.0)
	elif section_id == "S2_BOUNTY_BOARD_HUB":
		_add_lane_readability_stripe(section_id, bounds, floor_y, Color(1.0, 0.78, 0.12, 1.0), 1.5)


func _add_section_walls(section_id: String, section: Dictionary, ports: Dictionary) -> void:
	var bounds: Dictionary = section["bounds"]
	var floor_y := float(section["floor_y"])
	var x_min := float(bounds["x"])
	var x_max := x_min + float(bounds["w"])
	var z_min := float(bounds["z"])
	var z_max := z_min + float(bounds["d"])
	var wall_material := _material(DEBUG_MATERIAL_NAMES["wall"], Color(0.09, 0.1, 0.12, 1.0))

	_add_wall_side(section_id, "North", Vector3(x_min, floor_y, z_max), Vector3(x_max, floor_y, z_max), "x", ports, wall_material)
	_add_wall_side(section_id, "South", Vector3(x_min, floor_y, z_min), Vector3(x_max, floor_y, z_min), "x", ports, wall_material)
	_add_wall_side(section_id, "East", Vector3(x_max, floor_y, z_min), Vector3(x_max, floor_y, z_max), "z", ports, wall_material)
	_add_wall_side(section_id, "West", Vector3(x_min, floor_y, z_min), Vector3(x_min, floor_y, z_max), "z", ports, wall_material)


func _add_wall_side(
	section_id: String,
	side_name: String,
	start: Vector3,
	end: Vector3,
	axis: String,
	ports: Dictionary,
	material: Material
) -> void:
	var side_coord := start.z if axis == "x" else start.x
	var range_start := start.x if axis == "x" else start.z
	var range_end := end.x if axis == "x" else end.z
	var openings := _openings_for_side(section_id, axis, side_coord, range_start, range_end, ports)
	var segments := _subtract_openings(range_start, range_end, openings)

	for index: int in segments.size():
		var segment: Vector2 = segments[index]
		var segment_length := segment.y - segment.x
		if segment_length <= 0.01:
			continue

		var center: Vector3
		var size: Vector3
		if axis == "x":
			center = Vector3((segment.x + segment.y) * 0.5, start.y + WALL_HEIGHT * 0.5, side_coord)
			size = Vector3(segment_length, WALL_HEIGHT, WALL_THICKNESS)
		else:
			center = Vector3(side_coord, start.y + WALL_HEIGHT * 0.5, (segment.x + segment.y) * 0.5)
			size = Vector3(WALL_THICKNESS, WALL_HEIGHT, segment_length)

		_add_box("%s_%sWall_%02d" % [section_id, side_name, index + 1], walls_root, center, size, material)


func _openings_for_side(
	section_id: String,
	axis: String,
	side_coord: float,
	range_start: float,
	range_end: float,
	ports: Dictionary
) -> Array[Vector2]:
	var openings: Array[Vector2] = []
	for port_id: String in ports.keys():
		var port: Dictionary = ports[port_id]
		if port.get("section", "") != section_id:
			continue
		var position: Dictionary = port.get("position", {})
		var port_width := float(port.get("width", 0.0))
		var side_distance: float = abs(float(position["z"]) - side_coord) if axis == "x" else abs(float(position["x"]) - side_coord)
		if side_distance > EDGE_EPSILON:
			continue

		var center: float = float(position["x"]) if axis == "x" else float(position["z"])
		var opening := Vector2(center - port_width * 0.5, center + port_width * 0.5)
		opening.x = clamp(opening.x, range_start, range_end)
		opening.y = clamp(opening.y, range_start, range_end)
		if opening.y > opening.x:
			openings.append(opening)

	openings.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return openings


func _subtract_openings(range_start: float, range_end: float, openings: Array[Vector2]) -> Array[Vector2]:
	var segments: Array[Vector2] = []
	var cursor := range_start
	for opening: Vector2 in openings:
		if opening.x > cursor:
			segments.append(Vector2(cursor, opening.x))
		cursor = max(cursor, opening.y)
	if cursor < range_end:
		segments.append(Vector2(cursor, range_end))
	return segments


func _add_section_label(section_id: String, section: Dictionary) -> void:
	var bounds: Dictionary = section["bounds"]
	var center := Vector3(
		float(bounds["x"]) + float(bounds["w"]) * 0.5,
		float(section["floor_y"]) + SECTION_LABEL_HEIGHT,
		float(bounds["z"]) + float(bounds["d"]) * 0.5
	)
	_add_label("%s_Label" % section_id, section_id, center, Color.WHITE, 0.08)


func _add_section_landmarks(section_id: String, section: Dictionary) -> void:
	var landmarks: Array = section.get("required_landmarks", [])
	if landmarks.is_empty():
		return

	var bounds: Dictionary = section["bounds"]
	var floor_y := float(section["floor_y"])
	var count := landmarks.size()
	for index: int in count:
		var x_ratio := float(index + 1) / float(count + 1)
		var z_ratio := 0.34 if index % 2 == 0 else 0.66
		var position := Vector3(
			float(bounds["x"]) + float(bounds["w"]) * x_ratio,
			floor_y + LANDMARK_MARKER_SIZE.y * 0.5,
			float(bounds["z"]) + float(bounds["d"]) * z_ratio
		)
		var landmark_name := "%s_Landmark_%02d_%s" % [section_id, index + 1, _safe_name(str(landmarks[index]))]
		_add_box(landmark_name, landmarks_root, position, LANDMARK_MARKER_SIZE, _material(DEBUG_MATERIAL_NAMES["landmark"], Color(0.95, 0.72, 0.18, 1.0)))
		_add_label("%s_Label" % landmark_name, str(landmarks[index]), position + Vector3(0.0, 1.05, 0.0), Color(1.0, 0.86, 0.28, 1.0), 0.05)


func _add_ports(ports: Dictionary) -> void:
	for port_id: String in ports.keys():
		var port: Dictionary = ports[port_id]
		var color: Color = ROUTE_COLORS.get(port.get("route_color", ""), Color.WHITE)
		var position := _position_from_dict(port["position"]) + Vector3(0.0, 0.45, 0.0)
		_add_visual_box(port_id, ports_root, position, PORT_MARKER_SIZE, _route_material(color))
		_add_port_threshold(port_id, port, color)
		_add_label("%s_Label" % port_id, port_id, position + Vector3(0.0, PORT_LABEL_HEIGHT, 0.0), color, 0.045)


func _add_routes(ports: Dictionary) -> void:
	var created_pairs := {}
	for port_id: String in ports.keys():
		var port: Dictionary = ports[port_id]
		var target_id := str(port["connects_to"])
		var pair_key := _pair_key(port_id, target_id)
		if created_pairs.has(pair_key) or not ports.has(target_id):
			continue
		created_pairs[pair_key] = true

		var start := _position_from_dict(port["position"])
		var end := _position_from_dict(ports[target_id]["position"])
		var color: Color = ROUTE_COLORS.get(port.get("route_color", ""), Color.WHITE)
		_add_route_strip("%s_to_%s" % [port_id, target_id], start, end, color)


func _add_lane_readability_stripe(section_id: String, bounds: Dictionary, floor_y: float, color: Color, stripe_width: float) -> void:
	var center := Vector3(
		float(bounds["x"]) + float(bounds["w"]) * 0.5,
		floor_y + 0.03,
		float(bounds["z"]) + float(bounds["d"]) * 0.5
	)
	var size := Vector3(stripe_width, ROUTE_HEIGHT, max(float(bounds["d"]) - 1.2, 1.0))
	_add_visual_box("%s_ReadabilityStripe" % section_id, routes_root, center, size, _route_material(color))


func _add_port_threshold(port_id: String, port: Dictionary, color: Color) -> void:
	var width := float(port.get("width", 1.0))
	var position := _position_from_dict(port["position"]) + Vector3(0.0, 0.08, 0.0)
	var size := Vector3(width, ROUTE_HEIGHT, PORT_THRESHOLD_DEPTH)

	if "_EAST_" in port_id or "_WEST_" in port_id:
		size = Vector3(PORT_THRESHOLD_DEPTH, ROUTE_HEIGHT, width)
	elif "_NORTH_" in port_id or "_SOUTH_" in port_id:
		size = Vector3(width, ROUTE_HEIGHT, PORT_THRESHOLD_DEPTH)
	elif "_LOWER_" in port_id or "_HATCH_" in port_id or "_GRATE_" in port_id or "_VENT_" in port_id or "_DRAIN_" in port_id:
		size = Vector3(max(width, 1.2), ROUTE_HEIGHT, max(width, 1.2))

	_add_visual_box("%s_Threshold" % port_id, ports_root, position, size, _route_material(color))


func _add_route_strip(route_name: String, start: Vector3, end: Vector3, color: Color) -> void:
	var delta := end - start
	var horizontal := Vector2(delta.x, delta.z)
	var length := horizontal.length()
	if length <= 0.01:
		_add_visual_box(route_name, routes_root, start + Vector3(0.0, 0.08, 0.0), Vector3(1.0, ROUTE_HEIGHT, 1.0), _route_material(color))
		return

	var center := Vector3((start.x + end.x) * 0.5, (start.y + end.y) * 0.5 + 0.12, (start.z + end.z) * 0.5)
	var route := _add_visual_box(route_name, routes_root, center, Vector3(ROUTE_WIDTH, ROUTE_HEIGHT, length), _route_material(color))
	route.rotation.y = atan2(delta.x, delta.z)


func _add_upper_walkway_readability(sections: Dictionary, ports: Dictionary) -> void:
	if not sections.has("S5_UPPER_WALKWAY_OVERLAY"):
		return

	var section: Dictionary = sections["S5_UPPER_WALKWAY_OVERLAY"]
	var bounds: Dictionary = section["bounds"]
	var floor_y := float(section["floor_y"])
	var x_min := float(bounds["x"])
	var x_max := x_min + float(bounds["w"])
	var z_min := float(bounds["z"])
	var z_max := z_min + float(bounds["d"])
	var rail_material := _material("upper_rail", Color(0.5, 0.28, 0.95, 1.0))

	_add_rail_side("S5_UPPER_WALKWAY_OVERLAY", "NorthGuard", Vector3(x_min, floor_y, z_max), Vector3(x_max, floor_y, z_max), "x", ports, rail_material)
	_add_rail_side("S5_UPPER_WALKWAY_OVERLAY", "SouthGuard", Vector3(x_min, floor_y, z_min), Vector3(x_max, floor_y, z_min), "x", ports, rail_material)
	_add_rail_side("S5_UPPER_WALKWAY_OVERLAY", "EastGuard", Vector3(x_max, floor_y, z_min), Vector3(x_max, floor_y, z_max), "z", ports, rail_material)
	_add_rail_side("S5_UPPER_WALKWAY_OVERLAY", "WestGuard", Vector3(x_min, floor_y, z_min), Vector3(x_min, floor_y, z_max), "z", ports, rail_material)

	var support_material := _material("upper_support", Color(0.18, 0.16, 0.24, 1.0))
	var support_x := x_min + 4.0
	while support_x <= x_max - 4.0:
		for support_z: float in [z_min + 2.0, z_max - 2.0]:
			_add_box(
				"S5_UpperSupport_%03d_%03d" % [int(support_x), int(support_z)],
				walls_root,
				Vector3(support_x, floor_y * 0.5, support_z),
				Vector3(SUPPORT_SIZE, floor_y, SUPPORT_SIZE),
				support_material
			)
		support_x += 12.0


func _add_rail_side(
	section_id: String,
	side_name: String,
	start: Vector3,
	end: Vector3,
	axis: String,
	ports: Dictionary,
	material: Material
) -> void:
	var side_coord := start.z if axis == "x" else start.x
	var range_start := start.x if axis == "x" else start.z
	var range_end := end.x if axis == "x" else end.z
	var openings := _openings_for_side(section_id, axis, side_coord, range_start, range_end, ports)
	var segments := _subtract_openings(range_start, range_end, openings)

	for index: int in segments.size():
		var segment: Vector2 = segments[index]
		var segment_length := segment.y - segment.x
		if segment_length <= 0.01:
			continue

		var center: Vector3
		var size: Vector3
		if axis == "x":
			center = Vector3((segment.x + segment.y) * 0.5, start.y + RAIL_HEIGHT * 0.5, side_coord)
			size = Vector3(segment_length, RAIL_HEIGHT, RAIL_THICKNESS)
		else:
			center = Vector3(side_coord, start.y + RAIL_HEIGHT * 0.5, (segment.x + segment.y) * 0.5)
			size = Vector3(RAIL_THICKNESS, RAIL_HEIGHT, segment_length)

		_add_box("%s_%s_%02d" % [section_id, side_name, index + 1], walls_root, center, size, material)


func _add_under_route_readability(sections: Dictionary) -> void:
	if not sections.has("S7_RETURN_UTILITY_STRIP"):
		return

	var section: Dictionary = sections["S7_RETURN_UTILITY_STRIP"]
	var bounds: Dictionary = section["bounds"]
	var floor_y := float(section["floor_y"])
	var x_min := float(bounds["x"])
	var x_max := x_min + float(bounds["w"])
	var z_min := float(bounds["z"])
	var z_max := z_min + float(bounds["d"])
	var frame_material := _material("under_route_frame", Color(0.85, 0.36, 0.08, 1.0))

	var frame_x := x_min + 6.0
	while frame_x <= x_max - 6.0:
		_add_box(
			"S7_UnderRoute_OverheadFrame_%03d" % int(frame_x),
			walls_root,
			Vector3(frame_x, floor_y + 2.25, z_min + float(bounds["d"]) * 0.5),
			Vector3(0.28, 0.28, float(bounds["d"])),
			frame_material
		)
		_add_box(
			"S7_UnderRoute_LeftPost_%03d" % int(frame_x),
			walls_root,
			Vector3(frame_x, floor_y + 1.0, z_min + 0.35),
			Vector3(0.26, 2.0, 0.26),
			frame_material
		)
		_add_box(
			"S7_UnderRoute_RightPost_%03d" % int(frame_x),
			walls_root,
			Vector3(frame_x, floor_y + 1.0, z_max - 0.35),
			Vector3(0.26, 2.0, 0.26),
			frame_material
		)
		frame_x += 10.0


func _add_landmark_identity_pass(sections: Dictionary, ports: Dictionary) -> void:
	if sections.has("S1_DOCK_BAY"):
		_add_s1_dock_identity(sections["S1_DOCK_BAY"], ports)
	if sections.has("S2_BOUNTY_BOARD_HUB"):
		_add_s2_bounty_hub_identity(sections["S2_BOUNTY_BOARD_HUB"], ports)
	if sections.has("S3_SIDE_ALLEY"):
		_add_s3_side_alley_identity(sections["S3_SIDE_ALLEY"], ports)
	if sections.has("S4_MAIN_BAZAAR_STREET"):
		_add_s4_bazaar_identity(sections["S4_MAIN_BAZAAR_STREET"], ports)
	if sections.has("S5_UPPER_WALKWAY_OVERLAY"):
		_add_s5_upper_identity(sections["S5_UPPER_WALKWAY_OVERLAY"], ports)
	if sections.has("S6_CAPTURE_COURTYARD"):
		_add_s6_courtyard_identity(sections["S6_CAPTURE_COURTYARD"], ports)
	if sections.has("S7_RETURN_UTILITY_STRIP"):
		_add_s7_utility_identity(sections["S7_RETURN_UTILITY_STRIP"], ports)


func _add_s1_dock_identity(section: Dictionary, ports: Dictionary) -> void:
	var green := ROUTE_COLORS["green"]
	var purple := ROUTE_COLORS["purple"]
	var orange := ROUTE_COLORS["orange"]
	_add_section_identity_totem("S1_DOCK_BAY", section, "DOCK BAY\nGROUND / UPPER / UTILITY", green)
	_add_identity_box("S1_ExtractionStartBeacon", section, Vector2(0.15, 0.18), Vector3(1.2, 3.0, 1.2), green, "EXTRACTION START")
	_add_identity_box("S1_LandingPadSilhouette", section, Vector2(0.42, 0.45), Vector3(7.0, 0.14, 5.2), Color(0.08, 0.18, 0.2, 1.0), "DOCKED SHIP / LANDING PAD")
	_add_identity_box("S1_LandingPadNose", section, Vector2(0.58, 0.45), Vector3(2.0, 0.65, 2.2), Color(0.12, 0.26, 0.3, 1.0), "")
	_add_identity_box("S1_CustomsRampMarker", section, Vector2(0.28, 0.72), Vector3(4.8, 0.32, 1.2), green, "CUSTOMS RAMP")
	_add_crate_stack("S1_CargoPocket", section, Vector2(0.18, 0.68), green)
	_add_port_cue("S1_CatwalkCue", ports, "S1_NORTH_UPPER_A", purple, "UPPER CATWALK TO S5")
	_add_port_cue("S1_MaintenanceHatchCue", ports, "S1_LOWER_HATCH_A", orange, "UTILITY HATCH TO S7")
	_add_port_cue("S1_ReturnGateCue", ports, "S1_SOUTH_RETURN_A", green, "RETURN GATE")


func _add_s2_bounty_hub_identity(section: Dictionary, ports: Dictionary) -> void:
	var yellow := ROUTE_COLORS["yellow"]
	var blue := ROUTE_COLORS["blue"]
	var purple := ROUTE_COLORS["purple"]
	var orange := ROUTE_COLORS["orange"]
	var green := ROUTE_COLORS["green"]
	_add_section_identity_totem("S2_BOUNTY_BOARD_HUB", section, "BOUNTY HUB\nEARLY DECISION NODE", yellow)
	_add_identity_box("S2_BountyBoardTerminal", section, Vector2(0.5, 0.52), Vector3(4.0, 3.2, 0.8), yellow, "BOUNTY BOARD TERMINAL")
	_add_identity_box("S2_TerminalBase", section, Vector2(0.5, 0.45), Vector3(5.2, 0.6, 2.0), Color(0.22, 0.18, 0.1, 1.0), "")
	_add_identity_box("S2_MissionJunctionCross_NS", section, Vector2(0.5, 0.5), Vector3(1.2, 0.14, 13.0), yellow, "MISSION JUNCTION")
	_add_identity_box("S2_MissionJunctionCross_EW", section, Vector2(0.5, 0.5), Vector3(13.0, 0.14, 1.2), yellow, "")
	_add_port_cue("S2_UpperOfficeAccess", ports, "S2_NORTH_UPPER_A", purple, "UPPER BOUNTY OFFICE")
	_add_port_cue("S2_TerminalUtilityHatch", ports, "S2_LOWER_HATCH_A", orange, "UTILITY HATCH")
	_add_port_cue("S2_DockRouteSign", ports, "S2_WEST_GROUND_A", green, "TO DOCK")
	_add_port_cue("S2_BazaarRouteSign", ports, "S2_EAST_GROUND_A", yellow, "TO MAIN BAZAAR")
	_add_port_cue("S2_AlleyRouteSign", ports, "S2_SOUTH_GROUND_A", blue, "TO SIDE ALLEY")


func _add_s3_side_alley_identity(section: Dictionary, ports: Dictionary) -> void:
	var blue := ROUTE_COLORS["blue"]
	var purple := ROUTE_COLORS["purple"]
	var orange := ROUTE_COLORS["orange"]
	_add_section_identity_totem("S3_SIDE_ALLEY", section, "SIDE ALLEY\nINVESTIGATION ROUTE", blue)
	_add_identity_box("S3_WitnessSpotMarker", section, Vector2(0.24, 0.58), Vector3(1.2, 2.0, 1.2), blue, "WITNESS SPOT")
	_add_identity_box("S3_Clue2Marker", section, Vector2(0.45, 0.42), Vector3(1.0, 1.4, 1.0), blue, "CLUE 2")
	_add_identity_box("S3_NarrowAlleyFrame_Left", section, Vector2(0.18, 0.5), Vector3(0.8, 2.4, 12.0), Color(0.08, 0.12, 0.18, 1.0), "NARROW ALLEY")
	_add_identity_box("S3_NarrowAlleyFrame_Right", section, Vector2(0.82, 0.5), Vector3(0.8, 2.4, 12.0), Color(0.08, 0.12, 0.18, 1.0), "")
	_add_port_cue("S3_BackShopAccess", ports, "S3_EAST_BACKROOM_A", blue, "BACK SHOP ACCESS")
	_add_port_cue("S3_BackrouteToCourtyard", ports, "S3_EAST_BACKROUTE_A", blue, "HIDDEN BACKROUTE")
	_add_port_cue("S3_FireEscapeCue", ports, "S3_UPPER_FIREESCAPE_A", purple, "FIRE ESCAPE")
	_add_port_cue("S3_DrainHatchCue", ports, "S3_SOUTH_DRAIN_A", orange, "DRAIN HATCH")


func _add_s4_bazaar_identity(section: Dictionary, ports: Dictionary) -> void:
	var yellow := ROUTE_COLORS["yellow"]
	var blue := ROUTE_COLORS["blue"]
	var purple := ROUTE_COLORS["purple"]
	var orange := ROUTE_COLORS["orange"]
	var red := ROUTE_COLORS["red"]
	_add_section_identity_totem("S4_MAIN_BAZAAR_STREET", section, "MAIN BAZAAR\nPUBLIC SPINE", yellow)
	_add_identity_box("S4_CrowdLaneCenter", section, Vector2(0.5, 0.5), Vector3(3.2, 0.16, 30.0), yellow, "CENTER CROWD LANE")
	_add_identity_box("S4_VendorLaneWest", section, Vector2(0.24, 0.5), Vector3(1.2, 0.16, 29.0), yellow, "VENDOR LANE")
	_add_identity_box("S4_VendorLaneEast", section, Vector2(0.76, 0.5), Vector3(1.2, 0.16, 29.0), yellow, "")
	_add_identity_box("S4_Clue1Marker", section, Vector2(0.36, 0.36), Vector3(1.1, 1.5, 1.1), blue, "CLUE 1")
	for index: int in 5:
		var z_ratio := 0.2 + float(index) * 0.15
		_add_identity_box("S4_StallBlock_W_%02d" % index, section, Vector2(0.18, z_ratio), Vector3(2.5, 1.4, 2.0), yellow, "STALL BLOCK" if index == 0 else "")
		_add_identity_box("S4_StallBlock_E_%02d" % index, section, Vector2(0.82, z_ratio + 0.06), Vector3(2.5, 1.4, 2.0), yellow, "")
	_add_port_cue("S4_BackroomLaneMarker", ports, "S4_WEST_BACKROOM_A", blue, "BACKROOM LANE")
	_add_port_cue("S4_AwningUpperCue", ports, "S4_NORTH_UPPER_A", purple, "AWNING / UPPER ROUTE")
	_add_port_cue("S4_UtilityVentCue", ports, "S4_SOUTH_VENT_A", orange, "UTILITY VENT")
	_add_port_cue("S4_FrontGateCue", ports, "S4_EAST_GATE_A", red, "FRONT GATE TO TARGET")


func _add_s5_upper_identity(section: Dictionary, ports: Dictionary) -> void:
	var purple := ROUTE_COLORS["purple"]
	_add_section_identity_totem("S5_UPPER_WALKWAY_OVERLAY", section, "UPPER WALKWAY\nELEVATED ROUTE", purple)
	_add_identity_box("S5_AwningBridgeBazaar", section, Vector2(0.58, 0.42), Vector3(12.0, 0.22, 5.0), purple, "AWNING BRIDGE")
	_add_identity_box("S5_ObservationPoint", section, Vector2(0.7, 0.7), Vector3(2.4, 1.0, 2.4), purple, "OBSERVATION POINT")
	for index: int in 6:
		_add_identity_box("S5_HangingCable_%02d" % index, section, Vector2(0.18 + float(index) * 0.13, 0.86), Vector3(0.12, 3.0, 0.12), Color(0.25, 0.2, 0.35, 1.0), "HANGING CABLES" if index == 0 else "")
	_add_port_cue("S5_DockCatwalkConnector", ports, "S5_WEST_UPPER_A", purple, "DOCK CATWALK")
	_add_port_cue("S5_BountyOfficeConnector", ports, "S5_BOUNTY_UPPER_A", purple, "UPPER BOUNTY OFFICE")
	_add_port_cue("S5_FireEscapeConnector", ports, "S5_SIDE_FIREESCAPE_A", purple, "SIDE ALLEY FIRE ESCAPE")
	_add_port_cue("S5_BazaarAwningConnector", ports, "S5_BAZAAR_AWNING_A", purple, "BAZAAR AWNING")
	_add_port_cue("S5_EastBalconyConnector", ports, "S5_EAST_BALCONY_A", purple, "EAST BALCONY")


func _add_s6_courtyard_identity(section: Dictionary, ports: Dictionary) -> void:
	var red := ROUTE_COLORS["red"]
	var blue := ROUTE_COLORS["blue"]
	var purple := ROUTE_COLORS["purple"]
	var orange := ROUTE_COLORS["orange"]
	var green := ROUTE_COLORS["green"]
	_add_section_identity_totem("S6_CAPTURE_COURTYARD", section, "CAPTURE COURTYARD\nMULTI-ENTRY ARENA", red)
	_add_identity_box("S6_TargetAreaMarker", section, Vector2(0.5, 0.56), Vector3(2.0, 2.2, 2.0), red, "TARGET AREA")
	_add_identity_box("S6_CaptureRing_NS", section, Vector2(0.5, 0.56), Vector3(0.5, 0.16, 9.0), red, "CAPTURE ZONE")
	_add_identity_box("S6_CaptureRing_EW", section, Vector2(0.5, 0.56), Vector3(9.0, 0.16, 0.5), red, "")
	for index: int in 6:
		var x_ratio := 0.2 + float(index % 3) * 0.3
		var z_ratio := 0.26 if index < 3 else 0.78
		_add_identity_box("S6_ArenaCover_%02d" % index, section, Vector2(x_ratio, z_ratio), Vector3(2.0, 1.2, 1.2), Color(0.18, 0.12, 0.1, 1.0), "ARENA COVER" if index == 0 else "")
	_add_port_cue("S6_FrontGateEntry", ports, "S6_WEST_FRONTGATE_A", red, "FRONT GATE ENTRY")
	_add_port_cue("S6_BackDoorEntry", ports, "S6_WEST_BACKDOOR_A", blue, "BACK DOOR ENTRY")
	_add_port_cue("S6_BalconyEntry", ports, "S6_NORTH_BALCONY_A", purple, "BALCONY ENTRY")
	_add_port_cue("S6_LowerGrateAccess", ports, "S6_LOWER_GRATE_A", orange, "LOWER GRATE")
	_add_port_cue("S6_ReturnShortcut", ports, "S6_SOUTH_RETURN_A", green, "RETURN SHORTCUT")


func _add_s7_utility_identity(section: Dictionary, ports: Dictionary) -> void:
	var orange := ROUTE_COLORS["orange"]
	var green := ROUTE_COLORS["green"]
	_add_section_identity_totem("S7_RETURN_UTILITY_STRIP", section, "RETURN UTILITY STRIP\nLOWER UNDER-ROUTE", orange)
	_add_identity_box("S7_DrainageChannel", section, Vector2(0.5, 0.5), Vector3(98.0, 0.14, 1.2), orange, "DRAINAGE CHANNEL")
	_add_identity_box("S7_ReturnCorridorStripe", section, Vector2(0.5, 0.74), Vector3(98.0, 0.14, 1.0), green, "RETURN CORRIDOR")
	for index: int in 8:
		_add_identity_box("S7_VentShaft_%02d" % index, section, Vector2(0.12 + float(index) * 0.11, 0.28), Vector3(1.4, 1.2, 1.0), orange, "VENT SHAFTS" if index == 0 else "")
	_add_port_cue("S7_WestReturnToDock", ports, "S7_WEST_RETURN_A", green, "WEST RETURN TO DOCK")
	_add_port_cue("S7_WestServiceHatch", ports, "S7_WEST_UTILITY_A", orange, "SERVICE HATCH")
	_add_port_cue("S7_BountyServiceHatch", ports, "S7_BOUNTY_UTILITY_A", orange, "BOUNTY SERVICE HATCH")
	_add_port_cue("S7_AlleyDrain", ports, "S7_ALLEY_DRAIN_A", orange, "ALLEY DRAIN")
	_add_port_cue("S7_BazaarVent", ports, "S7_BAZAAR_UTILITY_A", orange, "BAZAAR VENT")
	_add_port_cue("S7_EastReturnFromCourt", ports, "S7_COURT_RETURN_A", green, "EAST RETURN FROM COURT")
	_add_port_cue("S7_CourtUtility", ports, "S7_COURT_UTILITY_A", orange, "COURT UTILITY GRATE")


func _add_route_identity_signs(ports: Dictionary) -> void:
	_add_route_arrow_between_ports("RouteSign_DockToBountyHub", ports, "S1_EAST_GROUND_A", "S2_WEST_GROUND_A", "DOCK -> BOUNTY HUB")
	_add_route_arrow_between_ports("RouteSign_BountyHubToBazaar", ports, "S2_EAST_GROUND_A", "S4_WEST_GROUND_A", "BOUNTY HUB -> MAIN BAZAAR")
	_add_route_arrow_between_ports("RouteSign_BountyHubToSideAlley", ports, "S2_SOUTH_GROUND_A", "S3_NORTH_GROUND_A", "BOUNTY HUB -> SIDE ALLEY")
	_add_route_arrow_between_ports("RouteSign_SideAlleyToBackrooms", ports, "S3_EAST_BACKROOM_A", "S4_WEST_BACKROOM_A", "SIDE ALLEY -> BACKROOMS")
	_add_route_arrow_between_ports("RouteSign_BazaarToCourtyard", ports, "S4_EAST_GATE_A", "S6_WEST_FRONTGATE_A", "MAIN BAZAAR -> CAPTURE COURTYARD")
	_add_route_arrow_between_ports("RouteSign_BazaarToUtilityVent", ports, "S4_SOUTH_VENT_A", "S7_BAZAAR_UTILITY_A", "MAIN BAZAAR -> UTILITY VENT")
	_add_route_arrow_between_ports("RouteSign_UpperToBalcony", ports, "S5_EAST_BALCONY_A", "S6_NORTH_BALCONY_A", "UPPER WALKWAY -> COURTYARD BALCONY")
	_add_route_arrow_between_ports("RouteSign_CourtyardToReturn", ports, "S6_SOUTH_RETURN_A", "S7_COURT_RETURN_A", "CAPTURE COURTYARD -> RETURN")
	_add_route_arrow_between_ports("RouteSign_UtilityToDockReturn", ports, "S7_WEST_RETURN_A", "S1_SOUTH_RETURN_A", "UTILITY STRIP -> DOCK RETURN")


func _add_section_identity_totem(section_id: String, section: Dictionary, label_text: String, color: Color) -> void:
	var bounds: Dictionary = section["bounds"]
	var position := Vector3(
		float(bounds["x"]) + 1.8,
		float(section["floor_y"]) + 1.6,
		float(bounds["z"]) + float(bounds["d"]) - 1.8
	)
	_add_box("%s_IdentityTotem" % section_id, identity_root, position, Vector3(0.8, 3.2, 0.8), _material("identity_%s" % section_id, color))
	_add_label("%s_IdentityTotem_Label" % section_id, label_text, position + Vector3(0.0, 2.1, 0.0), color, 0.055)


func _add_identity_box(node_name: String, section: Dictionary, ratio: Vector2, size: Vector3, color: Color, label_text: String) -> StaticBody3D:
	var position := _section_position(section, ratio, size.y * 0.5)
	var body := _add_box(node_name, identity_root, position, size, _material("identity_%s" % node_name, color))
	if not label_text.is_empty():
		_add_label("%s_Label" % node_name, label_text, position + Vector3(0.0, size.y * 0.5 + 0.45, 0.0), color, 0.04)
	return body


func _add_crate_stack(node_prefix: String, section: Dictionary, ratio: Vector2, color: Color) -> void:
	var base_position := _section_position(section, ratio, 0.0)
	var sizes := [
		Vector3(1.2, 1.0, 1.2),
		Vector3(1.0, 0.8, 1.0),
		Vector3(0.9, 0.9, 1.1),
	]
	for index: int in sizes.size():
		var size: Vector3 = sizes[index]
		var offset := Vector3(float(index % 2) * 1.05, size.y * 0.5 + float(index / 2) * 0.85, float(index) * 0.35)
		_add_box("%s_Crate_%02d" % [node_prefix, index + 1], identity_root, base_position + offset, size, _material("identity_crate_stack", color))
	_add_label("%s_Label" % node_prefix, "CARGO / CRATE POCKET", base_position + Vector3(0.5, 2.2, 0.5), color, 0.04)


func _add_port_cue(node_name: String, ports: Dictionary, port_id: String, color: Color, label_text: String) -> void:
	if not ports.has(port_id):
		return
	var port: Dictionary = ports[port_id]
	var position := _position_from_dict(port["position"])
	var arch_height := 2.2
	var width: float = max(float(port.get("width", 1.0)), 1.2)
	var top_size := Vector3(width, 0.25, 0.35)
	var side_size := Vector3(0.25, arch_height, 0.35)
	if "_EAST_" in port_id or "_WEST_" in port_id:
		top_size = Vector3(0.35, 0.25, width)
		side_size = Vector3(0.35, arch_height, 0.25)
		_add_visual_box("%s_PostA" % node_name, identity_root, position + Vector3(0.0, arch_height * 0.5, -width * 0.5), side_size, _route_material(color))
		_add_visual_box("%s_PostB" % node_name, identity_root, position + Vector3(0.0, arch_height * 0.5, width * 0.5), side_size, _route_material(color))
	else:
		_add_visual_box("%s_PostA" % node_name, identity_root, position + Vector3(-width * 0.5, arch_height * 0.5, 0.0), side_size, _route_material(color))
		_add_visual_box("%s_PostB" % node_name, identity_root, position + Vector3(width * 0.5, arch_height * 0.5, 0.0), side_size, _route_material(color))
	_add_visual_box("%s_Header" % node_name, identity_root, position + Vector3(0.0, arch_height + 0.15, 0.0), top_size, _route_material(color))
	_add_label("%s_Label" % node_name, label_text, position + Vector3(0.0, arch_height + 0.75, 0.0), color, 0.04)


func _add_route_arrow_between_ports(node_name: String, ports: Dictionary, from_port_id: String, to_port_id: String, label_text: String) -> void:
	if not ports.has(from_port_id) or not ports.has(to_port_id):
		return
	var from_port: Dictionary = ports[from_port_id]
	var to_port: Dictionary = ports[to_port_id]
	var color: Color = ROUTE_COLORS.get(from_port.get("route_color", ""), Color.WHITE)
	var start := _position_from_dict(from_port["position"]) + Vector3(0.0, 0.32, 0.0)
	var end := _position_from_dict(to_port["position"]) + Vector3(0.0, 0.32, 0.0)
	var delta := end - start
	var horizontal := Vector2(delta.x, delta.z)
	var length: float = max(horizontal.length(), 0.8)
	var midpoint := start.lerp(end, 0.5)
	var shaft := _add_visual_box("%s_ArrowShaft" % node_name, identity_root, midpoint, Vector3(0.5, 0.16, length), _route_material(color))
	shaft.rotation.y = atan2(delta.x, delta.z)
	var head := _add_visual_box("%s_ArrowHead" % node_name, identity_root, end, Vector3(1.2, 0.22, 1.2), _route_material(color))
	head.rotation.y = atan2(delta.x, delta.z)
	_add_label("%s_Label" % node_name, label_text, midpoint + Vector3(0.0, 1.1, 0.0), color, 0.04)


func _section_position(section: Dictionary, ratio: Vector2, y_offset: float) -> Vector3:
	var bounds: Dictionary = section["bounds"]
	return Vector3(
		float(bounds["x"]) + float(bounds["w"]) * ratio.x,
		float(section["floor_y"]) + y_offset,
		float(bounds["z"]) + float(bounds["d"]) * ratio.y
	)


func _add_visual_blockout_pass_4b(sections: Dictionary, ports: Dictionary) -> void:
	if not sections.has("S1_DOCK_BAY"):
		return
	_add_s1_dock_bay_visual_blockout(sections["S1_DOCK_BAY"], ports)


func _add_s1_dock_bay_visual_blockout(section: Dictionary, ports: Dictionary) -> void:
	var green: Color = ROUTE_COLORS["green"]
	var purple: Color = ROUTE_COLORS["purple"]
	var orange: Color = ROUTE_COLORS["orange"]
	var dock_metal := _material("visual_s1_dock_metal", Color(0.12, 0.22, 0.25, 1.0))
	var dark_trim := _material("visual_s1_dark_trim", Color(0.035, 0.04, 0.045, 1.0))

	_add_s1_dock_wall_panels(section)
	_add_s1_port_visual_frame(ports, "S1_EAST_GROUND_A", "S1_PortFrame_ToBountyHub", green, "TO BOUNTY BOARD HUB")
	_add_s1_port_visual_frame(ports, "S1_NORTH_UPPER_A", "S1_PortFrame_ToUpperWalkway", purple, "TO UPPER WALKWAY")
	_add_s1_port_visual_frame(ports, "S1_SOUTH_RETURN_A", "S1_PortFrame_ReturnGate", green, "EXTRACTION RETURN")
	_add_s1_port_visual_frame(ports, "S1_LOWER_HATCH_A", "S1_PortFrame_UtilityHatch", orange, "UTILITY / RETURN HATCH")

	for trim_index: int in 3:
		var trim_position := _section_position(section, Vector2(0.28 + float(trim_index) * 0.2, 0.42), 0.08)
		_instance_visual_module(VK_FLOOR_PLATE_TRIM, "S1_LandingPadTrim_%02d" % [trim_index + 1], trim_position, 0.0, Vector3.ONE, false)

	_add_visual_box("S1_DockedShip_HullSilhouette", visual_dressing_root, _section_position(section, Vector2(0.43, 0.43), 0.72), Vector3(7.6, 1.15, 4.8), dock_metal)
	_add_visual_box("S1_DockedShip_NoseSilhouette", visual_dressing_root, _section_position(section, Vector2(0.62, 0.43), 0.55), Vector3(2.4, 0.9, 2.2), dock_metal)
	_add_visual_box("S1_DockedShip_DarkKeel", visual_dressing_root, _section_position(section, Vector2(0.43, 0.43), 0.18), Vector3(8.4, 0.28, 5.5), dark_trim)
	_add_label("S1_DockedShip_Label", "DOCKED SHIP / LANDING PAD SILHOUETTE", _section_position(section, Vector2(0.43, 0.43), 1.75), green, 0.04)

	_add_visual_box("S1_CustomsRamp_Blockout", visual_dressing_root, _section_position(section, Vector2(0.68, 0.70), 0.16), Vector3(5.2, 0.32, 1.45), _route_material(green))
	_add_box("S1_CustomsBooth_Blockout", visual_dressing_root, _section_position(section, Vector2(0.80, 0.78), 1.25), Vector3(2.2, 2.5, 2.2), dock_metal)
	_add_label("S1_CustomsBooth_Label", "CUSTOMS BOOTH / RAMP", _section_position(section, Vector2(0.78, 0.75), 2.95), green, 0.04)

	for crate_index: int in 4:
		var crate_position := _section_position(section, Vector2(0.16 + float(crate_index % 2) * 0.1, 0.66 + float(crate_index / 2) * 0.08), 0.0)
		_instance_visual_module(VK_CRATE_STACK, "S1_VisualCargoCrateStack_%02d" % [crate_index + 1], crate_position, deg_to_rad(90.0 * float(crate_index % 2)), Vector3.ONE, true)
	_add_label("S1_VisualCargoPocket_Label", "CARGO / CRATE POCKET", _section_position(section, Vector2(0.22, 0.76), 2.4), green, 0.04)

	_add_visual_box("S1_ExtractionStart_FloorBeacon", visual_dressing_root, _section_position(section, Vector2(0.17, 0.32), 0.08), Vector3(2.6, 0.16, 2.6), _route_material(green))
	_add_visual_box("S1_ExtractionStart_VerticalBeacon", visual_dressing_root, _section_position(section, Vector2(0.17, 0.32), 2.2), Vector3(0.45, 4.4, 0.45), _route_material(green))
	_add_label("S1_ExtractionStart_VisualLabel", "EXTRACTION START", _section_position(section, Vector2(0.17, 0.32), 4.75), green, 0.05)

	_add_visual_box("S1_UpperCatwalkCue_Deck", visual_dressing_root, _section_position(section, Vector2(0.55, 0.91), 5.98), Vector3(7.4, 0.24, 3.0), dock_metal)
	_instance_visual_module(VK_CATWALK_RAILING, "S1_UpperCatwalkCue_RailingA", _section_position(section, Vector2(0.43, 0.86), 6.12), 0.0, Vector3.ONE, true)
	_instance_visual_module(VK_CATWALK_RAILING, "S1_UpperCatwalkCue_RailingB", _section_position(section, Vector2(0.66, 0.86), 6.12), 0.0, Vector3.ONE, true)
	for support_index: int in 3:
		var support_x_ratio := 0.42 + float(support_index) * 0.11
		_add_box("S1_UpperCatwalkCue_Support_%02d" % [support_index + 1], visual_dressing_root, _section_position(section, Vector2(support_x_ratio, 0.86), 3.0), Vector3(0.24, 6.0, 0.24), dark_trim)
	_add_label("S1_UpperCatwalkCue_Label", "VISIBLE UPPER CATWALK CUE TO S5", _section_position(section, Vector2(0.55, 0.86), 7.55), purple, 0.04)

	_instance_visual_module(VK_UTILITY_GRATE, "S1_MaintenanceHatch_UtilityGrate", Vector3(6.0, -0.92, 24.8), 0.0, Vector3.ONE, false)
	_instance_visual_module(VK_PIPE_BUNDLE, "S1_MaintenanceHatch_PipeBundle", Vector3(3.4, 0.55, 26.0), deg_to_rad(90.0), Vector3.ONE, false)
	_instance_visual_module(VK_CABLE_BUNDLE, "S1_MaintenanceHatch_CableBundle", Vector3(5.8, 1.5, 25.1), deg_to_rad(90.0), Vector3.ONE, false)
	_add_label("S1_MaintenanceHatch_VisualLabel", "MAINTENANCE HATCH CUE TO S7", Vector3(6.0, 1.45, 25.0), orange, 0.04)

	_add_dressing_route_strip("S1_GroundRoute_ToBountyHub", _section_position(section, Vector2(0.2, 0.36), 0.14), Vector3(22.0, 0.14, 43.0), green, 0.62, "GROUND PATH TO BOUNTY HUB")
	_add_dressing_route_strip("S1_UpperRoute_Cue", _section_position(section, Vector2(0.26, 0.42), 0.2), Vector3(12.0, 0.2, 56.2), purple, 0.48, "UPPER ROUTE")
	_add_dressing_route_strip("S1_UtilityRoute_Cue", _section_position(section, Vector2(0.2, 0.36), 0.18), Vector3(6.0, 0.18, 24.8), orange, 0.42, "UTILITY / RETURN")
	_add_dressing_route_strip("S1_ReturnRoute_Cue", _section_position(section, Vector2(0.2, 0.36), 0.16), Vector3(10.0, 0.16, 24.6), green, 0.42, "EXTRACTION RETURN")

	_add_s1_direction_sign("S1_Sign_ToBountyBoardHub", Vector3(18.8, 2.8, 43.0), deg_to_rad(90.0), "TO BOUNTY BOARD HUB", green)
	_add_s1_direction_sign("S1_Sign_ToUpperWalkway", Vector3(12.0, 3.5, 54.2), 0.0, "TO UPPER WALKWAY", purple)
	_add_s1_direction_sign("S1_Sign_ToUtilityReturn", Vector3(5.9, 2.0, 27.2), 0.0, "TO UTILITY / RETURN", orange)
	_add_s1_direction_sign("S1_Sign_ToExtractionReturn", Vector3(10.2, 2.2, 27.0), 0.0, "TO EXTRACTION RETURN", green)


func _add_s1_dock_wall_panels(section: Dictionary) -> void:
	var bounds: Dictionary = section["bounds"]
	var x_min := float(bounds["x"])
	var x_max := x_min + float(bounds["w"])
	var z_min := float(bounds["z"])
	var z_max := z_min + float(bounds["d"])
	var floor_y := float(section["floor_y"])

	for panel_z: float in [29.5, 36.5, 49.5, 54.0]:
		_instance_visual_module(VK_DOCK_WALL_PANEL, "S1_DockWallPanel_West_%03d" % int(panel_z), Vector3(x_min - 0.28, floor_y, panel_z), deg_to_rad(90.0), Vector3.ONE, false)
	for panel_x: float in [3.5, 17.5]:
		_instance_visual_module(VK_DOCK_WALL_PANEL, "S1_DockWallPanel_North_%03d" % int(panel_x), Vector3(panel_x, floor_y, z_max + 0.28), 0.0, Vector3.ONE, false)
	for panel_x: float in [2.2, 15.8, 19.5]:
		_instance_visual_module(VK_DOCK_WALL_PANEL, "S1_DockWallPanel_South_%03d" % int(panel_x), Vector3(panel_x, floor_y, z_min - 0.28), 0.0, Vector3.ONE, false)
	_instance_visual_module(VK_DOCK_WALL_PANEL, "S1_DockWallPanel_East_NorthOfPort", Vector3(x_max + 0.28, floor_y, 51.5), deg_to_rad(90.0), Vector3.ONE, false)
	_instance_visual_module(VK_DOCK_WALL_PANEL, "S1_DockWallPanel_East_SouthOfPort", Vector3(x_max + 0.28, floor_y, 33.5), deg_to_rad(90.0), Vector3.ONE, false)


func _add_s1_port_visual_frame(ports: Dictionary, port_id: String, node_name: String, color: Color, label_text: String) -> void:
	if not ports.has(port_id):
		return
	var port: Dictionary = ports[port_id]
	var position := _position_from_dict(port["position"])
	var rotation_y := 0.0
	if "_EAST_" in port_id or "_WEST_" in port_id:
		rotation_y = deg_to_rad(90.0)
	if port_id == "S1_LOWER_HATCH_A":
		_instance_visual_module(VK_VENT_HATCH_FRAME, "%s_VentFrame" % node_name, position + Vector3(0.0, 0.05, 0.65), 0.0, Vector3.ONE, false)
		_instance_visual_module(VK_UTILITY_GRATE, "%s_Grate" % node_name, position + Vector3(0.0, 0.05, 0.65), 0.0, Vector3.ONE, false)
	else:
		_instance_visual_module(VK_PORT_DOOR_FRAME, node_name, position, rotation_y, Vector3.ONE, false)
	_add_label("%s_Label" % node_name, label_text, position + Vector3(0.0, 3.6, 0.0), color, 0.04)


func _add_s1_direction_sign(node_name: String, position: Vector3, rotation_y: float, label_text: String, color: Color) -> void:
	_instance_visual_module(VK_HANGING_SIGN_BLOCK, node_name, position, rotation_y, Vector3.ONE, false)
	_add_label("%s_Label" % node_name, label_text, position + Vector3(0.0, 0.72, 0.0), color, 0.04)


func _add_dressing_route_strip(node_name: String, start: Vector3, end: Vector3, color: Color, width: float, label_text: String) -> void:
	var delta := end - start
	var horizontal := Vector2(delta.x, delta.z)
	var length: float = max(horizontal.length(), 0.8)
	var midpoint := start.lerp(end, 0.5)
	var strip := _add_visual_box("%s_GuideStrip" % node_name, visual_dressing_root, midpoint, Vector3(width, 0.12, length), _route_material(color))
	strip.rotation.y = atan2(delta.x, delta.z)
	_instance_visual_module(VK_NEON_ROUTE_STRIP, "%s_NeonModule" % node_name, midpoint + Vector3(0.0, 0.07, 0.0), atan2(delta.x, delta.z), Vector3.ONE, false)
	_add_label("%s_Label" % node_name, label_text, midpoint + Vector3(0.0, 0.85, 0.0), color, 0.035)


func _instance_visual_module(
	module_scene: PackedScene,
	node_name: String,
	position: Vector3,
	rotation_y: float,
	scale: Vector3,
	collision_enabled: bool
) -> Node3D:
	var instantiated_node := module_scene.instantiate()
	if not instantiated_node is Node3D:
		instantiated_node.free()
		push_error("Visual kit module did not instantiate as Node3D: %s" % node_name)
		return null

	var node_3d := instantiated_node as Node3D
	node_3d.name = node_name
	node_3d.position = position
	node_3d.rotation.y = rotation_y
	node_3d.scale = scale
	visual_dressing_root.add_child(node_3d)
	if not collision_enabled:
		_set_collision_enabled_recursive(node_3d, false)
	return node_3d


func _set_collision_enabled_recursive(node: Node, enabled: bool) -> void:
	if node is CollisionShape3D:
		var collision_shape := node as CollisionShape3D
		collision_shape.disabled = not enabled
	if node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		collision_object.collision_layer = 1 if enabled else 0
		collision_object.collision_mask = 1 if enabled else 0
	for child: Node in node.get_children():
		_set_collision_enabled_recursive(child, enabled)


func _add_debug_spawns(sections: Dictionary) -> void:
	var spawn_specs := {
		"DEBUG_SPAWN_DOCK_START": ["S1_DOCK_BAY", Vector2(0.18, 0.35)],
		"DEBUG_SPAWN_BOUNTY_HUB": ["S2_BOUNTY_BOARD_HUB", Vector2(0.5, 0.5)],
		"DEBUG_SPAWN_MAIN_BAZAAR": ["S4_MAIN_BAZAAR_STREET", Vector2(0.5, 0.56)],
		"DEBUG_SPAWN_SIDE_ALLEY": ["S3_SIDE_ALLEY", Vector2(0.35, 0.5)],
		"DEBUG_SPAWN_UPPER_WALKWAY": ["S5_UPPER_WALKWAY_OVERLAY", Vector2(0.5, 0.5)],
		"DEBUG_SPAWN_CAPTURE_COURTYARD": ["S6_CAPTURE_COURTYARD", Vector2(0.5, 0.5)],
		"DEBUG_SPAWN_RETURN_UTILITY": ["S7_RETURN_UTILITY_STRIP", Vector2(0.5, 0.5)],
	}

	for spawn_name: String in spawn_specs.keys():
		var spec: Array = spawn_specs[spawn_name]
		var section_id := str(spec[0])
		if not sections.has(section_id):
			continue
		var bounds: Dictionary = sections[section_id]["bounds"]
		var ratio: Vector2 = spec[1]
		var floor_y := float(sections[section_id]["floor_y"])
		var position := Vector3(
			float(bounds["x"]) + float(bounds["w"]) * ratio.x,
			floor_y + PLAYER_MARKER_HEIGHT * 0.5,
			float(bounds["z"]) + float(bounds["d"]) * ratio.y
		)
		_add_debug_spawn_marker(spawn_name, position, Vector3(PLAYER_MARKER_RADIUS * 2.0, PLAYER_MARKER_HEIGHT, PLAYER_MARKER_RADIUS * 2.0))
		_add_label("%s_Label" % spawn_name, spawn_name, position + Vector3(0.0, 1.15, 0.0), Color(0.2, 0.95, 1.0, 1.0), 0.045)


func _add_debug_spawn_marker(marker_name: String, position: Vector3, size: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = position
	debug_spawns_root.add_child(marker)

	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material("debug_spawn", Color(0.04, 0.9, 1.0, 0.45))

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Preview"
	mesh_instance.mesh = mesh
	marker.add_child(mesh_instance)
	return marker


func _add_playtest_player(sections: Dictionary) -> void:
	if not sections.has("S1_DOCK_BAY"):
		push_error("Cannot add playtest player: missing S1_DOCK_BAY.")
		return

	var player := PLAYER_SCENE.instantiate()
	player.name = "Player"
	var dock_section: Dictionary = sections["S1_DOCK_BAY"]
	var spawn_position := _section_position(dock_section, Vector2(0.18, 0.35), 0.08)
	player.position = spawn_position
	player.rotation.y = deg_to_rad(90.0)
	gameplay_root.add_child(player)


func _add_required_vertical_markers(sections: Dictionary, ports: Dictionary) -> void:
	for port_id: String in ports.keys():
		var upper_port_name: bool = "UPPER" in port_id or "FIREESCAPE" in port_id or "BALCONY" in port_id or "AWNING" in port_id
		var utility_port_name: bool = "LOWER" in port_id or "HATCH" in port_id or "GRATE" in port_id or "VENT" in port_id or "DRAIN" in port_id
		if not upper_port_name and not utility_port_name:
			continue

		var port: Dictionary = ports[port_id]
		var position := _position_from_dict(port["position"])
		var marker_height: float = 1.8 if utility_port_name else 2.4
		var color: Color = ROUTE_COLORS.get(port.get("route_color", ""), Color.WHITE)
		var marker_name := "%s_VerticalMarker" % port_id
		_add_box(
			marker_name,
			landmarks_root,
			position + Vector3(0.0, marker_height * 0.5, 0.0),
			Vector3(0.28, marker_height, 0.28),
			_material("vertical_%s" % port.get("route_color", "white"), color)
		)
		var label_text := "PLACEHOLDER LADDER / HATCH ACCESS" if utility_port_name else "PLACEHOLDER UPPER ACCESS"
		_add_label("%s_Label" % marker_name, label_text, position + Vector3(0.0, marker_height + 0.4, 0.0), color, 0.035)

	for section_id: String in sections.keys():
		var section: Dictionary = sections[section_id]
		var landmarks: Array = section.get("required_landmarks", [])
		for landmark in landmarks:
			var text := str(landmark).to_lower()
			if "ramp" not in text and "fire escape" not in text and "catwalk" not in text:
				continue
			var bounds: Dictionary = section["bounds"]
			var base := Vector3(float(bounds["x"]) + 1.2, float(section["floor_y"]) + 0.25, float(bounds["z"]) + 1.2)
			_add_box(
				"%s_%s_DebugVerticalAccess" % [section_id, _safe_name(str(landmark))],
				landmarks_root,
				base + Vector3(1.4, 0.25, 0.0),
				Vector3(2.8, 0.5, 0.9),
				_material("vertical_access", Color(0.62, 0.32, 1.0, 1.0))
			)


func _add_box(mesh_name: String, parent: Node, position: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = mesh_name
	body.position = position
	parent.add_child(body)

	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)

	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	body.add_child(collision)

	return body


func _add_visual_box(mesh_name: String, parent: Node, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_label(label_name: String, text: String, position: Vector3, color: Color, pixel_size: float) -> void:
	var label := Label3D.new()
	label.name = label_name
	label.text = text
	label.position = position
	label.modulate = color
	label.pixel_size = pixel_size
	label.font_size = 32
	label.outline_size = 6
	label.no_depth_test = true
	labels_root.add_child(label)


func _route_material(color: Color) -> StandardMaterial3D:
	if color == ROUTE_COLORS["green"]:
		return _material(DEBUG_MATERIAL_NAMES["green"], color)
	if color == ROUTE_COLORS["yellow"]:
		return _material(DEBUG_MATERIAL_NAMES["yellow"], color)
	if color == ROUTE_COLORS["blue"]:
		return _material(DEBUG_MATERIAL_NAMES["blue"], color)
	if color == ROUTE_COLORS["purple"]:
		return _material(DEBUG_MATERIAL_NAMES["purple"], color)
	if color == ROUTE_COLORS["orange"]:
		return _material(DEBUG_MATERIAL_NAMES["orange"], color)
	if color == ROUTE_COLORS["red"]:
		return _material(DEBUG_MATERIAL_NAMES["red"], color)
	return _material(DEBUG_MATERIAL_NAMES["landmark"], color)


func _material(material_name: String, color: Color) -> StandardMaterial3D:
	if _materials.has(material_name):
		return _materials[material_name]

	var material := StandardMaterial3D.new()
	material.resource_name = material_name
	material.albedo_color = color
	material.roughness = 0.82
	if material_name.begins_with("port_") or material_name.begins_with("route_") or material_name.begins_with("vertical_") or material_name.begins_with("DBG_Route_") or material_name.begins_with("identity_"):
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.2
	_materials[material_name] = material
	return material


func _position_from_dict(position: Dictionary) -> Vector3:
	return Vector3(float(position["x"]), float(position["y"]), float(position["z"]))


func _pair_key(first: String, second: String) -> String:
	var pair := [first, second]
	pair.sort()
	return "%s__%s" % [pair[0], pair[1]]


func _safe_name(raw_name: String) -> String:
	var result := raw_name.strip_edges().replace("/", "_")
	result = result.replace(" ", "_").replace("-", "_")
	var regex := RegEx.new()
	regex.compile("[^A-Za-z0-9_]")
	return regex.sub(result, "", true)
