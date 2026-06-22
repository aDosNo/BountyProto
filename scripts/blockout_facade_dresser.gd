@tool
extends Node3D
## Test pass for turning plain blockout boxes into readable city facades.
## Generates visual-only, non-colliding architecture cues: recessed windows,
## awnings, balconies, service bays, roof huts, pipes, and signs. Route/collision
## geometry is untouched.

enum MaterialSlot { WALL, TRIM, DARK, WINDOW, SIGN, SERVICE, AWNING, ROOF, RAIL }

const GENERATED_META := &"blockout_facade_dresser_generated"

var _materials: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_clear_generated()
	_rng.seed = 46219
	_build_materials()
	_dress_bazaar_west_facade()
	_dress_east_approach_apartment_back()
	_dress_courtyard_north_service_wall()
	_dress_side_alley_back_wall()


func _dress_bazaar_west_facade() -> void:
	# West edge of the bazaar street, visible when moving between bazaar and plaza.
	var x := -0.72
	var z_center := 10.2
	_add_box("BazaarWest_StorefrontRecess", Vector3(x - 0.08, 0.4, z_center), Vector3(0.3, 4.1, 27.0), MaterialSlot.DARK)
	_add_box("BazaarWest_UpperMass", Vector3(x - 0.02, 7.7, z_center), Vector3(0.24, 10.5, 25.2), MaterialSlot.WALL)
	_add_box("BazaarWest_RoofParapet", Vector3(x - 0.16, 14.55, z_center), Vector3(0.7, 1.35, 27.2), MaterialSlot.TRIM)

	_add_west_awning("BazaarWest_MainAwning", x, 3.1, z_center, 24.8, 2.4)
	_add_west_service_opening("BazaarWest_LeftShop", x, 0.6, 3.1, 3.6, 3.4)
	_add_west_service_opening("BazaarWest_MarketDoor", x, 0.6, 11.0, 4.4, 3.8)
	_add_west_service_opening("BazaarWest_RightShop", x, 0.6, 19.0, 3.6, 3.4)

	for z in [1.2, 8.8, 16.4]:
		_add_west_window_bay("BazaarWest_UpperBay_%s" % str(z), x, 7.6, z, 5.2, 4.2, 3, 2)
	_add_west_balcony("BazaarWest_BalconyMid", x, 5.0, 16.4, 6.2, 1.6)

	_add_box("BazaarWest_HangingSign", Vector3(x - 1.55, 4.45, 5.9), Vector3(0.18, 1.7, 3.0), MaterialSlot.SIGN)
	_add_roof_hut("BazaarWest_RoofHut", Vector3(-3.7, 15.3, 6.0), Vector3(3.8, 2.4, 4.6))
	_add_roof_units("BazaarWest_Roof", Vector3(-3.2, 15.45, 14.0), 2, Vector3(3.0, 1.0, 2.2), Vector3(0.0, 0.0, 5.8))
	_add_water_tank("BazaarWest_Tank", Vector3(-3.9, 16.1, 22.0))


func _dress_east_approach_apartment_back() -> void:
	# Building15: frames the empty south/back-lot space between plaza and courtyard.
	var x := 34.25
	var z_center := 23.4
	_add_box("EastApproach_ServiceRecess", Vector3(x - 0.1, 1.0, z_center), Vector3(0.32, 4.1, 21.0), MaterialSlot.DARK)
	_add_box("EastApproach_ApartmentMass", Vector3(x - 0.03, 10.8, z_center), Vector3(0.24, 15.4, 19.4), MaterialSlot.WALL)
	_add_box("EastApproach_BacklotParapet", Vector3(x - 0.2, 20.45, z_center), Vector3(0.75, 1.35, 22.2), MaterialSlot.TRIM)

	_add_west_awning("EastApproach_LoadingCanopy", x, 3.5, 25.8, 8.0, 2.8)
	_add_west_service_opening("EastApproach_LoadingDoor", x, 0.85, 25.8, 4.8, 4.4)
	_add_west_service_opening("EastApproach_UtilityDoor", x, 0.55, 15.4, 2.4, 3.0)

	for z in [16.3, 23.4, 30.5]:
		_add_west_window_bay("EastApproach_WindowStack_%s" % str(z), x, 9.5, z, 4.6, 5.0, 2, 3)
	_add_west_balcony("EastApproach_LeftBalcony", x, 7.2, 16.3, 5.4, 1.45)
	_add_west_balcony("EastApproach_RightBalcony", x, 12.8, 30.5, 5.4, 1.45)

	_add_box("EastApproach_HangingSign", Vector3(x - 1.65, 5.1, 18.0), Vector3(0.16, 1.3, 3.6), MaterialSlot.SIGN)
	_add_pipe_run("EastApproach_PipeLow", Vector3(x - 0.95, 4.0, 13.4), 20.0, true)
	_add_roof_hut("EastApproach_RoofStairwell", Vector3(37.8, 21.0, 18.0), Vector3(3.7, 2.6, 4.0))
	_add_roof_units("EastApproach_Roof", Vector3(38.0, 21.2, 25.5), 2, Vector3(3.2, 1.25, 2.4), Vector3(0.0, 0.0, 5.8))
	_add_antenna("EastApproach_Antenna", Vector3(38.5, 22.9, 33.0), 4.2)


