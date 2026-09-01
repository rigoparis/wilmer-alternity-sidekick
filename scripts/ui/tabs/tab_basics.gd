extends SheetTab
##
## Identity, setting, species, profession and ability scores.
##
## Owns the Setting selector, which is what gates Dark Matter content
## everywhere else -- changing it here changes which FX faiths, mutations and
## catalog entries the rest of the sheet will offer. That is why setting is a
## global-blast-radius change: it invalidates every other tab.
##
## The four profession-specific choices (Free Agent resistance bonus, Combat
## Spec bonus specialty, Mindwalker psionic focus, Diplomat bonus) appear only
## for the profession that has them, rather than being drawn greyed-out for
## everyone.
##

## Ability order is fixed by the rules, not alphabetical.
const ABILITIES := ["STR", "DEX", "CON", "INT", "WIL", "PER"]

const ABILITY_NAMES := {
	"STR": "Strength",
	"DEX": "Dexterity",
	"CON": "Constitution",
	"INT": "Intelligence",
	"WIL": "Will",
	"PER": "Personality",
}

## Value stored on the character, and the label shown for it.
const SETTINGS := [
	{"value": "Core", "label": "Core"},
	{"value": "Star*Drive", "label": "Star*Drive"},
	{"value": "Dark*Matter", "label": "Dark*Matter"},
]


## The age rows, in the order they run. Mirrors AlternityRules.AGE_MODIFIERS.
const AGE_CATEGORIES := [
	"adolescent", "young_adult", "mature", "middle_aged", "old", "ancient",
]


func watched_sections() -> Array:
	# Everything: species, profession and abilities all cascade, and the setting
	# selector changes what the whole sheet may show.
	return CharacterDoc.ALL


func build(container: Container) -> void:
	_build_identity(container)
	_build_advancement(container)
	_build_origin(container)
	_build_abilities(container)
	_build_profession_options(container)


# --- Identity --------------------------------------------------------------

func _build_identity(container: Container) -> void:
	var doc := ctx.doc
	var palette := ctx.palette
	var box := Widgets.section(container, "Hero", palette)

	_text_field(box, "Hero name", doc.get_hero_name(), func(value: String): doc.set_hero_name(value))
	_text_field(box, "Player", doc.get_player_name(), func(value: String): doc.set_player_name(value))
	_text_field(box, "Career", doc.get_career(), func(value: String): doc.set_career(value))

	_build_setting_picker(box)

	_build_age_picker(box)


## Level and the achievement points that drive it.
##
## Lives here as well as on the Achievements tab because this is where the
## hero's level is read, and levelling up was unreachable from it -- the only
## input for earned points was a tab away.
func _build_advancement(container: Container) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var raw := doc.raw()

	var box := Widgets.section(container, "Advancement", palette)

	var points := AlternityNum.as_int(raw.get("achievement_points", 0))
	var level: int = rules.achievements.achievement_level_for_points(points)
	Widgets.metric(box, "Achievement level", str(level), palette)

	var into_level: int = rules.achievements.achievement_points_available(raw)
	var to_next: int = rules.achievements.achievement_points_to_next_level(raw)
	if to_next > 0:
		Widgets.progress_metric(
			box, "Progress to level %d" % (level + 1), into_level, into_level + to_next,
			palette, false
		)

	# The GM awards these between adventures, so it is an input.
	var stepper := NumberStepper.new()
	box.add_child(stepper)
	stepper.setup(palette, "Achievement points earned", points, 0, 999)
	stepper.value_changed.connect(func(value: int):
		doc.apply(CharacterDoc.ALL, func(c): rules.achievements.set_achievement_points(c, value))
		save_requested.emit())


