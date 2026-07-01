extends SceneTree


func _initialize() -> void:
	var district_state := root.get_node_or_null("DistrictState")
	if district_state == null:
		push_error("Contract persistence test: DistrictState autoload missing")
		quit(1)
		return

	var old_contract: Dictionary = district_state.call("snapshot", "hesperus.contract.")
	district_state.call("set_flag", "hesperus.test_world.access_retained", true)
	district_state.call("set_state", "hesperus.contract.outcome", "stale")
	district_state.call("set_state", "hesperus.contract.escape_route", "stale_route")
	district_state.call("reset_contract_state")

	var failures: Array[String] = []
	_expect(bool(district_state.call("has_flag", "hesperus.test_world.access_retained")),
		"district state survives contract reset", failures)
	_expect(not bool(district_state.call("has_flag", "hesperus.contract.outcome")),
		"contract outcome cleared", failures)
	_expect(String(district_state.call("get_state", "hesperus.contract.escape_route", "")).is_empty(),
		"contract escape route cleared", failures)

	district_state.call("clear_prefix", "hesperus.test_world.")
	district_state.call("clear_prefix", "hesperus.contract.")
	for state_id in old_contract:
		district_state.call("set_state", state_id, old_contract[state_id])

	if failures.is_empty():
		print("Contract persistence boundary test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("Contract persistence boundary test: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
