extends CharacterBody3D

## Gang guard with graybox perception: UNAWARE -> SUSPICIOUS -> ALERTED.
## Doom-style movement: straight-line steering with move_and_slide, no navmesh.
## Joins groups: "pressure_enemy" (mission activation), "perceptive" (noise events).

signal perception_state_changed(new_state: int)

enum Perception { UNAWARE, SUSPICIOUS, ALERTED, RETURNING }

@export var health: int = 75
@export var starts_active: bool = false
@export var sentry: bool = false  ## true = BountyManager leaves activation to the scene
@export var attack_damage: int = 8
@export var attack_range: float = 28.0
@export var attack_cooldown: float = 1.1
@export var eye_height: float = 1.5

@export_group("Perception")
@export var vision_range: float = 22.0
@export var vision_half_angle_degrees: float = 60.0
@export var detect_time_close: float = 0.35
@export var detect_time_far: float = 1.6
@export var detection_decay: float = 0.35
@export var suspicion_linger: float = 4.0
@export var alert_memory: float = 6.0
@export var shout_radius: float = 25.0

@export_group("Movement")
@export var move_speed: float = 3.5
@export var gravity: float = 24.0
@export var patrol_route: NodePath  ## Node3D with Marker3D children; empty = stationary sentry
@export var patrol_wait: float = 1.6

@onready var mesh: MeshInstance3D = %GuardMesh
@onready var collision_shape: CollisionShape3D = %CollisionShape3D

const INDICATOR_COLORS := {
	Perception.UNAWARE: Color(0.75, 0.75, 0.75),
	Perception.SUSPICIOUS: Color(1.0, 0.85, 0.1),
	Perception.ALERTED: Color(1.0, 0.12, 0.08),
	Perception.RETURNING: Color(0.4, 0.6, 0.9),
}

var perception: Perception = Perception.UNAWARE

var _base_material: Material
var _is_dead: bool = false
var _next_attack_time: float = 0.0
var _player: Node3D

var _detection: float = 0.0
var _stimulus_position: Vector3
var _last_known: Vector3
var _suspicion_timer: float = 0.0
var _alert_timer: float = 0.0
var _post_position: Vector3
var _post_yaw: float = 0.0

var _patrol_points: Array[Vector3] = []
var _patrol_index: int = 0
var _patrol_wait_timer: float = 0.0

var _indicator: MeshInstance3D
var _indicator_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("pressure_enemy")
	add_to_group("perceptive")
	_base_material = mesh.get_active_material(0)
	_post_position = global_position
	_post_yaw = rotation.y
	_cache_patrol_points()
	_create_indicator()
	set_active(starts_active)


func set_active(active: bool) -> void:
	if _is_dead:
		return

	visible = active
	collision_shape.disabled = not active
	set_process(active)
	set_physics_process(active)


## Extraction pressure: ensure active and fully alerted toward the player.
func trigger_pressure() -> void:
	if _is_dead:
		return

	set_active(true)
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	var threat := _player.global_position if _player != null else _post_position
	_enter_alerted(threat, false)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	velocity.x = 0.0
	velocity.z = 0.0

	match perception:
		Perception.UNAWARE:
			_update_vision(delta)
			_do_patrol(delta)
		Perception.SUSPICIOUS:
			_update_vision(delta)
			_do_investigate(delta)
		Perception.ALERTED:
			_do_combat(delta)
		Perception.RETURNING:
			_update_vision(delta)
			_do_return(delta)

	move_and_slide()


# ---------------------------------------------------------------- perception

func _update_vision(delta: float) -> void:
	if _player_visible_in_cone():
		var dist := global_position.distance_to(_player.global_position)
		var detect_time: float = lerpf(detect_time_close, detect_time_far, clampf(dist / vision_range, 0.0, 1.0))
		var rate := delta / maxf(detect_time, 0.05)
		if _player_is_sprinting():
			rate *= 1.7
		if perception == Perception.SUSPICIOUS:
			rate *= 1.5
		_detection = minf(_detection + rate, 1.0)
		_stimulus_position = _player.global_position
	else:
		_detection = maxf(_detection - detection_decay * delta, 0.0)

	if _detection >= 1.0:
		_enter_alerted(_player.global_position)
	elif _detection >= 0.5 and (perception == Perception.UNAWARE or perception == Perception.RETURNING):
		_enter_suspicious(_stimulus_position)


