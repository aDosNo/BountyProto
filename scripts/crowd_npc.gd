extends CharacterBody3D
## CrowdNPC — scannable market civilian for the identity funnel.
## Identities dealt at runtime by CrowdDirector through apply_identity().
## Movement tells express through gait so observation is a real intel source.
## Scanning compares traits against intel (re-scannable). Confronting a scanned
## CANDIDATE is the accusation; civilians with a witness hint can be ASKED.
## Civilians PANIC (run from the player) when a weapon is visibly drawn nearby,
## and yield (get pushed aside) when the player walks into them.

signal npc_scanned(npc: Node)
signal died(npc: Node)

@export var npc_name: String = "CIVILIAN"
@export_group("Traits")
@export var build: String = ""
@export var appearance: String = ""
@export var movement_tell: String = ""
@export var location_habit: String = ""
@export var scanner_signature: String = ""
@export_group("Role")
@export var is_candidate: bool = false
@export var is_target: bool = false
@export_group("Scan")
@export var scan_time_required: float = 1.5
@export_group("Wander")
@export var wander_enabled: bool = true
@export var wander_radius: float = 8.0
@export var walk_speed: float = 1.6
@export var route_pause_min: float = 0.4
@export var route_pause_max: float = 2.4
@export var route_point_reach_distance: float = 0.55
@export_group("Reactions")
## Player with a drawn weapon inside this radius => run away.
@export var scare_radius: float = 9.0
@export var panic_speed: float = 3.6
## Player closer than this gets the NPC shoved aside (crowd yielding).
@export var push_radius: float = 1.0
@export var push_strength: float = 5.0
@export_group("Damage")
@export var health: int = 50
@export var death_cleanup_delay: float = 0.35

const GRAVITY := 18.0

enum WanderState { IDLE, WALK, PANIC }

@onready var mesh: MeshInstance3D = %NpcMesh
@onready var name_label: Label3D = %NameLabel
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var is_scanned: bool = false
var was_confronted: bool = false
var is_spooked: bool = false
var _is_dead: bool = false
var witness_hint_category: String = ""
var witness_hint_value: String = ""
var _witness_used: bool = false
## Wrong-accusation fallout: nearby civilians refuse to talk for a while.
var _clam_timer: float = 0.0
var _scan_progress: float = 0.0
var _completed_this_focus: bool = false
var _wander_state: WanderState = WanderState.IDLE
var _wander_timer: float = 0.0
var _wander_target: Vector3
var _home: Vector3
var _gait_time: float = 0.0
var _corridor: Array = []
var _corridor_half_width: float = 3.2
var _route: Array[Vector3] = []
var _route_index: int = 0
var _route_direction: int = 1
var _route_jitter: float = 0.9
var _loiter_chance: float = 0.3
var _player: Node3D = null
var _scare_timer: float = 0.0
var _base_material: Material


func set_corridor(points: Array, half_width: float) -> void:
	_home = global_position
	_corridor = points
	_corridor_half_width = half_width


func set_route(points: Array, half_width: float, start_index: int = 0) -> void:
	_home = global_position
	_route.clear()
	for point in points:
		if point is Vector3:
			_route.append(point)
	if _route.is_empty():
		set_corridor(points, half_width)
		return
	_corridor = _route.duplicate()
	_corridor_half_width = half_width
	_route_index = clampi(start_index, 0, _route.size() - 1)
	_route_direction = -1 if randf() < 0.5 else 1
	_route_jitter = randf_range(0.4, maxf(half_width * 0.5, 0.6))
	wander_radius = maxf(wander_radius, half_width * 1.6)


func _ready() -> void:
	add_to_group("scannable_npc")
	add_to_group("damageable")
	_base_material = mesh.get_active_material(0)
	_home = global_position
	name_label.text = npc_name
	name_label.visible = false
	_wander_timer = randf_range(0.3, 2.5)
	# Per-NPC variance so the crowd doesn't move in lockstep.
	walk_speed *= randf_range(0.85, 1.3)
	route_pause_max *= randf_range(0.7, 1.4)
	_loiter_chance = randf_range(0.18, 0.42)


func apply_identity(d: Dictionary) -> void:
	npc_name = d.get("npc_name", npc_name)
	build = d.get("build", build)
	appearance = d.get("appearance", appearance)
	movement_tell = d.get("movement_tell", movement_tell)
	location_habit = d.get("location_habit", location_habit)
	scanner_signature = d.get("scanner_signature", scanner_signature)
	is_candidate = d.get("is_candidate", is_candidate)
	is_target = d.get("is_target", is_target)
	witness_hint_category = d.get("witness_hint_category", "")
	witness_hint_value = d.get("witness_hint_value", "")
	if name_label != null:
		name_label.text = npc_name


