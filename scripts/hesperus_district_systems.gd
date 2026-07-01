extends Node3D
## Runtime-owned systemic layer for Hesperus. Imported assets remain
## architecture; this node adds functional traversal and chase route metadata.

const LADDER_SCENE := preload("res://scenes/props/LadderZone.tscn")
const SERVICE_HATCH := preload("res://scripts/service_hatch.gd")
const PRESSURE_VALVE := preload("res://scripts/pressure_valve.gd")
const ARCADE_ACTIVITY := preload("res://scripts/alien_bar_arcade_activity.gd")

const STEAM_CLEAR_FLAG := "hesperus.courtyard.steam_vented"


func _ready() -> void:
	_build_courtyard_traversal()
	_build_escape_routes()
	_build_arcade_activity()


func _build_arcade_activity() -> void:
	var activity := Node3D.new()
	activity.name = "AlienBarArcadeActivity"
	activity.set_script(ARCADE_ACTIVITY)
	add_child(activity)


func _build_courtyard_traversal() -> void:
	var generated := Node3D.new()
	generated.name = "CourtyardSystemicTraversal"
	add_child(generated)

	var ladder := LADDER_SCENE.instantiate() as Area3D
	ladder.name = "CourtyardRoofLadderZone"
	ladder.position = Vector3(136.4, 4.55, -19.0)
	ladder.scale = Vector3(1.5, 8.8, 1.5)
	generated.add_child(ladder)
	ladder.body_entered.connect(_on_roof_ladder_entered)

	var inside_marker := Marker3D.new()
	inside_marker.name = "ServiceCrawlInside"
	inside_marker.position = Vector3(134.7, 0.7, 2.0)
	generated.add_child(inside_marker)

	var outside_marker := Marker3D.new()
	outside_marker.name = "ServiceCrawlOutside"
	outside_marker.position = Vector3(139.2, 0.7, 2.0)
	generated.add_child(outside_marker)

	var inside_hatch := _make_hatch("InsideServiceGrate", Vector3(136.2, 1.0, 2.0))
	generated.add_child(inside_hatch)
	inside_hatch.destination = inside_hatch.get_path_to(outside_marker)

	var outside_hatch := _make_hatch("OutsideServiceGrate", Vector3(138.1, 1.0, 2.0))
	generated.add_child(outside_hatch)
	outside_hatch.destination = outside_hatch.get_path_to(inside_marker)

	var steam_blocker := StaticBody3D.new()
	steam_blocker.name = "ServiceSteamBlocker"
	steam_blocker.position = Vector3(137.2, 0.9, 2.0)
	var blocker_mesh := MeshInstance3D.new()
	var blocker_box := BoxMesh.new()
	blocker_box.size = Vector3(1.8, 1.8, 2.4)
	blocker_mesh.mesh = blocker_box
	var steam_material := StandardMaterial3D.new()
	steam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	steam_material.albedo_color = Color(0.55, 0.9, 1.0, 0.32)
	steam_material.emission_enabled = true
	steam_material.emission = Color(0.15, 0.55, 0.8)
	steam_material.emission_energy_multiplier = 1.4
	blocker_mesh.material_override = steam_material
	steam_blocker.add_child(blocker_mesh)
	var blocker_collision := CollisionShape3D.new()
	var blocker_shape := BoxShape3D.new()
	blocker_shape.size = Vector3(1.8, 1.8, 2.4)
	blocker_collision.shape = blocker_shape
	steam_blocker.add_child(blocker_collision)
	generated.add_child(steam_blocker)

	var valve := StaticBody3D.new()
	valve.name = "CourtyardPressureValve"
	valve.position = Vector3(132.9, 1.1, 6.0)
	valve.set_script(PRESSURE_VALVE)
	var valve_mesh := MeshInstance3D.new()
	var valve_box := BoxMesh.new()
	valve_box.size = Vector3(0.8, 1.2, 0.5)
	valve_mesh.mesh = valve_box
	valve.add_child(valve_mesh)
	var valve_collision := CollisionShape3D.new()
	var valve_shape := BoxShape3D.new()
	valve_shape.size = Vector3(1.0, 1.4, 0.8)
	valve_collision.shape = valve_shape
	valve.add_child(valve_collision)
	generated.add_child(valve)
	var blocker_paths: Array[NodePath] = [valve.get_path_to(steam_blocker)]
	valve.blocker_paths = blocker_paths


