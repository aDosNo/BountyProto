extends StaticBody3D

@export var power_grid: NodePath
@export var noise_loudness: float = 12.0


func get_interaction_text() -> String:
	var grid := get_node_or_null(power_grid)
	if grid == null:
		return ""
	return "Press E: %s alley power" % ("cut" if grid.powered else "restore")


func interact(_player: Node) -> void:
	var grid := get_node_or_null(power_grid)
	if grid == null:
		return
	grid.toggle_power()
	get_tree().call_group("perceptive", "hear_noise", global_position, noise_loudness)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_toast"):
		var text := "Power cut: checkpoint failed open; vendors shut down." if not grid.powered else "Alley power restored."
		hud.call("show_toast", text, 3.0)
