extends CharacterBody3D

signal revealed
signal flee_started
signal escape_route_selected(route_id: String, cue_text: String)
signal reached_final_node
signal escaped(route_id: String)
signal stunned
signal stun_expired
signal captured
signal killed

enum TargetState {
	HIDDEN,
	IDLE_HIDDEN,
	REVEALED,
	FLEEING,
	COMBAT,
	STUNNED,
	CAPTURED,
	DEAD,
}

@export var health: int = 150
@export var hit_flash_duration: float = 0.09
@export var death_pop_duration: float = 0.28
@export var flee_speed: float = 5.0
@export_group("Identity")
## This IS the bounty. on_npc_accused checks is_target; the courtyard model is
## the only valid confront target in the single-scripted-bounty phase (Option B).
@export var is_target: bool = true
@export var is_candidate: bool = true
@export var npc_name: String = "KORVAXI"
## Traits read from his sprite. Must match data/crowd_traits_hesperus.json
## funnel_profile so the gathered intel resolves to PROFILE FITS on a scan.
@export var build: String = "korvaxi-class heavy"
@export var appearance: String = "red coat"
@export var movement_tell: String = "heavy gait"
@export var location_habit: String = "courtyard"
@export var scanner_signature: String = "cybernetic arm"
@export_group("Scan")
@export var scan_time_required: float = 1.8
@export_group("Chase")
## Top speed at full stamina (slightly under player sprint 10.5, above walk 7.0 is too fast to ever catch — keep below walk for graybox tuning).
@export var sprint_speed: float = 7.8
## Speed when winded (stamina empty).
@export var winded_speed: float = 4.2
## Seconds of being pressed (player within pressure range) to fully drain stamina.
@export var stamina_seconds: float = 6.0
@export var stamina_recovery_rate: float = 0.55
## Player distance that counts as "pressing" the target.
@export var pressure_range: float = 14.0
## Speed multiplier floor when near death (wounds slow the target).
@export var hurt_speed_floor: float = 0.6
## Serpentine kicks in when the player is closer than this.
@export var juke_distance: float = 7.0
@export var juke_amplitude: float = 1.6
@export var juke_frequency: float = 2.3
@export_group("")
@export var node_reach_distance: float = 1.4
@export var reveal_delay: float = 0.35
@export var capture_range: float = 2.5
@export var capture_hold_time: float = 2.0
@export var route_height_tolerance: float = 1.2
@export var escape_route_parent: NodePath
@export var player_path: NodePath
@export_group("Chase Tracking")
@export var marker_los_grace: float = 2.0
@export var sweep_reacquire_duration: float = 6.0
@export_flags_3d_physics var chase_los_mask: int = 1
@export_group("Panic Response")
## Loud combat noise must meet this threshold before the hidden target reacts.
@export var gunshot_panic_loudness_threshold: float = 25.0
## Converts the noise event's guard-audibility radius into Korvaxi's panic radius.
@export_range(0.0, 1.0, 0.05) var gunshot_panic_radius_scale: float = 0.6
@export var guard_alert_panic_radius: float = 20.0
## Prevent alerts through solid level geometry. Dynamic actors do not occlude.
@export var require_clear_panic_path: bool = true
@export_flags_3d_physics var panic_occlusion_mask: int = 1

@onready var visual_root: Node3D = %VisualRoot
@onready var collision_shape: CollisionShape3D = %CollisionShape3D
@onready var target_marker: Node3D = %TargetMarker
@onready var stunned_marker: Node3D = %StunnedMarker

# State-feedback colors (shared by mesh-mode and sprite-mode).
const COLOR_HIT := Color(1.0, 0.12, 0.2)
const COLOR_STUN := Color(0.18, 0.82, 1.0)
const COLOR_CAPTURED := Color(0.3, 1.0, 0.45)
const COLOR_DEATH := Color(1.0, 0.3, 1.0)

