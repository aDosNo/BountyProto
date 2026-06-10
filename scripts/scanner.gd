extends Node3D
## Scanner — hold-RMB scan. Handles two target kinds:
##  - "scanner_clue"   (ClueObject — legacy chain / scene clues)
##  - "scannable_npc"  (CrowdNPC — identity funnel)

@export var scan_range: float = 25.0
@export var scan_time_required: float = 1.5
@export var scan_decay_speed: float = 2.0

var scanner_active: bool = false
var current_scan_progress: float = 0.0

var _camera: Camera3D
var _hud: CanvasLayer
var _shooter: CollisionObject3D
var _focused_target: Node
var _was_active_last_frame: bool = false
var _completed_clues: Dictionary = {}


func setup(camera: Camera3D, hud: CanvasLayer, shooter: CollisionObject3D = null) -> void:
	_camera = camera
	_hud = hud
	_shooter = shooter
	_set_hud_active(false)


func _physics_process(delta: float) -> void:
	scanner_active = Input.is_action_pressed("scan")

	if scanner_active and not _was_active_last_frame:
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
	var target := _extract_scannable(hit)

	if target == null:
		_clear_focus()
		current_scan_progress = maxf(current_scan_progress - (scan_decay_speed * delta), 0.0)
		_set_hud_text("NO TRACE")
		_set_hud_progress(current_scan_progress / scan_time_required)
		return

	if target != _focused_target:
		_clear_focus()
		_focused_target = target
		current_scan_progress = 0.0
		if target.has_method("begin_focus"):
			target.call("begin_focus")

	_set_hud_text(_get_scan_text(target))
	if target.has_method("scan"):
		var previous_progress := current_scan_progress
		var progress := target.call("scan", delta) as float
		current_scan_progress = progress
		if previous_progress < scan_time_required and progress >= scan_time_required:
			_on_scan_completed(target)
	else:
		current_scan_progress = minf(current_scan_progress + delta, scan_time_required)

	_set_hud_progress(current_scan_progress / scan_time_required)


func _extract_scannable(hit: Dictionary) -> Node:
	if hit.is_empty():
		return null

	var collider := hit["collider"] as Node
	if collider == null:
		return null

	var candidate: Node = collider
	while candidate != null:
		if candidate.has_method("is_scannable") and candidate.call("is_scannable"):
			if candidate.is_in_group("scanner_clue") or candidate.is_in_group("scannable_npc"):
				return candidate
		candidate = candidate.get_parent()

	return null


func _on_scan_completed(target: Node) -> void:
	if target.is_in_group("scannable_npc"):
		_show_npc_readout(target)
		return
	_show_clue_completed(target)


func _show_npc_readout(npc: Node) -> void:
	if _hud == null or not _hud.has_method("show_toast"):
		return
	var intel := get_node_or_null("/root/BountyIntel")
	if intel != null and intel.has_method("build_readout"):
		_hud.call("show_toast", intel.call("build_readout", npc), 4.5)
	else:
		_hud.call("show_toast", "Subject scanned.", 2.4)


func _clear_focus() -> void:
	if _focused_target != null and _focused_target.has_method("end_focus"):
		_focused_target.call("end_focus")
	_focused_target = null
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


func _get_scan_text(target: Node) -> String:
	if target != null and target.has_method("get_scan_text"):
		var text := target.call("get_scan_text") as String
		if not text.is_empty():
			return text
	return "SCANNING..."


func _show_clue_completed(clue: Node) -> void:
	var clue_key := _get_clue_id(clue)
	if _completed_clues.has(clue_key):
		return
	_completed_clues[clue_key] = true

	if _hud == null or not _hud.has_method("show_toast"):
		return

	var text := "Trace logged."
	if clue != null and clue.has_method("get_completed_text"):
		var completed_text := clue.call("get_completed_text") as String
		if not completed_text.is_empty():
			text = completed_text
	_hud.call("show_toast", text)
