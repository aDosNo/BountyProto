extends SceneTree


func _initialize() -> void:
	var packed := load("res://scenes/maps/HesperusMarket_Blockout.tscn") as PackedScene
	assert(packed != null)
	var map := packed.instantiate()
	root.add_child(map)
	current_scene = map
	await process_frame
	await process_frame

	var arcade := map.get_node("Hesperus_AlienBar_CommercialArcade")
	var old_shell := map.get_node("Hesperus_AlienBar_CourtyardAlley")
	var generated := map.get_node("EastMicroHub/Generated")
	assert(arcade != null)
	assert(old_shell != null)

	for mesh_name in [
		"ABA_Bar_EntranceHeader",
		"ABA_PawnCounter",
		"ABA_ClinicDesk",
		"ABA_UpperFloor",
		"ABA_UpperOfficeDesk",
		"ABA_InternalStair_Step_11",
	]:
		assert(arcade.find_child(mesh_name, true, false) != null)

	for old_prefix in ["ALY_Building_01", "ALY_Building_02", "ALY_Shell05_"]:
		var old_matches := old_shell.find_children("%s*" % old_prefix, "MeshInstance3D", true, false)
		assert(not old_matches.is_empty())
		for old_mesh in old_matches:
			assert(not (old_mesh as MeshInstance3D).visible)

	var package := generated.get_node("SocialCourierBlock/AlienBarCourierPackage") as Node3D
	var courier := generated.get_node("SocialCourierBlock/Courier") as Node3D
	var vendor := generated.get_node("SocialCourierBlock/PoweredVendor") as Node3D
	assert(package != null)
	assert(courier != null)
	assert(vendor != null)

	# The arcade front is around world z=-47.4. Existing social actors remain
	# south/in front of it rather than embedded in the replacement shell.
	assert(package.global_position.z > -47.0)
	assert(courier.global_position.z > -43.0)
	assert(vendor.global_position.z > -43.0)

	print("Alien Bar Commercial Arcade: replacement, interiors, and social-space clearance passed.")
	quit()
