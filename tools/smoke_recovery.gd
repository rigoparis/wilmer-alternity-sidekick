extends "res://tools/test_harness.gd"
##
## Downtime recovery checks and Summary tab affordances.
##
## Source: Gamemaster Guide p. 54.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")
const Doc := preload("res://scripts/core/character_doc.gd")
const Context := preload("res://scripts/ui/sheet_context.gd")
const TAB_SUMMARY := preload("res://scenes/ui/tabs/tab_summary.tscn")

var _rules: AlternityRules


func _init() -> void:
	begin_async("downtime recovery", 600)
	_run.call_deferred()


func _run() -> void:
	_rules = RulesScript.new()
	_rules.load_core_data()

	_test_recovery_rules_data()
	await _test_recovery_ui_rendering()
	await _test_recovery_damage_application()

	finish()


## Assert all cadences, amounts, and skill mappings come from RECOVERY
## rather than being retyped. Source: Gamemaster Guide p. 54.
func _test_recovery_rules_data() -> void:
	var combat = _rules.combat
	var recovery: Dictionary = combat.RECOVERY

	check_eq(String(recovery["stun"]["cadence"]), "scene", "stun cadence is scene")
	check_eq(String(recovery["fatigue"]["cadence"]), "hour", "fatigue cadence is hour")
	check_eq(String(recovery["wound"]["cadence"]), "week", "wound cadence is week")
	check_eq(String(recovery["mortal"]["cadence"]), "never", "mortal cadence is never")

	check_true(combat.recovers_naturally("fatigue"), "fatigue recovers naturally")
	check_true(combat.recovers_naturally("wound"), "wound recovers naturally")
	check_false(combat.recovers_naturally("mortal"), "mortal does not recover naturally")

	# Recovery amounts by degree
	check_eq(combat.recovery_amount("fatigue", "marginal"), 0, "fatigue marginal recovers 0")
	check_eq(combat.recovery_amount("fatigue", "ordinary"), 1, "fatigue ordinary recovers 1")
	check_eq(combat.recovery_amount("fatigue", "good"), 2, "fatigue good recovers 2")
	check_eq(combat.recovery_amount("fatigue", "amazing"), 3, "fatigue amazing recovers 3")
	check_eq(combat.recovery_amount("fatigue", "failure"), 0, "fatigue failure recovers 0")
	check_eq(combat.recovery_amount("fatigue", "critical failure"), 0, "fatigue critical failure recovers 0")

	check_eq(combat.recovery_amount("wound", "marginal"), 1, "wound marginal recovers 1")
	check_eq(combat.recovery_amount("wound", "ordinary"), 2, "wound ordinary recovers 2")
	check_eq(combat.recovery_amount("wound", "good"), 3, "wound good recovers 3")
	check_eq(combat.recovery_amount("wound", "amazing"), 4, "wound amazing recovers 4")
	check_eq(combat.recovery_amount("wound", "failure"), 0, "wound failure recovers 0")
	check_eq(combat.recovery_amount("wound", "critical failure"), 0, "wound critical failure recovers 0")

	check_eq(combat.recovery_amount("mortal", "amazing"), 0, "mortal damage never recovers by check")
	check_eq(combat.recovery_amount("stun", "amazing"), 0, "stun damage does not use check")

	# Skill IDs mapped to Resolve - physical resolve
	check_eq(
		AlternityNum.as_int(recovery["fatigue"]["skill_id"]),
		AlternityRules.PHYSICAL_RESOLVE_SKILL_ID,
		"fatigue recovery uses PHYSICAL_RESOLVE_SKILL_ID"
	)
	check_eq(
		AlternityNum.as_int(recovery["wound"]["skill_id"]),
		AlternityRules.PHYSICAL_RESOLVE_SKILL_ID,
		"wound recovery uses PHYSICAL_RESOLVE_SKILL_ID"
	)
	var skill: Dictionary = _rules.get_skill_by_id(AlternityRules.PHYSICAL_RESOLVE_SKILL_ID)
	check_eq(String(skill.get("name", "")), "Physical Resolve", "skill 136 is Physical Resolve")
	check_eq(String(skill.get("stat", "")), "WIL", "Physical Resolve is governed by WIL")


func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found = _find_node_by_name(child, target_name)
		if found != null:
			return found
	return null


func _find_label_containing(node: Node, needle: String) -> Label:
	if node is Label and (node as Label).text.contains(needle):
		return node as Label
	for child in node.get_children():
		var found = _find_label_containing(child, needle)
		if found != null:
			return found
	return null


