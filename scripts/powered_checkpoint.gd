extends StaticBody3D

@export var required_access_tag: String = "courtyard_service"
@export var slide_distance: float = 3.2
@export var slide_time: float = 0.7

var _powered := true
var _open := false
var _failed_open := false
var _closed_position: Vector3

@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	_closed_position = position
	add_to_group("east_microhub_power_consumer")


func adopt_current_position_as_closed() -> void:
	# Used when a Blender-authored placement is promoted onto this functional
	# node after _ready(). Opening and power restoration must return to that
	# authored doorway, not the original procedural placeholder position.
	_closed_position = position


func get_interaction_text() -> String:
	if _open:
		return ""
	if not _powered:
		return "Press E: Open failed checkpoint"
	return "Press E: Present service credentials"


func interact(player: Node) -> void:
	if _open:
		return
	if not _powered or (player.has_method("has_access_tag") and player.call("has_access_tag", required_access_tag)):
		_open_door()
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", "Checkpoint denies access.", 2.0)


func set_powered(active: bool) -> void:
	_powered = active
	if not _powered and not _open:
		_failed_open = true
		_open_door()
	elif _powered and _open and _failed_open:
		_close_door()


func _open_door() -> void:
	_open = true
	collision_shape.set_deferred("disabled", true)
	create_tween().tween_property(self, "position", _closed_position + Vector3.UP * slide_distance, slide_time)


func _close_door() -> void:
	_open = false
	_failed_open = false
	var tween := create_tween()
	tween.tween_property(self, "position", _closed_position, slide_time)
	tween.tween_callback(func() -> void: collision_shape.set_deferred("disabled", false))
