extends StaticBody3D
## DisguisePickup — wearable disguise on a stand/hook. Interact to don it.
## Tier 1 disguise = portable blending: the player counts as blended without
## needing nearby civilians, and guards are near-blind to them at range
## (see gang_guard disguise handling). Drawn weapon voids it (blend gate).
## Post-sprint economy: disguise tiers become purchases; this prop is the
## world-pickup form.

@export var disguise_name: String = "dock worker garb"
@export var disguise_id: String = "dock_worker"

var _taken: bool = false


func get_interaction_text() -> String:
	if _taken:
		return ""
	return "Press E: Don %s" % disguise_name


func interact(player: Node) -> void:
	if _taken:
		return
	if player == null or not player.has_method("equip_disguise"):
		return
	_taken = true
	player.call("equip_disguise", disguise_id, disguise_name)
	visible = false
	var shape := get_node_or_null("CollisionShape3D")
	if shape != null:
		shape.set_deferred("disabled", true)
	print("Disguise taken: %s" % disguise_name)
