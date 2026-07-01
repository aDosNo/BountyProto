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

	var activity := map.get_node("Gameplay/BazaarSafehouseActivity")
	var safehouse := map.get_node("Hesperus_BazaarSafehouse")
	var ledger := root.get_node("HunterLedger")
	var starting_credits: int = ledger.total()
	assert(activity != null)
	assert(safehouse != null)
	assert(safehouse.find_child("BS_BrokerReader", true, false) != null)
	assert(safehouse.find_child("BS_ServiceBypass", true, false) != null)
	assert(safehouse.find_child("BS_RoofOverride", true, false) != null)
	assert(safehouse.find_child("BS_HunterCacheDoor", true, false) != null)
	activity.state = 0
	activity.locked_down = false
	activity.solution_used = ""

	var player := AccessPlayer.new()
	map.add_child(player)

	activity.interact("broker", player)
	assert(activity.state == 0)
	player.access["vendor_staff"] = true
	activity.interact("broker", player)
	assert(activity.state == 1)
	assert(activity.solution_used == "vendor authorization")

	activity.state = 0
	activity.solution_used = ""
	var bounty_manager := map.get_node("Gameplay/BountyManager")
	bounty_manager.add_heat(2, "safehouse test")
	assert(activity.locked_down)
	activity.interact("broker", player)
	assert(activity.state == 0)
	player.access["utility"] = true
	activity.interact("service_bypass", player)
	assert(activity.state == 1)
	assert(activity.solution_used == "utility bypass")

	activity.state = 0
	activity.solution_used = ""
	activity.interact("roof_override", player)
	assert(activity.state == 1)
	assert(activity.solution_used == "roof override")

	activity.interact("cache", player)
	assert(activity.state == 2)
	assert(player.has_access_tag("vendor_staff"))
	ledger.add(starting_credits - ledger.total())

	print("Bazaar Safehouse: branch and anchor checks passed.")
	quit()