var state: TargetState = TargetState.IDLE_HIDDEN

var _meshes: Array[MeshInstance3D] = []
var _base_materials: Dictionary = {}
var _sprite: DirectionalSprite3D = null   # set if VisualRoot holds a sprite
var _base_scale: Vector3
var _is_dead: bool = false
var _is_captured: bool = false
var _hit_tween: Tween
var _escape_nodes: Array[Marker3D] = []
var _current_escape_index: int = 0
var _player: Node3D
var _hud: CanvasLayer
var _stun_timer: float = 0.0
var _capture_progress: float = 0.0
var _state_before_stun: TargetState = TargetState.COMBAT
var _max_health: int = 150
var _stamina: float = 1.0
var _juke_time: float = 0.0
var _stuck_timer: float = 0.0
var _last_flee_position: Vector3 = Vector3.ZERO
var _route_options: Array[Dictionary] = []
var _active_route_id := "legacy"
var _active_terminal_outcome := "cornered"
var _active_route_display_name := "public bazaar"
var _active_route_cue := "Korvaxi is breaking for the public bazaar!"
var _chase_los_lost_time := 0.0
var _sweep_reacquire_time := 0.0
var _last_known_position := Vector3.ZERO
var _last_known_marker: Node3D
var _is_scanned: bool = false
var _scan_progress: float = 0.0
var _scan_focus_complete: bool = false
var _was_confronted: bool = false
var _hidden_home_position: Vector3
var _hidden_meeting_marker: Marker3D
var _hidden_meeting_dwell: float = 0.0
var _hidden_meeting_timer: float = 0.0
var _returning_from_meeting := false


func _ready() -> void:
	add_to_group("bounty_target")
	add_to_group("damageable")
	add_to_group("target_panic_listener")
	# Pre-reveal he's the scan/confront target. Leaves the group once he flees so
	# the scanner can't re-acquire him mid-chase.
	add_to_group("scannable_npc")
	_max_health = maxi(health, 1)
	_base_scale = visual_root.scale
	set_identified(false)
	stunned_marker.visible = false
	_cache_escape_nodes()
	_player = get_node_or_null(player_path) as Node3D
	_hud = _find_hud()
	_hidden_home_position = global_position
	var district_state := get_node_or_null("/root/DistrictState")
	if district_state != null and bool(district_state.call("has_flag", "hesperus.target.implant_disrupted")):
		apply_preparation_modifier("implant_disrupted")

	# Discover the visual representation. A DirectionalSprite3D may be a direct
	# child of VisualRoot or be VisualRoot itself; otherwise collect meshes.
	if visual_root is DirectionalSprite3D:
		_sprite = visual_root
	else:
		for child in visual_root.get_children():
			if child is DirectionalSprite3D:
				_sprite = child
			elif child is MeshInstance3D:
				var mesh_instance := child as MeshInstance3D
				_meshes.append(mesh_instance)
				_base_materials[mesh_instance] = mesh_instance.get_active_material(0)


func _physics_process(delta: float) -> void:
	velocity = Vector3.ZERO

	if state == TargetState.FLEEING:
		_follow_escape_route(delta)
		if state == TargetState.FLEEING:
			_update_chase_tracking(delta)
	elif state == TargetState.COMBAT:
		_face_player(delta)
	elif state == TargetState.STUNNED:
		_update_stunned(delta)
	elif state == TargetState.HIDDEN or state == TargetState.IDLE_HIDDEN:
		_update_hidden_meeting(delta)


func request_hidden_move(marker: Marker3D, dwell_time: float = 18.0) -> bool:
	if marker == null or _is_dead or _is_captured:
		return false
	if state != TargetState.HIDDEN and state != TargetState.IDLE_HIDDEN:
		return false
	_hidden_meeting_marker = marker
	_hidden_meeting_dwell = maxf(dwell_time, 1.0)
	_hidden_meeting_timer = 0.0
	_returning_from_meeting = false
	return true


