@tool
extends Node3D
## Systems and dressing for the straight north-courtyard service street.
## The imported GLB owns architecture; this node owns gameplay, permissions,
## powered state, population, patrols, props, and traversal helpers.

const POWER_GRID := preload("res://scripts/power_grid.gd")
const POWER_SWITCH := preload("res://scripts/power_switch.gd")
const POWERED_LIGHT := preload("res://scripts/powered_light.gd")
const POWERED_CHECKPOINT := preload("res://scripts/powered_checkpoint.gd")
const POWERED_VENDOR := preload("res://scripts/powered_vendor.gd")
const RESTRICTED_AREA := preload("res://scripts/restricted_area.gd")
const COURIER_ACTIVITY := preload("res://scripts/courier_activity.gd")
const COURIER_NPC := preload("res://scripts/courier_npc.gd")
const PACKAGE_PICKUP := preload("res://scripts/package_pickup.gd")
const DELIVERY_TERMINAL := preload("res://scripts/delivery_terminal.gd")
const ROPE_DESCENT := preload("res://scripts/rope_descent.gd")
const LADDER_ZONE := preload("res://scripts/ladder_zone.gd")

const GUARD_SCENE := preload("res://scenes/enemies/GangGuard.tscn")
const CIVILIAN_SCENES: Array[PackedScene] = [
	preload("res://scenes/npcs/Civilian_RatSand.tscn"),
	preload("res://scenes/npcs/Civilian_RatTeal.tscn"),
	preload("res://scenes/npcs/Civilian_SaurianBazaar.tscn"),
	preload("res://scenes/npcs/Civilian_CephalopodBazaar.tscn"),
	preload("res://scenes/npcs/Civilian_AndroidBazaar.tscn"),
]

const STEEL := Color(0.105, 0.115, 0.14)
const WALL := Color(0.22, 0.19, 0.21)
const FLOOR := Color(0.16, 0.17, 0.18)
const CYAN := Color(0.05, 0.75, 0.85)
const AMBER := Color(1.0, 0.46, 0.08)
const GREEN := Color(0.18, 0.72, 0.36)
const RED := Color(0.72, 0.08, 0.1)
const PURPLE := Color(0.64, 0.18, 0.9)

@export var use_imported_visuals: bool = true


func _ready() -> void:
	_prepare_imported_visuals()
	_build()
	_apply_imported_dynamic_placements()


func _prepare_imported_visuals() -> void:
	var imported := get_node_or_null("ImportedVisuals")
	if imported == null:
		use_imported_visuals = false
		return
	imported.visible = use_imported_visuals
	if not use_imported_visuals:
		return

	# The GLB is the saved architectural snapshot. Hide exported copies of
	# actors and stateful props so the live scripted versions remain canonical.
	for dynamic_name in [
		"StreetPopulation",
		"NorthStreetPatrolGuard",
		"PoweredVendor",
		"Courier",
		"AlienBarCourierPackage",
		"PowerSwitch",
		"CredentialGate",
		"DeliveryTerminal",
	]:
		var dynamic_copy := imported.find_child(dynamic_name, true, false)
		if dynamic_copy is Node3D:
			dynamic_copy.visible = false

	# The live route is rebuilt against the current alley facades and
	# WalkwayEast seam. Hide the stale snapshot exported before that alignment.
	var imported_catwalk := imported.find_child("ContinuousUpperCatwalk", true, false)
	if imported_catwalk is Node3D:
		imported_catwalk.visible = false

	# Imported lights are static snapshots. The generated lights below remain
	# live power consumers, so disable the snapshot lights.
	for descendant in imported.find_children("*", "Light3D", true, false):
		if descendant is Light3D:
			descendant.visible = false


