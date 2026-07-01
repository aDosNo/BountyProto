extends Node3D
## Optional immersive-sim activity for the Courtyard Foremarket.
##
## Three solutions unlock the clinic cold locker:
## - recover a maintenance fuse and repair the street relay;
## - present the courtyard courier credential at the clinic reader;
## - climb the fire escape and use the roof override.

enum QuestState {
	AVAILABLE,
	ACTIVE,
	LOCKER_OPEN,
	COMPLETE,
}

var state: QuestState = QuestState.AVAILABLE
var has_maintenance_fuse := false
var solution_used := ""

const FOREMARKET_ROOT := "Hesperus_CourtyardForemarket"
const STATE_ROOT := "hesperus.foremarket.cold_chain"
const ROLE_ANCHORS := {
	"intake": {
		"mesh": "FM_ClinicDoorFrame",
		"offset": Vector3(-1.9, -1.25, -0.75),
	},
	"relay": {
		"mesh": "FM_StreetRelay",
		"offset": Vector3(0.0, 0.0, -0.5),
	},
	"credential": {
		"mesh": "FM_ClinicDoorFrame",
		"offset": Vector3(-0.9, -0.9, -0.75),
	},
	"roof_override": {
		"mesh": "FM_RoofOverride",
		"offset": Vector3(0.0, 0.0, -0.45),
	},
	"locker": {
		"mesh": "FM_ColdLocker",
		"offset": Vector3(0.0, 0.0, -0.55),
	},
	"fuse": {
		"mesh": "FM_ServicePassage_Floor",
		"offset": Vector3(-5.0, 1.0, 0.0),
	},
}


func _ready() -> void:
	call_deferred("_bind_activity_to_foremarket")


func get_prompt(role: String) -> String:
	match role:
		"intake":
			if state == QuestState.AVAILABLE:
				return "Press E: Read clinic emergency request"
			if state == QuestState.ACTIVE:
				return "Cold Chain: unlock the medicine locker"
			if state == QuestState.LOCKER_OPEN:
				return "Cold Chain: retrieve the medicine"
			return "Clinic request resolved"
		"fuse":
			return "" if has_maintenance_fuse or state == QuestState.COMPLETE else "Press E: Take maintenance fuse"
		"relay":
			if state == QuestState.LOCKER_OPEN or state == QuestState.COMPLETE:
				return "Clinic relay: stable"
			return "Press E: Repair clinic relay"
		"credential":
			if state == QuestState.LOCKER_OPEN or state == QuestState.COMPLETE:
				return "Clinic access reader: authorized"
			return "Press E: Present courier credential"
		"roof_override":
			if state == QuestState.LOCKER_OPEN or state == QuestState.COMPLETE:
				return "Roof override: released"
			return "Press E: Trigger clinic roof override"
		"locker":
			if state == QuestState.LOCKER_OPEN:
				return "Press E: Recover temperature-sensitive medicine"
			if state == QuestState.COMPLETE:
				return ""
			return "Medicine locker: sealed"
	return ""


func interact(role: String, player: Node) -> void:
	match role:
		"intake":
			_start()
		"fuse":
			_take_fuse()
		"relay":
			_use_relay()
		"credential":
			_use_credential(player)
		"roof_override":
			_unlock("roof override")
		"locker":
			_claim_locker(player)


func _start() -> void:
	if state == QuestState.AVAILABLE:
		state = QuestState.ACTIVE
		_save_state()
		_toast("Optional: COLD CHAIN — recover the clinic medicine. Relay, credential, or roof access.", 4.5)
	elif state == QuestState.ACTIVE:
		_toast("The medicine locker accepts utility power, courier authorization, or its roof override.", 3.5)


func _take_fuse() -> void:
	if has_maintenance_fuse or state == QuestState.COMPLETE:
		return
	_start()
	has_maintenance_fuse = true
	_save_state()
	_set_imported_glow("FM_StreetRelayGlow", Color(1.0, 0.48, 0.08, 1.0))
	_toast("Maintenance fuse acquired. The clinic relay is back near the street entrance.", 3.2)
	_disable_role("fuse")


func _use_relay() -> void:
	_start()
	if not has_maintenance_fuse:
		_toast("Relay fuse is burned out. Maintenance stores use the north service passage.", 3.2)
		return
	_unlock("utility repair")


func _use_credential(player: Node) -> void:
	_start()
	if player == null or not player.has_method("has_access_tag") or not player.call("has_access_tag", "courtyard_service"):
		_toast("Courier-grade courtyard credentials required.", 2.8)
		return
	_unlock("courier credential")


func _unlock(method: String) -> void:
	if state == QuestState.COMPLETE:
		return
	if state == QuestState.LOCKER_OPEN:
		_toast("Medicine locker is already released.", 2.0)
		return
	state = QuestState.LOCKER_OPEN
	solution_used = method
	_save_state()
	_open_imported_clinic_door()
	_set_imported_glow("FM_ColdLockerGlow", Color(0.05, 1.0, 0.32, 1.0))
	_mark_solution_used(method)
	_toast("Clinic locker released via %s. Recover the medicine." % method, 3.2)


