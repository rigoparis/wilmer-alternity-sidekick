extends "res://tools/test_harness.gd"
##
## Every catalog item must survive the two presentation formatters without
## erroring and without producing an empty line.
##
## NOTE: _equipment_item_meta / _equipment_combat_line currently live in
## scripts/main.gd. When the Equipment tab is extracted (Phase 5) they move with
## it, and the two preloads plus MainScript.new() below become a reference to the
## new tab scene instead.
##

const MainScript := preload("res://scripts/main.gd")
const RulesScript := preload("res://scripts/alternity_rules.gd")


func _init() -> void:
	begin("equipment catalog formatting")

	var main := MainScript.new()
	main.rules = RulesScript.new()
	main.rules.load_core_data()

	var catalog: Array = main.rules.equipment_catalog
	check_true(catalog.size() > 100, "equipment catalog loaded (>100 items), got %d" % catalog.size())

	# Report at most a few offenders rather than one line per item across a
	# catalog of this size.
	var empty_meta: Array = []
	var combat_items := 0
	for item in catalog:
		var item_name := String(item.get("name", "?"))
		if String(main._equipment_item_meta(item)).strip_edges().is_empty():
			if empty_meta.size() < 5:
				empty_meta.append(item_name)
		if String(main._equipment_combat_line(item)).strip_edges() != "":
			combat_items += 1

	check_true(
		empty_meta.is_empty(),
		"every item yields a non-empty meta line (offenders: %s)" % str(empty_meta)
	)
	check_true(combat_items > 0, "at least some items produce a combat line, got %d" % combat_items)

	main.free()
	finish()
