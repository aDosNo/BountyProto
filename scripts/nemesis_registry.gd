extends Node
## Nemesis-lite registry. Persists escaped targets as a small roster and mutates
## them for re-entry. Generator-independent: operates on trait_kit-shaped
## dictionaries (docs/design/01_TRAIT_FUNNEL_MATRIX.md) and is queried by the
## contract generator's nemesis-injection stage (docs/design/02, S1').
##
## Identity model: scanner_sig is the PERSISTENT anchor (it is the individual);
## narrowing traits MUTATE on re-entry (new disguise / turf / behavior). A tell
## earned by being WOUNDED persists and can worsen — the grudge made flesh.
##
## Registered as an autoload. BountyManager has record/clear hooks, but they are
## gated off until contract generation stamps targets with scanner_sig + trait_kit
## (see docs/design/03_NEMESIS_LITE.md "Integration points").

const SAVE_PATH := "user://nemesis_roster.save"
const MAX_ROSTER := 3        # [NICK] concurrent recurring rivals
const GRUDGE_MAX := 4        # [NICK] difficulty ceiling per nemesis

var _roster: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("nemesis_registry")
	_load()


# --- Recording (called when a target escapes alive) --------------------------

## profile: trait_kit-shaped dict of the target that got away
##   (expects at least scanner_sig; base_id/alias/appearance/movement_tell_id optional).
## encounter: { wounded: bool, district_id: String }
func record_escape(profile: Dictionary, encounter: Dictionary = {}) -> void:
	var sig := str(profile.get("scanner_sig", ""))
	if sig.is_empty():
		push_warning("NemesisRegistry: escape with no scanner_sig; ignored.")
		return

	var entry := _find(sig)
	if entry.is_empty():
		if _roster.size() >= MAX_ROSTER:
			_evict_lowest_grudge()
		entry = {
			"scanner_sig": sig,
			"base_id": profile.get("base_id", ""),
			"alias": profile.get("alias", "Unknown"),
			"grudge": 0,
			"times_escaped": 0,
			"physical_tell": null,
			"last_district": "",
			"last_appearance": profile.get("appearance", {}),
			"active_in_contract": false,
		}
		_roster.append(entry)

	entry["grudge"] = mini(int(entry["grudge"]) + 1, GRUDGE_MAX)
	entry["times_escaped"] = int(entry["times_escaped"]) + 1
	entry["last_district"] = str(encounter.get("district_id", entry.get("last_district", "")))
	entry["last_appearance"] = profile.get("appearance", entry.get("last_appearance", {}))
	entry["active_in_contract"] = false

	# Grudge made flesh: a wound becomes a permanent, carried physical tell.
	if bool(encounter.get("wounded", false)):
		entry["physical_tell"] = profile.get("movement_tell_id", entry.get("physical_tell"))

	_save()
	print("Nemesis recorded: %s (grudge %d, escapes %d)" % [entry["alias"], int(entry["grudge"]), int(entry["times_escaped"])])


# --- Injection (called by the generator's S1') -------------------------------

func has_pending_nemesis() -> bool:
	for e in _roster:
		if not bool(e.get("active_in_contract", false)):
			return true
	return false


## Pull a mutated trait_kit + difficulty bump for re-entry and mark the nemesis
## active so it isn't drawn into two contracts at once. Returns {} if none pending.
## Pools are the CURRENT district's legal trait values (generator supplies them),
## so mutation never picks a value this district can't render.
func roll_nemesis_entry(rng: RandomNumberGenerator, palette_pool: Array, location_pool: Array, movement_pool: Array) -> Dictionary:
	var entry := _next_pending()
	if entry.is_empty():
		return {}
	entry["active_in_contract"] = true
	_save()
	return _mutate_for_reentry(entry, rng, palette_pool, location_pool, movement_pool)


