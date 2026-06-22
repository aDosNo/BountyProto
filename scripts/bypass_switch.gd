extends StaticBody3D
## BypassSwitch — breaker/keypad that unlocks a linked LockedDoor. The other
## half of the lock/bypass template: front door locked, switch hidden around
## the back/up the catwalk. Optionally noisy (old breakers clunk).

@export var target_door: NodePath
@export var prompt_text: String = "Press E: Force breaker"
@export var used_text: String = "Breaker forced. Something unlocked."
@export var make_noise: bool = true
@export var noise_loudness: float = 10.0

var _used: bool = false

@onready var mesh: MeshInstance3D = $SwitchMesh


func get_interaction_text() -> String:
	if _used:
		return ""
	return prompt_text


func interact(_player: Node) -> void:
	if _used:
		return
	_used = true

	var door := get_node_or_null(target_door)
	if door != null and door.has_method("unlock"):
		door.call("unlock")
	else:
		push_warning("BypassSwitch '%s' has no valid target_door." % name)

	if make_noise:
		get_tree().call_group("perceptive", "hear_noise", global_position, noise_loudness)

	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", used_text, 2.2)

	_set_used_visual()
	print("BypassSwitch used: %s" % name)


func _set_used_visual() -> void:
	if mesh == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.9, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.06, 0.4, 0.12)
	mat.emission_energy_multiplier = 1.2
	mesh.set_surface_override_material(0, mat)
