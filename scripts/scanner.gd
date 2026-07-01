extends Node3D
## Scanner — the investigation verb (hybrid; see 05_INVESTIGATION_LAYER_BRIDGE C).
## One input (`scan`, RMB) carries two verbs:
##   SWEEP    — TAP: a forward cone pulse. Lights every scannable_npc / scanner_clue
##              that still matches the VISIBLE traits the player knows (amber
##              marker). Free, wide, confirms nothing. Gated: needs >=1 visible
##              trait known. Shortlist generator.
##   ANALYSIS — HOLD on one focused target: the per-trait readout (signature
##              resolves last). Costs cover — emits a suspicion ping into guard
##              perception scaled by hold time and whether the player is blended.
## Targets: "scanner_clue" (ClueObject) and "scannable_npc" (CrowdNPC).

@export_group("Sweep")
@export var sweep_range: float = 22.0
@export var sweep_half_angle_degrees: float = 35.0
@export var sweep_mark_duration: float = 6.0
## Press shorter than this (and not yet analyzing) = a SWEEP tap. Longer = ANALYSIS.
@export var sweep_tap_threshold: float = 0.2

@export_group("Analysis")
@export var analysis_range: float = 25.0
@export var scan_time_required: float = 1.5
@export var scan_decay_speed: float = 2.0
## Cover cost (C.3): while analysis is held, ping guard perception every
## suspicion_tick at the focused target's position. Radius scales with hold time
## (1.0 -> hold_scale_max over scan_time_required) and shrinks when blended.
@export var analysis_base_radius: float = 8.0
@export var analysis_blended_factor: float = 0.35
@export var analysis_hold_scale_max: float = 2.0
@export var suspicion_tick: float = 0.35

var scanner_active: bool = false
var current_scan_progress: float = 0.0

var _camera: Camera3D
var _hud: CanvasLayer
var _shooter: CollisionObject3D
var _player: Node3D
var _focused_target: Node
var _was_active_last_frame: bool = false
var _completed_clues: Dictionary = {}
var _press_time: float = 0.0
var _is_analyzing: bool = false
var _suspicion_accum: float = 0.0


func setup(camera: Camera3D, hud: CanvasLayer, shooter: CollisionObject3D = null) -> void:
	_camera = camera
	_hud = hud
	_shooter = shooter
	if shooter is Node3D:
		_player = shooter as Node3D
	_set_hud_active(false)


func _physics_process(delta: float) -> void:
	var pressed := Input.is_action_pressed("scan")

	if pressed and not _was_active_last_frame:
		# Press began: start timing, don't commit to a verb yet.
		_press_time = 0.0
		_is_analyzing = false
		_suspicion_accum = 0.0
		_set_hud_active(true)

	if not pressed:
		if _was_active_last_frame:
			# Release. If we never crossed into analysis, this was a SWEEP tap.
			if not _is_analyzing and _press_time < sweep_tap_threshold:
				_do_sweep()
			_clear_focus()
			_is_analyzing = false
			_set_hud_active(false)
		_was_active_last_frame = false
		return

	_was_active_last_frame = true
	_press_time += delta

	# Held past the tap threshold => ANALYSIS mode on whatever we're aiming at.
	if _press_time >= sweep_tap_threshold:
		if not _is_analyzing:
			_is_analyzing = true
		_analyze_forward(delta)


# ---------------------------------------------------------------- SWEEP

