extends Node3D
## VendorLockdown -- simple public-heat reaction for market stalls.
## Attach to a stall/root node. When heat trips, it drops cheap shutter panels
## over counters and tints awnings red so violence has visible world fallout.

@export var shutter_color: Color = Color(0.58, 0.05, 0.035, 1.0)
@export var shutter_emission: Color = Color(0.95, 0.08, 0.03, 1.0)
@export var awning_lockdown_color: Color = Color(0.24, 0.02, 0.018, 1.0)
@export var shutter_drop_time: float = 0.28
@export var add_lockdown_label: bool = true

var _locked_down := false
var _shutter_material: StandardMaterial3D
var _awning_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("vendor_lockdown")
	_shutter_material = _make_material(shutter_color, shutter_emission, 1.35)
	_awning_material = _make_material(awning_lockdown_color, Color(0.5, 0.02, 0.01), 0.55)


func set_lockdown(reason: String = "") -> void:
	if _locked_down:
		return
	_locked_down = true

	var counters := _find_nodes_by_name("_Counter")
	if counters.is_empty():
		counters = _find_nodes_by_name("Stall")

	for node in counters:
		if node is Node3D:
			_drop_shutter(node as Node3D)

	for awning in _find_nodes_by_name("_Awning"):
		if awning is MeshInstance3D:
			(awning as MeshInstance3D).set_surface_override_material(0, _awning_material)

	if add_lockdown_label:
		_add_lockdown_label(reason)
	print("Vendor lockdown: %s (%s)" % [name, reason])


func is_locked_down() -> bool:
	return _locked_down


func _drop_shutter(anchor: Node3D) -> void:
	var shutter := MeshInstance3D.new()
	shutter.name = "%s_LockdownShutter" % anchor.name

	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	shutter.mesh = mesh
	shutter.set_surface_override_material(0, _shutter_material)
	add_child(shutter)

	var basis := anchor.global_transform.basis
	var width := maxf(basis.x.length() * 1.08, 2.4)
	var depth := maxf(basis.z.length(), 0.8)
	var forward := -basis.z.normalized()
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD

	var closed_pos := anchor.global_position + forward * (depth * 0.58) + Vector3.UP * 1.35
	var open_pos := closed_pos + Vector3.UP * 1.25
	shutter.global_position = open_pos
	shutter.global_rotation = anchor.global_rotation
	shutter.scale = Vector3(width, 1.55, 0.08)

	var tween := create_tween()
	tween.tween_property(shutter, "global_position", closed_pos, shutter_drop_time)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _add_lockdown_label(reason: String) -> void:
	var label := Label3D.new()
	label.name = "LockdownLabel"
	label.text = "LOCKDOWN"
	label.font_size = 18
	label.modulate = Color(1.0, 0.18, 0.08, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	var center := _average_child_position()
	add_child(label)
	label.global_position = center + Vector3.UP * 3.0


func _average_child_position() -> Vector3:
	var count := 0
	var sum := Vector3.ZERO
	for child in get_children():
		if child is Node3D:
			sum += (child as Node3D).global_position
			count += 1
	if count == 0:
		return global_position
	return sum / float(count)


func _find_nodes_by_name(pattern: String) -> Array[Node]:
	var found: Array[Node] = []
	_collect_nodes_by_name(self, pattern, found)
	return found


func _collect_nodes_by_name(node: Node, pattern: String, found: Array[Node]) -> void:
	if node != self and node.name.contains(pattern):
		found.append(node)
	for child in node.get_children():
		_collect_nodes_by_name(child, pattern, found)


func _make_material(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = 0.78
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material
