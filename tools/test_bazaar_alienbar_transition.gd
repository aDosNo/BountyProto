extends SceneTree


func _initialize() -> void:
	var packed := load("res://scenes/maps/HesperusMarket_Blockout.tscn") as PackedScene
	assert(packed != null)
	var map := packed.instantiate()
	root.add_child(map)
	current_scene = map
	await process_frame
	await process_frame

	var transition := map.get_node("Hesperus_BazaarAlienBar_Transition") as Node3D
	assert(transition != null)
	assert(transition.basis.is_equal_approx(Basis.IDENTITY))
	assert(is_equal_approx(transition.position.x, -4.7875204))
	assert(is_equal_approx(transition.position.y, 0.0))
	assert(is_equal_approx(transition.position.z, 0.0))

	for mesh_name in [
		"BAT_MainPassage",
		"BAT_NoodleShop_Rear",
		"BAT_WeaponRepair_Counter",
		"BAT_ConnectorTower",
		"BAT_ConnectorStair_Step_27",
		"BAT_ConnectorBridge",
		"BAT_UpperTeaHouse_Mass",
		"BAT_UpperTailor_Mass",
		"BAT_UpperBroker_Mass",
		"BAT_ForecourtFloor",
		"BAT_SecurityBooth",
		"BAT_EastWedgeWest",
		"BAT_EastWedgeEast",
	]:
		assert(transition.find_child(mesh_name, true, false) != null)

	var evidence_anchor := map.get_node("Gameplay/Investigation/EvidenceAnchors/UpperWalkwayObservation") as Node3D
	var north_walkway := map.get_node("WorldGeometry/Floors/WalkwayNorth") as Node3D
	var west_walkway := map.get_node("WorldGeometry/Floors/WalkwayWest") as Node3D
	var bar_ramp := map.get_node("WorldGeometry/RampsAndCatwalk/BarEastRamp") as Node3D
	assert(evidence_anchor != null)
	assert(north_walkway != null)
	assert(west_walkway != null)
	assert(bar_ramp != null)

	# The investigation anchor remains in the intentionally empty upper bay.
	assert(evidence_anchor.global_position.x > 8.0 and evidence_anchor.global_position.x < 18.0)
	assert(evidence_anchor.global_position.y > 11.0)
	assert(evidence_anchor.global_position.z > -45.0 and evidence_anchor.global_position.z < -44.0)

	# The mixed-use wedge starts beyond the north edge of the existing ramp.
	var wedge := transition.find_child("BAT_EastWedgeWest", true, false) as Node3D
	assert(wedge.global_position.z < -55.0)
	assert(bar_ramp.global_position.z > wedge.global_position.z)

	print("Bazaar-Alien Bar transition: shops, vertical route, evidence bay, forecourt, and ramp clearance passed.")
	quit()
