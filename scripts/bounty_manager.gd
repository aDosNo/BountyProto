extends Node

enum MissionState {
	INACTIVE,
	ACCEPTED,
	TRACKING,
	TARGET_IDENTIFIED,
	TARGET_NEUTRALIZED,
	EXTRACTING,
	COMPLETE,
	FAILED,
}

@export var target_path: NodePath
@export var reward_screen_path: NodePath
@export var extraction_zone_path: NodePath
@export var pressure_enemies: Array[NodePath] = []
@export var first_clue_id: String = "clue_01_market_trace"
@export var auto_accept: bool = true
@export_group("Accusation")
## Known intel categories required before a confrontation is allowed.
@export var intel_required_to_confirm: int = 3
## Guards within their shout_radius of a wrong accusation go hostile.
@export var wrong_accusation_alerts_guards: bool = true
## Credits docked from the final payout per wrong accusation (capped at half).
@export var wrong_accusation_penalty: int = 500
@export_group("District Heat")
@export var heat_lockdown_threshold: int = 2
## A single wrong public accusation is meant to land hard (mission "transforms"):
## set equal to heat_lockdown_threshold so ONE wrong mark trips lockdown. Lower
## it if wrong marks should need to stack before the district reacts.
@export var heat_wrong_accusation: int = 2
@export var heat_civilian_wounded: int = 1
@export var heat_civilian_killed: int = 2
@export var heat_target_killed: int = 1
@export_group("Wrong Accusation Crowd")
## Bystanders within this radius of a wrong public accusation clam up.
@export var clam_up_radius: float = 15.0
## Seconds the clammed-up bystanders refuse to talk before recovering.
@export var clam_up_duration: float = 35.0

@export var target_name: String = "Korvaxi Jurraal"
@export var location: String = "Hesperus Market / FPS Vertical Arena placeholder"
@export var threat: String = "High"
@export var reward_dead: int = 3000
@export var reward_alive: int = 7000
@export_group("Nemesis")
## Record escaped targets to NemesisRegistry. OFF until the generator stamps
## targets with a scanner_sig + trait_kit — without one, escapes can't be keyed,
## so recording would no-op anyway (registry rejects empty sig). Flip on with
## the generator.
@export var nemesis_recording_enabled: bool = false

var state: MissionState = MissionState.INACTIVE

var _target: Node
var _reward_screen: Control
var _extraction_zone: Node
var _hud: CanvasLayer
var _clues_by_id: Dictionary = {}
var _target_status: String = ""
var _pending_reward: int = 0
var _district_heat: int = 0
var _vendors_locked_down := false
var _active_chase_route_id := ""


func _ready() -> void:
	add_to_group("bounty_manager")
	await get_tree().process_frame
	_target = _resolve_target()
	_reward_screen = _resolve_reward_screen()
	_extraction_zone = _resolve_extraction_zone()
	_hud = await _wait_for_hud()
	_connect_target()
	_connect_extraction_zone()
	_deactivate_pressure_enemies()
	_register_clues()
	_connect_investigation_director()
	_restore_district_consequences()
	if auto_accept:
		accept_bounty()
	else:
		_set_objective("Accept a contract at the bounty board")


func accept_bounty() -> void:
	if _mission_is_closed() or state != MissionState.INACTIVE:
		return

	var district_state := get_node_or_null("/root/DistrictState")
	if district_state != null and district_state.has_method("reset_contract_state"):
		district_state.call("reset_contract_state")
	_reset_bounty_intel()
	_restore_persistent_intel_rewards()
	_set_district_flag("hesperus.contract.active", true)
	_set_district_flag("hesperus.contract.target_escaped", false)
	_set_district_state("hesperus.contract.outcome", "active")
	_set_district_state("hesperus.contract.target_status", "")
	_set_district_state("hesperus.contract.escape_route", "")
	_set_district_flag("hesperus.contract.extraction_prepared", false)
	state = MissionState.ACCEPTED
	var investigation := get_tree().get_first_node_in_group("investigation_director")
	if investigation != null and investigation.has_method("start_contract"):
		investigation.call("start_contract")
		state = MissionState.TRACKING
		_set_objective(String(investigation.call("get_active_lead_summary")))
	else:
		_set_objective("Hold RMB to scan Korvaxi's trace in the bazaar")
		_activate_first_clue()
	print("Bounty accepted: %s" % target_name)


