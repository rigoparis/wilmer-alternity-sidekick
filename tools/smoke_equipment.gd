extends "res://tools/test_harness.gd"

const RulesScript := preload("res://scripts/alternity_rules.gd")


func _init() -> void:
	begin("equipment inventory")

	var rules = RulesScript.new()
	rules.load_core_data()
	var character := rules.default_character()
	rules.ensure_character_shape(character)

	var equipment: Dictionary = character.get("equipment", {})
	var carried: Array = equipment.get("carried", [])
	check_true(carried.is_empty(), "a new character carries nothing")
	check_false(rules.equipment_catalog.is_empty(), "equipment catalog loaded")

	# Adding a catalog item records line_id, item_id and quantity.
	var item_id: String = String(rules.equipment_catalog[0].get("id"))
	var line_id: String = rules.equipment.add_equipment_to_character(character, item_id, 2)
	carried = character.get("equipment", {}).get("carried", [])

	check_eq(carried.size(), 1, "item added to inventory")
	var item: Dictionary = carried[0]
	check_eq(String(item.get("line_id", "")), line_id, "line_id matches the returned handle")
	check_eq(String(item.get("item_id", "")), item_id, "item_id recorded")
	check_eq(rules._as_int(item.get("quantity", 0)), 2, "quantity recorded")

	# An unknown item id is rejected without touching the inventory.
	var prev_size := carried.size()
	var invalid_line_id: String = rules.equipment.add_equipment_to_character(
		character, "non_existent_item_id_12345", 1
	)
	carried = character.get("equipment", {}).get("carried", [])
	check_true(invalid_line_id.is_empty(), "unknown item id returns an empty line_id")
	check_eq(carried.size(), prev_size, "unknown item id leaves the inventory unchanged")

	# A non-positive quantity clamps up to 1 rather than storing a negative.
	var another_item_id: String = String(rules.equipment_catalog[1].get("id"))
	var clamped_line_id: String = rules.equipment.add_equipment_to_character(character, another_item_id, -5)
	carried = character.get("equipment", {}).get("carried", [])

	check_eq(carried.size(), 2, "second item added")
	var clamped: Dictionary = carried[1]
	check_eq(String(clamped.get("line_id", "")), clamped_line_id, "clamped item line_id matches")
	check_eq(String(clamped.get("item_id", "")), another_item_id, "clamped item item_id recorded")
	check_eq(rules._as_int(clamped.get("quantity", 0)), 1, "negative quantity clamps to 1")

	finish()