## Age category, and what it is currently doing to the hero.
##
## A selector rather than a read-only line: age was derived and displayed with
## no way to change it. Whether it moves any ability score depends on the
## age_effects optional rule, so the row says which of the two it is instead of
## leaving a control that silently does nothing.
func _build_age_picker(parent: Container) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var current := String(rules.age_category(doc.raw()))

	var label := Label.new()
	label.text = "Age category"
	label.add_theme_color_override("font_color", palette.muted)
	label.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	parent.add_child(label)

	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.custom_minimum_size = Vector2(0, 42)
	var selected := 0
	for i in AGE_CATEGORIES.size():
		var id := String(AGE_CATEGORIES[i])
		picker.add_item(id.capitalize().replace("_", " "), i)
		if id == current:
			selected = i
	picker.select(selected)
	picker.item_selected.connect(func(index: int):
		var chosen := String(AGE_CATEGORIES[index])
		doc.apply(CharacterDoc.ALL, func(c): c["age_category"] = chosen)
		save_requested.emit())
	parent.add_child(picker)

	if rules.optional_rule_enabled(doc.raw(), "age_effects"):
		var mods: Array = []
		for ability in ["STR", "DEX", "CON", "INT", "WIL", "PER"]:
			var delta: int = rules.age_modifier(doc.raw(), ability)
			if delta != 0:
				mods.append("%s %+d" % [ability, delta])
		Widgets.muted_text(
			parent,
			"Applies: %s" % (", ".join(mods) if not mods.is_empty() else "no ability change"),
			palette, Widgets.FONT_CAPTION
		)
	else:
		Widgets.muted_text(
			parent,
			"Age categories are off for this campaign, so every hero counts as a "
			+ "Young Adult for rules purposes. Recorded here for reference only.",
			palette, Widgets.FONT_CAPTION
		)


## The control that decides which optional-setting content the rest of the sheet
## may offer.
func _build_setting_picker(parent: Container) -> void:
	var doc := ctx.doc
	var palette := ctx.palette
	var current := String(doc.raw().get("setting", "Core"))

	var label := Label.new()
	label.text = "Setting"
	label.add_theme_color_override("font_color", palette.muted)
	label.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	parent.add_child(label)

	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.custom_minimum_size = Vector2(0, 42)
	var selected := 0
	for i in SETTINGS.size():
		picker.add_item(String(SETTINGS[i]["label"]), i)
		# Stored values have varied ("Dark*Matter" and "Dark Matter" both
		# appear), so match loosely rather than on an exact string.
		if _same_setting(current, String(SETTINGS[i]["value"])):
			selected = i
	picker.select(selected)
	parent.add_child(picker)

	picker.item_selected.connect(func(index: int):
		var chosen := String(SETTINGS[index]["value"])
		if _same_setting(current, chosen):
			return
		# ALL, not META: the setting determines which FX faiths, mutations and
		# catalog entries every other tab may show.
		doc.apply(CharacterDoc.ALL, func(c): c["setting"] = chosen)
		save_requested.emit())

	Widgets.muted_text(
		parent,
		"Optional-setting content only appears while its setting is selected.",
		palette,
		Widgets.FONT_CAPTION
	)


## Compare two setting names tolerantly.
##
## Saved characters contain both "Dark*Matter" and "Dark Matter", and the rules
## matcher is likewise fuzzy; an exact comparison here would silently fail to
## preselect the stored value and look like the setting had reset to Core.
func _same_setting(a: String, b: String) -> bool:
	var left := a.strip_edges().to_lower().replace("*", " ").replace("-", " ")
	var right := b.strip_edges().to_lower().replace("*", " ").replace("-", " ")
	return left == right


# --- Species and profession ------------------------------------------------

func _build_origin(container: Container) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var box := Widgets.section(container, "Origin", palette)

	var species_entries: Array = []
	for entry in rules.species:
		if typeof(entry) == TYPE_DICTIONARY:
			species_entries.append(entry)
	_id_picker(
		box, "Species", species_entries, doc.get_species_id(),
		func(id: int): doc.set_species_id(id)
	)

	var profession_ids: Array = rules.professions_by_id.keys()
	profession_ids.sort_custom(func(a, b): return AlternityNum.as_int(a) < AlternityNum.as_int(b))
	var professions: Array = []
	for id in profession_ids:
		professions.append(rules.professions_by_id[id])
	_id_picker(
		box, "Profession", professions, doc.get_profession_id(),
		func(id: int): doc.set_profession_id(id)
	)

	_build_species_detail(box)
	_build_profession_detail(box)


