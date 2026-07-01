extends SceneTree

func _init():
	var path := "res://scenes/maps/HesperusMarket_Blockout.tscn"
	var out := "/var/home/nick/bounty-hunt/_scene_check.txt"
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_line("checking: " + path)

	# Try loading the two materials first
	for mp in ["res://assets/materials/generated/M_Hesperus_WindowGlass_Warm.tres", "res://assets/materials/generated/M_Hesperus_WindowGlass_Cool.tres"]:
		var exists := ResourceLoader.exists(mp)
		f.store_line("material exists? %s -> %s" % [mp, str(exists)])
		if exists:
			var m = ResourceLoader.load(mp)
			f.store_line("  loaded: " + str(m))

	# Now try the scene
	var exists_scene := ResourceLoader.exists(path)
	f.store_line("scene exists? " + str(exists_scene))
	var ps = ResourceLoader.load(path)
	if ps == null:
		f.store_line("SCENE LOAD RETURNED NULL")
	else:
		f.store_line("SCENE LOADED OK: " + str(ps))
	f.flush()
	f.close()
	quit()
