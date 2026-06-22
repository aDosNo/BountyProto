extends StaticBody3D
## LockedDoor — placeable locked route. Interact while locked = refusal text.
## Unlock via a linked BypassSwitch (or any script calling unlock()), then
## interact slides it open. Post-sprint: lockpick/decoder items call unlock()
## directly — same hook, purchased verb.

signal unlocked
signal opened

@export var locked: bool = true
@export var locked_text: String = "Locked. There must be another way."
@export var open_prompt: String = "Press E: Open door"
@export var slide_axis: Vector3 = Vector3.UP  ## local direction the door slides when opening
@export var slide_distance: float = 3.2
@export var slide_time: float = 0.9

var _open: bool = false
var _animating: bool = false

@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group("locked_door")


func get_interaction_text() -> String:
	if _open:
		return ""
	if locked:
		return "Locked"
	return open_prompt


func interact(_player: Node) -> void:
	if _open or _animating:
		return
	if locked:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("show_toast"):
			hud.call("show_toast", locked_text, 2.0)
		print("LockedDoor: refused (locked).")
		return
	_open_door()


## Public unlock hook: BypassSwitch, lockpick item, mission scripting.
func unlock() -> void:
	if not locked:
		return
	locked = false
	unlocked.emit()
	print("LockedDoor unlocked: %s" % name)


func _open_door() -> void:
	_animating = true
	_open = true
	collision_shape.set_deferred("disabled", true)
	var direction := (global_transform.basis * slide_axis.normalized())
	var tween := create_tween()
	tween.tween_property(self, "global_position", global_position + direction * slide_distance, slide_time)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void: _animating = false)
	opened.emit()
	print("LockedDoor opened: %s" % name)
