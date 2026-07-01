extends CanvasLayer

@export var hit_marker_duration: float = 0.12
@export var hit_flash_duration: float = 0.18
@export var damage_flash_alpha: float = 0.42
@export var retro_visuals_enabled: bool = true
@export var weapon_overlay_enabled: bool = true
@export var weapon_overlay_bob_amount: float = 0.0
@export var weapon_overlay_bob_speed: float = 6.0

@onready var retro_overlay: ColorRect = %RetroOverlay
@onready var weapon_sprite_overlay: Control = %WeaponSpriteOverlay
@onready var weapon_sprite: TextureRect = %WeaponSprite
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
var _weapon_overlay_active: bool = false
var _weapon_animation_id: int = 0
var _intel_rows: Dictionary = {}
var _intel_counter: Label = null
var _intel_required: int = 3
var _lead_rows: Array[Label] = []
var _binocular_overlay: Control = null
var _binocular_zoom_label: Label = null
var _navigation_label: Label = null
var _navigation_update_accum := 0.0
var _last_zone_name := ""

const WEAPON_RUNTIME_ATLAS: Texture2D = preload("res://art/sprites/weapons/fps_revolver_runtime_atlas.png")
const WEAPON_FRAME_SIZE := Vector2(512.0, 320.0)


func _ready() -> void:
	add_to_group("hud")
	_weapon_overlay_base_position = weapon_sprite_overlay.position
	set_weapon_sprite_frame("idle", 0)
	set_retro_visuals_enabled(retro_visuals_enabled)
	_build_binocular_overlay()
	_build_intel_panel()
	_build_navigation_panel()


func _process(delta: float) -> void:
	_navigation_update_accum += delta
	if _navigation_update_accum >= 0.2:
		_navigation_update_accum = 0.0
		_update_navigation_panel()
	if weapon_sprite_overlay == null or not weapon_sprite_overlay.visible:
		return

	_weapon_overlay_bob_time += delta * weapon_overlay_bob_speed
	weapon_sprite_overlay.position = _weapon_overlay_base_position + Vector2(
		sin(_weapon_overlay_bob_time * 0.5) * weapon_overlay_bob_amount * 0.35,
		sin(_weapon_overlay_bob_time) * weapon_overlay_bob_amount
	)


func _build_navigation_panel() -> void:
	if _navigation_label != null:
		return
	var root: Control = get_node("Root")
	_navigation_label = Label.new()
	_navigation_label.name = "DistrictNavigation"
	_navigation_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_navigation_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_navigation_label.offset_left = 300.0
	_navigation_label.offset_top = 48.0
	_navigation_label.offset_right = -300.0
	_navigation_label.offset_bottom = 94.0
	_navigation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_navigation_label.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0, 0.95))
	_navigation_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.02, 0.03, 0.95))
	_navigation_label.add_theme_constant_override("shadow_offset_x", 2)
	_navigation_label.add_theme_constant_override("shadow_offset_y", 2)
	_navigation_label.add_theme_font_size_override("font_size", 15)
	_navigation_label.text = "DISTRICT NAV INITIALIZING"
	root.add_child(_navigation_label)


func _update_navigation_panel() -> void:
	if _navigation_label == null:
		return
	var investigation := get_tree().get_first_node_in_group("investigation_director")
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if investigation == null or player == null or not investigation.has_method("get_navigation_snapshot"):
		_navigation_label.text = "HESPERUS MARKET"
		return
	var snapshot: Dictionary = investigation.call("get_navigation_snapshot", player.global_position)
	var current_zone := String(snapshot.get("current_zone", "Hesperus Market"))
	if not _last_zone_name.is_empty() and current_zone != _last_zone_name:
		show_toast("ENTERING: %s" % current_zone.to_upper(), 2.0)
	_last_zone_name = current_zone
	if not snapshot.has("lead_title"):
		_navigation_label.text = "CURRENT: %s\nNO LOCATED EVIDENCE" % current_zone.to_upper()
		return
	_navigation_label.text = "CURRENT: %s\nLEAD: %s • %s %dm • %s" % [
		current_zone.to_upper(),
		String(snapshot.get("lead_title", "Evidence")).to_upper(),
		String(snapshot.get("bearing", "?")),
		roundi(float(snapshot.get("distance", 0.0))),
		String(snapshot.get("lead_zone", "Unknown")).to_upper(),
	]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		set_retro_visuals_enabled(not retro_visuals_enabled)


