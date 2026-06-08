extends CanvasLayer

@export var hit_marker_duration: float = 0.12
@export var hit_flash_duration: float = 0.18
@export var damage_flash_alpha: float = 0.42
@export var retro_visuals_enabled: bool = true
@export var weapon_overlay_enabled: bool = false
@export var weapon_overlay_bob_amount: float = 7.0
@export var weapon_overlay_bob_speed: float = 6.0

@onready var retro_overlay: ColorRect = %RetroOverlay
@onready var weapon_sprite_overlay: Control = %WeaponSpriteOverlay
@onready var health_label: Label = %HealthLabel
@onready var ammo_label: Label = %AmmoLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var damage_flash: ColorRect = %DamageFlash
@onready var hit_marker: Control = %HitMarker
@onready var crosshair_horizontal: ColorRect = %CrosshairHorizontal
@onready var crosshair_vertical: ColorRect = %CrosshairVertical
@onready var scanner_overlay: Control = %ScannerOverlay
@onready var scanner_status_label: Label = %ScannerStatusLabel
@onready var scanner_progress_bar: ProgressBar = %ScannerProgressBar
@onready var toast_label: Label = %ToastLabel
@onready var interaction_overlay: Control = %InteractionOverlay
@onready var interaction_prompt_label: Label = %InteractionPromptLabel
@onready var capture_overlay: Control = %CaptureOverlay
@onready var capture_prompt_label: Label = %CapturePromptLabel
@onready var capture_progress_bar: ProgressBar = %CaptureProgressBar

var _base_crosshair_color := Color(0.8, 1.0, 0.8, 0.9)
var _hit_crosshair_color := Color(1.0, 0.88, 0.25, 1.0)
var _hit_marker_timer: SceneTreeTimer
var _damage_crosshair_timer: SceneTreeTimer
var _damage_flash_tween: Tween
var _toast_timer: SceneTreeTimer
var _weapon_overlay_base_position: Vector2
var _weapon_overlay_bob_time: float = 0.0


func _ready() -> void:
	add_to_group("hud")
	_weapon_overlay_base_position = weapon_sprite_overlay.position
	set_retro_visuals_enabled(retro_visuals_enabled)


func _process(delta: float) -> void:
	if weapon_sprite_overlay == null or not weapon_sprite_overlay.visible:
		return

	_weapon_overlay_bob_time += delta * weapon_overlay_bob_speed
	weapon_sprite_overlay.position = _weapon_overlay_base_position + Vector2(
		sin(_weapon_overlay_bob_time * 0.5) * weapon_overlay_bob_amount * 0.35,
		sin(_weapon_overlay_bob_time) * weapon_overlay_bob_amount
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		set_retro_visuals_enabled(not retro_visuals_enabled)


func set_retro_visuals_enabled(enabled: bool) -> void:
	retro_visuals_enabled = enabled
	if retro_overlay != null:
		retro_overlay.visible = enabled
	if weapon_sprite_overlay != null:
		weapon_sprite_overlay.visible = enabled and weapon_overlay_enabled


func set_health(value: int) -> void:
	health_label.text = "Health: %d" % value
	if value <= 30:
		health_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3, 1.0))
	else:
		health_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85, 1.0))


func flash_damage(amount: int = 0) -> void:
	var flash_strength := damage_flash_alpha
	if amount > 0:
		flash_strength = clampf(damage_flash_alpha + (float(amount) * 0.01), damage_flash_alpha, 0.65)

	damage_flash.visible = true
	damage_flash.color = Color(1.0, 0.04, 0.02, flash_strength)
	if _damage_flash_tween != null:
		_damage_flash_tween.kill()

	_damage_flash_tween = create_tween()
	_damage_flash_tween.tween_property(
		damage_flash,
		"color",
		Color(1.0, 0.04, 0.02, 0.0),
		hit_flash_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_damage_flash_tween.tween_callback(func() -> void: damage_flash.visible = false)

	crosshair_horizontal.color = Color(1.0, 0.2, 0.2, 1.0)
	crosshair_vertical.color = Color(1.0, 0.2, 0.2, 1.0)
	_damage_crosshair_timer = get_tree().create_timer(0.12)
	var current_timer := _damage_crosshair_timer
	await current_timer.timeout
	if _damage_crosshair_timer == current_timer:
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


func set_interaction_prompt(text: String, active: bool) -> void:
	if interaction_overlay == null or interaction_prompt_label == null:
		return
	interaction_overlay.visible = active
	interaction_prompt_label.text = text


func show_toast(text: String, duration: float = 2.4) -> void:
	if text.is_empty():
		return
	if toast_label == null:
		return

	toast_label.text = text
	toast_label.visible = true

	_toast_timer = get_tree().create_timer(duration)
	var current_timer := _toast_timer
	await current_timer.timeout
	if _toast_timer == current_timer:
		toast_label.visible = false


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
