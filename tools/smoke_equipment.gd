extends SceneTree

const RulesScript := preload("res://scripts/alternity_rules.gd")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _init() -> void:
	var rules = RulesScript.new()
	rules.load_core_data()
	var character := rules.default_character()
	rules.ensure_character_shape(character)

	# Setup variables for testing
	var equipment: Dictionary = character.get("equipment", {})
	var carried: Array = equipment.get("carried", [])
	if not carried.is_empty():
		_fail("Character should start with empty equipment.")

	if rules.equipment_catalog.is_empty():
		_fail("Equipment catalog did not load.")

	var item_id: String = String(rules.equipment_catalog[0].get("id"))

	# Test adding valid item
	var line_id: String = rules.equipment.add_equipment_to_character(character, item_id, 2)
	equipment = character.get("equipment", {})
	carried = equipment.get("carried", [])

	if carried.size() != 1:
		_fail("Equipment was not added to the character.")

	var item: Dictionary = carried[0]
	if String(item.get("line_id", "")) != line_id:
		_fail("Line ID is incorrect.")
	if String(item.get("item_id", "")) != item_id:
		_fail("Item ID is incorrect.")
	if rules._as_int(item.get("quantity", 0)) != 2:
		_fail("Quantity is incorrect.")

	# Test adding invalid item
	var prev_carried_size := carried.size()
	var invalid_line_id: String = rules.equipment.add_equipment_to_character(character, "non_existent_item_id_12345", 1)

	equipment = character.get("equipment", {})
	carried = equipment.get("carried", [])

	if not invalid_line_id.is_empty():
		_fail("Adding an invalid item should return an empty string for line_id.")
	if carried.size() != prev_carried_size:
		_fail("Adding an invalid item should not modify the carried array size.")

	# Test quantity clamping
	var another_item_id: String = String(rules.equipment_catalog[1].get("id"))
	var clamped_line_id: String = rules.equipment.add_equipment_to_character(character, another_item_id, -5)

	equipment = character.get("equipment", {})
	carried = equipment.get("carried", [])

	if carried.size() != 2:
		_fail("Clamped item was not added to the character.")

	var clamped_item: Dictionary = carried[1]
	if String(clamped_item.get("line_id", "")) != clamped_line_id:
		_fail("Clamped item Line ID is incorrect.")
	if String(clamped_item.get("item_id", "")) != another_item_id:
		_fail("Clamped item Item ID is incorrect.")
	if rules._as_int(clamped_item.get("quantity", 0)) != 1:
		_fail("Quantity was not correctly clamped to 1. Got: %d" % rules._as_int(clamped_item.get("quantity", 0)))

	quit()
