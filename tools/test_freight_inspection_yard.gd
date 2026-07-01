extends SceneTree


class AccessPlayer:
	extends Node

	var access: Dictionary = {}

	func has_access_tag(access_tag: String) -> bool:
		return access.has(access_tag)

	func grant_credential(access_tag: String) -> void:
		access[access_tag] = true


func _initialize() -> void:
	var district_state := root.get_node_or_null("DistrictState")
	if district_state != null:
		district_state.call("clear_prefix", "hesperus.")

	var packed := load("res://scenes/maps/HesperusMarket_Blockout.tscn") as PackedScene
	assert(packed != null)
	var map := packed.instantiate()
	root.add_child(map)
	current_scene = map
	await process_frame
	await process_frame

	var activity := map.get_node("Gameplay/FreightInspectionYardActivity")
	var yard := map.get_node("Hesperus_FreightInspectionYard")
	var manager := map.get_node("Gameplay/BountyManager")
	var ledger := root.get_node("HunterLedger")
	var starting_credits: int = ledger.total()
	assert(activity != null)
	assert(yard != null)
	for anchor_name in [
		"FY_ManifestReader",
		"FY_ScannerBypass",
		"FY_TowerOverride",
		"FY_DispatchConsole",
		"FY_SuspendedCoverContainer",
	]:
		assert(yard.find_child(anchor_name, true, false) != null)
	activity.state = 0
	activity.solution_used = ""
	for role_node_name in ["ManifestTerminal", "ScannerBypass", "TowerOverride", "DispatchConsole"]:
		var role_node := activity.get_node(role_node_name) as Node3D
		assert(role_node != null)
		assert(role_node.global_position.length() > 1.0)

	var player := AccessPlayer.new()
	map.add_child(player)
	var extraction_guard := activity.get_node("YardExtractionGuard")
	extraction_guard.set_active(true)
	activity.apply_extraction_modifier()
	assert(activity.state == 0)
	extraction_guard.set_active(false)

	activity.interact("manifest", player)
	assert(activity.state == 0)
	player.access["courtyard_service"] = true
	activity.interact("manifest", player)
	assert(activity.state == 1)
	assert(activity.solution_used == "courier manifest")

	activity.state = 0
	activity.solution_used = ""
	player.access.erase("courtyard_service")
	activity.interact("scanner_bypass", player)
	assert(activity.state == 0)
	player.access["utility"] = true
	activity.interact("scanner_bypass", player)
	assert(activity.state == 1)
	assert(activity.solution_used == "scanner bypass")

	activity.state = 0
	activity.solution_used = ""
	activity.interact("tower_override", player)
	assert(activity.state == 1)
	assert(activity.solution_used == "tower override")
	activity.interact("dispatch", player)
	assert(activity.state == 2)
	assert(player.has_access_tag("freight_dispatch"))

	assert(not extraction_guard.visible)
	manager.start_extraction_phase("Alive", 7000)
	await process_frame
	assert(not extraction_guard.visible)

	ledger.add(starting_credits - ledger.total())
	print("Freight Inspection Yard: branches, anchors, and extraction modifier passed.")
	quit()
