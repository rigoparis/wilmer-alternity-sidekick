extends "res://tools/test_harness.gd"
##
## Captures the summary() golden snapshots that tools/smoke_golden_summary.gd
## compares against.
##
##     godot --headless --path . -s tools/capture_golden.gd
##
## Run this ONLY when a change to the computed results is intended. Recapturing
## to make a failing test pass discards the very protection the snapshot exists
## to provide -- read the reported diff first and confirm every line is a change
## you meant to make.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")
const Support := preload("res://tools/golden_support.gd")


func _init() -> void:
	begin("golden capture")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Support.GOLDEN_DIR))

	var names := Support.fixture_names()
	if not check(not names.is_empty(), "found fixtures in %s" % Support.FIXTURE_DIR):
		finish()
		return

	for name in names:
		var character = Support.load_json(Support.fixture_path(name))
		if not check(typeof(character) == TYPE_DICTIONARY, "%s parses as a Dictionary" % name):
			continue

		# A fresh rules instance per fixture: the summary cache is a single slot
		# on the instance, so sharing one would let fixtures affect each other.
		var rules = RulesScript.new()
		rules.load_core_data()

		var text := Support.serialize(Support.snapshot(rules, character))
		var out := FileAccess.open(Support.golden_path(name), FileAccess.WRITE)
		if not check(out != null, "can write golden for %s" % name):
			continue
		out.store_string(text)
		out.close()
		print("  captured %-32s %d bytes" % [name, text.length()])

	finish()
