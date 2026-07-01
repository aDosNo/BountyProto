extends Node
## Persistent, district-scoped world state.
##
## Keys are stable namespaced strings such as `hesperus.arcade.power`.
## Values are JSON-compatible and survive scene reloads and full restarts.

signal state_changed(state_id: String, value: Variant)

const SAVE_PATH := "user://district_state.json"
const CONTRACT_PREFIX := "hesperus.contract."

var _state: Dictionary = {}


func _ready() -> void:
	_load()


func get_state(state_id: String, default_value: Variant = null) -> Variant:
	return _state.get(state_id, default_value)


func set_state(state_id: String, value: Variant) -> void:
	if state_id.is_empty():
		return
	if _state.get(state_id) == value:
		return
	_state[state_id] = value
	_save()
	state_changed.emit(state_id, value)


func has_flag(state_id: String) -> bool:
	return bool(_state.get(state_id, false))


func set_flag(state_id: String, active: bool = true) -> void:
	set_state(state_id, active)


func erase_state(state_id: String) -> void:
	if not _state.erase(state_id):
		return
	_save()
	state_changed.emit(state_id, null)


func clear_prefix(prefix: String) -> void:
	var changed := false
	for state_id in _state.keys():
		if String(state_id).begins_with(prefix):
			_state.erase(state_id)
			changed = true
	if changed:
		_save()


## Starts a fresh bounty run without erasing district consequences, completed
## activities, or credentials earned in Hesperus.
func reset_contract_state() -> void:
	clear_prefix(CONTRACT_PREFIX)


func snapshot(prefix: String = "") -> Dictionary:
	if prefix.is_empty():
		return _state.duplicate(true)
	var result := {}
	for state_id in _state:
		if String(state_id).begins_with(prefix):
			result[state_id] = _state[state_id]
	return result


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("DistrictState could not write %s." % SAVE_PATH)
		return
	file.store_string(JSON.stringify(_state))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("DistrictState could not read %s." % SAVE_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_state = parsed