func apply_preparation_modifier(modifier_id: String) -> void:
	if modifier_id == "implant_disrupted":
		stamina_seconds = maxf(stamina_seconds * 0.62, 2.5)
		stamina_recovery_rate *= 0.55


func _update_hidden_meeting(delta: float) -> void:
	if _hidden_meeting_marker == null:
		return
	var destination := _hidden_home_position if _returning_from_meeting else _hidden_meeting_marker.global_position
	var offset := destination - global_position
	offset.y = 0.0
	if offset.length() > 0.35:
		velocity = offset.normalized() * minf(flee_speed * 0.55, 3.2)
		move_and_slide()
		return
	if not _returning_from_meeting:
		_hidden_meeting_timer += delta
		if _hidden_meeting_timer >= _hidden_meeting_dwell:
			_returning_from_meeting = true
	else:
		_cancel_hidden_meeting()


func _cancel_hidden_meeting() -> void:
	_hidden_meeting_marker = null
	_hidden_meeting_timer = 0.0
	_returning_from_meeting = false


func take_damage(amount: int) -> void:
	if _is_dead or _is_captured:
		return

	health = max(health - amount, 0)
	print("Korvaxi Jurraal hit for %d damage. Health: %d" % [amount, health])

	if health <= 0:
		_die()
		return

	_flash_hit()
	_pulse_hit()


## Explicit combat-noise channel. Lures, scanners, footsteps, and utility
## noises stay on the generic `perceptive` channel and cannot panic the target.
func on_combat_noise(noise_position: Vector3, loudness: float) -> void:
	if _is_dead or _is_captured:
		return
	if loudness < gunshot_panic_loudness_threshold:
		return
	if state != TargetState.HIDDEN and state != TargetState.IDLE_HIDDEN:
		return
	if global_position.distance_to(noise_position) > loudness * gunshot_panic_radius_scale:
		return
	if not _has_clear_panic_path(noise_position):
		return

	print("Korvaxi spooked by nearby gunfire.")
	reveal_and_flee()


## Explicit guard-alert channel, separate from guard-to-guard perception.
func on_guard_alert(shouter_position: Vector3, _threat_position: Vector3) -> void:
	if _is_dead or _is_captured:
		return
	if state != TargetState.HIDDEN and state != TargetState.IDLE_HIDDEN:
		return
	if global_position.distance_to(shouter_position) > guard_alert_panic_radius:
		return
	if not _has_clear_panic_path(shouter_position):
		return

	print("Korvaxi spooked by guard alert.")
	reveal_and_flee()


func _has_clear_panic_path(source_position: Vector3) -> bool:
	if not require_clear_panic_path:
		return true
	if not is_inside_tree() or get_world_3d() == null:
		return false

	var origin := global_position + Vector3.UP * 1.35
	var destination := source_position + Vector3.UP * 1.2
	var direction := destination - origin
	if direction.length_squared() < 1.0:
		return true
	# Stop short of the source so its own collision body is not treated as a wall.
	destination -= direction.normalized() * 0.6

	var excluded: Array[RID] = [get_rid()]
	for _attempt in range(8):
		var query := PhysicsRayQueryParameters3D.create(origin, destination, panic_occlusion_mask, excluded)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return true
		var collider := hit.get("collider") as CollisionObject3D
		if collider is CharacterBody3D or collider is RigidBody3D:
			excluded.append(collider.get_rid())
			continue
		return false
	return true


func set_identified(active: bool) -> void:
	target_marker.visible = active


func reveal_and_flee() -> void:
	if _is_dead or _is_captured or state == TargetState.FLEEING or state == TargetState.COMBAT:
		return

	_cancel_hidden_meeting()
	state = TargetState.REVEALED
	set_identified(true)
	if is_in_group("scannable_npc"):
		remove_from_group("scannable_npc")
	revealed.emit()
	print("Korvaxi revealed.")
	_flash_hit()

	await get_tree().create_timer(reveal_delay).timeout
	if _is_dead:
		return
	_start_flee()


