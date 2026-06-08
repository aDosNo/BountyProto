extends StaticBody3D

@export var bounty_manager_path: NodePath
@export var prompt_text: String = "Press E: Accept Korvaxi contract"
@export var accepted_text: String = "Contract accepted: Korvaxi Jurraal"
@export var accepted_prompt_text: String = "Korvaxi contract active"

var _accepted: bool = false
var _bounty_manager: Node


func _ready() -> void:
	add_to_group("bounty_board")
	_bounty_manager = get_node_or_null(bounty_manager_path)


func get_interaction_text() -> String:
	return accepted_prompt_text if _accepted else prompt_text


func interact(_player: Node) -> void:
	if _accepted:
		return

	if _bounty_manager == null:
		_bounty_manager = get_node_or_null(bounty_manager_path)
	if _bounty_manager == null or not _bounty_manager.has_method("accept_bounty"):
		push_warning("BountyBoard could not find a BountyManager with accept_bounty().")
		return

	_accepted = true
	_bounty_manager.call("accept_bounty")

	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", accepted_text)
