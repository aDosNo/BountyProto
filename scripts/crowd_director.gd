extends Node3D
## CrowdDirector — spawns the market crowd and deals identities for the funnel.
## Spawn markers are grouped by name prefix (Spawn_Street_*, Spawn_Alley_*...)
## into corridor polylines. NPCs spawn scattered ALONG each corridor and stroll
## its full length, so the crowd reads as flowing market traffic.

signal crowd_ready(target_profile: Dictionary)

@export var npc_scene: PackedScene
@export var spawn_parent: NodePath
@export var total_npcs: int = 30
@export var candidate_count: int = 10
@export var corridor_half_width: float = 2.4
@export var rng_seed: int = 0  # 0 = random each run

const BUILDS := ["korvaxi-class heavy", "slight frame", "avian-stock", "stocky terran"]
const TARGET_BUILD := "korvaxi-class heavy"
const APPEARANCES := ["red jacket", "grey coat", "tan wraps", "green vest", "black harness", "blue poncho"]
const MOVEMENT_TELLS := ["limp", "fast walker", "shuffler", "steady pace"]
const HABITS := ["dock side", "fountain loiterer", "alley edges", "stall browser"]
const SIGNATURES := ["cybernetic arm", "clean", "masked bio-sig", "weapon under clothing"]
const NAMES := ["DOCKHAND", "VENDOR", "HAULER", "BROKER", "SPICER", "WELDER", "COURIER",
	"SCRAPPER", "DRIFTER", "FIXER", "STEVEDORE", "TINKER", "RUNNER", "PILGRIM", "LOOKOUT",
	"GRAFTER", "PEDDLER", "LUGGER", "WATCHER", "TRADER"]

var rng := RandomNumberGenerator.new()
var target_profile: Dictionary = {}
var target_npc: Node = null


func _ready() -> void:
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	await get_tree().process_frame
	_spawn_crowd()
	_sync_clues_to_target()
	crowd_ready.emit(target_profile)
	print("CrowdDirector: target is '%s' — %s / %s / %s / %s" % [
		target_profile.get("npc_name", "?"), target_profile.get("appearance", "?"),
		target_profile.get("movement_tell", "?"), target_profile.get("location_habit", "?"),
		target_profile.get("scanner_signature", "?")])


func _spawn_crowd() -> void:
	if npc_scene == null:
		push_warning("CrowdDirector: npc_scene not set.")
		return
	var corridors := _collect_corridors()
	if corridors.is_empty():
		push_warning("CrowdDirector: no spawn markers found under spawn_parent.")
		return

	# Weight corridors by marker count so a 2-marker alley gets a small share.
	var weighted: Array = []
	var total_markers := 0
	for key in corridors:
		total_markers += corridors[key].size()
	for key in corridors:
		var share := int(round(float(total_npcs) * float(corridors[key].size()) / float(total_markers)))
		weighted.append({"points": corridors[key], "count": share})

	var identities := _deal_identities()
	var idx := 0
	for entry in weighted:
		for i in entry["count"]:
			if idx >= identities.size():
				break
			var npc := npc_scene.instantiate()
			add_child(npc)
			npc.global_position = _random_point_on(entry["points"]) + Vector3(0, 0.1, 0)
			npc.rotate_y(rng.randf() * TAU)
			if npc.has_method("set_corridor"):
				npc.call("set_corridor", entry["points"], corridor_half_width)
			if npc.has_method("apply_identity"):
				npc.call("apply_identity", identities[idx])
			if identities[idx].get("is_target", false):
				target_npc = npc
			idx += 1


## Groups Marker3D children by name prefix (text before the trailing _NN).
func _collect_corridors() -> Dictionary:
	var corridors: Dictionary = {}
	var parent := get_node_or_null(spawn_parent)
	if parent == null:
		return corridors
	for child in parent.get_children():
		if not (child is Node3D):
			continue
		var prefix := String(child.name)
		var underscore := prefix.rfind("_")
		if underscore > 0:
			prefix = prefix.substr(0, underscore)
		if not corridors.has(prefix):
			corridors[prefix] = []
		corridors[prefix].append((child as Node3D).global_position)
	return corridors


## Random point along the polyline with lateral offset across street width.
func _random_point_on(points: Array) -> Vector3:
	if points.size() == 1:
		return points[0]
	var seg := rng.randi() % (points.size() - 1)
	var a: Vector3 = points[seg]
	var b: Vector3 = points[seg + 1]
	var p: Vector3 = a.lerp(b, rng.randf())
	var dir := (b - a)
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		var perp := dir.normalized().cross(Vector3.UP)
		p += perp * rng.randf_range(-corridor_half_width, corridor_half_width)
	return p


func _deal_identities() -> Array:
	var identities: Array = []
	var used_names: Dictionary = {}

	target_profile = {
		"npc_name": _next_name(used_names),
		"build": TARGET_BUILD,
		"appearance": _pick(APPEARANCES),
		"movement_tell": _pick(MOVEMENT_TELLS),
		"location_habit": _pick(HABITS),
		"scanner_signature": _pick(["cybernetic arm", "weapon under clothing"]),
		"is_candidate": true,
		"is_target": true,
	}
	identities.append(target_profile)

	var n_candidates: int = clampi(candidate_count, 1, total_npcs) - 1
	for i in n_candidates:
		var ident := {
			"npc_name": _next_name(used_names),
			"build": TARGET_BUILD,
			"appearance": _pick(APPEARANCES),
			"movement_tell": _pick(MOVEMENT_TELLS),
			"location_habit": _pick(HABITS),
			"scanner_signature": _pick(SIGNATURES),
			"is_candidate": true,
			"is_target": false,
		}
		if _matches_target(ident):
			var alt := APPEARANCES.duplicate()
			alt.erase(target_profile["appearance"])
			ident["appearance"] = alt[rng.randi() % alt.size()]
		identities.append(ident)

	var other_builds := BUILDS.duplicate()
	other_builds.erase(TARGET_BUILD)
	while identities.size() < total_npcs:
		identities.append({
			"npc_name": _next_name(used_names),
			"build": other_builds[rng.randi() % other_builds.size()],
			"appearance": _pick(APPEARANCES),
			"movement_tell": _pick(MOVEMENT_TELLS),
			"location_habit": _pick(HABITS),
			"scanner_signature": "clean",
			"is_candidate": false,
			"is_target": false,
		})

	identities.shuffle()
	return identities


func _matches_target(ident: Dictionary) -> bool:
	for key in ["appearance", "movement_tell", "location_habit", "scanner_signature"]:
		if ident[key] != target_profile[key]:
			return false
	return true


func _sync_clues_to_target() -> void:
	for clue in get_tree().get_nodes_in_group("scanner_clue"):
		var cat = clue.get("intel_category")
		if cat is String and not cat.is_empty() and target_profile.has(cat):
			clue.set("intel_value", target_profile[cat])


func _pick(pool: Array) -> String:
	return pool[rng.randi() % pool.size()]


func _next_name(used: Dictionary) -> String:
	for attempt in 40:
		var name: String = NAMES[rng.randi() % NAMES.size()]
		if not used.has(name):
			used[name] = true
			return name
	var fallback := "CIVILIAN-%02d" % (used.size() + 1)
	used[fallback] = true
	return fallback
