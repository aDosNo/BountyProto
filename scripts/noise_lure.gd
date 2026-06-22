extends RigidBody3D
## NoiseLure — thrown distraction (stealth verb). Emits one noise event on
## first solid impact. Loudness sits BELOW the gunfire threshold (25), so
## guards investigate (SUSPICIOUS) rather than going hostile, and the Korvaxi
## target is NOT spooked. Systems ruling: lures pull guards, never panic them.

@export var noise_loudness: float = 14.0
@export var min_impact_speed: float = 2.0
@export var lifetime_after_impact: float = 6.0
@export var max_lifetime: float = 12.0

var _emitted: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Safety despawn if it never lands (thrown into a pit, etc).
	await get_tree().create_timer(max_lifetime).timeout
	if is_instance_valid(self) and not _emitted:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _emitted:
		return
	# Don't pop on brushing the thrower.
	if body != null and body.is_in_group("player"):
		return
	if linear_velocity.length() < min_impact_speed:
		return

	_emitted = true
	get_tree().call_group("perceptive", "hear_noise", global_position, noise_loudness)
	print("Noise lure impact (loudness %.1f m)." % noise_loudness)
	_flash()

	await get_tree().create_timer(lifetime_after_impact).timeout
	if is_instance_valid(self):
		queue_free()


func _flash() -> void:
	var mesh := get_node_or_null("LureMesh") as MeshInstance3D
	if mesh == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.7, 0.1)
	mat.emission_energy_multiplier = 2.2
	mesh.set_surface_override_material(0, mat)
