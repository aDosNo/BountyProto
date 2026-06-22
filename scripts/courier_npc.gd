extends StaticBody3D

@export var activity: NodePath


func get_interaction_text() -> String:
	var coordinator := get_node_or_null(activity)
	if coordinator == null:
		return ""
	if coordinator.credentials_granted:
		return "Courier: delivery route is active"
	if coordinator.has_package:
		return "Press E: Return courier package"
	return "Press E: Ask courier about courtyard access"


func interact(player: Node) -> void:
	var coordinator := get_node_or_null(activity)
	if coordinator != null:
		coordinator.complete_delivery(player)
