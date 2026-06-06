extends Node3D

@export var speed: float = 20.0
@export var lifetime: float = 2.0
@export var stun_duration: float = 5.0

const IMPACT_SPARK_SCENE: PackedScene = preload("res://scenes/props/ImpactSpark.tscn")

var direction: Vector3 = Vector3.FORWARD
var shooter: CollisionObject3D

var _age: float = 0.0


func setup(new_direction: Vector3, new_shooter: CollisionObject3D = null) -> void:
	direction = new_direction.normalized()
	shooter = new_shooter
	if direction != Vector3.ZERO:
		look_at(global_position + direction, Vector3.UP)


func _physics_process(delta: float) -> void:
	var from := global_position
	var to := from + (direction * speed * delta)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	if shooter != null:
		query.exclude = [shooter.get_rid()]
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_on_hit(hit)
		return

	global_position = to
	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_hit(hit: Dictionary) -> void:
	var collider := hit["collider"] as Object
	if collider != null and collider.has_method("apply_stun"):
		collider.call("apply_stun", stun_duration)
		print("Stun net hit capturable target.")

	_spawn_impact_spark(hit)
	queue_free()


func _spawn_impact_spark(hit: Dictionary) -> void:
	var effect := IMPACT_SPARK_SCENE.instantiate() as Node3D
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root

	parent.add_child(effect)
	effect.global_position = hit["position"] as Vector3
