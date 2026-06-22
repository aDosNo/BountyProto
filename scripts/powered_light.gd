extends OmniLight3D

@export var emergency_energy: float = 0.0
var _normal_energy := 1.0


func _ready() -> void:
	_normal_energy = light_energy
	add_to_group("east_microhub_power_consumer")


func set_powered(active: bool) -> void:
	light_energy = _normal_energy if active else emergency_energy
