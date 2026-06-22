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
@export var sprint_noise_radius: float = 9.0
@export var sprint_noise_interval: float = 0.4
@export_group("Binoculars")
@export var binocular_fov: float = 28.0
@export var binocular_min_fov: float = 16.0
@export var binocular_max_fov: float = 42.0
@export var binocular_fov_step: float = 4.0
@export var binocular_zoom_speed: float = 12.0
@export var binocular_mouse_sensitivity_scale: float = 0.45
@export var binocular_movement_speed_scale: float = 0.72
@export_group("Crowd Blending")
@export var blend_radius: float = 4.0
@export var blend_npcs_required: int = 2
@export_group("Lures")
@export var lure_count: int = 3
@export var lure_throw_force: float = 13.0
@export var lure_throw_lift: float = 3.0
@export_group("Mantle")
## Cheapest-version mantle (locked 6/12): low ledges only — crates, stall
## counters, stage lips. Balcony-height climbing stays out of scope.
@export var mantle_enabled: bool = true
@export var mantle_min_height: float = 0.3
@export var mantle_max_height: float = 1.2
@export var mantle_forward_reach: float = 0.75
@export var mantle_duration: float = 0.22
## While airborne and pushing forward, auto-grab valid ledges (no extra press).
@export var mantle_air_assist: bool = true
@export_group("Ladder")
## Climb speed along the camera look-direction while inside a LadderZone.
@export var ladder_climb_speed: float = 4.0
@export_group("Crouch")
@export var crouch_speed: float = 3.8
@export var crouch_height: float = 1.05
@export var crouch_camera_height: float = 0.95
@export var crouch_transition_speed: float = 10.0

const PISTOL_SCENE: PackedScene = preload("res://scenes/weapons/Pistol.tscn")
const STUN_NET_SCENE: PackedScene = preload("res://scenes/weapons/StunNetLauncher.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/HUD.tscn")
const SCANNER_SCENE: PackedScene = preload("res://scenes/player/Scanner.tscn")
const LURE_SCENE: PackedScene = preload("res://scenes/props/NoiseLure.tscn")

@onready var camera: Camera3D = %Camera3D
@onready var weapon_mount: Node3D = %weapon_mount
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

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
var _sprint_noise_timer: float = 0.0
var _blended: bool = false
var _disguise: String = ""
var _disguise_access_tags: PackedStringArray = []
var _credentials: Dictionary = {}
var _disguise_profiles: Dictionary = {}
var _base_camera_fov: float = 78.0
var _binocular_active: bool = false
var _binocular_target_fov: float = 28.0
var _mantling: bool = false
var _mantle_time: float = 0.0
var _mantle_start: Vector3
var _mantle_target: Vector3
var _ladder: Area3D = null
var _crouched := false
var _standing_shape_height := 1.65
var _standing_shape_position_y := 0.9


func _ready() -> void:
	add_to_group("player")
	add_to_group("damageable")
	current_health = starting_health
	camera.current = true
	_base_camera_fov = camera.fov
	_binocular_target_fov = binocular_fov
	_camera_base_position = camera.position
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule != null:
		_standing_shape_height = capsule.height
	_standing_shape_position_y = collision_shape.position.y
	_load_disguise_profiles()
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
		# Release the FPS look-lock but keep the cursor trapped inside the game
		# window (CONFINED, not VISIBLE) so it can't wander onto another monitor.
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
		return

	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_capture_mouse()
		return

	if _is_dead:
		return

	if _binocular_active and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust_binocular_zoom(-binocular_fov_step)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_binocular_zoom(binocular_fov_step)
			return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_mouse_look(event.relative)

	if event.is_action_pressed("weapon_primary"):
		_toggle_weapon(pistol)

	if event.is_action_pressed("weapon_capture"):
		_toggle_weapon(stun_net_launcher)

	if event.is_action_pressed("binoculars"):
		_set_binocular_active(not _binocular_active)

	if event.is_action_pressed("reload") and active_weapon != null and active_weapon.has_method("reload"):
		active_weapon.call("reload")

	if event.is_action_pressed("interact"):
		_try_interact()

	if event.is_action_pressed("throw_lure"):
		_throw_lure()

	if event.is_action_pressed("crouch"):
		_set_crouched(not _crouched)


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return

	if _mantling:
		_process_mantle(delta)
		return

	if _ladder != null:
		_process_ladder(delta)
		_update_interaction_focus()
		return

	_apply_movement(delta)
	_update_interaction_focus()
	_update_blend_state()

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("fire") and not _binocular_active:
		if active_weapon != null and active_weapon.has_method("try_fire"):
			active_weapon.call("try_fire")


