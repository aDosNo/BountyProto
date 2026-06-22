extends Node
## HunterLedger — persistent credit account (autoload). Survives scene reloads
## (autoload lifetime) and full restarts (user:// save). This is the economy's
## spine: post-sprint, verb purchases (lockpicks, lures, disguises, permits,
## intel broker) all draw from here via spend().

signal credits_changed(total: int)

const SAVE_PATH := "user://hunter_ledger.json"

var credits: int = 0


func _ready() -> void:
	_load()
	print("HunterLedger: %d CR on account." % credits)


func add(amount: int) -> void:
	credits = maxi(credits + amount, 0)
	credits_changed.emit(credits)
	_save()
	print("Ledger: %+d CR (account: %d)." % [amount, credits])


func can_afford(amount: int) -> bool:
	return credits >= amount


## Returns false (and charges nothing) if the account can't cover it.
func spend(amount: int) -> bool:
	if amount <= 0 or not can_afford(amount):
		return false
	add(-amount)
	return true


func total() -> int:
	return credits


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"credits": credits}))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.has("credits"):
		credits = int(parsed["credits"])
