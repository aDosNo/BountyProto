extends StaticBody3D

signal clue_scanned(clue_id: String, next_clue_id: String, reveals_target: bool)

@export var clue_id: String = ""
@export var next_clue_id: String = ""
@export var scan_text: String = "Trace detected."
@export var completed_text: String = "Trace logged."
@export var scan_time_required: float = 1.5
@export var reveals_target: bool = false
@export var active: bool = false

@onready var mesh: MeshInstance3D = %ClueMesh
@onready var clue_light: OmniLight3D = %ClueLight
@onready var label: Label3D = %DebugLabel
@onready var collision_shape: CollisionShape3D = %CollisionShape3D

var is_completed: bool = false
var _scan_progress: float = 0.0
var _base_material: Material


func _ready() -> void:
	add_to_group("scanner_clue")
	_base_material = mesh.get_active_material(0)
	set_active(active)


func set_active(new_active: bool) -> void:
	active = new_active
	if is_completed:
		visible = true
		collision_shape.disabled = true
		return

	visible = active
	collision_shape.disabled = not active
	clue_light.visible = active
	label.visible = active


func is_scannable() -> bool:
	return active and not is_completed


func begin_focus() -> void:
	if not is_scannable():
		return
	clue_light.light_energy = 2.2
	label.text = "HOLD RMB TO SCAN"


func end_focus() -> void:
	if not is_completed:
		clue_light.light_energy = 1.2
		label.text = "SCAN TRACE"


func scan(delta: float) -> float:
	if not is_scannable():
		return 0.0

	_scan_progress = minf(_scan_progress + delta, scan_time_required)
	if _scan_progress >= scan_time_required:
		_complete_scan()

	return _scan_progress


func get_scan_text() -> String:
	return scan_text


func get_completed_text() -> String:
	return completed_text


func _complete_scan() -> void:
	if is_completed:
		return

	is_completed = true
	active = false
	collision_shape.disabled = true
	clue_light.light_color = Color(0.35, 1.0, 0.55)
	clue_light.light_energy = 1.0
	label.text = "SCAN COMPLETE"

	var completed_material := StandardMaterial3D.new()
	completed_material.albedo_color = Color(0.22, 0.9, 0.42)
	completed_material.emission_enabled = true
	completed_material.emission = Color(0.08, 0.45, 0.16)
	completed_material.emission_energy_multiplier = 0.85
	mesh.set_surface_override_material(0, completed_material)

	print("Clue scanned: %s" % clue_id)
	clue_scanned.emit(clue_id, next_clue_id, reveals_target)
