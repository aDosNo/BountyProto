extends Node3D
## Optional bazaar safehouse occupying the former Building24 placeholder.
##
## Three approaches release one hunter cache:
## - vendor-staff authorization at the street broker terminal;
## - utility access at the rear service bypass;
## - an exposed roof override reached by ladder.
##
## District heat closes the street shutters. That removes the easy broker
## approach while leaving the service and vertical routes available.

enum ActivityState {
	SEALED,
	OPEN,
	COMPLETE,
}

const SAFEHOUSE_ROOT := "Hesperus_BazaarSafehouse"
const STATE_ROOT := "hesperus.safehouse"
const ROLE_ANCHORS := {
	"broker": ["BS_BrokerReader", Vector3(-0.45, 0.0, 0.0)],
	"service_bypass": ["BS_ServiceBypass", Vector3(0.0, 0.0, 0.45)],
	"roof_override": ["BS_RoofOverride", Vector3(0.0, 0.0, 0.55)],
	"cache": ["BS_HunterCacheDoor", Vector3(-0.45, 0.0, 0.0)],
}

var state: ActivityState = ActivityState.SEALED
var solution_used := ""
var locked_down := false


func _ready() -> void:
	add_to_group("vendor_lockdown")
	call_deferred("_bind_to_safehouse")


func get_prompt(role: String) -> String:
	match role:
		"broker":
			if state != ActivityState.SEALED:
				return "Broker terminal: cache released"
			if locked_down:
				return "Broker terminal: sealed behind emergency shutters"
			return "Press E: Present vendor-staff authorization"
		"service_bypass":
			return "Safehouse service feed: bypassed" if state != ActivityState.SEALED else "Press E: Bypass safehouse service feed"
		"roof_override":
			return "Roof release: triggered" if state != ActivityState.SEALED else "Press E: Trigger roof cache release"
		"cache":
			if state == ActivityState.OPEN:
				return "Press E: Recover hunter dead-drop"
			if state == ActivityState.COMPLETE:
				return ""
			return "Hunter cache: sealed"
	return ""


func interact(role: String, player: Node) -> void:
	match role:
		"broker":
			_use_broker(player)
		"service_bypass":
			_use_service_bypass(player)
		"roof_override":
			_unlock("roof override")
		"cache":
			_claim_cache(player)


func set_lockdown(reason: String = "", quiet: bool = false) -> void:
	if locked_down:
		return
	locked_down = true
	_set_flag("%s.lockdown" % STATE_ROOT, true)
	for shutter_name in ["BS_StreetShutter_A", "BS_StreetShutter_B"]:
		_move_imported_mesh(shutter_name, Vector3(0.0, -3.2, 0.0), 0.32)
	_set_imported_glow("BS_BrokerGlow", Color(0.92, 0.05, 0.02, 1.0))
	if not quiet:
		_toast("Bazaar shutters dropping. The safehouse street entrance is sealed.", 3.2)
	print("Bazaar Safehouse lockdown: %s" % reason)


func _use_broker(player: Node) -> void:
	if locked_down:
		_toast("Emergency shutters cut off the broker terminal. Find a service or roof route.", 3.2)
		return
	if not _player_has_access(player, "vendor_staff"):
		_toast("The broker terminal requires vendor-staff authorization.", 2.8)
		return
	_unlock("vendor authorization")


func _use_service_bypass(player: Node) -> void:
	if not _player_has_access(player, "utility"):
		_toast("The safehouse service feed requires utility access.", 2.8)
		return
	_unlock("utility bypass")


func _unlock(method: String) -> void:
	if state == ActivityState.COMPLETE:
		return
	if state == ActivityState.OPEN:
		_toast("The hunter cache is already released.", 2.0)
		return
	state = ActivityState.OPEN
	solution_used = method
	_set_value("%s.state" % STATE_ROOT, state)
	_set_value("%s.solution" % STATE_ROOT, solution_used)
	_move_imported_mesh("BS_HunterCacheDoor", Vector3(0.0, -2.8, 0.0), 0.7)
	_set_imported_glow("BS_CacheGlow", Color(0.05, 1.0, 0.32, 1.0))
	_toast("Hunter cache released via %s. Recover the dead-drop." % method, 3.2)


