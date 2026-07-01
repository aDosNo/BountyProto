extends StaticBody3D
## Persistent pressurized-route control. Venting clears linked steam blockers,
## creates a noise stimulus, and exposes the state to chase-route selection.

@export var state_id: String = "hesperus.courtyard.steam_vented"
@export var blocker_paths: Array[NodePath] = []
@export var noise_loudness: float = 13.0

var _vented := false


func _ready() -> void:
	var district_state := get_node_or_null("/root/DistrictState")
	if district_state != null:
		_vented = bool(district_state.call("get_state", state_id, false))
	call_deferred("_apply_state")


func get_interaction_text() -> String:
	return "Steam line: vented" if _vented else "Press E: Vent service-crawl pressure"


func interact(_player: Node) -> void:
	if _vented:
		return
	_vented = true
	var district_state := get_node_or_null("/root/DistrictState")
	if district_state != null:
		district_state.call("set_flag", state_id, true)
	_apply_state()
	get_tree().call_group("perceptive", "hear_noise", global_position, noise_loudness)
	_toast("Pressure vented. The courtyard service crawl is passable.", 2.8)


func _apply_state() -> void:
	for blocker_path in blocker_paths:
		var blocker := get_node_or_null(blocker_path)
		if blocker == null:
			continue
		blocker.visible = not _vented
		var collision := blocker.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision != null:
			collision.set_deferred("disabled", _vented)


func _toast(text: String, duration: float) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", text, duration)