func apply_stun(duration: float) -> void:
	if _is_dead or _is_captured:
		return

	if state == TargetState.HIDDEN or state == TargetState.IDLE_HIDDEN:
		print("Stun net ignored: Korvaxi has not been identified.")
		return

	if state != TargetState.STUNNED:
		_state_before_stun = state

	state = TargetState.STUNNED
	velocity = Vector3.ZERO
	_stun_timer = duration
	_capture_progress = 0.0
	stunned_marker.visible = true
	_apply_stun_material()
	stunned.emit()
	print("Korvaxi stunned for %.1f seconds." % duration)


func _flash_hit() -> void:
	if _sprite != null:
		_sprite.set_state_tint(COLOR_HIT)
	else:
		var hit_material := StandardMaterial3D.new()
		hit_material.albedo_color = COLOR_HIT
		hit_material.emission_enabled = true
		hit_material.emission = Color(0.8, 0.02, 0.08)
		hit_material.emission_energy_multiplier = 1.3
		for mesh_instance in _meshes:
			mesh_instance.set_surface_override_material(0, hit_material)

	await get_tree().create_timer(hit_flash_duration).timeout
	if _is_dead or _is_captured:
		return

	if state == TargetState.STUNNED:
		_apply_stun_material()
		return

	_restore_base_materials()


func _pulse_hit() -> void:
	if _hit_tween != null:
		_hit_tween.kill()

	_hit_tween = create_tween()
	_hit_tween.tween_property(visual_root, "scale", _base_scale * 1.08, 0.045)
	_hit_tween.tween_property(visual_root, "scale", _base_scale, 0.075)


func _start_flee() -> void:
	_choose_escape_route()
	if _escape_nodes.is_empty():
		state = TargetState.COMBAT
		reached_final_node.emit()
		print("Korvaxi has no escape route; entering combat state.")
		return

	state = TargetState.FLEEING
	_current_escape_index = 0
	_stamina = 1.0
	_juke_time = 0.0
	_stuck_timer = 0.0
	_last_flee_position = global_position
	_last_known_position = global_position
	add_to_group("chase_target")
	escape_route_selected.emit(_active_route_id, _active_route_cue)
	flee_started.emit()
	print("Korvaxi started fleeing (%d-node route)." % _escape_nodes.size())


## Picks the route whose first node is farthest from the player. With a single
## route (legacy Marker3D children) behavior is unchanged from before.
func _choose_escape_route() -> void:
	_cache_escape_nodes()
	if _route_options.is_empty():
		return
	if _route_options.size() == 1:
		_apply_route(_route_options[0])
		return

	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D

	var valid_routes: Array[Dictionary] = []
	for route_data in _route_options:
		if _route_is_available(route_data):
			valid_routes.append(route_data)
	if valid_routes.is_empty():
		valid_routes.append(_route_options[0])

	var best: Dictionary = valid_routes[0]
	var best_distance := -1.0
	for route_data in valid_routes:
		var route: Array[Marker3D] = route_data["nodes"]
		if route.is_empty():
			continue
		var d := randf()
		if _player != null:
			d = route[0].global_position.distance_to(_player.global_position)
		if d > best_distance:
			best_distance = d
			best = route_data
	_apply_route(best)
	print("Korvaxi chose escape route '%s' starting at %s." % [_active_route_id, str(_escape_nodes[0].global_position)])


func _route_is_available(route_data: Dictionary) -> bool:
	var required_flag := String(route_data.get("required_flag", ""))
	if required_flag.is_empty():
		return true
	var district_state := get_node_or_null("/root/DistrictState")
	return district_state != null and bool(district_state.call("has_flag", required_flag))


