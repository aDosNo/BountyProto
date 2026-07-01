extends SceneTree

const MAIN_SCENE := preload("res://scenes/maps/HesperusMarket_Blockout.tscn")
const CROWD_NPC_SCENE := preload("res://scenes/npcs/CrowdNPC.tscn")


func _initialize() -> void:
	var scene := MAIN_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	for _frame in range(12):
		await process_frame

	var failures: Array[String] = []
	var director := scene.get_node_or_null("Gameplay/Investigation")
	var intel := root.get_node_or_null("BountyIntel")
	_expect(director != null, "InvestigationDirector exists", failures)
	_expect(intel != null, "BountyIntel autoload exists", failures)
	if director == null or intel == null:
		_finish(failures)
		return

	intel.call("reset")
	director.set("evidence_seed", 77331)
	director.call("start_contract")
	_expect(int(director.call("definition_count")) == 4, "four evidence definitions loaded", failures)
	_expect(bool(intel.call("knows", "build")), "bounty dossier seeds shared target build", failures)
	var validation_errors: Array = director.get("validation_errors")
	_expect(validation_errors.is_empty(), "database and anchor tags validate", failures)
	_expect(int(director.call("active_evidence_count")) == 1, "footprints seed the investigation chain", failures)
	var navigation: Dictionary = director.call(
		"get_navigation_snapshot",
		Vector3(-55.0, 0.0, -8.0)
	)
	_expect(String(navigation.get("current_zone", "")) == "Extraction Dock",
		"navigation resolves the player's current canonical zone", failures)
	_expect(navigation.has("lead_zone") and navigation.has("bearing") and navigation.has("distance"),
		"navigation exposes a located lead bearing and distance", failures)
	var first_placements := _placement_map(director)
	director.call("start_contract")
	_expect(_placement_map(director) == first_placements, "identical seed reproduces placements", failures)
	director.set("evidence_seed", 77332)
	director.call("start_contract")
	_expect(_placement_map(director) != first_placements, "different seed varies placements", failures)
	director.set("evidence_seed", 77331)
	director.call("start_contract")

	var footprint := _evidence_for_category(director, "movement_tell")
	_expect(footprint != null, "footprint trail spawned", failures)
	if footprint != null:
		_expect(String(footprint.get("evidence_kind")) == "footprint_trail", "movement evidence is footprints", failures)
		_expect(String(footprint.get("resolved_value")) == "heavy gait", "footprints resolve live target gait", failures)
		_expect(not String(footprint.get("followup_anchor_id")).is_empty(),
			"footprints point to a concrete follow-up anchor", failures)

	var witness := CROWD_NPC_SCENE.instantiate()
	scene.add_child(witness)
	witness.call("apply_identity", {
		"npc_name": "TEST WITNESS",
		"is_candidate": false,
		"is_target": false,
		"witness_hint_category": "appearance",
		"witness_hint_value": "red coat",
	})
	witness.call("interact", null)
	var witness_lead := _lead_for_category(director, "appearance")
	_expect(not witness_lead.is_empty(), "witness creates a lead", failures)
	_expect(not bool(intel.call("knows", "appearance")), "witness rumor does not verify appearance", failures)
	_expect(String(witness_lead.get("zone_label", "unlocated")) != "unlocated", "witness lead points to a zone", failures)
	_expect(int(director.call("active_evidence_count")) == 2,
		"witness adds a second active lead beside the footprint trail", failures)

	var expected_followup := String(footprint.get("followup_anchor_id")) if footprint != null else ""
	if footprint != null:
		footprint.call("scan", 10.0)
	_expect(bool(intel.call("knows", "movement_tell")), "scanning footprints verifies movement", failures)
	if footprint != null:
		_expect(footprint.get_node_or_null("DirectionCue") == null,
			"footprint trail has no arrow overlay", failures)
		_expect(footprint is Area3D,
			"footprint scan volume does not block player movement", failures)
		var first_print := footprint.get_node("VisualRoot/Footprint_00") as MeshInstance3D
		var last_print := footprint.get_node("VisualRoot/Footprint_07") as MeshInstance3D
		var trail_direction := (last_print.global_position - first_print.global_position).normalized()
		var footprint_anchor := _anchor_for_id(
			director,
			String(footprint.get("evidence_id")).get_slice("@", 1)
		)
		var authored_points: PackedVector3Array = footprint_anchor.call("world_trail_points")
		var authored_direction := (authored_points[-1] - authored_points[0]).normalized()
		_expect(trail_direction.dot(authored_direction) > 0.9,
			"the footprints follow the anchor's authored walkable alignment", failures)
		_expect(String(footprint.call("get_completed_text")).contains("Trail continues"),
			"footprint result names the continuing trail", failures)

	var appearance_evidence := _evidence_for_category(director, "appearance")
	_expect(appearance_evidence != null, "appearance evidence spawned", failures)
	if appearance_evidence != null:
		appearance_evidence.call("scan", 10.0)
	_expect(bool(intel.call("knows", "appearance")), "physical fibers verify appearance", failures)

	var location_evidence := _evidence_for_category(director, "location_habit")
	_expect(location_evidence != null, "location evidence spawned", failures)
	var location_lead := _lead_for_category(director, "location_habit")
	_expect(String(location_lead.get("anchor_id", "")) == expected_followup,
		"footprint chain activates its authored destination", failures)
	var routed_navigation: Dictionary = director.call(
		"get_navigation_snapshot",
		(footprint as Node3D).global_position
	)
	_expect(String(routed_navigation.get("lead_zone", "")) == "Courtyard Threshold",
		"new trail follow-up remains the focused navigation lead", failures)
	if location_evidence != null:
		location_evidence.call("scan", 10.0)
	_expect(bool(intel.call("knows", "location_habit")), "delivery trace verifies location", failures)

	var signature_evidence := _evidence_for_category(director, "scanner_signature")
	_expect(signature_evidence != null, "location follow-up activates implant residue", failures)
	if signature_evidence != null:
		signature_evidence.call("scan", 10.0)
	_expect(bool(intel.call("knows", "scanner_signature")), "implant residue registers expected signature", failures)
	var evidence_log: Array = intel.call("get_evidence_log")
	_expect(evidence_log.size() == 4, "all verified evidence records provenance", failures)

	director.call("reset_contract")
	_expect(int(director.call("active_evidence_count")) == 0, "contract reset clears runtime evidence", failures)
	intel.call("reset")
	_finish(failures)


func _evidence_for_category(director: Node, category: String) -> Node:
	var spawned: Dictionary = director.get("_spawned_evidence")
	var leads: Dictionary = director.get("leads")
	for lead_id in spawned:
		if not leads.has(lead_id):
			continue
		var lead: Dictionary = leads[lead_id]
		if String(lead.get("category", "")) == category:
			return spawned[lead_id] as Node
	return null


func _lead_for_category(director: Node, category: String) -> Dictionary:
	var leads: Array = director.call("get_leads")
	for lead in leads:
		if String((lead as Dictionary).get("category", "")) == category:
			return lead
	return {}


func _anchor_for_id(director: Node, anchor_id: String) -> Node:
	for anchor in director.get("_anchors"):
		if String((anchor as Node).get("anchor_id")) == anchor_id:
			return anchor as Node
	return null


func _placement_map(director: Node) -> Dictionary:
	var result := {}
	var leads: Array = director.call("get_leads")
	for lead in leads:
		if String((lead as Dictionary).get("status", "")) == "ACTIVE":
			result[String(lead.get("category", ""))] = String(lead.get("anchor_id", ""))
	return result


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("Dynamic evidence database, witness lead, placement, and verification test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("Dynamic evidence test: %s" % failure)
	quit(1)