func _reset_bounty_intel() -> void:
	var intel := get_node_or_null("/root/BountyIntel")
	if intel != null and intel.has_method("reset"):
		intel.call("reset")


func _restore_persistent_intel_rewards() -> void:
	var district_state := get_node_or_null("/root/DistrictState")
	var intel := get_node_or_null("/root/BountyIntel")
	if district_state == null or intel == null or not intel.has_method("learn"):
		return

	if bool(district_state.call("has_flag", "hesperus.arcade.pawn_complete")):
		intel.call("learn", "appearance", "red coat", "saved pawned armor receipt")
	if bool(district_state.call("has_flag", "hesperus.arcade.bar_complete")):
		intel.call("learn", "location_habit", "courtyard", "saved North Arcade schedule")
	if bool(district_state.call("has_flag", "hesperus.arcade.clinic_complete")):
		intel.call("learn", "scanner_signature", "cybernetic arm", "saved implant registry")
	if int(district_state.call("get_state", "hesperus.safehouse.state", 0)) >= 2:
		intel.call("learn", "movement_tell", "heavy gait", "saved pursuit ledger")
	if int(district_state.call("get_state", "hesperus.foremarket.cold_chain.state", 0)) >= 3:
		intel.call("learn", "scanner_signature", "cybernetic arm", "saved clinic implant log")
	if int(district_state.call("get_state", "hesperus.evidence_annex.state", 0)) >= 2:
		intel.call("learn", "build", "korvaxi-class heavy", "saved impound biometric record")


func on_target_neutralized() -> void:
	if _mission_is_closed() or state == MissionState.TARGET_NEUTRALIZED or state == MissionState.EXTRACTING:
		return

	_clear_nemesis_if_known()
	add_heat(heat_target_killed, "bounty target killed")
	state = MissionState.TARGET_NEUTRALIZED
	_set_district_state("hesperus.contract.target_status", "dead")
	_set_district_state("hesperus.contract.outcome", "secured")
	_set_objective("%s neutralized. Reach extraction." % target_name.split(" ")[0])
	print("Bounty target neutralized: %s" % target_name)
	start_extraction_phase("Dead", reward_dead)


func on_target_captured() -> void:
	if _mission_is_closed() or state == MissionState.TARGET_NEUTRALIZED or state == MissionState.EXTRACTING:
		return

	_clear_nemesis_if_known()
	state = MissionState.TARGET_NEUTRALIZED
	_set_district_state("hesperus.contract.target_status", "alive")
	_set_district_state("hesperus.contract.outcome", "secured")
	_set_objective("Korvaxi captured alive. Reach extraction.")
	print("Bounty target captured alive: %s" % target_name)
	start_extraction_phase("Alive", reward_alive)


func on_clue_scanned(clue_id: String, next_clue_id: String, reveals_target: bool) -> void:
	if _mission_is_closed() or state == MissionState.TARGET_NEUTRALIZED or state == MissionState.EXTRACTING:
		return

	print("Clue scanned: %s" % clue_id)

	if reveals_target:
		_show_toast_for_clue(clue_id)
		# Funnel rule: clues complete the TRAIL, never the identification.
		# The player must scan candidates and CONFRONT — no free reveals.
		_set_objective("Trail complete. Scan the crowd, verify the profile, and confront the target")
		return

	if next_clue_id.is_empty():
		_show_toast_for_clue(clue_id)
		_set_objective("Trail logged. Sweep the district for another trace")
		return

	_activate_clue(next_clue_id)
	_show_toast_for_clue(clue_id)
	_set_objective(_objective_for_next_clue(next_clue_id))
	print("Activating next clue: %s" % next_clue_id)


## Scan completion on a crowd NPC: intel-comparison only (readout comes from
## scanner/BountyIntel). Identification now requires a deliberate CONFRONT
## (interact) ruled on by on_npc_accused below.
func on_scannable_npc_scanned(npc: Node) -> void:
	if npc == null:
		return
	print("NPC scan logged: %s" % str(npc.get("npc_name")))


func _connect_investigation_director() -> void:
	var investigation := get_tree().get_first_node_in_group("investigation_director")
	if investigation == null:
		return
	if investigation.has_signal("evidence_verified") \
			and not investigation.evidence_verified.is_connected(_on_evidence_verified):
		investigation.evidence_verified.connect(_on_evidence_verified)