func _apply_route(route_data: Dictionary) -> void:
	_escape_nodes = route_data.get("nodes", [])
	_active_route_id = String(route_data.get("route_id", "legacy"))
	_active_terminal_outcome = String(route_data.get("terminal_outcome", "cornered"))
	_active_route_display_name = String(route_data.get("display_name", _active_route_id.replace("_", " ")))
	_active_route_cue = String(route_data.get(
		"cue_text",
		"Korvaxi is breaking for the %s!" % _active_route_display_name
	))


func _follow_escape_route(delta: float) -> void:
	if _current_escape_index >= _escape_nodes.size():
		_finish_escape_route()
		return

	var target_position := _escape_nodes[_current_escape_index].global_position
	var direction := target_position - global_position

	# Reach is judged in the HORIZONTAL plane: route markers were plotted at
	# old blockout heights and must still count as reached on new GLB floors.
	if Vector2(direction.x, direction.z).length() <= node_reach_distance:
		_current_escape_index += 1
		if _current_escape_index >= _escape_nodes.size():
			_finish_escape_route()
			return

	if direction != Vector3.ZERO:
		var horizontal_direction := Vector3(direction.x, 0.0, direction.z)
		if horizontal_direction != Vector3.ZERO:
			var speed := _current_flee_speed(delta)
			var move_dir := horizontal_direction.normalized()
			# Never weave while scraping geometry — slide along the wall instead.
			if is_on_wall():
				var slid := move_dir.slide(get_wall_normal())
				if slid.length_squared() > 0.04:
					move_dir = slid.normalized()
			else:
				move_dir = _apply_juke(move_dir, delta)
			velocity = move_dir * speed
			_look_in_direction(horizontal_direction, delta)

		var y_delta := target_position.y - global_position.y
		if absf(y_delta) > route_height_tolerance:
			velocity.y = clampf(y_delta / maxf(delta, 0.001), -flee_speed, flee_speed)
		elif not is_on_floor():
			velocity.y -= 18.0 * delta
		else:
			velocity.y = 0.0

		move_and_slide()
		_update_stuck_watchdog(delta)


## Recovery: if barely moving while fleeing, skip ahead on the route rather
## than grinding a corner forever. Skipping past the last node = cornered.
func _update_stuck_watchdog(delta: float) -> void:
	var moved := global_position.distance_to(_last_flee_position)
	_last_flee_position = global_position
	if moved < flee_speed * delta * 0.2:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0

	if _stuck_timer >= 0.8:
		_stuck_timer = 0.0
		_juke_time = 0.0
		_current_escape_index += 1
		print("Korvaxi unstuck: skipping to escape node %d." % _current_escape_index)
		if _current_escape_index >= _escape_nodes.size():
			_finish_escape_route()


func _finish_escape_route() -> void:
	if _active_terminal_outcome == "escaped":
		_escape_district()
	else:
		_enter_combat_state()


func _escape_district() -> void:
	if _is_dead or _is_captured:
		return
	velocity = Vector3.ZERO
	visible = false
	remove_from_group("chase_target")
	_clear_last_known_marker()
	collision_shape.set_deferred("disabled", true)
	escaped.emit(_active_route_id)
	print("Korvaxi escaped Hesperus via route '%s'." % _active_route_id)


## Chase pacing: a stamina sprint that drains while the player presses close
## and recovers when they fall behind; wounds slow the target proportionally.
## Net effect: a clean chase rubber-bands toward a catch without scripting it.
func _current_flee_speed(delta: float) -> float:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D

	var pressed := false
	if _player != null:
		pressed = global_position.distance_to(_player.global_position) < pressure_range

	if pressed:
		_stamina = maxf(_stamina - (delta / maxf(stamina_seconds, 0.5)), 0.0)
	else:
		_stamina = minf(_stamina + stamina_recovery_rate * delta, 1.0)

	var base := lerpf(winded_speed, sprint_speed, _stamina)
	var health_factor := lerpf(hurt_speed_floor, 1.0, float(health) / float(_max_health))
	return base * health_factor


