extends Area3D
## Permission volume. Disguises and credentials use the same access-tag
## vocabulary, while only disguises affect normal visual scrutiny.

@export var required_access_tag: String = ""
@export var warning_text: String = "Restricted area."
@export var escalation_delay: float = 2.0
@export var alert_radius: float = 28.0

var _intruder: Node3D
var _timer := 0.0
var _escalated := false


func _ready() -> void:
	monitoring = true
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if _intruder == null or _has_access(_intruder):
		_timer = 0.0
		return
	_timer += delta
	if _timer >= escalation_delay and not _escalated:
		_escalated = true
		for guard in get_tree().get_nodes_in_group("perceptive"):
			if guard is Node3D and global_position.distance_to(guard.global_position) <= alert_radius:
				if guard.has_method("on_ally_alert"):
					guard.call("on_ally_alert", global_position, _intruder.global_position)
		_show_toast("Security noticed the trespass.", 2.2)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_intruder = body as Node3D
	_timer = 0.0
	_escalated = false
	if not _has_access(body):
		_show_toast(warning_text, 2.0)


func _on_body_exited(body: Node) -> void:
	if body == _intruder:
		_intruder = null
		_timer = 0.0
		_escalated = false


func _has_access(body: Node) -> bool:
	if required_access_tag.is_empty():
		return true
	return body.has_method("has_access_tag") and body.call("has_access_tag", required_access_tag)


func _show_toast(text: String, duration: float) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", text, duration)
