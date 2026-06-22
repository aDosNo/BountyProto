extends StaticBody3D

@export var activity: NodePath


func get_interaction_text() -> String:
	return "Press E: Call courtyard delivery meeting"


func interact(_player: Node) -> void:
	var coordinator := get_node_or_null(activity)
	if coordinator != null:
		coordinator.call_delivery_meeting()
