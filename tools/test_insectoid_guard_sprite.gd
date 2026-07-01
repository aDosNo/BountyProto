extends SceneTree


func _initialize() -> void:
	var packed := load("res://scenes/enemies/GangGuard.tscn") as PackedScene
	assert(packed != null)
	var guard := packed.instantiate()
	root.add_child(guard)
	await process_frame

	var mesh := guard.get_node("GuardMesh") as MeshInstance3D
	var sprite := guard.get_node("GuardSprite") as DirectionalSprite3D
	assert(mesh != null)
	assert(not mesh.visible)
	assert(sprite != null)
	assert(sprite.visible)
	assert(sprite.sheet != null)
	assert(sprite.sheet.get_width() == 2048)
	assert(sprite.sheet.get_height() == 384)
	assert(sprite.columns == 8)
	assert(sprite.frames_per_direction == 1)
	assert(sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)

	sprite.set_state_tint(Color.RED)
	assert(sprite.modulate.r > sprite.modulate.g)
	sprite.clear_state_tint()

	print("Insectoid guard sprite: scene, dimensions, and visual feedback passed.")
	quit()
