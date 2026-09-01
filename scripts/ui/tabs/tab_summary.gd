extends SheetTab
##
## The whole sheet at a glance, plus the damage trackers.
##
## Migrated last, because in the old file its code was scattered across five
## separate regions and the boundaries actively misled: main.gd lines 3201-3357
## sat in the middle of the Equipment block but were Summary-only.
##
## Almost everything here is a read of doc.summary(). The exceptions are the
## damage trackers and Last Resorts, which are the two things a player actually
## changes mid-session -- so this is the tab that stays open during play.
##

const ABILITIES := ["STR", "DEX", "CON", "INT", "WIL", "PER"]

## Damage tracks, in the order they are marked off.
const TRACKS := ["stun", "wound", "mortal", "fatigue"]


func watched_sections() -> Array:
	# Genuinely everything: this aggregates the entire character.
	return CharacterDoc.ALL


func build(container: Container) -> void:
	var summary := ctx.doc.summary()

	_build_validations(container, summary)
	_build_abilities(container, summary)
	_build_action(container, summary)
	_build_damage(container, summary)
	_build_last_resorts(container, summary)
	_build_movement(container, summary)
	_build_combat(container, summary)
	_build_notes(container)


## Rule violations first: an over-spent budget or an illegal choice is the thing
## you most need to see, so it is not buried under the stat blocks.
func _build_validations(container: Container, summary: Dictionary) -> void:
	var messages: Array = summary.get("validations", [])
	if messages.is_empty():
		return

	var palette := ctx.palette
	var box := Widgets.section(container, "Needs attention", palette)
	for message in messages:
		Widgets.text(box, String(message), palette, Widgets.FONT_DETAIL, palette.warning)


func _build_abilities(container: Container, summary: Dictionary) -> void:
	var palette := ctx.palette
	var box := Widgets.section(container, "Abilities", palette)

	var effective: Dictionary = summary.get("effective_abilities", {})
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(grid)

	for ability in ABILITIES:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)
		Widgets.muted_text(cell, ability, palette, Widgets.FONT_CAPTION)
		Widgets.text(cell, str(AlternityNum.as_int(effective.get(ability, 0))), palette, 20)

	Widgets.metric(box, "Ability points spent", str(AlternityNum.as_int(summary.get("ability_total", 0))), palette)


func _build_action(container: Container, summary: Dictionary) -> void:
	var palette := ctx.palette
	var action: Dictionary = summary.get("action_check", {})
	if action.is_empty():
		return

	var box := Widgets.section(container, "Action Check", palette)
	Widgets.metric(box, "Actions per round", str(AlternityNum.as_int(action.get("actions", 1), 1)), palette)
	Widgets.metric(box, "Situation die", String(action.get("die", "")), palette)

	# Amazing / Good / Ordinary / Marginal are the phase thresholds, so they read
	# best as a row rather than four separate lines.
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(grid)
	for degree in ["amazing", "good", "ordinary", "marginal"]:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)
		Widgets.muted_text(cell, degree.capitalize(), palette, Widgets.FONT_CAPTION)
		Widgets.text(cell, str(AlternityNum.as_int(action.get(degree, 0))), palette, Widgets.FONT_SUBHEADING)


## The trackers, and the main reason this tab is the one open during play.
func _build_damage(container: Container, summary: Dictionary) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var durability: Dictionary = summary.get("durability", {})
	var damage: Dictionary = doc.raw().get("damage", {})

	var box := Widgets.section(container, "Damage", palette)

	for track in TRACKS:
		var total := AlternityNum.as_int(durability.get(track, 0))
		var used := AlternityNum.as_int(damage.get(track, 0))

		var stepper := NumberStepper.new()
		box.add_child(stepper)
		stepper.setup(palette, "%s  (%d max)" % [track.capitalize(), total], used, 0, maxi(total, used))
		stepper.value_changed.connect(func(value: int):
			doc.apply([CharacterDoc.DAMAGE], func(c):
				var tracks: Dictionary = c.get("damage", {})
				tracks[track] = value
				c["damage"] = tracks
				rules.clamp_trackers(c))
			save_requested.emit())

	var heal := Button.new()
	heal.text = "Clear all damage"
	heal.custom_minimum_size = Vector2(0, 44)
	heal.pressed.connect(func():
		doc.apply([CharacterDoc.DAMAGE], func(c):
			var tracks: Dictionary = c.get("damage", {})
			for track in TRACKS:
				tracks[track] = 0
			c["damage"] = tracks)
		save_requested.emit())
	box.add_child(heal)


