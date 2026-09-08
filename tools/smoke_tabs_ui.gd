extends "res://tools/test_harness.gd"
##
## Tab-specific behaviour that the shell walkthrough does not reach.
##
## Replaces smoke_mutation_ui, smoke_ability_generation_ui and
## smoke_optional_rules_ui, which each instantiated main.tscn and reached into
## its members. They were three near-identical scene harnesses testing three
## unrelated things; this drives the migrated tabs directly instead.
##
## The rules assertions they made are preserved -- ability rolls landing inside
## their legal band, optional rules reaching the created character, mutations
## applying -- because those are what actually mattered.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")
const Doc := preload("res://scripts/core/character_doc.gd")
const Context := preload("res://scripts/ui/sheet_context.gd")

const TAB_BASICS := preload("res://scenes/ui/tabs/tab_basics.tscn")
const TAB_MUTATIONS := preload("res://scenes/ui/tabs/tab_mutations.tscn")
const TAB_SUMMARY := preload("res://scenes/ui/tabs/tab_summary.tscn")
const TAB_FX := preload("res://scenes/ui/tabs/tab_fx.tscn")
const TAB_SKILLS := preload("res://scenes/ui/tabs/tab_skills.tscn")
const TAB_PSIONICS := preload("res://scenes/ui/tabs/tab_psionics.tscn")
const TAB_EQUIPMENT := preload("res://scenes/ui/tabs/tab_equipment.tscn")
const OPTIONAL_RULES_ROUTE := preload("res://scenes/ui/routes/optional_rules_route.tscn")
const SkillPickerScript := preload("res://scripts/ui/widgets/skill_picker.gd")
const FxPickerScript := preload("res://scripts/ui/widgets/fx_picker.gd")

var _rules: AlternityRules


func _init() -> void:
	begin_async("tab behaviour", 400)
	_run.call_deferred()


func _run() -> void:
	_rules = RulesScript.new()
	_rules.load_core_data()

	await _test_ability_generation()
	await _test_basics_explains_origin()
	await _test_mutations_tab()
	await _test_summary_tab()
	await _test_summary_is_self_contained()
	await _test_permanent_fx_effects_render()
	await _test_optional_rules_route()
	await _test_skills_tab()
	await _test_catalog_rank_controls_and_scores()
	await _test_psionics_tab()
	await _test_fx_tab()
	await _test_summary_attack_forms_and_tables()
	await _test_summary_armor_cards()
	await _test_dark_matter_basics_career_packages()
	await _test_dark_matter_equipment_requisition()
	await _test_custom_ability_target_spinbox()
	await _test_durability_dazed_markers()

	finish()


func _mount(scene: PackedScene, doc: CharacterDoc, is_wide: bool = false):
	var tab = scene.instantiate()
	root.add_child(tab)
	tab.bind(Context.new(doc, _rules, null, ThemePalette.new(), is_wide))
	return tab


## Every generation method must land inside the legal band for the character,
## because a species or profession minimum can exceed what the dice rolled.
func _test_ability_generation() -> void:
	var doc := Doc.new(_rules)
	doc.set_species_id(0)      # Human
	doc.set_profession_id(0)   # Combat Spec

	var tab = _mount(TAB_BASICS, doc)
	await process_frame
	check_true(tab.get_child_count() > 0, "Basics renders")

	# Only the two methods the tab offers. The third button called
	# roll_random_abilities_by_profession, which returns the formula table rather
	# than rolled scores -- and this loop asserted only that scores landed inside
	# the legal band, which clamping a coerced 0 up to the minimum satisfies. The
	# test passed while the button reliably produced a floor-value hero.
	for method in ["method_1", "method_2"]:
		var rolled: Dictionary = {}
		match method:
			"method_1": rolled = _rules.roll_abilities_method_1(doc.get_profession_id())
			_: rolled = _rules.roll_abilities_method_2(doc.get_species_id())

		if not check(not rolled.is_empty(), "%s produced a spread" % method):
			continue

		tab._apply_rolled(rolled)
		await process_frame

		var abilities: Dictionary = doc.raw().get("abilities", {})
		check_eq(abilities.size(), 6, "%s writes all six abilities" % method)

		var out_of_band: Array = []
		var above_floor := 0
		for ability in ["STR", "DEX", "CON", "INT", "WIL", "PER"]:
			var limits: Array = _rules.ability_limits(doc.raw(), ability)
			var score := AlternityNum.as_int(abilities.get(ability, 0))
			if score < AlternityNum.as_int(limits[0]) or score > AlternityNum.as_int(limits[1]):
				out_of_band.append("%s=%d" % [ability, score])
			if score > AlternityNum.as_int(limits[0]):
				above_floor += 1
		check_true(out_of_band.is_empty(), "%s stays inside the legal band (%s)" % [method, str(out_of_band)])

		# In-band is not enough: a generator that produces nothing and gets
		# clamped up to the minimum is also in band. Every published spread
		# starts each ability well above the species floor, so a roll that
		# leaves every score sitting on it did not roll anything.
		check_true(
			above_floor > 0,
			"%s produced scores above the floor, not a clamped zero spread" % method
		)

		# The point target is reset to what the roll cost, so the budget is not
		# compared against a purchased spread that no longer exists.
		check_eq(
			AlternityNum.as_int(doc.raw().get("custom_ability_target", -1), -1),
			_rules.ability_total(doc.raw()),
			"%s resets the ability point target" % method
		)

	tab.queue_free()