## Wrong-accusation fallout for the real target: word spread, they get wary.
func spook() -> void:
	if is_spooked:
		return
	is_spooked = true
	walk_speed = minf(walk_speed * 1.6, 3.4)
	_loiter_chance = 0.04
	route_pause_min = 0.1
	route_pause_max = 0.5
	_wander_state = WanderState.WALK
	_wander_target = _pick_destination()
	_wander_timer = randf_range(5.0, 13.0)
	print("CrowdNPC spooked: %s" % npc_name)


## Wrong-accusation fallout: a bad public call makes this bystander refuse to
## talk for `duration` seconds. Only meaningful for witnesses (candidates don't
## canvass). Refreshes to the longer remaining time rather than stacking.
func clam_up(duration: float) -> void:
	if _is_dead:
		return
	_clam_timer = maxf(_clam_timer, duration)
	if not witness_hint_category.is_empty() and not _witness_used:
		print("CrowdNPC clammed up: %s (%.0fs)" % [npc_name, _clam_timer])


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if _clam_timer > 0.0:
		_clam_timer = maxf(_clam_timer - delta, 0.0)

	# Safety net: recover NPCs that fall out of the world.
	if global_position.y < _home.y - 8.0:
		global_position = _home
		velocity = Vector3.ZERO
		_wander_state = WanderState.IDLE
		_wander_timer = randf_range(1.0, 3.0)
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	_update_scare(delta)

	if _wander_state == WanderState.PANIC:
		_process_panic(delta)
	elif wander_enabled:
		_process_wander(delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	_apply_player_push()
	move_and_slide()


# --- Weapon panic ------------------------------------------------------------

func _update_scare(delta: float) -> void:
	_scare_timer -= delta
	if _scare_timer > 0.0:
		return
	_scare_timer = 0.25  # staggered checks, cheap
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		return

	var dist := global_position.distance_to(_player.global_position)
	var armed: bool = _player.has_method("is_holstered") and not _player.call("is_holstered")

	if armed and dist < scare_radius and _wander_state != WanderState.PANIC:
		_wander_state = WanderState.PANIC
		print("CrowdNPC panicking: %s" % npc_name)
	elif _wander_state == WanderState.PANIC and (not armed or dist > scare_radius * 1.6):
		_wander_state = WanderState.IDLE
		_wander_timer = randf_range(0.5, 1.5)


func _process_panic(delta: float) -> void:
	if _player == null:
		_wander_state = WanderState.IDLE
		return
	_gait_time += delta
	var away := global_position - _player.global_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.FORWARD
	var dir := away.normalized()
	# Slight weave so a fleeing crowd doesn't move as one rank.
	var side := dir.cross(Vector3.UP)
	dir = (dir + side * sin(_gait_time * 4.0 + float(get_instance_id() % 7)) * 0.3).normalized()
	velocity.x = dir.x * panic_speed
	velocity.z = dir.z * panic_speed
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length_squared() > 0.01:
		look_at(global_position + flat, Vector3.UP)


func on_nearby_npc_shot(shot_position: Vector3) -> void:
	if _is_dead:
		return
	if global_position.distance_to(shot_position) > scare_radius * 1.8:
		return
	_wander_state = WanderState.PANIC
	_scare_timer = 0.4


# --- Damage ------------------------------------------------------------------

func take_damage(amount: int) -> void:
	if _is_dead:
		return

	health = maxi(health - amount, 0)
	print("CrowdNPC hit: %s for %d damage. Health: %d" % [npc_name, amount, health])

	_alert_on_shot()
	get_tree().call_group("scannable_npc", "on_nearby_npc_shot", global_position)
	_report_public_harm(health <= 0)

	if health <= 0:
		_die()
		return

	_flash_hit()
	_wander_state = WanderState.PANIC


func _alert_on_shot() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	var threat := global_position
	if _player != null:
		threat = _player.global_position
	get_tree().call_group("perceptive", "on_ally_alert", global_position, threat)


func _report_public_harm(was_killed: bool) -> void:
	for manager in get_tree().get_nodes_in_group("bounty_manager"):
		if manager.has_method("report_civilian_harmed"):
			manager.call("report_civilian_harmed", was_killed, global_position)


func _flash_hit() -> void:
	var hit_material := StandardMaterial3D.new()
	hit_material.albedo_color = Color(1.0, 0.14, 0.08)
	hit_material.emission_enabled = true
	hit_material.emission = Color(0.8, 0.06, 0.03)
	hit_material.emission_energy_multiplier = 1.2
	mesh.set_surface_override_material(0, hit_material)

	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(mesh) and not _is_dead:
		if is_scanned:
			_set_scanned_tint()
		else:
			mesh.set_surface_override_material(0, _base_material)


func _die() -> void:
	_is_dead = true
	remove_from_group("scannable_npc")
	remove_from_group("damageable")
	# Police-drone trigger: only a NON-target civilian kill arms patrol drones.
	# The drone holds the policy; we just report the fact + whether this was the
	# bounty target so it can ignore a sanctioned kill.
	get_tree().call_group("police_drone", "on_civilian_killed", global_position, is_target)
	died.emit(self)
	name_label.visible = false
	collision_shape.set_deferred("disabled", true)
	set_physics_process(false)

	var death_material := StandardMaterial3D.new()
	death_material.albedo_color = Color(0.62, 0.08, 0.04)
	death_material.emission_enabled = true
	death_material.emission = Color(0.45, 0.02, 0.01)
	death_material.emission_energy_multiplier = 0.8
	mesh.set_surface_override_material(0, death_material)

	var tween := create_tween()
	tween.tween_property(mesh, "scale", mesh.scale * Vector3(1.15, 0.18, 1.15), death_cleanup_delay)
	tween.parallel().tween_property(mesh, "position:y", 0.16, death_cleanup_delay)
	tween.tween_interval(1.5)
	tween.tween_callback(queue_free)


# --- Crowd yielding ----------------------------------------------------------

func _apply_player_push() -> void:
	if _player == null:
		return
	var away := global_position - _player.global_position
	away.y = 0.0
	var dist := away.length()
	if dist > push_radius or dist < 0.001:
		return
	var shove := away.normalized() * (push_radius - dist) * push_strength
	velocity.x += shove.x
	velocity.z += shove.z


# --- Wandering ---------------------------------------------------------------

func _process_wander(delta: float) -> void:
	_gait_time += delta
	match _wander_state:
		WanderState.IDLE:
			velocity.x = 0.0
			velocity.z = 0.0
			_wander_timer -= delta
			if _wander_timer <= 0.0:
				_wander_target = _pick_destination()
				_wander_state = WanderState.WALK
				_wander_timer = randf_range(5.0, 14.0)  # walk timeout
		WanderState.WALK:
			_wander_timer -= delta
			var to_target := _wander_target - global_position
			to_target.y = 0.0
			if to_target.length() < route_point_reach_distance or _wander_timer <= 0.0:
				_wander_state = WanderState.IDLE
				_wander_timer = _dwell_pause()
				return
			var dir := to_target.normalized()
			var speed := walk_speed * _gait_factor()
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			if velocity.length_squared() > 0.01:
				var flat := Vector3(velocity.x, 0.0, velocity.z)
				look_at(global_position + flat, Vector3.UP)


## Movement tells expressed as gait so binoculars/observation can read them.
## RULED 6/17: only TRANSFORM-readable tells (speed / dwell / path) are
## load-bearing; vertical bob + gaze offset were dropped (don't read on a flat
## billboard). `movement_tell` values come from data/crowd_traits_hesperus.json:
## heavy gait | limp | fast walker | shuffler | steady pace.
func _tell_profile() -> Dictionary:
	match movement_tell:
		"heavy gait":
			# Slow, deliberate, takes the center lane. Korvaxi's own tell.
			return {"speed": 0.7, "dwell": "normal", "path": "center"}
		"limp":
			# Halting pace + frequent short stops, keeps to the edges.
			return {"speed": 0.6, "dwell": "frequent", "path": "wall_hug"}
		"fast walker":
			# Quick, rarely pauses, cuts straight through.
			return {"speed": 1.5, "dwell": "rare", "path": "center"}
		"shuffler":
			# Slow, stop-start, meandering line.
			return {"speed": 0.72, "dwell": "frequent", "path": "weave"}
		"steady pace":
			# The null tell — unremarkable on purpose (shouldn't narrow much).
			return {"speed": 1.0, "dwell": "normal", "path": "center"}
		_:
			return {"speed": 1.0, "dwell": "normal", "path": "center"}


## Speed multiplier for the current tell. `limp` keeps a subtle halting PULSE
## (reads as an uneven pace, not a billboard bob — the dropped vertical_bob).
func _gait_factor() -> float:
	var base: float = _tell_profile().get("speed", 1.0)
	if movement_tell == "limp":
		return base * (0.6 + 0.4 * absf(sin(_gait_time * 3.2)))
	return base


## Dwell cadence as a movement tell: how long this NPC lingers between legs.
## `frequent` stoppers pause noticeably longer (reads as a loiterer), `rare`
## barely stop (reads as always-on-the-move), `normal` is the baseline range.
func _dwell_pause() -> float:
	var base := randf_range(route_pause_min, route_pause_max)
	match _tell_profile().get("dwell", "normal"):
		"frequent":
			return base * randf_range(1.6, 2.4) + 0.6
		"rare":
			return base * 0.25
		_:
			return base


func _pick_destination() -> Vector3:
	if _route.size() >= 2:
		if randf() < _loiter_chance:
			return _pick_loiter_point()
		return _next_route_point()

	if _corridor.size() >= 2:
		var seg := randi() % (_corridor.size() - 1)
		var a: Vector3 = _corridor[seg]
		var b: Vector3 = _corridor[seg + 1]
		var p: Vector3 = a.lerp(b, randf())
		var dir := b - a
		dir.y = 0.0
		if dir.length_squared() > 0.001:
			var perp := dir.normalized().cross(Vector3.UP)
			p += perp * randf_range(-_corridor_half_width, _corridor_half_width)
		p.y = global_position.y
		return p
	var angle := randf() * TAU
	var dist := randf_range(wander_radius * 0.3, wander_radius)
	return _home + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)