func _on_evidence_verified(_category: String, _value: String, _evidence_id: String) -> void:
	if _mission_is_closed():
		return
	var investigation := get_tree().get_first_node_in_group("investigation_director")
	if investigation != null and investigation.has_method("get_active_lead_summary"):
		_set_objective(String(investigation.call("get_active_lead_summary")))


var _wrong_accusations: int = 0


## The accusation. Threshold-gated; wrong mark transforms the mission
## (guards hostile nearby, target goes to ground) — it does not fail it.
func on_npc_accused(npc: Node) -> void:
	if _mission_is_closed() or state == MissionState.TARGET_NEUTRALIZED or state == MissionState.EXTRACTING:
		return
	if state == MissionState.INACTIVE:
		_show_toast("No active contract.")
		return
	if npc == null:
		return

	var intel := get_node_or_null("/root/BountyIntel")
	var known := 0
	if intel != null and intel.has_method("known_visible_count"):
		known = int(intel.call("known_visible_count"))

	if known < intel_required_to_confirm:
		_show_toast("Not enough narrowing intel to confront (%d/%d visible traits). Work the district." % [known, intel_required_to_confirm], 3.0)
		return
	if intel == null or not intel.has_method("knows") or not bool(intel.call("knows", "scanner_signature")):
		_show_toast("Identity unresolved: obtain scanner-signature intel before confronting.", 3.2)
		return
	if not _npc_was_analyzed(npc):
		_show_toast("Analyze this subject before confronting.", 2.8)
		return

	if npc.has_method("mark_confronted"):
		npc.call("mark_confronted")

	var is_target_value = npc.get("is_target")
	if is_target_value is bool and is_target_value:
		_show_toast("Identity confirmed: Korvaxi.")
		_identify_target(npc)
		return

	_on_wrong_accusation(npc)


func _on_wrong_accusation(npc: Node) -> void:
	_wrong_accusations += 1
	add_heat(heat_wrong_accusation, "wrong public accusation")
	_show_toast("Wrong mark. The street saw that — Korvaxi goes to ground.", 3.5)
	_set_objective("Word is spreading. Re-verify your intel and find the real Korvaxi")
	print("Wrong accusation #%d: %s" % [_wrong_accusations, str(npc.get("npc_name"))])

	# Nearby guards take exception to the hunter hassling civilians.
	if wrong_accusation_alerts_guards and npc is Node3D:
		var player := get_tree().get_first_node_in_group("player") as Node3D
		var threat_pos: Vector3 = player.global_position if player != null else (npc as Node3D).global_position
		get_tree().call_group("perceptive", "on_ally_alert", (npc as Node3D).global_position, threat_pos)

	# The real target gets wary and keeps moving.
	var director := get_tree().get_first_node_in_group("crowd_director")
	if director != null and director.has_method("spook_target"):
		director.call("spook_target")

	# Bystanders near the bad call stop cooperating for a while (canvassing the
	# crowd right where you blew it gets harder).
	if director != null and director.has_method("clam_up_near") and npc is Node3D:
		director.call("clam_up_near", (npc as Node3D).global_position, clam_up_radius, clam_up_duration)


func report_civilian_harmed(was_killed: bool, source_position: Vector3 = Vector3.ZERO) -> void:
	var amount := heat_civilian_killed if was_killed else heat_civilian_wounded
	add_heat(amount, "civilian killed" if was_killed else "civilian wounded", source_position)


func add_heat(amount: int, reason: String = "public violence", _source_position: Vector3 = Vector3.ZERO) -> void:
	if amount <= 0 or _mission_is_closed():
		return

	_district_heat += amount
	_set_district_state("hesperus.heat.level", _district_heat)
	print("District heat +%d: %s (total %d/%d)" % [amount, reason, _district_heat, heat_lockdown_threshold])

	if not _vendors_locked_down and _district_heat >= heat_lockdown_threshold:
		_trigger_vendor_lockdown(reason)


func _trigger_vendor_lockdown(reason: String) -> void:
	_vendors_locked_down = true
	_set_district_flag("hesperus.lockdown.active", true)
	_set_district_state("hesperus.heat.level", _district_heat)
	# Responders own their local visual/state consequences. The Bazaar Safehouse
	# drops authored street shutters; legacy responders without stall geometry
	# remain harmless.
	get_tree().call_group("vendor_lockdown", "set_lockdown", reason)
	_show_toast("The bazaar locks down — street access is changing.", 3.0)
	print("District heat hit lockdown threshold (%d): %s. Vendor responders activated." % [heat_lockdown_threshold, reason])


