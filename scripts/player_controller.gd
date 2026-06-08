extends CharacterBody3D

signal damaged(amount: int, health: int)
signal died

@export var walk_speed: float = 7.0
@export var sprint_speed: float = 10.5
@export var jump_velocity: float = 5.5
@export var mouse_sensitivity: float = 0.0022
@export var gravity: float = 24.0
@export var ground_deceleration: float = 90.0
@export var starting_health: int = 100
@export var capture_mouse_on_focus: bool = true
@export var interaction_range: float = 3.5
@export var damage_shake_duration: float = 0.18
@export var damage_shake_position_strength: float = 0.08
@export var damage_shake_rotation_strength: float = 0.018

const PISTOL_SCENE: PackedScene = preload("res://scenes/weapons/Pistol.tscn")
const STUN_NET_SCENE: PackedScene = preload("res://scenes/weapons/StunNetLauncher.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/HUD.tscn")
const SCANNER_SCENE: PackedScene = preload("res://scenes/player/Scanner.tscn")

@onready var camera: Camera3D = %Camera3D
@onready var weapon_mount: Node3D = %weapon_mount

var active_weapon: Node
var pistol: Node
var stun_net_launcher: Node
var scanner: Node
var hud: CanvasLayer
var current_health: int
var _is_dead: bool = false
var _pitch: float = 0.0
var _focused_interactable: Node
var _camera_base_position: Vector3
var _shake_time_left: float = 0.0
var _shake_duration: float = 0.0
var _shake_position_strength: float = 0.0
var _shake_rotation_strength: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("player")
	add_to_group("damageable")
	current_health = starting_health
	camera.current = true
	_camera_base_position = camera.position
	_pitch = camera.rotation.x
	_rng.randomize()
	_capture_mouse()
	await _spawn_hud()
	_spawn_weapon()
	_spawn_scanner()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN and capture_mouse_on_focus:
		_capture_mouse()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return

	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_capture_mouse()
		return

	if _is_dead:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_mouse_look(event.relative)

	if event.is_action_pressed("weapon_primary"):
		_equip_weapon(pistol)

	if event.is_action_pressed("weapon_capture"):
		_equip_weapon(stun_net_launcher)

	if event.is_action_pressed("reload") and active_weapon != null and active_weapon.has_method("reload"):
		active_weapon.call("reload")

	if event.is_action_pressed("interact"):
		_try_interact()


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return

	_apply_movement(delta)
	_update_interaction_focus()

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("fire"):
		if active_weapon != null and active_weapon.has_method("try_fire"):
			active_weapon.call("try_fire")


func _process(delta: float) -> void:
	_update_damage_shake(delta)


func _apply_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var wish_dir := (right * input_dir.x + forward * -input_dir.y).normalized()
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed

	if wish_dir != Vector3.ZERO:
		velocity.x = wish_dir.x * speed
		velocity.z = wish_dir.z * speed
	else:
		var deceleration := ground_deceleration * delta
		velocity.x = move_toward(velocity.x, 0.0, deceleration)
		velocity.z = move_toward(velocity.z, 0.0, deceleration)

	move_and_slide()


func _apply_mouse_look(relative_motion: Vector2) -> void:
	rotation.y -= relative_motion.x * mouse_sensitivity
	rotation.x = 0.0
	rotation.z = 0.0

	_pitch = clamp(_pitch - relative_motion.y * mouse_sensitivity, deg_to_rad(-89.0), deg_to_rad(89.0))
	camera.rotation = Vector3(_pitch, 0.0, 0.0)


func _capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _update_interaction_focus() -> void:
	if camera == null:
		return

	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * interaction_range)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	_focused_interactable = _extract_interactable(hit)

	if hud == null or not hud.has_method("set_interaction_prompt"):
		return

	if _focused_interactable == null:
		hud.call("set_interaction_prompt", "", false)
		return

	var prompt := "Press E"
	if _focused_interactable.has_method("get_interaction_text"):
		prompt = _focused_interactable.call("get_interaction_text") as String
	hud.call("set_interaction_prompt", prompt, not prompt.is_empty())


func _try_interact() -> void:
	if _is_dead:
		return

	if _focused_interactable == null:
		_update_interaction_focus()

	if _focused_interactable != null and _focused_interactable.has_method("interact"):
		_focused_interactable.call("interact", self)
		_update_interaction_focus()