func _dress_courtyard_north_service_wall() -> void:
	# Building13: north service lane / balcony-route edge. Keep the lane readable.
	var z := -37.85
	var x_center := 112.0
	_add_box("NorthService_UpperMass", Vector3(x_center, 10.0, z), Vector3(25.5, 17.0, 0.24), MaterialSlot.WALL)
	_add_box("NorthService_GroundServiceBand", Vector3(x_center, 1.1, z - 0.1), Vector3(26.0, 2.8, 0.32), MaterialSlot.DARK)
	_add_box("NorthService_Parapet", Vector3(x_center, 24.95, z - 0.16), Vector3(27.5, 1.35, 0.72), MaterialSlot.TRIM)

	_add_north_catwalk("NorthService_Catwalk", x_center, 11.4, z, 24.0, 1.8)
	_add_north_awning("NorthService_ServiceCanopy", 111.0, 3.25, z, 13.5, 2.4)
	_add_north_service_opening("NorthService_LoadingDoorA", 105.0, z, 0.8, 4.4, 4.0)
	_add_north_service_opening("NorthService_LoadingDoorB", 117.5, z, 0.8, 5.2, 4.0)

	for x in [101.0, 108.2, 115.4, 122.6]:
		_add_north_window_bay("NorthService_UpperBay_%s" % str(x), x, 15.8, z, 4.6, 5.0, 2, 3)

	_add_pipe_run("NorthService_OverheadPipe", Vector3(99.0, 19.5, z - 0.95), 27.0, false)
	_add_box("NorthService_RouteSign", Vector3(125.8, 4.4, z - 1.0), Vector3(3.2, 1.0, 0.14), MaterialSlot.SIGN)
	_add_roof_hut("NorthService_RoofElevator", Vector3(104.0, 25.8, -42.6), Vector3(4.8, 3.0, 3.6))
	_add_roof_units("NorthService_Roof", Vector3(113.0, 25.7, -43.2), 3, Vector3(2.8, 1.1, 2.0), Vector3(5.4, 0.0, 0.0))
	_add_antenna("NorthService_Antenna", Vector3(124.0, 27.2, -42.5), 5.2)


