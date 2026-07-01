extends Node3D

signal opened
signal closed
signal unlocked

@export var locked: bool = false
@export var locked_text: String = "Locked."
@export var open_prompt: String = "Press E: Open door"
@export var close_prompt: String = "Press E: Close door"
@export var frame_path_pattern: String = "res://art/sprites/doors/door1_open/Door1_%03d.png"
@export var frame_count: int = 18
@export var frames_per_second: float = 18.0
@export var close_on_interact: bool = true
@export var state_id: String = ""

var _frames: Array[Texture2D] = []
var _frame_index: int = 0
var _open: bool = false
var _animating: bool = false

@onready var _sprite: Sprite3D = $DoorSprite
@onready var _blocker_shape: CollisionShape3D = $DoorBlocker/CollisionShape3D


func _ready() -> void:
	add_to_group("sprite_door")
	_load_frames()
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.double_sided = true
	_apply_frame()
	call_deferred("_restore_persistent_state")


func get_interaction_text() -> String:
	if _animating:
		return ""
	if locked:
		return "Locked"
	if _open:
		return close_prompt if close_on_interact else ""
	return open_prompt


func interact(_player: Node) -> void:
	if _animating:
		return
	if locked:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("show_toast"):
			hud.call("show_toast", locked_text, 2.0)
		return
	if _open:
		if close_on_interact:
			_close_door()
	else:
		_open_door()


func unlock() -> void:
	if not locked:
		return
	locked = false
	_set_persistent_flag("unlocked", true)
	unlocked.emit()


func open() -> void:
	if locked or _open or _animating:
		return
	_open_door()


func close() -> void:
	if not _open or _animating:
		return
	_close_door()


func _load_frames() -> void:
	_frames.clear()
	for index in range(1, frame_count + 1):
		var path := frame_path_pattern % index
		var texture := load(path) as Texture2D
		if texture == null:
			push_error("SpriteDoor3D missing frame: %s" % path)
			continue
		_frames.append(texture)


func _apply_frame() -> void:
	if _frames.is_empty():
		return
	_frame_index = clampi(_frame_index, 0, _frames.size() - 1)
	_sprite.texture = _frames[_frame_index]


func _open_door() -> void:
	_open = true
	_set_persistent_flag("open", true)
	await _animate_to(_frames.size() - 1)
	_blocker_shape.set_deferred("disabled", true)
	opened.emit()


func _close_door() -> void:
	_open = false
	_set_persistent_flag("open", false)
	await _animate_to(0)
	_blocker_shape.set_deferred("disabled", false)
	closed.emit()


func _animate_to(target_index: int) -> void:
	if _frames.is_empty():
		return
	_animating = true
	target_index = clampi(target_index, 0, _frames.size() - 1)
	var step := 1 if target_index > _frame_index else -1
	var delay := 1.0 / maxf(frames_per_second, 1.0)
	while _frame_index != target_index:
		_frame_index += step
		_apply_frame()
		await get_tree().create_timer(delay).timeout
	_animating = false


func _restore_persistent_state() -> void:
	if state_id.is_empty():
		return
	var district_state := get_node_or_null("/root/DistrictState")
	if district_state == null:
		return
	var was_unlocked := bool(district_state.call("get_state", "%s.unlocked" % state_id, false))
	var was_open := bool(district_state.call("get_state", "%s.open" % state_id, false))
	if was_unlocked or was_open:
		locked = false
	if was_open:
		_open = true
		_frame_index = _frames.size() - 1
		_apply_frame()
		_blocker_shape.set_deferred("disabled", true)


func _set_persistent_flag(suffix: String, active: bool) -> void:
	if state_id.is_empty():
		return
	var district_state := get_node_or_null("/root/DistrictState")
	if district_state != null:
		district_state.call("set_flag", "%s.%s" % [state_id, suffix], active)
