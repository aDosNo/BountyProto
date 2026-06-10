extends SceneTree

const SCENE_PATH := "res://levels/hesperus_market/scenes/hesperus_market_graybox.tscn"
const GENERATED_ROOT_NAMES := [
	"Sections",
	"Walls",
	"Ports",
	"Routes",
	"Landmarks",
	"IdentityMarkers",
	"VisualDressing",
	"DebugLabels",
	"DebugSpawns",
	"Gameplay",
]


func _initialize() -> void:
	var packed_scene: PackedScene = load(SCENE_PATH)
	if packed_scene == null:
		_fail("Could not load scene: %s" % SCENE_PATH)
		return

	var scene_root := packed_scene.instantiate()
	if scene_root == null:
		_fail("Could not instantiate scene: %s" % SCENE_PATH)
		return

	if not scene_root.has_method("build_graybox"):
		scene_root.free()
		_fail("Scene root does not expose build_graybox().")
		return

	scene_root.call("build_graybox")
	for root_name: String in GENERATED_ROOT_NAMES:
		var generated_root := scene_root.get_node_or_null(root_name)
		if generated_root == null:
			scene_root.free()
			_fail("Generated root missing after build: %s" % root_name)
			return
		_assign_owner_recursive(generated_root, scene_root)

	var baked_scene := PackedScene.new()
	var pack_result := baked_scene.pack(scene_root)
	if pack_result != OK:
		scene_root.free()
		_fail("Could not pack baked scene. Error: %s" % error_string(pack_result))
		return

	var save_result := ResourceSaver.save(baked_scene, SCENE_PATH)
	scene_root.free()
	if save_result != OK:
		_fail("Could not save baked scene. Error: %s" % error_string(save_result))
		return

	print("Hesperus Market graybox baked into %s" % SCENE_PATH)
	quit(0)


func _assign_owner_recursive(node: Node, scene_root: Node) -> void:
	node.owner = scene_root
	for child: Node in node.get_children():
		_assign_owner_recursive(child, scene_root)


func _fail(message: String) -> void:
	push_error(message)
	print("Hesperus Market graybox bake FAILED: %s" % message)
	quit(1)
