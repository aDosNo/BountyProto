@tool
extends StaticBody3D

@export var wall_material: Material:
	set(value):
		wall_material = value
		if is_inside_tree():
			_apply_wall_material.call_deferred()


func _ready() -> void:
	_apply_wall_material()


func _apply_wall_material() -> void:
	if wall_material == null:
		return

	var display_material := _create_display_material()
	var mesh_instances: Array[MeshInstance3D] = []
	_collect_mesh_instances(self, mesh_instances)
	for mesh_instance in mesh_instances:
		if mesh_instance.visible:
			mesh_instance.material_override = display_material


func _collect_mesh_instances(node: Node, mesh_instances: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			mesh_instances.append(child)
		_collect_mesh_instances(child, mesh_instances)


func _create_display_material() -> Material:
	var material := wall_material.duplicate() as StandardMaterial3D
	if material == null:
		return wall_material

	material.roughness = 0.9
	material.metallic = 0.0
	material.metallic_specular = 0.1
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return material