## What the chosen species is, and what taking it actually gives you.
##
## The tab showed a species picker and nothing else -- it read species["summary"],
## a key the data does not have, so the line never rendered and the mechanical
## notes that do exist were never surfaced anywhere. Choosing a race meant
## knowing the manual already, which is the opposite of the point.
func _build_species_detail(parent: Container) -> void:
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var raw := ctx.doc.raw()
	var species := rules.get_species_by_id(ctx.doc.get_species_id())
	if species.is_empty():
		return

	Widgets.separator(parent, palette)
	Widgets.subheading(parent, String(species.get("name", "Species")), palette)

	var description := String(species.get("description", "")).strip_edges()
	if not description.is_empty():
		Widgets.text(parent, description, palette, Widgets.FONT_CAPTION)

	# Derived from the same fields the rules read, so this cannot drift from what
	# the species actually does.
	var limits: Dictionary = species.get("ability_limits", {})
	var bands: Array = []
	for ability in ABILITIES:
		var band: Array = limits.get(ability, [])
		if band.size() >= 2:
			bands.append("%s %d-%d" % [
				ability, AlternityNum.as_int(band[0]), AlternityNum.as_int(band[1])
			])
	if not bands.is_empty():
		Widgets.metric(parent, "Ability range", "  ".join(bands), palette)

	var free_names: Array = []
	for skill_id in rules.get_free_skill_ids(raw):
		var skill_name := rules.skill_name_for_id(AlternityNum.as_int(skill_id))
		if not skill_name.is_empty():
			free_names.append(skill_name)
	if not free_names.is_empty():
		Widgets.metric(parent, "Free broad skills", ", ".join(free_names), palette)

	var skill_bonus := AlternityNum.as_int(species.get("skill_points", 0))
	if skill_bonus != 0:
		Widgets.metric(parent, "Bonus skill points", "%+d" % skill_bonus, palette)
	var broad_bonus := AlternityNum.as_int(species.get("broad_skills", 0))
	if broad_bonus != 0:
		Widgets.metric(parent, "Bonus broad skills", "%+d" % broad_bonus, palette)

	# A step modifier, not a die string: 0 for most species, -1 for T'sa. A
	# negative step is an improvement, so it is worth saying so rather than
	# printing a bare "-1".
	var action_step := AlternityNum.as_int(species.get("action_step", 0))
	if action_step != 0:
		Widgets.metric(
			parent, "Action check",
			"%+d step%s" % [action_step, "" if abs(action_step) == 1 else "s"]
				+ ("  (better)" if action_step < 0 else "  (worse)"),
			palette
		)

	var durability := AlternityNum.as_float(species.get("durability_multiplier", 1.0), 1.0)
	if not is_equal_approx(durability, 1.0):
		Widgets.metric(parent, "Durability", "CON x %s" % Widgets.format_number(durability), palette)

	if bool(species.get("psionic", false)):
		var psi := AlternityNum.as_float(species.get("psi_multiplier", 1.0), 1.0)
		Widgets.metric(parent, "Psionic", "yes, energy pool WIL x %s" % Widgets.format_number(psi), palette)
	if bool(species.get("can_fly", false)):
		Widgets.metric(parent, "Flight", "can fly", palette)
	elif bool(species.get("can_glide", false)):
		Widgets.metric(parent, "Flight", "can glide", palette)

	for note in species.get("notes", []):
		Widgets.muted_text(parent, "- %s" % String(note), palette, Widgets.FONT_CAPTION)


## What the chosen profession is and what it grants.
##
## The notes were already written, with sources, and nothing displayed them.
## The first is the description; the rest are the mechanical grants.
func _build_profession_detail(parent: Container) -> void:
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var profession := rules.get_profession_by_id(ctx.doc.get_profession_id())
	if profession.is_empty():
		return

	Widgets.separator(parent, palette)
	Widgets.subheading(parent, String(profession.get("name", "Profession")), palette)

	var minimums: Dictionary = profession.get("ability_minimums", {})
	var required: Array = []
	for ability in ABILITIES:
		if minimums.has(ability):
			required.append("%s %d" % [ability, AlternityNum.as_int(minimums[ability])])
	if not required.is_empty():
		Widgets.metric(parent, "Requires", "  ".join(required), palette)

	var notes: Array = profession.get("notes", [])
	for i in notes.size():
		var note := String(notes[i])
		if i == 0:
			Widgets.text(parent, note, palette, Widgets.FONT_CAPTION)
		else:
			Widgets.muted_text(parent, "- %s" % note, palette, Widgets.FONT_CAPTION)


# --- Abilities -------------------------------------------------------------

func _build_abilities(container: Container) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var box := Widgets.section(container, "Abilities", palette)

	Widgets.metric(box, "Points spent", str(rules.ability_total(doc.raw())), palette)

	for ability in ABILITIES:
		_build_ability_row(box, ability)

	Widgets.separator(box, palette)
	_build_generation(box)


