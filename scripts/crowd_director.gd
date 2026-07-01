extends Node3D
## CrowdDirector — spawns the market crowd and deals identities for the funnel.
## Trait pools load from a JSON data file (default: res://data/crowd_traits_hesperus.json)
## so the post-sprint contract generator samples data, not code. Consts below are
## emergency fallbacks only.
## Spawn markers are grouped by name prefix (Spawn_Street_*, Spawn_Alley_*...)
## into corridor polylines. NPCs spawn scattered ALONG each corridor and stroll
## its full length, so the crowd reads as flowing market traffic.

signal crowd_ready(target_profile: Dictionary)

@export var npc_scene: PackedScene
@export var spawn_parent: NodePath
@export var trait_data_path: String = "res://data/crowd_traits_hesperus.json"
@export var total_npcs: int = 30
@export var candidate_count: int = 10
@export var corridor_half_width: float = 3.2
@export var personal_route_offset: float = 2.6
@export var spawn_jitter: float = 1.8
## Minimum distance between spawn positions so the crowd starts spread out.
@export var min_spawn_separation: float = 2.6
@export var rng_seed: int = 0  # 0 = random each run

# Emergency fallbacks if the data file is missing/corrupt.
const FALLBACK_BUILDS := ["korvaxi-class heavy", "slight frame", "avian-stock", "stocky terran"]
const FALLBACK_TARGET_BUILD := "korvaxi-class heavy"
const FALLBACK_APPEARANCES := ["red jacket", "grey coat", "tan wraps", "green vest", "black harness", "blue poncho"]
const FALLBACK_MOVEMENT_TELLS := ["limp", "fast walker", "shuffler", "steady pace"]
const FALLBACK_HABITS := ["dock side", "fountain loiterer", "alley edges", "stall browser"]
const FALLBACK_SIGNATURES := ["cybernetic arm", "clean", "masked bio-sig", "weapon under clothing"]
const FALLBACK_NAMES := ["DOCKHAND", "VENDOR", "HAULER", "BROKER", "SPICER", "WELDER", "COURIER",
	"SCRAPPER", "DRIFTER", "FIXER", "STEVEDORE", "TINKER", "RUNNER", "PILGRIM", "LOOKOUT",
	"GRAFTER", "PEDDLER", "LUGGER", "WATCHER", "TRADER"]

var rng := RandomNumberGenerator.new()
var target_profile: Dictionary = {}
var target_npc: Node = null

var _builds: Array = FALLBACK_BUILDS
var _target_build: String = FALLBACK_TARGET_BUILD
var _appearances: Array = FALLBACK_APPEARANCES
var _movement_tells: Array = FALLBACK_MOVEMENT_TELLS
var _habits: Array = FALLBACK_HABITS
var _signatures: Array = FALLBACK_SIGNATURES
var _target_signature_pool: Array = ["cybernetic arm", "weapon under clothing"]
var _noncandidate_signature: String = "clean"
## The target's known traits. Drives clue values + witness hints so the crowd
## funnel narrows toward the real target. In single-bounty phase this is the
## courtyard Korvaxi's profile (from the data file's funnel_profile).
var _funnel_profile: Dictionary = {}
## false (Option B, current): crowd is pure decoys, the scripted courtyard model
## is the only valid target. true (generator phase): a hidden crowd NPC is the
## target and confronting it hands off to the chase actor.
var _target_in_crowd: bool = false
## Hand-authored candidate trait-kits (Phase E, 05 doc). When non-empty, the
## candidate slots use THESE exact kits instead of independent rolls, so the
## decoy field is a constructed funnel (the generator's Venn step, done by hand).
## Each entry: {appearance, movement_tell, location_habit, scanner_signature,
## (optional) npc_name}. build defaults to target_build. Civilian filler still rolls.
var _authored_candidates: Array = []
var _names: Array = FALLBACK_NAMES
var _witness_hint_chance: float = 0.4
var _witness_categories: Array = ["appearance", "movement_tell", "location_habit"]
var _spawn_quotas: Dictionary = {}


func _ready() -> void:
	add_to_group("crowd_director")
	_load_trait_data()
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