func start_extraction_phase(status: String, reward: int) -> void:
	if _mission_is_closed() or state == MissionState.EXTRACTING:
		return

	_target_status = status
	_pending_reward = reward
	state = MissionState.EXTRACTING
	var district_state := get_node_or_null("/root/DistrictState")
	var freight_prepared := district_state != null and bool(
		district_state.call("has_flag", "hesperus.extraction.freight_prepared")
	)
	_set_district_flag("hesperus.contract.extraction_prepared", freight_prepared)
	_set_objective("Bounty secured. South gate open — return to dock extraction")
	_activate_extraction_zone()
	_activate_pressure_enemies()
	get_tree().call_group("extraction_modifier", "apply_extraction_modifier")
	_open_return_routes()
	print("Extraction phase started. Status: %s. Pending reward: %d" % [_target_status, _pending_reward])


func complete_contract_at_extraction() -> void:
	if state != MissionState.EXTRACTING:
		if state != MissionState.COMPLETE:
			print("Extraction ignored: secure bounty first.")
		return

	complete_bounty(_target_status, _pending_reward)


func complete_bounty(status: String = "Dead", reward: int = -1) -> void:
	if _mission_is_closed():
		return

	state = MissionState.COMPLETE
	_set_district_flag("hesperus.contract.active", false)
	_set_district_state("hesperus.contract.outcome", "complete")
	var final_reward := reward_dead if reward < 0 else reward

	# Collateral fines: wrong accusations come out of the payout, never more
	# than half — sloppy work still pays, it just pays badly.
	var penalty: int = mini(_wrong_accusations * wrong_accusation_penalty, floori(final_reward / 2.0))
	final_reward -= penalty

	var status_text := status
	if status == "Alive":
		status_text = "Alive (+%d CR alive bonus)" % (reward_alive - reward_dead)
	if penalty > 0:
		status_text += "  —  fines: -%d CR" % penalty

	var ledger := get_node_or_null("/root/HunterLedger")
	if ledger != null and ledger.has_method("add"):
		ledger.call("add", final_reward)

	_set_objective("Contract complete.")
	if _reward_screen == null:
		_reward_screen = _resolve_reward_screen()

	if _reward_screen != null and _reward_screen.has_method("show_reward"):
		_reward_screen.call("show_reward", target_name, status_text, final_reward)
	else:
		print("CONTRACT COMPLETE")
		print("Target: %s" % target_name)
		print("Status: %s" % status_text)
		print("Reward: %d CR" % final_reward)


func fail_bounty() -> void:
	if state == MissionState.COMPLETE or state == MissionState.FAILED:
		return

	# Target survived the contract: if we'd identified them, they escape alive
	# and become (or harden into) a nemesis. Identity gate = we know who got away.
	if state == MissionState.TARGET_IDENTIFIED or state == MissionState.TRACKING:
		_record_nemesis_escape()

	state = MissionState.FAILED
	_set_district_flag("hesperus.contract.active", false)
	_set_district_state("hesperus.contract.outcome", "hunter_down")
	_set_objective("Hunter down. Contract failed.")
	print("CONTRACT FAILED: %s" % target_name)

	if _reward_screen == null:
		_reward_screen = _resolve_reward_screen()

	if _reward_screen != null and _reward_screen.has_method("show_failure"):
		_reward_screen.call("show_failure", target_name)
	elif _reward_screen != null and _reward_screen.has_method("show_reward"):
		_reward_screen.call("show_reward", target_name, "Failed", 0)


func _connect_target() -> void:
	if _target == null:
		push_warning("BountyManager could not find Korvaxi target.")
		return

	if _target.has_signal("killed"):
		_target.killed.connect(on_target_neutralized)
	else:
		push_warning("Bounty target has no killed signal.")

	if _target.has_signal("flee_started"):
		_target.flee_started.connect(_on_target_flee_started)
	if _target.has_signal("escape_route_selected"):
		_target.escape_route_selected.connect(_on_escape_route_selected)
	if _target.has_signal("reached_final_node"):
		_target.reached_final_node.connect(_on_target_reached_final_node)
	if _target.has_signal("escaped"):
		_target.escaped.connect(_on_target_escaped)
	if _target.has_signal("stunned"):
		_target.stunned.connect(_on_target_stunned)
	if _target.has_signal("stun_expired"):
		_target.stun_expired.connect(_on_target_stun_expired)
	if _target.has_signal("captured"):
		_target.captured.connect(on_target_captured)


