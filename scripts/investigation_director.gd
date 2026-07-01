extends Node3D
## Contract-scoped evidence web. Definitions own meaning, anchors own placement,
## and runtime evidence resolves values from the active target profile.

signal lead_added(lead: Dictionary)
signal lead_updated(lead: Dictionary)
signal evidence_verified(category: String, value: String, evidence_id: String)

const EVIDENCE_SCENE := preload("res://scenes/props/ScanEvidence3D.tscn")
const DEFAULT_DEFINITIONS := "res://data/investigation_clues_hesperus.json"
const ZONE_DIRECTORY := [
	{"id": "dock", "name": "Extraction Dock", "position": Vector3(-55.0, 0.0, -8.0)},
	{"id": "side_alley", "name": "Side Alley", "position": Vector3(-35.0, 0.0, 24.0)},
	{"id": "main_bazaar", "name": "Main Bazaar", "position": Vector3(15.0, 0.0, 5.0)},
	{"id": "north_arcade", "name": "North Arcade", "position": Vector3(8.0, 0.0, -47.0)},
	{"id": "north_service", "name": "North Service Street", "position": Vector3(75.0, 0.0, -39.0)},
	{"id": "foremarket", "name": "Foremarket", "position": Vector3(50.0, 0.0, 43.0)},
	{"id": "courtyard", "name": "Capture Courtyard", "position": Vector3(112.0, 0.0, -4.0)},
	{"id": "freight_return", "name": "Freight Return", "position": Vector3(44.0, 0.0, 75.0)},
]

@export_file("*.json") var definitions_path := DEFAULT_DEFINITIONS
@export var max_active_leads := 3
@export var anchors_path: NodePath = NodePath("EvidenceAnchors")
@export var evidence_seed := 0

var target_profile: Dictionary = {}
var definitions: Dictionary = {}
var leads: Dictionary = {}
var validation_errors: Array[String] = []
var _anchors: Array[Node] = []
var _used_anchor_ids: Dictionary = {}
var _spawned_evidence: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _lead_serial := 0
var _navigation_lead_id := ""


func _ready() -> void:
	add_to_group("investigation_director")
	_load_definitions()
	_collect_anchors()
	var crowd_director := get_tree().get_first_node_in_group("crowd_director")
	if crowd_director != null:
		var profile_value = crowd_director.get("target_profile")
		if profile_value is Dictionary and not profile_value.is_empty():
			target_profile = profile_value.duplicate(true)
		if crowd_director.has_signal("crowd_ready"):
			crowd_director.crowd_ready.connect(_on_crowd_ready)


func start_contract(profile_override: Dictionary = {}) -> void:
	reset_contract()
	if not profile_override.is_empty():
		target_profile = profile_override.duplicate(true)
	if target_profile.is_empty():
		var crowd_director := get_tree().get_first_node_in_group("crowd_director")
		if crowd_director != null:
			var profile_value = crowd_director.get("target_profile")
			if profile_value is Dictionary:
				target_profile = profile_value.duplicate(true)
	if target_profile.is_empty():
		push_warning("InvestigationDirector cannot start without a target profile.")
		return
	_configure_seed()
	var intel := get_node_or_null("/root/BountyIntel")
	if intel != null and intel.has_method("learn"):
		intel.call("learn", "build", String(target_profile.get("build", "")), "bounty dossier")
	_queue_definition("korvaxi_footprint_trail", "bounty dossier")
	_fill_available_slots()


func reset_contract() -> void:
	for evidence in _spawned_evidence.values():
		if is_instance_valid(evidence):
			evidence.remove_from_group("scanner_evidence")
			evidence.set_process(false)
			evidence.queue_free()
	leads.clear()
	_used_anchor_ids.clear()
	_spawned_evidence.clear()
	_lead_serial = 0
	_navigation_lead_id = ""


func report_witness_hint(category: String, claimed_value: String, witness_id: String) -> Dictionary:
	var existing := _find_lead_for_category(category)
	if not existing.is_empty():
		return existing
	var definition := _definition_for_category(category)
	if definition.is_empty():
		return {}
	var lead := _queue_definition(
		String(definition["definition_id"]),
		"witness: %s" % witness_id,
		claimed_value
	)
	_fill_available_slots()
	return leads.get(String(lead.get("lead_id", "")), lead).duplicate(true)