func _process(delta: float) -> void:
	_update_damage_shake(delta)
	_update_binocular_zoom(delta)


func _apply_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		if not _try_start_mantle():
			velocity.y = jump_velocity
	elif mantle_air_assist and not is_on_floor() and velocity.y < 2.0:
		var pushing := Input.get_vector("move_left", "move_right", "move_forward", "move_backward").y < -0.2
		if pushing:
			_try_start_mantle()
	if _mantling:
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var wish_dir := (right * input_dir.x + forward * -input_dir.y).normalized()
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	if _crouched:
		speed = crouch_speed
	if _binocular_active:
		speed *= binocular_movement_speed_scale

	if wish_dir != Vector3.ZERO:
		velocity.x = wish_dir.x * speed
		velocity.z = wish_dir.z * speed
	else:
		var deceleration := ground_deceleration * delta
		velocity.x = move_toward(velocity.x, 0.0, deceleration)
		velocity.z = move_toward(velocity.z, 0.0, deceleration)

	_update_sprint_noise(delta)

	move_and_slide()


func _update_sprint_noise(delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var sprinting := is_on_floor() and horizontal.length() > walk_speed + 0.5
	if not sprinting:
		_sprint_noise_timer = 0.0
		return

	_sprint_noise_timer -= delta
	if _sprint_noise_timer <= 0.0:
		_sprint_noise_timer = sprint_noise_interval
		get_tree().call_group("perceptive", "hear_noise", global_position, sprint_noise_radius)


func _apply_mouse_look(relative_motion: Vector2) -> void:
	var sensitivity := mouse_sensitivity
	if _binocular_active:
		sensitivity *= binocular_mouse_sensitivity_scale
	rotation.y -= relative_motion.x * sensitivity
	rotation.x = 0.0
	rotation.z = 0.0

	_pitch = clamp(_pitch - relative_motion.y * sensitivity, deg_to_rad(-89.0), deg_to_rad(89.0))
	camera.rotation = Vector3(_pitch, 0.0, 0.0)


func _capture_mouse() -> void:
	# CAPTURED hides + locks the cursor to centre for mouselook, and already
	# confines it to the window. Used on focus-in and on first click.
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


## Toggle: pressing the equipped weapon's key again holsters it.
func _toggle_weapon(weapon: Node) -> void:
	if weapon == null:
		return
	if active_weapon == weapon:
		_holster_weapons()
	else:
		_equip_weapon(weapon)


func _holster_weapons() -> void:
	for child in weapon_mount.get_children():
		if child is Node3D:
			child.visible = false
			child.set_process(false)
			child.set_physics_process(false)
	active_weapon = null
	if hud != null and hud.has_method("set_weapon_overlay_active"):
		hud.call("set_weapon_overlay_active", false)
	print("Weapons holstered.")


func is_holstered() -> bool:
	return active_weapon == null or _binocular_active


func _set_binocular_active(active: bool) -> void:
	if _is_dead or camera == null:
		return
	if _binocular_active == active:
		return
	_binocular_active = active
	if _binocular_active:
		_binocular_target_fov = clampf(_binocular_target_fov, binocular_min_fov, binocular_max_fov)
	_refresh_weapon_visibility()
	if hud != null and hud.has_method("set_binocular_active"):
		hud.call("set_binocular_active", _binocular_active, _base_camera_fov / maxf(_binocular_target_fov, 1.0))


func _update_binocular_zoom(delta: float) -> void:
	if camera == null:
		return
	var target_fov := _binocular_target_fov if _binocular_active else _base_camera_fov
	camera.fov = lerpf(camera.fov, target_fov, clampf(delta * binocular_zoom_speed, 0.0, 1.0))


func _adjust_binocular_zoom(fov_delta: float) -> void:
	_binocular_target_fov = clampf(_binocular_target_fov + fov_delta, binocular_min_fov, binocular_max_fov)
	if hud != null and hud.has_method("set_binocular_active"):
		hud.call("set_binocular_active", true, _base_camera_fov / maxf(_binocular_target_fov, 1.0))


func _refresh_weapon_visibility() -> void:
	if weapon_mount == null:
		return
	for child in weapon_mount.get_children():
		if child is Node3D:
			var should_show := (not _binocular_active and child == active_weapon)
			child.visible = should_show
			child.set_process(should_show)
			child.set_physics_process(should_show)
	if hud != null and hud.has_method("set_weapon_overlay_active"):
		hud.call("set_weapon_overlay_active", not _binocular_active and active_weapon == pistol)


## Crowd blending (locked design): holstered + walking pace + near 2+ civilians.
## A worn disguise removes the crowd-proximity requirement (portable blending).
## Guards dampen vision detection against a blended player; disguises deepen
## it at range but thin under close scrutiny (gang_guard).
func is_blended() -> bool:
	return _blended


func is_disguised() -> bool:
	return not _disguise.is_empty()


func equip_disguise(disguise_id: String, display_name: String = "") -> void:
	var profile: Dictionary = _disguise_profiles.get(disguise_id, {})
	_disguise = disguise_id
	_disguise_access_tags = PackedStringArray(profile.get("access_tags", []))
	var shown_name := display_name
	if shown_name.is_empty():
		shown_name = profile.get("display_name", disguise_id)
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", "Donned: %s. Walk easy, keep it holstered — and don't let them get close." % shown_name, 3.5)
	print("Disguise equipped: %s" % disguise_id)


func get_disguise_id() -> String:
	return _disguise


func grant_credential(access_tag: String) -> void:
	if access_tag.is_empty():
		return
	_credentials[access_tag] = true


func has_credential(access_tag: String) -> bool:
	return _credentials.has(access_tag)


func has_access_tag(access_tag: String) -> bool:
	return has_credential(access_tag) or _disguise_access_tags.has(access_tag)


func is_crouched() -> bool:
	return _crouched


func _set_crouched(active: bool) -> void:
	if not active and not _can_stand():
		if hud != null and hud.has_method("show_toast"):
			hud.call("show_toast", "Not enough clearance to stand.", 1.4)
		return
	_crouched = active
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule != null:
		capsule.height = crouch_height if active else _standing_shape_height
	collision_shape.position.y = crouch_height * 0.5 if active else _standing_shape_position_y
	var target_y := crouch_camera_height if active else _camera_base_position.y
	create_tween().tween_property(camera, "position:y", target_y, 1.0 / maxf(crouch_transition_speed, 0.1))


func _can_stand() -> bool:
	if not _crouched:
		return true
	var from := global_position + Vector3.UP * crouch_height
	var extra_height := maxf(_standing_shape_height - crouch_height, 0.1)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * extra_height)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _load_disguise_profiles() -> void:
	var file := FileAccess.open("res://data/disguise_profiles_hesperus.json", FileAccess.READ)
	if file == null:
		push_warning("Disguise profiles could not be loaded.")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_disguise_profiles = parsed


