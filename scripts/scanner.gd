extends Node3D

@export var scan_range: float = 25.0
@export var scan_time_required: float = 1.5
@export var scan_decay_speed: float = 2.0

var scanner_active: bool = false
var current_scan_progress: float = 0.0

var _camera: Camera3D
var _hud: CanvasLayer
var _shooter: CollisionObject3D
var _focused_clue: Node
var _was_active_last_frame: bool = false


func setup(camera: Camera3D, hud: CanvasLayer, shooter: CollisionObject3D = null) -> void:
	_camera = camera
	_hud = hud
	_shooter = shooter
	_set_hud_active(false)


func _physics_process(delta: float) -> void:
	scanner_active = Input.is_action_pressed("scan")

	if scanner_active and not _was_active_last_frame:
		print("Scanner active")
		_set_hud_active(true)

	if not scanner_active:
		if _was_active_last_frame:
			_clear_focus()
			_set_hud_active(false)
		_was_active_last_frame = false
		return

	_was_active_last_frame = true
	_scan_forward(delta)


func _scan_forward(delta: float) -> void:
	if _camera == null:
		return

	var from := _camera.global_position
	var to := from + (-_camera.global_transform.basis.z * scan_range)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	if _shooter != null:
		query.exclude = [_shooter.get_rid()]
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var clue := _extract_scannable_clue(hit)

	if clue == null:
		_clear_focus()
		current_scan_progress = maxf(current_scan_progress - (scan_decay_speed * delta), 0.0)
		_set_hud_text("NO TRACE")
		_set_hud_progress(current_scan_progress / scan_time_required)
		return

	if clue != _focused_clue:
		_clear_focus()
		_focused_clue = clue
		current_scan_progress = 0.0
		if clue.has_method("begin_focus"):
			clue.call("begin_focus")
		print("Scanning clue: %s" % _get_clue_id(clue))

	_set_hud_text("SCANNING...")
	if clue.has_method("scan"):
		var progress := clue.call("scan", delta) as float
		current_scan_progress = progress
	else:
		current_scan_progress = minf(current_scan_progress + delta, scan_time_required)

	_set_hud_progress(current_scan_progress / scan_time_required)


func _extract_scannable_clue(hit: Dictionary) -> Node:
	if hit.is_empty():
		return null

	var collider := hit["collider"] as Node
	if collider == null:
		return null

	var candidate: Node = collider
	while candidate != null:
		if candidate.is_in_group("scanner_clue") and candidate.has_method("is_scannable") and candidate.call("is_scannable"):
			return candidate
		candidate = candidate.get_parent()

	return null


func _clear_focus() -> void:
	if _focused_clue != null and _focused_clue.has_method("end_focus"):
		_focused_clue.call("end_focus")
	_focused_clue = null
	current_scan_progress = 0.0


func _set_hud_active(active: bool) -> void:
	if _hud == null:
		return
	if _hud.has_method("set_scanner_active"):
		_hud.call("set_scanner_active", active)
	if not active:
		if _hud.has_method("set_scanner_text"):
			_hud.call("set_scanner_text", "")
		if _hud.has_method("set_scan_progress"):
			_hud.call("set_scan_progress", 0.0)
	else:
		_set_hud_text("SCANNER ACTIVE")


func _set_hud_text(text: String) -> void:
	if _hud != null and _hud.has_method("set_scanner_text"):
		_hud.call("set_scanner_text", text)


func _set_hud_progress(value: float) -> void:
	if _hud != null and _hud.has_method("set_scan_progress"):
		_hud.call("set_scan_progress", clampf(value, 0.0, 1.0))


func _get_clue_id(clue: Node) -> String:
	var clue_value = clue.get("clue_id")
	if clue_value is String:
		return clue_value
	return str(clue)