func verify_evidence(evidence: Node) -> void:
	var runtime_lead_id := String(evidence.get("lead_id"))
	if not leads.has(runtime_lead_id):
		return
	var lead: Dictionary = leads[runtime_lead_id]
	if String(lead.get("status", "")) == "VERIFIED":
		return
	lead["status"] = "VERIFIED"
	lead["evidence_id"] = String(evidence.get("evidence_id"))
	lead["value"] = String(evidence.get("resolved_value"))
	leads[runtime_lead_id] = lead
	var intel := get_node_or_null("/root/BountyIntel")
	if intel != null and intel.has_method("verify_from_evidence"):
		intel.call(
			"verify_from_evidence",
			String(lead["category"]),
			String(lead["value"]),
			String(lead["evidence_id"]),
			String(lead["source"])
		)
	lead_updated.emit(lead.duplicate(true))
	if runtime_lead_id == _navigation_lead_id:
		_navigation_lead_id = ""
	_queue_followups(
		String(lead["definition_id"]),
		String(lead["lead_id"]),
		String(evidence.get("followup_anchor_id"))
	)
	_fill_available_slots()
	_focus_active_followup(String(lead["definition_id"]))
	evidence_verified.emit(String(lead["category"]), String(lead["value"]), String(lead["evidence_id"]))


func get_leads() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for lead in leads.values():
		result.append((lead as Dictionary).duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("serial", 0)) < int(b.get("serial", 0))
	)
	return result


func get_active_lead_summary() -> String:
	var parts: Array[String] = []
	for lead in get_leads():
		if String(lead.get("status", "")) != "ACTIVE":
			continue
		parts.append("%s — %s" % [lead.get("title", "Evidence"), lead.get("zone_label", "district")])
	if parts.is_empty():
		return "Work witnesses and district activities for new evidence."
	return "Active leads: " + " | ".join(parts)


func definition_count() -> int:
	return definitions.size()


func active_evidence_count() -> int:
	return _spawned_evidence.size()


func get_zone_for_position(world_position: Vector3) -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_distance := INF
	var flat_position := Vector3(world_position.x, 0.0, world_position.z)
	for zone_value in ZONE_DIRECTORY:
		var zone: Dictionary = zone_value
		var distance := flat_position.distance_to(zone["position"])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = zone
	return nearest.duplicate(true)


func get_navigation_snapshot(player_position: Vector3) -> Dictionary:
	var active_lead: Dictionary = {}
	var nearest_distance := INF
	if not _navigation_lead_id.is_empty() and leads.has(_navigation_lead_id):
		var focused: Dictionary = leads[_navigation_lead_id]
		if String(focused.get("status", "")) == "ACTIVE":
			active_lead = focused
			var focused_position: Vector3 = focused.get("world_position", Vector3.ZERO)
			nearest_distance = Vector2(
				focused_position.x - player_position.x,
				focused_position.z - player_position.z
			).length()
	for lead_value in get_leads():
		var lead: Dictionary = lead_value
		if String(lead.get("status", "")) != "ACTIVE":
			continue
		if not active_lead.is_empty():
			break
		var destination: Vector3 = lead.get("world_position", Vector3.ZERO)
		var distance := Vector2(
			destination.x - player_position.x,
			destination.z - player_position.z
		).length()
		if distance < nearest_distance:
			nearest_distance = distance
			active_lead = lead
	var snapshot := {
		"current_zone": String(get_zone_for_position(player_position).get("name", "Hesperus Market")),
	}
	if active_lead.is_empty():
		return snapshot
	var destination: Vector3 = active_lead.get("world_position", Vector3.ZERO)
	snapshot["lead_title"] = String(active_lead.get("title", "Evidence"))
	snapshot["lead_zone"] = String(active_lead.get("zone_label", "Unknown district"))
	snapshot["distance"] = nearest_distance
	snapshot["bearing"] = _cardinal_bearing(destination - player_position)
	return snapshot


func _cardinal_bearing(offset: Vector3) -> String:
	var angle := wrapf(rad_to_deg(atan2(offset.x, -offset.z)), 0.0, 360.0)
	var directions := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	return directions[int(floor((angle + 22.5) / 45.0)) % directions.size()]