func _update_blend_state() -> void:
	var blended := _compute_blended()
	if blended != _blended:
		_blended = blended
		print("Player blend: %s" % ("IN CROWD" if _blended else "exposed"))
		if hud != null and hud.has_method("show_toast"):
			hud.call("show_toast", "Blending with the crowd" if _blended else "Exposed", 1.2)


func _compute_blended() -> bool:
	if not is_holstered():
		return false
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal.length() > walk_speed + 0.5:
		return false
	if is_disguised():
		return true
	var nearby := 0
	for npc in get_tree().get_nodes_in_group("scannable_npc"):
		if npc is Node3D and global_position.distance_to((npc as Node3D).global_position) <= blend_radius:
			nearby += 1
			if nearby >= blend_npcs_required:
				return true
	return false


## Throws a noise lure from the camera: arcs with gravity, pops a noise
## event on landing that pulls guards to investigate. G key.
func _throw_lure() -> void:
	if _is_dead or camera == null:
		return
	if _binocular_active:
		_set_binocular_active(false)
	if lure_count <= 0:
		if hud != null and hud.has_method("show_toast"):
			hud.call("show_toast", "Out of lures.", 1.5)
		return

	lure_count -= 1
	var lure := LURE_SCENE.instantiate() as RigidBody3D
	get_tree().current_scene.add_child(lure)
	var forward := -camera.global_transform.basis.z
	lure.global_position = camera.global_position + forward * 0.8
	lure.linear_velocity = forward * lure_throw_force + Vector3.UP * lure_throw_lift + velocity * 0.5
	lure.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))

	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", "Lure thrown (%d left)" % lure_count, 1.2)
	print("Lure thrown. %d remaining." % lure_count)


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

	_set_binocular_active(false)
	_is_dead = true
	died.emit()
	print("Player down.")
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)

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

	active_weapon = weapon
	_refresh_weapon_visibility()
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


# --- Ladder -------------------------------------------------------------------
# Climbable wall volume (LadderZone Area3D). While overlapping, gravity is off
# and the player moves along the camera look-direction: look up + W climbs,
# look down + W descends, jump detaches with a small hop. Dismount happens by
# climbing past the top onto a ledge or stepping off the bottom into a tunnel
# (both simply leave the Area3D, which restores normal movement).

func enter_ladder(zone: Area3D) -> void:
	if _ladder == zone:
		return
	_ladder = zone
	velocity = Vector3.ZERO


