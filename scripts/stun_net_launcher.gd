extends Node3D

@export var net_ammo: int = 3
@export var fire_cooldown: float = 0.8
@export var projectile_spawn_offset: float = 0.65

const STUN_PROJECTILE_SCENE: PackedScene = preload("res://scenes/props/StunNetProjectile.tscn")

var shooter: CollisionObject3D
var aim_camera: Camera3D
var hud: CanvasLayer

var _next_fire_time: float = 0.0
var _rest_position: Vector3
var _rest_rotation: Vector3
var _weapon_tween: Tween

@onready var muzzle_flash: Node3D = %MuzzleFlash
@onready var muzzle_light: OmniLight3D = %MuzzleLight


func _ready() -> void:
	_rest_position = position
	_rest_rotation = rotation


func setup(new_shooter: CollisionObject3D, new_camera: Camera3D, new_hud: CanvasLayer) -> void:
	shooter = new_shooter
	aim_camera = new_camera
	hud = new_hud
	_update_hud()


func on_equipped() -> void:
	_update_hud()
	if hud != null and hud.has_method("set_objective"):
		hud.call("set_objective", "Stun Net Equipped")


func try_fire() -> void:
	if aim_camera == null:
		return

	var now := Time.get_ticks_msec() / 1000.0
	if now < _next_fire_time:
		return

	if net_ammo <= 0:
		print("No stun nets remaining.")
		return

	_next_fire_time = now + fire_cooldown
	net_ammo -= 1
	_update_hud()
	_show_muzzle_flash()
	_play_fire_feedback()
	_spawn_projectile()


func reload() -> void:
	print("Stun net launcher has no reserve ammo in this prototype.")


func _spawn_projectile() -> void:
	var projectile := STUN_PROJECTILE_SCENE.instantiate() as Node3D
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root

	parent.add_child(projectile)
	var direction := -aim_camera.global_transform.basis.z
	projectile.global_position = aim_camera.global_position + (direction * projectile_spawn_offset)
	if projectile.has_method("setup"):
		projectile.call("setup", direction, shooter)


func _show_muzzle_flash() -> void:
	muzzle_flash.visible = true
	muzzle_light.visible = true
	await get_tree().create_timer(0.07).timeout
	if is_instance_valid(muzzle_flash):
		muzzle_flash.visible = false
	if is_instance_valid(muzzle_light):
		muzzle_light.visible = false


func _play_fire_feedback() -> void:
	if _weapon_tween != null:
		_weapon_tween.kill()

	_weapon_tween = create_tween()
	_weapon_tween.tween_property(self, "position", _rest_position + Vector3(0.0, -0.018, 0.075), 0.045)
	_weapon_tween.parallel().tween_property(self, "rotation_degrees", Vector3(5.0, 0.0, -3.0), 0.045)
	_weapon_tween.tween_property(self, "position", _rest_position, 0.1)
	_weapon_tween.parallel().tween_property(self, "rotation", _rest_rotation, 0.1)


func _update_hud() -> void:
	if hud != null and hud.has_method("set_ammo"):
		hud.call("set_ammo", net_ammo, 0)
