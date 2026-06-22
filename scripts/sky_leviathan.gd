extends Node
## Visual-only driver for the distant sky-leviathans — slow drifting
## bioluminescent creatures far above the Hesperus skyline.
##
## Each leviathan is a "Leviathan_Pivot_N" Node3D (with a child mesh) baked into
## the DistantCity GLB. This script finds them by name anywhere in the scene and:
##   * drifts each along a slow, gently-curving loop high over the map,
##   * adds a faint bob + roll + pitch so the body undulates like something alive,
##   * pulses the bioluminescent glow materials so the creatures "breathe."
## Pure set-dressing: no collision, never reachable, cheap.

@export var pivot_prefix: String = "Leviathan_Pivot_"

@export_group("Drift")
## Horizontal radius of each creature's slow looping path.
@export var drift_radius_range: Vector2 = Vector2(28.0, 55.0)
## Seconds for one full loop (very slow — these are huge, distant things).
@export var drift_period_range: Vector2 = Vector2(95.0, 160.0)
## Vertical bob amount (units) and how much the body rolls/pitches as it moves.
@export var bob_amplitude_range: Vector2 = Vector2(3.0, 7.0)
@export var roll_degrees: float = 8.0
@export var pitch_degrees: float = 5.0

@export_group("Bioluminescence")
@export var glow_material_prefix: String = "M_LevGlow"
@export var glow_min_energy: float = 1.6
@export var glow_max_energy: float = 4.6
## Seconds per breath pulse (slow, organic).
@export var glow_period_range: Vector2 = Vector2(4.0, 8.0)

@export_group("High Clouds")
## Mesh name of the high-atmosphere cloud deck baked into the city GLB.
@export var cloud_mesh_name: String = "DistantCity_Clouds"
## Very slow lateral drift of the cloud deck (units/sec) and how far it travels
## before wrapping back to its origin, so the weather feels like it's moving.
@export var cloud_drift_speed: float = 2.2
@export var cloud_drift_axis: Vector3 = Vector3(1.0, 0.0, 0.25)
@export var cloud_drift_distance: float = 120.0
## Noise cloud shader swapped onto the deck at runtime (replaces the imported
## placeholder material so the rectangular quads read as soft vapor).
@export var cloud_shader: Shader = preload("res://shaders/sky_cloud.gdshader")
@export var cloud_color: Color = Color(0.62, 0.55, 0.70)
@export var cloud_shadow: Color = Color(0.12, 0.10, 0.18)
@export var cloud_density: float = 0.9
@export var cloud_coverage: float = 0.5
@export var cloud_noise_scale: float = 3.0

@export_group("Floating Billboards")
## Billboard pivots (Billboard_Pivot_N) baked into the city GLB — stationary
## neon signs held aloft by levitation thrusters, gently bobbing.
@export var billboard_prefix: String = "Billboard_Pivot_"
## Vertical bob height (units) and seconds per bob cycle.
@export var billboard_bob_range: Vector2 = Vector2(0.4, 0.9)
@export var billboard_period_range: Vector2 = Vector2(3.5, 6.5)
## Tiny drift/sway (units) so the levitation reads as not perfectly locked.
@export var billboard_sway: float = 0.25
## Subtle yaw wobble in degrees as the thrusters correct.
@export var billboard_yaw_wobble_degrees: float = 1.5

var _creatures: Array[Dictionary] = []
var _glow_mats: Array[Dictionary] = []
var _billboards: Array[Dictionary] = []
var _cloud: Node3D = null
var _cloud_home: Vector3 = Vector3.ZERO
var _t: float = 0.0


func _ready() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	_collect(root)
	if _cloud != null:
		_cloud_home = _cloud.position
	set_process(not _creatures.is_empty() or not _glow_mats.is_empty() or _cloud != null or not _billboards.is_empty())


func _collect(node: Node) -> void:
	if node is Node3D and node.name.begins_with(pivot_prefix):
		_register_creature(node as Node3D)
	if node is Node3D and node.name.begins_with(billboard_prefix):
		_register_billboard(node as Node3D)
	if node is Node3D and node.name == cloud_mesh_name:
		_cloud = node as Node3D
		if node is MeshInstance3D:
			_apply_cloud_shader(node as MeshInstance3D)
	# Gather glow materials off any mesh under a leviathan so we can pulse them.
	if node is MeshInstance3D:
		_harvest_glow_materials(node as MeshInstance3D)
	for child in node.get_children():
		_collect(child)


func _register_billboard(pivot: Node3D) -> void:
	_billboards.append({
		"node": pivot,
		"home": pivot.position,
		"base_yaw": pivot.rotation.y,
		"bob": randf_range(billboard_bob_range.x, billboard_bob_range.y),
		"period": randf_range(billboard_period_range.x, billboard_period_range.y),
		"phase": randf_range(0.0, TAU),
		"sway_phase": randf_range(0.0, TAU),
	})