## The three ways the rules let you generate a starting spread.
##
## Method I rolls against the profession, Method II against the species; the
## third is the profession-weighted random spread. All three go through
## _apply_rolled, which clamps each score into the legal range rather than
## trusting the roll -- a species or profession minimum can be higher than what
## the dice produced.
func _build_generation(parent: Container) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules

	Widgets.muted_text(
		parent,
		"Generating replaces all six scores and resets the point target. "
		+ "Rolled scores are clamped into the legal band for your species and "
		+ "profession, so a low roll still meets a requirement.",
		ctx.palette,
		Widgets.FONT_CAPTION
	)

	# There used to be a third button, "Random spread for profession", wired to
	# roll_random_abilities_by_profession. That returns the *formula table*
	# ({"STR": "10+d4", ...}), not rolled scores, so every ability was coerced
	# from an unparseable string to 0 and then clamped up to its minimum: the
	# button reliably produced a floor-value hero. It also duplicated Method I,
	# which rolls the same table properly, so it is gone rather than repaired.
	var methods := [
		{
			"label": "Method I - roll for your profession",
			"note": "Each ability is rolled on the spread for your profession, so "
				+ "the scores it cares about start high. Table G2.",
			"roll": func(): return rules.roll_abilities_method_1(doc.get_profession_id()),
		},
		{
			"label": "Method II - roll for your species",
			"note": "Each ability is rolled on the spread for your species, giving "
				+ "a hero typical of that race rather than of a job. Table G3.",
			"roll": func(): return rules.roll_abilities_method_2(doc.get_species_id()),
		},
	]

	for method in methods:
		var button := Button.new()
		button.text = String(method["label"])
		button.custom_minimum_size = Vector2(0, 44)
		var roll: Callable = method["roll"]
		button.pressed.connect(func(): _apply_rolled(roll.call()))
		parent.add_child(button)
		Widgets.muted_text(parent, String(method["note"]), ctx.palette, Widgets.FONT_CAPTION)


## Clamp each rolled score into its legal band and reset the point target.
##
## custom_ability_target is recorded so the budget reflects what the roll cost,
## rather than continuing to compare against a purchased spread that no longer
## exists.
func _apply_rolled(rolled: Variant) -> void:
	if typeof(rolled) != TYPE_DICTIONARY or rolled.is_empty():
		return

	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	doc.apply(CharacterDoc.ALL, func(c):
		var abilities: Dictionary = c.get("abilities", {})
		for ability in ABILITIES:
			if not rolled.has(ability):
				continue
			var limits: Array = rules.ability_limits(c, ability)
			abilities[ability] = clampi(
				AlternityNum.as_int(rolled[ability]),
				AlternityNum.as_int(limits[0], 4),
				AlternityNum.as_int(limits[1], 14)
			)
		c["abilities"] = abilities
		c["custom_ability_target"] = rules.ability_total(c)
		rules.clamp_trackers(c))
	save_requested.emit()


func _build_ability_row(parent: Container, ability: String) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules

	var limits: Array = rules.ability_limits(doc.raw(), ability)
	var minimum: int = AlternityNum.as_int(limits[0], 4) if limits.size() > 0 else 4
	var maximum: int = AlternityNum.as_int(limits[1], 14) if limits.size() > 1 else 14

	var stepper := NumberStepper.new()
	parent.add_child(stepper)
	stepper.setup(
		ctx.palette,
		"%s (%s)  %d-%d" % [ABILITY_NAMES.get(ability, ability), ability, minimum, maximum],
		doc.get_ability(StringName(ability)),
		minimum,
		maximum
	)
	# set_ability clamps and cascades; the stepper is only the input.
	stepper.value_changed.connect(func(value: int):
		doc.set_ability(StringName(ability), value)
		save_requested.emit())

	# Show the effective score when species, mutations or cybertech move it away
	# from the purchased one, so the difference is visible rather than confusing.
	var effective := AlternityNum.as_int(rules.effective_abilities(doc.raw()).get(ability, 0))
	if effective != doc.get_ability(StringName(ability)):
		Widgets.muted_text(
			parent,
			"Effective %s: %d" % [ability, effective],
			ctx.palette,
			Widgets.FONT_CAPTION
		)


# --- Profession-specific choices -------------------------------------------

## Only the current profession's choice is drawn.
##
## The old renderer built all four unconditionally and hid the irrelevant ones,
## which meant every profession paid for the others being constructed.
func _build_profession_options(container: Container) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var codes: Array = rules.profession_codes(doc.raw())

	var rows: Array = []
	if codes.has("F"):
		rows.append(_free_agent_row)
	if codes.has("C"):
		rows.append(_combat_spec_row)
	if codes.has("M"):
		rows.append(_mindwalker_row)
	if codes.has("D"):
		rows.append(_diplomat_row)
	if rows.is_empty():
		return

	var box := Widgets.section(container, "Profession Options", ctx.palette)
	for row in rows:
		row.call(box)