func _apply_imported_dynamic_placements() -> void:
	if not use_imported_visuals:
		return
	var imported := get_node_or_null("ImportedVisuals")
	var generated := get_node_or_null("Generated")
	if imported == null or generated == null:
		return

	# Blender edits may move a visible child mesh instead of its exported
	# functional parent. Promote the visible mesh transform onto the live actor
	# so collision, AI, and interaction match what was positioned in Blender.
	var imported_guard := imported.find_child("NorthStreetPatrolGuard", true, false) as Node3D
	var live_guard := generated.get_node_or_null("NorthStreetPatrolGuard") as Node3D
	if imported_guard != null and live_guard != null:
		var imported_guard_mesh := imported_guard.find_child("GuardMesh", true, false) as Node3D
		var live_guard_mesh := live_guard.find_child("GuardMesh", true, false) as Node3D
		if imported_guard_mesh != null and live_guard_mesh != null:
			var authored_local := to_local(imported_guard_mesh.global_position)
			# Preserve the authored position along the street, but project it
			# onto the current facade-hugging catwalk surface.
			live_guard.position = Vector3(authored_local.x, 4.58, -31.1)

	_sync_interactable_to_imported_mesh(imported, generated, "CredentialGate")


func _sync_interactable_to_imported_mesh(
	imported: Node,
	generated: Node,
	node_name: String
) -> void:
	var imported_node := imported.find_child(node_name, true, false) as Node3D
	var live_node := generated.find_child(node_name, true, false) as Node3D
	if imported_node == null or live_node == null:
		return
	var imported_meshes := imported_node.find_children("*", "MeshInstance3D", true, false)
	var live_meshes := live_node.find_children("*", "MeshInstance3D", true, false)
	if imported_meshes.is_empty() or live_meshes.is_empty():
		return
	var imported_mesh := imported_meshes[0] as MeshInstance3D
	var live_mesh := live_meshes[0] as MeshInstance3D
	live_node.global_transform = imported_mesh.global_transform * live_mesh.transform.affine_inverse()
	if live_node.has_method("adopt_current_position_as_closed"):
		live_node.call("adopt_current_position_as_closed")


func _build() -> void:
	var old := get_node_or_null("Generated")
	if old != null:
		old.free()

	var generated := Node3D.new()
	generated.name = "Generated"
	add_child(generated)

	var power_grid := Node3D.new()
	power_grid.name = "PowerGrid"
	if not Engine.is_editor_hint():
		power_grid.set_script(POWER_GRID)
	generated.add_child(power_grid)

	var activity := Node3D.new()
	activity.name = "CourierActivity"
	if not Engine.is_editor_hint():
		activity.set_script(COURIER_ACTIVITY)
	var meeting := Marker3D.new()
	meeting.name = "MeetingMarker"
	meeting.position = Vector3(116.0, 0.2, -31.0)
	activity.add_child(meeting)
	generated.add_child(activity)

	_build_social_block(generated, activity)
	_build_utility_block(generated, power_grid)
	_build_security_block(generated, activity)
	_build_upper_route(generated)
	_build_courtyard_routes(generated)
	_build_street_dressing(generated)
	_build_population(generated)
	_build_street_patrol(generated)
	_build_powered_lighting(generated)


func _build_social_block(root: Node3D, activity: Node3D) -> void:
	var block := Node3D.new()
	block.name = "SocialCourierBlock"
	root.add_child(block)

	# The western bar is the street's social landmark. The package is now inside
	# its authored shell rather than in an unrelated distant coordinate.
	var package := _interactable(
		block,
		"AlienBarCourierPackage",
		Vector3(57.0, 0.55, -42.0),
		Vector3(0.8, 0.55, 0.7),
		AMBER,
		PACKAGE_PICKUP
	)
	if not Engine.is_editor_hint():
		package.activity = package.get_path_to(activity)

	var vendor := Node3D.new()
	vendor.name = "PoweredVendor"
	vendor.position = Vector3(70.5, 0.0, -37.1)
	var shutter := _body_box(
		"Shutter",
		Vector3.ZERO,
		Vector3(3.0, 1.25, 0.18),
		RED
	)
	vendor.add_child(shutter)
	if not Engine.is_editor_hint():
		vendor.set_script(POWERED_VENDOR)
	block.add_child(vendor)

	var courier := _interactable(
		block,
		"Courier",
		Vector3(67.5, 0.9, -36.7),
		Vector3(0.8, 1.8, 0.8),
		AMBER,
		COURIER_NPC
	)
	if not Engine.is_editor_hint():
		courier.activity = courier.get_path_to(activity)

	var restricted := _area(
		block,
		"VendorStaffOnly",
		Vector3(72.0, 1.2, -41.0),
		Vector3(11.0, 2.4, 6.2)
	)
	if not Engine.is_editor_hint():
		restricted.set_script(RESTRICTED_AREA)
		restricted.required_access_tag = "vendor_staff"
		restricted.warning_text = "Courier freight office. Vendor staff only."
		restricted.call("_ready")

	_label(block, "ALIEN BAR / COURIER", Vector3(58.0, 4.7, -37.2), PURPLE)
	_label(block, "FREIGHT DESK", Vector3(72.0, 3.6, -37.2), CYAN)


