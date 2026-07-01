extends Node3D
## South-band freight yard occupying the former Building21 slab footprint.
##
## Three approaches authorize the dispatch console:
## - social: courtyard/foremarket service credentials at the manifest booth;
## - systemic: utility credentials at the cargo-scanner bypass;
## - vertical: climb the inspection tower and trigger its local override.
##
## Committing the dispatch plan changes extraction: the additional yard
## pressure guard is suppressed and a suspended container lowers into cover.

enum ActivityState {
	SEALED,
	AUTHORIZED,
	PREPARED,
}

const YARD_ROOT := "Hesperus_FreightInspectionYard"
const STATE_ROOT := "hesperus.freight_yard"
const ROLE_ANCHORS := {
	"manifest": ["FY_ManifestReader", Vector3(-0.45, 0.0, 0.0)],
	"scanner_bypass": ["FY_ScannerBypass", Vector3(0.0, 0.0, 0.45)],
	"tower_override": ["FY_TowerOverride", Vector3(0.0, 0.0, 0.55)],
	"dispatch": ["FY_DispatchConsole", Vector3(-0.45, 0.0, 0.0)],
}

var state: ActivityState = ActivityState.SEALED
var solution_used := ""


func _ready() -> void:
	add_to_group("extraction_modifier")
	call_deferred("_bind_to_yard")


func get_prompt(role: String) -> String:
	match role:
		"manifest":
			if state != ActivityState.SEALED:
				return "Manifest accepted"
			return "Press E: Submit courier freight manifest"
		"scanner_bypass":
			if state != ActivityState.SEALED:
				return "Cargo scanner: bypassed"
			return "Press E: Bypass cargo scanner"
		"tower_override":
			if state != ActivityState.SEALED:
				return "Inspection tower: overridden"
			return "Press E: Override freight inspection"
		"dispatch":
			if state == ActivityState.AUTHORIZED:
				return "Press E: Schedule quiet extraction freight"
			if state == ActivityState.PREPARED:
				return "Quiet freight route: scheduled"
			return "Dispatch console: inspection authorization required"
	return ""


func interact(role: String, player: Node) -> void:
	match role:
		"manifest":
			_use_manifest(player)
		"scanner_bypass":
			_use_scanner_bypass(player)
		"tower_override":
			_authorize("tower override")
		"dispatch":
			_commit_dispatch(player)


func apply_extraction_modifier() -> void:
	if state != ActivityState.PREPARED:
		return
	var pressure_guard := get_node_or_null("YardExtractionGuard")
	if pressure_guard != null and pressure_guard.has_method("set_active"):
		pressure_guard.call("set_active", false)
	_lower_cover_container()
	_set_imported_glow("FY_RouteStatusGlow", Color(0.05, 1.0, 0.28, 1.0))
	_toast("Freight plan active: yard reinforcement diverted and container cover deployed.", 4.0)


func _use_manifest(player: Node) -> void:
	if not (_player_has_access(player, "courtyard_service") or _player_has_access(player, "foremarket_service")):
		_toast("Dispatch rejects the manifest. Courtyard courier authorization required.", 3.0)
		return
	_authorize("courier manifest")


func _use_scanner_bypass(player: Node) -> void:
	if not _player_has_access(player, "utility"):
		_toast("Cargo scanner housing requires utility access.", 2.8)
		return
	_authorize("scanner bypass")


func _authorize(method: String) -> void:
	if state == ActivityState.PREPARED:
		return
	if state == ActivityState.AUTHORIZED:
		_toast("Inspection is already cleared. Confirm the route at dispatch.", 2.5)
		return
	state = ActivityState.AUTHORIZED
	solution_used = method
	_save_state()
	_raise_scanner_arms()
	_open_yard_gate()
	_set_imported_glow("FY_DispatchGlow", Color(0.05, 1.0, 0.3, 1.0))
	_toast("Freight inspection cleared via %s. Confirm the quiet route at dispatch." % method, 3.6)


func _commit_dispatch(player: Node) -> void:
	if state == ActivityState.PREPARED:
		_toast("Quiet freight extraction is already scheduled.", 2.2)
		return
	if state != ActivityState.AUTHORIZED:
		_toast("Dispatch is locked until inspection is cleared.", 2.7)
		return
	state = ActivityState.PREPARED
	_save_state()
	if player != null and player.has_method("grant_credential"):
		player.call("grant_credential", "freight_dispatch")
	var ledger := get_node_or_null("/root/HunterLedger")
	if ledger != null and ledger.has_method("add"):
		ledger.call("add", 200)
	_set_imported_glow("FY_RouteStatusGlow", Color(0.1, 0.82, 1.0, 1.0))
	_disable_role("dispatch")
	_toast("Quiet extraction freight scheduled: 200 CR advance and reduced yard pressure.", 4.0)


