extends Marker3D
## Authored placement contract for runtime evidence. Anchors carry spatial
## meaning only; target values always come from the active contract profile.

@export var anchor_id: String = ""
@export var zone_label: String = ""
@export var anchor_tags: PackedStringArray = []
@export var trail_points: PackedVector3Array = []
@export_enum("authored", "floor", "floor_near_landmark", "mesh_top") var placement_mode := "authored"
@export var landmark_root_name := ""
@export var landmark_name := ""
@export var landmark_offset := Vector3.ZERO
@export_range(0.01, 0.2, 0.005) var surface_clearance := 0.04
@export_group("Trail Follow-up")
@export var followup_anchor_id := ""
@export var followup_zone_label := ""

var placement_error := ""

const FALLBACK_TAGS := {
	"bazaar_trail_a": ["ground", "trail"],
	"side_alley_trail": ["ground", "trail"],
	"east_approach_trail": ["ground", "trail"],
	"north_service_trail": ["ground", "trail"],
	"bazaar_stall_fiber": ["edge", "fabric"],
	"side_alley_fiber": ["edge", "fabric"],
	"service_awning_fiber": ["edge", "fabric"],
	"east_market_stall_fiber": ["edge", "fabric"],
	"bazaar_delivery_counter": ["counter", "service"],
	"north_arcade_bar_counter": ["counter", "service"],
	"courtyard_threshold_trace": ["counter", "service"],
	"north_arcade_clinic_tech": ["clinic", "tech"],
	"foremarket_clinic_tech": ["clinic", "tech"],
}


func accepts(required_tags: Array) -> bool:
	var effective_tags := get_effective_tags()
	for required in required_tags:
		if not effective_tags.has(String(required)):
			return false
	return true


func get_effective_tags() -> PackedStringArray:
	if not anchor_tags.is_empty():
		return anchor_tags
	var fallback: Array = FALLBACK_TAGS.get(anchor_id, [])
	var result := PackedStringArray()
	for tag in fallback:
		result.append(String(tag))
	return result


func get_followup_position() -> Vector3:
	var followup := _find_sibling_anchor(followup_anchor_id)
	if followup == null:
		return global_position
	if followup.has_method("resolve_placement"):
		followup.call("resolve_placement")
	return followup.global_position


func get_followup_zone() -> String:
	if not followup_zone_label.is_empty():
		return followup_zone_label
	var followup := _find_sibling_anchor(followup_anchor_id)
	return String(followup.get("zone_label")) if followup != null else ""


func _find_sibling_anchor(requested_id: String) -> Node3D:
	if requested_id.is_empty() or get_parent() == null:
		return null
	for sibling in get_parent().get_children():
		if sibling is Node3D and String(sibling.get("anchor_id")) == requested_id:
			return sibling as Node3D
	return null


func resolve_placement() -> bool:
	placement_error = ""
	var landmark: Node3D
	if placement_mode in ["floor_near_landmark", "mesh_top"]:
		landmark = _find_landmark()
		if landmark == null:
			placement_error = "missing landmark %s/%s" % [landmark_root_name, landmark_name]
			return false
		var landmark_basis := landmark.global_basis.orthonormalized()
		global_basis = landmark_basis
		if placement_mode == "mesh_top":
			var mesh := _mesh_for_landmark(landmark)
			if mesh == null:
				placement_error = "landmark %s has no mesh" % landmark_name
				return false
			global_position = _world_mesh_top(mesh) + landmark_basis * landmark_offset
		else:
			global_position = landmark.global_position + landmark_basis * landmark_offset

	if placement_mode in ["floor", "floor_near_landmark"]:
		if not _snap_to_floor():
			placement_error = "no floor below placement"
			return false
	return true


func is_placement_clear() -> bool:
	var world := get_world_3d()
	if world == null:
		return false
	var shape := SphereShape3D.new()
	shape.radius = 0.14
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * 0.22)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return world.direct_space_state.intersect_shape(query, 1).is_empty()


func _find_landmark() -> Node3D:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return null
	var search_root: Node = scene_root
	if not landmark_root_name.is_empty():
		var roots := scene_root.find_children(landmark_root_name, "Node3D", true, false)
		if roots.is_empty():
			return null
		search_root = roots[0]
	if search_root.name == landmark_name and search_root is Node3D:
		return search_root as Node3D
	var matches := search_root.find_children(landmark_name, "Node3D", true, false)
	return matches[0] as Node3D if not matches.is_empty() else null


func _mesh_for_landmark(landmark: Node3D) -> MeshInstance3D:
	if landmark is MeshInstance3D:
		return landmark as MeshInstance3D
	var meshes := landmark.find_children("*", "MeshInstance3D", true, false)
	return meshes[0] as MeshInstance3D if not meshes.is_empty() else null


func _world_mesh_top(mesh: MeshInstance3D) -> Vector3:
	var bounds := mesh.get_aabb()
	var center := mesh.global_transform * bounds.get_center()
	var maximum_y := -INF
	for x in [bounds.position.x, bounds.end.x]:
		for y in [bounds.position.y, bounds.end.y]:
			for z in [bounds.position.z, bounds.end.z]:
				maximum_y = maxf(maximum_y, (mesh.global_transform * Vector3(x, y, z)).y)
	center.y = maximum_y + surface_clearance
	return center


func _snap_to_floor() -> bool:
	var world := get_world_3d()
	if world == null:
		return false
	var from := global_position + Vector3.UP * 1.25
	var to := global_position + Vector3.DOWN * 4.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	global_position = Vector3(global_position.x, float(hit.position.y) + surface_clearance, global_position.z)
	return true


func world_trail_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	if trail_points.is_empty():
		for index in range(8):
			points.append(global_transform * Vector3(0.0, 0.0, -float(index) * 0.72))
		return points
	for point in trail_points:
		points.append(global_transform * point)
	return points