func _connect_extraction_zone() -> void:
	if _extraction_zone == null:
		push_warning("BountyManager could not find extraction zone.")
		return

	if _extraction_zone.has_signal("extraction_reached"):
		_extraction_zone.extraction_reached.connect(complete_contract_at_extraction)


func _register_clues() -> void:
	_clues_by_id.clear()
	var clues := get_tree().get_nodes_in_group("scanner_clue")

	for clue in clues:
		var clue_id_value = clue.get("clue_id")
		if clue_id_value is String and not clue_id_value.is_empty():
			_clues_by_id[clue_id_value] = clue
			if clue.has_signal("clue_scanned"):
				clue.clue_scanned.connect(on_clue_scanned)
			if clue.has_method("set_active"):
				clue.call("set_active", false)


func _activate_first_clue() -> void:
	state = MissionState.TRACKING
	_activate_clue(first_clue_id)


func _activate_clue(clue_id: String) -> void:
	if not _clues_by_id.has(clue_id):
		push_warning("No clue found for id: %s" % clue_id)
		return

	var clue := _clues_by_id[clue_id] as Node
	if clue != null and clue.has_method("set_active"):
		clue.call("set_active", true)


func _identify_target(accused_npc: Node = null) -> void:
	if _mission_is_closed() or state == MissionState.TARGET_NEUTRALIZED or state == MissionState.EXTRACTING:
		return

	state = MissionState.TARGET_IDENTIFIED
	_set_objective("Target identified. Chase Korvaxi!")
	print("Target identified: %s" % target_name)
	_resolve_accused_target_npc(accused_npc)

	if _target == null:
		_target = _resolve_target()
	if _target != null:
		if _target.has_method("reveal_and_flee"):
			_target.call("reveal_and_flee")
		elif _target.has_method("set_identified"):
			_target.call("set_identified", true)


func _resolve_accused_target_npc(accused_npc: Node) -> void:
	if accused_npc == null:
		return
	if accused_npc.has_method("resolve_as_target_handoff"):
		accused_npc.call("resolve_as_target_handoff")


func _on_target_flee_started() -> void:
	if _mission_is_closed() or state == MissionState.TARGET_NEUTRALIZED or state == MissionState.EXTRACTING:
		return

	if _active_chase_route_id.is_empty():
		_set_objective("Chase Korvaxi through the courtyard")


func _on_escape_route_selected(route_id: String, cue_text: String) -> void:
	if _mission_is_closed():
		return
	_active_chase_route_id = route_id
	_set_district_state("hesperus.contract.escape_route", route_id)
	_set_objective(cue_text)
	_show_toast(cue_text, 3.2)


func _on_target_reached_final_node() -> void:
	if _mission_is_closed() or state == MissionState.TARGET_NEUTRALIZED or state == MissionState.EXTRACTING:
		return

	_set_objective("Korvaxi cornered. Shoot or stun and capture")


func _on_target_escaped(route_id: String) -> void:
	if _mission_is_closed() or state == MissionState.TARGET_NEUTRALIZED or state == MissionState.EXTRACTING:
		return
	_record_nemesis_escape()
	state = MissionState.FAILED
	_set_district_flag("hesperus.contract.active", false)
	_set_district_flag("hesperus.contract.target_escaped", true)
	_set_district_state("hesperus.contract.escape_route", route_id)
	_set_district_state("hesperus.contract.outcome", "target_escaped")
	_set_objective("Target escaped the district. Contract failed.")
	_show_toast("Korvaxi escaped via %s." % route_id.replace("_", " "), 3.5)
	print("CONTRACT FAILED: target escaped via %s." % route_id)
	if _reward_screen == null:
		_reward_screen = _resolve_reward_screen()
	if _reward_screen != null and _reward_screen.has_method("show_failure"):
		_reward_screen.call("show_failure", target_name)


