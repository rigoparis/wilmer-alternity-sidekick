extends SceneTree

const MainScript := preload("res://scripts/main.gd")
const RulesScript := preload("res://scripts/alternity_rules.gd")


func _init() -> void:
	var main := MainScript.new()
	main.rules = RulesScript.new()
	main.rules.load_core_data()
	for item in main.rules.equipment_catalog:
		main._equipment_item_meta(item)
		main._equipment_combat_line(item)
	main.free()
	quit()
