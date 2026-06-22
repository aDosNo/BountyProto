extends Sprite3D

## 8-way billboard for the alien police drone sheet.
## Uses row 0 of a 2-row sheet as directional views. Row 1 remains available for
## future hover/alert animation states.

@export var sheet: Texture2D
@export var columns: int = 8
@export var rows: int = 2
@export var direction_row: int = 0

var _body: Node3D
var _cell_w: float = 128.0
var _cell_h: float = 128.0
var _current_col: int = -1


func _ready() -> void:
	_body = get_parent() as Node3D
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shaded = false
	if sheet != null:
		texture = sheet
		region_enabled = true
		_cell_w = float(sheet.get_width()) / float(maxi(columns, 1))
		_cell_h = float(sheet.get_height()) / float(maxi(rows, 1))
		_apply_column(0)


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
	if fwd.length() < 0.001:
		return
	fwd = fwd.normalized()

	var angle := atan2(fwd.cross(to_cam).y, fwd.dot(to_cam))
	var sector := int(round(angle / (PI / 4.0)))
	sector = ((sector % 8) + 8) % 8
	_apply_column(_sector_to_column(sector))


func _sector_to_column(sector: int) -> int:
	match sector:
		0: return 0 # front
		1: return 1 # front-right
		2: return 2 # right
		3: return 3 # back-right
		4: return 4 # back
		5: return 5 # back-left
		6: return 6 # left
		7: return 7 # front-left
		_: return 0


func _apply_column(col: int) -> void:
	if col == _current_col:
		return
	_current_col = col
	var row := clampi(direction_row, 0, maxi(rows - 1, 0))
	region_rect = Rect2(col * _cell_w, row * _cell_h, _cell_w, _cell_h)
