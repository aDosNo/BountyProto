extends SceneTree

const MAIN_SCENE := preload("res://scenes/maps/HesperusMarket_Blockout.tscn")
const AUTHORED_NAMES := [
	"HAULER", "STEVEDORE", "PEDDLER", "GRAFTER", "SPICER",
	"WELDER", "PILGRIM", "LUGGER", "DRIFTER", "TINKER",
]


func _initialize() -> void:
	var scene := MAIN_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	for _frame in range(20):
		await process_frame
		var pending_manager := scene.get_node_or_null("Gameplay/BountyManager")
		if pending_manager != null and int(pending_manager.get("state")) != 0:
			break

	var failures: Array[String] = []
	var intel := root.get_node_or_null("BountyIntel")
	var district_state := root.get_node_or_null("DistrictState")
	var manager := scene.get_node_or_null("Gameplay/BountyManager")
	var target := scene.get_node_or_null("Gameplay/KorvaxiTarget")
	_expect(intel != null, "BountyIntel autoload", failures)
	_expect(manager != null, "BountyManager", failures)
	_expect(target != null, "KorvaxiTarget", failures)
	if intel == null or manager == null or target == null:
		_finish(failures)
		return

	if int(manager.get("state")) == 0:
		manager.call("accept_bounty")
		await process_frame

	var old_arcade_state: Dictionary = {}
	if district_state != null:
		old_arcade_state = district_state.call("snapshot", "hesperus.arcade.")
		district_state.call("set_flag", "hesperus.arcade.pawn_complete", true)
		intel.call("reset")
		manager.call("_restore_persistent_intel_rewards")
		_expect(bool(intel.call("knows", "appearance")), "completed activity rehydrates earned intel", failures)
		district_state.call("clear_prefix", "hesperus.arcade.")
		for state_id in old_arcade_state:
			district_state.call("set_state", state_id, old_arcade_state[state_id])

	intel.call("reset")
	_expect(int(intel.call("known_visible_count")) == 0, "zero-intel sweep gate", failures)

	intel.call("learn", "appearance", "red coat", "test")
	_expect(_matching_authored_count(intel) == 5, "appearance narrows authored field to five", failures)
	intel.call("learn", "movement_tell", "heavy gait", "test")
	_expect(_matching_authored_count(intel) == 3, "appearance plus gait narrows to three", failures)
	intel.call("learn", "location_habit", "courtyard", "test")
	_expect(_matching_authored_count(intel) == 1, "visible conjunction leaves one triple-twin", failures)

	target.call("begin_focus")
	target.call("scan", 10.0)
	manager.call("on_npc_accused", target)
	_expect(int(manager.get("state")) == 2, "confront blocked without signature intel", failures)

	intel.call("learn", "scanner_signature", "cybernetic arm", "test")
	manager.call("on_npc_accused", target)
	_expect(int(manager.get("state")) == 3, "analyzed target confirms with signature intel", failures)

	_finish(failures)


func _matching_authored_count(intel: Node) -> int:
	var count := 0
	for npc in get_nodes_in_group("scannable_npc"):
		var npc_name = npc.get("npc_name")
		if npc_name is String and AUTHORED_NAMES.has(npc_name) and bool(intel.call("visible_match", npc)):
			count += 1
	return count


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("Golden investigation contract test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("Golden investigation contract test: %s" % failure)
	quit(1)
