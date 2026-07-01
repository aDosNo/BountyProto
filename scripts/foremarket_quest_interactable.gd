extends StaticBody3D

@export_enum("intake", "fuse", "relay", "credential", "roof_override", "locker")
var role: String = "intake"
@export var activity: NodePath = NodePath("..")


func get_interaction_text() -> String:
	var coordinator := get_node_or_null(activity)
	if coordinator == null or not coordinator.has_method("get_prompt"):
		return ""
	return coordinator.call("get_prompt", role) as String


func interact(player: Node) -> void:
	var coordinator := get_node_or_null(activity)
	if coordinator != null and coordinator.has_method("interact"):
		coordinator.call("interact", role, player)
