extends StaticBody3D

@export var role: String = ""
@export var activity_path: NodePath


func get_interaction_text() -> String:
	var activity := get_node_or_null(activity_path)
	if activity != null and activity.has_method("get_prompt"):
		return String(activity.call("get_prompt", role))
	return ""


func interact(player: Node) -> void:
	var activity := get_node_or_null(activity_path)
	if activity != null and activity.has_method("interact"):
		activity.call("interact", role, player)
