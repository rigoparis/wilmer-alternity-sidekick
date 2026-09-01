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

	# Validations span the full width -- they are the one thing you must not
	# miss. Everything else splits, so a desktop window shows the stat block and
	# the trackers at once instead of one narrow strip scrolled twice.
	_build_validations(container, summary)

	var split := columns(container)
	var left: Container = split[0]
	var right: Container = split[1]

	_build_abilities(left, summary)
	_build_action(left, summary)
	_build_movement(left, summary)

	_build_damage(right, summary)
	_build_last_resorts(right, summary)
	_build_combat(right, summary)

	# Everything the hero actually has, spelled out here rather than linked to.
	# This is the tab that stays open at the table, and the point of the app is
	# to replace reaching for a manual -- so a section that says "3 perks" and
	# makes you go to another tab to find out which has failed at its job.
	var reference := columns(container)
	_build_skills(reference[0])
	_build_psionics(reference[0])
	_build_fx(reference[0])
	_build_perks_flaws(reference[1])
	_build_cybertech(reference[1])
	_build_mutations(reference[1])
	_build_achievements(reference[1])
	_build_species_notes(reference[1])

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


## Abilities as a table, and the three numbers you actually roll against.
##
## Six cells in a 3-wide grid stretched to the window width put STR at one edge
## of a maximised screen and PER at the other -- by the time you read the last
## you have forgotten the first. A fixed table keeps the six together in a block
## you take in at once, and has room for the untrained score and resistance
## modifier the old compact summary showed and this one had dropped.
func _build_abilities(container: Container, summary: Dictionary) -> void:
	var palette := ctx.palette
	var rules: AlternityRules = ctx.rules
	var raw := ctx.doc.raw()
	var box := Widgets.section(container, "Abilities", palette)

	var effective: Dictionary = summary.get("effective_abilities", {})
	var base: Dictionary = raw.get("abilities", {})

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", Widgets.GAP_SECTION)
	grid.add_theme_constant_override("v_separation", Widgets.GAP_TIGHT)
	box.add_child(grid)

	for heading in ["Ability", "Score", "Untrained", "Resistance"]:
		Widgets.table_cell(
			grid, heading, palette, true,
			HORIZONTAL_ALIGNMENT_LEFT if heading == "Ability" else HORIZONTAL_ALIGNMENT_RIGHT
		)

	for ability in ABILITIES:
		var base_score := AlternityNum.as_int(base.get(ability, 0))
		var score := AlternityNum.as_int(effective.get(ability, base_score))
		# Say where a bonus came from rather than silently showing a raised
		# number: a mutation or permanent power moving a score is worth seeing.
		var score_text := str(score)
		if score != base_score:
			score_text = "%d  (%d %+d)" % [score, base_score, score - base_score]

		Widgets.table_cell(grid, ability, palette, false)
		Widgets.table_cell(grid, score_text, palette, false, HORIZONTAL_ALIGNMENT_RIGHT)
		Widgets.table_cell(
			grid, str(rules.untrained_score(score)), palette, false, HORIZONTAL_ALIGNMENT_RIGHT
		)
		Widgets.table_cell(
			grid, "%+d" % rules.character_resistance_modifier(raw, ability),
			palette, false, HORIZONTAL_ALIGNMENT_RIGHT
		)

	Widgets.metric(box, "Ability points spent", str(AlternityNum.as_int(summary.get("ability_total", 0))), palette)