func _dress_side_alley_back_wall() -> void:
	# Building5: reinforces the side-alley investigation route with scale cues.
	var x := -39.55
	var z_center := 34.0
	_add_box("SideAlley_ServiceRecess", Vector3(x - 0.08, 1.25, z_center), Vector3(0.32, 3.9, 17.0), MaterialSlot.DARK)
	_add_box("SideAlley_UpperMass", Vector3(x - 0.02, 9.2, z_center), Vector3(0.24, 12.5, 16.4), MaterialSlot.WALL)
	_add_box("SideAlley_RoofLip", Vector3(x - 0.18, 19.1, z_center), Vector3(0.68, 1.25, 18.4), MaterialSlot.TRIM)

	_add_west_awning("SideAlley_DoorAwning", x, 3.2, 30.0, 5.8, 1.9)
	_add_west_service_opening("SideAlley_DoorFrame", x, 0.6, 30.0, 3.4, 3.4)
	_add_west_balcony("SideAlley_WorkBalcony", x, 6.6, 37.0, 7.0, 1.6)
	for z in [28.4, 34.2, 40.0]:
		_add_west_window_bay("SideAlley_WindowBay_%s" % str(z), x, 10.0, z, 4.2, 4.6, 2, 2)
		_add_box("SideAlley_DuctBox_%s" % str(z), Vector3(x - 0.62, 5.0, z + 1.7), Vector3(0.75, 1.1, 1.6), MaterialSlot.SERVICE)

	_add_pipe_run("SideAlley_VerticalPipeA", Vector3(x - 0.9, 9.0, 25.7), 15.5, false, true)
	_add_box("SideAlley_SmallSign", Vector3(x - 0.9, 3.9, 39.0), Vector3(0.16, 1.0, 3.0), MaterialSlot.SIGN)
	_add_roof_hut("SideAlley_RoofShed", Vector3(-42.1, 19.6, 31.5), Vector3(3.2, 2.2, 3.5))
	_add_water_tank("SideAlley_Tank", Vector3(-42.4, 20.1, 39.6))


func _add_west_window_bay(prefix: String, x_face: float, y: float, z: float, width_z: float, height_y: float, columns: int, rows: int) -> void:
	_add_box("%s_Recess" % prefix, Vector3(x_face - 0.18, y, z), Vector3(0.18, height_y, width_z), MaterialSlot.DARK)
	_add_box("%s_Header" % prefix, Vector3(x_face - 0.32, y + height_y * 0.5 + 0.18, z), Vector3(0.28, 0.22, width_z + 0.55), MaterialSlot.TRIM)
	_add_box("%s_Sill" % prefix, Vector3(x_face - 0.34, y - height_y * 0.5 - 0.18, z), Vector3(0.34, 0.24, width_z + 0.7), MaterialSlot.TRIM)
	for column in range(columns):
		for row in range(rows):
			var z_offset := lerpf(-width_z * 0.32, width_z * 0.32, float(column) / float(maxi(columns - 1, 1)))
			var y_offset := lerpf(-height_y * 0.25, height_y * 0.25, float(row) / float(maxi(rows - 1, 1)))
			_add_box("%s_Pane_%02d_%02d" % [prefix, column, row], Vector3(x_face - 0.38, y + y_offset, z + z_offset), Vector3(0.08, height_y / rows * 0.5, width_z / columns * 0.48), MaterialSlot.WINDOW)
	for column in range(columns + 1):
		var z_offset := lerpf(-width_z * 0.5, width_z * 0.5, float(column) / float(maxi(columns, 1)))
		_add_box("%s_Mullion_%02d" % [prefix, column], Vector3(x_face - 0.36, y, z + z_offset), Vector3(0.12, height_y * 0.92, 0.12), MaterialSlot.TRIM)


func _add_north_window_bay(prefix: String, x: float, y: float, z_face: float, width_x: float, height_y: float, columns: int, rows: int) -> void:
	_add_box("%s_Recess" % prefix, Vector3(x, y, z_face - 0.18), Vector3(width_x, height_y, 0.18), MaterialSlot.DARK)
	_add_box("%s_Header" % prefix, Vector3(x, y + height_y * 0.5 + 0.18, z_face - 0.32), Vector3(width_x + 0.55, 0.22, 0.28), MaterialSlot.TRIM)
	_add_box("%s_Sill" % prefix, Vector3(x, y - height_y * 0.5 - 0.18, z_face - 0.34), Vector3(width_x + 0.7, 0.24, 0.34), MaterialSlot.TRIM)
	for column in range(columns):
		for row in range(rows):
			var x_offset := lerpf(-width_x * 0.32, width_x * 0.32, float(column) / float(maxi(columns - 1, 1)))
			var y_offset := lerpf(-height_y * 0.25, height_y * 0.25, float(row) / float(maxi(rows - 1, 1)))
			_add_box("%s_Pane_%02d_%02d" % [prefix, column, row], Vector3(x + x_offset, y + y_offset, z_face - 0.38), Vector3(width_x / columns * 0.48, height_y / rows * 0.5, 0.08), MaterialSlot.WINDOW)
	for column in range(columns + 1):
		var x_offset := lerpf(-width_x * 0.5, width_x * 0.5, float(column) / float(maxi(columns, 1)))
		_add_box("%s_Mullion_%02d" % [prefix, column], Vector3(x + x_offset, y, z_face - 0.36), Vector3(0.12, height_y * 0.92, 0.12), MaterialSlot.TRIM)