func _build_utility_block(root: Node3D, grid: Node3D) -> void:
	var block := Node3D.new()
	block.name = "UtilityPowerBlock"
	root.add_child(block)

	_box(block, "Generator", Vector3(89.0, 0.8, -42.0), Vector3(2.2, 1.6, 1.4), GREEN)
	_box(block, "PipeBank", Vector3(86.0, 1.8, -43.2), Vector3(3.0, 0.35, 0.5), AMBER)

	var switch := _interactable(
		block,
		"PowerSwitch",
		Vector3(85.0, 1.25, -37.3),
		Vector3(0.6, 1.0, 0.35),
		CYAN,
		POWER_SWITCH
	)
	if not Engine.is_editor_hint():
		switch.power_grid = switch.get_path_to(grid)

	var restricted := _area(
		block,
		"UtilityRestricted",
		Vector3(87.0, 1.3, -41.0),
		Vector3(12.5, 2.6, 6.2)
	)
	if not Engine.is_editor_hint():
		restricted.set_script(RESTRICTED_AREA)
		restricted.required_access_tag = "utility"
		restricted.warning_text = "Utility access required."
		restricted.call("_ready")

	_label(block, "GRID CONTROL", Vector3(87.0, 4.2, -37.2), AMBER)


func _build_security_block(root: Node3D, activity: Node3D) -> void:
	var block := Node3D.new()
	block.name = "SecurityAccessBlock"
	root.add_child(block)

	var checkpoint := _interactable(
		block,
		"CredentialGate",
		Vector3(104.0, 1.6, -37.25),
		Vector3(3.0, 3.2, 0.3),
		RED,
		POWERED_CHECKPOINT
	)
	if not Engine.is_editor_hint():
		checkpoint.required_access_tag = "courtyard_service"

	var terminal := _interactable(
		block,
		"DeliveryTerminal",
		Vector3(108.3, 1.1, -38.5),
		Vector3(0.7, 1.4, 0.5),
		CYAN,
		DELIVERY_TERMINAL
	)
	if not Engine.is_editor_hint():
		terminal.activity = terminal.get_path_to(activity)

	var restricted := _area(
		block,
		"SecurityRestricted",
		Vector3(104.0, 2.2, -41.0),
		Vector3(14.0, 4.4, 6.2)
	)
	if not Engine.is_editor_hint():
		restricted.set_script(RESTRICTED_AREA)
		restricted.required_access_tag = "courtyard_service"
		restricted.warning_text = "North courtyard security. Credentials required."
		restricted.call("_ready")

	_label(block, "NORTH COURTYARD ACCESS", Vector3(104.0, 5.3, -37.2), CYAN)


