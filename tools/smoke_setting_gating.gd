extends "res://tools/test_harness.gd"
##
## Optional-setting content must only appear when its setting is selected.
##
## This is the failure mode worth guarding: a view that forgets the check does
## not error, it just quietly offers Dark Matter content in a Core campaign.
## Nothing else would notice.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")
const Doc := preload("res://scripts/core/character_doc.gd")

var _rules: AlternityRules


func _init() -> void:
	begin("setting gating")

	_rules = RulesScript.new()
	_rules.load_core_data()

	_test_matcher()
	_test_entry_helper()
	_test_catalog_filtering()
	_test_gated_content_exists()
	_test_switching_setting_changes_availability()

	finish()


func _character(setting: String) -> Dictionary:
	var doc := Doc.new(_rules)
	doc.apply([CharacterDoc.META], func(c): c["setting"] = setting)
	return doc.raw()


func _test_matcher() -> void:
	var core := _character("Core")
	var dark := _character("Dark*Matter")

	# Content with no setting is always available.
	check_true(_rules.is_setting_available(core, ""), "ungated content is available in Core")
	check_true(_rules.is_setting_available(core, "Core"), "Core content is available in Core")

	check_false(_rules.is_setting_available(core, "Dark*Matter"), "Dark Matter content is hidden in Core")
	check_true(_rules.is_setting_available(dark, "Dark*Matter"), "Dark Matter content shows in Dark Matter")

	# Stored values vary in spelling, so the matcher has to tolerate both.
	check_true(
		_rules.is_setting_available(_character("Dark Matter"), "Dark*Matter"),
		"a space-spelled stored setting still matches"
	)
	check_true(
		_rules.is_setting_available(dark, "Dark Matter"),
		"a space-spelled required setting still matches"
	)

	check_false(_rules.is_setting_available(core, "Star*Drive"), "Star Drive content is hidden in Core")
	check_true(_rules.is_setting_available(_character("Star*Drive"), "Star*Drive"), "Star Drive content shows in Star Drive")


## The helper the migrated tabs call, so each one does not re-derive the idiom.
func _test_entry_helper() -> void:
	var core := _character("Core")
	var dark := _character("Dark*Matter")

	check_true(_rules.is_entry_available(core, {}), "an entry with no setting field is available")
	check_true(_rules.is_entry_available(core, {"setting": ""}), "an empty setting is available")
	check_false(_rules.is_entry_available(core, {"setting": "Dark*Matter"}), "a gated entry is hidden in Core")
	check_true(_rules.is_entry_available(dark, {"setting": "Dark*Matter"}), "a gated entry shows in its setting")


func _test_catalog_filtering() -> void:
	var core := _character("Core")
	var dark := _character("Dark*Matter")
	var catalog := [
		{"id": "a", "name": "Always"},
		{"id": "b", "name": "Core only", "setting": "Core"},
		{"id": "c", "name": "Dark only", "setting": "Dark*Matter"},
		{"id": "d", "name": "Star only", "setting": "Star*Drive"},
	]

	var in_core := _rules.available_entries(core, catalog)
	var core_ids: Array = []
	for entry in in_core:
		core_ids.append(entry["id"])
	check_eq(core_ids, ["a", "b"], "Core sees only ungated and Core entries")

	var in_dark := _rules.available_entries(dark, catalog)
	var dark_ids: Array = []
	for entry in in_dark:
		dark_ids.append(entry["id"])
	check_eq(dark_ids, ["a", "b", "c"], "Dark Matter additionally sees its own entries")

	# Non-dictionary junk in a catalog must not crash the filter.
	check_eq(_rules.available_entries(core, ["nope", 42, {}]).size(), 1, "malformed catalog entries are skipped")


## The gating is only meaningful if gated content actually ships.
func _test_gated_content_exists() -> void:
	var gated: Array = []
	for broad in _rules.fx_broad_skills:
		if typeof(broad) == TYPE_DICTIONARY and not String(broad.get("setting", "")).is_empty():
			gated.append(String(broad.get("name", "?")))

	check_true(
		not gated.is_empty(),
		"the FX catalog contains setting-gated content (%s)" % str(gated.slice(0, 5))
	)


## End to end through the FX catalog, which is what a player would see.
func _test_switching_setting_changes_availability() -> void:
	var doc := Doc.new(_rules)

	doc.apply([CharacterDoc.META], func(c): c["setting"] = "Core")
	var core_broads: Array = _rules.fx.get_broad_skills_for_character(doc.raw())

	doc.apply([CharacterDoc.META], func(c): c["setting"] = "Dark*Matter")
	var dark_broads: Array = _rules.fx.get_broad_skills_for_character(doc.raw())

	check_true(
		dark_broads.size() > core_broads.size(),
		"Dark Matter offers more FX broads than Core (%d vs %d)" % [dark_broads.size(), core_broads.size()]
	)

	# And switching back hides them again, rather than leaving them unlocked.
	doc.apply([CharacterDoc.META], func(c): c["setting"] = "Core")
	check_eq(
		_rules.fx.get_broad_skills_for_character(doc.raw()).size(), core_broads.size(),
		"switching back to Core hides the gated content again"
	)