func _queue_definition(
	definition_id: String,
	source: String,
	claimed_value: String = "",
	preferred_anchor_id: String = ""
) -> Dictionary:
	if not definitions.has(definition_id):
		return {}
	_lead_serial += 1
	var definition: Dictionary = definitions[definition_id]
	var lead_id := "lead_%02d_%s" % [_lead_serial, definition_id]
	var lead := {
		"lead_id": lead_id,
		"definition_id": definition_id,
		"category": String(definition.get("trait_category", "")),
		"claimed_value": claimed_value,
		"value": "",
		"source": source,
		"title": String(definition.get("lead_title", definition_id)),
		"zone_label": "unlocated",
		"anchor_id": "",
		"preferred_anchor_id": preferred_anchor_id,
		"world_position": Vector3.ZERO,
		"evidence_id": "",
		"status": "RUMORED",
		"serial": _lead_serial,
	}
	leads[lead_id] = lead
	lead_added.emit(lead.duplicate(true))
	return lead


func _fill_available_slots() -> void:
	var active_count := 0
	for lead in leads.values():
		if String((lead as Dictionary).get("status", "")) == "ACTIVE":
			active_count += 1
	for lead in get_leads():
		if active_count >= max_active_leads:
			break
		if String(lead.get("status", "")) != "RUMORED":
			continue
		if _spawn_lead(lead):
			active_count += 1


func _spawn_lead(lead: Dictionary) -> bool:
	var definition_id := String(lead.get("definition_id", ""))
	if not definitions.has(definition_id):
		return false
	var definition: Dictionary = definitions[definition_id]
	var anchor := _choose_anchor(definition, String(lead.get("preferred_anchor_id", "")))
	if anchor == null:
		return false
	var evidence := EVIDENCE_SCENE.instantiate()
	add_child(evidence)
	evidence.call("configure", definition, target_profile, anchor, String(lead["lead_id"]))
	var anchor_id := String(anchor.get("anchor_id"))
	_used_anchor_ids[anchor_id] = true
	_spawned_evidence[String(lead["lead_id"])] = evidence
	lead["status"] = "ACTIVE"
	lead["anchor_id"] = anchor_id
	lead["zone_label"] = String(anchor.get("zone_label"))
	lead["world_position"] = (anchor as Node3D).global_position
	leads[String(lead["lead_id"])] = lead
	if _navigation_lead_id.is_empty():
		_navigation_lead_id = String(lead["lead_id"])
	lead_updated.emit(lead.duplicate(true))
	return true


func _focus_active_followup(definition_id: String) -> void:
	if not definitions.has(definition_id):
		return
	var definition: Dictionary = definitions[definition_id]
	for category in definition.get("followup_categories", []):
		var followup := _find_lead_for_category(String(category))
		if String(followup.get("status", "")) == "ACTIVE":
			_navigation_lead_id = String(followup.get("lead_id", ""))
			return


func _choose_anchor(definition: Dictionary, preferred_anchor_id: String = "") -> Node:
	var required_tags: Array = definition.get("anchor_tags", [])
	var candidates: Array[Node] = []
	for anchor in _anchors:
		var anchor_id := String(anchor.get("anchor_id"))
		if anchor_id.is_empty() or _used_anchor_ids.has(anchor_id):
			continue
		if not anchor.has_method("accepts") or not bool(anchor.call("accepts", required_tags)):
			continue
		if anchor.has_method("resolve_placement") and not bool(anchor.call("resolve_placement")):
			push_warning("Evidence anchor %s rejected: %s." % [
				anchor_id,
				String(anchor.get("placement_error")),
			])
			continue
		if anchor.has_method("is_placement_clear") and not bool(anchor.call("is_placement_clear")):
			push_warning("Evidence anchor %s rejected: placement intersects world collision." % anchor_id)
			continue
		if not preferred_anchor_id.is_empty() and anchor_id == preferred_anchor_id:
			return anchor
		candidates.append(anchor)
	if candidates.is_empty():
		return null
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _definition_for_category(category: String) -> Dictionary:
	for definition in definitions.values():
		if String((definition as Dictionary).get("trait_category", "")) == category:
			return definition
	return {}


func _find_lead_for_category(category: String) -> Dictionary:
	for lead in get_leads():
		if String(lead.get("category", "")) == category:
			return lead
	return {}


