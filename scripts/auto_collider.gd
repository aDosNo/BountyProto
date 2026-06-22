@tool
extends Node3D
## AutoCollider — attach to an imported GLB scene instance to generate static
## trimesh collision for every MeshInstance3D under it at load time.
## Graybox-grade: concave trimesh, fine for static level geometry.

@export var enabled: bool = true
@export_category("Material Overrides")
@export var floor_material: Material
@export var accent_floor_material: Material
@export var floor_mesh_prefixes: PackedStringArray = []
@export var accent_floor_mesh_names: PackedStringArray = []


func _ready() -> void:
	call_deferred("_refresh_imported_floor_materials")
	if Engine.is_editor_hint():
		return
	if not enabled:
		return
	var count := _add_collision_recursive(self)
	print("AutoCollider: generated collision for %d meshes under %s" % [count, name])


func _refresh_imported_floor_materials() -> void:
	var material_count := _apply_floor_materials_recursive(self)
	if material_count > 0:
		print("AutoCollider: applied floor materials to %d meshes under %s" % [material_count, name])


func _apply_floor_materials_recursive(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_instance := child as MeshInstance3D
			if accent_floor_material != null and accent_floor_mesh_names.has(mesh_instance.name):
				mesh_instance.material_override = accent_floor_material
				count += 1
			elif floor_material != null and _name_starts_with_any(mesh_instance.name, floor_mesh_prefixes):
				mesh_instance.material_override = floor_material
				count += 1
		count += _apply_floor_materials_recursive(child)
	return count


func _name_starts_with_any(node_name: StringName, prefixes: PackedStringArray) -> bool:
	var node_name_string := String(node_name)
	for prefix in prefixes:
		if node_name_string.begins_with(prefix):
			return true
	return false


func _add_collision_recursive(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			(child as MeshInstance3D).create_trimesh_collision()
			count += 1
		count += _add_collision_recursive(child)
	return count