func exit_ladder(zone: Area3D) -> void:
	if _ladder == zone:
		_ladder = null


func is_on_ladder() -> bool:
	return _ladder != null


func _process_ladder(delta: float) -> void:
	if _binocular_active:
		_set_binocular_active(false)

	# Jump detaches with a small hop backward off the rungs.
	if Input.is_action_just_pressed("jump"):
		var back := global_transform.basis.z
		back.y = 0.0
		_ladder = null
		velocity = back.normalized() * walk_speed * 0.55 + Vector3.UP * jump_velocity * 0.65
		move_and_slide()
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	# Climb along where the camera looks (pitch included): W = toward look.
	var look := -camera.global_transform.basis.z
	var move := look * (-input_dir.y) * ladder_climb_speed
	# Allow horizontal strafing so you can line up and step off sideways.
	var right := global_transform.basis.x
	right.y = 0.0
	move += right.normalized() * input_dir.x * (ladder_climb_speed * 0.55)
	velocity = move
	move_and_slide()


# --- Mantle -------------------------------------------------------------------
# Low-ledge mantle: jump press against a 0.3–1.2m ledge vaults onto it instead
# of jumping; airborne + pushing forward auto-grabs the same ledges. Detection
# is two space-state raycasts plus a capsule clearance check — no scene nodes.

func _try_start_mantle() -> bool:
	if not mantle_enabled or _mantling:
		return false

	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return false
	forward = forward.normalized()

	var space := get_world_3d().direct_space_state
	var feet := global_position

	# 1) Down-cast ahead of the chest to find a candidate ledge top.
	var probe_top := feet + forward * mantle_forward_reach + Vector3.UP * (mantle_max_height + 0.45)
	var probe_bottom := probe_top + Vector3.DOWN * (mantle_max_height + 0.45 - mantle_min_height)
	var down := PhysicsRayQueryParameters3D.create(probe_top, probe_bottom)
	down.exclude = [get_rid()]
	var ledge: Dictionary = space.intersect_ray(down)
	if ledge.is_empty():
		return false
	var normal := ledge["normal"] as Vector3
	if normal.y < 0.7:
		return false  # not a walkable top
	var ledge_height := (ledge["position"] as Vector3).y - feet.y
	if ledge_height < mantle_min_height or ledge_height > mantle_max_height:
		return false

	# 2) Make sure there is actually a face in front (not a thin rail snag):
	# a short forward ray at half ledge height should hit something.
	var face_from := feet + Vector3.UP * maxf(ledge_height * 0.5, 0.15)
	var face := PhysicsRayQueryParameters3D.create(face_from, face_from + forward * (mantle_forward_reach + 0.1))
	face.exclude = [get_rid()]
	if space.intersect_ray(face).is_empty():
		return false

	# 3) Capsule clearance at the landing spot (slightly shrunk capsule).
	var target := Vector3((ledge["position"] as Vector3).x, (ledge["position"] as Vector3).y + 0.04, (ledge["position"] as Vector3).z) + forward * 0.08
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.6
	var clearance := PhysicsShapeQueryParameters3D.new()
	clearance.shape = capsule
	clearance.transform = Transform3D(Basis.IDENTITY, target + Vector3.UP * 0.92)
	clearance.exclude = [get_rid()]
	if not space.intersect_shape(clearance, 1).is_empty():
		return false

	_mantling = true
	_mantle_time = 0.0
	_mantle_start = feet
	_mantle_target = target
	velocity = Vector3.ZERO
	return true


func _process_mantle(delta: float) -> void:
	_mantle_time += delta
	var t := clampf(_mantle_time / maxf(mantle_duration, 0.01), 0.0, 1.0)
	# Two-phase curve: rise first, then translate forward over the lip.
	var up_t := clampf(t / 0.6, 0.0, 1.0)
	var fwd_t := clampf((t - 0.45) / 0.55, 0.0, 1.0)
	up_t = up_t * up_t * (3.0 - 2.0 * up_t)
	fwd_t = fwd_t * fwd_t * (3.0 - 2.0 * fwd_t)

	var pos := _mantle_start
	pos.y = lerpf(_mantle_start.y, _mantle_target.y, up_t)
	pos.x = lerpf(_mantle_start.x, _mantle_target.x, fwd_t)
	pos.z = lerpf(_mantle_start.z, _mantle_target.z, fwd_t)
	global_position = pos
	velocity = Vector3.ZERO

	if t >= 1.0:
		_mantling = false
		# Small carry-through so landing doesn't feel like hitting a wall.
		var forward := -global_transform.basis.z
		forward.y = 0.0
		velocity = forward.normalized() * walk_speed * 0.35


func is_mantling() -> bool:
	return _mantling
