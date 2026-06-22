extends Node3D
## Visual-only high-altitude CAPITAL-SHIP traffic for Hesperus — big, slow alien
## cargo haulers and warships crossing far above the skyline. Companion to
## air_traffic_controller.gd (which handles the small fast darting craft); this
## one builds much larger blocky organic-alien hulls, moves them slowly along
## long gentle bezier lanes, and gives them running lights + engine banks.
##
## Pure set-dressing: no collision, never reachable, cheap (a handful of ships).
## Placeholder hulls are built procedurally; assign a GLB to craft_scene later.

@export var craft_scene: PackedScene
@export var craft_count: int = 4
@export var rng_seed: int = 41207
@export var field_center: Vector3 = Vector3(40.0, 150.0, -10.0)
@export var field_radius: float = 240.0
@export var min_altitude: float = 120.0
@export var max_altitude: float = 185.0
## Slow: these are enormous. Long lane / low speed = barely-crawling drift.
@export var min_speed: float = 5.0
@export var max_speed: float = 11.0
@export var path_curve_amount: float = 60.0
@export var respawn_delay_range: Vector2 = Vector2(4.0, 18.0)
## Overall hull scale multiplier range — capital ships are big and varied.
@export var ship_scale_range: Vector2 = Vector2(2.6, 5.4)
@export var nav_light_energy: float = 2.2
@export var engine_glow_energy: float = 2.8
## Gentle banking only — massive ships don't roll hard.
@export var bank_amount_range: Vector2 = Vector2(0.01, 0.05)

var _rng := RandomNumberGenerator.new()
var _flights: Array[Dictionary] = []
var _hull_a: StandardMaterial3D       # main hull plating (dark alien chitin/metal)
var _hull_b: StandardMaterial3D       # secondary hull / underside (darker)
var _trim: StandardMaterial3D         # structural trim
var _engine_material: StandardMaterial3D
var _nav_warm_material: StandardMaterial3D
var _nav_cyan_material: StandardMaterial3D
var _window_material: StandardMaterial3D


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
		var next_position := _bezier(flight["p0"], flight["p1"], flight["p2"], flight["p3"], minf(t + 0.01, 1.0))
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
	var end_altitude := clampf(start_altitude + _rng.randf_range(-12.0, 14.0), min_altitude, max_altitude)
	var start_distance := field_radius * _rng.randf_range(0.82, 1.15)
	var end_distance := field_radius * _rng.randf_range(0.82, 1.15)
	var lateral_offset := _rng.randf_range(-field_radius * 0.3, field_radius * 0.3)
	var p0 := field_center + side * start_distance + tangent * lateral_offset
	var p3 := field_center - side * end_distance + tangent * _rng.randf_range(-field_radius * 0.3, field_radius * 0.3)
	p0.y = start_altitude
	p3.y = end_altitude

	var travel := p3 - p0
	var length := maxf(travel.length(), 1.0)
	# Gentle curve only — long sweeping lanes, not tight turns.
	var curve := tangent * _rng.randf_range(-path_curve_amount, path_curve_amount)
	curve += Vector3.UP * _rng.randf_range(-8.0, 10.0)
	var p1 := p0 + travel * _rng.randf_range(0.25, 0.4) + curve
	var p2 := p0 + travel * _rng.randf_range(0.6, 0.78) - curve * _rng.randf_range(0.4, 0.8)
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
		"blink_speed": _rng.randf_range(1.5, 3.5),  # slow, heavy beacons
		"bank_phase": _rng.randf_range(0.0, TAU),
		"bank_amount": _rng.randf_range(bank_amount_range.x, bank_amount_range.y),
	}


func _make_craft(index: int) -> Node3D:
	var craft := Node3D.new()
	craft.name = "CapitalShip_%02d" % index

	var visual_root := Node3D.new()
	visual_root.name = "VisualRoot"
	craft.add_child(visual_root)

	if craft_scene != null:
		visual_root.add_child(craft_scene.instantiate())
	else:
		_build_capital_hull(visual_root, _rng.randf_range(ship_scale_range.x, ship_scale_range.y), index)

	return craft


