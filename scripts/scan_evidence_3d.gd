extends Area3D
## Runtime physical evidence configured by InvestigationDirector.

signal evidence_scanned(evidence_id: String, lead_id: String)

@onready var collision_shape: CollisionShape3D = %CollisionShape3D
@onready var visual_root: Node3D = %VisualRoot
@onready var scan_label: Label3D = %ScanLabel

var evidence_id := ""
var definition_id := ""
var lead_id := ""
var evidence_kind := ""
var trait_category := ""
var resolved_value := ""
var zone_label := ""
var scan_text := "Analyzing trace..."
var completed_text := "Evidence verified."
var scan_time_required := 1.5
var is_completed := false
var followup_anchor_id := ""
var followup_zone_label := ""
var followup_world_position := Vector3.ZERO
var _scan_progress := 0.0
var _swept_timer := 0.0
var _visual_meshes: Array[MeshInstance3D] = []
var _base_material: StandardMaterial3D
var _swept_material: StandardMaterial3D
var _completed_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("scanner_evidence")
	_build_materials()
	scan_label.visible = false


func configure(definition: Dictionary, profile: Dictionary, anchor: Node3D, runtime_lead_id: String) -> void:
	definition_id = String(definition.get("definition_id", "evidence"))
	lead_id = runtime_lead_id
	evidence_id = "%s@%s" % [definition_id, String(anchor.get("anchor_id"))]
	evidence_kind = String(definition.get("evidence_kind", "trace"))
	trait_category = String(definition.get("trait_category", ""))
	var value_source := String(definition.get("value_source", trait_category))
	resolved_value = String(profile.get(value_source, "unknown"))
	zone_label = String(anchor.get("zone_label"))
	scan_text = String(definition.get("scan_text", "Analyzing trace..."))
	completed_text = String(definition.get("result_template", "Evidence confirms: %s.")) % resolved_value
	followup_anchor_id = String(anchor.get("followup_anchor_id"))
	if not followup_anchor_id.is_empty() and anchor.has_method("get_followup_position"):
		followup_world_position = anchor.call("get_followup_position")
	if not followup_anchor_id.is_empty() and anchor.has_method("get_followup_zone"):
		followup_zone_label = String(anchor.call("get_followup_zone"))
	if evidence_kind == "footprint_trail" and not followup_zone_label.is_empty():
		completed_text += " Trail continues toward %s." % followup_zone_label
	global_transform = anchor.global_transform
	_build_materials()
	_build_visuals(anchor)


func _process(delta: float) -> void:
	if _swept_timer <= 0.0:
		return
	_swept_timer = maxf(_swept_timer - delta, 0.0)
	if _swept_timer == 0.0 and not is_completed:
		_apply_material(_base_material)
		scan_label.visible = false


func is_scannable() -> bool:
	return not is_completed


func begin_focus() -> void:
	if is_completed:
		return
	scan_label.text = "HOLD RMB • ANALYZE TRACE"
	scan_label.visible = true
	_apply_material(_swept_material)


func end_focus() -> void:
	_scan_progress = 0.0
	if is_completed:
		return
	if _swept_timer > 0.0:
		scan_label.text = "TRACE • HOLD RMB"
		scan_label.visible = true
	else:
		scan_label.visible = false
		_apply_material(_base_material)


func mark_swept(duration: float) -> void:
	if is_completed:
		return
	_swept_timer = maxf(_swept_timer, duration)
	scan_label.text = "TRACE • HOLD RMB"
	scan_label.visible = true
	_apply_material(_swept_material)


func is_swept() -> bool:
	return _swept_timer > 0.0


func scan(delta: float) -> float:
	if is_completed:
		return scan_time_required
	_scan_progress = minf(_scan_progress + delta, scan_time_required)
	if _scan_progress >= scan_time_required:
		_complete_scan()
	return _scan_progress


func get_scan_text() -> String:
	return scan_text


func get_scan_time_required() -> float:
	return scan_time_required


func get_completed_text() -> String:
	return completed_text


func _complete_scan() -> void:
	if is_completed:
		return
	is_completed = true
	collision_shape.set_deferred("disabled", true)
	scan_label.text = "EVIDENCE VERIFIED"
	scan_label.visible = true
	if evidence_kind == "footprint_trail" and not followup_zone_label.is_empty():
		scan_label.text = "TRAIL CONTINUES • %s" % followup_zone_label.to_upper()
	_apply_material(_completed_material)
	get_tree().call_group("investigation_director", "verify_evidence", self)
	evidence_scanned.emit(evidence_id, lead_id)


