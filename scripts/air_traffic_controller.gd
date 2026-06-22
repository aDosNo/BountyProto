extends Node3D
## Visual-only high-altitude traffic for Hesperus. Craft use procedural flight
## lanes and placeholder meshes that can later be replaced with a GLB scene.

@export var craft_scene: PackedScene
@export var craft_count: int = 14
@export var rng_seed: int = 88421
@export var field_center: Vector3 = Vector3(35.0, 78.0, 8.0)
@export var field_radius: float = 165.0
@export var min_altitude: float = 54.0
@export var max_altitude: float = 118.0
@export var min_speed: float = 18.0
@export var max_speed: float = 42.0
@export var path_curve_amount: float = 42.0
@export var respawn_delay_range: Vector2 = Vector2(0.8, 6.0)
@export var placeholder_scale_range: Vector2 = Vector2(0.45, 1.2)
@export var nav_light_energy: float = 1.8
@export var engine_glow_energy: float = 2.4

var _rng := RandomNumberGenerator.new()
var _flights: Array[Dictionary] = []
var _hull_material: StandardMaterial3D
var _dark_material: StandardMaterial3D
var _engine_material: StandardMaterial3D
var _nav_cyan_material: StandardMaterial3D
var _nav_warm_material: StandardMaterial3D


func _ready() -> void:
	_rng.seed = rng_seed
	_build_materials()
	for i in range(maxi(craft_count, 0)):
		var craft := _make_craft(i)
		add_child(craft)
		_flights.append(_make_flight(craft, -_rng.randf_range(0.0, respawn_delay_range.y)))
	set_process(craft_count > 0)


func _process(delta: float) -> void:
	for i in range(_flights.size()):
		var flight := _flights[i]
		flight["elapsed"] = float(flight["elapsed"]) + delta

		var craft := flight["node"] as Node3D
		if float(flight["elapsed"]) < 0.0:
			craft.visible = false
			_flights[i] = flight
			continue

		craft.visible = true
		var t: float = clampf(float(flight["elapsed"]) / float(flight["duration"]), 0.0, 1.0)
		var craft_pos := _bezier(flight["p0"], flight["p1"], flight["p2"], flight["p3"], t)
		var next_position := _bezier(flight["p0"], flight["p1"], flight["p2"], flight["p3"], minf(t + 0.015, 1.0))
		var direction := next_position - craft_pos
		craft.global_position = craft_pos
		if direction.length_squared() > 0.001:
			craft.look_at(craft_pos + direction.normalized(), Vector3.UP)
			craft.rotate_object_local(Vector3.FORWARD, sin(t * TAU + float(flight["bank_phase"])) * float(flight["bank_amount"]))

		_update_lights(craft, flight, t)

		if t >= 1.0:
			_flights[i] = _make_flight(craft, _rng.randf_range(respawn_delay_range.x, respawn_delay_range.y) * -1.0)
		else:
			_flights[i] = flight


func _make_flight(craft: Node3D, start_time: float = 0.0) -> Dictionary:
	var angle := _rng.randf_range(0.0, TAU)
	var side := Vector3(cos(angle), 0.0, sin(angle))
	var tangent := Vector3(-side.z, 0.0, side.x)
	var start_altitude := _rng.randf_range(min_altitude, max_altitude)
	var end_altitude := clampf(start_altitude + _rng.randf_range(-18.0, 22.0), min_altitude, max_altitude)
	var start_distance := field_radius * _rng.randf_range(0.78, 1.16)
	var end_distance := field_radius * _rng.randf_range(0.78, 1.16)
	var lateral_offset := _rng.randf_range(-field_radius * 0.32, field_radius * 0.32)
	var p0 := field_center + side * start_distance + tangent * lateral_offset
	var p3 := field_center - side * end_distance + tangent * _rng.randf_range(-field_radius * 0.34, field_radius * 0.34)
	p0.y = start_altitude
	p3.y = end_altitude

	var travel := p3 - p0
	var length := maxf(travel.length(), 1.0)
	var curve := tangent * _rng.randf_range(-path_curve_amount, path_curve_amount)
	curve += Vector3.UP * _rng.randf_range(-10.0, 16.0)
	var p1 := p0 + travel * _rng.randf_range(0.22, 0.38) + curve
	var p2 := p0 + travel * _rng.randf_range(0.62, 0.82) - curve * _rng.randf_range(0.45, 0.9)
	p1.y = clampf(p1.y, min_altitude, max_altitude)
	p2.y = clampf(p2.y, min_altitude, max_altitude)

	return {
		"node": craft,
		"p0": p0,
		"p1": p1,
		"p2": p2,
		"p3": p3,
		"duration": length / _rng.randf_range(min_speed, max_speed),
		"elapsed": start_time,
		"blink_phase": _rng.randf_range(0.0, TAU),
		"blink_speed": _rng.randf_range(4.0, 9.0),
		"bank_phase": _rng.randf_range(0.0, TAU),
		"bank_amount": _rng.randf_range(0.03, 0.14),
	}