func _build_last_resorts(container: Container, summary: Dictionary) -> void:
	var doc := ctx.doc
	var palette := ctx.palette
	var resorts: Dictionary = summary.get("last_resorts", {})
	if resorts.is_empty():
		return

	var maximum := AlternityNum.as_int(resorts.get("max", 0))
	if maximum <= 0:
		return

	var box := Widgets.section(container, "Last Resorts", palette)
	var used := AlternityNum.as_int(doc.raw().get("last_resorts_used", 0))

	var stepper := NumberStepper.new()
	box.add_child(stepper)
	stepper.setup(palette, "Spent  (%d max)" % maximum, used, 0, maximum)
	stepper.value_changed.connect(func(value: int):
		doc.apply([CharacterDoc.DAMAGE], func(c): c["last_resorts_used"] = value)
		save_requested.emit())

	Widgets.metric(box, "Recovery cost", "%d SP each" % AlternityNum.as_int(resorts.get("cost", 0)), palette)


func _build_movement(container: Container, summary: Dictionary) -> void:
	var palette := ctx.palette
	var movement: Dictionary = summary.get("movement", {})
	if movement.is_empty():
		return

	var box := Widgets.section(container, "Movement", palette)
	for key in ["sprint", "run", "walk", "easy_swim", "fly"]:
		if not movement.has(key):
			continue
		var value: Variant = movement[key]
		if typeof(value) == TYPE_STRING and String(value).is_empty():
			continue
		Widgets.metric(box, key.capitalize().replace("_", " "), "%s m" % str(value), palette)

	var encumbrance: Dictionary = summary.get("encumbrance", {})
	if not encumbrance.is_empty():
		var penalty := AlternityNum.as_int(encumbrance.get("penalty", 0))
		if penalty != 0:
			Widgets.metric(box, "Encumbrance penalty", "%+d steps" % penalty, palette)


func _build_combat(container: Container, summary: Dictionary) -> void:
	var palette := ctx.palette
	var equipment: Dictionary = summary.get("equipment", {})
	if equipment.is_empty():
		return

	var attacks: Array = equipment.get("attack_forms", [])
	if not attacks.is_empty():
		var box := Widgets.section(container, "Attacks", palette)
		for form in attacks:
			if typeof(form) != TYPE_DICTIONARY:
				continue
			Widgets.text(box, String(form.get("name", "?")), palette, Widgets.FONT_DETAIL, palette.accent)
			Widgets.muted_text(box, _attack_line(form), palette, Widgets.FONT_CAPTION)

	var armor: Array = equipment.get("combat_armor", [])
	if not armor.is_empty():
		var box := Widgets.section(container, "Armour", palette)
		for row in armor:
			if typeof(row) != TYPE_DICTIONARY:
				continue
			Widgets.text(box, String(row.get("name", "?")), palette, Widgets.FONT_DETAIL, palette.accent)
			Widgets.muted_text(box, _armor_line(row), palette, Widgets.FONT_CAPTION)


func _attack_line(form: Dictionary) -> String:
	var parts: Array = []
	var damage := String(form.get("damage", "")).strip_edges()
	if not damage.is_empty():
		parts.append(damage)
	var score: Variant = form.get("score", form.get("skill_score", null))
	if score != null:
		parts.append("score %s" % str(score))
	var range_text := String(form.get("range", "")).strip_edges()
	if not range_text.is_empty():
		parts.append(range_text)
	return "  |  ".join(parts)


func _armor_line(row: Dictionary) -> String:
	var parts: Array = []
	for key in ["li", "hi", "en"]:
		var value := String(row.get(key, "")).strip_edges()
		if not value.is_empty():
			parts.append("%s %s" % [key.to_upper(), value])
	var toughness := String(row.get("toughness", "")).strip_edges()
	if not toughness.is_empty():
		parts.append(toughness)
	return "  |  ".join(parts)


## Notes live here because this is the tab that stays open during a session.
##
## Committed on focus-exit rather than per keystroke: a text_changed handler
## would rebuild the whole Summary tab on every character typed, and take the
## text field with it.
func _build_notes(container: Container) -> void:
	var doc := ctx.doc
	var palette := ctx.palette
	var box := Widgets.section(container, "Notes", palette)

	var edit := TextEdit.new()
	edit.text = doc.get_notes()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0, 160)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(edit)

	edit.focus_exited.connect(func():
		if edit.text == doc.get_notes():
			return
		doc.set_notes(edit.text)
		save_requested.emit())