func _do_sweep() -> void:
	if _camera == null:
		return
	var intel := get_node_or_null("/root/BountyIntel")
	var has_visible_intel := intel != null and intel.has_method("known_visible_count") \
		and int(intel.call("known_visible_count")) > 0

	var origin := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	var cos_half := cos(deg_to_rad(sweep_half_angle_degrees))
	var profile_matches := 0
	var traces := 0

	if has_visible_intel:
		for node in get_tree().get_nodes_in_group("scannable_npc"):
			if _sweep_consider(node, origin, forward, cos_half, intel):
				profile_matches += 1
	for node in get_tree().get_nodes_in_group("scanner_evidence"):
		if _sweep_evidence(node, origin, forward, cos_half):
			traces += 1
	for node in get_tree().get_nodes_in_group("scanner_clue"):
		# Clues are leads regardless of trait-match — surface any in-cone trace.
		if _in_sweep_cone(node, origin, forward, cos_half) and _has_los(origin, node):
			if node.has_method("mark_swept"):
				node.call("mark_swept", sweep_mark_duration)
				traces += 1
	for node in get_tree().get_nodes_in_group("chase_target"):
		if _sweep_chase_target(node, origin, forward, cos_half):
			profile_matches += 1

	if traces > 0 or profile_matches > 0:
		_toast("SWEEP: %d TRACE%s • %d PROFILE MATCH%s" % [
			traces, "" if traces == 1 else "S",
			profile_matches, "" if profile_matches == 1 else "ES",
		], 2.4)
	elif not has_visible_intel:
		_toast("NO TRACES — gather evidence or question witnesses", 2.2)
	else:
		_toast("SWEEP: no matches in view", 2.0)


## NPC sweep test: in cone + LOS + still matches known visible traits => mark.
func _sweep_consider(node: Node, origin: Vector3, forward: Vector3, cos_half: float, intel: Node) -> bool:
	if not (node is Node3D) or not node.has_method("mark_swept"):
		return false
	if not _in_sweep_cone(node, origin, forward, cos_half):
		return false
	if not intel.has_method("visible_match") or not bool(intel.call("visible_match", node)):
		return false
	if not _has_los(origin, node):
		return false
	node.call("mark_swept", sweep_mark_duration)
	return true


func _sweep_chase_target(node: Node, origin: Vector3, forward: Vector3, cos_half: float) -> bool:
	if not (node is Node3D) or not node.has_method("mark_swept"):
		return false
	if node.has_method("is_chase_reacquirable") and not bool(node.call("is_chase_reacquirable")):
		return false
	if not _in_sweep_cone(node, origin, forward, cos_half):
		return false
	if not _has_los(origin, node):
		return false
	node.call("mark_swept", sweep_mark_duration)
	return true


func _sweep_evidence(node: Node, origin: Vector3, forward: Vector3, cos_half: float) -> bool:
	if not (node is Node3D) or not node.has_method("mark_swept"):
		return false
	if node.has_method("is_scannable") and not bool(node.call("is_scannable")):
		return false
	if not _in_sweep_cone(node, origin, forward, cos_half):
		return false
	if not _has_los(origin, node):
		return false
	node.call("mark_swept", sweep_mark_duration)
	return true


func _in_sweep_cone(node: Node, origin: Vector3, forward: Vector3, cos_half: float) -> bool:
	var to := (node as Node3D).global_position - origin
	var dist := to.length()
	if dist > sweep_range or dist < 0.05:
		return false
	return forward.dot(to / dist) >= cos_half


## LOS to a node's approximate center. Tolerant: a hit on the node itself (or
## one of its children) passes; anything solid in between fails.
func _has_los(origin: Vector3, node: Node) -> bool:
	var height := 0.3 if node.is_in_group("scanner_evidence") else 1.0
	var target := (node as Node3D).global_position + Vector3(0.0, height, 0.0)
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	if _shooter != null:
		query.exclude = [_shooter.get_rid()]
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true  # nothing blocking; billboard NPCs often have thin colliders
	var collider := hit["collider"] as Node
	while collider != null:
		if collider == node:
			return true
		collider = collider.get_parent()
	return false


# ---------------------------------------------------------------- ANALYSIS