func _next_route_point() -> Vector3:
	# Occasional long strides (skip a point) and direction flips keep the
	# flow from reading as a conveyor belt.
	var step := _route_direction * (2 if randf() < 0.25 else 1)
	if randf() < 0.12:
		_route_direction = -_route_direction
		step = _route_direction
	_route_index += step
	if _route_index >= _route.size():
		_route_index = max(_route.size() - 2, 0)
		_route_direction = -1
	elif _route_index < 0:
		_route_index = min(1, _route.size() - 1)
		_route_direction = 1

	return _offset_from_route(_route[_route_index])


func _pick_loiter_point() -> Vector3:
	var anchor := _route[_route_index]
	var angle := randf() * TAU
	var dist := randf_range(0.8, wander_radius)
	var point := anchor + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	point.y = global_position.y
	return point


func _offset_from_route(point: Vector3) -> Vector3:
	var route_dir := Vector3.FORWARD
	if _route.size() >= 2:
		var previous_index: int = clampi(_route_index - _route_direction, 0, _route.size() - 1)
		route_dir = point - _route[previous_index]
		route_dir.y = 0.0
	if route_dir.length_squared() < 0.001:
		route_dir = Vector3.FORWARD
	var side := route_dir.normalized().cross(Vector3.UP)
	var offset := _path_offset()
	var result := point + side * offset
	result.y = global_position.y
	return result


