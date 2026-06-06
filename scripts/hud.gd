extends CanvasLayer

@export var hit_marker_duration: float = 0.12
@export var hit_flash_duration: float = 0.08

@onready var health_label: Label = %HealthLabel
@onready var ammo_label: Label = %AmmoLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var hit_marker: Control = %HitMarker
@onready var crosshair_horizontal: ColorRect = %CrosshairHorizontal
@onready var crosshair_vertical: ColorRect = %CrosshairVertical
@onready var scanner_overlay: Control = %ScannerOverlay
@onready var scanner_status_label: Label = %ScannerStatusLabel
@onready var scanner_progress_bar: ProgressBar = %ScannerProgressBar
@onready var capture_overlay: Control = %CaptureOverlay
@onready var capture_prompt_label: Label = %CapturePromptLabel
@onready var capture_progress_bar: ProgressBar = %CaptureProgressBar

var _base_crosshair_color := Color(0.8, 1.0, 0.8, 0.9)
var _hit_crosshair_color := Color(1.0, 0.88, 0.25, 1.0)
var _hit_marker_timer: SceneTreeTimer


func _ready() -> void:
	add_to_group("hud")


func set_health(value: int) -> void:
	health_label.text = "Health: %d" % value
	if value <= 30:
		health_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3, 1.0))
	else:
		health_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85, 1.0))


func flash_damage() -> void:
	crosshair_horizontal.color = Color(1.0, 0.2, 0.2, 1.0)
	crosshair_vertical.color = Color(1.0, 0.2, 0.2, 1.0)
	await get_tree().create_timer(0.12).timeout
	crosshair_horizontal.color = _base_crosshair_color
	crosshair_vertical.color = _base_crosshair_color


func set_ammo(current: int, reserve: int) -> void:
	ammo_label.text = "Ammo: %d / %d" % [current, reserve]


func set_objective(text: String) -> void:
	objective_label.text = text


func get_objective() -> String:
	return objective_label.text


func set_scanner_active(active: bool) -> void:
	scanner_overlay.visible = active
	if not active:
		set_scan_progress(0.0)
		set_scanner_text("")


func set_scan_progress(value: float) -> void:
	scanner_progress_bar.value = clampf(value, 0.0, 1.0)


func set_scanner_text(text: String) -> void:
	scanner_status_label.text = text


func set_capture_prompt(text: String, active: bool) -> void:
	capture_overlay.visible = active
	capture_prompt_label.text = text
	if not active:
		set_capture_progress(0.0)


func set_capture_progress(value: float) -> void:
	capture_progress_bar.value = clampf(value, 0.0, 1.0)


func show_hit_marker() -> void:
	hit_marker.visible = true
	crosshair_horizontal.color = _hit_crosshair_color
	crosshair_vertical.color = _hit_crosshair_color

	_hit_marker_timer = get_tree().create_timer(hit_marker_duration)
	await _hit_marker_timer.timeout
	hit_marker.visible = false

	await get_tree().create_timer(hit_flash_duration).timeout
	crosshair_horizontal.color = _base_crosshair_color
	crosshair_vertical.color = _base_crosshair_color
