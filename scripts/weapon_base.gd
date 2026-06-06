extends Node3D

@export var magazine_size: int = 24
@export var ammo_current: int = 24
@export var ammo_reserve: int = 96
@export var fire_rate: float = 8.0
@export var damage: int = 25
@export var weapon_range: float = 80.0
@export var reload_time: float = 1.25
@export var muzzle_flash_duration: float = 0.045
@export var recoil_kick_position: Vector3 = Vector3(0.0, -0.025, 0.09)
@export var recoil_kick_rotation_degrees: Vector3 = Vector3(7.0, 0.0, 0.0)
@export var debug_fire_log: bool = false

const IMPACT_SPARK_SCENE: PackedScene = preload("res://scenes/props/ImpactSpark.tscn")

var shooter: CollisionObject3D
var aim_camera: Camera3D
var hud: CanvasLayer
var is_reloading: bool = false

var _next_fire_time: float = 0.0
var _rest_position: Vector3
var _rest_rotation: Vector3
var _weapon_tween: Tween
var _objective_before_reload: String = "FPS Kernel Test"

@onready var muzzle_flash: Node3D = %MuzzleFlash
@onready var muzzle_light: OmniLight3D = %MuzzleLight
@onready var fire_sfx: AudioStreamPlayer3D = %FireSFX
@onready var reload_sfx: AudioStreamPlayer3D = %ReloadSFX
@onready var hit_sfx: AudioStreamPlayer3D = %HitSFX


func _ready() -> void:
	_rest_position = position
	_rest_rotation = rotation


func setup(new_shooter: CollisionObject3D, new_camera: Camera3D, new_hud: CanvasLayer) -> void:
	shooter = new_shooter
	aim_camera = new_camera
	hud = new_hud
	_update_hud()


func try_fire() -> void:
	if is_reloading:
		return

	var now := Time.get_ticks_msec() / 1000.0
	if now < _next_fire_time:
		return

	if ammo_current <= 0:
		reload()
		return

	_next_fire_time = now + (1.0 / fire_rate)
	ammo_current -= 1
	_update_hud()
	_show_muzzle_flash()
	_play_fire_feedback()
	_fire_hitscan()


func reload() -> void:
	if is_reloading or ammo_current == magazine_size or ammo_reserve <= 0:
		return

	is_reloading = true
	print("Reloading...")
	if hud != null and hud.has_method("get_objective"):
		_objective_before_reload = hud.call("get_objective") as String
	if hud != null and hud.has_method("set_objective"):
		hud.call("set_objective", "Reloading...")
	_play_reload_feedback()
	await get_tree().create_timer(reload_time).timeout

	var needed := magazine_size - ammo_current
	var loaded: int = mini(needed, ammo_reserve)
	ammo_current += loaded
	ammo_reserve -= loaded
	is_reloading = false
	_update_hud()
	if hud != null and hud.has_method("set_objective"):
		hud.call("set_objective", _objective_before_reload)
	print("Reload complete. Ammo: %d / %d" % [ammo_current, ammo_reserve])


func _fire_hitscan() -> void:
	if aim_camera == null:
		push_warning("Weapon has no aim camera.")
		return

	var from := aim_camera.global_position
	var to := from + (-aim_camera.global_transform.basis.z * weapon_range)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	if shooter != null:
		query.exclude = [shooter.get_rid()]
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var space_state := get_world_3d().direct_space_state
	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		if debug_fire_log:
			print("Pistol fired. Miss.")
		return

	var collider := hit["collider"] as Object
	_spawn_impact_spark(hit)
	if debug_fire_log:
		print("Pistol hit %s at %s" % [collider, hit["position"]])
	if collider != null and collider.has_method("take_damage"):
		collider.call("take_damage", damage)
		# TODO: assign hit_sfx.
		if hit_sfx.stream != null:
			hit_sfx.play()
		if hud != null and hud.has_method("show_hit_marker"):
			hud.call("show_hit_marker")


func _show_muzzle_flash() -> void:
	muzzle_flash.visible = true
	muzzle_light.visible = true

	await get_tree().create_timer(muzzle_flash_duration).timeout
	if is_instance_valid(muzzle_flash):
		muzzle_flash.visible = false
	if is_instance_valid(muzzle_light):
		muzzle_light.visible = false


func _play_fire_feedback() -> void:
	# TODO: assign fire_sfx.
	if fire_sfx.stream != null:
		fire_sfx.play()

	if _weapon_tween != null:
		_weapon_tween.kill()

	_weapon_tween = create_tween()
	_weapon_tween.tween_property(self, "position", _rest_position + recoil_kick_position, 0.035)
	_weapon_tween.parallel().tween_property(self, "rotation_degrees", _rest_rotation_degrees() + recoil_kick_rotation_degrees, 0.035)
	_weapon_tween.tween_property(self, "position", _rest_position, 0.08)
	_weapon_tween.parallel().tween_property(self, "rotation", _rest_rotation, 0.08)


func _play_reload_feedback() -> void:
	# TODO: assign reload_sfx.
	if reload_sfx.stream != null:
		reload_sfx.play()

	if _weapon_tween != null:
		_weapon_tween.kill()

	_weapon_tween = create_tween()
	_weapon_tween.tween_property(self, "position", _rest_position + Vector3(0.0, -0.12, 0.04), reload_time * 0.35)
	_weapon_tween.parallel().tween_property(self, "rotation_degrees", _rest_rotation_degrees() + Vector3(18.0, 0.0, -8.0), reload_time * 0.35)
	_weapon_tween.tween_property(self, "position", _rest_position, reload_time * 0.55)
	_weapon_tween.parallel().tween_property(self, "rotation", _rest_rotation, reload_time * 0.55)


func _spawn_impact_spark(hit: Dictionary) -> void:
	var effect := IMPACT_SPARK_SCENE.instantiate() as Node3D
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root

	parent.add_child(effect)
	effect.global_position = hit["position"] as Vector3

	var normal := hit["normal"] as Vector3
	if normal != Vector3.ZERO:
		var up := Vector3.UP
		if abs(normal.normalized().dot(up)) > 0.98:
			up = Vector3.FORWARD
		effect.look_at(effect.global_position + normal, up)


func _rest_rotation_degrees() -> Vector3:
	return Vector3(rad_to_deg(_rest_rotation.x), rad_to_deg(_rest_rotation.y), rad_to_deg(_rest_rotation.z))


func _update_hud() -> void:
	if hud != null and hud.has_method("set_ammo"):
		hud.call("set_ammo", ammo_current, ammo_reserve)
