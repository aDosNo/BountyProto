extends Node

## One-shot render capture for layout review.
## Saves PNGs to res://renders/ then quits.

const MAP_PATH := "res://scenes/maps/HesperusMarket_Blockout.tscn"
const OUT_DIR := "res://renders"

# [filename, camera_position, look_target, ortho_size (0 = perspective), fog_on]
var shots := [
	["fp_freight_ramp_base", Vector3(36.0, 1.6, 56.0), Vector3(24.7, 9.0, 67), 0.0, true],
	["fp_west_descent", Vector3(-26.0, 11.6, 71.3), Vector3(-47, -0.2, 71.3), 0.0, true],
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var map := (load(MAP_PATH) as PackedScene).instantiate()
	add_child(map)
	get_tree().paused = true

	var env_node := map.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var env: Environment = env_node.environment if env_node else null

	var cam := Camera3D.new()
	cam.far = 800.0
	cam.fov = 75.0
	add_child(cam)

	# Simulate the extraction-phase gate state so the render shows the route open.
	var gate := map.get_node_or_null("WorldGeometry/CourtyardArena/Exits/ReturnGate_Door") as Node3D
	if gate != null:
		gate.position.y -= 4.6

	for i in 6:
		await get_tree().process_frame
	_hide_canvas_layers(get_tree().root)

	for shot in shots:
		var fname: String = shot[0]
		var pos: Vector3 = shot[1]
		var target: Vector3 = shot[2]
		var ortho: float = shot[3]
		var fog_on: bool = shot[4]

		_hide_canvas_layers(get_tree().root)

		if env:
			env.fog_enabled = fog_on

		if ortho > 0.0:
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = ortho
		else:
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE

		cam.position = pos
		var dir := (target - pos).normalized()
		var up := Vector3.UP
		if absf(dir.dot(Vector3.UP)) > 0.99:
			up = Vector3(0, 0, -1)
		cam.look_at(target, up)
		cam.make_current()

		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw

		var img := get_viewport().get_texture().get_image()
		var err := img.save_png("%s/%s.png" % [OUT_DIR, fname])
		print("RENDER_SAVED %s err=%d" % [fname, err])

	print("RENDER_CAPTURE_DONE")
	get_tree().quit()

func _hide_canvas_layers(n: Node) -> void:
	if n is CanvasLayer:
		(n as CanvasLayer).visible = false
	for c in n.get_children():
		_hide_canvas_layers(c)