## Panic serpentine when the player is right behind: harder to line up shots.
func _apply_juke(move_dir: Vector3, delta: float) -> Vector3:
	if _player == null or juke_amplitude <= 0.0:
		return move_dir
	if global_position.distance_to(_player.global_position) > juke_distance:
		_juke_time = 0.0
		return move_dir

	_juke_time += delta
	var side := move_dir.cross(Vector3.UP)
	var weave := sin(_juke_time * TAU * juke_frequency) * juke_amplitude
	return (move_dir + side * weave * 0.22).normalized()


func _update_chase_tracking(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		return

	_sweep_reacquire_time = maxf(_sweep_reacquire_time - delta, 0.0)
	if _has_clear_chase_los():
		_chase_los_lost_time = 0.0
		_last_known_position = global_position
		target_marker.visible = true
		if _last_known_marker != null:
			_last_known_marker.visible = false
		return

	_chase_los_lost_time += delta
	if _chase_los_lost_time < marker_los_grace or _sweep_reacquire_time > 0.0:
		target_marker.visible = true
		if _sweep_reacquire_time > 0.0:
			_last_known_position = global_position
		return

	target_marker.visible = false
	_show_last_known_marker()


func _has_clear_chase_los() -> bool:
	if _player == null or not is_inside_tree() or get_world_3d() == null:
		return false
	var origin := global_position + Vector3.UP * 1.25
	var destination := _player.global_position + Vector3.UP * 1.25
	var query := PhysicsRayQueryParameters3D.create(origin, destination, chase_los_mask, [get_rid()])
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider := hit.get("collider") as Node
	while collider != null:
		if collider == _player or collider.is_in_group("player"):
			return true
		collider = collider.get_parent()
	return false


func _show_last_known_marker() -> void:
	if _last_known_marker == null:
		_last_known_marker = Node3D.new()
		_last_known_marker.name = "KorvaxiLastKnownMarker"
		var label := Label3D.new()
		label.text = "LAST KNOWN"
		label.font_size = 24
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(1.0, 0.66, 0.15, 1.0)
		_last_known_marker.add_child(label)
		var scene_root := get_tree().current_scene
		if scene_root == null:
			scene_root = get_parent()
		scene_root.add_child(_last_known_marker)
	_last_known_marker.global_position = _last_known_position + Vector3.UP * 2.8
	_last_known_marker.visible = true


func _clear_last_known_marker() -> void:
	if _last_known_marker != null and is_instance_valid(_last_known_marker):
		_last_known_marker.queue_free()
	_last_known_marker = null


func _enter_combat_state() -> void:
	if _is_dead or _is_captured or state == TargetState.COMBAT:
		return

	velocity = Vector3.ZERO
	state = TargetState.COMBAT
	remove_from_group("chase_target")
	_clear_last_known_marker()
	set_identified(true)
	reached_final_node.emit()
	print("Korvaxi reached final node.")


func _face_player(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		return

	var direction := _player.global_position - global_position
	direction.y = 0.0
	if direction != Vector3.ZERO:
		_look_in_direction(direction, delta)


func _update_stunned(delta: float) -> void:
	_stun_timer = maxf(_stun_timer - delta, 0.0)
	_update_capture(delta)

	if _stun_timer <= 0.0 and not _is_captured:
		_expire_stun()


func _update_capture(delta: float) -> void:
	if _player == null:
		_player = get_node_or_null(player_path) as Node3D
	if _hud == null:
		_hud = _find_hud()

	if _player == null:
		_hide_capture_prompt()
		return

	var in_range := global_position.distance_to(_player.global_position) <= capture_range
	if not in_range:
		_capture_progress = 0.0
		_hide_capture_prompt()
		return

	if _hud != null and _hud.has_method("set_capture_prompt"):
		_hud.call("set_capture_prompt", "Hold E to capture Korvaxi", true)

	if Input.is_action_pressed("interact"):
		_capture_progress = minf(_capture_progress + delta, capture_hold_time)
	else:
		_capture_progress = maxf(_capture_progress - (delta * 1.5), 0.0)

	if _hud != null and _hud.has_method("set_capture_progress"):
		_hud.call("set_capture_progress", _capture_progress / capture_hold_time)

	if _capture_progress >= capture_hold_time:
		_capture()


func _expire_stun() -> void:
	stunned_marker.visible = false
	_capture_progress = 0.0
	_hide_capture_prompt()
	_restore_base_materials()
	stun_expired.emit()
	print("Korvaxi stun expired.")

	if _state_before_stun == TargetState.FLEEING and _current_escape_index < _escape_nodes.size():
		state = TargetState.FLEEING
	else:
		state = TargetState.COMBAT


func _capture() -> void:
	if _is_dead or _is_captured:
		return

	_is_captured = true
	state = TargetState.CAPTURED
	velocity = Vector3.ZERO
	collision_shape.disabled = true
	stunned_marker.visible = false
	remove_from_group("chase_target")
	_clear_last_known_marker()
	set_identified(true)
	_hide_capture_prompt()
	_apply_captured_material()
	captured.emit()
	print("Korvaxi captured alive.")


func _hide_capture_prompt() -> void:
	if _hud != null and _hud.has_method("set_capture_prompt"):
		_hud.call("set_capture_prompt", "", false)


func _apply_stun_material() -> void:
	if _sprite != null:
		_sprite.set_state_tint(COLOR_STUN)
		return
	var stun_material := StandardMaterial3D.new()
	stun_material.albedo_color = COLOR_STUN
	stun_material.emission_enabled = true
	stun_material.emission = Color(0.02, 0.45, 0.75)
	stun_material.emission_energy_multiplier = 1.45
	for mesh_instance in _meshes:
		mesh_instance.set_surface_override_material(0, stun_material)


func _apply_captured_material() -> void:
	if _sprite != null:
		_sprite.set_state_tint(COLOR_CAPTURED)
		return
	var captured_material := StandardMaterial3D.new()
	captured_material.albedo_color = COLOR_CAPTURED
	captured_material.emission_enabled = true
	captured_material.emission = Color(0.04, 0.35, 0.12)
	captured_material.emission_energy_multiplier = 0.9
	for mesh_instance in _meshes:
		mesh_instance.set_surface_override_material(0, captured_material)


func _restore_base_materials() -> void:
	if _sprite != null:
		_sprite.clear_state_tint()
		return
	for mesh_instance in _meshes:
		mesh_instance.set_surface_override_material(0, _base_materials[mesh_instance])


func _find_hud() -> CanvasLayer:
	var grouped_hud := get_tree().get_first_node_in_group("hud")
	if grouped_hud is CanvasLayer:
		return grouped_hud
	return null


func _look_in_direction(direction: Vector3, delta: float) -> void:
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 10.0, 1.0))