func _build_upper_route(root: Node3D) -> void:
	var route := Node3D.new()
	route.name = "ContinuousUpperCatwalk"
	root.add_child(route)

	# One legible route replaces the previous freight, service, conduit, and
	# rooftop chains. It offers two entry ladders and one commitment to the
	# existing courtyard AccessLanding.
	# Follow the south building facades, then turn northeast into WalkwayEast.
	# EastMicroHub itself is offset in the map, so the final local point resolves
	# to WalkwayEast's world center at approximately (113.66, 4.41, -31.87).
	var points := [
		Vector3(74.0, 4.45, -31.1),
		Vector3(88.0, 4.45, -31.1),
		Vector3(101.5, 4.45, -31.1),
		Vector3(105.5, 4.45, -29.7),
		Vector3(108.58, 4.45, -27.68),
	]
	for i in range(points.size() - 1):
		_bridge(route, "UpperDeck%02d" % i, points[i], points[i + 1], 2.0, 0.25, STEEL)
		var outer_offset := Vector3(0.0, 0.65, 0.9)
		_bridge(
			route,
			"UpperRail%02d" % i,
			points[i] + outer_offset,
			points[i + 1] + outer_offset,
			0.12,
			1.3,
			AMBER
		)

	_box(route, "VendorLanding", points[0], Vector3(2.8, 0.25, 2.8), STEEL)
	_box(route, "UtilityLanding", points[1], Vector3(2.8, 0.25, 2.8), STEEL)
	_box(route, "SecurityLanding", points[2], Vector3(3.0, 0.25, 2.8), STEEL)

	# Credential-door interior access: enter beneath the AccessRamp, climb
	# inside the final shell, then step out onto the curved catwalk return.
	var credential_ladder_position := Vector3(108.7, 2.25, -29.1)
	var credential_ladder := _area(
		route,
		"CredentialInteriorLadder",
		credential_ladder_position,
		Vector3(1.15, 4.5, 1.15)
	)
	if not Engine.is_editor_hint():
		credential_ladder.set_script(LADDER_ZONE)
		credential_ladder.call("_ready")
	_box(route, "CredentialLadderRailLeft", credential_ladder_position + Vector3(-0.42, 0.0, 0.0), Vector3(0.12, 4.5, 0.12), AMBER)
	_box(route, "CredentialLadderRailRight", credential_ladder_position + Vector3(0.42, 0.0, 0.0), Vector3(0.12, 4.5, 0.12), AMBER)
	for rung_index in range(10):
		_box(
			route,
			"CredentialLadderRung%02d" % rung_index,
			Vector3(108.7, 0.45 + rung_index * 0.42, -29.1),
			Vector3(0.9, 0.1, 0.12),
			STEEL
		)
	_box(route, "CredentialSecondFloor", Vector3(108.0, 4.45, -29.2), Vector3(3.4, 0.25, 2.8), STEEL)
	_bridge(
		route,
		"CredentialExitToCatwalk",
		Vector3(108.0, 4.45, -29.2),
		Vector3(108.58, 4.45, -27.68),
		2.0,
		0.25,
		STEEL
	)

	for ladder_data in [
		["VendorCatwalkLadder", Vector3(74.0, 2.2, -30.3)],
		["UtilityCatwalkLadder", Vector3(88.0, 2.2, -30.3)],
	]:
		var ladder := _area(route, ladder_data[0], ladder_data[1], Vector3(1.1, 4.4, 1.1))
		if not Engine.is_editor_hint():
			ladder.set_script(LADDER_ZONE)
			ladder.call("_ready")

	_label(route, "UPPER SERVICE / HIGH EXPOSURE", Vector3(91.0, 5.4, -31.1), PURPLE)


