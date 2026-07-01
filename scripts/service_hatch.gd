extends StaticBody3D
## Two-way service opening used for short, explicit crawl bypasses.

@export var destination: NodePath
@export var required_clear_flag: String = ""
@export var state_flag: String = ""


func get_interaction_text() -> String:
	if not required_clear_flag.is_empty() and not _has_flag(required_clear_flag):
		return "Steam pressure blocks the service crawl"
	return "Press E: Crawl through service grate"


func interact(player: Node) -> void:
	if player == null or not player is Node3D:
		return
	if not required_clear_flag.is_empty() and not _has_flag(required_clear_flag):
		_toast("The crawl is flooded with scalding steam. Find the pressure valve.", 2.8)
		return
	var marker := get_node_or_null(destination) as Marker3D
	if marker == null:
		return
	(player as Node3D).global_position = marker.global_position
	if player.has_method("_set_crouched"):
		player.call("_set_crouched", true)
	if not state_flag.is_empty():
		var district_state := get_node_or_null("/root/DistrictState")
		if district_state != null:
			district_state.call("set_flag", state_flag, true)
	_toast("Service crawl traversed.", 1.4)


func _has_flag(state_id: String) -> bool:
	var district_state := get_node_or_null("/root/DistrictState")
	return district_state != null and bool(district_state.call("has_flag", state_id))


func _toast(text: String, duration: float) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", text, duration)