func _build_action(container: Container, summary: Dictionary) -> void:
	var palette := ctx.palette
	var action: Dictionary = summary.get("action_check", {})
	if action.is_empty():
		return

	var box := Widgets.section(container, "Action Check", palette)
	Widgets.metric(box, "Actions per round", str(AlternityNum.as_int(action.get("actions", 1), 1)), palette)
	Widgets.metric(box, "Situation die", String(action.get("die", "")), palette)

	# The four thresholds are one reading, so they go in a table that stays
	# together rather than four cells stretched over the width of the window.
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", Widgets.GAP_SECTION)
	grid.add_theme_constant_override("v_separation", Widgets.GAP_TIGHT)
	box.add_child(grid)

	for degree in ["amazing", "good", "ordinary", "marginal"]:
		Widgets.table_cell(grid, degree.capitalize(), palette, true, HORIZONTAL_ALIGNMENT_RIGHT)
	for degree in ["amazing", "good", "ordinary", "marginal"]:
		Widgets.table_cell(
			grid, str(AlternityNum.as_int(action.get(degree, 0))),
			palette, false, HORIZONTAL_ALIGNMENT_RIGHT
		)


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

		# Boxes, the way it is marked on paper. A stepper showed the number but
		# hid the track, and during play what you need is how much room is left.
		var tracker := DamageTrack.new()
		box.add_child(tracker)
		tracker.setup(palette, track.capitalize(), used, total)
		tracker.value_changed.connect(func(value: int):
			doc.apply([CharacterDoc.DAMAGE], func(c):
				var tracks: Dictionary = c.get("damage", {})
				tracks[track] = value
				c["damage"] = tracks
				rules.clamp_trackers(c))
			save_requested.emit())


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

	# Same consumable-track shape as damage, so it gets the same boxes rather
	# than the stepper it used to share with it.
	var tracker := DamageTrack.new()
	box.add_child(tracker)
	tracker.setup(palette, "Spent", used, maximum)
	tracker.value_changed.connect(func(value: int):
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


## Every skill the hero holds, with the score to roll against and the rules text
## that governs it.
##
## Broads carry their specialties, and anything with roll notes or rank benefits
## states them here in full: those are exactly the lines a player would otherwise
## stop to look up mid-scene.
func _build_skills(container: Container) -> void:
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var raw := ctx.doc.raw()

	var rows: Array = []
	for skill in rules.selected_skills(raw):
		if not rules.is_psionic_skill(skill):
			rows.append(skill)
	if rows.is_empty():
		return

	var box := Widgets.section(container, "Skills", palette)
	Widgets.muted_text(
		box,
		"A broad skill rolls its ability score at +d4. A specialty rolls that "
		+ "ability plus its rank at +d0, or the broad score at +d4 if only the "
		+ "broad is trained.",
		palette, Widgets.FONT_CAPTION
	)
	_build_skill_rows(box, rows)


## Psionics are the same shape as skills but a separate discipline, so they get
## their own heading rather than being mixed into the skill list.
func _build_psionics(container: Container) -> void:
	var rules: AlternityRules = ctx.rules
	var raw := ctx.doc.raw()

	var rows: Array = []
	for skill in rules.selected_skills(raw):
		if rules.is_psionic_skill(skill):
			rows.append(skill)
	if rows.is_empty():
		return

	var box := Widgets.section(container, "Psionics", ctx.palette)
	_build_skill_rows(box, rows)


func _build_skill_rows(box: Container, rows: Array) -> void:
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var raw := ctx.doc.raw()

	# Broads first, then their specialties, so the list reads the way the tree
	# does rather than in whatever order the ids happened to land.
	rows.sort_custom(func(a, b):
		var a_broad: bool = a.get("type", "") == "broad"
		var b_broad: bool = b.get("type", "") == "broad"
		if a_broad != b_broad:
			return a_broad
		return String(a.get("name", "")) < String(b.get("name", "")))

	for skill in rows:
		var is_broad: bool = skill.get("type", "") == "broad"
		var score: Dictionary = skill.get("score", {})
		var rank := AlternityNum.as_int(skill.get("rank", 0))

		var name := String(rules.skill_label(skill))
		if not is_broad:
			name = "    " + name
		var value := "rank %d  -  %d  %s" % [
			rank,
			AlternityNum.as_int(score.get("ordinary", 0)),
			String(score.get("die", "")),
		]
		var row := Widgets.metric(box, name, value, palette)
		if is_broad:
			(row.get_child(0) as Label).add_theme_color_override("font_color", palette.accent)

		# The reference text, inline. skill_detail resolves it against this
		# character, so the ranks shown are the ones actually reached.
		var detail: Dictionary = rules.skill_detail(skill, raw)

		var complex := String(detail.get("complex_check", "")).strip_edges()
		if not complex.is_empty():
			Widgets.muted_text(box, complex, palette, Widgets.FONT_CAPTION)

		for note in detail.get("roll_notes", []):
			if _is_general_rule(String(note)):
				continue
			Widgets.muted_text(box, "- %s" % String(note), palette, Widgets.FONT_CAPTION)

		var benefits: Dictionary = detail.get("rank_benefits", {})
		for benefit_rank_value in _sorted_ranks(benefits):
			var benefit_rank := AlternityNum.as_int(benefit_rank_value)
			# Benefits the hero has not reached yet still show, greyed: knowing
			# what the next rank buys is half of why you read this.
			var reached := rank >= benefit_rank
			Widgets.text(
				box,
				"Rank %d: %s" % [benefit_rank, String(benefits.get(benefit_rank, benefits.get(str(benefit_rank), "")))],
				palette, Widgets.FONT_CAPTION,
				palette.text if reached else palette.muted
			)


## Notes that are true of every skill of their kind, rather than of this one.
##
## skill_detail prefixes each skill's roll notes with how its score and situation
## die are derived. That is worth stating in a detail view opened for one skill;
## repeated down a list of forty it is noise that buries the notes that actually
## differ. Stated once at the head of the section instead.
const GENERAL_RULE_PREFIXES := [
	"Score is the linked ability score",
	"Score is linked ability +",
	"If only the parent broad skill is trained",
]


func _is_general_rule(note: String) -> bool:
	for prefix in GENERAL_RULE_PREFIXES:
		if note.begins_with(prefix):
			return true
	return false


## Rank-benefit keys arrive as strings from JSON, so they are sorted as numbers
## rather than lexically -- otherwise rank 12 files between rank 1 and rank 2.
func _sorted_ranks(benefits: Dictionary) -> Array:
	var ranks: Array = []
	for key in benefits:
		ranks.append(AlternityNum.as_int(key))
	ranks.sort()
	return ranks


func _build_fx(container: Container) -> void:
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var raw := ctx.doc.raw()
	if not rules.fx.is_fx_talent(raw):
		return

	var selected: Array = rules.fx.selected_fx_skills(raw)
	if selected.is_empty():
		return

	var box := Widgets.section(container, "FX", palette)

	var pool: int = rules.fx.energy_pool(raw)
	var drain: int = rules.fx.permanent_fx_energy_drain(raw)
	Widgets.metric(box, "Energy pool", str(pool), palette)
	if drain > 0:
		Widgets.metric(box, "Reserved by permanent powers", "-%d" % drain, palette)
		Widgets.metric(box, "Usable", str(maxi(0, pool - drain)), palette)

	for skill in selected:
		var skill_name := String(skill.get("name", ""))
		var is_broad: bool = String(skill.get("type", "")) == "broad"
		var score: Dictionary = rules.fx.fx_skill_score(raw, skill_name)
		var row := Widgets.metric(
			box,
			skill_name if is_broad else "    " + skill_name,
			"rank %d  -  %d  %s" % [
				AlternityNum.as_int(skill.get("rank", 0)),
				AlternityNum.as_int(score.get("ordinary", 0)),
				String(score.get("die", "")),
			],
			palette
		)
		if is_broad:
			(row.get_child(0) as Label).add_theme_color_override("font_color", palette.accent)
		if rules.fx.is_fx_skill_permanent(raw, skill_name):
			Widgets.muted_text(box, "    Always active", palette, Widgets.FONT_CAPTION)

		var description := String(skill.get("description", "")).strip_edges()
		if not description.is_empty():
			Widgets.muted_text(box, description, palette, Widgets.FONT_CAPTION)

	for effect in rules.fx.permanent_fx_effects_summary(raw):
		Widgets.muted_text(box, String(effect), palette, Widgets.FONT_CAPTION)


func _build_perks_flaws(container: Container) -> void:
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var raw := ctx.doc.raw()

	var perks: Array = rules.selected_perks(raw)
	var flaws: Array = rules.selected_flaws(raw)
	if perks.is_empty() and flaws.is_empty():
		return

	var box := Widgets.section(container, "Perks and Flaws", palette)
	for perk in perks:
		_build_option_entry(box, perk, "cost", "SP")
	for flaw in flaws:
		_build_option_entry(box, flaw, "bonus", "SP granted")


## One perk, flaw or mutation, with the text that says what it does.
func _build_option_entry(box: Container, entry: Dictionary, value_key: String, unit: String) -> void:
	var palette := ctx.palette
	var label := String(entry.get("name", ""))
	if bool(entry.get("gm_given", false)):
		label += "  (GM)"
	Widgets.metric(
		box, label, "%d %s" % [AlternityNum.as_int(entry.get(value_key, 0)), unit], palette
	)
	var description := String(entry.get("description", entry.get("summary", ""))).strip_edges()
	if not description.is_empty():
		Widgets.muted_text(box, description, palette, Widgets.FONT_CAPTION)


func _build_cybertech(container: Container) -> void:
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var raw := ctx.doc.raw()
	if not rules.cybertech.cybertech_enabled(raw):
		return

	var installed: Array = rules.cybertech.installed_cybertech(raw)
	if installed.is_empty():
		return

	var box := Widgets.section(container, "Cybertech", palette)
	Widgets.progress_metric(
		box, "Cyber tolerance",
		rules.cybertech.cyber_tolerance_used(raw),
		rules.cybertech.cyber_tolerance_total(raw),
		palette
	)

	for install in installed:
		var item: Dictionary = install.get("item", {})
		Widgets.metric(
			box,
			String(item.get("name", "")),
			String(install.get("quality", "")).capitalize(),
			palette
		)
		var description := String(item.get("description", item.get("summary", ""))).strip_edges()
		if not description.is_empty():
			Widgets.muted_text(box, description, palette, Widgets.FONT_CAPTION)


func _build_mutations(container: Container) -> void:
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var raw := ctx.doc.raw()

	var advantages: Array = rules.mutations.selected_mutation_advantages(raw)
	var drawbacks: Array = rules.mutations.selected_mutation_drawbacks(raw)
	if advantages.is_empty() and drawbacks.is_empty():
		return

	var box := Widgets.section(container, "Mutations", palette)
	for mutation in advantages:
		_build_option_entry(box, mutation, "cost", "points")
	for drawback in drawbacks:
		_build_option_entry(box, drawback, "value", "points granted")


func _build_achievements(container: Container) -> void:
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var raw := ctx.doc.raw()

	var purchased: Array = rules.achievements.selected_achievements(raw)
	if purchased.is_empty():
		return

	var box := Widgets.section(container, "Achievement Benefits", palette)
	for entry in purchased:
		var achievement: Dictionary = rules.get_achievement_by_id(
			String(entry.get("achievement_id", ""))
		)
		Widgets.metric(
			box,
			String(rules.achievements.achievement_display_name(achievement, entry)),
			"%d SP" % AlternityNum.as_int(entry.get("cost", 0)),
			palette
		)
		var summary_text := String(achievement.get("summary", "")).strip_edges()
		if not summary_text.is_empty():
			Widgets.muted_text(box, summary_text, palette, Widgets.FONT_CAPTION)


## Species rules and the rolls they modify.
##
## These are the lines that decide a check at the table, and were previously
## reachable only by remembering which species you picked and looking it up.
func _build_species_notes(container: Container) -> void:
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var raw := ctx.doc.raw()

	var rule_notes: Array = rules.species_rule_notes(raw)
	var roll_notes: Array = rules.species_roll_notes_for_character(raw)
	if rule_notes.is_empty() and roll_notes.is_empty():
		return

	var box := Widgets.section(container, "Species Rules", palette)
	for note in rule_notes:
		Widgets.text(box, "- %s" % String(note), palette, Widgets.FONT_CAPTION)
	if not roll_notes.is_empty():
		Widgets.subheading(box, "Roll notes", palette)
		for note in roll_notes:
			Widgets.text(box, "- %s" % String(note), palette, Widgets.FONT_CAPTION)


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
