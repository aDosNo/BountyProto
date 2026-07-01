extends SceneTree


func _initialize() -> void:
	var packed := load("res://scenes/maps/HesperusMarket_Blockout.tscn") as PackedScene
	assert(packed != null)
	var map := packed.instantiate()
	root.add_child(map)
	current_scene = map
	await process_frame
	await process_frame

	var backlot := map.get_node("Hesperus_AlienBar_EastBacklot") as Node3D
	assert(backlot != null)
	for mesh_name in [
		"ABL_NorthWorker_Mass",
		"ABL_EastRepair_Mass",
		"ABL_BarAnnex_Mass",
		"ABL_FoodStall_Mass",
		"ABL_PartsStall_Mass",
		"ABL_UpperStair_00",
		"ABL_UpperStair_11",
		"ABL_UpperBridgeDeck",
		"ABL_GroundCue_ServiceLane",
	]:
		assert(backlot.find_child(mesh_name, true, false) != null)

	var bridge := backlot.find_child("ABL_UpperBridgeDeck", true, false) as MeshInstance3D
	assert(bridge.global_position.distance_to(Vector3(79.0, 4.45, -46.7)) < 0.05)
	var vendor_landing := map.get_node(
		"EastMicroHub/Generated/ContinuousUpperCatwalk/VendorLanding"
	) as Node3D
	assert(vendor_landing.global_position.distance_to(Vector3(79.07281, 4.45, -35.29328)) < 0.05)

	for route_point in [
		Vector3(45.0, 1.0, -68.0),
		Vector3(55.0, 1.0, -68.0),
		Vector3(70.0, 1.0, -68.0),
		Vector3(82.0, 1.0, -64.0),
		Vector3(100.0, 1.0, -62.0),
		Vector3(118.0, 1.0, -60.0),
	]:
		assert(not _point_inside_structural_mesh(backlot, route_point))

	print("Alien Bar East Backlot: ground loop and upper catwalk connection passed.")
	quit()


func _point_inside_structural_mesh(root_node: Node, world_point: Vector3) -> bool:
	for child in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if not mesh_instance.visible:
			continue
		if (
			mesh_instance.name.contains("Glow")
			or mesh_instance.name.contains("Window")
			or mesh_instance.name.contains("Sign")
			or mesh_instance.name.contains("Cue")
			or mesh_instance.name.contains("Rail")
			or mesh_instance.name.contains("Cable")
			or mesh_instance.name.contains("Pipe")
		):
			continue
		var local_point := mesh_instance.global_transform.affine_inverse() * world_point
		if mesh_instance.get_aabb().has_point(local_point):
			return true
	return false
