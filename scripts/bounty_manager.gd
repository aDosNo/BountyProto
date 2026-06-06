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

@export var target_name: String = "Korvaxi Jurraal"
@export var location: String = "Hesperus Market / FPS Vertical Arena placeholder"
@export var threat: String = "High"
@export var reward_dead: int = 3000
@export var reward_alive: int = 7000

var state: MissionState = MissionState.INACTIVE

var _target: Node
var _reward_screen: Control
var _extraction_zone: Node
var _hud: CanvasLayer
var _clues_by_id: Dictionary = {}
var _target_status: String = ""
var _pending_reward: int = 0


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
	accept_bounty()


func accept_bounty() -> void:
	state = MissionState.ACCEPTED
	_set_objective("Scan for Korvaxi's trail")
	_activate_first_clue()
	print("Bounty accepted: %s" % target_name)


func on_target_neutralized() -> void:
	if _mission_is_closed() or state == MissionState.TARGET_NEUTRALIZED or state == MissionState.EXTRACTING:
		return

	state = MissionState.TARGET_NEUTRALIZED
	_set_objective("%s neutralized. Reach extraction." % target_name.split(" ")[0])
	print("Bounty target neutralized: %s" % target_name)
	start_extraction_phase("Dead", reward_dead)


func on_target_captured() -> void:
	if _mission_is_closed() or state == MissionState.TARGET_NEUTRALIZED or state == MissionState.EXTRACTING:
		return

	state = MissionState.TARGET_NEUTRALIZED
	_set_objective("Korvaxi captured alive. Reach extraction.")
	print("Bounty target captured alive: %s" % target_name)
	start_extraction_phase("Alive", reward_alive)


func on_clue_scanned(clue_id: String, next_clue_id: String, reveals_target: bool) -> void:
	if _mission_is_closed() or state == MissionState.TARGET_NEUTRALIZED or state == MissionState.EXTRACTING:
		return

	print("Clue scanned: %s" % clue_id)

	if reveals_target:
		_identify_target()
		return

	if next_clue_id.is_empty():
		_set_objective("Trail logged. Search for the next trace.")
		return

	_activate_clue(next_clue_id)
	_set_objective("Follow Korvaxi's trail")
	print("Activating next clue: %s" % next_clue_id)


func start_extraction_phase(status: String, reward: int) -> void:
	if _mission_is_closed() or state == MissionState.EXTRACTING:
		return

	_target_status = status
	_pending_reward = reward
	state = MissionState.EXTRACTING
	_set_objective("Bounty secured. Reach extraction.")
	_activate_extraction_zone()
	_activate_pressure_enemies()
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
	var final_reward := reward_dead if reward < 0 else reward
	_set_objective("Contract complete.")
	if _reward_screen == null:
		_reward_screen = _resolve_reward_screen()

	if _reward_screen != null and _reward_screen.has_method("show_reward"):
		_reward_screen.call("show_reward", target_name, status, final_reward)
	else:
		print("CONTRACT COMPLETE")
		print("Target: %s" % target_name)
		print("Status: %s" % status)
		print("Reward: %d CR" % final_reward)


func fail_bounty() -> void:
	if state == MissionState.COMPLETE or state == MissionState.FAILED:
		return

	state = MissionState.FAILED
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
	if _target.has_signal("reached_final_node"):
		_target.reached_final_node.connect(_on_target_reached_final_node)
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


func _identify_target() -> void:
	if _mission_is_closed() or state == MissionState.TARGET_NEUTRALIZED or state == MissionState.EXTRACTING:
		return

	state = MissionState.TARGET_IDENTIFIED
	_set_objective("Target identified: Korvaxi is fleeing!")
	print("Target identified: %s" % target_name)

	if _target == null:
		_target = _resolve_target()
	if _target != null:
		if _target.has_method("reveal_and_flee"):
			_target.call("reveal_and_flee")
		elif _target.has_method("set_identified"):
			_target.call("set_identified", true)


func _on_target_flee_started() -> void:
	if _mission_is_closed() or state == MissionState.TARGET_NEUTRALIZED or state == MissionState.EXTRACTING:
		return

	_set_objective("Chase Korvaxi Jurraal")


func _on_target_reached_final_node() -> void:
	if _mission_is_closed() or state == MissionState.TARGET_NEUTRALIZED or state == MissionState.EXTRACTING:
		return

	_set_objective("Korvaxi cornered. Neutralize target.")


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
		if enemy != null and enemy.has_method("set_active"):
			enemy.call("set_active", false)

	if pressure_enemies.is_empty():
		for enemy in get_tree().get_nodes_in_group("pressure_enemy"):
			if enemy.has_method("set_active"):
				enemy.call("set_active", false)


func _activate_pressure_enemies() -> void:
	for enemy_path in pressure_enemies:
		var enemy := get_node_or_null(enemy_path)
		if enemy != null and enemy.has_method("set_active"):
			enemy.call("set_active", true)

	if pressure_enemies.is_empty():
		for enemy in get_tree().get_nodes_in_group("pressure_enemy"):
			if enemy.has_method("set_active"):
				enemy.call("set_active", true)

	print("Pressure wave activated.")


func _set_objective(text: String) -> void:
	if _hud == null:
		_hud = _find_hud()

	if _hud != null and _hud.has_method("set_objective"):
		_hud.call("set_objective", text)
	else:
		print("Objective: %s" % text)


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