func _free_agent_row(parent: Container) -> void:
	var doc := ctx.doc
	var current := String(doc.raw().get("free_agent_rm_bonus", ""))
	# Any ability except Constitution qualifies for the resistance bonus.
	var choices: Array = []
	for ability in ABILITIES:
		if ability != "CON":
			choices.append({"id": ability, "name": ABILITY_NAMES.get(ability, ability)})

	_string_picker(parent, "Resistance bonus ability", choices, current, func(value: String):
		doc.apply(CharacterDoc.ALL, func(c): c["free_agent_rm_bonus"] = value)
		save_requested.emit())


func _combat_spec_row(parent: Container) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var specialties: Array = rules.combat_spec_bonus_specialties(doc.raw())
	if specialties.is_empty():
		Widgets.muted_text(parent, "No eligible combat specialties yet.", ctx.palette, Widgets.FONT_CAPTION)
		return

	_id_picker(
		parent, "Combat Spec bonus specialty", specialties,
		AlternityNum.as_int(doc.raw().get("combat_spec_bonus_specialty", -1), -1),
		func(id: int):
			doc.apply(CharacterDoc.ALL, func(c): c["combat_spec_bonus_specialty"] = id)
			save_requested.emit()
	)


func _mindwalker_row(parent: Container) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var broads: Array = []
	for skill in rules.skills:
		if typeof(skill) == TYPE_DICTIONARY and String(skill.get("type", "")) == "broad":
			if AlternityNum.as_int(skill.get("id", 0)) >= 900:
				broads.append(skill)
	if broads.is_empty():
		return

	_id_picker(
		parent, "Psionic focus", broads,
		AlternityNum.as_int(doc.raw().get("mindwalker_psionic_focus", -1), -1),
		func(id: int):
			doc.apply(CharacterDoc.ALL, func(c): c["mindwalker_psionic_focus"] = id)
			save_requested.emit()
	)


func _diplomat_row(parent: Container) -> void:
	var doc := ctx.doc
	var current := String(doc.raw().get("diplomat_bonus", ""))
	var choices := [
		{"id": "contact", "name": "Additional contact"},
		{"id": "culture", "name": "Culture specialty"},
	]
	_string_picker(parent, "Diplomat bonus", choices, current, func(value: String):
		doc.apply(CharacterDoc.ALL, func(c): c["diplomat_bonus"] = value)
		save_requested.emit())


# --- Small builders --------------------------------------------------------

func _text_field(parent: Container, label_text: String, value: String, changed: Callable) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", ctx.palette.muted)
	label.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	parent.add_child(label)

	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0, 42)
	parent.add_child(edit)

	# On focus-exit and submit rather than per keystroke: a text_changed handler
	# would rebuild the tab on every character typed and take the field with it.
	edit.text_submitted.connect(func(text: String): changed.call(text))
	edit.focus_exited.connect(func(): changed.call(edit.text))


## Dropdown over entries carrying an integer "id" and a "name".
func _id_picker(parent: Container, label_text: String, entries: Array, current_id: int, changed: Callable) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", ctx.palette.muted)
	label.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	parent.add_child(label)

	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.custom_minimum_size = Vector2(0, 42)
	parent.add_child(picker)

	var selected_index := -1
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var id := AlternityNum.as_int(entry.get("id", i))
		picker.add_item(String(entry.get("name", "?")), id)
		if id == current_id:
			selected_index = i
	if selected_index >= 0:
		picker.select(selected_index)

	picker.item_selected.connect(func(index: int): changed.call(picker.get_item_id(index)))


## Dropdown over entries carrying a string "id" and a "name".
func _string_picker(parent: Container, label_text: String, entries: Array, current_id: String, changed: Callable) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", ctx.palette.muted)
	label.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	parent.add_child(label)

	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.custom_minimum_size = Vector2(0, 42)
	parent.add_child(picker)

	var ids: Array = []
	var selected_index := -1
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var id := String(entry.get("id", ""))
		ids.append(id)
		picker.add_item(String(entry.get("name", id)), i)
		if id == current_id:
			selected_index = i
	if selected_index >= 0:
		picker.select(selected_index)

	picker.item_selected.connect(func(index: int): changed.call(String(ids[index])))
