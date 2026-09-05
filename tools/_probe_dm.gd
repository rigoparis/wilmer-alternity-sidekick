extends SceneTree

func _init() -> void:
	var rules = load("res://scripts/alternity_rules.gd").new()
	rules.load_core_data()
	for setting in ["Core", "Dark*Matter"]:
		var doc = load("res://scripts/core/character_doc.gd").new(rules)
		doc.apply([CharacterDoc.META], func(c): c["setting"] = setting)
		var raw = doc.raw()
		print("== ", setting)
		print("  fx broads:      ", rules.fx.get_broad_skills_for_character(raw).size())
		print("  perks:          ", rules.available_entries(raw, rules.perks_by_id.values()).size())
		print("  flaws:          ", rules.available_entries(raw, rules.flaws_by_id.values()).size())
		var specs := 0
		for b in rules.fx.get_broad_skills_for_character(raw):
			specs += rules.fx.get_specialty_skills_for_character(raw, String(b.get("name",""))).size()
		print("  fx specialties: ", specs)
		print("  psionic broads: ", rules.get_psionic_broad_skills(raw).size() if rules.has_method("get_psionic_broad_skills") else "n/a")
		print("  species:        ", rules.species.size())
		print("  professions:    ", rules.professions.size())
	quit()