## Basics must say what a species and profession are, not just let you pick one.
##
## "This app is trying to be a replacement for the manuals" -- and choosing a
## race showed a dropdown and nothing else. The species summary line read a key
## the data does not have, so it never rendered, and the mechanical notes that
## do exist were displayed nowhere at all.
func _test_basics_explains_origin() -> void:
	var doc := Doc.new(_rules)
	doc.set_species_id(4)     # T'sa: has notes, a free skill and an action-step bonus
	doc.set_profession_id(0)  # Combat Spec

	var tab = _mount(TAB_BASICS, doc)
	await process_frame
	var labels := _labels_in(tab)

	var species: Dictionary = _rules.get_species_by_id(doc.get_species_id())
	var species_name := String(species.get("name", ""))
	check_true(_any_label_contains(labels, species_name), "Basics names the species (%s)" % species_name)

	var description := String(species.get("description", ""))
	check_true(not description.is_empty(), "the species catalog carries a description")
	if not description.is_empty():
		check_true(
			_any_label_contains(labels, description.substr(0, 40)),
			"Basics shows the species description"
		)

	check_true(_any_label_contains(labels, "Ability range"), "Basics states the species ability range")

	var notes: Array = species.get("notes", [])
	if not notes.is_empty():
		check_true(
			_any_label_contains(labels, String(notes[0]).substr(0, 30)),
			"Basics shows the species rule notes"
		)

	var profession: Dictionary = _rules.get_profession_by_id(doc.get_profession_id())
	check_true(
		_any_label_contains(labels, String(profession.get("name", ""))),
		"Basics names the profession"
	)
	var prof_notes: Array = profession.get("notes", [])
	if not prof_notes.is_empty():
		check_true(
			_any_label_contains(labels, String(prof_notes[0]).substr(0, 30)),
			"Basics shows what the profession is"
		)
	check_true(_any_label_contains(labels, "Requires"), "Basics states the profession requirements")
	# Combat Spec's requirement is STR 11, CON 9 -- Table P1 (PHB p. 30) leaves
	# every other cell blank, so the rendered line must not invent a third stat.
	check_true(
		_any_label_contains(labels, "STR 11  CON 9"),
		"Basics shows the Combat Spec requirement as STR 11, CON 9"
	)
	check_false(
		_any_label_contains(labels, "STR 11  DEX 9  CON 9"),
		"Basics does not show the old phantom DEX 9 in the Combat Spec requirement line"
	)

	# Every generation button offered must actually roll. The removed third
	# button passed the formula table in as if it were scores.
	check_true(
		_any_label_contains(labels, "Method I"), "Basics offers Method I with a name that says what it rolls"
	)

	tab.queue_free()


func _test_mutations_tab() -> void:
	var doc := Doc.new(_rules)
	var context := Context.new(doc, _rules, null, ThemePalette.new(), false)

	var probe = TAB_MUTATIONS.instantiate()
	check_false(probe.is_available_for(context), "Mutations excluded for a Human hero")

	doc.set_species_id(_rules.mutations.mutant_species_id())
	check_true(probe.is_available_for(context), "Mutations applies to a Mutant hero")
	probe.free()

	doc.apply(CharacterDoc.ALL, func(c):
		_rules.mutations.set_mutation_points(c, 3, 2))

	var tab = _mount(TAB_MUTATIONS, doc)
	await process_frame
	check_true(tab.get_child_count() > 0, "Mutations renders for a Mutant")

	# Adding through the rules must reach the tab as a rebuild.
	var before: int = tab.get_child_count()
	doc.apply(CharacterDoc.ALL, func(c):
		_rules.mutations.add_mutation_advantage(c, "improved_str"))
	await process_frame
	check_eq(
		_rules.mutations.selected_mutation_advantages(doc.raw()).size(), 1,
		"the advantage was recorded"
	)
	check_true(tab.get_child_count() >= before, "the tab rebuilt after the change")

	tab.queue_free()


