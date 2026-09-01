extends "res://tools/test_harness.gd"
##
## Every catalog item must survive the two presentation formatters without
## erroring and without producing an empty line.
##
## Formatting now lives on the Equipment tab, so this drives that rather than
## main.gd, which no longer exists.
##

const TabEquipment := preload("res://scenes/ui/tabs/tab_equipment.tscn")
const RulesScript := preload("res://scripts/alternity_rules.gd")
const Doc := preload("res://scripts/core/character_doc.gd")
const Context := preload("res://scripts/ui/sheet_context.gd")


func _init() -> void:
	begin("equipment catalog formatting")

	var rules: AlternityRules = RulesScript.new()
	rules.load_core_data()

	var tab = TabEquipment.instantiate()
	tab.bind(Context.new(Doc.new(rules), rules, null, ThemePalette.new(), false))

	var catalog: Array = rules.equipment_catalog
	check_true(catalog.size() > 100, "equipment catalog loaded (>100 items), got %d" % catalog.size())

	# Report at most a few offenders rather than one line per item across a
	# catalog of this size.
	var empty_meta: Array = []
	var combat_items := 0
	for item in catalog:
		var item_name := String(item.get("name", "?"))
		var described := String(tab._describe(item)).strip_edges()
		if described.is_empty():
			if empty_meta.size() < 5:
				empty_meta.append(item_name)
		var combat = item.get("combat", null)
		if typeof(combat) == TYPE_DICTIONARY and not String(combat.get("damage", "")).strip_edges().is_empty():
			combat_items += 1

	check_true(
		empty_meta.is_empty(),
		"every item yields a non-empty meta line (offenders: %s)" % str(empty_meta)
	)
	check_true(combat_items > 0, "at least some items carry combat damage, got %d" % combat_items)

	tab.free()
	finish()
