extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/maps/HesperusMarket_Blockout.tscn") as PackedScene
	var map := scene.instantiate()
	root.add_child(map)
	await process_frame
	await process_frame

	var hub := map.get_node("EastMicroHub/Generated")
	var player := get_first_node_in_group("player")
	var package := hub.find_child("AlienBarCourierPackage", true, false)
	var courier := hub.find_child("Courier", true, false)
	var terminal := hub.find_child("DeliveryTerminal", true, false)
	var grid := hub.get_node("PowerGrid")
	var checkpoint := hub.find_child("CredentialGate", true, false)
	var social := hub.find_child("SocialCourierBlock", true, false)
	var utility := hub.find_child("UtilityPowerBlock", true, false)
	var security := hub.find_child("SecurityAccessBlock", true, false)
	var upper_route := hub.find_child("ContinuousUpperCatwalk", true, false)
	var courtyard_routes := hub.find_child("AuthoredCourtyardRoutes", true, false)
	var dressing := hub.find_child("StreetDressing", true, false)

	assert(player != null)
	assert(package != null and courier != null and terminal != null)
	assert(grid != null and checkpoint != null)
	assert(social != null and social.has_node("VendorStaffOnly"))
	assert(utility != null and utility.has_node("PowerSwitch"))
	assert(security != null and security.has_node("SecurityRestricted"))
	assert(upper_route != null and upper_route.has_node("UpperDeck00"))
	assert(upper_route.has_node("CredentialInteriorLadder"))
	assert(upper_route.has_node("CredentialExitToCatwalk"))
	assert(upper_route.has_node("VendorCatwalkLadder"))
	assert(upper_route.has_node("UtilityCatwalkLadder"))
	assert(courtyard_routes != null and courtyard_routes.has_node("FunctionalRoofLadder"))
	assert(courtyard_routes.has_node("FunctionalRopeDrop"))
	assert(dressing != null and dressing.has_node("CoverWest"))
	assert(dressing.has_node("CoverCenter"))
	assert(dressing.has_node("CoverEast"))

	package.interact(player)
	courier.interact(player)
	assert(player.has_access_tag("courtyard_service"))
	assert(terminal.get_interaction_text().contains("meeting"))
	terminal.interact(player)

	grid.set_powered(false)
	await create_timer(0.8).timeout
	assert(checkpoint.get_node("CollisionShape3D").disabled)
	grid.set_powered(true)
	await create_timer(0.8).timeout
	assert(not checkpoint.get_node("CollisionShape3D").disabled)

	print("EAST MICRO-HUB SMOKE TEST PASSED")
	quit()