func _analyze_forward(delta: float) -> void:
	if _camera == null:
		return

	var from := _camera.global_position
	var to := from + (-_camera.global_transform.basis.z * analysis_range)
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
		_set_hud_progress(current_scan_progress / _get_scan_time_required(null))
		return

	if target != _focused_target:
		_clear_focus()
		_focused_target = target
		current_scan_progress = 0.0
		if target.has_method("begin_focus"):
			target.call("begin_focus")

	var required_time := _get_scan_time_required(target)
	_set_hud_text(_get_scan_text(target))

	# Cover cost: analyzing an NPC pings guard perception (C.3). Clues are inert
	# objects — reading a trace draws no scrutiny.
	if target.is_in_group("scannable_npc"):
		_accrue_suspicion(delta, target)

	if target.has_method("scan"):
		var previous_progress := current_scan_progress
		var progress := target.call("scan", delta) as float
		current_scan_progress = progress
		if previous_progress < required_time and progress >= required_time:
			_on_scan_completed(target)
	else:
		current_scan_progress = minf(current_scan_progress + delta, required_time)

	_set_hud_progress(current_scan_progress / required_time)


## Periodic suspicion ping at the analyzed NPC. Radius grows with hold time and
## shrinks when the player is blended. Routed as sub-gunfire noise so guards go
## SUSPICIOUS (yellow beat), never instant-ALERT.
func _accrue_suspicion(delta: float, target: Node) -> void:
	_suspicion_accum += delta
	if _suspicion_accum < suspicion_tick:
		return
	_suspicion_accum = 0.0

	var hold_scale: float = lerpf(1.0, analysis_hold_scale_max,
		clampf(current_scan_progress / maxf(scan_time_required, 0.05), 0.0, 1.0))
	var blended := _player != null and _player.has_method("is_blended") and bool(_player.call("is_blended"))
	var radius := analysis_base_radius * hold_scale
	if blended:
		radius *= analysis_blended_factor

	var at := (target as Node3D).global_position
	# loudness < 25 keeps it below the gunfire threshold in gang_guard.hear_noise.
	get_tree().call_group("perceptive", "hear_noise", at, minf(radius, 24.0))


# ---------------------------------------------------------------- shared

func _extract_scannable(hit: Dictionary) -> Node:
	if hit.is_empty():
		return null
	var collider := hit["collider"] as Node
	if collider == null:
		return null
	var candidate: Node = collider
	while candidate != null:
		if candidate.has_method("is_scannable") and candidate.call("is_scannable"):
			if candidate.is_in_group("scanner_clue") \
					or candidate.is_in_group("scanner_evidence") \
					or candidate.is_in_group("scannable_npc"):
				return candidate
		candidate = candidate.get_parent()
	return null


func _on_scan_completed(target: Node) -> void:
	if target.is_in_group("scannable_npc"):
		_show_npc_readout(target)
		get_tree().call_group("bounty_manager", "on_scannable_npc_scanned", target)
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
	_suspicion_accum = 0.0


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
		_set_hud_text("SCANNER")


func _set_hud_text(text: String) -> void:
	if _hud != null and _hud.has_method("set_scanner_text"):
		_hud.call("set_scanner_text", text)


func _set_hud_progress(value: float) -> void:
	if _hud != null and _hud.has_method("set_scan_progress"):
		_hud.call("set_scan_progress", clampf(value, 0.0, 1.0))


func _toast(text: String, duration: float = 2.2) -> void:
	if _hud != null and _hud.has_method("show_toast"):
		_hud.call("show_toast", text, duration)


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
	return "ANALYZING..."


func _get_scan_time_required(target: Node) -> float:
	if target != null and target.has_method("get_scan_time_required"):
		var required := target.call("get_scan_time_required") as float
		return maxf(required, 0.05)
	if target != null:
		var required_value = target.get("scan_time_required")
		if required_value is float:
			return maxf(required_value, 0.05)
		if required_value is int:
			return maxf(float(required_value), 0.05)
	return maxf(scan_time_required, 0.05)


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