func _on_target_stunned() -> void:
	if _mission_is_closed() or state == MissionState.TARGET_NEUTRALIZED or state == MissionState.EXTRACTING:
		return

	_set_objective("Korvaxi stunned. Move close and hold E.")


func _on_target_stun_expired() -> void:
	if _mission_is_closed() or state == MissionState.TARGET_NEUTRALIZED or state == MissionState.EXTRACTING:
		return

	_set_objective("Stun expired. Keep pressure on Korvaxi.")


func _mission_is_closed() -> bool:
	return state == MissionState.COMPLETE or state == MissionState.FAILED


func _set_district_flag(state_id: String, active: bool) -> void:
	var district_state := get_node_or_null("/root/DistrictState")
	if district_state != null and district_state.has_method("set_flag"):
		district_state.call("set_flag", state_id, active)


func _set_district_state(state_id: String, value: Variant) -> void:
	var district_state := get_node_or_null("/root/DistrictState")
	if district_state != null and district_state.has_method("set_state"):
		district_state.call("set_state", state_id, value)


func _restore_district_consequences() -> void:
	var district_state := get_node_or_null("/root/DistrictState")
	if district_state == null:
		return
	_district_heat = int(district_state.call("get_state", "hesperus.heat.level", 0))
	_vendors_locked_down = bool(district_state.call("has_flag", "hesperus.lockdown.active"))
	if _vendors_locked_down:
		get_tree().call_group("vendor_lockdown", "set_lockdown", "persisted district heat", true)


func _npc_was_analyzed(npc: Node) -> bool:
	var public_scanned = npc.get("is_scanned")
	if public_scanned is bool:
		return public_scanned
	var target_scanned = npc.get("_is_scanned")
	return target_scanned is bool and target_scanned


# --- Nemesis hooks ------------------------------------------------------------
# Plumbed but gated by nemesis_recording_enabled (off until the generator stamps
# targets with scanner_sig + trait_kit). Profile is assembled from BountyIntel
# (what the player actually learned) + the target node's own fields.

func _record_nemesis_escape() -> void:
	if not nemesis_recording_enabled:
		return
	var registry := get_node_or_null("/root/NemesisRegistry")
	if registry == null or not registry.has_method("record_escape"):
		return
	var profile := _build_target_profile()
	if String(profile.get("scanner_sig", "")).is_empty():
		return  # no identity key yet (pre-generator); nothing to record
	var encounter := {
		"wounded": _target_was_wounded(),
		"district_id": "hesperus_market",
	}
	registry.call("record_escape", profile, encounter)


func _clear_nemesis_if_known() -> void:
	if not nemesis_recording_enabled:
		return
	var registry := get_node_or_null("/root/NemesisRegistry")
	if registry == null or not registry.has_method("clear_nemesis"):
		return
	var sig := _target_scanner_sig()
	if not sig.is_empty():
		registry.call("clear_nemesis", sig)


func _build_target_profile() -> Dictionary:
	var intel := get_node_or_null("/root/BountyIntel")
	var appearance := {}
	var movement_tell = null
	if intel != null:
		var known_dict = intel.get("known")
		if known_dict is Dictionary:
			if known_dict.has("appearance"):
				appearance = {"palette_id": known_dict["appearance"].get("value", null), "overlay_ids": []}
			if known_dict.has("movement_tell"):
				movement_tell = known_dict["movement_tell"].get("value", null)
	return {
		"scanner_sig": _target_scanner_sig(),
		"base_id": _target_field("base_id", ""),
		"alias": target_name,
		"appearance": appearance,
		"movement_tell_id": movement_tell,
	}


func _target_scanner_sig() -> String:
	return _target_field("scanner_sig", "")


func _target_field(field: String, fallback):
	if _target == null:
		_target = _resolve_target()
	if _target != null:
		var v = _target.get(field)
		if v != null:
			return v
	return fallback


func _target_was_wounded() -> bool:
	var v = _target_field("was_wounded", null)
	return v is bool and v


func _resolve_target() -> Node:
	if target_path != NodePath():
		var assigned_target := get_node_or_null(target_path)
		if assigned_target != null:
			return assigned_target

	return get_tree().get_first_node_in_group("bounty_target")