func _make_craft(index: int) -> Node3D:
	var craft := Node3D.new()
	craft.name = "AirTrafficCraft_%02d" % index

	var visual_root := Node3D.new()
	visual_root.name = "VisualRoot"
	craft.add_child(visual_root)

	if craft_scene != null:
		visual_root.add_child(craft_scene.instantiate())
	else:
		_add_placeholder_craft(visual_root, _rng.randf_range(placeholder_scale_range.x, placeholder_scale_range.y))

	var nav_light := _make_glow("NavLight_Cyan", _nav_cyan_material, 0.08)
	nav_light.position = Vector3(-0.42, 0.0, 0.22)
	craft.add_child(nav_light)

	var beacon := _make_glow("Beacon_Warm", _nav_warm_material, 0.07)
	beacon.position = Vector3(0.42, 0.02, 0.22)
	craft.add_child(beacon)

	var engine := _make_glow("EngineGlow", _engine_material, 0.16)
	engine.position = Vector3(0.0, 0.0, 0.72)
	engine.scale = Vector3(0.7, 0.7, 1.8)
	craft.add_child(engine)

	return craft


func _add_placeholder_craft(parent: Node3D, craft_scale: float) -> void:
	parent.scale = Vector3.ONE * craft_scale

	var hull := MeshInstance3D.new()
	hull.name = "PlaceholderHull"
	var hull_mesh := BoxMesh.new()
	hull_mesh.size = Vector3(0.42, 0.16, 1.05)
	hull.mesh = hull_mesh
	hull.material_override = _hull_material
	parent.add_child(hull)

	var nose := MeshInstance3D.new()
	nose.name = "PlaceholderNose"
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.28, 0.12, 0.34)
	nose.mesh = nose_mesh
	nose.position = Vector3(0.0, 0.0, -0.62)
	nose.material_override = _dark_material
	parent.add_child(nose)

	var wing := MeshInstance3D.new()
	wing.name = "PlaceholderWingBar"
	var wing_mesh := BoxMesh.new()
	wing_mesh.size = Vector3(0.95, 0.04, 0.28)
	wing.mesh = wing_mesh
	wing.position = Vector3(0.0, -0.01, 0.12)
	wing.material_override = _dark_material
	parent.add_child(wing)


func _make_glow(glow_name: String, material: Material, radius: float) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0

	var glow := MeshInstance3D.new()
	glow.name = glow_name
	glow.mesh = mesh
	glow.material_override = material
	return glow


func _update_lights(craft: Node3D, flight: Dictionary, t: float) -> void:
	var blink := 0.45 + 0.55 * absf(sin(float(flight["elapsed"]) * float(flight["blink_speed"]) + float(flight["blink_phase"])))
	var engine_pulse := 0.72 + 0.28 * sin(t * TAU * 3.0 + float(flight["blink_phase"]))
	var nav_light := craft.get_node_or_null("NavLight_Cyan") as MeshInstance3D
	var beacon := craft.get_node_or_null("Beacon_Warm") as MeshInstance3D
	var engine := craft.get_node_or_null("EngineGlow") as MeshInstance3D
	if nav_light != null:
		nav_light.scale = Vector3.ONE * lerpf(0.75, 1.25, blink)
	if beacon != null:
		beacon.scale = Vector3.ONE * lerpf(0.55, 1.35, 1.0 - blink)
	if engine != null:
		engine.scale = Vector3(0.7, 0.7, 1.8) * engine_pulse


func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var inv := 1.0 - t
	return p0 * inv * inv * inv + p1 * 3.0 * inv * inv * t + p2 * 3.0 * inv * t * t + p3 * t * t * t


func _build_materials() -> void:
	_hull_material = _make_material(Color(0.08, 0.095, 0.12, 1.0), Color(0.0, 0.0, 0.0, 1.0), 0.0)
	_dark_material = _make_material(Color(0.015, 0.018, 0.025, 1.0), Color(0.0, 0.0, 0.0, 1.0), 0.0)
	_engine_material = _make_material(Color(0.25, 0.72, 1.0, 1.0), Color(0.08, 0.48, 1.0, 1.0), engine_glow_energy)
	_nav_cyan_material = _make_material(Color(0.1, 0.9, 1.0, 1.0), Color(0.02, 0.65, 0.9, 1.0), nav_light_energy)
	_nav_warm_material = _make_material(Color(1.0, 0.56, 0.16, 1.0), Color(0.95, 0.32, 0.04, 1.0), nav_light_energy)


func _make_material(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = 0.82
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material
