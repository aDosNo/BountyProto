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
## Sheet layout: 1 row, 8 columns, in this column order:
##   N, NE, E, SE, S, SW, W, NW
## Cell size is read from the texture (width / 8, full height).

@export var sheet: Texture2D
@export var columns: int = 8
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
var _state_tint: Color = Color(1, 1, 1, 1)   # set by state methods; multiplies base


func _ready() -> void:
	_body = get_parent()
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shaded = false
	if sheet:
		texture = sheet
		region_enabled = true
		_cell_w = float(sheet.get_width()) / float(columns)
		_cell_h = float(sheet.get_height())
		_apply_column(DIR_N)
	_refresh_modulate()


func _process(_delta: float) -> void:
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

	# sector 0 = front (N). Positive rotates toward the body's left/right
	# consistently; the column table maps sector -> sheet column.
	var col := _sector_to_column(sector)
	_apply_column(col)


func _sector_to_column(sector: int) -> int:
	# sector measured CCW from front. Sheet columns laid out CW visually,
	# so map explicitly to keep left/right correct.
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


func _apply_column(col: int) -> void:
	if col == _current_col:
		return
	_current_col = col
	region_rect = Rect2(col * _cell_w, 0.0, _cell_w, _cell_h)


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