func _add_west_awning(prefix: String, x_face: float, y: float, z: float, width_z: float, depth_x: float) -> void:
	_add_box("%s_Slab" % prefix, Vector3(x_face - depth_x * 0.5, y, z), Vector3(depth_x, 0.22, width_z), MaterialSlot.AWNING)
	_add_box("%s_FrontLip" % prefix, Vector3(x_face - depth_x, y - 0.24, z), Vector3(0.22, 0.42, width_z + 0.22), MaterialSlot.TRIM)
	for z_offset in [-width_z * 0.42, width_z * 0.0, width_z * 0.42]:
		_add_box("%s_Bracket_%s" % [prefix, str(z_offset)], Vector3(x_face - depth_x * 0.55, y - 0.85, z + z_offset), Vector3(0.12, 1.25, 0.12), MaterialSlot.RAIL)


func _add_north_awning(prefix: String, x: float, y: float, z_face: float, width_x: float, depth_z: float) -> void:
	_add_box("%s_Slab" % prefix, Vector3(x, y, z_face - depth_z * 0.5), Vector3(width_x, 0.22, depth_z), MaterialSlot.AWNING)
	_add_box("%s_FrontLip" % prefix, Vector3(x, y - 0.24, z_face - depth_z), Vector3(width_x + 0.22, 0.42, 0.22), MaterialSlot.TRIM)
	for x_offset in [-width_x * 0.42, 0.0, width_x * 0.42]:
		_add_box("%s_Bracket_%s" % [prefix, str(x_offset)], Vector3(x + x_offset, y - 0.85, z_face - depth_z * 0.55), Vector3(0.12, 1.25, 0.12), MaterialSlot.RAIL)


func _add_west_service_opening(prefix: String, x_face: float, y: float, z: float, width_z: float, height_y: float) -> void:
	_add_box("%s_DarkOpening" % prefix, Vector3(x_face - 0.35, y, z), Vector3(0.12, height_y, width_z), MaterialSlot.DARK)
	_add_box("%s_DoorPlate" % prefix, Vector3(x_face - 0.5, y - 0.15, z), Vector3(0.08, height_y * 0.82, width_z * 0.7), MaterialSlot.SERVICE)
	_add_box("%s_FrameTop" % prefix, Vector3(x_face - 0.52, y + height_y * 0.5 + 0.15, z), Vector3(0.28, 0.3, width_z + 0.5), MaterialSlot.TRIM)
	_add_box("%s_FrameLeft" % prefix, Vector3(x_face - 0.52, y, z - width_z * 0.5 - 0.18), Vector3(0.24, height_y + 0.25, 0.22), MaterialSlot.TRIM)
	_add_box("%s_FrameRight" % prefix, Vector3(x_face - 0.52, y, z + width_z * 0.5 + 0.18), Vector3(0.24, height_y + 0.25, 0.22), MaterialSlot.TRIM)


func _add_north_service_opening(prefix: String, x: float, z_face: float, y: float, width_x: float, height_y: float) -> void:
	_add_box("%s_DarkOpening" % prefix, Vector3(x, y, z_face - 0.35), Vector3(width_x, height_y, 0.12), MaterialSlot.DARK)
	_add_box("%s_DoorPlate" % prefix, Vector3(x, y - 0.15, z_face - 0.5), Vector3(width_x * 0.7, height_y * 0.82, 0.08), MaterialSlot.SERVICE)
	_add_box("%s_FrameTop" % prefix, Vector3(x, y + height_y * 0.5 + 0.15, z_face - 0.52), Vector3(width_x + 0.5, 0.3, 0.28), MaterialSlot.TRIM)
	_add_box("%s_FrameLeft" % prefix, Vector3(x - width_x * 0.5 - 0.18, y, z_face - 0.52), Vector3(0.22, height_y + 0.25, 0.24), MaterialSlot.TRIM)
	_add_box("%s_FrameRight" % prefix, Vector3(x + width_x * 0.5 + 0.18, y, z_face - 0.52), Vector3(0.22, height_y + 0.25, 0.24), MaterialSlot.TRIM)