func _make_hatch(hatch_name: String, world_position: Vector3) -> StaticBody3D:
	var hatch := StaticBody3D.new()
	hatch.name = hatch_name
	hatch.position = world_position
	hatch.set_script(SERVICE_HATCH)
	hatch.required_clear_flag = STEAM_CLEAR_FLAG
	hatch.state_flag = "hesperus.courtyard.service_crawl_used"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.35, 1.8, 2.2)
	collision.shape = shape
	hatch.add_child(collision)
	return hatch


func _build_escape_routes() -> void:
	var scene_root := _get_scene_root()
	if scene_root == null:
		return
	var route_root := scene_root.get_node_or_null("KorvaxiEscapeRoute")
	if route_root == null:
		return
	_add_route(route_root, "Route_ServiceStreet", [
		Vector3(104.0, 0.0, -13.0),
		Vector3(125.0, 0.0, -25.5),
		Vector3(112.0, 0.0, -31.0),
		Vector3(82.0, 0.0, -31.0),
		Vector3(58.0, 0.0, -31.0),
	], "hesperus.north_service.power_cut", "escaped",
		"north service street", "Korvaxi is breaking for the darkened north service street!")
	_add_route(route_root, "Route_Rooftop", [
		Vector3(126.0, 0.0, -18.0),
		Vector3(136.0, 0.0, -19.0),
		Vector3(136.0, 8.8, -19.0),
		Vector3(116.0, 8.8, -29.0),
		Vector3(82.0, 8.8, -31.0),
	], "hesperus.courtyard.roof_access", "escaped",
		"courtyard rooftops", "Korvaxi is climbing for the courtyard rooftops!")
	_add_route(route_root, "Route_ServiceCrawl", [
		Vector3(125.0, 0.0, 1.5),
		Vector3(136.0, 0.0, 2.0),
		Vector3(142.0, 0.0, 2.0),
		Vector3(155.0, 0.0, 10.0),
	], STEAM_CLEAR_FLAG, "escaped",
		"east service crawl", "Korvaxi is diving into the cleared east service crawl!")


func _add_route(
	route_root: Node,
	route_name: String,
	world_points: Array[Vector3],
	required_flag: String,
	terminal_outcome: String,
	display_name: String,
	cue_text: String
) -> void:
	if route_root.has_node(route_name):
		return
	var branch := Node3D.new()
	branch.name = route_name
	branch.set_meta("route_id", route_name.trim_prefix("Route_").to_snake_case())
	branch.set_meta("required_flag", required_flag)
	branch.set_meta("terminal_outcome", terminal_outcome)
	branch.set_meta("display_name", display_name)
	branch.set_meta("cue_text", cue_text)
	route_root.add_child(branch)
	for index in world_points.size():
		var marker := Marker3D.new()
		marker.name = "Node_%02d" % (index + 1)
		branch.add_child(marker)
		marker.global_position = world_points[index]


func _get_scene_root() -> Node:
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		return tree.current_scene
	if owner != null:
		return owner
	var node := get_parent()
	while node != null:
		if tree != null and node.get_parent() == tree.root:
			return node
		if node.get_parent() == null:
			return node
		node = node.get_parent()
	return null


func _on_roof_ladder_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var district_state := get_node_or_null("/root/DistrictState")
	if district_state != null:
		district_state.call("set_flag", "hesperus.courtyard.roof_access", true)
