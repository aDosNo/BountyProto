extends Node3D

signal powered_changed(powered: bool)

@export var powered: bool = true


func _ready() -> void:
	add_to_group("east_microhub_power")
	call_deferred("_broadcast_power")


func toggle_power() -> void:
	set_powered(not powered)


func set_powered(active: bool) -> void:
	if powered == active:
		return
	powered = active
	_broadcast_power()


func _broadcast_power() -> void:
	powered_changed.emit(powered)
	for consumer in get_tree().get_nodes_in_group("east_microhub_power_consumer"):
		if consumer.has_method("set_powered"):
			consumer.call("set_powered", powered)
	print("East micro-hub power: %s" % ("ON" if powered else "OFF"))
