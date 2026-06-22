extends Node3D
## Visual-only elevated rail train for the distant Hesperus skyline.
##
## Runs a chain of cars back and forth along a straight rail segment defined by
## two endpoints. The train accelerates in from one end, crosses the visible
## span, exits the far end, waits, then returns from the other direction. It is
## pure set-dressing: no collision, no gameplay hooks, never reachable.
##
## Endpoints can be auto-read from the DistantCity GLB's RailPath_Start /
## RailPath_End marker nodes, or set manually in the inspector.

## If set, the train reads start/end from marker nodes found by name anywhere in
## the scene (the baked GLB markers). Set the names to target a specific rail.
@export var auto_find_markers: bool = true
@export var start_marker_name: String = "RailPath_Start"
@export var end_marker_name: String = "RailPath_End"
@export var start_marker_path: NodePath
@export var end_marker_path: NodePath

## Manual fallback endpoints (world space) if markers aren't found.
@export var manual_start: Vector3 = Vector3(-140.0, 46.0, -95.0)
@export var manual_end: Vector3 = Vector3(220.0, 46.0, -95.0)

@export_group("Train")
@export var car_count: int = 5
@export var car_length: float = 9.0
@export var car_gap: float = 1.4
@export var car_width: float = 3.0
@export var car_height: float = 3.2
@export var speed: float = 70.0          ## units/sec along the rail (fast)
@export var end_wait: Vector2 = Vector2(2.5, 6.0)  ## random pause range at each end

@export_group("Look")
@export var hull_color: Color = Color(0.06, 0.07, 0.1)
@export var window_color: Color = Color(1.0, 0.75, 0.35)
@export var window_energy: float = 3.4
@export var headlight_color: Color = Color(0.7, 0.95, 1.0)

var _start: Vector3
var _end: Vector3
var _dir: Vector3
var _span: float
var _cars: Array[Node3D] = []
var _hull_mat: StandardMaterial3D
var _win_mat: StandardMaterial3D
var _head_mat: StandardMaterial3D

# Lead-car distance measured ALONG the rail, in units. The train runs from
# -train_length (fully off the near end) to span+? then reverses. We let it run
# from behind the start to beyond the end so it fully clears the visible span.
var _lead_pos: float = 0.0
var _moving_forward: bool = true
var _wait_timer: float = 0.0
var _train_length: float = 0.0


func _ready() -> void:
	_resolve_endpoints()
	_dir = (_end - _start)
	_span = _dir.length()
	if _span < 0.01:
		set_process(false)
		return
	_dir = _dir / _span
	_train_length = car_count * car_length + maxf(car_count - 1, 0) * car_gap
	_build_materials()
	_build_cars()
	# Start fully off the near end.
	_lead_pos = -_train_length
	_wait_timer = 0.0
	set_process(true)


func _resolve_endpoints() -> void:
	var s: Node3D = null
	var e: Node3D = null
	if auto_find_markers:
		s = _find_descendant_named(start_marker_name)
		e = _find_descendant_named(end_marker_name)
	if s == null and start_marker_path != NodePath():
		s = get_node_or_null(start_marker_path) as Node3D
	if e == null and end_marker_path != NodePath():
		e = get_node_or_null(end_marker_path) as Node3D
	_start = s.global_position if s != null else manual_start
	_end = e.global_position if e != null else manual_end


## Search the whole scene tree for the first node whose name matches (markers
## live inside the imported DistantCity GLB instance, wherever it was placed).
func _find_descendant_named(target: String) -> Node3D:
	var root := get_tree().current_scene
	if root == null:
		return null
	return _recurse_find(root, target)


func _recurse_find(node: Node, target: String) -> Node3D:
	if node.name == target and node is Node3D:
		return node as Node3D
	for child in node.get_children():
		var found := _recurse_find(child, target)
		if found != null:
			return found
	return null


func _build_materials() -> void:
	_hull_mat = StandardMaterial3D.new()
	_hull_mat.albedo_color = hull_color
	_hull_mat.roughness = 0.7

	_win_mat = StandardMaterial3D.new()
	_win_mat.albedo_color = Color(0.02, 0.02, 0.02)
	_win_mat.emission_enabled = true
	_win_mat.emission = window_color
	_win_mat.emission_energy_multiplier = window_energy

	_head_mat = StandardMaterial3D.new()
	_head_mat.albedo_color = Color(0.02, 0.02, 0.02)
	_head_mat.emission_enabled = true
	_head_mat.emission = headlight_color
	_head_mat.emission_energy_multiplier = 4.0


func _build_cars() -> void:
	for i in range(car_count):
		var car := Node3D.new()
		car.name = "RailCar_%02d" % i
		add_child(car)

		var hull := MeshInstance3D.new()
		hull.name = "Hull"
		var hull_mesh := BoxMesh.new()
		hull_mesh.size = Vector3(car_width, car_height, car_length)
		hull.mesh = hull_mesh
		hull.material_override = _hull_mat
		hull.position = Vector3(0.0, car_height * 0.5, 0.0)
		car.add_child(hull)

		# Window band down each side (emissive strip).
		for side in [-1.0, 1.0]:
			var win := MeshInstance3D.new()
			win.name = "WinBand"
			var wm := BoxMesh.new()
			wm.size = Vector3(0.12, car_height * 0.4, car_length * 0.82)
			win.mesh = wm
			win.material_override = _win_mat
			win.position = Vector3(side * (car_width * 0.5 + 0.02), car_height * 0.62, 0.0)
			car.add_child(win)

		# Headlight on the lead car only (both ends so it reads in both directions).
		if i == 0 or i == car_count - 1:
			var head := MeshInstance3D.new()
			head.name = "Head"
			var hm := SphereMesh.new()
			hm.radius = 0.5
			hm.height = 1.0
			head.mesh = hm
			head.material_override = _head_mat
			var z := car_length * 0.5 if i == 0 else -car_length * 0.5
			head.position = Vector3(0.0, car_height * 0.5, z)
			car.add_child(head)

		_cars.append(car)


func _process(delta: float) -> void:
	if _wait_timer > 0.0:
		_wait_timer -= delta
		# Park the train just off the end it's waiting at.
		_position_cars()
		return

	if _moving_forward:
		_lead_pos += speed * delta
		# Train fully past the far end?
		if _lead_pos - _train_length > _span:
			_moving_forward = false
			_wait_timer = randf_range(end_wait.x, end_wait.y)
	else:
		_lead_pos -= speed * delta
		if _lead_pos < -_train_length:
			_moving_forward = true
			_wait_timer = randf_range(end_wait.x, end_wait.y)

	_position_cars()


func _position_cars() -> void:
	# Lead car sits at _lead_pos along the rail; following cars trail behind by
	# car_length + car_gap. "Behind" depends on travel direction so cars stay
	# coupled and face the way they move.
	var facing := _dir if _moving_forward else -_dir
	for i in range(_cars.size()):
		var offset := float(i) * (car_length + car_gap)
		# Distance of THIS car's center along the rail from the start point.
		var d: float
		if _moving_forward:
			d = _lead_pos - offset - car_length * 0.5
		else:
			d = _lead_pos - offset - car_length * 0.5
		var pos := _start + _dir * d
		var car := _cars[i]
		car.global_position = pos
		# Orient local -Z down the direction of travel.
		var look_target := pos + facing
		car.look_at(look_target, Vector3.UP)
