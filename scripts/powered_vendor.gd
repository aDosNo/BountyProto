extends Node3D

@export var shutter_drop_time: float = 0.3
var _powered := true
var _closed_y: float
var _open_y: float

@onready var shutter: Node3D = $Shutter


func _ready() -> void:
	add_to_group("east_microhub_power_consumer")
	_closed_y = shutter.position.y
	_open_y = _closed_y + 2.8
	shutter.position.y = _open_y


func set_powered(active: bool) -> void:
	_powered = active
	var target_y := _open_y if _powered else _closed_y
	create_tween().tween_property(shutter, "position:y", target_y, shutter_drop_time)


func is_service_available() -> bool:
	return _powered
