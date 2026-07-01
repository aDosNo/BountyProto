extends Node3D
## Contract-facing activity layer for the player-facing North Arcade.
## Each tenant changes a different system rather than opening one shared cache.

const ARCADE_ROOT := "Hesperus_AlienBar_CommercialArcade"
const CANTINA_ROOT := "HoloCantina"
const STATE_ROOT := "hesperus.arcade"
const INTERACTABLE := preload("res://scripts/arcade_interactable.gd")

const ROLE_ANCHORS := {
	"bar": [CANTINA_ROOT, "HC_GAMEPLAY_BAR_CONTACT", Vector3.ZERO],
	"pawn": [ARCADE_ROOT, "ABA_PawnCounter", Vector3(0.0, 0.8, -0.8)],
	"clinic": [ARCADE_ROOT, "ABA_ClinicDesk", Vector3(0.0, 0.8, -0.8)],
	"motel": [ARCADE_ROOT, "ABA_UpperOfficeDesk", Vector3(0.0, 0.8, -0.7)],
	"service": [ARCADE_ROOT, "ABA_RearServiceWalk", Vector3(0.0, 0.8, 0.0)],
}


func _ready() -> void:
	call_deferred("_bind")


func get_prompt(role: String) -> String:
	if _done(role):
		match role:
			"bar": return "Bar contact: meeting arranged"
			"pawn": return "Pawn records: recovered"
			"clinic": return "Implant relay: disrupted"
			"motel": return "Motel roof access: authorized"
			"service": return "Arcade service circuit: bypassed"
	match role:
		"bar": return "Press E: Pay the bartender for Korvaxi's schedule"
		"pawn": return "Press E: Search pawn records for Korvaxi's gear"
		"clinic": return "Press E: Sabotage Korvaxi's implant relay"
		"motel": return "Press E: Override motel roof authorization"
		"service": return "Press E: Cut the arcade service circuit"
	return ""


func interact(role: String, player: Node) -> void:
	if _done(role):
		return
	match role:
		"bar":
			_use_bar()
		"pawn":
			_use_pawn(player)
		"clinic":
			_use_clinic()
		"motel":
			_use_motel()
		"service":
			_use_service()


func _use_bar() -> void:
	var ledger := get_node_or_null("/root/HunterLedger")
	if ledger == null or not ledger.has_method("spend") or not bool(ledger.call("spend", 300)):
		_toast("The bartender wants 300 CR for Korvaxi's schedule.", 2.8)
		return
	_complete("bar")
	_set_flag("hesperus.target.meeting_scheduled", true)
	_schedule_target_meeting()
	var intel := get_node_or_null("/root/BountyIntel")
	if intel != null:
		intel.call("learn", "location_habit", "courtyard", "North Arcade meeting schedule")
	_toast("Meeting scheduled: Korvaxi will expose himself near the north service street.", 3.8)


func _use_pawn(player: Node) -> void:
	_complete("pawn")
	if player != null and player.has_method("grant_credential"):
		player.call("grant_credential", "vendor_staff")
	var intel := get_node_or_null("/root/BountyIntel")
	if intel != null:
		intel.call("learn", "appearance", "red coat", "pawned armor receipt")
	_toast("Pawn records recovered: red-coat intel and vendor-staff credentials.", 3.5)


func _use_clinic() -> void:
	_complete("clinic")
	_set_flag("hesperus.target.implant_disrupted", true)
	var intel := get_node_or_null("/root/BountyIntel")
	if intel != null:
		intel.call("learn", "scanner_signature", "cybernetic arm", "clinic implant registry")
	var target := get_tree().get_first_node_in_group("bounty_target")
	if target != null and target.has_method("apply_preparation_modifier"):
		target.call("apply_preparation_modifier", "implant_disrupted")
	_toast("Implant relay sabotaged: scanner signature acquired; Korvaxi's chase stamina reduced.", 3.8)


func _use_motel() -> void:
	_complete("motel")
	_set_flag("hesperus.courtyard.roof_access", true)
	_toast("Motel roof authorization forged. The upper courtyard route is now chase-valid.", 3.3)


func _use_service() -> void:
	_complete("service")
	_set_flag("hesperus.arcade.power_cut", true)
	get_tree().call_group("perceptive", "hear_noise", global_position, 12.0)
	_toast("Arcade service power cut. Tenant security and lighting are compromised.", 3.3)


func _bind() -> void:
	var scene_root := _get_scene_root()
	for role in ROLE_ANCHORS:
		var data: Array = ROLE_ANCHORS[role]
		var role_root := scene_root.get_node_or_null(String(data[0])) if scene_root != null else null
		if role_root == null:
			push_warning("North Arcade activity could not find %s for %s." % [data[0], role])
			continue
		var matches := role_root.find_children(String(data[1]), "Node3D", true, false)
		if matches.is_empty():
			push_warning("North Arcade activity missing anchor %s." % data[1])
			continue
		var anchor := matches[0] as Node3D
		var body := StaticBody3D.new()
		body.name = "%sInteractable" % String(role).to_pascal_case()
		body.set_script(INTERACTABLE)
		add_child(body)
		body.global_position = anchor.global_position + anchor.global_basis * (data[2] as Vector3)
		body.role = role
		body.activity_path = body.get_path_to(self)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.7, 0.9, 0.25)
		mesh.mesh = box
		body.add_child(mesh)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.9, 1.1, 0.55)
		collision.shape = shape
		body.add_child(collision)
	if _has_flag("hesperus.target.meeting_scheduled"):
		_schedule_target_meeting()


func _schedule_target_meeting() -> void:
	var target := get_tree().get_first_node_in_group("bounty_target")
	if target == null or not target.has_method("request_hidden_move"):
		return
	var marker := get_node_or_null("ScheduledMeetingMarker") as Marker3D
	if marker == null:
		marker = Marker3D.new()
		marker.name = "ScheduledMeetingMarker"
		add_child(marker)
		marker.global_position = Vector3(80.0, 0.2, -31.0)
	target.call("request_hidden_move", marker, 24.0)


func _done(role: String) -> bool:
	return _has_flag("%s.%s_complete" % [STATE_ROOT, role])


func _has_flag(state_id: String) -> bool:
	var district_state := get_node_or_null("/root/DistrictState")
	return district_state != null and bool(district_state.call("has_flag", state_id))


func _complete(role: String) -> void:
	_set_flag("%s.%s_complete" % [STATE_ROOT, role], true)


func _set_flag(state_id: String, active: bool) -> void:
	var district_state := get_node_or_null("/root/DistrictState")
	if district_state != null:
		district_state.call("set_flag", state_id, active)


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


func _toast(text: String, duration: float) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", text, duration)
