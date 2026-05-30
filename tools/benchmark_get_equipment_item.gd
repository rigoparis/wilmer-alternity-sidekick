extends SceneTree

const RulesScript := preload("res://scripts/alternity_rules.gd")

func get_character_equipment_item_old(rules, character: Dictionary, item_id: String) -> Dictionary:
	var catalog_item: Dictionary = rules.equipment._get_parent().get_equipment_item_by_id(item_id)
	if not catalog_item.is_empty():
		return catalog_item
	var equipment: Dictionary = character.get("equipment", {})
	for item in equipment.get("custom_items", []):
		if typeof(item) == TYPE_DICTIONARY and String(item.get("id", "")) == item_id:
			return item
	return {}


func _init() -> void:
	var rules = RulesScript.new()
	rules.load_core_data()
	var character := rules.default_character()
	rules.ensure_character_shape(character)

	# Add a bunch of custom items to make the list long
	for i in range(1000):
		var id = "custom_item_" + str(i)
		character.equipment.custom_items.append({"id": id, "name": "Item " + str(i)})

	var start_time = Time.get_ticks_usec()
	for i in range(1000):
		# Lookup an item that is not in the catalog
		# We'll look up items at the end of the array to maximize linear search time
		var id = "custom_item_" + str(900 + (i % 100))
		rules.equipment.get_character_equipment_item(character, id)

	var end_time = Time.get_ticks_usec()
	var diff_new = end_time - start_time
	print("Benchmark get_character_equipment_item (NEW) took: ", diff_new, " usec")

	start_time = Time.get_ticks_usec()
	for i in range(1000):
		# Lookup an item that is not in the catalog
		var id = "custom_item_" + str(900 + (i % 100))
		get_character_equipment_item_old(rules, character, id)

	end_time = Time.get_ticks_usec()
	var diff_old = end_time - start_time
	print("Benchmark get_character_equipment_item (OLD) took: ", diff_old, " usec")

	quit()