func _claim_locker(player: Node) -> void:
	if state == QuestState.COMPLETE:
		return
	if state != QuestState.LOCKER_OPEN:
		_start()
		_toast("The cold locker is still sealed. Find another way to release it.", 3.0)
		return
	state = QuestState.COMPLETE
	_save_state()
	if player != null and player.has_method("grant_credential"):
		player.call("grant_credential", "foremarket_service")
		player.call("grant_credential", "courtyard_service")
	var intel := get_node_or_null("/root/BountyIntel")
	if intel != null and intel.has_method("learn"):
		intel.call("learn", "scanner_signature", "cybernetic arm", "foremarket clinic implant log")
	var ledger := get_node_or_null("/root/HunterLedger")
	if ledger != null and ledger.has_method("add"):
		ledger.call("add", 350)
	_disable_role("locker")
	_set_imported_glow("FM_ColdLockerGlow", Color(0.04, 0.24, 0.12, 1.0))
	_toast("Cold Chain complete: medicine secured, 350 CR, courtyard service access, and implant intel recovered.", 4.5)


func _disable_role(role: String) -> void:
	for node in get_children():
		if node is StaticBody3D and node.get("role") == role:
			node.visible = false
			var collision := node.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if collision != null:
				collision.set_deferred("disabled", true)


func _open_imported_clinic_door() -> void:
	var foremarket := _get_foremarket()
	if foremarket == null:
		return
	var matches := foremarket.find_children("FM_ClinicDoor", "MeshInstance3D", true, false)
	if not matches.is_empty():
		var door := matches[0] as MeshInstance3D
		var tween := create_tween()
		tween.tween_property(door, "position:y", door.position.y - 4.4, 0.8)


func _bind_activity_to_foremarket() -> void:
	var foremarket := _get_foremarket()
	if foremarket == null:
		push_warning("Foremarket Cold Chain could not find %s." % FOREMARKET_ROOT)
		return

	for role_name: String in ROLE_ANCHORS:
		var role_node := _find_role_node(role_name)
		if role_node == null:
			continue
		var anchor_data: Dictionary = ROLE_ANCHORS[role_name]
		var anchor := _find_imported_mesh(foremarket, anchor_data["mesh"])
		if anchor == null:
			push_warning("Foremarket Cold Chain is missing geometry anchor %s." % anchor_data["mesh"])
			continue
		var anchor_offset: Vector3 = anchor_data["offset"]
		role_node.global_position = anchor.global_position + anchor.global_basis * anchor_offset

	var ladder := get_node_or_null("FireEscapeLadderZone") as Node3D
	var ladder_anchor := _find_imported_mesh(foremarket, "FM_FireEscapeStep_00")
	if ladder != null and ladder_anchor != null:
		ladder.global_position = ladder_anchor.global_position + Vector3(0.0, 4.0, 0.0)

	_set_imported_glow("FM_ColdLockerGlow", Color(0.08, 0.42, 0.62, 1.0))
	_set_imported_glow("FM_StreetRelayGlow", Color(0.55, 0.08, 0.12, 1.0))
	_set_imported_glow("FM_RoofOverrideGlow", Color(0.16, 0.58, 0.22, 1.0))
	_restore_persistent_state()


func _save_state() -> void:
	var district_state := get_node_or_null("/root/DistrictState")
	if district_state == null:
		return
	district_state.call("set_state", "%s.state" % STATE_ROOT, state)
	district_state.call("set_state", "%s.has_fuse" % STATE_ROOT, has_maintenance_fuse)
	district_state.call("set_state", "%s.solution" % STATE_ROOT, solution_used)


func _restore_persistent_state() -> void:
	var district_state := get_node_or_null("/root/DistrictState")
	if district_state == null:
		return
	state = int(district_state.call("get_state", "%s.state" % STATE_ROOT, state))
	has_maintenance_fuse = bool(district_state.call("get_state", "%s.has_fuse" % STATE_ROOT, false))
	solution_used = String(district_state.call("get_state", "%s.solution" % STATE_ROOT, solution_used))
	if has_maintenance_fuse:
		_disable_role("fuse")
	if state >= QuestState.LOCKER_OPEN:
		_open_imported_clinic_door()
		_mark_solution_used(solution_used)
	if state == QuestState.COMPLETE:
		_disable_role("locker")
		_set_imported_glow("FM_ColdLockerGlow", Color(0.04, 0.24, 0.12, 1.0))


func _find_role_node(role_name: String) -> Node3D:
	for node in get_children():
		if node is StaticBody3D and node.get("role") == role_name:
			return node as Node3D
	return null


func _get_foremarket() -> Node3D:
	var scene_root := _get_scene_root()
	if scene_root == null:
		return null
	return scene_root.get_node_or_null(FOREMARKET_ROOT) as Node3D


func _get_scene_root() -> Node:
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		return tree.current_scene
	if owner != null:
		return owner
	var node := get_parent()
	while node != null:
		if tree != null and node.get_parent() == tree.root:
			return node
		if node.get_parent() == null:
			return node
		node = node.get_parent()
	return null


func _find_imported_mesh(foremarket: Node3D, mesh_name: String) -> MeshInstance3D:
	var matches := foremarket.find_children(mesh_name, "MeshInstance3D", true, false)
	if matches.is_empty():
		return null
	return matches[0] as MeshInstance3D


func _set_imported_glow(mesh_name: String, color: Color) -> void:
	var foremarket := _get_foremarket()
	if foremarket == null:
		return
	var glow := _find_imported_mesh(foremarket, mesh_name)
	if glow == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.58)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.4
	glow.material_override = material


func _mark_solution_used(method: String) -> void:
	match method:
		"utility repair":
			_set_imported_glow("FM_StreetRelayGlow", Color(0.05, 1.0, 0.32, 1.0))
			_disable_role("relay")
		"courier credential":
			_disable_role("credential")
		"roof override":
			_set_imported_glow("FM_RoofOverrideGlow", Color(0.05, 1.0, 0.32, 1.0))
			_disable_role("roof_override")


func _toast(text: String, duration: float) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", text, duration)
	print("Foremarket Cold Chain: %s" % text)
