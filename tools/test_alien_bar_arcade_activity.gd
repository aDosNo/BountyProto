extends SceneTree


class AccessPlayer:
	extends Node

	var access: Dictionary = {}

	func has_access_tag(access_tag: String) -> bool:
		return access.has(access_tag)

	func grant_credential(access_tag: String) -> void:
		access[access_tag] = true


func _initialize() -> void:
	await process_frame

	var district_state := root.get_node_or_null("DistrictState")
	if district_state != null:
		district_state.call("clear_prefix", "hesperus.")

	var intel := root.get_node_or_null("BountyIntel")
	if intel != null and intel.has_method("reset"):
		intel.call("reset")

	var packed := load("res://scenes/maps/HesperusMarket_Blockout.tscn") as PackedScene
	assert(packed != null)
	var map := packed.instantiate()
	root.add_child(map)
	current_scene = map
	await process_frame
	await process_frame

	var systems := map.get_node("HesperusDistrictSystems")
	var activity := systems.get_node("AlienBarArcadeActivity")
	var arcade := map.get_node("Hesperus_AlienBar_CommercialArcade")
	var ledger := root.get_node("HunterLedger")
	var starting_credits: int = ledger.total()
	assert(activity != null)
	assert(arcade != null)
	assert(district_state != null)
	assert(intel != null)

	for role_node_name in [
		"BarInteractable",
		"PawnInteractable",
		"ClinicInteractable",
		"MotelInteractable",
		"ServiceInteractable",
	]:
		var role_node := activity.get_node(role_node_name) as Node3D
		assert(role_node != null)
		assert(role_node.global_position.length() > 1.0)

	var player := AccessPlayer.new()
	map.add_child(player)

	if ledger.total() < 300:
		ledger.add(300 - ledger.total())
	activity.interact("bar", player)
	assert(district_state.call("has_flag", "hesperus.target.meeting_scheduled"))
	assert(intel.known.has("location_habit"))
	assert(intel.known["location_habit"]["value"] == "courtyard")

	activity.interact("pawn", player)
	assert(player.has_access_tag("vendor_staff"))
	assert(intel.known.has("appearance"))
	assert(intel.known["appearance"]["value"] == "red coat")

	activity.interact("clinic", player)
	assert(district_state.call("has_flag", "hesperus.target.implant_disrupted"))
	assert(intel.known.has("scanner_signature"))
	assert(intel.known["scanner_signature"]["value"] == "cybernetic arm")

	activity.interact("motel", player)
	assert(district_state.call("has_flag", "hesperus.courtyard.roof_access"))

	activity.interact("service", player)
	assert(district_state.call("has_flag", "hesperus.arcade.power_cut"))

	var snapshot: Dictionary = district_state.call("snapshot", "hesperus.arcade.")
	for role in ["bar", "pawn", "clinic", "motel", "service"]:
		assert(snapshot.has("hesperus.arcade.%s_complete" % role))

	ledger.add(starting_credits - ledger.total())
	print("Alien Bar Arcade activity: interactables, state flags, intel, and credentials passed.")
	quit()