func _apply_cloud_shader(mesh: MeshInstance3D) -> void:
	# Replace the imported placeholder material on every cloud surface with a
	# ShaderMaterial running the noise cloud shader, tinted from the inspector.
	if cloud_shader == null:
		return
	var sm := ShaderMaterial.new()
	sm.shader = cloud_shader
	sm.set_shader_parameter("cloud_color", cloud_color)
	sm.set_shader_parameter("cloud_shadow", cloud_shadow)
	sm.set_shader_parameter("density", cloud_density)
	sm.set_shader_parameter("coverage", cloud_coverage)
	sm.set_shader_parameter("noise_scale", cloud_noise_scale)
	var count := mesh.mesh.get_surface_count() if mesh.mesh != null else 0
	for i in range(count):
		mesh.set_surface_override_material(i, sm)


func _register_creature(pivot: Node3D) -> void:
	_creatures.append({
		"node": pivot,
		"home": pivot.position,
		"radius": randf_range(drift_radius_range.x, drift_radius_range.y),
		"period": randf_range(drift_period_range.x, drift_period_range.y),
		"phase": randf_range(0.0, TAU),
		"bob": randf_range(bob_amplitude_range.x, bob_amplitude_range.y),
		"bob_phase": randf_range(0.0, TAU),
		"dir": 1.0 if randf() > 0.5 else -1.0,  # some loop clockwise, some not
	})


func _harvest_glow_materials(mesh: MeshInstance3D) -> void:
	# A joined leviathan mesh has multiple surfaces; the glow surfaces use a
	# material whose resource name starts with M_LevGlow. Duplicate each so we
	# can animate emission without touching other meshes that share it.
	var count := mesh.mesh.get_surface_count() if mesh.mesh != null else 0
	for i in range(count):
		var src := mesh.mesh.surface_get_material(i)
		if src == null:
			src = mesh.get_active_material(i)
		if src is StandardMaterial3D and src.resource_name.begins_with(glow_material_prefix):
			var dup := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			dup.emission_enabled = true
			mesh.set_surface_override_material(i, dup)
			_glow_mats.append({
				"mat": dup,
				"period": randf_range(glow_period_range.x, glow_period_range.y),
				"phase": randf_range(0.0, TAU),
			})


func _process(delta: float) -> void:
	_t += delta

	for c in _creatures:
		var node := c["node"] as Node3D
		var home: Vector3 = c["home"]
		var w := TAU / float(c["period"])
		var a := _t * w * float(c["dir"]) + float(c["phase"])
		var r: float = c["radius"]
		# Slow horizontal loop (ellipse — wider than deep), plus vertical bob.
		var offset := Vector3(cos(a) * r, sin(_t * 0.12 + float(c["bob_phase"])) * float(c["bob"]), sin(a) * r * 0.7)
		node.position = home + offset
		# Face roughly along travel direction (tangent of the loop).
		var tangent := Vector3(-sin(a), 0.0, cos(a) * 0.7) * float(c["dir"])
		if tangent.length() > 0.001:
			var target := node.position + tangent
			node.look_at(target, Vector3.UP)
		# Gentle undulation on top of facing.
		node.rotate_object_local(Vector3.FORWARD, deg_to_rad(roll_degrees) * sin(_t * 0.5 + float(c["phase"])))
		node.rotate_object_local(Vector3.RIGHT, deg_to_rad(pitch_degrees) * sin(_t * 0.37 + float(c["bob_phase"])))

	for g in _glow_mats:
		var mat := g["mat"] as StandardMaterial3D
		var s := 0.5 + 0.5 * sin(_t * (TAU / float(g["period"])) + float(g["phase"]))
		mat.emission_energy_multiplier = lerpf(glow_min_energy, glow_max_energy, s)

	# Floating billboards: stationary, gentle vertical bob + faint sway + yaw
	# wobble so they read as held aloft by imperfect levitation thrusters.
	for b in _billboards:
		var node := b["node"] as Node3D
		var home: Vector3 = b["home"]
		var w := TAU / float(b["period"])
		var bob := sin(_t * w + float(b["phase"])) * float(b["bob"])
		var sway_x := sin(_t * w * 0.6 + float(b["sway_phase"])) * billboard_sway
		var sway_z := cos(_t * w * 0.47 + float(b["sway_phase"])) * billboard_sway
		node.position = home + Vector3(sway_x, bob, sway_z)
		node.rotation.y = float(b["base_yaw"]) + deg_to_rad(billboard_yaw_wobble_degrees) * sin(_t * w * 0.5 + float(b["phase"]))

	# Drift the high cloud deck slowly along its axis, wrapping back so the
	# weather appears to move continuously across the sky.
	if _cloud != null and cloud_drift_distance > 0.0:
		var axis := cloud_drift_axis.normalized()
		var travelled := fmod(_t * cloud_drift_speed, cloud_drift_distance)
		# triangle wave so it eases out and back rather than snapping at the wrap
		var tri := travelled
		if travelled > cloud_drift_distance * 0.5:
			tri = cloud_drift_distance - travelled
		_cloud.position = _cloud_home + axis * tri
