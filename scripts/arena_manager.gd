extends Node

@export var objective_text: String = "Vertical Arena Test: clear all dummies"
@export var updates_hud_objective: bool = true

var remaining_dummies: int = 0
var _hud: CanvasLayer


func _ready() -> void:
	await get_tree().process_frame
	_connect_dummies()
	await get_tree().process_frame
	_hud = _find_hud()
	if updates_hud_objective:
		_set_objective("%s (%d targets)" % [objective_text, remaining_dummies])
	print("Dummies remaining: %d" % remaining_dummies)


func _connect_dummies() -> void:
	var dummies := get_tree().get_nodes_in_group("target_dummies")
	remaining_dummies = dummies.size()

	for dummy in dummies:
		if dummy.has_signal("died"):
			dummy.died.connect(_on_dummy_died)


func _on_dummy_died(_dummy: Node) -> void:
	remaining_dummies = maxi(remaining_dummies - 1, 0)
	print("Dummies remaining: %d" % remaining_dummies)

	if remaining_dummies == 0:
		if updates_hud_objective:
			_set_objective("Arena clear")
	else:
		if updates_hud_objective:
			_set_objective("Dummies remaining: %d" % remaining_dummies)


func _set_objective(text: String) -> void:
	if _hud == null:
		_hud = _find_hud()

	if _hud != null and _hud.has_method("set_objective"):
		_hud.call("set_objective", text)


func _find_hud() -> CanvasLayer:
	for child in get_tree().root.get_children():
		if child is CanvasLayer and child.has_method("set_objective"):
			return child

	return null
