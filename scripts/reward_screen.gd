extends Control

@onready var title_label: Label = %TitleLabel
@onready var target_label: Label = %TargetLabel
@onready var status_label: Label = %StatusLabel
@onready var reward_label: Label = %RewardLabel

const COLOR_COMPLETE := Color(1.0, 0.92, 0.45, 1.0)
const COLOR_FAILED := Color(1.0, 0.4, 0.35, 1.0)
const COLOR_REWARD := Color(0.75, 1.0, 0.62, 1.0)
const COLOR_NEUTRAL := Color(0.9, 0.92, 1.0, 1.0)

var _shown: bool = false


func _ready() -> void:
	add_to_group("reward_screen")
	# Keep processing while the tree is paused so this screen stays interactive
	# and visible after we freeze the rest of the game.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func show_reward(target_name: String, status: String, reward: int) -> void:
	title_label.text = "CONTRACT COMPLETE"
	title_label.add_theme_color_override("font_color", COLOR_COMPLETE)
	target_label.text = "Target: %s" % target_name
	status_label.text = "Status: %s" % status
	status_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	reward_label.text = "Reward: %d CR" % reward
	reward_label.add_theme_color_override("font_color", COLOR_REWARD)
	_show()


func show_failure(target_name: String) -> void:
	title_label.text = "CONTRACT FAILED"
	title_label.add_theme_color_override("font_color", COLOR_FAILED)
	target_label.text = "Target: %s" % target_name
	status_label.text = "Status: Hunter down"
	status_label.add_theme_color_override("font_color", COLOR_FAILED)
	reward_label.text = "Reward: 0 CR"
	reward_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	_show()


func _show() -> void:
	visible = true
	_shown = true
	# Freeze the rest of the game: guards stop firing, the player stops taking
	# damage, the chase halts. This screen keeps running via PROCESS_MODE_ALWAYS.
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _unhandled_input(event: InputEvent) -> void:
	if not _shown:
		return

	if event.is_action_pressed("reload"):
		_restart()


func _restart() -> void:
	_shown = false
	get_tree().paused = false
	get_tree().reload_current_scene()