func set_retro_visuals_enabled(enabled: bool) -> void:
	retro_visuals_enabled = enabled
	if retro_overlay != null:
		retro_overlay.visible = enabled
	if weapon_sprite_overlay != null:
		weapon_sprite_overlay.visible = _weapon_overlay_active and weapon_overlay_enabled


func set_weapon_overlay_active(active: bool) -> void:
	_weapon_overlay_active = active
	if weapon_sprite_overlay != null:
		weapon_sprite_overlay.visible = active and weapon_overlay_enabled
	if active:
		set_weapon_sprite_frame("idle", 0)


func set_weapon_sprite_frame(animation: String, frame: int) -> void:
	if weapon_sprite == null:
		return
	var atlas := AtlasTexture.new()
	if animation == "reload":
		var reload_frame := clampi(frame, 0, 11)
		atlas.atlas = WEAPON_RUNTIME_ATLAS
		atlas.region = Rect2(
			float(reload_frame % 4) * WEAPON_FRAME_SIZE.x,
			float(1 + floori(float(reload_frame) / 4.0)) * WEAPON_FRAME_SIZE.y,
			WEAPON_FRAME_SIZE.x,
			WEAPON_FRAME_SIZE.y
		)
	else:
		var fire_frame := clampi(frame, 0, 3)
		atlas.atlas = WEAPON_RUNTIME_ATLAS
		atlas.region = Rect2(
			float(fire_frame) * WEAPON_FRAME_SIZE.x,
			0.0,
			WEAPON_FRAME_SIZE.x,
			WEAPON_FRAME_SIZE.y
		)
	weapon_sprite.texture = atlas


func play_weapon_fire() -> void:
	_weapon_animation_id += 1
	var animation_id := _weapon_animation_id
	var frames := [1, 2, 3, 0]
	var frame_durations := [0.08, 0.1, 0.12, 0.1]
	for index in range(frames.size()):
		if animation_id != _weapon_animation_id:
			return
		set_weapon_sprite_frame("fire", frames[index])
		await get_tree().create_timer(frame_durations[index]).timeout


func play_weapon_reload(duration: float) -> void:
	_weapon_animation_id += 1
	var animation_id := _weapon_animation_id
	var frame_time := duration / 12.0
	for frame in range(12):
		if animation_id != _weapon_animation_id:
			return
		set_weapon_sprite_frame("reload", frame)
		await get_tree().create_timer(frame_time).timeout
	if animation_id == _weapon_animation_id:
		set_weapon_sprite_frame("idle", 0)


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


func set_binocular_active(active: bool, zoom_multiplier: float = 1.0) -> void:
	if _binocular_overlay == null:
		_build_binocular_overlay()
	_binocular_overlay.visible = active
	if crosshair_horizontal != null:
		crosshair_horizontal.visible = not active
	if crosshair_vertical != null:
		crosshair_vertical.visible = not active
	if _binocular_zoom_label != null:
		_binocular_zoom_label.text = "BINOCULARS %.1fx" % zoom_multiplier


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


