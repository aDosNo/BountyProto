extends StaticBody3D

@export var health: int = 75
@export var starts_active: bool = false
@export var attack_damage: int = 8
@export var attack_range: float = 28.0
@export var attack_cooldown: float = 1.1
@export var eye_height: float = 1.5

@onready var mesh: MeshInstance3D = %GuardMesh
@onready var collision_shape: CollisionShape3D = %CollisionShape3D

var _base_material: Material
var _is_dead: bool = false
var _next_attack_time: float = 0.0
var _player: Node3D


func _ready() -> void:
	add_to_group("pressure_enemy")
	_base_material = mesh.get_active_material(0)
	set_active(starts_active)


func set_active(active: bool) -> void:
	if _is_dead:
		return

	visible = active
	collision_shape.disabled = not active
	set_process(active)
	set_physics_process(active)


func _physics_process(_delta: float) -> void:
	if _is_dead:
		return

	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		return

	var now := Time.get_ticks_msec() / 1000.0
	if now < _next_attack_time:
		return

	if _can_see_player():
		_next_attack_time = now + attack_cooldown
		_attack_player()


func _can_see_player() -> bool:
	var origin := global_position + Vector3(0.0, eye_height, 0.0)
	var player_point := _player.global_position + Vector3(0.0, 1.0, 0.0)
	if origin.distance_to(player_point) > attack_range:
		return false

	var query := PhysicsRayQueryParameters3D.create(origin, player_point)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false

	var collider := hit["collider"] as Node
	return collider != null and collider.is_in_group("player")


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
