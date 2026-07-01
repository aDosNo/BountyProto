extends SceneTree

const MAIN_SCENE := preload("res://scenes/maps/HesperusMarket_Blockout.tscn")


func _initialize() -> void:
	var scene := MAIN_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame

	var target := scene.get_node("Gameplay/KorvaxiTarget")
	var walkway_guard := scene.get_node("Gameplay/PressureEnemies/PressureGuard_Walkway")
	assert(int(target.get("state")) == 1) # IDLE_HIDDEN
	walkway_guard.take_damage(1)
	assert(int(target.get("state")) == 1) # Architecture occludes the shout.

	print("Hesperus guard panic occlusion: walkway guard does not remotely start Korvaxi chase.")
	quit()
