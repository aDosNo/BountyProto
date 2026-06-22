extends Area3D
## LadderZone — a climbable wall volume. While the player overlaps it, the
## player controller switches to look-direction climbing (see enter_ladder /
## _process_ladder in player_controller.gd). Place a box filling the shaft
## cross-section; the top should stop just below a covered hatch (so standing
## on a closed grate does not grab the ladder) or just above an open ledge
## (so climbing carries the player out onto it).

func _ready() -> void:
	monitoring = true
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("enter_ladder"):
		body.call("enter_ladder", self)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("exit_ladder"):
		body.call("exit_ladder", self)