## Summary aggregates everything, so it is the tab most likely to break on an
## unusual character.
func _test_summary_tab() -> void:
	var doc := Doc.new(_rules)
	doc.set_species_id(_rules.mutations.mutant_species_id())
	doc.apply(CharacterDoc.ALL, func(c):
		_rules.mutations.set_mutation_origin(c, "engineered")
		_rules.mutations.set_mutation_uniqueness(c, "engineered_community")
		_rules.mutations.set_mutation_points(c, 3, 2)
		_rules.mutations.add_mutation_advantage(c, "improved_str")
		_rules.mutations.add_mutation_drawback(c, "slow_reflexes"))

	var tab = _mount(TAB_SUMMARY, doc)
	await process_frame
	check_true(tab.get_child_count() > 0, "Summary renders after mutation selections")

	var labels := _labels_in(tab)
	check_true(_any_label_contains(labels, "Mutations"), "Summary displays Mutations section")
	check_true(_any_label_contains(labels, "Engineered mutation(s)"), "Summary shows mutation origin")
	check_true(_any_label_contains(labels, "Belongs to mutant community"), "Summary shows mutation uniqueness")
	check_true(_any_label_contains(labels, "Advantage points"), "Summary shows advantage points label")
	check_true(_any_label_contains(labels, "Drawback points"), "Summary shows drawback points label")
	check_true(_any_label_contains(labels, "Advantages"), "Summary displays Advantages subsection")
	check_true(_any_label_contains(labels, "Drawbacks"), "Summary displays Drawbacks subsection")
	check_true(_any_label_contains(labels, "Improved STR"), "Summary lists Improved STR")
	check_true(_any_label_contains(labels, "Slow Reflexes"), "Summary lists Slow Reflexes")

	# Check that points are correctly formatted (e.g. "1 pt", NOT "0 points")
	check_false(_any_label_contains(labels, "0 points"), "No 0-point bug for mutations")
	check_true(_any_label_contains(labels, "Ordinary • 1 pt • STR"), "Advantage badge shows Tier, Points, and Related Ability")
	check_true(_any_label_contains(labels, "untrained check at 1/2 the related ability score"), "Advantages subsection displays untrained check rules")
	check_true(_any_label_contains(labels, "Table P51"), "Drawbacks subsection displays Table P51 ability rule")

	# Verify that mutation detail adapts cleanly to SkillDetail
	var adv := _rules.mutations.get_mutation_advantage_by_id("improved_str")
	var detail_data := {
		"name": String(adv.get("name", "")),
		"meta": "Tier: Ordinary • 1 point • Related Ability: STR",
		"summary": String(adv.get("summary", "")),
		"sources": [String(adv.get("reference", ""))],
	}
	var detail := SkillDetail.from_data(detail_data)
	check_eq(detail.title, "Improved STR", "detail title is mutation name")
	check_true(detail.subtitle.contains("Ordinary"), "detail subtitle has tier")
	check_true(detail.find_section("Source").get("body", "").contains("Player's Handbook"), "detail captures reference source")

	# The damage trackers are the interactive part, so they must survive a
	# character whose durability came from mutations.
	var summary := doc.summary()
	var durability: Dictionary = summary.get("durability", {})
	check_true(AlternityNum.as_int(durability.get("stun", 0)) > 0, "durability is computed")

	tab.queue_free()


## Summary must carry the whole character, not a set of pointers to other tabs.
##
## The app exists to replace reaching for the manuals mid-session, and Summary is
## the tab that stays open at the table. A heading that says "3 perks" and makes
## you go elsewhere to find out which ones has failed at that job, so this
## asserts the content is actually present rather than merely counted.
func _test_summary_is_self_contained() -> void:
	var doc := Doc.new(_rules)
	doc.set_species_id(0)     # Human
	doc.set_profession_id(0)  # Combat Spec

	# Give the hero one of everything Summary is supposed to spell out.
	doc.apply(CharacterDoc.ALL, func(c):
		for broad in _rules.broad_skills:
			if typeof(broad) == TYPE_DICTIONARY and not _rules.is_psionic_skill(broad):
				_rules.set_skill_rank(c, AlternityNum.as_int(broad.get("id", 0)), 1)
				break
		for perk in AlternityRules.PERK_DEFINITIONS:
			var costs: Array = perk.get("cost_options", [])
			_rules.set_perk_selected(
				c, String(perk.get("id", "")),
				AlternityNum.as_int(costs[0] if not costs.is_empty() else perk.get("cost", 0))
			)
			break
		for flaw in AlternityRules.FLAW_DEFINITIONS:
			var bonuses: Array = flaw.get("bonus_options", [])
			_rules.set_flaw_selected(
				c, String(flaw.get("id", "")),
				AlternityNum.as_int(bonuses[0] if not bonuses.is_empty() else flaw.get("bonus", 0))
			)
			break
		_rules.fx.set_fx_talent(c, true)
		for broad in _rules.fx.get_broad_skills_for_character(c):
			_rules.fx.add_fx_skill(c, String(broad.get("name", "")))
			break)

	var tab = _mount(TAB_SUMMARY, doc)
	await process_frame

	var headings := _labels_in(tab)

	# Each of these is a section the human review asked to see inline.
	for heading in ["Skills", "FX", "Perks and Flaws"]:
		check_true(headings.has(heading), "Summary shows a %s section inline" % heading)

	# And the entries themselves, not just the headings.
	var skills: Array = _rules.selected_skills(doc.raw())
	if check(not skills.is_empty(), "the test hero holds a skill"):
		var skill_name := String(_rules.skill_label(skills[0]))
		check_true(
			_any_label_contains(headings, skill_name),
			"Summary names the skill itself (%s)" % skill_name
		)

	var perks: Array = _rules.selected_perks(doc.raw())
	if check(not perks.is_empty(), "the test hero holds a perk"):
		check_true(
			_any_label_contains(headings, String(perks[0].get("name", ""))),
			"Summary names the perk itself (%s)" % String(perks[0].get("name", ""))
		)

	tab.queue_free()