func _add_west_balcony(prefix: String, x_face: float, y: float, z: float, width_z: float, depth_x: float) -> void:
	_add_box("%s_Platform" % prefix, Vector3(x_face - depth_x * 0.5, y - 0.15, z), Vector3(depth_x, 0.25, width_z), MaterialSlot.SERVICE)
	_add_box("%s_FrontRail" % prefix, Vector3(x_face - depth_x, y + 0.55, z), Vector3(0.14, 1.1, width_z), MaterialSlot.RAIL)
	_add_box("%s_LeftRail" % prefix, Vector3(x_face - depth_x * 0.5, y + 0.55, z - width_z * 0.5), Vector3(depth_x, 1.0, 0.12), MaterialSlot.RAIL)
	_add_box("%s_RightRail" % prefix, Vector3(x_face - depth_x * 0.5, y + 0.55, z + width_z * 0.5), Vector3(depth_x, 1.0, 0.12), MaterialSlot.RAIL)


func _add_north_catwalk(prefix: String, x: float, y: float, z_face: float, width_x: float, depth_z: float) -> void:
	_add_box("%s_Platform" % prefix, Vector3(x, y - 0.18, z_face - depth_z * 0.5), Vector3(width_x, 0.25, depth_z), MaterialSlot.SERVICE)
	_add_box("%s_FrontRail" % prefix, Vector3(x, y + 0.55, z_face - depth_z), Vector3(width_x, 1.05, 0.14), MaterialSlot.RAIL)
	for x_offset in [-width_x * 0.42, -width_x * 0.2, 0.0, width_x * 0.2, width_x * 0.42]:
		_add_box("%s_Post_%s" % [prefix, str(x_offset)], Vector3(x + x_offset, y + 0.35, z_face - depth_z), Vector3(0.16, 1.5, 0.16), MaterialSlot.RAIL)


func _add_roof_hut(prefix: String, world_pos: Vector3, size: Vector3) -> void:
	_add_box("%s_Body" % prefix, world_pos, size, MaterialSlot.ROOF)
	_add_box("%s_Cap" % prefix, world_pos + Vector3(0.0, size.y * 0.55, 0.0), Vector3(size.x + 0.45, 0.22, size.z + 0.45), MaterialSlot.TRIM)
	_add_box("%s_Door" % prefix, world_pos + Vector3(-size.x * 0.5 - 0.06, -size.y * 0.12, 0.0), Vector3(0.1, size.y * 0.5, size.z * 0.36), MaterialSlot.DARK)


func _add_water_tank(prefix: String, world_pos: Vector3) -> void:
	_add_box("%s_StandA" % prefix, world_pos + Vector3(-0.7, -0.6, -0.7), Vector3(0.16, 1.2, 0.16), MaterialSlot.RAIL)
	_add_box("%s_StandB" % prefix, world_pos + Vector3(0.7, -0.6, -0.7), Vector3(0.16, 1.2, 0.16), MaterialSlot.RAIL)
	_add_box("%s_StandC" % prefix, world_pos + Vector3(-0.7, -0.6, 0.7), Vector3(0.16, 1.2, 0.16), MaterialSlot.RAIL)
	_add_box("%s_StandD" % prefix, world_pos + Vector3(0.7, -0.6, 0.7), Vector3(0.16, 1.2, 0.16), MaterialSlot.RAIL)
	_add_box("%s_Tank" % prefix, world_pos + Vector3(0.0, 0.35, 0.0), Vector3(2.1, 1.2, 2.1), MaterialSlot.SERVICE)
	_add_box("%s_Cap" % prefix, world_pos + Vector3(0.0, 1.05, 0.0), Vector3(2.35, 0.18, 2.35), MaterialSlot.TRIM)


