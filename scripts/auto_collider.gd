extends Node3D
## AutoCollider — attach to an imported GLB scene instance to generate static
## trimesh collision for every MeshInstance3D under it at load time.
## Graybox-grade: concave trimesh, fine for static level geometry.

@export var enabled: bool = true


func _ready() -> void:
	if not enabled:
		return
	var count := _add_collision_recursive(self)
	print("AutoCollider: generated collision for %d meshes under %s" % [count, name])


func _add_collision_recursive(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			(child as MeshInstance3D).create_trimesh_collision()
			count += 1
		count += _add_collision_recursive(child)
	return count
