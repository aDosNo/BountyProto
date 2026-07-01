extends SceneTree

const SCANNER_SCRIPT := preload("res://scripts/scanner.gd")


class SweepTarget extends Node3D:
	var appearance := "red coat"
	var movement_tell := "heavy gait"
	var location_habit := "courtyard"
	var swept_count := 0

	func mark_swept(_duration: float) -> void:
		swept_count += 1


class EvidenceTarget extends Node3D:
	var swept_count := 0

	func is_scannable() -> bool:
		return true

	func mark_swept(_duration: float) -> void:
		swept_count += 1


class BlendPlayer extends CharacterBody3D:
	var blended := false

	func is_blended() -> bool:
		return blended


class PerceptionSpy extends Node:
	var radii: Array[float] = []

	func hear_noise(_position: Vector3, radius: float) -> void:
		radii.append(radius)


func _initialize() -> void:
	var failures: Array[String] = []
	var world_root := Node3D.new()
	root.add_child(world_root)
	current_scene = world_root

	var camera := Camera3D.new()
	world_root.add_child(camera)
	var player := BlendPlayer.new()
	world_root.add_child(player)
	var scanner := SCANNER_SCRIPT.new()
	world_root.add_child(scanner)
	scanner.call("setup", camera, null, player)

	var target := SweepTarget.new()
	target.position = Vector3(0.0, 0.0, -10.0)
	target.add_to_group("scannable_npc")
	world_root.add_child(target)
	var evidence := EvidenceTarget.new()
	evidence.position = Vector3(0.0, 0.0, -8.0)
	evidence.add_to_group("scanner_evidence")
	world_root.add_child(evidence)
	var spy := PerceptionSpy.new()
	spy.add_to_group("perceptive")
	world_root.add_child(spy)
	await physics_frame

	var intel := root.get_node_or_null("BountyIntel")
	_expect(intel != null, "BountyIntel autoload", failures)
	if intel == null:
		_finish(failures)
		return

	intel.call("reset")
	scanner.call("_do_sweep")
	_expect(target.swept_count == 0, "sweep is inert without visible intel", failures)
	_expect(evidence.swept_count == 1, "physical evidence is discoverable without visible intel", failures)

	intel.call("learn", "appearance", "red coat", "scanner test")
	scanner.call("_do_sweep")
	_expect(target.swept_count == 1, "in-cone matching target is swept", failures)
	_expect(evidence.swept_count == 2, "evidence remains sweep-discoverable with intel", failures)

	target.position = Vector3(12.0, 0.0, -1.0)
	scanner.call("_do_sweep")
	_expect(target.swept_count == 1, "out-of-cone target is rejected", failures)
	target.position = Vector3(0.0, 0.0, -10.0)

	Input.action_press("scan")
	scanner.call("_physics_process", 0.05)
	Input.action_release("scan")
	scanner.call("_physics_process", 0.01)
	_expect(target.swept_count == 2, "short press dispatches sweep", failures)
	_expect(evidence.swept_count == 4, "short press dispatches evidence sweep", failures)

	Input.action_press("scan")
	scanner.call("_physics_process", 0.25)
	_expect(bool(scanner.get("_is_analyzing")), "held press enters analysis", failures)
	Input.action_release("scan")
	scanner.call("_physics_process", 0.01)
	_expect(target.swept_count == 2, "analysis release does not dispatch sweep", failures)

	scanner.set("current_scan_progress", 1.5)
	scanner.call("_accrue_suspicion", 1.0, target)
	var exposed_radius: float = spy.radii.back() if not spy.radii.is_empty() else 0.0
	player.blended = true
	scanner.set("current_scan_progress", 1.5)
	scanner.call("_accrue_suspicion", 1.0, target)
	var blended_radius: float = spy.radii.back() if not spy.radii.is_empty() else 0.0
	_expect(exposed_radius > blended_radius and blended_radius > 0.0,
		"blending reduces analysis suspicion radius", failures)

	intel.call("reset")
	_finish(failures)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _finish(failures: Array[String]) -> void:
	Input.action_release("scan")
	if failures.is_empty():
		print("Hybrid scanner input, cone, gate, and suspicion test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("Hybrid scanner test: %s" % failure)
	quit(1)
