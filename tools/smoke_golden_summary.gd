extends "res://tools/test_harness.gd"
##
## The regression net for the architecture rewrite.
##
## For every fixture in tests/fixtures/characters/, normalizing and summarizing
## it must produce byte-identical output to the snapshot in tests/golden/.
## Two of the fixtures are real saved characters, so this is what guarantees
## months of actual play data still loads and computes the same way.
##
## If this fails, read the reported paths before doing anything else. Recapture
## (tools/capture_golden.gd) only once every line of the diff is a change you
## intended.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")
const Support := preload("res://tools/golden_support.gd")


func _init() -> void:
	begin("summary golden snapshots")

	var names := Support.fixture_names()
	if not check(not names.is_empty(), "found fixtures in %s" % Support.FIXTURE_DIR):
		finish()
		return

	for name in names:
		_compare(name)

	_check_determinism(names)

	finish()


func _compare(name: String) -> void:
	var golden_text := _read_text(Support.golden_path(name))
	if not check(
		golden_text != "",
		"golden exists for %s (run tools/capture_golden.gd)" % name
	):
		return

	var character = Support.load_json(Support.fixture_path(name))
	if not check(typeof(character) == TYPE_DICTIONARY, "%s parses as a Dictionary" % name):
		return

	# Fresh rules per fixture: the summary cache is a single slot on the
	# instance, so a shared one would let fixtures mask each other.
	var rules = RulesScript.new()
	rules.load_core_data()
	var actual := Support.snapshot(rules, character)
	var actual_text := Support.serialize(actual)

	if actual_text == golden_text:
		check(true, "%s matches its golden snapshot" % name)
		return

	# Byte mismatch: report where, not just that.
	#
	# Both sides are parsed back from their serialized form before diffing.
	# Godot's JSON parser yields a float for every number, so diffing the live
	# Dictionary against the parsed golden would report an int-vs-float "change"
	# on every integer field and bury the real difference. The text comparison
	# above is the authoritative check; this is purely diagnostic.
	var expected = JSON.parse_string(golden_text)
	var differences := Support.diff(expected, JSON.parse_string(actual_text))
	if differences.is_empty():
		# Same structure, different bytes: formatting or float precision.
		fail("%s: serialized output changed but no structural difference found" % name)
		return

	fail("%s: %d difference(s) from golden" % [name, differences.size()])
	for line in differences.slice(0, 12):
		printerr("        %s" % line)
	if differences.size() > 12:
		printerr("        ... and %d more" % (differences.size() - 12))


## summary() must be a pure function of the character. Running it twice on
## separate instances has to agree, or the goldens would be capturing noise
## (unsorted iteration, unseeded randomness, leaked cache state).
func _check_determinism(names: Array) -> void:
	var name := String(names[0])
	var texts: Array = []
	for _i in 2:
		var character = Support.load_json(Support.fixture_path(name))
		var rules = RulesScript.new()
		rules.load_core_data()
		texts.append(Support.serialize(Support.snapshot(rules, character)))
	check_eq(texts[0], texts[1], "%s summarizes identically across runs" % name)


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
