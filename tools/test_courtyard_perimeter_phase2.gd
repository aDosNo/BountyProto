extends SceneTree


func _initialize() -> void:
	var packed := load("res://scenes/maps/HesperusMarket_Blockout.tscn") as PackedScene
	assert(packed != null)
	var map := packed.instantiate()
	root.add_child(map)
	current_scene = map
	await process_frame
	await process_frame

	var phase1 := map.get_node("Hesperus_CourtyardPerimeter_Phase1") as Node3D
	var phase2 := map.get_node("Hesperus_CourtyardPerimeter_Phase2") as Node3D
	var alley := map.get_node("Hesperus_AlienBar_CourtyardAlley") as Node3D
	assert(phase1 != null)
	assert(phase2 != null)
	assert(alley != null)

	# Preserve the user's rotated Phase 1 placement.
	assert(phase1.basis.x.dot(Vector3.LEFT) > 0.999)
	assert(phase1.basis.z.dot(Vector3.FORWARD) > 0.999)
	assert(phase1.position.distance_to(Vector3(226.92072, 0.0, -0.3902626)) < 0.01)

	for mesh_name in [
		"CP2_CredentialApproachCue_West",
		"CP2_CredentialApproachCue_East",
		"CP2_EastNorth_Podium",
		"CP2_EastSouth_Workshop",
		"CP2_ServicePortal_NorthPier",
		"CP2_ServicePortal_SouthPier",
		"CP2_ServicePortal_Header",
	]:
		assert(phase2.find_child(mesh_name, true, false) != null)

	for restored_name in [
		"ALY_Building_08",
		"ALY_Shell10_Back",
		"ALY_Shell10_FrontLeft",
		"ALY_Shell10_FrontRight",
		"ALY_Window_10_58_0",
		"ALY_RoofMass_10",
		"ALY_SecurityBandBack_4_15",
		"ALY_SecurityRoofCollar",
	]:
		var restored_mesh := alley.find_child(restored_name, true, false) as MeshInstance3D
		assert(restored_mesh != null)
		assert(restored_mesh.visible)

	# Critical traversal remains represented after the complementary shell lands.
	assert(map.get_node("WorldGeometry/CourtyardArena/BalconyAccess/AccessRamp") != null)
	assert(map.get_node("WorldGeometry/CourtyardArena/Exits/ReturnGateRamp") != null)
	assert(map.get_node("HesperusDistrictSystems/CourtyardSystemicTraversal/InsideServiceGrate") != null)
	assert(map.get_node("HesperusDistrictSystems/CourtyardSystemicTraversal/OutsideServiceGrate") != null)
	assert(map.get_node("HesperusDistrictSystems/CourtyardSystemicTraversal/CourtyardRoofLadderZone") != null)
	var credential_ladder := map.get_node(
		"EastMicroHub/Generated/ContinuousUpperCatwalk/CredentialInteriorLadder"
	) as Area3D
	assert(credential_ladder != null)
	assert(credential_ladder.global_position.distance_to(Vector3(113.77281, 2.25, -33.29328)) < 0.05)

	# The route-defining openings stay clear of structural masses.
	for route_point in [
		Vector3(112.3, 1.0, -25.5),
		Vector3(112.3, 1.0, -27.5),
		Vector3(139.2, 1.0, 2.0),
		Vector3(142.0, 1.0, 2.0),
		Vector3(155.0, 1.0, 10.0),
	]:
		assert(not _point_inside_structural_mesh(phase2, route_point))

	print("Courtyard Perimeter Phase 2: north/east architecture and route-clearance checks passed.")
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
			or mesh_instance.name.contains("Rail")
		):
			continue
		var local_point := mesh_instance.global_transform.affine_inverse() * world_point
		if mesh_instance.get_aabb().has_point(local_point):
			return true
	return false
