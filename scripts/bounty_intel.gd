extends Node
## BountyIntel — autoload. Tracks traits the player has learned about the target
## and compares them against crowd NPC identities (funnel system).

signal intel_updated(category: String, value: String, source: String)
signal intel_reset
signal evidence_verified(category: String, value: String, evidence_id: String)

const CATEGORIES := ["build", "appearance", "movement_tell", "location_habit", "scanner_signature"]

## Eye-visible narrowing axes the SWEEP filters on. Excludes `scanner_signature`
## (scanner-only, read by ANALYSIS) and `build` (shared by all candidates,
## non-narrowing). Keep in sync with 05_INVESTIGATION_LAYER_BRIDGE C.1.
const VISIBLE_AXES := ["appearance", "movement_tell", "location_habit"]

const CATEGORY_LABELS := {
	"build": "BUILD",
	"appearance": "APPEARANCE",
	"movement_tell": "MOVEMENT",
	"location_habit": "HABIT",
	"scanner_signature": "SIG",
}

## category -> { "value": String, "source": String }
var known: Dictionary = {}
var evidence_log: Array[Dictionary] = []


func reset() -> void:
	if known.is_empty() and evidence_log.is_empty():
		return
	known.clear()
	evidence_log.clear()
	intel_reset.emit()


func learn(category: String, value: String, source: String = "") -> void:
	if not CATEGORIES.has(category) or value.is_empty():
		return
	if known.has(category) and known[category]["value"] == value:
		return
	known[category] = {"value": value, "source": source}
	intel_updated.emit(category, value, source)
	print("Intel learned [%s]: %s (via %s)" % [category, value, source])


func verify_from_evidence(
	category: String,
	value: String,
	evidence_id: String,
	source_id: String = ""
) -> void:
	if not CATEGORIES.has(category) or value.is_empty() or evidence_id.is_empty():
		return
	for entry in evidence_log:
		if String(entry.get("evidence_id", "")) == evidence_id:
			return
	evidence_log.append({
		"category": category,
		"value": value,
		"evidence_id": evidence_id,
		"source": source_id,
	})
	learn(category, value, "evidence: %s" % evidence_id)
	evidence_verified.emit(category, value, evidence_id)


func get_evidence_log() -> Array[Dictionary]:
	return evidence_log.duplicate(true)


func knows(category: String) -> bool:
	return known.has(category)


## How many VISIBLE narrowing traits the player has learned (sweep gate).
func known_visible_count() -> int:
	var n := 0
	for category in VISIBLE_AXES:
		if known.has(category):
			n += 1
	return n


## SWEEP comparison: does this NPC still match EVERY visible trait the player
## currently knows? (i.e. not yet eliminated on a known visible axis.)
## Gate: returns false when zero visible traits are known — the sweep is inert
## until the player has done some investigation. Signature is never consulted.
func visible_match(npc: Node) -> bool:
	if known_visible_count() == 0:
		return false
	for category in VISIBLE_AXES:
		if not known.has(category):
			continue
		var npc_value: String = _npc_trait(npc, category)
		if npc_value.is_empty():
			continue
		if known[category]["value"] != npc_value:
			return false
	return true


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
