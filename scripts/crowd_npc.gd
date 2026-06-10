extends CharacterBody3D
## CrowdNPC — scannable market civilian for the identity funnel.
## Identities can be set per-instance via exports, or dealt at runtime by
## CrowdDirector through apply_identity(). Movement tells are expressed
## through wander speed/gait so observation is a real intel source.

signal npc_scanned(npc: Node)

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
@export var wander_radius: float = 6.0
@export var walk_speed: float = 1.6

const GRAVITY := 18.0

enum WanderState { IDLE, WALK }

@onready var mesh: MeshInstance3D = %NpcMesh
@onready var name_label: Label3D = %NameLabel

var is_scanned: bool = false
var _scan_progress: float = 0.0
var _wander_state: WanderState = WanderState.IDLE
var _wander_timer: float = 0.0
var _wander_target: Vector3
var _home: Vector3
var _gait_time: float = 0.0
var _corridor: Array = []
var _corridor_half_width: float = 2.4


func set_corridor(points: Array, half_width: float) -> void:
	_corridor = points
	_corridor_half_width = half_width


func _ready() -> void:
	add_to_group("scannable_npc")
	_home = global_position
	name_label.text = npc_name
	name_label.visible = false
	_wander_timer = randf_range(0.5, 3.0)


func apply_identity(d: Dictionary) -> void:
	npc_name = d.get("npc_name", npc_name)
	build = d.get("build", build)
	appearance = d.get("appearance", appearance)
	movement_tell = d.get("movement_tell", movement_tell)
	location_habit = d.get("location_habit", location_habit)
	scanner_signature = d.get("scanner_signature", scanner_signature)
	is_candidate = d.get("is_candidate", is_candidate)
	is_target = d.get("is_target", is_target)
	if name_label != null:
		name_label.text = npc_name


func _physics_process(delta: float) -> void:
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

	if wander_enabled:
		_process_wander(delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()


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
				_wander_timer = randf_range(8.0, 16.0)  # walk timeout
		WanderState.WALK:
			_wander_timer -= delta
			var to_target := _wander_target - global_position
			to_target.y = 0.0
			if to_target.length() < 0.4 or _wander_timer <= 0.0:
				_wander_state = WanderState.IDLE
				_wander_timer = randf_range(0.6, 2.5)
				return
			var dir := to_target.normalized()
			var speed := walk_speed * _gait_factor()
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			if velocity.length_squared() > 0.01:
				var flat := Vector3(velocity.x, 0.0, velocity.z)
				look_at(global_position + flat, Vector3.UP)


## Movement tells expressed as gait so binoculars/observation can read them.
func _gait_factor() -> float:
	match movement_tell:
		"limp":
			return 0.55 * (0.6 + 0.4 * absf(sin(_gait_time * 3.2)))
		"fast walker":
			return 1.55
		"shuffler":
			return 0.7
		_:
			return 1.0


func _pick_destination() -> Vector3:
	if _corridor.size() >= 2:
		# Stroll the street: random point along the corridor polyline + lateral offset.
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
	# Fallback: radius wander around home.
	var angle := randf() * TAU
	var dist := randf_range(wander_radius * 0.3, wander_radius)
	return _home + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)


# --- Scanner contract -------------------------------------------------------

func is_scannable() -> bool:
	return true


func begin_focus() -> void:
	name_label.visible = true
	_set_highlight(true)


func end_focus() -> void:
	name_label.visible = false
	_set_highlight(false)
	if not is_scanned:
		_scan_progress = 0.0


func scan(delta: float) -> float:
	_scan_progress = minf(_scan_progress + delta, scan_time_required)
	if _scan_progress >= scan_time_required and not is_scanned:
		_complete_scan()
	return _scan_progress


func get_scan_text() -> String:
	if is_scanned:
		return "SUBJECT SCANNED"
	return "SCANNING SUBJECT..."


func _complete_scan() -> void:
	is_scanned = true
	_set_scanned_tint()
	npc_scanned.emit(self)
	print("NPC scanned: %s (candidate=%s target=%s)" % [npc_name, is_candidate, is_target])


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
