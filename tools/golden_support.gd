extends RefCounted
##
## Shared helpers for the summary() golden-snapshot regression.
##
## Both tools/capture_golden.gd and tools/smoke_golden_summary.gd go through
## here so the captured snapshot and the compared snapshot cannot drift apart.
##

const FIXTURE_DIR := "res://tests/fixtures/characters"
const GOLDEN_DIR := "res://tests/golden"


## Fixture base names, sorted so runs are reproducible.
static func fixture_names() -> Array:
	var names: Array = []
	var dir := DirAccess.open(FIXTURE_DIR)
	if dir == null:
		return names
	for file_name in dir.get_files():
		if file_name.ends_with(".json"):
			names.append(file_name.get_basename())
	names.sort()
	return names


static func load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


static func fixture_path(name: String) -> String:
	return "%s/%s.json" % [FIXTURE_DIR, name]


static func golden_path(name: String) -> String:
	return "%s/%s.json" % [GOLDEN_DIR, name]


## Normalize a fixture and summarize it.
##
## Captures both halves deliberately: "normalized" proves ensure_character_shape
## still migrates a stored file the same way, and "summary" proves the computed
## results are unchanged. A refactor that alters either is a regression.
##
## Order matters -- summary() calls ensure_character_shape() internally and also
## writes achievement_points_available back onto the character, so the
## normalized copy is taken after summarizing to capture the settled state.
static func snapshot(rules, character: Dictionary) -> Dictionary:
	rules.ensure_character_shape(character)
	var summary: Dictionary = rules.summary(character)
	var normalized := character.duplicate(true)
	# Transient memo written onto the character by the equipment module; never
	# part of the saved shape.
	if typeof(normalized.get("equipment")) == TYPE_DICTIONARY:
		normalized["equipment"].erase("_custom_items_by_id")
	return {
		"normalized": normalized,
		"summary": summary.duplicate(true),
	}


## Canonical serialization. sort_keys makes dictionary ordering irrelevant.
static func serialize(snapshot_data: Dictionary) -> String:
	return JSON.stringify(snapshot_data, "\t", true) + "\n"


## Serialized form with numeric types normalized, for comparing a live value
## against one parsed back from a golden file.
##
## Godot's JSON parser returns a float for every number, so a live Dictionary
## holding int 9 and the same value parsed from disk (9.0) serialize as "9" and
## "9.0". Pushing both through an encode/decode cycle puts them in the same
## representation, so a comparison reports real differences only.
static func canonical(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)), "\t", true)


## Recursively collect human-readable differences, most useful first.
## Returns paths like: summary/durability/stun
static func diff(expected: Variant, actual: Variant, path: String = "") -> Array:
	var out: Array = []
	var label := path if path != "" else "(root)"

	if typeof(expected) != typeof(actual):
		out.append("%s: type %s -> %s" % [label, type_string(typeof(expected)), type_string(typeof(actual))])
		return out

	if typeof(expected) == TYPE_DICTIONARY:
		var keys: Array = expected.keys()
		keys.sort()
		for key in keys:
			if not actual.has(key):
				out.append("%s/%s: key removed" % [label, key])
			else:
				out.append_array(diff(expected[key], actual[key], "%s/%s" % [path, key]))
		var added: Array = actual.keys()
		added.sort()
		for key in added:
			if not expected.has(key):
				out.append("%s/%s: key added (%s)" % [label, key, _brief(actual[key])])
		return out

	if typeof(expected) == TYPE_ARRAY:
		if expected.size() != actual.size():
			out.append("%s: size %d -> %d" % [label, expected.size(), actual.size()])
			return out
		for i in expected.size():
			out.append_array(diff(expected[i], actual[i], "%s[%d]" % [path, i]))
		return out

	if expected != actual:
		out.append("%s: %s -> %s" % [label, _brief(expected), _brief(actual)])
	return out


static func _brief(value: Variant) -> String:
	var text := JSON.stringify(value)
	if text.length() > 80:
		return text.substr(0, 77) + "..."
	return text
