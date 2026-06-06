extends StaticBody3D

signal died(dummy: Node)

@export var health: int = 100
@export var hit_pulse_scale: float = 1.08
@export var death_pop_duration: float = 0.18

@onready var mesh: MeshInstance3D = %DummyMesh
@onready var collision_shape: CollisionShape3D = %CollisionShape3D

var _base_material: Material
var _base_scale: Vector3
var _mesh_base_scale: Vector3
var _is_dead: bool = false
var _pulse_tween: Tween


func _ready() -> void:
	add_to_group("target_dummies")
	_base_material = mesh.get_active_material(0)
	_base_scale = scale
	_mesh_base_scale = mesh.scale


func take_damage(amount: int) -> void:
	if _is_dead:
		return

	health = max(health - amount, 0)
	print("TargetDummy hit for %d damage. Health: %d" % [amount, health])

	if health <= 0:
		print("TargetDummy destroyed.")
		_die()
		return

	_flash_hit()
	_pulse_hit()


func _flash_hit() -> void:
	var hit_material := StandardMaterial3D.new()
	hit_material.albedo_color = Color(1.0, 0.1, 0.05)
	mesh.set_surface_override_material(0, hit_material)

	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(mesh) and not _is_dead:
		mesh.set_surface_override_material(0, _base_material)


func _pulse_hit() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()

	_pulse_tween = create_tween()
	_pulse_tween.tween_property(mesh, "scale", _mesh_base_scale * hit_pulse_scale, 0.045)
	_pulse_tween.tween_property(mesh, "scale", _mesh_base_scale, 0.075)


func _die() -> void:
	_is_dead = true
	died.emit(self)
	collision_shape.disabled = true

	var death_material := StandardMaterial3D.new()
	death_material.albedo_color = Color(1.0, 0.35, 0.1)
	death_material.emission_enabled = true
	death_material.emission = Color(1.0, 0.12, 0.02)
	death_material.emission_energy_multiplier = 1.8
	mesh.set_surface_override_material(0, death_material)

	if _pulse_tween != null:
		_pulse_tween.kill()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh, "scale", _mesh_base_scale * 1.25, death_pop_duration * 0.45)
	tween.tween_property(mesh, "transparency", 1.0, death_pop_duration)
	tween.chain().tween_property(mesh, "scale", Vector3.ONE * 0.01, death_pop_duration * 0.55)
	tween.chain().tween_callback(queue_free)