func _resolve_reward_screen() -> Control:
	if reward_screen_path != NodePath():
		var assigned_screen := get_node_or_null(reward_screen_path)
		if assigned_screen is Control:
			return assigned_screen

	var grouped_screen := get_tree().get_first_node_in_group("reward_screen")
	if grouped_screen is Control:
		return grouped_screen

	return null


func _resolve_extraction_zone() -> Node:
	if extraction_zone_path != NodePath():
		var assigned_zone := get_node_or_null(extraction_zone_path)
		if assigned_zone != null:
			return assigned_zone

	return get_tree().get_first_node_in_group("extraction_zone")


func _activate_extraction_zone() -> void:
	if _extraction_zone == null:
		_extraction_zone = _resolve_extraction_zone()

	if _extraction_zone != null and _extraction_zone.has_method("set_active"):
		_extraction_zone.call("set_active", true)


func _deactivate_pressure_enemies() -> void:
	for enemy_path in pressure_enemies:
		var enemy := get_node_or_null(enemy_path)
		if enemy != null and not _is_sentry(enemy) and enemy.has_method("set_active"):
			enemy.call("set_active", false)

	if pressure_enemies.is_empty():
		for enemy in get_tree().get_nodes_in_group("pressure_enemy"):
			if not _is_sentry(enemy) and enemy.has_method("set_active"):
				enemy.call("set_active", false)


func _is_sentry(enemy: Node) -> bool:
	var sentry_value = enemy.get("sentry")
	return sentry_value is bool and sentry_value


func _activate_pressure_enemies() -> void:
	for enemy_path in pressure_enemies:
		var enemy := get_node_or_null(enemy_path)
		if enemy != null:
			_pressure_on(enemy)

	if pressure_enemies.is_empty():
		for enemy in get_tree().get_nodes_in_group("pressure_enemy"):
			_pressure_on(enemy)

	print("Pressure wave activated.")


func _pressure_on(enemy: Node) -> void:
	if enemy.has_method("trigger_pressure"):
		enemy.call("trigger_pressure")
	elif enemy.has_method("set_active"):
		enemy.call("set_active", true)


## Securing the bounty unlocks the south return route: gates in the
## "extraction_unlock" group sink open and stop colliding.
func _open_return_routes() -> void:
	for gate in get_tree().get_nodes_in_group("extraction_unlock"):
		if not gate is Node3D:
			continue
		for child in gate.get_children():
			if child is CollisionShape3D:
				(child as CollisionShape3D).set_deferred("disabled", true)
		var tween := create_tween()
		tween.tween_property(gate, "position:y", (gate as Node3D).position.y - 4.6, 0.9)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		print("Return gate opened: %s" % gate.name)


func _set_objective(text: String) -> void:
	if _hud == null:
		_hud = _find_hud()

	if _hud != null and _hud.has_method("set_objective"):
		_hud.call("set_objective", text)
	else:
		print("Objective: %s" % text)


func _show_toast_for_clue(clue_id: String) -> void:
	if _hud == null:
		_hud = _find_hud()
	if _hud == null or not _hud.has_method("show_toast"):
		return
	if not _clues_by_id.has(clue_id):
		return

	var clue := _clues_by_id[clue_id] as Node
	if clue == null:
		return

	var text_value = clue.get("completed_text")
	if text_value is String and not text_value.is_empty():
		_show_toast(text_value)


func _show_toast(text: String, duration: float = 2.5) -> void:
	if text.is_empty():
		return
	if _hud == null:
		_hud = _find_hud()
	if _hud != null and _hud.has_method("show_toast"):
		_hud.call("show_toast", text, duration)


func _objective_for_next_clue(clue_id: String) -> String:
	match clue_id:
		"clue_02_side_alley_residue":
			return "Trace points to the side alley. Hold RMB to scan"
		"clue_03_upper_walkway_residue":
			return "Witness trail points upward. Scan the upper walkway"
		_:
			return "Follow Korvaxi's trail to the next highlighted trace"


func _find_hud() -> CanvasLayer:
	var grouped_hud := get_tree().get_first_node_in_group("hud")
	if grouped_hud is CanvasLayer:
		return grouped_hud

	for child in get_tree().root.get_children():
		if child is CanvasLayer and child.has_method("set_objective"):
			return child

	return null


func _wait_for_hud() -> CanvasLayer:
	for _index in range(10):
		var found_hud := _find_hud()
		if found_hud != null:
			return found_hud
		await get_tree().process_frame

	return null