## Loads trait pools from JSON. Falls back to consts on any failure.
func _load_trait_data() -> void:
	if not FileAccess.file_exists(trait_data_path):
		push_warning("CrowdDirector: trait data file missing at %s — using fallbacks." % trait_data_path)
		return
	var file := FileAccess.open(trait_data_path, FileAccess.READ)
	if file == null:
		push_warning("CrowdDirector: could not open %s — using fallbacks." % trait_data_path)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("CrowdDirector: %s is not valid JSON — using fallbacks." % trait_data_path)
		return

	_builds = _string_array(parsed, "builds", _builds)
	_appearances = _string_array(parsed, "appearances", _appearances)
	_movement_tells = _string_array(parsed, "movement_tells", _movement_tells)
	_habits = _string_array(parsed, "location_habits", _habits)
	_signatures = _string_array(parsed, "scanner_signatures", _signatures)
	_target_signature_pool = _string_array(parsed, "target_signature_pool", _target_signature_pool)
	_names = _string_array(parsed, "names", _names)
	var tb = parsed.get("target_build")
	if tb is String and not tb.is_empty():
		_target_build = tb
	var ncs = parsed.get("noncandidate_signature")
	if ncs is String and not ncs.is_empty():
		_noncandidate_signature = ncs
	var ft = parsed.get("funnel_profile")
	if ft is Dictionary and not (ft as Dictionary).is_empty():
		_funnel_profile = ft
	var tic = parsed.get("target_in_crowd")
	if tic is bool:
		_target_in_crowd = tic
	var whc = parsed.get("witness_hint_chance")
	if whc is float or whc is int:
		_witness_hint_chance = clampf(float(whc), 0.0, 1.0)
	_witness_categories = _string_array(parsed, "witness_categories", _witness_categories)
	var quotas = parsed.get("spawn_quotas")
	if quotas is Dictionary:
		_spawn_quotas = quotas
	var authored = parsed.get("authored_candidates")
	if authored is Array:
		_authored_candidates = []
		for entry in authored:
			if entry is Dictionary:
				_authored_candidates.append(entry)
	print("CrowdDirector: trait data loaded from %s" % trait_data_path)


func _string_array(source: Dictionary, key: String, fallback: Array) -> Array:
	var value = source.get(key)
	if value is Array and not (value as Array).is_empty():
		var out: Array = []
		for entry in value:
			if entry is String:
				out.append(entry)
		if not out.is_empty():
			return out
	return fallback


func _spawn_crowd() -> void:
	if npc_scene == null:
		push_warning("CrowdDirector: npc_scene not set.")
		return
	var corridors := _collect_corridors()
	if corridors.is_empty():
		push_warning("CrowdDirector: no spawn markers found under spawn_parent.")
		return

	var identities := _deal_identities()

	# Zone QUOTAS from data file (keyed by marker prefix e.g. "Spawn_Plaza").
	# Corridors without a quota share the remainder by marker count.
	var order: Array = []
	var remaining := identities.size()
	var leftovers: Array = []
	var leftover_markers := 0
	for key in corridors:
		if _spawn_quotas.has(key):
			var q: int = mini(int(_spawn_quotas[key]), remaining)
			for i in q:
				order.append(key)
			remaining -= q
		else:
			leftovers.append(key)
			leftover_markers += corridors[key].size()
	for key in leftovers:
		if remaining <= 0:
			break
		var share: int = mini(int(round(float(identities.size()) * float(corridors[key].size()) / float(maxi(leftover_markers, 1)))), remaining)
		for i in share:
			order.append(key)
		remaining -= share
	while remaining > 0:
		var biggest = corridors.keys()[0]
		for key in corridors:
			if corridors[key].size() > corridors[biggest].size():
				biggest = key
		order.append(biggest)
		remaining -= 1
	order.shuffle()

	var placed: Array[Vector3] = []
	for idx in range(mini(order.size(), identities.size())):
		var route := _build_personal_route(corridors[order[idx]], idx)
		var npc := npc_scene.instantiate()
		add_child(npc)
		npc.global_position = _spaced_spawn_point(route, placed) + Vector3(0, 0.1, 0)
		placed.append(npc.global_position)
		npc.rotate_y(rng.randf() * TAU)
		if npc.has_method("set_route"):
			npc.call("set_route", route, corridor_half_width, rng.randi_range(0, maxi(route.size() - 1, 0)))
		elif npc.has_method("set_corridor"):
			npc.call("set_corridor", route, corridor_half_width)
		if npc.has_method("apply_identity"):
			npc.call("apply_identity", identities[idx])
		if identities[idx].get("is_target", false):
			target_npc = npc


