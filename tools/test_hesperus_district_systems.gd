extends SceneTree

const MAIN_SCENE := preload("res://scenes/maps/HesperusMarket_Blockout.tscn")


func _initialize() -> void:
	var scene := MAIN_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame

	var failures: Array[String] = []
	_expect(root.get_node_or_null("DistrictState") != null, "DistrictState autoload", failures)
	_expect(scene.get_node_or_null("HesperusDistrictSystems/CourtyardSystemicTraversal/CourtyardRoofLadderZone") != null, "courtyard roof ladder", failures)
	_expect(scene.get_node_or_null("HesperusDistrictSystems/CourtyardSystemicTraversal/CourtyardPressureValve") != null, "pressure valve", failures)
	_expect(scene.get_node_or_null("HesperusDistrictSystems/CourtyardSystemicTraversal/InsideServiceGrate") != null, "inside service grate", failures)
	var arcade_activity := scene.get_node_or_null("HesperusDistrictSystems/AlienBarArcadeActivity")
	_expect(arcade_activity != null, "arcade activity", failures)
	if arcade_activity != null:
		for role_name in ["BarInteractable", "PawnInteractable", "ClinicInteractable", "MotelInteractable", "ServiceInteractable"]:
			_expect(arcade_activity.get_node_or_null(role_name) != null, role_name, failures)

	var route_root := scene.get_node_or_null("KorvaxiEscapeRoute")
	_expect(route_root != null, "escape route root", failures)
	if route_root != null:
		for route_name in ["Route_ServiceStreet", "Route_Rooftop", "Route_ServiceCrawl"]:
			var route := route_root.get_node_or_null(route_name)
			_expect(route != null, route_name, failures)
			if route != null:
				_expect(route.get_child_count() >= 4, "%s marker count" % route_name, failures)
				_expect(not String(route.get_meta("route_id", "")).is_empty(), "%s route id" % route_name, failures)

	var backdoor := scene.get_node_or_null("WorldGeometry/CourtyardArena/Exits/BackDoor_Locked")
	_expect(backdoor != null and String(backdoor.get("state_id")) == "hesperus.courtyard.backdoor", "persistent courtyard backdoor", failures)

	if failures.is_empty():
		print("Hesperus district systems test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("Hesperus district systems test: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
