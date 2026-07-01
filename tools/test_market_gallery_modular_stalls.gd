extends SceneTree

const ASSET_PATH := "res://assets/blender_models/Hesperus_Market2_Street_gallery.glb"
const MAP_PATH := "res://scenes/maps/HesperusMarket_Blockout.tscn"


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load(ASSET_PATH) as PackedScene
	_expect(packed != null, "updated street gallery imports", failures)
	if packed != null:
		var gallery := packed.instantiate()
		root.add_child(gallery)
		await process_frame
		for stall_id in ["01", "02", "03", "04", "05"]:
			_expect(
				gallery.find_child("GAL_ModularStall_%s" % stall_id, true, false) != null,
				"modular stall %s exists" % stall_id,
				failures
			)
		_expect(
			gallery.find_child("Stall_Canopy*", true, false) == null,
			"legacy stall canopies are removed",
			failures
		)
		_expect(
			gallery.find_child("Stall_Counter*", true, false) == null,
			"legacy stall counters are removed",
			failures
		)
		var modular_meshes := gallery.find_children("GAL_MS*", "MeshInstance3D", true, false)
		_expect(modular_meshes.size() >= 400, "complete modular stall geometry exported", failures)
		var proxies := gallery.find_children("GAL_collision_*", "MeshInstance3D", true, false)
		_expect(proxies.size() >= 100, "coarse set-piece collision proxies exported", failures)
		gallery.queue_free()

	var map_packed := load(MAP_PATH) as PackedScene
	_expect(map_packed != null, "Hesperus map loads", failures)
	if map_packed != null:
		var map := map_packed.instantiate()
		root.add_child(map)
		await process_frame
		var gallery := map.get_node_or_null("Hesperus_Market2_Street_gallery")
		_expect(gallery != null, "live map contains the street gallery", failures)
		if gallery != null:
			var proxies := gallery.find_children(
				"GAL_collision_*", "MeshInstance3D", true, false
			)
			var proxy := proxies[0] as MeshInstance3D if not proxies.is_empty() else null
			_expect(proxy != null and not proxy.visible,
				"live collision proxies are hidden", failures)
			_expect(
				proxy != null
					and not proxy.find_children("*", "StaticBody3D", true, false).is_empty(),
				"live collision proxies generate static bodies",
				failures
			)
		map.queue_free()

	if failures.is_empty():
		print("Street gallery modular stall replacement: PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
