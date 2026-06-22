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
	var security := hub.find_child("SecurityCheckpoint", true, false)
	var upper_route := hub.find_child("CredentialCatwalkToAccessRamp", true, false)
	var service_route := hub.find_child("UtilitySecurityServicePassage", true, false)
	var vendor := hub.find_child("VendorCourierOffice", true, false)
	var utility := hub.find_child("UtilityRoom", true, false)
	var freight_route := hub.find_child("VendorUtilityFreightCatwalk", true, false)
	var east_conduit := hub.find_child("EastMaintenanceConduit", true, false)
	var roof_route := hub.find_child("UtilitySecurityRooftopTraverse", true, false)

	assert(player != null)
	assert(package != null and courier != null and terminal != null)
	assert(grid != null and checkpoint != null)
	assert(security != null and security.has_node("Stair07"))
	assert(not security.has_node("Roof"))
	assert(security.has_node("RoofWest") and security.has_node("UpperLanding"))
	assert(upper_route != null and upper_route.has_node("CredentialBridgeB"))
	assert(service_route != null and service_route.has_node("ServiceDeck03"))
	assert(vendor != null and vendor.has_node("VendorFreightLadder"))
	assert(utility != null and utility.has_node("UtilityMezzanineLadder"))
	assert(utility.has_node("UtilityRoofTerrace"))
	assert(utility.has_node("UtilityRoofLadder"))
	assert(security.has_node("SecurityRoofTerrace"))
	assert(freight_route != null and freight_route.has_node("FreightBridge02"))
	assert(freight_route.has_node("CentralDropLadder"))
	assert(east_conduit != null and east_conduit.has_node("ConduitRoof03"))
	assert(roof_route != null and roof_route.has_node("Building06RoofLadder"))
	assert(roof_route.has_node("Building09RoofLadder"))
	assert(roof_route.has_node("SecurityRoofDescent"))
	assert(hub.find_child("StreetStall_West", true, false) != null)
	assert(hub.find_child("StreetStall_Central", true, false) != null)
	assert(hub.find_child("StreetStall_East", true, false) != null)

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
