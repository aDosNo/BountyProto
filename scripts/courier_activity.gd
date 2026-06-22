extends Node3D

signal package_collected
signal completed

var has_package := false
var credentials_granted := false
var terminal_enabled := false


func collect_package() -> void:
	if has_package or credentials_granted:
		return
	has_package = true
	package_collected.emit()
	_toast("Delivery package collected. Return it to the alley courier.", 3.0)


func complete_delivery(player: Node) -> bool:
	if credentials_granted:
		return true
	if not has_package:
		_toast("\"My delivery is still in the Alien Bar storage room.\"", 3.0)
		return false
	has_package = false
	credentials_granted = true
	terminal_enabled = true
	if player.has_method("grant_credential"):
		player.call("grant_credential", "courtyard_service")
	var intel := get_node_or_null("/root/BountyIntel")
	if intel != null and intel.has_method("learn"):
		intel.call("learn", "location_habit", "courtyard", "courier schedule")
	_toast("Courier credentials acquired. Delivery-call terminal enabled.", 3.5)
	completed.emit()
	return true


func call_delivery_meeting() -> bool:
	if not terminal_enabled:
		_toast("Terminal requires an active courier credential.", 2.5)
		return false
	var target := get_tree().get_first_node_in_group("bounty_target")
	var marker := get_node_or_null("MeetingMarker") as Marker3D
	if target == null or marker == null or not target.has_method("request_hidden_move"):
		return false
	if target.call("request_hidden_move", marker, 18.0):
		_toast("Delivery meeting scheduled. Korvaxi is moving to the north service point.", 3.5)
		return true
	_toast("The target is no longer available for a quiet meeting.", 2.5)
	return false


func _toast(text: String, duration: float) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", text, duration)