func _claim_cache(player: Node) -> void:
	if state == ActivityState.COMPLETE:
		return
	if state != ActivityState.OPEN:
		_toast("The dead-drop is still sealed. Use vendor access, utilities, or the roof release.", 3.4)
		return
	state = ActivityState.COMPLETE
	_set_value("%s.state" % STATE_ROOT, state)
	var intel := get_node_or_null("/root/BountyIntel")
	if intel != null and intel.has_method("learn"):
		intel.call("learn", "movement_tell", "heavy gait", "safehouse pursuit ledger")
	var ledger := get_node_or_null("/root/HunterLedger")
	if ledger != null and ledger.has_method("add"):
		ledger.call("add", 250)
	if player != null and player.has_method("grant_credential"):
		player.call("grant_credential", "vendor_staff")
	_disable_role("cache")
	_set_imported_glow("BS_CacheGlow", Color(0.04, 0.22, 0.1, 1.0))
	_toast("Dead-drop recovered: heavy-gait intel, 250 CR, and vendor-staff access.", 4.2)


func _bind_to_safehouse() -> void:
	var safehouse := _get_safehouse()
	if safehouse == null:
		push_warning("Bazaar Safehouse activity could not find %s." % SAFEHOUSE_ROOT)
		return
	for role_name: String in ROLE_ANCHORS:
		var role_node := _find_role_node(role_name)
		var anchor_data: Array = ROLE_ANCHORS[role_name]
		var anchor := _find_imported_mesh(safehouse, anchor_data[0])
		if role_node != null and anchor != null:
			role_node.global_position = anchor.global_position + anchor.global_basis * (anchor_data[1] as Vector3)
	var ladder := get_node_or_null("RoofLadderZone") as Node3D
	var ladder_anchor := _find_imported_mesh(safehouse, "BS_RoofLadderAnchor")
	if ladder != null and ladder_anchor != null:
		ladder.global_position = ladder_anchor.global_position + Vector3(0.0, 4.1, 0.0)
	_set_imported_glow("BS_CacheGlow", Color(0.68, 0.04, 0.34, 1.0))
	_set_imported_glow("BS_BrokerGlow", Color(0.04, 0.62, 0.8, 1.0))
	_restore_persistent_state()


func _restore_persistent_state() -> void:
	var district_state := get_node_or_null("/root/DistrictState")
	if district_state == null:
		return
	state = int(district_state.call("get_state", "%s.state" % STATE_ROOT, state))
	solution_used = String(district_state.call("get_state", "%s.solution" % STATE_ROOT, solution_used))
	locked_down = bool(district_state.call("get_state", "%s.lockdown" % STATE_ROOT, false))
	if locked_down:
		for shutter_name in ["BS_StreetShutter_A", "BS_StreetShutter_B"]:
			_move_imported_mesh(shutter_name, Vector3(0.0, -3.2, 0.0), 0.01)
		_set_imported_glow("BS_BrokerGlow", Color(0.92, 0.05, 0.02, 1.0))
	if state >= ActivityState.OPEN:
		_move_imported_mesh("BS_HunterCacheDoor", Vector3(0.0, -2.8, 0.0), 0.01)
	if state == ActivityState.COMPLETE:
		_disable_role("cache")
		_set_imported_glow("BS_CacheGlow", Color(0.04, 0.22, 0.1, 1.0))


func _set_flag(state_id: String, active: bool) -> void:
	var district_state := get_node_or_null("/root/DistrictState")
	if district_state != null:
		district_state.call("set_flag", state_id, active)


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


func _get_safehouse() -> Node3D:
	var scene_root := _get_scene_root()
	if scene_root == null:
		return null
	return scene_root.get_node_or_null(SAFEHOUSE_ROOT) as Node3D


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


func _find_imported_mesh(safehouse: Node3D, mesh_name: String) -> MeshInstance3D:
	var matches := safehouse.find_children(mesh_name, "MeshInstance3D", true, false)
	return null if matches.is_empty() else matches[0] as MeshInstance3D


func _move_imported_mesh(mesh_name: String, offset: Vector3, duration: float) -> void:
	var safehouse := _get_safehouse()
	if safehouse == null:
		return
	var mesh := _find_imported_mesh(safehouse, mesh_name)
	if mesh != null:
		create_tween().tween_property(mesh, "position", mesh.position + offset, duration)


func _set_imported_glow(mesh_name: String, color: Color) -> void:
	var safehouse := _get_safehouse()
	if safehouse == null:
		return
	var mesh := _find_imported_mesh(safehouse, mesh_name)
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
	print("Bazaar Safehouse: %s" % text)