func _build_visuals(anchor: Node3D) -> void:
	for child in visual_root.get_children():
		child.queue_free()
	_visual_meshes.clear()
	match evidence_kind:
		"footprint_trail":
			_build_footprints(anchor)
		"fiber":
			_build_fibers()
		"delivery_trace":
			_build_delivery_trace()
		"tech_residue":
			_build_tech_residue()
		_:
			_build_delivery_trace()
	_apply_material(_base_material)


func _build_footprints(anchor: Node3D) -> void:
	var local_points := PackedVector3Array()
	if anchor.has_method("world_trail_points"):
		var points: PackedVector3Array = anchor.call("world_trail_points")
		for point in points:
			local_points.append(to_local(point))
	if local_points.size() < 2:
		for index in range(8):
			local_points.append(Vector3.FORWARD * float(index) * 0.72)
	var overall_direction := (local_points[-1] - local_points[0]).normalized()
	var lateral_direction := Vector3(-overall_direction.z, 0.0, overall_direction.x)
	for index in range(local_points.size()):
		var print_mesh := MeshInstance3D.new()
		print_mesh.name = "Footprint_%02d" % index
		var box := BoxMesh.new()
		var heavy := resolved_value == "heavy gait"
		box.size = Vector3(0.28 if heavy else 0.22, 0.025, 0.48 if heavy else 0.38)
		print_mesh.mesh = box
		var lateral := -0.18 if index % 2 == 0 else 0.18
		print_mesh.position = local_points[index] + lateral_direction * lateral + Vector3.UP * 0.025
		print_mesh.rotation.y = atan2(-overall_direction.x, -overall_direction.z)
		visual_root.add_child(print_mesh)
		_visual_meshes.append(print_mesh)
	var first := local_points[0]
	var last := local_points[local_points.size() - 1]
	var midpoint := first.lerp(last, 0.5)
	var length := maxf(first.distance_to(last), 1.5)
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 0.25, length + 0.6)
	collision_shape.shape = shape
	collision_shape.position = midpoint + Vector3.UP * 0.1


func _build_fibers() -> void:
	for index in range(3):
		var fiber := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.06, 0.025, 0.42)
		fiber.mesh = box
		fiber.position = Vector3(float(index - 1) * 0.08, 0.04, float(index) * 0.09)
		fiber.rotation.y = float(index) * 0.55
		visual_root.add_child(fiber)
		_visual_meshes.append(fiber)
	_set_point_collision(Vector3(0.8, 0.6, 0.8))


func _build_delivery_trace() -> void:
	var receipt := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.62, 0.035, 0.42)
	receipt.mesh = box
	receipt.position = Vector3.UP * 0.04
	visual_root.add_child(receipt)
	_visual_meshes.append(receipt)
	_set_point_collision(Vector3(1.0, 0.7, 1.0))


func _build_tech_residue() -> void:
	for index in range(4):
		var residue := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.18, 0.025, 0.18)
		residue.mesh = box
		residue.position = Vector3(cos(float(index) * 1.57), 0.04, sin(float(index) * 1.57)) * 0.22
		visual_root.add_child(residue)
		_visual_meshes.append(residue)
	_set_point_collision(Vector3(0.9, 0.7, 0.9))


func _set_point_collision(size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	collision_shape.shape = shape
	collision_shape.position = Vector3.UP * 0.3


func _build_materials() -> void:
	_base_material = StandardMaterial3D.new()
	_base_material.albedo_color = _natural_color()
	_base_material.roughness = 0.92
	_swept_material = StandardMaterial3D.new()
	_swept_material.albedo_color = Color(0.14, 0.78, 1.0, 1.0)
	_swept_material.emission_enabled = true
	_swept_material.emission = Color(0.02, 0.52, 0.9)
	_swept_material.emission_energy_multiplier = 2.0
	_completed_material = StandardMaterial3D.new()
	_completed_material.albedo_color = Color(0.18, 0.72, 0.38, 1.0)
	_completed_material.emission_enabled = true
	_completed_material.emission = Color(0.03, 0.35, 0.12)
	_completed_material.emission_energy_multiplier = 0.8


func _natural_color() -> Color:
	match evidence_kind:
		"footprint_trail":
			return Color(0.11, 0.075, 0.055, 0.92)
		"fiber":
			if resolved_value.contains("red"):
				return Color(0.38, 0.045, 0.04, 1.0)
			return Color(0.2, 0.18, 0.16, 1.0)
		"tech_residue":
			return Color(0.08, 0.24, 0.28, 1.0)
		_:
			return Color(0.3, 0.27, 0.2, 1.0)


func _apply_material(material: Material) -> void:
	for mesh in _visual_meshes:
		mesh.set_surface_override_material(0, material)