## Path style as a movement tell: where in the lane this NPC walks.
##  center   — hugs the centerline (small jitter); deliberate, reads as confident.
##  wall_hug — sticks to ONE side of the corridor (stable per-NPC side); furtive.
##  weave    — oscillates across the lane over time; meandering, reads as aimless.
func _path_offset() -> float:
	match _tell_profile().get("path", "center"):
		"center":
			return randf_range(-_route_jitter, _route_jitter) * 0.25
		"wall_hug":
			# Stable side per NPC (instance-id parity) so they don't flip sides.
			var hug_side := 1.0 if (get_instance_id() % 2 == 0) else -1.0
			return hug_side * _route_jitter * randf_range(0.8, 1.0)
		"weave":
			return sin(_gait_time * 1.6 + float(get_instance_id() % 7)) * _route_jitter
		_:
			return randf_range(-_route_jitter, _route_jitter)


# --- Scanner contract ---------------------------------------------------------
# NPCs stay re-scannable: the readout is an intel-comparison tool. Scanned
# tint persists as an "already checked" marker.

func is_scannable() -> bool:
	return true


func begin_focus() -> void:
	name_label.visible = true
	_completed_this_focus = false
	_scan_progress = 0.0
	_set_highlight(true)


func end_focus() -> void:
	name_label.visible = false
	_set_highlight(false)
	_scan_progress = 0.0
	_completed_this_focus = false