func _player_visible_in_cone() -> bool:
	var origin := global_position + Vector3(0.0, eye_height, 0.0)
	var player_point: Vector3 = _player.global_position + Vector3(0.0, 1.0, 0.0)
	var to_player := player_point - origin
	if to_player.length() > vision_range:
		return false

	var forward := -global_transform.basis.z
	if forward.dot(to_player.normalized()) < cos(deg_to_rad(vision_half_angle_degrees)):
		return false

	return _has_line_of_sight(origin, player_point)


func _player_visible_any_direction(max_range: float) -> bool:
	var origin := global_position + Vector3(0.0, eye_height, 0.0)
	var player_point: Vector3 = _player.global_position + Vector3(0.0, 1.0, 0.0)
	if origin.distance_to(player_point) > max_range:
		return false
	return _has_line_of_sight(origin, player_point)


func _has_line_of_sight(origin: Vector3, target_point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(origin, target_point)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false

	var collider := hit["collider"] as Node
	return collider != null and collider.is_in_group("player")


func _player_is_sprinting() -> bool:
	if _player is CharacterBody3D:
		var horizontal := Vector3((_player as CharacterBody3D).velocity.x, 0.0, (_player as CharacterBody3D).velocity.z)
		return horizontal.length() > 8.5
	return false


## Noise event: loudness is the audible radius in meters.
func hear_noise(noise_position: Vector3, loudness: float) -> void:
	if _is_dead or not is_physics_processing():
		return
	if global_position.distance_to(noise_position) > loudness:
		return

	if loudness >= 25.0:
		# Gunfire: close shots fully alert, distant ones draw investigation.
		if global_position.distance_to(noise_position) < 15.0:
			_enter_alerted(noise_position)
		else:
			_enter_suspicious(noise_position)
	else:
		if perception == Perception.UNAWARE or perception == Perception.RETURNING:
			_enter_suspicious(noise_position)


## Another guard shouted: join the alert if in earshot of the shouter.
func on_ally_alert(shouter_position: Vector3, threat_position: Vector3) -> void:
	if _is_dead or not is_physics_processing():
		return
	if global_position.distance_to(shouter_position) > shout_radius:
		return
	if perception != Perception.ALERTED:
		_enter_alerted(threat_position, false)


func _enter_suspicious(stimulus: Vector3) -> void:
	if perception == Perception.ALERTED:
		return
	_stimulus_position = stimulus
	_suspicion_timer = suspicion_linger
	if perception != Perception.SUSPICIOUS:
		perception = Perception.SUSPICIOUS
		perception_state_changed.emit(perception)
		print("GangGuard suspicious.")
	_update_indicator()


func _enter_alerted(threat: Vector3, shout: bool = true) -> void:
	_last_known = threat
	_alert_timer = alert_memory
	_detection = 1.0
	if perception != Perception.ALERTED:
		perception = Perception.ALERTED
		perception_state_changed.emit(perception)
		print("GangGuard alerted!")
		if shout:
			get_tree().call_group("perceptive", "on_ally_alert", global_position, threat)
	_update_indicator()


# ---------------------------------------------------------------- behaviors

func _do_patrol(delta: float) -> void:
	if _patrol_points.is_empty():
		_face_yaw(_post_yaw, delta)
		return

	if _patrol_wait_timer > 0.0:
		_patrol_wait_timer -= delta
		return

	if _walk_toward(_patrol_points[_patrol_index], delta):
		_patrol_index = (_patrol_index + 1) % _patrol_points.size()
		_patrol_wait_timer = patrol_wait


func _do_investigate(delta: float) -> void:
	if _walk_toward(_stimulus_position, delta):
		_suspicion_timer -= delta
		if _suspicion_timer <= 0.0:
			perception = Perception.RETURNING
			perception_state_changed.emit(perception)
			_update_indicator()


func _do_combat(delta: float) -> void:
	var sees_player := _player_visible_any_direction(attack_range)

	if sees_player:
		_last_known = _player.global_position
		_alert_timer = alert_memory
		var to_player: Vector3 = _player.global_position - global_position
		to_player.y = 0.0
		if to_player != Vector3.ZERO:
			_look_in_direction(to_player, delta)

		var now := Time.get_ticks_msec() / 1000.0
		if now >= _next_attack_time:
			_next_attack_time = now + attack_cooldown
			_attack_player()
		return

	_alert_timer -= delta
	var arrived := _walk_toward(_last_known, delta)
	if _alert_timer <= 0.0 or (arrived and _alert_timer <= alert_memory * 0.5):
		perception = Perception.SUSPICIOUS
		_stimulus_position = _last_known
		_suspicion_timer = suspicion_linger
		_detection = 0.5
		perception_state_changed.emit(perception)
		_update_indicator()


func _do_return(delta: float) -> void:
	if _walk_toward(_post_position, delta):
		perception = Perception.UNAWARE
		_detection = 0.0
		perception_state_changed.emit(perception)
		_update_indicator()


func _walk_toward(point: Vector3, delta: float) -> bool:
	var flat := point - global_position
	flat.y = 0.0
	if flat.length() <= 1.2:
		return true

	var direction := flat.normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	_look_in_direction(direction, delta)
	return false


func _look_in_direction(direction: Vector3, delta: float) -> void:
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 8.0, 1.0))


