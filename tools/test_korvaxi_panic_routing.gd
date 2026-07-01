extends SceneTree

const TARGET_SCENE := preload("res://scenes/enemies/KorvaxiTarget.tscn")
const GUARD_SCENE := preload("res://scenes/enemies/GangGuard.tscn")


class PanicSpy extends Node:
	var guard_alerts := 0

	func on_guard_alert(_shouter_position: Vector3, _threat_position: Vector3) -> void:
		guard_alerts += 1


func _initialize() -> void:
	var clear_target := _spawn_target(Vector3.ZERO)
	await physics_frame
	assert(clear_target.is_in_group("target_panic_listener"))
	assert(not clear_target.is_in_group("perceptive"))

	clear_target.call("on_guard_alert", Vector3(0.0, 0.0, 10.0), Vector3.ZERO)
	assert(int(clear_target.get("state")) == 2) # REVEALED

	var distant_target := _spawn_target(Vector3(40.0, 0.0, 0.0))
	distant_target.call("on_guard_alert", Vector3(0.0, 0.0, 0.0), Vector3.ZERO)
	assert(int(distant_target.get("state")) == 1) # IDLE_HIDDEN

	var blocked_target := _spawn_target(Vector3(80.0, 0.0, 0.0))
	var wall := _make_wall(Vector3(80.0, 2.0, 5.0))
	root.add_child(wall)
	await physics_frame
	blocked_target.call("on_guard_alert", Vector3(80.0, 0.0, 10.0), Vector3.ZERO)
	assert(int(blocked_target.get("state")) == 1) # IDLE_HIDDEN

	var noise_target := _spawn_target(Vector3(120.0, 0.0, 0.0))
	noise_target.call("on_combat_noise", Vector3(120.0, 0.0, 10.0), 35.0)
	assert(int(noise_target.get("state")) == 2) # REVEALED

	var spy := PanicSpy.new()
	spy.add_to_group("target_panic_listener")
	root.add_child(spy)
	var player_stub := Node3D.new()
	player_stub.add_to_group("player")
	root.add_child(player_stub)

	var lethal_guard := GUARD_SCENE.instantiate()
	lethal_guard.health = 10
	root.add_child(lethal_guard)
	await process_frame
	lethal_guard.take_damage(10)
	assert(spy.guard_alerts == 0)

	var surviving_guard := GUARD_SCENE.instantiate()
	surviving_guard.health = 75
	root.add_child(surviving_guard)
	await process_frame
	surviving_guard.take_damage(1)
	assert(spy.guard_alerts == 1)

	print("Korvaxi panic routing: dedicated channel, range, occlusion, and lethal-hit checks passed.")
	quit()


func _spawn_target(world_position: Vector3) -> CharacterBody3D:
	var target := TARGET_SCENE.instantiate() as CharacterBody3D
	target.position = world_position
	root.add_child(target)
	return target


func _make_wall(world_position: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.position = world_position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.0, 4.0, 0.6)
	collision.shape = shape
	wall.add_child(collision)
	return wall