func _extract_interactable(hit: Dictionary) -> Node:
	if hit.is_empty():
		return null

	var candidate := hit["collider"] as Node
	while candidate != null:
		if candidate.has_method("interact") and candidate.has_method("get_interaction_text"):
			return candidate
		candidate = candidate.get_parent()

	return null


func take_damage(amount: int) -> void:
	if _is_dead:
		return

	current_health = max(current_health - amount, 0)
	damaged.emit(amount, current_health)
	print("Player hit for %d damage. Health: %d" % [amount, current_health])

	if hud != null and hud.has_method("set_health"):
		hud.call("set_health", current_health)
	if hud != null and hud.has_method("flash_damage"):
		hud.call("flash_damage", amount)
	_start_damage_shake(amount)

	if current_health <= 0:
		_die()


func _start_damage_shake(amount: int) -> void:
	var scaled_amount := clampf(float(amount) / 12.0, 0.65, 1.6)
	_shake_duration = damage_shake_duration
	_shake_time_left = damage_shake_duration
	_shake_position_strength = damage_shake_position_strength * scaled_amount
	_shake_rotation_strength = damage_shake_rotation_strength * scaled_amount


func _update_damage_shake(delta: float) -> void:
	if camera == null:
		return

	if _shake_time_left <= 0.0:
		camera.position = _camera_base_position
		camera.rotation = Vector3(_pitch, 0.0, 0.0)
		return

	_shake_time_left = maxf(_shake_time_left - delta, 0.0)
	var falloff := _shake_time_left / maxf(_shake_duration, 0.001)
	falloff *= falloff

	var offset := Vector3(
		_rng.randf_range(-1.0, 1.0) * _shake_position_strength * falloff,
		_rng.randf_range(-1.0, 1.0) * _shake_position_strength * 0.65 * falloff,
		0.0
	)
	var pitch_offset := _rng.randf_range(-1.0, 1.0) * _shake_rotation_strength * 0.6 * falloff
	var roll_offset := _rng.randf_range(-1.0, 1.0) * _shake_rotation_strength * falloff

	camera.position = _camera_base_position + offset
	camera.rotation = Vector3(_pitch + pitch_offset, 0.0, roll_offset)


func _die() -> void:
	if _is_dead:
		return

	_is_dead = true
	died.emit()
	print("Player down.")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var bounty_manager := get_tree().get_first_node_in_group("bounty_manager")
	if bounty_manager != null and bounty_manager.has_method("fail_bounty"):
		bounty_manager.call("fail_bounty")


func _spawn_hud() -> void:
	hud = HUD_SCENE.instantiate() as CanvasLayer
	get_tree().root.add_child.call_deferred(hud)
	await hud.ready
	if hud.has_method("set_health"):
		hud.call("set_health", starting_health)
	if hud.has_method("set_objective"):
		hud.call("set_objective", "FPS Kernel Test")


func _spawn_weapon() -> void:
	pistol = PISTOL_SCENE.instantiate()
	weapon_mount.add_child(pistol)
	pistol.position = Vector3.ZERO
	pistol.rotation = Vector3.ZERO

	stun_net_launcher = STUN_NET_SCENE.instantiate()
	weapon_mount.add_child(stun_net_launcher)
	stun_net_launcher.position = Vector3.ZERO
	stun_net_launcher.rotation = Vector3.ZERO

	for weapon in [pistol, stun_net_launcher]:
		if weapon.has_method("setup"):
			weapon.call("setup", self, camera, hud)

	_equip_weapon(pistol)


func _equip_weapon(weapon: Node) -> void:
	if weapon == null:
		return

	for child in weapon_mount.get_children():
		if child is Node3D:
			child.visible = child == weapon
			child.set_process(child == weapon)
			child.set_physics_process(child == weapon)

	active_weapon = weapon
	if active_weapon.has_method("on_equipped"):
		active_weapon.call("on_equipped")
	elif active_weapon.has_method("_update_hud"):
		active_weapon.call("_update_hud")


func _spawn_scanner() -> void:
	scanner = SCANNER_SCENE.instantiate()
	camera.add_child(scanner)
	scanner.position = Vector3.ZERO
	scanner.rotation = Vector3.ZERO

	if scanner.has_method("setup"):
		scanner.call("setup", camera, hud, self)