func _mutate_for_reentry(entry: Dictionary, rng: RandomNumberGenerator, palette_pool: Array, location_pool: Array, movement_pool: Array) -> Dictionary:
	var grudge := int(entry["grudge"])
	var last_palette = (entry.get("last_appearance", {}) as Dictionary).get("palette_id", null)

	var kit := {
		"scanner_sig": entry["scanner_sig"],            # persists — confirms it's them
		"base_id": entry["base_id"],                    # persists — same build
		"appearance": {
			"palette_id": _pick_different(rng, palette_pool, last_palette),
			"overlay_ids": [],
		},
		"location_habit_id": _pick_any(rng, location_pool),
		# Physical tell (from a wound) persists; otherwise re-roll behaviorally.
		"movement_tell_id": entry["physical_tell"] if entry.get("physical_tell") != null else _pick_any(rng, movement_pool),
	}
	var bump := {
		"is_nemesis": true,
		"grudge": grudge,
		"difficulty_bonus": grudge,                     # generator maps -> k / n_*
		"force_complication": _grudge_complication(grudge),
		"alias": entry["alias"],
	}
	return {"trait_kit": kit, "nemesis": bump}


## Final capture/kill — the nemesis story ends, drop them from the roster.
func clear_nemesis(scanner_sig: String) -> void:
	for i in range(_roster.size()):
		if str(_roster[i].get("scanner_sig", "")) == scanner_sig:
			var gone: Dictionary = _roster[i]
			_roster.remove_at(i)
			_save()
			print("Nemesis cleared: %s (after %d escapes)" % [gone.get("alias", "?"), int(gone.get("times_escaped", 0))])
			return


# --- Helpers -----------------------------------------------------------------

func _grudge_complication(grudge: int) -> String:
	# Low grudge keeps it clean; a seasoned escapee brings protection.
	if grudge >= 4:
		return "rival"           # brings an escort hunter
	if grudge >= 3:
		return "bribed_faction"  # bought local muscle
	if grudge >= 2:
		return "double"          # uses a decoy to muddy the funnel
	return "none"


func _pick_any(rng: RandomNumberGenerator, pool: Array):
	if pool.is_empty():
		return null
	return pool[rng.randi_range(0, pool.size() - 1)]


func _pick_different(rng: RandomNumberGenerator, pool: Array, avoid):
	if pool.is_empty():
		return null
	if pool.size() == 1:
		return pool[0]
	var pick = avoid
	# Bounded retries; pool is tiny (4-6 palettes) so this resolves immediately.
	for _i in range(8):
		pick = pool[rng.randi_range(0, pool.size() - 1)]
		if pick != avoid:
			break
	return pick


func _find(scanner_sig: String) -> Dictionary:
	for e in _roster:
		if str(e.get("scanner_sig", "")) == scanner_sig:
			return e
	return {}


func _next_pending() -> Dictionary:
	# Highest grudge first — the angriest rival re-enters soonest.
	var best := {}
	var best_grudge := -1
	for e in _roster:
		if bool(e.get("active_in_contract", false)):
			continue
		if int(e.get("grudge", 0)) > best_grudge:
			best_grudge = int(e.get("grudge", 0))
			best = e
	return best


func _evict_lowest_grudge() -> void:
	if _roster.is_empty():
		return
	var worst_index := 0
	var worst_grudge := int(_roster[0].get("grudge", 0))
	for i in range(1, _roster.size()):
		if int(_roster[i].get("grudge", 0)) < worst_grudge:
			worst_grudge = int(_roster[i].get("grudge", 0))
			worst_index = i
	_roster.remove_at(worst_index)


# --- Persistence -------------------------------------------------------------

func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("NemesisRegistry: could not open save for write.")
		return
	file.store_string(var_to_str(_roster))
	file.close()


func _load() -> void:
	_roster.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var raw := file.get_as_text()
	file.close()
	var parsed = str_to_var(raw)
	if parsed is Array:
		for item in parsed:
			if item is Dictionary:
				_roster.append(item)