## A hero with an always-active power must not take the tab down with them.
##
## permanent_fx_effects_summary returns {name, description} dictionaries. Both
## Summary and the FX tab passed each entry straight to String(), which has no
## Dictionary constructor, so both sections crashed -- but only for a character
## who actually had a permanent power, which no fixture or screenshot hero did.
## Found by driving the real app against a real saved character.
func _test_permanent_fx_effects_render() -> void:
	var doc := Doc.new(_rules)
	doc.set_species_id(0)
	doc.set_profession_id(0)

	var permanent_name := [""]
	doc.apply(CharacterDoc.ALL, func(c):
		_rules.fx.set_fx_talent(c, true)
		for broad in _rules.fx.get_broad_skills_for_character(c):
			var broad_name := String(broad.get("name", ""))
			_rules.fx.add_fx_skill(c, broad_name)
			for power in _rules.fx.get_specialty_skills_for_broad_and_character(broad_name, c):
				var power_name := String(power.get("name", ""))
				if not _rules.fx.can_fx_skill_be_permanent(power_name):
					continue
				_rules.fx.add_fx_skill(c, power_name)
				_rules.fx.set_fx_skill_permanent(c, power_name, true)
				permanent_name[0] = power_name
				break
			if not permanent_name[0].is_empty():
				break)

	if not check(not permanent_name[0].is_empty(), "the catalog has a power that can be permanent"):
		return

	var effects: Array = _rules.fx.permanent_fx_effects_summary(doc.raw())
	check_true(not effects.is_empty(), "the hero has an always-active power recorded")

	# Both tabs render that list, and both used to die on it.
	for scene in [TAB_SUMMARY, TAB_FX]:
		var tab = _mount(scene, doc)
		await process_frame
		check_true(tab.get_child_count() > 0, "the tab still renders with a permanent power")
		check_true(
			_any_label_contains(_labels_in(tab), permanent_name[0]),
			"the always-active power is named (%s)" % permanent_name[0]
		)
		tab.queue_free()