# --- Scanner + confront contract (Option B: courtyard model is the target) ----
# Mirrors CrowdNPC's contract so the existing scanner/interact code treats him
# uniformly. He's scannable only while hidden in the courtyard; confronting him
# is the accusation BountyManager.on_npc_accused rules on.

func is_scannable() -> bool:
	return is_in_group("scannable_npc") and not _was_confronted


func begin_focus() -> void:
	_scan_focus_complete = false
	_scan_progress = 0.0


func end_focus() -> void:
	_scan_progress = 0.0
	_scan_focus_complete = false


func scan(delta: float) -> float:
	_scan_progress = minf(_scan_progress + delta, scan_time_required)
	if _scan_progress >= scan_time_required and not _scan_focus_complete:
		_scan_focus_complete = true
		_is_scanned = true
		print("Korvaxi scanned (courtyard model).")
	return _scan_progress


func get_scan_text() -> String:
	return "RE-SCANNING SUBJECT..." if _is_scanned else "SCANNING SUBJECT..."


func get_scan_time_required() -> float:
	return scan_time_required


func is_chase_reacquirable() -> bool:
	return state == TargetState.FLEEING and not _is_dead and not _is_captured


func mark_swept(duration: float = -1.0) -> void:
	if not is_chase_reacquirable():
		return
	_sweep_reacquire_time = maxf(
		sweep_reacquire_duration if duration < 0.0 else duration,
		_sweep_reacquire_time
	)
	_last_known_position = global_position
	target_marker.visible = true
	if _last_known_marker != null:
		_last_known_marker.visible = false