func _build_courtyard_routes(root: Node3D) -> void:
	var routes := Node3D.new()
	routes.name = "AuthoredCourtyardRoutes"
	root.add_child(routes)

	# Preserve the already functional east-wall crouch route, roof ladder, and
	# rope descent without letting them complicate the street's main topology.
	_box(routes, "CrouchFloorNorth", Vector3(139.0, -0.05, -13.0), Vector3(2.2, 0.2, 15.0), FLOOR)
	_box(routes, "CrouchRoofNorth", Vector3(139.0, 1.65, -13.0), Vector3(2.2, 0.2, 15.0), STEEL)
	_box(routes, "CrouchOuterWall", Vector3(140.1, 0.8, -13.0), Vector3(0.2, 1.7, 15.0), WALL)
	_box(routes, "CrouchTurnFloor", Vector3(137.0, -0.05, -5.6), Vector3(6.0, 0.2, 2.0), FLOOR)
	_box(routes, "CrouchTurnRoof", Vector3(137.0, 1.65, -5.6), Vector3(6.0, 0.2, 2.0), STEEL)

	var ladder := _area(
		routes,
		"FunctionalRoofLadder",
		Vector3(136.8, 4.6, -18.8),
		Vector3(1.5, 9.2, 1.5)
	)
	if not Engine.is_editor_hint():
		ladder.set_script(LADDER_ZONE)
		ladder.call("_ready")
	_box(routes, "RoofObservationLedge", Vector3(133.8, 9.0, -18.8), Vector3(7.0, 0.3, 3.0), STEEL)

	var rope := _interactable(
		routes,
		"FunctionalRopeDrop",
		Vector3(112.0, 4.4, -21.7),
		Vector3(0.5, 1.0, 0.5),
		AMBER,
		ROPE_DESCENT
	)
	var destination := Marker3D.new()
	destination.name = "RopeDestination"
	destination.position = Vector3(112.0, 0.25, -18.0)
	routes.add_child(destination)
	if not Engine.is_editor_hint():
		rope.destination = rope.get_path_to(destination)


func _build_street_dressing(root: Node3D) -> void:
	var dressing := Node3D.new()
	dressing.name = "StreetDressing"
	root.add_child(dressing)

	# Three cover clusters leave more than 3.5 m clear down the road.
	_box(dressing, "CoverWest", Vector3(64.0, 0.55, -34.7), Vector3(2.4, 1.1, 1.2), GREEN)
	_box(dressing, "CoverCenter", Vector3(91.0, 0.55, -29.4), Vector3(2.5, 1.1, 1.2), STEEL)
	_box(dressing, "CoverEast", Vector3(115.0, 0.55, -34.5), Vector3(2.4, 1.1, 1.2), RED)

	_market_stall(dressing, "SocialStallA", Vector3(75.0, 0.0, -27.2), RED)
	_market_stall(dressing, "SocialStallB", Vector3(80.0, 0.0, -27.2), GREEN)

	# The south connector is a deliberate loop back to the East Approach.
	_box(dressing, "ConnectorRailWest", Vector3(81.9, 0.65, -23.0), Vector3(0.15, 1.3, 8.0), AMBER)
	_box(dressing, "ConnectorRailEast", Vector3(90.1, 0.65, -23.0), Vector3(0.15, 1.3, 8.0), AMBER)
	_label(dressing, "EAST APPROACH", Vector3(86.0, 2.2, -19.5), CYAN)


func _build_population(root: Node3D) -> void:
	var population := Node3D.new()
	population.name = "StreetPopulation"
	root.add_child(population)

	var positions := [
		Vector3(69.0, 0.0, -29.0),
		Vector3(71.5, 0.0, -30.0),
		Vector3(75.0, 0.0, -29.0),
		Vector3(77.5, 0.0, -30.0),
		Vector3(80.0, 0.0, -28.5),
		Vector3(82.5, 0.0, -30.2),
	]
	for i in range(positions.size()):
		var civilian := CIVILIAN_SCENES[i % CIVILIAN_SCENES.size()].instantiate()
		civilian.name = "NorthStreetCivilian_%02d" % (i + 1)
		civilian.position = positions[i]
		population.add_child(civilian)