## Procedural alien capital-ship hull: a long segmented spine with a swollen
## forward mass, asymmetric dorsal/ventral fins, a slung command blister, hull
## window strips, and a cluster of engine bells at the stern. Built nose toward
## -Z (forward) so look_at orients it along travel. All children of `parent`.
func _build_capital_hull(parent: Node3D, ship_scale: float, index: int) -> void:
	parent.scale = Vector3.ONE * ship_scale
	var warship := (index % 2 == 0)  # alternate cargo vs warship silhouettes

	# --- main hull segments (tapered stack along Z) ---
	var seg_count := 3
	var z := 0.6
	var widths := [0.5, 0.74, 0.62] if not warship else [0.42, 0.66, 0.58]
	for s in range(seg_count):
		var w: float = float(widths[s]) * (1.15 if warship else 1.0)
		var seg := _box("Hull_%d" % s, Vector3(w, w * 0.6, 0.85), Vector3(0.0, 0.0, z - s * 0.8), _hull_a, parent)
		# slight vertical taper toward nose
		seg.scale.y *= lerpf(1.0, 0.8, float(s) / float(seg_count))
	# forward swollen mass / bridge prow
	_box("Prow", Vector3(0.46, 0.34, 0.7), Vector3(0.0, 0.03, -0.95), _hull_b, parent)
	# blunt nose cap
	_box("NoseCap", Vector3(0.3, 0.24, 0.34), Vector3(0.0, 0.02, -1.4), _trim, parent)

	# --- dorsal superstructure (asymmetric — alien, off-centre) ---
	_box("Dorsal_A", Vector3(0.26, 0.4, 0.9), Vector3(0.08, 0.42, 0.1), _hull_b, parent)
	if warship:
		# warship: tall sensor/weapon mast + side sponsons
		_box("Mast", Vector3(0.08, 0.7, 0.12), Vector3(-0.05, 0.78, -0.1), _trim, parent)
		_box("Sponson_L", Vector3(0.18, 0.16, 0.5), Vector3(-0.62, 0.0, 0.2), _hull_b, parent)
		_box("Sponson_R", Vector3(0.18, 0.16, 0.5), Vector3(0.62, 0.0, 0.2), _hull_b, parent)
	else:
		# cargo: stacked container blocks along the spine
		for c in range(3):
			_box("Cargo_%d" % c, Vector3(0.5, 0.26, 0.36), Vector3(0.0, 0.4, 0.5 - c * 0.5), _hull_a, parent)

	# --- ventral slung command blister ---
	_box("Belly", Vector3(0.34, 0.22, 0.6), Vector3(-0.04, -0.36, -0.2), _hull_b, parent)

	# --- asymmetric fins ---
	_box("Fin_Dorsal", Vector3(0.05, 0.5, 0.6), Vector3(0.0, 0.5, 1.0), _trim, parent)
	_box("Fin_Port", Vector3(0.6, 0.05, 0.4), Vector3(-0.5, -0.05, 0.95), _trim, parent)
	_box("Fin_Stbd", Vector3(0.48, 0.05, 0.36), Vector3(0.46, 0.08, 0.98), _trim, parent)

	# --- hull window strips (faint warm interior glow) ---
	_box("Windows_L", Vector3(0.02, 0.06, 1.1), Vector3(-0.37, 0.08, 0.0), _window_material, parent)
	_box("Windows_R", Vector3(0.02, 0.06, 0.9), Vector3(0.37, 0.05, 0.1), _window_material, parent)
	_box("Windows_Prow", Vector3(0.3, 0.04, 0.02), Vector3(0.0, 0.12, -1.25), _window_material, parent)

	# --- engine bank at the stern (cluster of bells) ---
	var engine_z := 1.05
	var bell_positions := [Vector3(-0.18, 0.0, engine_z), Vector3(0.18, 0.0, engine_z),
						   Vector3(0.0, 0.2, engine_z), Vector3(0.0, -0.16, engine_z)]
	for bi in range(bell_positions.size()):
		var bell := _box("EngineBell_%d" % bi, Vector3(0.16, 0.16, 0.18), bell_positions[bi], _trim, parent)
		var glow := _make_glow("EngineGlow_%d" % bi, _engine_material, 0.12)
		glow.position = bell_positions[bi] + Vector3(0.0, 0.0, 0.16)
		glow.scale = Vector3(0.9, 0.9, 1.6)
		parent.add_child(glow)

	# --- running lights (slow beacons): port red-warm, starboard cyan ---
	var nav_warm := _make_glow("NavWarm", _nav_warm_material, 0.07)
	nav_warm.position = Vector3(-0.6, 0.0, 0.2)
	parent.add_child(nav_warm)
	var nav_cyan := _make_glow("NavCyan", _nav_cyan_material, 0.07)
	nav_cyan.position = Vector3(0.6, 0.0, 0.2)
	parent.add_child(nav_cyan)
	# dorsal beacon
	var beacon := _make_glow("Beacon", _nav_warm_material, 0.06)
	beacon.position = Vector3(0.0, 0.62, 0.1)
	parent.add_child(beacon)


