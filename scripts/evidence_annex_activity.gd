extends Node3D
## Optional evidence-annex activity replacing the oversized Building15 slab.
##
## Three approaches release one impound vault:
## - public records access using courtyard credentials;
## - service bypass using the Foremarket service credential;
## - roof override reached through exterior traversal.

enum ActivityState {
	SEALED,
	OPEN,
	COMPLETE,
}

const ANNEX_ROOT := "Hesperus_BountyEvidenceAnnex"
const STATE_ROOT := "hesperus.evidence_annex"
const ROLE_ANCHORS := {
	"public_records": ["EA_PublicReader", Vector3(-0.45, 0.0, 0.0)],
	"service_bypass": ["EA_ServiceBreaker", Vector3(0.0, 0.0, 0.45)],
	"roof_override": ["EA_RoofOverride", Vector3(0.0, 0.0, 0.55)],
	"vault": ["EA_EvidenceVaultDoor", Vector3(-0.45, 0.0, 0.0)],
}

var state: ActivityState = ActivityState.SEALED
var solution_used := ""


func _ready() -> void:
	call_deferred("_bind_to_annex")


func get_prompt(role: String) -> String:
	match role:
		"public_records":
			return "Records terminal: authorized" if state != ActivityState.SEALED else "Press E: Request impound record"
		"service_bypass":
			return "Vault service feed: bypassed" if state != ActivityState.SEALED else "Press E: Bypass evidence-vault feed"
		"roof_override":
			return "Roof release: triggered" if state != ActivityState.SEALED else "Press E: Trigger roof vault release"
		"vault":
			if state == ActivityState.OPEN:
				return "Press E: Recover Korvaxi evidence file"
			if state == ActivityState.COMPLETE:
				return ""
			return "Evidence vault: sealed"
	return ""


func interact(role: String, player: Node) -> void:
	match role:
		"public_records":
			_use_public_records(player)
		"service_bypass":
			_use_service_bypass(player)
		"roof_override":
			_unlock("roof override")
		"vault":
			_claim_vault(player)


func _use_public_records(player: Node) -> void:
	if not _player_has_access(player, "courtyard_service"):
		_toast("Impound records require courtyard service credentials.", 3.0)
		return
	_unlock("public records")


func _use_service_bypass(player: Node) -> void:
	if not _player_has_access(player, "foremarket_service"):
		_toast("The evidence feed requires a Foremarket service authorization.", 3.0)
		return
	_unlock("service bypass")


func _unlock(method: String) -> void:
	if state == ActivityState.COMPLETE:
		return
	if state == ActivityState.OPEN:
		_toast("The evidence vault is already released.", 2.0)
		return
	state = ActivityState.OPEN
	solution_used = method
	_set_value("%s.state" % STATE_ROOT, state)
	_set_value("%s.solution" % STATE_ROOT, solution_used)
	_move_imported_mesh("EA_EvidenceVaultDoor", Vector3(0.0, -3.6, 0.0))
	_set_imported_glow("EA_EvidenceVaultGlow", Color(0.05, 1.0, 0.3, 1.0))
	_toast("Evidence vault released via %s. Recover the impound file." % method, 3.4)


func _claim_vault(player: Node) -> void:
	if state == ActivityState.COMPLETE:
		return
	if state != ActivityState.OPEN:
		_toast("The impound vault is still sealed. Records, service access, or the roof release can open it.", 3.5)
		return
	state = ActivityState.COMPLETE
	_set_value("%s.state" % STATE_ROOT, state)
	var intel := get_node_or_null("/root/BountyIntel")
	if intel != null and intel.has_method("learn"):
		intel.call("learn", "build", "korvaxi-class heavy", "impound biometric record")
	var ledger := get_node_or_null("/root/HunterLedger")
	if ledger != null and ledger.has_method("add"):
		ledger.call("add", 300)
	if player != null and player.has_method("grant_credential"):
		player.call("grant_credential", "utility")
	_disable_role("vault")
	_set_imported_glow("EA_EvidenceVaultGlow", Color(0.04, 0.22, 0.1, 1.0))
	_toast("Evidence recovered: Korvaxi build confirmed, 300 CR, utility access issued.", 4.2)


func _bind_to_annex() -> void:
	var annex := _get_annex()
	if annex == null:
		push_warning("Evidence Annex activity could not find %s." % ANNEX_ROOT)
		return
	for role_name: String in ROLE_ANCHORS:
		var role_node := _find_role_node(role_name)
		var anchor_data: Array = ROLE_ANCHORS[role_name]
		var anchor := _find_imported_mesh(annex, anchor_data[0])
		if role_node != null and anchor != null:
			role_node.global_position = anchor.global_position + anchor.global_basis * (anchor_data[1] as Vector3)
	var ladder := get_node_or_null("RoofLadderZone") as Node3D
	var ladder_anchor := _find_imported_mesh(annex, "EA_RoofLadderAnchor")
	if ladder != null and ladder_anchor != null:
		ladder.global_position = ladder_anchor.global_position + Vector3(0.0, 4.1, 0.0)
	_set_imported_glow("EA_EvidenceVaultGlow", Color(0.72, 0.04, 0.38, 1.0))
	_restore_persistent_state()


func _restore_persistent_state() -> void:
	var district_state := get_node_or_null("/root/DistrictState")
	if district_state == null:
		return
	state = int(district_state.call("get_state", "%s.state" % STATE_ROOT, state))
	solution_used = String(district_state.call("get_state", "%s.solution" % STATE_ROOT, solution_used))
	if state >= ActivityState.OPEN:
		_move_imported_mesh("EA_EvidenceVaultDoor", Vector3(0.0, -3.6, 0.0))
	if state == ActivityState.COMPLETE:
		_disable_role("vault")
		_set_imported_glow("EA_EvidenceVaultGlow", Color(0.04, 0.22, 0.1, 1.0))


func _set_value(state_id: String, value: Variant) -> void:
	var district_state := get_node_or_null("/root/DistrictState")
	if district_state != null:
		district_state.call("set_state", state_id, value)


func _player_has_access(player: Node, access_tag: String) -> bool:
	return player != null and player.has_method("has_access_tag") and player.call("has_access_tag", access_tag)


func _find_role_node(role_name: String) -> Node3D:
	for node in get_children():
		if node is StaticBody3D and node.get("role") == role_name:
			return node as Node3D
	return null


func _get_annex() -> Node3D:
	var scene_root := _get_scene_root()
	if scene_root == null:
		return null
	return scene_root.get_node_or_null(ANNEX_ROOT) as Node3D


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


func _find_imported_mesh(annex: Node3D, mesh_name: String) -> MeshInstance3D:
	var matches := annex.find_children(mesh_name, "MeshInstance3D", true, false)
	return null if matches.is_empty() else matches[0] as MeshInstance3D


func _move_imported_mesh(mesh_name: String, offset: Vector3) -> void:
	var annex := _get_annex()
	if annex == null:
		return
	var mesh := _find_imported_mesh(annex, mesh_name)
	if mesh != null:
		create_tween().tween_property(mesh, "position", mesh.position + offset, 0.8)


func _set_imported_glow(mesh_name: String, color: Color) -> void:
	var annex := _get_annex()
	if annex == null:
		return
	var mesh := _find_imported_mesh(annex, mesh_name)
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
	print("Evidence Annex: %s" % text)
