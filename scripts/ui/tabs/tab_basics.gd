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


func watched_sections() -> Array:
	# Everything: species, profession and abilities all cascade, and the setting
	# selector changes what the whole sheet may show.
	return CharacterDoc.ALL


func build(container: Container) -> void:
	_build_identity(container)
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

	var age := String(ctx.rules.age_category(doc.raw()))
	if not age.is_empty():
		Widgets.metric(box, "Age category", age.capitalize(), palette)


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

	var species := rules.get_species_by_id(doc.get_species_id())
	var summary := String(species.get("summary", species.get("description", "")))
	if not summary.is_empty():
		Widgets.muted_text(box, summary, palette, Widgets.FONT_CAPTION)


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

	var roll := Button.new()
	roll.text = "Roll random abilities for profession"
	roll.custom_minimum_size = Vector2(0, 44)
	roll.pressed.connect(func():
		var rolled: Dictionary = rules.roll_random_abilities_by_profession(doc.get_profession_id())
		if rolled.is_empty():
			return
		doc.apply(CharacterDoc.ALL, func(c):
			c["abilities"] = rolled.duplicate()
			rules.clamp_abilities_to_species(c)
			rules.clamp_trackers(c))
		save_requested.emit())
	box.add_child(roll)


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