## Test that Summary tab renders recovery affordances only for damaged tracks,
## never offers checks for mortal or stun, and displays the cadence note.
func _test_recovery_ui_rendering() -> void:
	var doc := Doc.new(_rules)
	doc.set_species_id(0)
	doc.set_profession_id(0)

	# 1. Undamaged hero: no recovery buttons
	var tab = TAB_SUMMARY.instantiate()
	root.add_child(tab)
	var dummy_checks = load("res://scripts/ui/check_runner.gd").new(_rules, null, ThemePalette.new())
	var ctx := Context.new(doc, _rules, null, ThemePalette.new(), false)
	ctx.checks = dummy_checks
	tab.bind(ctx)
	await process_frame

	check_true(_find_node_by_name(tab, "RecoverWoundButton") == null, "no wound button when undamaged")
	check_true(_find_node_by_name(tab, "RecoverFatigueButton") == null, "no fatigue button when undamaged")
	check_true(_find_node_by_name(tab, "RecoverMortalButton") == null, "no mortal button when undamaged")
	check_true(_find_node_by_name(tab, "RecoverStunButton") == null, "no stun button when undamaged")

	# 2. Hurt hero: wound=2, fatigue=1, mortal=1, stun=3
	doc.apply([CharacterDoc.DAMAGE], func(c):
		var tracks: Dictionary = c.get("damage", {})
		tracks["wound"] = 2
		tracks["fatigue"] = 1
		tracks["mortal"] = 1
		tracks["stun"] = 3
		c["damage"] = tracks)
	await process_frame

	var wound_btn = _find_node_by_name(tab, "RecoverWoundButton")
	check_true(wound_btn != null, "wound recovery button appears when wounded")
	if wound_btn != null:
		check_true((wound_btn as Button).text.contains("1 week"), "wound button states 1 week cadence")

	var fatigue_btn = _find_node_by_name(tab, "RecoverFatigueButton")
	check_true(fatigue_btn != null, "fatigue recovery button appears when fatigued")
	if fatigue_btn != null:
		check_true((fatigue_btn as Button).text.contains("1 hour"), "fatigue button states 1 hour cadence")

	# Stun and mortal must NEVER have recovery check buttons
	check_true(_find_node_by_name(tab, "RecoverMortalButton") == null, "mortal damage never gets a check button")
	check_true(_find_node_by_name(tab, "RecoverStunButton") == null, "stun damage never gets a check button")

	# Mortal note is displayed
	var mortal_note = _find_label_containing(tab, "Mortal damage")
	check_true(mortal_note != null, "mortal damage explanation note is rendered")
	if mortal_note != null:
		check_true(mortal_note.text.contains("surgery"), "mortal note states surgery is required")

	tab.queue_free()
	await process_frame


## Test check outcome application to character damage tracks via doc.apply().
func _test_recovery_damage_application() -> void:
	var doc := Doc.new(_rules)
	doc.set_species_id(0)
	doc.set_profession_id(0)

	doc.apply([CharacterDoc.DAMAGE], func(c):
		var tracks: Dictionary = c.get("damage", {})
		tracks["wound"] = 3
		tracks["fatigue"] = 2
		c["damage"] = tracks)

	var tab = TAB_SUMMARY.instantiate()
	root.add_child(tab)
	var ctx := Context.new(doc, _rules, null, ThemePalette.new(), false)
	tab.bind(ctx)
	await process_frame

	var saved := [false]
	tab.save_requested.connect(func(): saved[0] = true)

	# 1. Ordinary wound recovery restores 2 points (from RECOVERY)
	var wound_restored_pts := _rules.combat.recovery_amount("wound", "ordinary")
	check_eq(wound_restored_pts, 2, "ordinary wound recovery amount is 2")

	var restored: int = AlternityNum.as_int(doc.apply([CharacterDoc.DAMAGE], func(c: Dictionary) -> int:
		var tracks: Dictionary = c.get("damage", {})
		var current: int = AlternityNum.as_int(tracks.get("wound", 0))
		var to_restore: int = mini(current, wound_restored_pts)
		tracks["wound"] = maxi(0, current - to_restore)
		c["damage"] = tracks
		_rules.clamp_trackers(c)
		return to_restore
	), 0)
	check_eq(restored, 2, "apply returned 2 restored points")
	check_eq(
		AlternityNum.as_int(doc.raw().get("damage", {}).get("wound", 0)),
		1,
		"wound reduced from 3 to 1"
	)

	# 2. Failed check restores 0 points
	var fail_restored_pts := _rules.combat.recovery_amount("wound", "failure")
	check_eq(fail_restored_pts, 0, "failed check recovery amount is 0")
	var before_fail: int = AlternityNum.as_int(doc.raw().get("damage", {}).get("wound", 0))
	if fail_restored_pts > 0:
		doc.apply([CharacterDoc.DAMAGE], func(c): pass)
	check_eq(
		AlternityNum.as_int(doc.raw().get("damage", {}).get("wound", 0)),
		before_fail,
		"failed recovery check does not change wound damage"
	)

	# 3. Fatigue ordinary recovery restores 1 point
	var fatigue_restored_pts := _rules.combat.recovery_amount("fatigue", "ordinary")
	check_eq(fatigue_restored_pts, 1, "ordinary fatigue recovery amount is 1")
	var fatigue_restored: int = AlternityNum.as_int(doc.apply([CharacterDoc.DAMAGE], func(c: Dictionary) -> int:
		var tracks: Dictionary = c.get("damage", {})
		var current: int = AlternityNum.as_int(tracks.get("fatigue", 0))
		var to_restore: int = mini(current, fatigue_restored_pts)
		tracks["fatigue"] = maxi(0, current - to_restore)
		c["damage"] = tracks
		_rules.clamp_trackers(c)
		return to_restore
	), 0)
	check_eq(fatigue_restored, 1, "apply returned 1 fatigue restored point")
	check_eq(
		AlternityNum.as_int(doc.raw().get("damage", {}).get("fatigue", 0)),
		1,
		"fatigue reduced from 2 to 1"
	)

	tab.queue_free()
	await process_frame