## Rejection-samples along the route until the point clears min_spawn_separation
## from every already-placed NPC (8 tries, then takes the last candidate).
func _spaced_spawn_point(route: Array, placed: Array[Vector3]) -> Vector3:
	var candidate := Vector3.ZERO
	for attempt in 8:
		candidate = _random_point_on(route) + _random_ground_jitter(spawn_jitter)
		var clear := true
		for p in placed:
			if candidate.distance_to(p) < min_spawn_separation:
				clear = false
				break
		if clear:
			return candidate
	return candidate


## Wrong accusation fallout: the target gets wary and keeps moving.
func spook_target() -> void:
	if target_npc != null and target_npc.has_method("spook"):
		target_npc.call("spook")


## Wrong accusation fallout: bystanders near the accused refuse to talk for a
## while. Loops the spawned crowd (our direct children) and clams civilians
## within `radius` of `origin`. Returns how many were silenced (for logging).
func clam_up_near(origin: Vector3, radius: float, duration: float) -> int:
	var count := 0
	for child in get_children():
		if not (child is Node3D) or not child.has_method("clam_up"):
			continue
		if (child as Node3D).global_position.distance_to(origin) <= radius:
			child.call("clam_up", duration)
			count += 1
	print("CrowdDirector: %d bystander(s) clammed up within %.0fm of a wrong accusation." % [count, radius])
	return count


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


func _build_personal_route(points: Array, index: int) -> Array[Vector3]:
	var route: Array[Vector3] = []
	if points.is_empty():
		return route
	if points.size() == 1:
		route.append(points[0])
		return route

	var side_sign := -1.0 if index % 2 == 0 else 1.0
	var route_offset := rng.randf_range(personal_route_offset * 0.35, personal_route_offset) * side_sign
	var stagger := rng.randf_range(-0.9, 0.9)

	for point_index in range(points.size()):
		var point: Vector3 = points[point_index]
		var tangent := _route_tangent(points, point_index)
		var side := tangent.normalized().cross(Vector3.UP)
		var wave := sin(float(point_index) * 1.37 + float(index) * 0.73) * 0.55
		var route_point := point + side * (route_offset + wave) + tangent.normalized() * stagger
		route_point.y = point.y
		route.append(route_point)

	if route.size() == 2:
		var a := route[0]
		var b := route[1]
		var tangent := (b - a)
		tangent.y = 0.0
		var side := Vector3.RIGHT
		if tangent.length_squared() > 0.001:
			side = tangent.normalized().cross(Vector3.UP)
		var mid_a := a.lerp(b, 0.34) + side * rng.randf_range(-personal_route_offset, personal_route_offset)
		var mid_b := a.lerp(b, 0.68) + side * rng.randf_range(-personal_route_offset, personal_route_offset)
		mid_a.y = a.lerp(b, 0.34).y
		mid_b.y = a.lerp(b, 0.68).y
		route.insert(1, mid_a)
		route.insert(2, mid_b)

	return route


func _route_tangent(points: Array, index: int) -> Vector3:
	var previous: Vector3 = points[maxi(index - 1, 0)]
	var next: Vector3 = points[mini(index + 1, points.size() - 1)]
	var tangent := next - previous
	tangent.y = 0.0
	if tangent.length_squared() < 0.001:
		tangent = Vector3.FORWARD
	return tangent


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


func _random_ground_jitter(radius: float) -> Vector3:
	var angle := rng.randf() * TAU
	var dist := rng.randf_range(0.0, radius)
	return Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)