## Every piece of text in the subtree, so a test can ask what is on screen.
##
## Buttons count: their label is content a reader sees, and several of the
## things these tests assert about (generation methods, catalog actions) are
## rendered as buttons rather than labels.
func _labels_in(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is Label:
			out.append((child as Label).text)
		elif child is Button:
			out.append((child as Button).text)
		elif child is RichTextLabel:
			out.append((child as RichTextLabel).get_parsed_text())
		out.append_array(_labels_in(child))
	return out


func _buttons_in(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is Button:
			out.append(child)
		out.append_array(_buttons_in(child))
	return out


func _any_label_contains(labels: Array, needle: String) -> bool:
	if needle.is_empty():
		return false
	for text in labels:
		if String(text).contains(needle):
			return true
	return false


func _assert_rank_is_between_buttons(picker: Control, label: String) -> void:
	var rank_label := picker.find_child("RankLabel", true, false) as Label
	check_true(rank_label != null, "%s catalog renders a Rank label" % label)
	if rank_label == null:
		return
	var row := rank_label.get_parent()
	var minus_index := -1
	var plus_index := -1
	for index in row.get_child_count():
		var child := row.get_child(index)
		if child is Button:
			var button := child as Button
			if button.tooltip_text == "Reduce rank":
				minus_index = index
			elif button.tooltip_text == "Increase rank":
				plus_index = index
	check_true(minus_index >= 0 and plus_index >= 0, "%s catalog has both rank buttons" % label)
	check_true(minus_index < rank_label.get_index() and rank_label.get_index() < plus_index, "%s places Rank between minus and plus" % label)


## The new-hero flow: rules chosen before the character exists, because several
## change the starting skill budget.
func _test_optional_rules_route() -> void:
	var doc := Doc.new(_rules)
	var route = OPTIONAL_RULES_ROUTE.instantiate()
	root.add_child(route)
	route.configure({
		"palette": ThemePalette.new(),
		"rules": _rules,
		"character": doc.raw(),
		"confirm_text": "Create Hero",
	})
	await process_frame

	check_eq(route._confirm_text, "Create Hero", "the confirm label is configurable")
	check_true(route.get_child_count() > 0, "the route renders the rule list")

	# Nothing touched, nothing reported: the caller invalidates the whole sheet on
	# any result, so an empty one has to be null rather than a pair of empty maps.
	check_eq(route._result(), null, "an untouched screen reports no change")

	# Toggling records only the net change, so a rule flipped twice applies
	# nothing.
	route._changed["2a"] = true
	route._changed_supplements["dataware"] = true
	var result: Dictionary = route._result()
	check_eq(result.get("rules", {}).size(), 1, "a rule change is recorded")
	check_eq(result.get("supplements", {}).size(), 1, "a supplement change is recorded separately")

	for rule_id in result["rules"]:
		_rules.set_optional_rule(doc.raw(), String(rule_id), bool(result["rules"][rule_id]))
	for supplement_id in result["supplements"]:
		_rules.set_supplement(doc.raw(), String(supplement_id), bool(result["supplements"][supplement_id]))
	check_true(_rules.optional_rule_enabled(doc.raw(), "2a"), "the chosen rule reaches the character")
	check_true(_rules.supplement_enabled(doc.raw(), "dataware"), "the chosen supplement reaches the character")

	var full_rank_rule: Dictionary = {}
	for rule in AlternityRules.OPTIONAL_RULES:
		if String(rule.get("id", "")) == "dm_adept_unrestricted_ranks":
			full_rank_rule = rule
	check_false(route._rule_is_visible(full_rank_rule), "the Adept rank crossover is hidden outside Dark*Matter")
	doc.raw()["setting"] = "Dark*Matter"
	_rules.set_supplement(doc.raw(), "beyond_science", false)
	check_true(route._rule_is_visible(full_rank_rule), "the Adept rank crossover is available in Dark*Matter regardless of books in play")

	route.queue_free()


func _test_skills_tab() -> void:
	var doc := Doc.new(_rules)
	doc.set_species_id(0)     # Human
	doc.set_profession_id(0)  # Combat Spec

	# Mount wide (desktop) layout first
	var tab = _mount(TAB_SKILLS, doc, true)
	await process_frame
	check_true(tab.get_child_count() > 0, "Skills tab renders in wide layout")
	check_true(tab.has_custom_scroll(), "Skills tab declares custom scroll")

	var labels := _labels_in(tab)
	check_true(_any_label_contains(labels, "Skill points"), "Skills tab shows Skill points progress")
	check_true(_any_label_contains(labels, "Broad skills"), "Skills tab shows Broad skills progress")
	check_true(_any_label_contains(labels, "Selected Skills"), "Skills tab has Selected Skills breakdown")

	# Select a broad skill
	var athletics = _rules.get_skill_by_id(1) # Athletics
	doc.apply(CharacterDoc.ALL, func(c):
		_rules.set_skill_rank(c, 1, 1))
	await process_frame

	labels = _labels_in(tab)
	check_true(_any_label_contains(labels, "Athletics"), "Selected skills breakdown lists Athletics")

	tab.queue_free()

	# A setting-gated specialty must not be offered under an ungated broad.
	#
	# The picker checks the broad, and every broad Dark*Matter hangs a skill under
	# -- Investigate, Creativity, Knowledge -- is a skill every campaign has. So a
	# check on the broad alone lets the specialty through, and a Core hero is
	# quietly offered Cryptography.
	var picker = SkillPickerScript.new()
	root.add_child(picker)
	picker.setup(Context.new(doc, _rules, null, ThemePalette.new(), true), 0)
	await process_frame

	var investigate: Dictionary = _rules.get_skill_by_id(130)
	var core_names := _specialty_names(picker, investigate)
	check_true(core_names.has("Interrogate"), "a Core hero sees Investigate's core specialties")
	check_false(core_names.has("Cryptography"), "and is not offered the Dark*Matter one")

	doc.apply(CharacterDoc.ALL, func(c): c["setting"] = "Dark*Matter")
	var dark_names := _specialty_names(picker, investigate)
	check_true(dark_names.has("Cryptography"), "a Dark*Matter hero is offered Cryptography")
	check_true(dark_names.has("Interrogate"), "and keeps the core ones")
	picker.queue_free()

	doc.apply(CharacterDoc.ALL, func(c): c["setting"] = "Core")

	# Mount compact (mobile) layout
	var tab_mobile = _mount(TAB_SKILLS, doc, false)
	await process_frame
	check_true(tab_mobile.get_child_count() > 0, "Skills tab renders in compact layout")
	labels = _labels_in(tab_mobile)
	check_true(_any_label_contains(labels, "Selected Skills"), "Compact layout has Selected Skills accordion")
	tab_mobile.queue_free()


func _test_catalog_rank_controls_and_scores() -> void:
	var normal_doc := Doc.new(_rules)
	normal_doc.set_species_id(0)
	normal_doc.set_profession_id(0)
	normal_doc.apply(CharacterDoc.ALL, func(c):
		_rules.set_skill_rank(c, 3, 1) # Athletics
		_rules.set_skill_rank(c, 4, 1) # Climb
	)
	var normal_picker := SkillPickerScript.new()
	root.add_child(normal_picker)
	normal_picker.setup(Context.new(normal_doc, _rules, null, ThemePalette.new(), true), SkillPickerScript.Mode.NORMAL)
	await process_frame
	check_true(_any_label_contains(_labels_in(normal_picker), "O11 / G5 / A2"), "normal catalog shows the current O / G / A score below cost")
	check_eq(normal_picker.find_children("CheckScore", "Label", true, false).size(), 2, "normal catalog shows scores only for its bought broad and specialty")
	_assert_rank_is_between_buttons(normal_picker, "normal")
	normal_picker.queue_free()

	var fx_doc := Doc.new(_rules)
	fx_doc.set_species_id(0)
	fx_doc.set_profession_id(0)
	fx_doc.apply([CharacterDoc.FX], func(c):
		_rules.fx.set_fx_talent(c, true)
		_rules.fx.add_fx_skill(c, "Shamanism")
		_rules.fx.add_fx_skill(c, "Animal voice")
	)
	var fx_picker := FxPickerScript.new()
	root.add_child(fx_picker)
	fx_picker.setup(Context.new(fx_doc, _rules, null, ThemePalette.new(), true))
	fx_picker._category = "Faith"
	fx_picker.refresh_skills()
	await process_frame
	check_true(_any_label_contains(_labels_in(fx_picker), "O11 / G5 / A2"), "FX catalog shows the current O / G / A score below cost")
	check_eq(fx_picker.find_children("CheckScore", "Label", true, false).size(), 2, "FX catalog shows scores only for its bought broad and power")
	_assert_rank_is_between_buttons(fx_picker, "FX")
	fx_picker.queue_free()


func _specialty_names(picker, broad: Dictionary) -> Array:
	var names: Array = []
	for specialty in picker._specialties(broad):
		names.append(String(specialty.get("name", "")))
	return names


func _test_psionics_tab() -> void:
	var doc := Doc.new(_rules)
	doc.set_species_id(1)     # Fraal (psionic)
	doc.set_profession_id(6)  # Mindwalker (psionic)

	var tab = _mount(TAB_PSIONICS, doc, true)
	await process_frame
	check_true(tab.get_child_count() > 0, "Psionics tab renders")
	check_true(tab.has_custom_scroll(), "Psionics tab declares custom scroll")

	var labels := _labels_in(tab)
	check_true(_any_label_contains(labels, "Psionic Energy"), "Psionics tab shows Psionic Energy tracker")
	check_true(_any_label_contains(labels, "Selected Powers"), "Psionics tab shows Selected Powers breakdown")

	tab.queue_free()


func _test_fx_tab() -> void:
	var doc := Doc.new(_rules)
	doc.set_species_id(0)
	doc.set_profession_id(0)

	doc.apply(CharacterDoc.ALL, func(c):
		_rules.fx.set_fx_talent(c, true)
		_rules.fx.set_energy_pool(c, 10)
		_rules.fx.add_fx_skill(c, "Shamanism")
		_rules.fx.add_fx_skill(c, "Animal voice")
	)

	# 1. Desktop wide layout
	var tab_wide = _mount(TAB_FX, doc, true)
	await process_frame
	check_true(tab_wide.get_child_count() > 0, "FX tab renders in wide layout")
	check_true(tab_wide.has_custom_scroll(), "FX tab declares custom scroll")

	var labels := _labels_in(tab_wide)
	check_true(_any_label_contains(labels, "FX Energy"), "Wide FX tab shows FX Energy tracker")
	check_true(_any_label_contains(labels, "Selected Powers"), "Wide FX tab shows Selected Powers breakdown")
	check_true(_any_label_contains(labels, "FX Cost"), "Wide FX tab has FX Cost column")
	check_true(_any_label_contains(labels, "Shamanism"), "Selected Powers lists Shamanism broad")
	check_true(_any_label_contains(labels, "Animal voice"), "Selected Powers lists Animal voice power")
	tab_wide.queue_free()

	# 2. Compact mobile layout
	var tab_mobile = _mount(TAB_FX, doc, false)
	await process_frame
	check_true(tab_mobile.get_child_count() > 0, "FX tab renders in compact layout")
	labels = _labels_in(tab_mobile)
	check_true(_any_label_contains(labels, "Selected Powers"), "Compact FX tab has Selected Powers accordion")
	tab_mobile.queue_free()


func _test_summary_attack_forms_and_tables() -> void:
	var doc := Doc.new(_rules)
	doc.set_species_id(0)
	doc.set_profession_id(0)

	doc.apply(CharacterDoc.ALL, func(c):
		_rules.set_skill_rank(c, 3, 1) # Athletics
		_rules.set_skill_rank(c, 4, 1) # Climb
		_rules.fx.set_fx_talent(c, true)
		_rules.fx.set_energy_pool(c, 8)
		_rules.fx.add_fx_skill(c, "Necromancy")
		_rules.fx.add_fx_skill(c, "Animate dead")
	)

	var tab = _mount(TAB_SUMMARY, doc, true)
	await process_frame
	check_true(tab.get_child_count() > 0, "Summary tab mounts")

	var labels := _labels_in(tab)
	# Attack forms card checks
	check_true(_any_label_contains(labels, "Attack Forms"), "Summary shows Attack Forms section")
	check_true(_any_label_contains(labels, "Score"), "Attack card has Score field")
	check_true(_any_label_contains(labels, "Damage O/G/A"), "Attack card has Damage O/G/A field")
	check_true(_any_label_contains(labels, "Range"), "Attack card has Range field")
	check_true(_any_label_contains(labels, "Hide"), "Attack card has Hide field")
	check_true(_any_label_contains(labels, "Clip"), "Attack card has Clip field")

	# Skills and FX reference tables
	check_true(_any_label_contains(labels, "Athletics"), "Summary skills table has Athletics")
	check_true(_any_label_contains(labels, "Climb"), "Summary skills table has Climb")
	check_true(_any_label_contains(labels, "Roll"), "Summary skills table has Roll header")
	check_true(_any_label_contains(labels, "Necromancy"), "Summary FX table has Necromancy")
	check_true(_any_label_contains(labels, "Animate dead"), "Summary FX table has Animate dead")
	check_true(_any_label_contains(labels, "FX Cost"), "Summary FX table has FX Cost header")

	var buttons := _buttons_in(tab)
	var has_skill_roll_btn := false
	var has_skill_info_btn := false
	var has_fx_info_btn := false
	for btn in buttons:
		if btn is Button:
			var b := btn as Button
			if b.tooltip_text.begins_with("Roll "):
				has_skill_roll_btn = true
			elif b.tooltip_text.begins_with("View details for Athletics"):
				has_skill_info_btn = true
			elif b.tooltip_text.begins_with("View details for Necromancy"):
				has_fx_info_btn = true
	check_true(has_skill_roll_btn, "Summary skills table has roll button")
	check_true(has_skill_info_btn, "Summary skills table has skill info button")
	check_true(has_fx_info_btn, "Summary FX table has power info button")
	tab.queue_free()


func _test_summary_armor_cards() -> void:
	var doc := Doc.new(_rules)
	doc.set_species_id(0)
	doc.set_profession_id(0)

	doc.apply(CharacterDoc.ALL, func(c):
		var line_id := _rules.equipment.add_equipment_to_character(c, "armor_core_028", 1)
		_rules.equipment.update_carried_equipment(c, line_id, 1, true, "Armor", "")
	)

	var tab = _mount(TAB_SUMMARY, doc, true)
	await process_frame
	check_true(tab.get_child_count() > 0, "Summary tab mounts with armor")

	var labels := _labels_in(tab)
	check_true(_any_label_contains(labels, "Armour"), "Summary shows Armour section")
	check_true(_any_label_contains(labels, "Leather armor"), "Summary Armour card names Leather armor")
	check_false(labels.has("?"), "Summary Armour card does not show '?' placeholder")
	check_true(_any_label_contains(labels, "LI Armor"), "Armour card has LI Armor field")
	check_true(_any_label_contains(labels, "d6-2"), "Armour card shows LI rating d6-2")
	check_true(_any_label_contains(labels, "HI Armor"), "Armour card has HI Armor field")
	check_true(_any_label_contains(labels, "d6-4"), "Armour card shows HI rating d6-4")
	check_true(_any_label_contains(labels, "EN Armor"), "Armour card has EN Armor field")
	check_true(_any_label_contains(labels, "Toughness"), "Armour card has Toughness field")
	check_true(_any_label_contains(labels, "Equipped"), "Armour card indicates Equipped status")

	tab.queue_free()


func _test_dark_matter_basics_career_packages() -> void:
	var doc_dm := Doc.new(_rules)
	doc_dm.apply(CharacterDoc.ALL, func(c):
		c["setting"] = "Dark*Matter"
		c["species_id"] = 0 # Human
		c["profession_id"] = 0 # Combat Spec
	)

	var tab_dm = _mount(TAB_BASICS, doc_dm, false)
	await process_frame
	var labels_dm := _labels_in(tab_dm)
	check_true(_any_label_contains(labels_dm, "Career Package"), "Basics tab shows Career Package in Dark*Matter")

	# Gated: Core hero must not see Career Package
	var doc_core := Doc.new(_rules)
	doc_core.apply(CharacterDoc.ALL, func(c):
		c["setting"] = "Core"
		c["species_id"] = 0
		c["profession_id"] = 0
	)
	var tab_core = _mount(TAB_BASICS, doc_core, false)
	await process_frame
	var labels_core := _labels_in(tab_core)
	check_false(_any_label_contains(labels_core, "Career Package"), "Basics tab hides Career Package in Core")

	tab_dm.queue_free()
	tab_core.queue_free()


func _test_dark_matter_equipment_requisition() -> void:
	var doc_dm := Doc.new(_rules)
	doc_dm.apply(CharacterDoc.ALL, func(c):
		c["setting"] = "Dark*Matter"
		c["species_id"] = 0
		c["profession_id"] = 0
	)

	var tab_dm = _mount(TAB_EQUIPMENT, doc_dm, false)
	await process_frame
	var labels_dm := _labels_in(tab_dm)
	check_true(_any_label_contains(labels_dm, "Requisition"), "Equipment tab shows Requisition in Dark*Matter")
	check_true(_any_label_contains(labels_dm, "Item Availability"), "Requisition shows Item Availability")
	check_true(_any_label_contains(labels_dm, "Target score"), "Requisition shows calculated target score")

	# Gated: Core hero must not see Requisition
	var doc_core := Doc.new(_rules)
	doc_core.apply(CharacterDoc.ALL, func(c):
		c["setting"] = "Core"
		c["species_id"] = 0
		c["profession_id"] = 0
	)
	var tab_core = _mount(TAB_EQUIPMENT, doc_core, false)
	await process_frame
	var labels_core := _labels_in(tab_core)
	check_false(_any_label_contains(labels_core, "Requisition"), "Equipment tab hides Requisition in Core")

	tab_dm.queue_free()
	tab_core.queue_free()


func _spinboxes_in(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is SpinBox:
			out.append(child)
		out.append_array(_spinboxes_in(child))
	return out


func _test_custom_ability_target_spinbox() -> void:
	var doc := Doc.new(_rules)
	doc.set_species_id(0)
	doc.set_profession_id(0)

	var tab = _mount(TAB_BASICS, doc, false)
	await process_frame

	var spins := _spinboxes_in(tab)
	check_true(spins.size() > 0, "found SpinBox for custom ability target in offline mode")
	if not spins.is_empty():
		var spin: SpinBox = spins[0]
		check_eq(int(spin.value), 60, "default ability target is 60")
		spin.value = 65
		spin.value_changed.emit(65.0)
		await process_frame
		check_eq(
			AlternityNum.as_int(doc.raw().get("custom_ability_target", 0)),
			65,
			"SpinBox updates custom_ability_target on character doc"
		)
		check_eq(
			_rules.ability_point_total(doc.raw()),
			65,
			"rules.ability_point_total reflects customized target"
		)

	tab.queue_free()


func _test_durability_dazed_markers() -> void:
	check_eq(_rules.dazed_threshold(10), 5, "dazed threshold for 10 is 5")
	check_eq(_rules.dazed_threshold(11), 5, "dazed threshold for 11 is 5")
	check_eq(_rules.dazed_threshold(9), 4, "dazed threshold for 9 is 4")
	check_true(_rules.is_dazed_track("stun"), "stun is a dazed track")
	check_true(_rules.is_dazed_track("wound"), "wound is a dazed track")
	check_false(_rules.is_dazed_track("mortal"), "mortal is not a dazed track")
	check_false(_rules.is_dazed_track("fatigue"), "fatigue is not a dazed track")

	var doc := Doc.new(_rules)
	doc.set_species_id(0) # Human, CON 10 -> Stun 10, Wound 10, Mortal 5, Fatigue 10
	doc.set_profession_id(0)

	var tab = _mount(TAB_SUMMARY, doc, false)
	await process_frame

	var trackers: Dictionary = tab._damage_trackers
	check_true(trackers.has("stun"), "summary has stun damage tracker")
	check_true(trackers.has("wound"), "summary has wound damage tracker")
	check_true(trackers.has("mortal"), "summary has mortal damage tracker")

	var stun_tracker: DamageTrack = trackers.get("stun")
	check_eq(stun_tracker._marker_index, 5, "stun tracker marker index is 5")
	check_eq(stun_tracker._boxes.get_child_count(), 11, "stun tracker has 11 children (10 boxes + 1 marker)")
	check_true(stun_tracker._marker_node != null, "stun tracker instantiated marker node")
	check_eq(stun_tracker._boxes.get_child(5), stun_tracker._marker_node, "marker node sits at index 5 between box 5 and 6")

	# Check button tooltips
	var box_4: Button = stun_tracker._boxes.get_child(4)
	var box_6: Button = stun_tracker._boxes.get_child(6)
	check_false(box_4.tooltip_text.contains("(Dazed)"), "pre-marker box 5 does not say (Dazed)")
	check_true(box_6.tooltip_text.contains("(Dazed)"), "post-marker box 6 says (Dazed)")

	# Fast-path value update test
	stun_tracker.set_value(6)
	check_eq(stun_tracker.value(), 6, "tracker value updated to 6")
	check_eq(stun_tracker._boxes.get_child_count(), 11, "fast-path preserves child count")

	var mortal_tracker: DamageTrack = trackers.get("mortal")
	check_eq(mortal_tracker._marker_index, -1, "mortal tracker has no marker index")
	check_eq(mortal_tracker._boxes.get_child_count(), 5, "mortal tracker has exactly 5 boxes without marker")

	tab.queue_free()