func _build_binocular_overlay() -> void:
	if _binocular_overlay != null:
		return

	var root: Control = get_node("Root")
	_binocular_overlay = Control.new()
	_binocular_overlay.name = "BinocularOverlay"
	_binocular_overlay.visible = false
	_binocular_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_binocular_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_binocular_overlay)

	var tint := ColorRect.new()
	tint.name = "GlassTint"
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(0.02, 0.08, 0.1, 0.18)
	_binocular_overlay.add_child(tint)

	_add_binocular_mask_rect("TopMask", 0.0, 0.0, 1.0, 0.16)
	_add_binocular_mask_rect("BottomMask", 0.0, 0.84, 1.0, 1.0)
	_add_binocular_mask_rect("LeftMask", 0.0, 0.0, 0.12, 1.0)
	_add_binocular_mask_rect("RightMask", 0.88, 0.0, 1.0, 1.0)
	_add_binocular_mask_rect("CenterBridge", 0.485, 0.0, 0.515, 1.0, Color(0.0, 0.0, 0.0, 0.24))

	_add_scope_line("CenterHorizontal", Vector2(-68.0, -1.0), Vector2(68.0, 1.0))
	_add_scope_line("CenterVertical", Vector2(-1.0, -48.0), Vector2(1.0, 48.0))
	_add_scope_line("LeftTick", Vector2(-168.0, -1.0), Vector2(-112.0, 1.0))
	_add_scope_line("RightTick", Vector2(112.0, -1.0), Vector2(168.0, 1.0))
	_add_scope_line("TopTick", Vector2(-1.0, -132.0), Vector2(1.0, -88.0))
	_add_scope_line("BottomTick", Vector2(-1.0, 88.0), Vector2(1.0, 132.0))

	_binocular_zoom_label = Label.new()
	_binocular_zoom_label.name = "ZoomLabel"
	_binocular_zoom_label.text = "BINOCULARS 2.8x"
	_binocular_zoom_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_binocular_zoom_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_binocular_zoom_label.offset_left = 18.0
	_binocular_zoom_label.offset_top = 52.0
	_binocular_zoom_label.offset_right = 230.0
	_binocular_zoom_label.offset_bottom = 78.0
	_binocular_zoom_label.add_theme_color_override("font_color", Color(0.62, 1.0, 0.9, 0.92))
	_binocular_zoom_label.add_theme_font_size_override("font_size", 16)
	_binocular_overlay.add_child(_binocular_zoom_label)


func _add_binocular_mask_rect(name: String, left: float, top: float, right: float, bottom: float, color: Color = Color(0.0, 0.0, 0.0, 0.58)) -> void:
	var rect := ColorRect.new()
	rect.name = name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.anchor_left = left
	rect.anchor_top = top
	rect.anchor_right = right
	rect.anchor_bottom = bottom
	rect.color = color
	_binocular_overlay.add_child(rect)


func _add_scope_line(name: String, top_left: Vector2, bottom_right: Vector2) -> void:
	var line := ColorRect.new()
	line.name = name
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_anchors_preset(Control.PRESET_CENTER)
	line.offset_left = top_left.x
	line.offset_top = top_left.y
	line.offset_right = bottom_right.x
	line.offset_bottom = bottom_right.y
	line.color = Color(0.52, 1.0, 0.86, 0.72)
	_binocular_overlay.add_child(line)


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


# --- Intel panel (funnel legibility) -----------------------------------------
# Built in code so HUD.tscn stays editor-owned. Five trait slots: unknowns
# dimmed, learned values bright (flash on acquisition), counter flips to
# CONFRONT AUTHORIZED at BountyManager.intel_required_to_confirm.

func _build_intel_panel() -> void:
	var intel := get_node_or_null("/root/BountyIntel")
	if intel == null:
		return
	var root: Control = get_node("Root")

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.07, 0.09, 0.6)
	style.border_color = Color(0.2, 0.55, 0.62, 0.5)
	style.set_border_width_all(1)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 8.0

	var panel := PanelContainer.new()
	panel.name = "IntelPanel"
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -262.0
	panel.offset_right = -14.0
	panel.offset_top = 14.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "TARGET PROFILE"
	title.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0, 1.0))
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var categories: Array = intel.get("CATEGORIES")
	var labels: Dictionary = intel.get("CATEGORY_LABELS")
	for category in categories:
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 13)
		vbox.add_child(row)
		_intel_rows[category] = {"label": row, "name": labels.get(category, String(category).to_upper())}

	_intel_counter = Label.new()
	_intel_counter.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_intel_counter)

	var lead_title := Label.new()
	lead_title.text = "EVIDENCE LEADS"
	lead_title.add_theme_color_override("font_color", Color(0.95, 0.72, 0.28, 1.0))
	lead_title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(lead_title)
	for _index in range(3):
		var lead_row := Label.new()
		lead_row.add_theme_font_size_override("font_size", 12)
		lead_row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lead_row.custom_minimum_size.x = 220.0
		vbox.add_child(lead_row)
		_lead_rows.append(lead_row)

	intel.intel_updated.connect(_on_intel_updated)
	intel.intel_reset.connect(_refresh_intel_panel)
	_refresh_intel_panel()
	# Threshold comes from BountyManager once the tree settles.
	_resolve_intel_threshold.call_deferred()
	_bind_investigation_director.call_deferred()


