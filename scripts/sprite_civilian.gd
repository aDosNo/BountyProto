extends "res://scripts/crowd_npc.gd"
## SpriteCivilian — CrowdNPC with an 8-way directional billboard sprite in
## place of the capsule mesh. Inherits ALL crowd behavior (wander, panic,
## push, scan, witness, damage, blending membership via scannable_npc group).
##
## Visual state feedback (scanner highlight, scanned tint, hit flash, death)
## rides the sprite's modulate via DirectionalSprite3D's state API instead of
## the base class's MeshInstance3D material overrides. The scene keeps an
## EMPTY MeshInstance3D named %NpcMesh so the base class's typed @onready
## reference still binds; every method that touched it is overridden here.

@onready var _dir_sprite: Sprite3D = $Sprite


func _flash_hit() -> void:
	if _dir_sprite == null:
		return
	_dir_sprite.set_state_tint(Color(1.0, 0.18, 0.12))
	await get_tree().create_timer(0.08).timeout
	if _is_dead or not is_instance_valid(_dir_sprite):
		return
	if is_scanned:
		_set_scanned_tint()
	else:
		_dir_sprite.clear_state_tint()


func _die() -> void:
	_is_dead = true
	remove_from_group("scannable_npc")
	remove_from_group("damageable")
	# Preserve CrowdNPC's police response when this visual subclass replaces
	# the base death implementation.
	get_tree().call_group("police_drone", "on_civilian_killed", global_position, is_target)
	died.emit(self)
	name_label.visible = false
	collision_shape.set_deferred("disabled", true)
	set_physics_process(false)

	if _dir_sprite == null:
		queue_free()
		return
	_dir_sprite.set_state_tint(Color(0.62, 0.1, 0.08))
	var tween := create_tween()
	tween.tween_property(_dir_sprite, "scale",
		_dir_sprite.scale * Vector3(1.1, 0.16, 1.1), death_cleanup_delay)
	tween.parallel().tween_property(_dir_sprite, "position:y", 0.12, death_cleanup_delay)
	tween.tween_interval(1.5)
	tween.tween_callback(queue_free)


func _set_highlight(active: bool) -> void:
	if _dir_sprite == null:
		return
	if active:
		_dir_sprite.set_state_tint(Color(0.62, 0.92, 1.0))
	elif is_scanned:
		_set_scanned_tint()
	else:
		_dir_sprite.clear_state_tint()


func _set_scanned_tint() -> void:
	if _dir_sprite == null:
		return
	_dir_sprite.set_state_tint(Color(0.55, 0.95, 0.62))