func scan(delta: float) -> float:
	_scan_progress = minf(_scan_progress + delta, scan_time_required)
	if _scan_progress >= scan_time_required and not _completed_this_focus:
		_complete_scan()
	return _scan_progress


func get_scan_text() -> String:
	if is_scanned:
		return "RE-SCANNING SUBJECT..."
	return "SCANNING SUBJECT..."


func get_scan_time_required() -> float:
	return scan_time_required


func _complete_scan() -> void:
	_completed_this_focus = true
	is_scanned = true
	_set_scanned_tint()
	npc_scanned.emit(self)
	print("NPC scanned: %s (candidate=%s target=%s)" % [npc_name, is_candidate, is_target])


# --- Confrontation (accusation) + witness canvassing ---------------------------
# CANDIDATES: scanned + unconfronted -> CONFRONT (BountyManager rules on it).
# CIVILIANS: if dealt a witness hint -> ASK (one-liner reveals a target trait;
# never the scanner signature - that stays scanner-only).

func get_interaction_text() -> String:
	if is_candidate:
		if was_confronted:
			return "%s: already confronted" % npc_name
		if not is_scanned:
			return ""
		return "Press E: Confront %s" % npc_name
	if witness_hint_category.is_empty() or _witness_used:
		return ""
	if _clam_timer > 0.0:
		return "%s won't talk after that scene" % npc_name
	return "Press E: Ask %s about the bounty" % npc_name


func interact(_interacting_player: Node) -> void:
	if is_candidate:
		if was_confronted or not is_scanned:
			return
		get_tree().call_group("bounty_manager", "on_npc_accused", self)
		return
	_give_witness_hint()


func _give_witness_hint() -> void:
	if _witness_used or witness_hint_category.is_empty():
		return
	if _clam_timer > 0.0:
		var hud_busy := get_tree().get_first_node_in_group("hud")
		if hud_busy != null and hud_busy.has_method("show_toast"):
			hud_busy.call("show_toast", "\"After that? I didn't see anything.\"", 2.5)
		return
	_witness_used = true

	var intel := get_node_or_null("/root/BountyIntel")
	if intel != null and intel.has_method("learn"):
		intel.call("learn", witness_hint_category, witness_hint_value, "witness: %s" % npc_name)

	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", _witness_line(), 3.5)
	print("Witness %s: %s = %s" % [npc_name, witness_hint_category, witness_hint_value])


func _witness_line() -> String:
	match witness_hint_category:
		"appearance":
			return "\"The korvaxi you want? Seen one — %s, if I remember right.\"" % witness_hint_value
		"movement_tell":
			return "\"The walk gives 'em away: %s.\"" % witness_hint_value
		"location_habit":
			return "\"Usually hanging around — %s.\"" % witness_hint_value
		_:
			return "\"Heard something: %s.\"" % witness_hint_value


## Called by BountyManager when an accusation actually resolves
## (not on insufficient-intel attempts).
func mark_confronted() -> void:
	was_confronted = true


## Correct-accusation handoff: the crowd identity is resolved, then the staged
## Korvaxi chase actor takes over. This prevents two visible "real" targets.
func resolve_as_target_handoff() -> void:
	was_confronted = true
	is_scanned = true
	wander_enabled = false
	_wander_state = WanderState.IDLE
	velocity = Vector3.ZERO
	remove_from_group("scannable_npc")
	remove_from_group("damageable")
	name_label.visible = false
	collision_shape.set_deferred("disabled", true)
	set_physics_process(false)
	# Scale the MESH to zero, never the CharacterBody3D itself — a zero-scaled
	# body basis is singular and Jolt rejects it (set_transform warning).
	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3.ZERO, 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _set_highlight(active: bool) -> void:
	if active:
		var highlight := StandardMaterial3D.new()
		highlight.albedo_color = Color(0.55, 0.85, 1.0)
		highlight.emission_enabled = true
		highlight.emission = Color(0.1, 0.35, 0.6)
		highlight.emission_energy_multiplier = 0.9
		mesh.set_surface_override_material(0, highlight)
	else:
		if is_scanned:
			_set_scanned_tint()
		else:
			mesh.set_surface_override_material(0, null)


func _set_scanned_tint() -> void:
	var scanned := StandardMaterial3D.new()
	scanned.albedo_color = Color(0.4, 0.75, 0.5)
	scanned.emission_enabled = true
	scanned.emission = Color(0.06, 0.3, 0.12)
	scanned.emission_energy_multiplier = 0.6
	mesh.set_surface_override_material(0, scanned)
