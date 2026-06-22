extends Node
## BountyIntel — autoload. Tracks traits the player has learned about the target
## and compares them against crowd NPC identities (funnel system).

signal intel_updated(category: String, value: String, source: String)
signal intel_reset

const CATEGORIES := ["build", "appearance", "movement_tell", "location_habit", "scanner_signature"]

const CATEGORY_LABELS := {
	"build": "BUILD",
	"appearance": "APPEARANCE",
	"movement_tell": "MOVEMENT",
	"location_habit": "HABIT",
	"scanner_signature": "SIG",
}

## category -> { "value": String, "source": String }
var known: Dictionary = {}


func reset() -> void:
	if known.is_empty():
		return
	known.clear()
	intel_reset.emit()


func learn(category: String, value: String, source: String = "") -> void:
	if not CATEGORIES.has(category) or value.is_empty():
		return
	if known.has(category) and known[category]["value"] == value:
		return
	known[category] = {"value": value, "source": source}
	intel_updated.emit(category, value, source)
	print("Intel learned [%s]: %s (via %s)" % [category, value, source])


func knows(category: String) -> bool:
	return known.has(category)


func known_count() -> int:
	return known.size()


## Compares an NPC's traits against gathered intel.
## Returns { "matches": int, "known": int, "mismatches": int, "lines": Array[String] }
func match_report(npc: Node) -> Dictionary:
	var matches := 0
	var mismatches := 0
	var lines: Array[String] = []

	for category in CATEGORIES:
		var npc_value: String = _npc_trait(npc, category)
		if npc_value.is_empty():
			continue
		var label: String = CATEGORY_LABELS[category]
		if not known.has(category):
			lines.append("%s: UNKNOWN" % label)
			continue

		if known[category]["value"] == npc_value:
			matches += 1
			lines.append("%s: %s [MATCH]" % [label, npc_value])
		else:
			mismatches += 1
			lines.append("%s: %s [X]" % [label, npc_value])

	return {"matches": matches, "known": known.size(), "mismatches": mismatches, "lines": lines}


## One-line scan readout for HUD toast.
func build_readout(npc: Node) -> String:
	var report := match_report(npc)
	var npc_name := "SUBJECT"
	var name_value = npc.get("npc_name")
	if name_value is String and not name_value.is_empty():
		npc_name = name_value

	var header := "%s — %d/%d intel match" % [npc_name, report["matches"], report["known"]]
	if report["known"] > 0 and report["mismatches"] == 0 and report["matches"] == report["known"]:
		header += " — PROFILE FITS"
	var lines: Array[String] = report["lines"]
	return header + "\n" + "\n".join(lines)


func _npc_trait(npc: Node, category: String) -> String:
	var value = npc.get(category)
	if value is String:
		return value
	return ""