func _resolve_intel_threshold() -> void:
	var manager := get_tree().get_first_node_in_group("bounty_manager")
	if manager != null:
		var required = manager.get("intel_required_to_confirm")
		if required is int and required > 0:
			_intel_required = required
	_refresh_intel_panel()


func _on_intel_updated(category: String, _value: String, _source: String) -> void:
	_refresh_intel_panel()
	if _intel_rows.has(category):
		var row: Label = _intel_rows[category]["label"]
		row.add_theme_color_override("font_color", Color(1.0, 0.95, 0.45, 1.0))
		var tween := create_tween()
		tween.tween_interval(0.55)
		tween.tween_callback(_refresh_intel_panel)


func _bind_investigation_director() -> void:
	var investigation := get_tree().get_first_node_in_group("investigation_director")
	if investigation == null:
		await get_tree().process_frame
		investigation = get_tree().get_first_node_in_group("investigation_director")
	if investigation == null:
		return
	if investigation.has_signal("lead_added"):
		investigation.lead_added.connect(_on_lead_changed)
	if investigation.has_signal("lead_updated"):
		investigation.lead_updated.connect(_on_lead_changed)
	_refresh_lead_panel()


func _on_lead_changed(_lead: Dictionary) -> void:
	_refresh_lead_panel()


func _refresh_lead_panel() -> void:
	if _lead_rows.is_empty():
		return
	var investigation := get_tree().get_first_node_in_group("investigation_director")
	var leads: Array = investigation.call("get_leads") if investigation != null else []
	var ordered_leads: Array = []
	for desired_status in ["ACTIVE", "RUMORED", "VERIFIED"]:
		for lead_value in leads:
			if String((lead_value as Dictionary).get("status", "")) == desired_status:
				ordered_leads.append(lead_value)
	for index in range(_lead_rows.size()):
		var row := _lead_rows[index]
		if index >= ordered_leads.size():
			row.text = "—"
			row.add_theme_color_override("font_color", Color(0.42, 0.5, 0.52, 0.65))
			continue
		var lead: Dictionary = ordered_leads[index]
		var status := String(lead.get("status", "RUMORED"))
		var zone := String(lead.get("zone_label", "unlocated"))
		row.text = "%s: %s [%s]" % [status, lead.get("title", "Evidence"), zone]
		match status:
			"VERIFIED":
				row.add_theme_color_override("font_color", Color(0.45, 1.0, 0.6, 1.0))
			"ACTIVE":
				row.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0, 1.0))
			_:
				row.add_theme_color_override("font_color", Color(1.0, 0.72, 0.28, 1.0))


func _refresh_intel_panel() -> void:
	var intel := get_node_or_null("/root/BountyIntel")
	if intel == null or _intel_rows.is_empty():
		return
	var known: Dictionary = intel.get("known")
	for category in _intel_rows:
		var row: Label = _intel_rows[category]["label"]
		var display_name: String = _intel_rows[category]["name"]
		if known.has(category):
			row.text = "%s: %s" % [display_name, known[category]["value"]]
			row.add_theme_color_override("font_color", Color(0.78, 1.0, 0.85, 1.0))
		else:
			row.text = "%s: ---" % display_name
			row.add_theme_color_override("font_color", Color(0.45, 0.55, 0.58, 0.7))

	if _intel_counter != null:
		var count: int = intel.call("known_visible_count")
		var signature_known := bool(intel.call("knows", "scanner_signature"))
		if count >= _intel_required and signature_known:
			_intel_counter.text = "CONFRONT AUTHORIZED (%d/%d + SIG)" % [count, _intel_required]
			_intel_counter.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6, 1.0))
		else:
			_intel_counter.text = "VISIBLE: %d/%d • SIG: %s" % [
				count, _intel_required, "READY" if signature_known else "---"
			]
			_intel_counter.add_theme_color_override("font_color", Color(0.95, 0.75, 0.4, 0.9))