func _box(box_name: String, size: Vector3, pos: Vector3, material: Material, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = box_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = material
	parent.add_child(mi)
	return mi


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
	var visual := craft.get_node_or_null("VisualRoot")
	if visual == null:
		return
	var blink := 0.4 + 0.6 * absf(sin(float(flight["elapsed"]) * float(flight["blink_speed"]) + float(flight["blink_phase"])))
	var engine_pulse := 0.78 + 0.22 * sin(t * TAU * 2.0 + float(flight["blink_phase"]))
	for child in visual.get_children():
		if child is MeshInstance3D:
			var n := (child as MeshInstance3D).name
			if n.begins_with("EngineGlow"):
				(child as MeshInstance3D).scale = Vector3(0.9, 0.9, 1.6) * engine_pulse
			elif n == "NavWarm" or n == "Beacon":
				(child as MeshInstance3D).scale = Vector3.ONE * lerpf(0.6, 1.3, blink)
			elif n == "NavCyan":
				(child as MeshInstance3D).scale = Vector3.ONE * lerpf(0.6, 1.3, 1.0 - blink)


func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var inv := 1.0 - t
	return p0 * inv * inv * inv + p1 * 3.0 * inv * inv * t + p2 * 3.0 * inv * t * t + p3 * t * t * t


func _build_materials() -> void:
	# Dark alien hull tones matching the city's dark blue-grey palette.
	_hull_a = _make_material(Color(0.06, 0.07, 0.09, 1.0), Color.BLACK, 0.0, 0.85)
	_hull_b = _make_material(Color(0.035, 0.045, 0.06, 1.0), Color.BLACK, 0.0, 0.9)
	_trim = _make_material(Color(0.05, 0.055, 0.07, 1.0), Color.BLACK, 0.0, 0.7)
	_engine_material = _make_material(Color(0.3, 0.6, 1.0, 1.0), Color(0.1, 0.4, 1.0, 1.0), engine_glow_energy)
	_nav_warm_material = _make_material(Color(1.0, 0.4, 0.2, 1.0), Color(0.95, 0.2, 0.05, 1.0), nav_light_energy)
	_nav_cyan_material = _make_material(Color(0.2, 0.9, 1.0, 1.0), Color(0.05, 0.6, 0.9, 1.0), nav_light_energy)
	# faint warm interior windows
	_window_material = _make_material(Color(0.04, 0.03, 0.02, 1.0), Color(1.0, 0.6, 0.25, 1.0), 1.6)


func _make_material(albedo: Color, emission: Color, energy: float, rough: float = 0.82) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = rough
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material