func _queue_followups(
	definition_id: String,
	source_lead_id: String,
	preferred_anchor_id: String = ""
) -> void:
	if not definitions.has(definition_id):
		return
	var definition: Dictionary = definitions[definition_id]
	for category in definition.get("followup_categories", []):
		var category_id := String(category)
		var existing := _find_lead_for_category(category_id)
		if not existing.is_empty():
			if not preferred_anchor_id.is_empty() \
					and String(existing.get("status", "")) != "VERIFIED" \
					and String(existing.get("anchor_id", "")) != preferred_anchor_id:
				_retarget_lead(existing, preferred_anchor_id, source_lead_id)
			continue
		var followup := _definition_for_category(category_id)
		if followup.is_empty():
			continue
		_queue_definition(
			String(followup["definition_id"]),
			"follow-up: %s" % source_lead_id,
			"",
			preferred_anchor_id
		)


func _retarget_lead(lead: Dictionary, preferred_anchor_id: String, source_lead_id: String) -> void:
	var lead_id := String(lead.get("lead_id", ""))
	var old_anchor_id := String(lead.get("anchor_id", ""))
	if _spawned_evidence.has(lead_id):
		var old_evidence: Node = _spawned_evidence[lead_id]
		if is_instance_valid(old_evidence):
			old_evidence.remove_from_group("scanner_evidence")
			old_evidence.queue_free()
		_spawned_evidence.erase(lead_id)
	if not old_anchor_id.is_empty():
		_used_anchor_ids.erase(old_anchor_id)
	lead["status"] = "RUMORED"
	lead["source"] = "follow-up: %s" % source_lead_id
	lead["anchor_id"] = ""
	lead["preferred_anchor_id"] = preferred_anchor_id
	lead["world_position"] = Vector3.ZERO
	lead["zone_label"] = "trail destination pending"
	leads[lead_id] = lead
	lead_updated.emit(lead.duplicate(true))


func _configure_seed() -> void:
	var district_state := get_node_or_null("/root/DistrictState")
	var seed_value := 0
	if evidence_seed != 0:
		seed_value = evidence_seed
	elif district_state != null:
		seed_value = int(district_state.call("get_state", "hesperus.contract.evidence_seed", seed_value))
	if seed_value == 0:
		seed_value = randi_range(1, 2147483646)
	if district_state != null:
		district_state.call("set_state", "hesperus.contract.evidence_seed", seed_value)
	_rng.seed = seed_value


func _load_definitions() -> void:
	definitions.clear()
	validation_errors.clear()
	if not FileAccess.file_exists(definitions_path):
		validation_errors.append("Missing evidence database: %s" % definitions_path)
		return
	var file := FileAccess.open(definitions_path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
	if not (parsed is Dictionary):
		validation_errors.append("Evidence database is not a dictionary.")
		return
	var entries = parsed.get("definitions", [])
	if not (entries is Array):
		validation_errors.append("Evidence database definitions must be an array.")
		return
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var definition: Dictionary = entry
		var definition_id := String(definition.get("definition_id", ""))
		var category := String(definition.get("trait_category", ""))
		if definition_id.is_empty():
			validation_errors.append("Evidence definition has no definition_id.")
			continue
		if not ["build", "appearance", "movement_tell", "location_habit", "scanner_signature"].has(category):
			validation_errors.append("%s has invalid trait category %s." % [definition_id, category])
			continue
		var sources = definition.get("source_types", [])
		if category != "scanner_signature" and (not sources is Array or sources.size() < 2):
			validation_errors.append("%s needs at least two source types." % definition_id)
			continue
		definitions[definition_id] = definition


func _collect_anchors() -> void:
	_anchors.clear()
	var root_node := get_node_or_null(anchors_path)
	if root_node == null:
		validation_errors.append("EvidenceAnchors node is missing.")
		return
	for child in root_node.get_children():
		if child.has_method("accepts"):
			_anchors.append(child)
	var known_tags: Dictionary = {}
	for anchor in _anchors:
		var tags: PackedStringArray = anchor.call("get_effective_tags") \
			if anchor.has_method("get_effective_tags") else anchor.get("anchor_tags")
		for tag in tags:
			known_tags[String(tag)] = true
	for definition in definitions.values():
		for tag in (definition as Dictionary).get("anchor_tags", []):
			if not known_tags.has(String(tag)):
				validation_errors.append("%s references missing anchor tag %s." % [
					definition.get("definition_id", "?"), tag
				])


func _on_crowd_ready(profile: Dictionary) -> void:
	target_profile = profile.duplicate(true)
