extends StaticBody3D

@export var activity: NodePath
var _taken := false


func get_interaction_text() -> String:
	return "" if _taken else "Press E: Take courier delivery package"


func interact(_player: Node) -> void:
	if _taken:
		return
	var coordinator := get_node_or_null(activity)
	if coordinator == null:
		return
	_taken = true
	coordinator.collect_package()
	visible = false
	$CollisionShape3D.set_deferred("disabled", true)
