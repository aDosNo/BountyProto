extends CharacterBody3D

signal revealed
signal flee_started
signal reached_final_node
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
@export var node_reach_distance: float = 0.75
@export var reveal_delay: float = 0.35
@export var capture_range: float = 2.5
@export var capture_hold_time: float = 2.0
@export var route_height_tolerance: float = 0.08
@export var escape_route_parent: NodePath
@export var player_path: NodePath

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


func _ready() -> void:
	add_to_group("bounty_target")
	add_to_group("damageable")
	add_to_group("perceptive")
	_base_scale = visual_root.scale
	set_identified(false)
	stunned_marker.visible = false
	_cache_escape_nodes()
	_player = get_node_or_null(player_path) as Node3D
	_hud = _find_hud()

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
	elif state == TargetState.COMBAT:
		_face_player(delta)
	elif state == TargetState.STUNNED:
		_update_stunned(delta)


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


## Noise event: gunfire near the unidentified target spooks it into bolting.
## Systems ruling: a loud approach forfeits the calm confrontation.
func hear_noise(noise_position: Vector3, loudness: float) -> void:
	if _is_dead or _is_captured:
		return
	if loudness < 25.0:
		return
	if state != TargetState.HIDDEN and state != TargetState.IDLE_HIDDEN:
		return
	if global_position.distance_to(noise_position) > loudness * 0.6:
		return

	print("Korvaxi spooked by nearby gunfire.")
	reveal_and_flee()


## A guard shouted an alert nearby: the target bolts as well.
func on_ally_alert(shouter_position: Vector3, _threat_position: Vector3) -> void:
	if _is_dead or _is_captured:
		return
	if state != TargetState.HIDDEN and state != TargetState.IDLE_HIDDEN:
		return
	if global_position.distance_to(shouter_position) > 20.0:
		return

	print("Korvaxi spooked by guard alert.")
	reveal_and_flee()


func set_identified(active: bool) -> void:
	target_marker.visible = active


func reveal_and_flee() -> void:
	if _is_dead or _is_captured or state == TargetState.FLEEING or state == TargetState.COMBAT:
		return

	state = TargetState.REVEALED
	set_identified(true)
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
	if _escape_nodes.is_empty():
		state = TargetState.COMBAT
		reached_final_node.emit()
		print("Korvaxi has no escape route; entering combat state.")
		return

	state = TargetState.FLEEING
	_current_escape_index = 0
	flee_started.emit()
	print("Korvaxi started fleeing.")


func _follow_escape_route(delta: float) -> void:
	if _current_escape_index >= _escape_nodes.size():
		_enter_combat_state()
		return

	var target_position := _escape_nodes[_current_escape_index].global_position
	var direction := target_position - global_position

	if global_position.distance_to(target_position) <= node_reach_distance:
		_current_escape_index += 1
		if _current_escape_index >= _escape_nodes.size():
			_enter_combat_state()
		return

	if direction != Vector3.ZERO:
		var horizontal_direction := Vector3(direction.x, 0.0, direction.z)
		if horizontal_direction != Vector3.ZERO:
			velocity = horizontal_direction.normalized() * flee_speed
			_look_in_direction(horizontal_direction, delta)

		var y_delta := target_position.y - global_position.y
		if absf(y_delta) > route_height_tolerance:
			velocity.y = clampf(y_delta / maxf(delta, 0.001), -flee_speed, flee_speed)

		move_and_slide()


func _enter_combat_state() -> void:
	if _is_dead or _is_captured or state == TargetState.COMBAT:
		return

	velocity = Vector3.ZERO
	state = TargetState.COMBAT
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


func _cache_escape_nodes() -> void:
	_escape_nodes.clear()
	if escape_route_parent == NodePath():
		return

	var route_parent := get_node_or_null(escape_route_parent)
	if route_parent == null:
		return

	for child in route_parent.get_children():
		if child is Marker3D:
			_escape_nodes.append(child)


func _die() -> void:
	if _is_captured:
		return

	_is_dead = true
	state = TargetState.DEAD
	velocity = Vector3.ZERO
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