func _add_antenna(prefix: String, world_pos: Vector3, height: float) -> void:
	_add_box("%s_Mast" % prefix, world_pos + Vector3(0.0, height * 0.5, 0.0), Vector3(0.14, height, 0.14), MaterialSlot.RAIL)
	_add_box("%s_CrossbarA" % prefix, world_pos + Vector3(0.0, height * 0.74, 0.0), Vector3(2.0, 0.08, 0.08), MaterialSlot.RAIL)
	_add_box("%s_CrossbarB" % prefix, world_pos + Vector3(0.0, height * 0.55, 0.0), Vector3(0.08, 0.08, 1.6), MaterialSlot.RAIL)


func _add_roof_units(prefix: String, start: Vector3, count: int, size: Vector3, step: Vector3) -> void:
	for i in range(count):
		var pos := start + step * float(i)
		var unit_size := size * Vector3(_rng.randf_range(0.82, 1.15), _rng.randf_range(0.75, 1.1), _rng.randf_range(0.8, 1.2))
		_add_box("%s_Unit_%02d" % [prefix, i], pos, unit_size, MaterialSlot.SERVICE)
		_add_box("%s_Cap_%02d" % [prefix, i], pos + Vector3(0.0, unit_size.y * 0.62, 0.0), Vector3(unit_size.x * 0.85, 0.12, unit_size.z * 0.85), MaterialSlot.TRIM)


func _add_pipe_run(node_prefix: String, start: Vector3, length: float, along_z: bool, vertical: bool = false) -> void:
	var segments := 4
	for i in range(segments):
		var t := float(i) / float(maxi(segments - 1, 1))
		var pos := start
		var size := Vector3(0.22, 0.22, length / segments * 0.78)
		if vertical:
			pos.y += (t - 0.5) * length
			size = Vector3(0.18, length / segments * 0.8, 0.18)
		elif along_z:
			pos.z += (t - 0.5) * length
		else:
			pos.x += (t - 0.5) * length
			size = Vector3(length / segments * 0.78, 0.22, 0.22)
		_add_box("%s_%02d" % [node_prefix, i], pos, size, MaterialSlot.SERVICE)


func _add_box(node_name: String, world_pos: Vector3, size: Vector3, material_slot: MaterialSlot) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size

	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = _materials[material_slot]
	instance.position = world_pos
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	instance.set_meta(GENERATED_META, true)
	add_child(instance)
	return instance


func _clear_generated() -> void:
	for child in get_children():
		if child.has_meta(GENERATED_META):
			child.queue_free()


func _build_materials() -> void:
	_materials[MaterialSlot.WALL] = _make_material(Color(0.13, 0.16, 0.18, 1.0), Color(0.0, 0.0, 0.0, 1.0), 0.0)
	_materials[MaterialSlot.TRIM] = _make_material(Color(0.055, 0.065, 0.075, 1.0), Color(0.0, 0.0, 0.0, 1.0), 0.0)
	_materials[MaterialSlot.DARK] = _make_material(Color(0.025, 0.03, 0.035, 1.0), Color(0.0, 0.0, 0.0, 1.0), 0.0)
	_materials[MaterialSlot.WINDOW] = _make_material(Color(0.08, 0.55, 0.75, 1.0), Color(0.02, 0.36, 0.62, 1.0), 1.8)
	_materials[MaterialSlot.SIGN] = _make_material(Color(0.92, 0.28, 0.78, 1.0), Color(0.75, 0.06, 0.54, 1.0), 2.4)
	_materials[MaterialSlot.SERVICE] = _make_material(Color(0.18, 0.15, 0.12, 1.0), Color(0.02, 0.015, 0.01, 1.0), 0.25)
	_materials[MaterialSlot.AWNING] = _make_material(Color(0.36, 0.08, 0.07, 1.0), Color(0.12, 0.015, 0.01, 1.0), 0.25)
	_materials[MaterialSlot.ROOF] = _make_material(Color(0.11, 0.115, 0.105, 1.0), Color(0.0, 0.0, 0.0, 1.0), 0.0)
	_materials[MaterialSlot.RAIL] = _make_material(Color(0.035, 0.04, 0.045, 1.0), Color(0.0, 0.0, 0.0, 1.0), 0.0)


func _make_material(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = 0.86
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material
