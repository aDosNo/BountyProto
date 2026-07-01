extends SceneTree

const MAIN_SCENE := preload("res://scenes/maps/HesperusMarket_Blockout.tscn")
const ROUTE_FLAGS := [
	"hesperus.north_service.power_cut",
	"hesperus.courtyard.roof_access",
	"hesperus.courtyard.steam_vented",
]


func _initialize() -> void:
	var district_state := root.get_node_or_null("DistrictState")
	var previous_flags := {}
	if district_state != null:
		for state_id in ROUTE_FLAGS:
			previous_flags[state_id] = district_state.call("get_state", state_id, null)
			district_state.call("set_flag", state_id, false)

	var scene := MAIN_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame

	var failures: Array[String] = []
	var target := scene.get_node_or_null("Gameplay/KorvaxiTarget")
	var route_root := scene.get_node_or_null("KorvaxiEscapeRoute")
	_expect(target != null, "Korvaxi target", failures)
	_expect(route_root != null, "route root", failures)
	if target != null and route_root != null:
		for route_name in ["Route_ServiceStreet", "Route_Rooftop", "Route_ServiceCrawl"]:
			var route := route_root.get_node_or_null(route_name)
			_expect(route != null, route_name, failures)
			if route != null:
				_expect(not String(route.get_meta("display_name", "")).is_empty(),
					"%s display name" % route_name, failures)
				_expect(not String(route.get_meta("cue_text", "")).is_empty(),
					"%s cue text" % route_name, failures)

		target.call("_cache_escape_nodes")
		var options: Array = target.get("_route_options")
		var available_without_preparation := 0
		for route_data in options:
			if bool(target.call("_route_is_available", route_data)):
				available_without_preparation += 1
		_expect(available_without_preparation == 1, "only public route available without preparation", failures)

		target.set("state", 3) # FLEEING
		_expect(bool(target.call("is_chase_reacquirable")), "fleeing target is sweep-reacquirable", failures)
		target.call("mark_swept", 4.0)
		var marker := target.get_node_or_null("TargetMarker")
		_expect(marker != null and marker.visible, "sweep restores live target marker", failures)

	if district_state != null:
		for state_id in ROUTE_FLAGS:
			var previous = previous_flags[state_id]
			if previous == null:
				district_state.call("erase_state", state_id)
			else:
				district_state.call("set_state", state_id, previous)

	if failures.is_empty():
		print("Korvaxi chase contract test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("Korvaxi chase contract test: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