func _build_street_patrol(root: Node3D) -> void:
	var route := Node3D.new()
	route.name = "NorthStreetPatrolRoute"
	root.add_child(route)
	for i in range(4):
		var marker := Marker3D.new()
		marker.name = "NSP_%d" % (i + 1)
		marker.position = [
			Vector3(82.0, 4.58, -31.1),
			Vector3(98.0, 4.58, -31.1),
			Vector3(105.0, 4.58, -29.9),
			Vector3(108.0, 4.58, -27.95),
		][i]
		route.add_child(marker)

	var guard := GUARD_SCENE.instantiate()
	guard.name = "NorthStreetPatrolGuard"
	guard.position = Vector3(96.0, 4.58, -31.1)
	guard.starts_active = true
	guard.sentry = true
	guard.vision_range = 15.0
	guard.vision_half_angle_degrees = 45.0
	guard.restrict_perception_to_bounds = true
	guard.perception_bounds_center = Vector3(112.0, 3.0, -4.0)
	guard.perception_bounds_half_extents = Vector3(27.0, 12.0, 21.0)
	root.add_child(guard)
	guard.patrol_route = guard.get_path_to(route)


func _build_powered_lighting(root: Node3D) -> void:
	for i in range(5):
		var x := 58.0 + i * 16.0
		var light := OmniLight3D.new()
		light.name = "PoweredStreetLight_%02d" % (i + 1)
		light.position = Vector3(x, 4.2, -32.0)
		light.light_color = CYAN if i % 2 == 0 else AMBER
		light.light_energy = 2.2
		light.omni_range = 9.0
		if not Engine.is_editor_hint():
			light.set_script(POWERED_LIGHT)
		root.add_child(light)


func _box(parent: Node, node_name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	mesh_instance.visible = not use_imported_visuals or _is_live_generated_route(parent)
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.55
	material.roughness = 0.7
	mesh.material = material
	mesh_instance.mesh = mesh
	parent.add_child(mesh_instance)

	var body := StaticBody3D.new()
	body.name = node_name + "Collision"
	body.position = pos
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return mesh_instance


func _is_live_generated_route(node: Node) -> bool:
	var current := node
	while current != null and current != self:
		if current.name == "ContinuousUpperCatwalk":
			return true
		current = current.get_parent()
	return false


func _bridge(
	parent: Node,
	node_name: String,
	start: Vector3,
	finish: Vector3,
	width: float,
	height: float,
	color: Color
) -> Node3D:
	var direction := finish - start
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	var bridge := Node3D.new()
	bridge.name = node_name
	bridge.position = (start + finish) * 0.5
	bridge.rotation.y = atan2(-horizontal.z, horizontal.x)
	parent.add_child(bridge)
	_box(bridge, "Deck", Vector3.ZERO, Vector3(horizontal.length(), height, width), color)
	return bridge


func _interactable(
	parent: Node,
	node_name: String,
	pos: Vector3,
	size: Vector3,
	color: Color,
	behavior: Script
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	if not Engine.is_editor_hint():
		body.set_script(behavior)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 0.35
	box.material = material
	mesh.mesh = box
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body


func _area(parent: Node, node_name: String, pos: Vector3, size: Vector3) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.position = pos
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	area.add_child(collision)
	parent.add_child(area)
	return area


func _body_box(node_name: String, pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _market_stall(parent: Node, node_name: String, pos: Vector3, color: Color) -> void:
	var stall := Node3D.new()
	stall.name = node_name
	stall.position = pos
	parent.add_child(stall)
	_box(stall, "Counter", Vector3(0.0, 0.6, 0.0), Vector3(3.2, 1.2, 1.2), STEEL)
	_box(stall, "PostLeft", Vector3(-1.4, 2.0, 0.0), Vector3(0.15, 4.0, 0.15), WALL)
	_box(stall, "PostRight", Vector3(1.4, 2.0, 0.0), Vector3(0.15, 4.0, 0.15), WALL)
	_box(stall, "Canopy", Vector3(0.0, 3.4, 0.0), Vector3(3.4, 0.18, 2.4), color)


func _label(
	parent: Node,
	text: String,
	pos: Vector3,
	color: Color,
	rot_degrees := Vector3.ZERO
) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.rotation_degrees = rot_degrees
	label.modulate = color
	label.outline_size = 8
	label.font_size = 48
	label.pixel_size = 0.012
	parent.add_child(label)