func _face_yaw(yaw: float, delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, yaw, minf(delta * 4.0, 1.0))


func _cache_patrol_points() -> void:
	_patrol_points.clear()
	if patrol_route == NodePath():
		return
	var route := get_node_or_null(patrol_route)
	if route == null:
		return
	for child in route.get_children():
		if child is Marker3D:
			_patrol_points.append((child as Marker3D).global_position)


# ---------------------------------------------------------------- indicator

func _create_indicator() -> void:
	_indicator = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.32, 0.32, 0.32)
	_indicator.mesh = box
	_indicator.position = Vector3(0.0, 2.3, 0.0)
	_indicator_material = StandardMaterial3D.new()
	_indicator_material.emission_enabled = true
	_indicator_material.emission_energy_multiplier = 1.4
	_indicator.material_override = _indicator_material
	add_child(_indicator)
	_update_indicator()


func _update_indicator() -> void:
	if _indicator_material == null:
		return
	var color: Color = INDICATOR_COLORS.get(perception, Color.WHITE)
	_indicator_material.albedo_color = color
	_indicator_material.emission = color


# ---------------------------------------------------------------- combat fx

func _attack_player() -> void:
	if _player != null and _player.has_method("take_damage"):
		_player.call("take_damage", attack_damage)
		print("GangGuard fired at player for %d." % attack_damage)
	_flash_attack()


func _flash_attack() -> void:
	var muzzle_material := StandardMaterial3D.new()
	muzzle_material.albedo_color = Color(1.0, 0.55, 0.1)
	muzzle_material.emission_enabled = true
	muzzle_material.emission = Color(1.0, 0.4, 0.05)
	muzzle_material.emission_energy_multiplier = 1.6
	mesh.set_surface_override_material(0, muzzle_material)

	await get_tree().create_timer(0.06).timeout
	if is_instance_valid(mesh) and not _is_dead:
		mesh.set_surface_override_material(0, _base_material)


func take_damage(amount: int) -> void:
	if _is_dead:
		return

	health = max(health - amount, 0)
	print("GangGuard hit for %d damage. Health: %d" % [amount, health])

	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player != null:
		_enter_alerted(_player.global_position)

	if health <= 0:
		_die()
		return

	_flash_hit()


func _flash_hit() -> void:
	var hit_material := StandardMaterial3D.new()
	hit_material.albedo_color = Color(1.0, 0.08, 0.02)
	mesh.set_surface_override_material(0, hit_material)

	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(mesh) and not _is_dead:
		mesh.set_surface_override_material(0, _base_material)


func _die() -> void:
	_is_dead = true
	collision_shape.disabled = true
	queue_free()