func get_interaction_text() -> String:
	if _was_confronted or not is_in_group("scannable_npc"):
		return ""
	if not _is_scanned:
		return ""
	return "Press E: Confront %s" % npc_name


func interact(_interacting_player: Node) -> void:
	if _was_confronted or not _is_scanned:
		return
	get_tree().call_group("bounty_manager", "on_npc_accused", self)


## BountyManager calls this on a resolved accusation. For the courtyard model a
## correct confront just kicks off the reveal/chase — no actor handoff needed.
func mark_confronted() -> void:
	_was_confronted = true


func _cache_escape_nodes() -> void:
	_escape_nodes.clear()
	_route_options.clear()
	if escape_route_parent == NodePath():
		return

	var route_parent := get_node_or_null(escape_route_parent)
	if route_parent == null:
		return

	var direct: Array[Marker3D] = []
	for child in route_parent.get_children():
		if child is Marker3D:
			direct.append(child)
		elif child is Node3D:
			var branch: Array[Marker3D] = []
			for sub in child.get_children():
				if sub is Marker3D:
					branch.append(sub)
			if not branch.is_empty():
				_route_options.append({
					"nodes": branch,
					"route_id": String(child.get_meta("route_id", child.name)),
					"required_flag": String(child.get_meta("required_flag", "")),
					"terminal_outcome": String(child.get_meta("terminal_outcome", "cornered")),
					"display_name": String(child.get_meta("display_name", child.name)),
					"cue_text": String(child.get_meta("cue_text", "")),
				})
	if not direct.is_empty():
		_route_options.append({
			"nodes": direct,
			"route_id": "public_bazaar",
			"required_flag": "",
			"terminal_outcome": "cornered",
			"display_name": "public bazaar",
			"cue_text": "Korvaxi is breaking west for the public bazaar!",
		})
	if _route_options.size() == 1:
		_apply_route(_route_options[0])


func _die() -> void:
	if _is_captured:
		return

	_is_dead = true
	state = TargetState.DEAD
	velocity = Vector3.ZERO
	remove_from_group("chase_target")
	_clear_last_known_marker()
	collision_shape.disabled = true
	stunned_marker.visible = false
	_hide_capture_prompt()
	killed.emit()
	print("Korvaxi Jurraal killed.")

	if _hit_tween != null:
		_hit_tween.kill()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual_root, "scale", _base_scale * 1.25, death_pop_duration * 0.45)

	if _sprite != null:
		_sprite.set_state_tint(COLOR_DEATH)
		tween.tween_method(_sprite.set_visual_transparency, 0.0, 1.0, death_pop_duration)
	else:
		var death_material := StandardMaterial3D.new()
		death_material.albedo_color = COLOR_DEATH
		death_material.emission_enabled = true
		death_material.emission = Color(0.7, 0.08, 0.9)
		death_material.emission_energy_multiplier = 2.0
		for mesh_instance in _meshes:
			mesh_instance.set_surface_override_material(0, death_material)
			tween.tween_property(mesh_instance, "transparency", 1.0, death_pop_duration)

	tween.chain().tween_property(visual_root, "scale", Vector3.ONE * 0.01, death_pop_duration * 0.55)
	tween.chain().tween_callback(queue_free)
