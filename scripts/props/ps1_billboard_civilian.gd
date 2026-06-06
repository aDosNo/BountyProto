extends Node3D

@export var face_camera: bool = true

var _player: Node3D


func _process(delta: float) -> void:
	if not face_camera:
		return

	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		return

	var direction := _player.global_position - global_position
	direction.y = 0.0
	if direction == Vector3.ZERO:
		return

	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 8.0, 1.0))
