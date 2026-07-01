extends Node3D

signal powered_changed(powered: bool)

@export var powered: bool = true
@export var state_id: String = "hesperus.north_service.power"


func _ready() -> void:
	add_to_group("east_microhub_power")
	var district_state := get_node_or_null("/root/DistrictState")
	if district_state != null and district_state.has_method("get_state"):
		powered = bool(district_state.call("get_state", state_id, powered))
		district_state.call("set_flag", "%s_cut" % state_id, not powered)
	call_deferred("_broadcast_power")


func toggle_power() -> void:
	set_powered(not powered)


func set_powered(active: bool) -> void:
	if powered == active:
		return
	powered = active
	var district_state := get_node_or_null("/root/DistrictState")
	if district_state != null and district_state.has_method("set_state"):
		district_state.call("set_state", state_id, powered)
		district_state.call("set_flag", "%s_cut" % state_id, not powered)
	_broadcast_power()


func _broadcast_power() -> void:
	powered_changed.emit(powered)
	for consumer in get_tree().get_nodes_in_group("east_microhub_power_consumer"):
		if consumer.has_method("set_powered"):
			consumer.call("set_powered", powered)
	print("East micro-hub power: %s" % ("ON" if powered else "OFF"))
