extends Sprite3D
class_name DirectionalSprite3D
## 8-way directional billboard driven by a single packed sprite sheet.
##
## Picks one of 8 compass cells (N/NE/E/SE/S/SW/W/NW) based on the angle
## between the camera and the parent body's facing direction, Build/Doom-style.
##
## Also acts as the visual state-feedback surface for korvaxi_target.gd:
## hit-flash, stun, captured, and death are expressed via `modulate` /
## `transparency` instead of per-mesh StandardMaterial3D overrides.
##
## Sheet layout: 1 row, 8 directions, in this column order:
##   N, NE, E, SE, S, SW, W, NW
## Each direction may have one or more adjacent animation frames.
## If direction_frame_counts is empty, every direction uses frames_per_direction.

@export var sheet: Texture2D
@export var columns: int = 8
@export_range(1, 8, 1) var frames_per_direction: int = 1
@export var direction_frame_counts: PackedInt32Array = PackedInt32Array()
@export var walk_fps: float = 4.0
@export var movement_speed_threshold: float = 0.05
@export var base_modulate: Color = Color(1, 1, 1, 1)

# Column index per compass direction (matches the packed sheet order).
const DIR_N := 0
const DIR_NE := 1
const DIR_E := 2
const DIR_SE := 3
const DIR_S := 4
const DIR_SW := 5
const DIR_W := 6
const DIR_NW := 7

var _body: Node3D
var _cell_w: float
var _cell_h: float
var _current_col: int = -1
var _current_frame: int = -1
var _anim_time: float = 0.0
var _state_tint: Color = Color(1, 1, 1, 1)   # set by state methods; multiplies base


func _ready() -> void:
	_body = get_parent()
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shaded = false
	if sheet:
		texture = sheet
		region_enabled = true
		_cell_w = float(sheet.get_width()) / float(_total_frame_count())
		_cell_h = float(sheet.get_height())
		_apply_column(DIR_N, 0)
	_refresh_modulate()


func _process(delta: float) -> void:
	if _body == null or sheet == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return

	var to_cam := cam.global_position - _body.global_position
	to_cam.y = 0.0
	if to_cam.length() < 0.001:
		return
	to_cam = to_cam.normalized()

	var fwd := -_body.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()

	# Signed angle (radians) of the camera around the body, measured from
	# the body's forward direction. 0 = camera in front -> show N (front).
	var ang := atan2(fwd.cross(to_cam).y, fwd.dot(to_cam))
	# Map [-PI, PI] to one of 8 sectors, 45 degrees each, centered on N.
	var sector := int(round(ang / (PI / 4.0)))
	sector = ((sector % 8) + 8) % 8

	# The packed character sheets label a frame by the side of the character
	# visible to the camera. That is opposite the signed camera-orbit sector:
	# camera-left reveals the character's right side, and vice versa.
	var col := _sector_to_column(sector)
	var frame := _animation_frame(delta, col)
	_apply_column(col, frame)


func _sector_to_column(sector: int) -> int:
	match sector:
		0: return DIR_N
		1: return DIR_NW
		2: return DIR_W
		3: return DIR_SW
		4: return DIR_S
		5: return DIR_SE
		6: return DIR_E
		7: return DIR_NE
		_: return DIR_N


func _animation_frame(delta: float, col: int) -> int:
	var frame_count := _frame_count_for_column(col)
	if frame_count <= 1:
		return 0
	if _body is CharacterBody3D:
		var body := _body as CharacterBody3D
		var planar_speed := Vector2(body.velocity.x, body.velocity.z).length()
		if planar_speed > movement_speed_threshold:
			_anim_time += delta * walk_fps
		else:
			_anim_time = 0.0
	return int(floor(_anim_time)) % frame_count


func _apply_column(col: int, frame: int) -> void:
	if col == _current_col and frame == _current_frame:
		return
	_current_col = col
	_current_frame = frame
	var packed_col := _packed_column_offset(col) + frame
	region_rect = Rect2(packed_col * _cell_w, 0.0, _cell_w, _cell_h)


func _uses_direction_frame_counts() -> bool:
	return direction_frame_counts.size() == columns


func _frame_count_for_column(col: int) -> int:
	if _uses_direction_frame_counts():
		return max(1, direction_frame_counts[col])
	return max(1, frames_per_direction)


func _packed_column_offset(col: int) -> int:
	if not _uses_direction_frame_counts():
		return col * max(1, frames_per_direction)
	var offset := 0
	for i in range(col):
		offset += max(1, direction_frame_counts[i])
	return offset


func _total_frame_count() -> int:
	if not _uses_direction_frame_counts():
		return columns * max(1, frames_per_direction)
	var total := 0
	for count in direction_frame_counts:
		total += max(1, count)
	return max(1, total)


func _refresh_modulate() -> void:
	modulate = base_modulate * _state_tint


# --- State-feedback API (called by korvaxi_target.gd) ---

func set_state_tint(tint: Color) -> void:
	_state_tint = tint
	_refresh_modulate()

func clear_state_tint() -> void:
	_state_tint = Color(1, 1, 1, 1)
	_refresh_modulate()

func set_visual_transparency(value: float) -> void:
	# 0 = opaque, 1 = fully transparent (mirrors MeshInstance3D.transparency).
	var c := modulate
	c.a = 1.0 - clampf(value, 0.0, 1.0)
	modulate = c