func _deal_identities() -> Array:
	var identities: Array = []
	var used_names: Dictionary = {}

	# Build the target's known profile. With a funnel_profile in data (single
	# scripted bounty) it's LOCKED to the courtyard Korvaxi; otherwise rolled
	# (generator phase). This profile always drives clue values + witness hints.
	target_profile = {
		"npc_name": "",
		"build": _target_build,
		"appearance": _pick(_appearances),
		"movement_tell": _pick(_movement_tells),
		"location_habit": _pick(_habits),
		"scanner_signature": _pick(_target_signature_pool),
		"is_candidate": true,
		"is_target": true,
	}
	if not _funnel_profile.is_empty():
		for key in ["build", "appearance", "movement_tell", "location_habit", "scanner_signature"]:
			if _funnel_profile.has(key) and String(_funnel_profile[key]) != "":
				target_profile[key] = _funnel_profile[key]
		var fixed_name := String(_funnel_profile.get("npc_name", ""))
		if not fixed_name.is_empty():
			target_profile["npc_name"] = fixed_name
	if String(target_profile["npc_name"]).is_empty():
		target_profile["npc_name"] = _next_name(used_names)
	else:
		used_names[target_profile["npc_name"]] = true

	# Option B (target_in_crowd=false): the crowd carries NO is_target NPC — the
	# scripted courtyard model is the only valid target. The whole crowd is
	# candidates (share build, differ in >=1 trait from the profile) + civilians.
	# Generator phase (target_in_crowd=true): the target hides in the crowd.
	var reserved_candidates := candidate_count
	if _target_in_crowd:
		identities.append(target_profile)
		reserved_candidates -= 1

	var n_candidates: int = clampi(reserved_candidates, 0, total_npcs)
	if not _authored_candidates.is_empty():
		n_candidates = mini(n_candidates, _authored_candidates.size())
	for i in n_candidates:
		var ident: Dictionary
		if not _authored_candidates.is_empty():
			ident = _authored_candidate_kit(i, used_names)
		else:
			ident = {
				"npc_name": _next_name(used_names),
				"build": _target_build,
				"appearance": _pick(_appearances),
				"movement_tell": _pick(_movement_tells),
				"location_habit": _pick(_habits),
				"scanner_signature": _pick(_signatures),
				"is_candidate": true,
				"is_target": false,
			}
			# Guarantee every candidate differs from the target in >=1 trait so none
			# is an accidental perfect match (in Option B that would be a false target).
			if _matches_target(ident):
				var alt := _appearances.duplicate()
				alt.erase(target_profile["appearance"])
				if not alt.is_empty():
					ident["appearance"] = alt[rng.randi() % alt.size()]
		identities.append(ident)

	var other_builds := _builds.duplicate()
	other_builds.erase(_target_build)
	while identities.size() < total_npcs:
		var civilian := {
			"npc_name": _next_name(used_names),
			"build": other_builds[rng.randi() % other_builds.size()],
			"appearance": _pick(_appearances),
			"movement_tell": _pick(_movement_tells),
			"location_habit": _pick(_habits),
			"scanner_signature": _noncandidate_signature,
			"is_candidate": false,
			"is_target": false,
		}
		# Some civilians saw something: deal a witness hint about the target.
		# Never scanner_signature (scanner-only trait), never build (all candidates share it).
		if rng.randf() < _witness_hint_chance and not _witness_categories.is_empty():
			var category: String = _witness_categories[rng.randi() % _witness_categories.size()]
			if target_profile.has(category):
				civilian["witness_hint_category"] = category
				civilian["witness_hint_value"] = target_profile[category]
		identities.append(civilian)

	identities.shuffle()
	return identities


func _matches_target(ident: Dictionary) -> bool:
	for key in ["appearance", "movement_tell", "location_habit", "scanner_signature"]:
		if ident[key] != target_profile[key]:
			return false
	return true


## Builds one candidate identity from the hand-authored field (Phase E). Missing
## trait keys fall back to the target's value (so an entry can specify only what
## differs); build defaults to target_build; name auto-assigns unless authored.
func _authored_candidate_kit(index: int, used_names: Dictionary) -> Dictionary:
	var src: Dictionary = _authored_candidates[index]
	var ident := {
		"build": String(src.get("build", _target_build)),
		"appearance": String(src.get("appearance", target_profile["appearance"])),
		"movement_tell": String(src.get("movement_tell", target_profile["movement_tell"])),
		"location_habit": String(src.get("location_habit", target_profile["location_habit"])),
		"scanner_signature": String(src.get("scanner_signature", _noncandidate_signature)),
		"is_candidate": true,
		"is_target": false,
	}
	var authored_name := String(src.get("npc_name", ""))
	if authored_name.is_empty():
		ident["npc_name"] = _next_name(used_names)
	else:
		ident["npc_name"] = authored_name
		used_names[authored_name] = true
	return ident


func _sync_clues_to_target() -> void:
	for clue in get_tree().get_nodes_in_group("scanner_clue"):
		var cat = clue.get("intel_category")
		if cat is String and not cat.is_empty() and target_profile.has(cat):
			clue.set("intel_value", target_profile[cat])


func _pick(pool: Array) -> String:
	return pool[rng.randi() % pool.size()]


func _next_name(used: Dictionary) -> String:
	for attempt in 40:
		var name: String = _names[rng.randi() % _names.size()]
		if not used.has(name):
			used[name] = true
			return name
	var fallback := "CIVILIAN-%02d" % (used.size() + 1)
	used[fallback] = true
	return fallback
