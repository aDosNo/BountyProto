extends Node3D
## Lightweight drifting sky clouds. Uses a few translucent shader planes high
## above the map so the skybox remains sparse while the atmosphere moves.

@export var cloud_shader: Shader = preload("res://shaders/sky_cloud_plane.gdshader")
@export var cloud_count: int = 7
@export var layer_height: float = 78.0
@export var field_radius: float = 135.0
@export var scroll_direction: Vector3 = Vector3(1.0, 0.0, -0.22)
@export var scroll_speed: float = 1.15
@export var cloud_color: Color = Color(1.0, 0.47, 0.18, 0.12)
@export var rng_seed: int = 7321

var _clouds: Array[MeshInstance3D] = []
var _uv_offsets: Array[Vector2] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_process(true)
	_rng.seed = rng_seed
	var direction := _flat_direction()
	for i in range(maxi(cloud_count, 1)):
		var cloud := _make_cloud(i)
		var offset := _cloud_offset(i)
		cloud.position = Vector3(offset.x, layer_height, offset.y)
		add_child(cloud)
		_clouds.append(cloud)
		_uv_offsets.append(Vector2(float(i) * 0.137, float(i) * 0.271))
	_update_cloud_yaw(direction)


func _process(delta: float) -> void:
	var direction := _flat_direction()
	var movement := direction * scroll_speed * delta
	for i in range(_clouds.size()):
		var cloud := _clouds[i]
		cloud.position += movement
		if Vector2(cloud.position.x, cloud.position.z).length() > field_radius:
			var reset := -Vector2(direction.x, direction.z).normalized() * field_radius * 0.72
			reset += _side_vector(direction) * _rng.randf_range(-field_radius * 0.45, field_radius * 0.45)
			cloud.position.x = reset.x
			cloud.position.z = reset.y

		var mat := cloud.material_override as ShaderMaterial
		if mat != null:
			var uv := _uv_offsets[i] + Vector2(0.018, 0.006) * delta
			_uv_offsets[i] = uv
			mat.set_shader_parameter("uv_offset", uv)


func _make_cloud(index: int) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	var width := _rng.randf_range(42.0, 128.0)
	var depth := _rng.randf_range(13.0, 42.0)
	mesh.size = Vector2(width, depth)

	var tint := cloud_color
	tint.a *= _rng.randf_range(0.62, 1.18)
	tint.r *= _rng.randf_range(0.86, 1.08)
	tint.g *= _rng.randf_range(0.78, 1.05)
	tint.b *= _rng.randf_range(0.72, 1.12)

	var material := ShaderMaterial.new()
	material.shader = cloud_shader
	material.set_shader_parameter("cloud_color", tint)
	material.set_shader_parameter("cloud_scale", _rng.randf_range(1.35, 4.4))
	material.set_shader_parameter("cloud_threshold", _rng.randf_range(0.52, 0.70))
	material.set_shader_parameter("cloud_softness", _rng.randf_range(0.14, 0.34))
	material.set_shader_parameter("seed", _rng.randf_range(0.0, 100.0) + float(index) * 9.17)
	material.set_shader_parameter("warp_strength", _rng.randf_range(0.15, 0.85))
	material.set_shader_parameter("shape_stretch", Vector2(_rng.randf_range(0.72, 1.6), _rng.randf_range(0.55, 1.45)))
	material.set_shader_parameter("uv_offset", Vector2(_rng.randf_range(-9.0, 9.0), _rng.randf_range(-9.0, 9.0)))

	var cloud := MeshInstance3D.new()
	cloud.name = "CloudBand_%02d" % index
	cloud.mesh = mesh
	cloud.material_override = material
	return cloud


func _cloud_offset(index: int) -> Vector2:
	var t := float(index) / maxf(float(maxi(cloud_count - 1, 1)), 1.0)
	var angle := t * TAU + _rng.randf_range(-0.45, 0.45)
	var radius := _rng.randf_range(field_radius * 0.18, field_radius * 0.78)
	return Vector2(cos(angle), sin(angle)) * radius


func _flat_direction() -> Vector3:
	var direction := Vector3(scroll_direction.x, 0.0, scroll_direction.z)
	if direction.length_squared() < 0.001:
		direction = Vector3.RIGHT
	return direction.normalized()


func _side_vector(direction: Vector3) -> Vector2:
	return Vector2(-direction.z, direction.x).normalized()


func _update_cloud_yaw(direction: Vector3) -> void:
	var yaw := atan2(-direction.x, -direction.z)
	for cloud in _clouds:
		cloud.rotation.y = yaw + _rng.randf_range(-0.38, 0.38)