func _bind_to_yard() -> void:
	var yard := _get_yard()
	if yard == null:
		push_warning("Freight Inspection Yard could not find %s." % YARD_ROOT)
		return
	for role_name: String in ROLE_ANCHORS:
		var role_node := _find_role_node(role_name)
		var anchor_data: Array = ROLE_ANCHORS[role_name]
		var anchor := _find_imported_mesh(yard, anchor_data[0])
		if role_node != null and anchor != null:
			role_node.global_position = anchor.global_position + anchor.global_basis * (anchor_data[1] as Vector3)

	var ladder := get_node_or_null("TowerLadderZone") as Node3D
	var ladder_anchor := _find_imported_mesh(yard, "FY_TowerLadderAnchor")
	if ladder != null and ladder_anchor != null:
		ladder.global_position = ladder_anchor.global_position + Vector3(0.0, 4.2, 0.0)

	var inspector := get_node_or_null("YardInspector") as Node3D
	var inspector_anchor := _find_imported_mesh(yard, "FY_InspectorPost")
	if inspector != null and inspector_anchor != null:
		inspector.global_position = inspector_anchor.global_position

	var extraction_guard := get_node_or_null("YardExtractionGuard") as Node3D
	var guard_anchor := _find_imported_mesh(yard, "FY_ExtractionGuardPost")
	if extraction_guard != null and guard_anchor != null:
		extraction_guard.global_position = guard_anchor.global_position

	_set_imported_glow("FY_DispatchGlow", Color(0.68, 0.04, 0.34, 1.0))
	_set_imported_glow("FY_RouteStatusGlow", Color(0.75, 0.22, 0.04, 1.0))
	_restore_persistent_state()


func _save_state() -> void:
	var district_state := get_node_or_null("/root/DistrictState")
	if district_state == null:
		return
	district_state.call("set_state", "%s.state" % STATE_ROOT, state)
	district_state.call("set_state", "%s.solution" % STATE_ROOT, solution_used)
	district_state.call("set_flag", "hesperus.extraction.freight_prepared", state == ActivityState.PREPARED)


func _restore_persistent_state() -> void:
	var district_state := get_node_or_null("/root/DistrictState")
	if district_state == null:
		return
	state = int(district_state.call("get_state", "%s.state" % STATE_ROOT, state))
	solution_used = String(district_state.call("get_state", "%s.solution" % STATE_ROOT, solution_used))
	if state >= ActivityState.AUTHORIZED:
		_raise_scanner_arms()
		_open_yard_gate()
		_set_imported_glow("FY_DispatchGlow", Color(0.05, 1.0, 0.3, 1.0))
	if state == ActivityState.PREPARED:
		_disable_role("dispatch")
		_set_imported_glow("FY_RouteStatusGlow", Color(0.1, 0.82, 1.0, 1.0))


func _raise_scanner_arms() -> void:
	for mesh_name in ["FY_ScannerArm_A", "FY_ScannerArm_B"]:
		_move_imported_mesh(mesh_name, Vector3(0.0, 3.4, 0.0), 0.65)


func _open_yard_gate() -> void:
	for mesh_name in ["FY_OutboundGate_L", "FY_OutboundGate_R"]:
		var direction := -1.0 if mesh_name.ends_with("_L") else 1.0
		_move_imported_mesh(mesh_name, Vector3(direction * 2.6, 0.0, 0.0), 0.7)


func _lower_cover_container() -> void:
	_move_imported_mesh("FY_SuspendedCoverContainer", Vector3(0.0, -5.5, 0.0), 1.0)


func _player_has_access(player: Node, access_tag: String) -> bool:
	return player != null and player.has_method("has_access_tag") and player.call("has_access_tag", access_tag)


func _find_role_node(role_name: String) -> Node3D:
	for node in get_children():
		if node is StaticBody3D and node.get("role") == role_name:
			return node as Node3D
	return null


func _get_yard() -> Node3D:
	var scene_root := _get_scene_root()
	if scene_root == null:
		return null
	return scene_root.get_node_or_null(YARD_ROOT) as Node3D


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


func _find_imported_mesh(yard: Node3D, mesh_name: String) -> MeshInstance3D:
	var matches := yard.find_children(mesh_name, "MeshInstance3D", true, false)
	return null if matches.is_empty() else matches[0] as MeshInstance3D


func _move_imported_mesh(mesh_name: String, offset: Vector3, duration: float) -> void:
	var yard := _get_yard()
	if yard == null:
		return
	var mesh := _find_imported_mesh(yard, mesh_name)
	if mesh != null:
		create_tween().tween_property(mesh, "position", mesh.position + offset, duration)


func _set_imported_glow(mesh_name: String, color: Color) -> void:
	var yard := _get_yard()
	if yard == null:
		return
	var mesh := _find_imported_mesh(yard, mesh_name)
	if mesh == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.6)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.5
	mesh.material_override = material


func _disable_role(role: String) -> void:
	for node in get_children():
		if node is StaticBody3D and node.get("role") == role:
			node.visible = false
			var collision := node.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if collision != null:
				collision.set_deferred("disabled", true)


func _toast(text: String, duration: float) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", text, duration)
	print("Freight Inspection Yard: %s" % text)
