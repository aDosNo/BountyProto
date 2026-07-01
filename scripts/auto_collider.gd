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
## Wall material applied to meshes matching wall_mesh_prefixes.
@export var wall_material: Material
@export var wall_mesh_prefixes: PackedStringArray = []
## When true, apply wall_material to every mesh not already claimed by a floor,
## accent-floor, window, or hidden rule. Fast first-pass for bare GLBs.
@export var wall_material_default: bool = false
@export_category("Collision Filtering")
@export var collision_excluded_prefixes: PackedStringArray = []
## Meshes matching these prefixes generate collision and are then hidden.
## Use for deliberately simple proxy geometry exported beside visual meshes.
@export var collision_proxy_prefixes: PackedStringArray = []
## Restrict collision generation to matching proxies when a detailed visual
## scene would otherwise create hundreds of unnecessary physics bodies.
@export var collision_proxy_only: bool = false
@export_category("Imported Mesh Visibility")
## Hide superseded pieces inside a larger imported shell without editing the
## source export. Hidden meshes are also skipped by collision generation.
@export var hidden_mesh_prefixes: PackedStringArray = []
@export_category("Window Glass Tint")
## Tint baked-in building window sub-meshes with the lit glass look. Any mesh
## whose name contains `window_match` (case-insensitive) gets one of the two
## glass materials, picked deterministically per mesh name so the warm/cool
## spread is stable across loads. Leave materials null to disable.
@export var window_glass_warm: Material
@export var window_glass_cool: Material
@export var window_match: String = "Window"
## 0.0 = all cool, 1.0 = all warm. Fraction of windows that get the warm material.
@export_range(0.0, 1.0) var window_warm_ratio: float = 0.45


func _ready() -> void:
	_hide_imported_meshes_recursive(self)
	_hide_collision_proxy_meshes_recursive(self)
	call_deferred("_refresh_imported_floor_materials")
	call_deferred("_refresh_imported_wall_materials")
	call_deferred("_apply_window_glass")
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


func _refresh_imported_wall_materials() -> void:
	if wall_material == null:
		return
	var material_count := _apply_wall_materials_recursive(self)
	if material_count > 0:
		print("AutoCollider: applied wall materials to %d meshes under %s" % [material_count, name])


func _apply_wall_materials_recursive(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			# Skip meshes already owned by other rules.
			var already_claimed := (
				(floor_material != null and _name_starts_with_any(mi.name, floor_mesh_prefixes))
				or (accent_floor_material != null and accent_floor_mesh_names.has(mi.name))
				or _name_starts_with_any(mi.name, hidden_mesh_prefixes)
				or String(mi.name).to_lower().contains(window_match.to_lower())
			)
			if not already_claimed:
				if _name_starts_with_any(mi.name, wall_mesh_prefixes):
					mi.material_override = wall_material
					count += 1
				elif wall_material_default and mi.material_override == null:
					mi.material_override = wall_material
					count += 1
		count += _apply_wall_materials_recursive(child)
	return count


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
		var is_proxy := (
			child is MeshInstance3D
			and _name_starts_with_any(child.name, collision_proxy_prefixes)
		)
		if (
			child is MeshInstance3D
			and (child as MeshInstance3D).mesh != null
			and (
				is_proxy
				or (
					not collision_proxy_only
					and not _name_starts_with_any(child.name, collision_excluded_prefixes)
				)
			)
			and not _name_starts_with_any(child.name, hidden_mesh_prefixes)
		):
			(child as MeshInstance3D).create_trimesh_collision()
			if is_proxy:
				(child as MeshInstance3D).visible = false
			count += 1
		count += _add_collision_recursive(child)
	return count


func _hide_imported_meshes_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and _name_starts_with_any(child.name, hidden_mesh_prefixes):
			(child as MeshInstance3D).visible = false
		_hide_imported_meshes_recursive(child)


func _hide_collision_proxy_meshes_recursive(node: Node) -> void:
	for child in node.get_children():
		if (
			child is MeshInstance3D
			and _name_starts_with_any(child.name, collision_proxy_prefixes)
		):
			(child as MeshInstance3D).visible = false
		_hide_collision_proxy_meshes_recursive(child)


func _apply_window_glass() -> void:
	if window_glass_warm == null and window_glass_cool == null:
		return
	if window_match.is_empty():
		return
	var count := _apply_window_glass_recursive(self)
	if count > 0:
		print("AutoCollider: tinted %d window meshes under %s" % [count, name])


func _apply_window_glass_recursive(node: Node) -> int:
	var count := 0
	var needle := window_match.to_lower()
	for child in node.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible:
			if String(child.name).to_lower().contains(needle):
				var mesh_instance := child as MeshInstance3D
				var mat := _pick_window_material(String(child.name))
				if mat != null:
					mesh_instance.material_override = mat
					count += 1
		count += _apply_window_glass_recursive(child)
	return count


func _pick_window_material(mesh_name: String) -> Material:
	# Deterministic per-name pick so the warm/cool spread is stable across loads.
	# Falls back to whichever single material is set if only one is provided.
	if window_glass_warm == null:
		return window_glass_cool
	if window_glass_cool == null:
		return window_glass_warm
	var h := float(hash(mesh_name) % 1000) / 1000.0
	return window_glass_warm if h < window_warm_ratio else window_glass_cool
