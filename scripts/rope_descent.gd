extends StaticBody3D

@export var destination: NodePath


func get_interaction_text() -> String:
	return "Press E: Descend rope"


func interact(player: Node) -> void:
	var marker := get_node_or_null(destination) as Marker3D
	if marker != null and player is Node3D:
		player.global_position = marker.global_position
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("show_toast"):
			hud.call("show_toast", "Committed to the courtyard.", 1.8)
