extends SceneTree


func _initialize() -> void:
	var packed := load("res://scenes/maps/HesperusMarket_Blockout.tscn") as PackedScene
	assert(packed != null)
	var map := packed.instantiate()
	root.add_child(map)
	current_scene = map
	await process_frame
	await process_frame

	var perimeter := map.get_node("Hesperus_CourtyardPerimeter_Phase1")
	assert(perimeter != null)
	for mesh_name in [
		"CP_EastMega_Podium",
		"CP_EastMega_UtilityRecess",
		"CP_EastMega_LadderRecess",
		"CP_SouthWest_Mass",
		"CP_SouthMiddle_Mass",
		"CP_SouthEast_Mass",
		"CP_ReturnPassage_LeftPier",
		"CP_ReturnPassage_RightPier",
	]:
		assert(perimeter.find_child(mesh_name, true, false) != null)

	for old_name in ["Building14", "Building17", "Building18"]:
		var old_building := map.get_node("WorldGeometry/WallsAndFacades/%s" % old_name)
		assert(not old_building.visible)
		assert(old_building.collision_layer == 0)

	assert(map.get_node("WorldGeometry/CourtyardArena/Exits/FrontGateRamp") != null)
	assert(map.get_node("WorldGeometry/CourtyardArena/Exits/BackDoor_Locked") != null)
	assert(map.get_node("WorldGeometry/CourtyardArena/Exits/ReturnGateRamp") != null)
	assert(map.get_node("WorldGeometry/CourtyardArena/BalconyAccess/AccessRamp") != null)
	assert(map.get_node("EastMicroHub/Generated/AuthoredCourtyardRoutes/FunctionalRoofLadder") != null)

	print("Courtyard Perimeter Phase 1: architecture and route-preservation checks passed.")
	quit()
