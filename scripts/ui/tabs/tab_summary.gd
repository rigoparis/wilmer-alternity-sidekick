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

const DETAIL_ROUTE := preload("res://scenes/ui/routes/skill_detail_route.tscn")
const ABILITIES := ["STR", "DEX", "CON", "INT", "WIL", "PER"]

## Damage tracks, in the order they are marked off.
const TRACKS := ["stun", "wound", "mortal", "fatigue"]

var _damage_trackers: Dictionary = {}
var _recovery_host: Container
var _last_resorts_tracker: DamageTrack
var _last_resorts_actions_host: Container
var _rendered_recovery_damage: Array = [-1, -1, -1]
var _rendered_last_resorts_state: Array = [-1, -1, -1]


func watched_sections() -> Array:
	# Genuinely everything: this aggregates the entire character.
	return CharacterDoc.ALL


func unbind() -> void:
	super.unbind()
	_damage_trackers.clear()
	_recovery_host = null
	_last_resorts_tracker = null
	_last_resorts_actions_host = null
	_rendered_recovery_damage = [-1, -1, -1]
	_rendered_last_resorts_state = [-1, -1, -1]


func _rebuild() -> void:
	_damage_trackers.clear()
	_recovery_host = null
	_last_resorts_tracker = null
	_last_resorts_actions_host = null
	_rendered_recovery_damage = [-1, -1, -1]
	_rendered_last_resorts_state = [-1, -1, -1]
	super._rebuild()


func _on_document_changed(sections: PackedStringArray) -> void:
	if not _touches_watched(sections):
		return

	if _can_update_damage_in_place(sections):
		_update_damage_in_place()
		return

	super._on_document_changed(sections)


func _can_update_damage_in_place(sections: PackedStringArray) -> bool:
	if not is_visible_in_tree() or _needs_rebuild:
		return false
	if _damage_trackers.is_empty():
		return false
	for s in sections:
		if s != String(CharacterDoc.DAMAGE) and s != String(CharacterDoc.SKILLS):
			return false
	return true


func _update_damage_in_place() -> void:
	if ctx == null or ctx.doc == null:
		return
	var raw := ctx.doc.raw()
	var damage: Dictionary = raw.get("damage", {})

	for track in TRACKS:
		var tracker: DamageTrack = _damage_trackers.get(track)
		if tracker != null and is_instance_valid(tracker):
			var track_val := AlternityNum.as_int(damage.get(track, 0))
			if tracker.value() != track_val:
				tracker.set_value(track_val)

	var recovery_state := [
		AlternityNum.as_int(damage.get("fatigue", 0)),
		AlternityNum.as_int(damage.get("wound", 0)),
		AlternityNum.as_int(damage.get("mortal", 0))
	]
	if _recovery_host != null and is_instance_valid(_recovery_host):
		if _rendered_recovery_damage != recovery_state:
			_rendered_recovery_damage = recovery_state
			_render_recovery(_recovery_host, damage)

	var used_resorts := AlternityNum.as_int(raw.get("last_resorts_used", 0))
	if _last_resorts_tracker != null and is_instance_valid(_last_resorts_tracker):
		if _last_resorts_tracker.value() != used_resorts:
			_last_resorts_tracker.set_value(used_resorts)

	var rebought := AlternityNum.as_int(raw.get("last_resorts_rebought", 0))
	var summary := ctx.doc.summary()
	var sp_left := AlternityNum.as_int(summary.get("skill_points_remaining", 0))
	var lr_state := [used_resorts, rebought, sp_left]
	if _last_resorts_actions_host != null and is_instance_valid(_last_resorts_actions_host):
		if _rendered_last_resorts_state != lr_state:
			_rendered_last_resorts_state = lr_state
			_render_last_resorts_actions(_last_resorts_actions_host, summary)


func build(container: Container) -> void:
	var summary := ctx.doc.summary()

	# Validations span the full width -- they are the one thing you must not
	# miss. Everything else splits, so a desktop window shows the stat block and
	# the trackers at once instead of one narrow strip scrolled twice.
	_build_validations(container, summary)

	var split := columns(container)
	var left: Container = split[0]
	var right: Container = split[1]

	_build_core_panel(left, summary)

	_build_damage(right, summary)
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
		Widgets.text(box, "• " + String(message), palette, Widgets.FONT_DETAIL, palette.warning)


## Abilities as a table, and the three numbers you actually roll against.
##
## Six cells in a 3-wide grid stretched to the window width put STR at one edge
## of a maximised screen and PER at the other -- by the time you read the last
## you have forgotten the first. A fixed table keeps the six together in a block
## you take in at once, and has room for the untrained score and resistance
## modifier the old compact summary showed and this one had dropped.
## Concentrated core attributes panel: Abilities, Action Check, Movement, and Last Resorts.
func _build_core_panel(container: Container, summary: Dictionary) -> void:
	var palette := ctx.palette
	var box := Widgets.section(container, "Core Attributes", palette)

	_build_abilities_content(box, summary)
	Widgets.separator(box, palette)
	_build_action_content(box, summary)
	Widgets.separator(box, palette)
	_build_movement_content(box, summary)
	Widgets.separator(box, palette)
	_build_last_resorts_content(box, summary)


func _build_abilities_content(box: Container, summary: Dictionary) -> void:
	var palette := ctx.palette
	var rules: AlternityRules = ctx.rules
	var raw := ctx.doc.raw()

	Widgets.subheading(box, "Abilities", palette)

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
		var score_text := str(score)
		if score != base_score:
			score_text = "%d (%+d)" % [score, score - base_score]

		var cells := [
			Widgets.table_cell(grid, ability, palette, false),
			Widgets.table_cell(grid, score_text, palette, false, HORIZONTAL_ALIGNMENT_RIGHT),
			Widgets.table_cell(
				grid, str(rules.untrained_score(score)), palette, false, HORIZONTAL_ALIGNMENT_RIGHT
			),
			Widgets.table_cell(
				grid, "%+d" % rules.character_resistance_modifier(raw, ability),
				palette, false, HORIZONTAL_ALIGNMENT_RIGHT
			),
		]
		for cell in cells:
			(cell as Label).autowrap_mode = TextServer.AUTOWRAP_OFF

	var ability_spent := AlternityNum.as_int(summary.get("ability_total", 0))
	var ability_target := AlternityNum.as_int(summary.get("ability_target", 60))
	var ability_text := "%d / %d" % [ability_spent, ability_target] if ability_spent != ability_target else str(ability_spent)
	Widgets.metric(box, "Ability points spent", ability_text, palette)


func _build_action_content(box: Container, summary: Dictionary) -> void:
	var palette := ctx.palette
	var action: Dictionary = summary.get("action_check", {})
	if action.is_empty():
		return

	Widgets.subheading(box, "Action Check", palette)
	Widgets.metric(box, "Actions per round", str(AlternityNum.as_int(action.get("actions", 1), 1)), palette)
	Widgets.metric(box, "Situation die", String(action.get("die", "")), palette)

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

	_damage_trackers.clear()
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
		_damage_trackers[track] = tracker

	_recovery_host = VBoxContainer.new()
	_recovery_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_recovery_host)
	_render_recovery(_recovery_host, damage)


## Downtime recovery checks, between sessions or during rest.
##
## Source: Gamemaster Guide p. 54. The cadences are deliberately unlike each
## other and that is the whole point: fatigue comes back hourly, wounds take
## weeks, and mortal damage never heals on its own -- so it is offered as a note
## rather than a button that cannot work.
func _render_recovery(container: Container, damage: Dictionary) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	var fatigue_used := AlternityNum.as_int(damage.get("fatigue", 0))
	var wound_used := AlternityNum.as_int(damage.get("wound", 0))
	var mortal_used := AlternityNum.as_int(damage.get("mortal", 0))

	if fatigue_used <= 0 and wound_used <= 0 and mortal_used <= 0:
		return

	Widgets.separator(container, ctx.palette)
	Widgets.muted_text(container, "Recovery", ctx.palette, Widgets.FONT_CAPTION)

	var recovery: Dictionary = ctx.rules.combat.RECOVERY

	if fatigue_used > 0:
		_build_recovery_action(
			container,
			"fatigue",
			"Rest 1 hour (Recover Fatigue)",
			String(recovery.get("fatigue", {}).get("note", "Requires complete rest. One check per hour."))
		)

	if wound_used > 0:
		_build_recovery_action(
			container,
			"wound",
			"Rest 1 week (Recover Wound)",
			String(recovery.get("wound", {}).get("note", "Requires rest. One check per week, or treatment with Medical Science."))
		)

	if mortal_used > 0:
		var note := Widgets.muted_text(
			container,
			"Mortal damage: %s" % String(recovery.get("mortal", {}).get("note", "Does not heal naturally. Only surgery repairs it.")),
			ctx.palette,
			Widgets.FONT_CAPTION
		)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(1, 0)


func _build_recovery_action(
	container: Container,
	track: String,
	button_text: String,
	caption_text: String
) -> void:
	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	container.add_child(row)

	if ctx.can_roll():
		var button := Button.new()
		button.name = "Recover" + track.capitalize() + "Button"
		button.text = button_text
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 36)
		button.clip_text = true
		button.pressed.connect(func(): _on_recovery_check(track))
		row.add_child(button)

	var label := Widgets.muted_text(row, caption_text, ctx.palette, Widgets.FONT_CAPTION)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(1, 0)


func _on_recovery_check(track: String) -> void:
	if ctx == null or ctx.doc == null or ctx.rules == null or not ctx.can_roll():
		return
	var row: Dictionary = ctx.rules.combat.RECOVERY.get(track, {})
	if row.is_empty():
		return
	var skill_id: int = AlternityNum.as_int(row.get("skill_id", AlternityRules.PHYSICAL_RESOLVE_SKILL_ID), AlternityRules.PHYSICAL_RESOLVE_SKILL_ID)
	var skill: Dictionary = ctx.rules.get_skill_by_id(skill_id)
	if skill.is_empty():
		return

	var cadence: String = String(row.get("cadence", ""))
	var reason := "Recovery (%s, 1 %s rest)" % [track.capitalize(), cadence]
	var check := SkillCheck.call_for(
		ctx.rules.skill_label(skill),
		0,
		reason,
		skill_id
	)
	var rolled = await ctx.checks.run_called(check, ctx.doc, skill)
	if not is_instance_valid(self) or rolled == null:
		return
	var degree: String = (rolled as SkillCheck).degree()
	var amount: int = ctx.rules.combat.recovery_amount(track, degree)
	if amount <= 0:
		return

	var restored: int = AlternityNum.as_int(ctx.doc.apply([CharacterDoc.DAMAGE], func(c: Dictionary) -> int:
		var tracks: Dictionary = c.get("damage", {})
		var current: int = AlternityNum.as_int(tracks.get(track, 0))
		var to_restore: int = mini(current, amount)
		tracks[track] = maxi(0, current - to_restore)
		c["damage"] = tracks
		ctx.rules.clamp_trackers(c)
		return to_restore
	), 0)

	if restored > 0:
		save_requested.emit()


func _build_movement_content(box: Container, summary: Dictionary) -> void:
	var palette := ctx.palette
	var movement: Dictionary = summary.get("movement", {})
	if movement.is_empty():
		return

	Widgets.subheading(box, "Movement", palette)
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


func _build_last_resorts_content(box: Container, summary: Dictionary) -> void:
	var doc := ctx.doc
	var palette := ctx.palette
	var resorts: Dictionary = summary.get("last_resorts", {})
	if resorts.is_empty():
		return

	var maximum := AlternityNum.as_int(resorts.get("max", 0))
	if maximum <= 0:
		return

	Widgets.subheading(box, "Last Resorts", palette)
	var used := AlternityNum.as_int(doc.raw().get("last_resorts_used", 0))
	var cost := AlternityNum.as_int(resorts.get("cost", 0))

	var tracker := DamageTrack.new()
	box.add_child(tracker)
	tracker.setup(palette, "Spent", used, maximum)
	tracker.value_changed.connect(func(value: int):
		doc.apply([CharacterDoc.DAMAGE], func(c): c["last_resorts_used"] = value)
		save_requested.emit())
	_last_resorts_tracker = tracker

	Widgets.metric(box, "Recovery cost", "%d SP each" % cost, palette)

	_last_resorts_actions_host = VBoxContainer.new()
	_last_resorts_actions_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_last_resorts_actions_host)
	_render_last_resorts_actions(_last_resorts_actions_host, summary)


func _render_last_resorts_actions(host: Container, summary: Dictionary) -> void:
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()

	var doc := ctx.doc
	var palette := ctx.palette
	var resorts: Dictionary = summary.get("last_resorts", {})
	var maximum := AlternityNum.as_int(resorts.get("max", 0))
	var used := AlternityNum.as_int(doc.raw().get("last_resorts_used", 0))
	var cost := AlternityNum.as_int(resorts.get("cost", 0))
	var rebought := AlternityNum.as_int(doc.raw().get("last_resorts_rebought", 0))
	var sp_left := AlternityNum.as_int(summary.get("skill_points_remaining", 0))

	# Interactive Re-buy action row (SP deduction)
	var action_row := HBoxContainer.new()
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_theme_constant_override("separation", Widgets.GAP_ROW)
	host.add_child(action_row)

	var buy_btn := Button.new()
	buy_btn.text = "Re-buy Last Resort (%d SP)" % cost
	buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_btn.custom_minimum_size = Vector2(0, 36)
	var can_rebuy := used > 0 and sp_left >= cost
	buy_btn.disabled = not can_rebuy
	if used <= 0:
		buy_btn.tooltip_text = "No last resort points are currently spent."
	elif sp_left < cost:
		buy_btn.tooltip_text = "Not enough skill points remaining (costs %d SP, have %d SP)." % [cost, sp_left]
	else:
		buy_btn.tooltip_text = "Spend %d SP to recover 1 spent Last Resort point." % cost
	buy_btn.pressed.connect(func():
		doc.apply([CharacterDoc.DAMAGE, CharacterDoc.SKILLS], func(c: Dictionary):
			var current_used := AlternityNum.as_int(c.get("last_resorts_used", 0))
			var current_rebought := AlternityNum.as_int(c.get("last_resorts_rebought", 0))
			c["last_resorts_used"] = maxi(0, current_used - 1)
			c["last_resorts_rebought"] = current_rebought + 1
		)
		save_requested.emit())
	action_row.add_child(buy_btn)

	if rebought > 0:
		var refund_btn := Button.new()
		refund_btn.text = "Refund (+%d SP)" % cost
		refund_btn.tooltip_text = "Undo 1 rebought Last Resort and refund %d SP." % cost
		refund_btn.custom_minimum_size = Vector2(100, 36)
		refund_btn.pressed.connect(func():
			doc.apply([CharacterDoc.DAMAGE, CharacterDoc.SKILLS], func(c: Dictionary):
				var current_used := AlternityNum.as_int(c.get("last_resorts_used", 0))
				var current_rebought := AlternityNum.as_int(c.get("last_resorts_rebought", 0))
				c["last_resorts_used"] = mini(maximum, current_used + 1)
				c["last_resorts_rebought"] = maxi(0, current_rebought - 1)
			)
			save_requested.emit())
		action_row.add_child(refund_btn)

		Widgets.muted_text(host, "Rebought in play: %d (%d SP spent total)" % [rebought, rebought * cost], palette, Widgets.FONT_CAPTION)


func _build_combat(container: Container, summary: Dictionary) -> void:
	var palette := ctx.palette
	var equipment: Dictionary = summary.get("equipment", {})
	if equipment.is_empty():
		return

	var attacks: Array = equipment.get("attack_forms", [])
	if not attacks.is_empty():
		var box := Widgets.section(container, "Attack Forms", palette)
		for form in attacks:
			if typeof(form) != TYPE_DICTIONARY:
				continue
			_build_attack_card(box, form, palette)

	var armor: Array = equipment.get("combat_armor", [])
	if not armor.is_empty():
		var box := Widgets.section(container, "Armour", palette)
		for row in armor:
			if typeof(row) != TYPE_DICTIONARY:
				continue
			Widgets.text(box, String(row.get("name", "?")), palette, Widgets.FONT_DETAIL, palette.accent)
			Widgets.muted_text(box, _armor_line(row), palette, Widgets.FONT_CAPTION)


func _build_attack_card(parent: Container, form: Dictionary, palette: ThemePalette) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Widgets.flat_style(palette.surface, palette.border, 6, true))
	parent.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)

	var card := VBoxContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	margin.add_child(card)

	# Weapon / Attack Title
	var title_lbl := Label.new()
	title_lbl.text = String(form.get("name", "?"))
	title_lbl.add_theme_color_override("font_color", palette.accent)
	title_lbl.add_theme_font_size_override("font_size", Widgets.FONT_BODY)
	card.add_child(title_lbl)

	# Row 1: Score & Die
	var r1 := HBoxContainer.new()
	r1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	card.add_child(r1)

	var score_val: Variant = form.get("score", form.get("skill_score", "-"))
	_add_stat_cell(r1, "Score", str(score_val), palette, true)
	_add_stat_cell(r1, "Die", String(form.get("base_die", form.get("die", "+d0"))), palette, true)

	# Row 2: Damage O/G/A
	var dmg_val: String = String(form.get("damage", "-")).strip_edges()
	if dmg_val.is_empty():
		dmg_val = "-"
	_add_stat_cell(card, "Damage O/G/A", dmg_val, palette, false)

	# Row 3: Type & Range
	var r3 := HBoxContainer.new()
	r3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r3.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	card.add_child(r3)

	var type_val: String = String(form.get("type", "-")).strip_edges()
	_add_stat_cell(r3, "Type", type_val if not type_val.is_empty() else "-", palette, true)
	var range_val: String = String(form.get("range", "-")).strip_edges()
	_add_stat_cell(r3, "Range", range_val if not range_val.is_empty() else "-", palette, true)

	# Row 4: Hide, Clip, Mass
	var r4 := HBoxContainer.new()
	r4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r4.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	card.add_child(r4)

	var hide_val: String = String(form.get("hide", "-")).strip_edges()
	_add_stat_cell(r4, "Hide", hide_val if not hide_val.is_empty() else "-", palette, true)
	var clip_val: String = String(form.get("clip_size", form.get("clip", "-"))).strip_edges()
	_add_stat_cell(r4, "Clip", clip_val if not clip_val.is_empty() else "-", palette, true)
	var mass_val: String = String(form.get("mass", "-")).strip_edges()
	_add_stat_cell(r4, "Mass", mass_val if not mass_val.is_empty() else "-", palette, true)


func _add_stat_cell(parent: Container, label_text: String, value_text: String, palette: ThemePalette, expand: bool) -> Container:
	var cell := VBoxContainer.new()
	if expand:
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", 2)
	parent.add_child(cell)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", palette.muted)
	lbl.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	cell.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.add_theme_color_override("font_color", palette.text)
	val.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	cell.add_child(val)

	return cell


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

	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", Widgets.GAP_TIGHT)
	grid.add_theme_constant_override("v_separation", Widgets.GAP_SECTION)
	box.add_child(grid)

	for title in ["Rank", "Skill", "O / G / A", "Die", "Roll"]:
		var hdr := Label.new()
		hdr.text = title
		hdr.add_theme_color_override("font_color", palette.muted)
		hdr.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
		if title == "Skill":
			hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elif title == "Roll":
			hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		elif title == "O / G / A":
			hdr.tooltip_text = "Ordinary / Good / Amazing"
		grid.add_child(hdr)

	# Group broads and their specialties
	var broad_map: Dictionary = {}
	var standalone: Array = []
	for skill in rows:
		var is_broad: bool = skill.get("type", "") == "broad"
		var skill_id: int = AlternityNum.as_int(skill.get("id", -1))
		if is_broad:
			if not broad_map.has(skill_id):
				broad_map[skill_id] = {"broad": skill, "specialties": []}
			else:
				broad_map[skill_id]["broad"] = skill
		else:
			var broad_id: int = AlternityNum.as_int(skill.get("broad_id", -1))
			if broad_id >= 0:
				if not broad_map.has(broad_id):
					var broad_def: Dictionary = rules.get_skill_by_id(broad_id)
					if not broad_def.is_empty():
						var broad_copy := broad_def.duplicate(true)
						broad_copy["rank"] = rules.skill_rank(raw, broad_id)
						broad_copy["score"] = rules.skill_score(raw, broad_def)
						broad_copy["type"] = "broad"
						broad_map[broad_id] = {"broad": broad_copy, "specialties": []}
					else:
						standalone.append(skill)
						continue
				broad_map[broad_id]["specialties"].append(skill)
			else:
				standalone.append(skill)

	var ability_order := {"STR": 0, "DEX": 1, "CON": 2, "INT": 3, "WIL": 4, "PER": 5}
	var sorted_groups: Array = broad_map.values()
	sorted_groups.sort_custom(func(a, b):
		var broad_a: Dictionary = a.get("broad", {})
		var broad_b: Dictionary = b.get("broad", {})
		var stat_a: String = String(broad_a.get("stat", "STR"))
		var stat_b: String = String(broad_b.get("stat", "STR"))
		var order_a: int = ability_order.get(stat_a, 99)
		var order_b: int = ability_order.get(stat_b, 99)
		if order_a != order_b:
			return order_a < order_b
		return String(broad_a.get("name", "")) < String(broad_b.get("name", ""))
	)

	for group in sorted_groups:
		var broad: Dictionary = group.get("broad", {})
		if not broad.is_empty():
			_add_summary_skill_row(grid, broad, true, 0)
		for spec in group.get("specialties", []):
			_add_summary_skill_row(grid, spec, false, 1)

	for spec in standalone:
		_add_summary_skill_row(grid, spec, false, 0)


func _add_summary_skill_row(grid: GridContainer, skill: Dictionary, is_broad: bool, indent_level: int) -> void:
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var raw := ctx.doc.raw()
	var skill_id: int = AlternityNum.as_int(skill.get("id", -1))
	var rank: int = rules.skill_rank(raw, skill_id)
	var score: Dictionary = rules.skill_score(raw, skill)
	var full_label := String(rules.skill_label(skill))
	var skill_name := String(skill.get("name", full_label)) if indent_level > 0 else full_label

	# 1. Rank
	var rank_str := "Broad" if is_broad else str(rank)
	var rank_lbl := Label.new()
	rank_lbl.text = rank_str
	rank_lbl.add_theme_color_override("font_color", palette.muted)
	rank_lbl.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(rank_lbl)

	# 2. Skill Name & Info button
	var skill_cell := HBoxContainer.new()
	skill_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_cell.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	grid.add_child(skill_cell)

	var name_btn := Button.new()
	name_btn.flat = true
	name_btn.text = ("    " + skill_name) if indent_level > 0 else skill_name
	name_btn.tooltip_text = "View details for %s" % full_label
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.clip_text = true
	name_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_btn.custom_minimum_size = Vector2(1, 0)
	name_btn.add_theme_color_override("font_color", palette.accent if is_broad else palette.text)
	name_btn.add_theme_color_override("font_hover_color", palette.accent)
	name_btn.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	name_btn.pressed.connect(func(): _open_detail(skill))
	skill_cell.add_child(name_btn)

	var info_btn := Button.new()
	info_btn.icon = preload("res://assets/question-square.svg")
	info_btn.expand_icon = true
	info_btn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	info_btn.tooltip_text = "View details for %s" % full_label
	info_btn.custom_minimum_size = Vector2(22, 22)
	info_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	info_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	info_btn.add_theme_color_override("icon_normal_color", palette.text)
	info_btn.add_theme_color_override("icon_hover_color", palette.accent)
	info_btn.add_theme_color_override("icon_pressed_color", palette.accent)
	info_btn.add_theme_stylebox_override("normal", Widgets.flat_style(palette.surface_soft, Color(0, 0, 0, 0), 3))
	info_btn.add_theme_stylebox_override("hover", Widgets.flat_style(palette.surface_soft.lightened(0.1), palette.accent, 3))
	info_btn.add_theme_stylebox_override("pressed", Widgets.flat_style(palette.accent, Color(0, 0, 0, 0), 3))
	info_btn.pressed.connect(func(): _open_detail(skill))
	skill_cell.add_child(info_btn)

	# 3. Score (O / G / A)
	var ord_val: int = AlternityNum.as_int(score.get("ordinary", 0))
	var good_val: int = AlternityNum.as_int(score.get("good", 0))
	var amaz_val: int = AlternityNum.as_int(score.get("amazing", 0))
	var score_lbl := Label.new()
	score_lbl.text = "%d / %d / %d" % [ord_val, good_val, amaz_val]
	score_lbl.add_theme_color_override("font_color", palette.text)
	score_lbl.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	score_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(score_lbl)

	# 4. Die
	var die_str: String = String(score.get("die", "+d0"))
	var die_lbl := Label.new()
	die_lbl.text = die_str
	die_lbl.add_theme_color_override("font_color", palette.muted)
	die_lbl.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	die_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(die_lbl)

	# 5. Roll Button
	var roll_btn := Button.new()
	roll_btn.name = "RollButton_" + str(skill_id)
	roll_btn.icon = preload("res://assets/dice-d20.svg")
	roll_btn.expand_icon = true
	roll_btn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	roll_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roll_btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	roll_btn.tooltip_text = "Roll %s" % full_label
	roll_btn.custom_minimum_size = Vector2(34, 28)
	roll_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	roll_btn.add_theme_stylebox_override("normal", Widgets.flat_style(palette.surface_soft, palette.accent, 4))
	roll_btn.add_theme_stylebox_override("hover", Widgets.flat_style(palette.surface_soft.lightened(0.1), palette.accent, 4))
	roll_btn.add_theme_stylebox_override("pressed", Widgets.flat_style(palette.accent, Color(0, 0, 0, 0), 4))
	roll_btn.add_theme_stylebox_override("disabled", Widgets.flat_style(palette.surface, Color(palette.muted, 0.25), 4))
	roll_btn.add_theme_color_override("icon_normal_color", palette.text)
	roll_btn.add_theme_color_override("icon_hover_color", palette.text)
	roll_btn.add_theme_color_override("icon_pressed_color", palette.text)
	roll_btn.add_theme_color_override("icon_disabled_color", Color(palette.muted, 0.35))
	roll_btn.disabled = not ctx.can_roll()
	roll_btn.pressed.connect(func(): _roll_skill(skill))
	grid.add_child(roll_btn)


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

	var grid := GridContainer.new()
	grid.columns = 6
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", Widgets.GAP_TIGHT)
	grid.add_theme_constant_override("v_separation", Widgets.GAP_SECTION)
	box.add_child(grid)

	for title in ["Rank", "Power", "O / G / A", "Die", "FX Cost", "Roll"]:
		var hdr := Label.new()
		hdr.text = title
		hdr.add_theme_color_override("font_color", palette.muted)
		hdr.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
		if title == "Power":
			hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elif title == "O / G / A":
			hdr.tooltip_text = "Ordinary / Good / Amazing"
		elif title == "Roll":
			hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(hdr)

	var groups := _group_fx_powers(selected)
	for group in groups:
		var broad: Dictionary = group.get("broad", {})
		if not broad.is_empty():
			_add_summary_fx_row(grid, broad, true, 0)
		for spec in group.get("specialties", []):
			_add_summary_fx_row(grid, spec, false, 1 if not broad.is_empty() else 0)

	var perms := rules.fx.permanent_fx_effects_summary(raw)
	if not perms.is_empty():
		Widgets.separator(box, palette)
		Widgets.subheading(box, "Always Active Effects", palette)
		for effect in perms:
			_build_permanent_effect(box, effect)


func _add_summary_fx_row(grid: GridContainer, item: Dictionary, is_broad: bool, indent_level: int) -> void:
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var raw := ctx.doc.raw()
	var item_name: String = String(item.get("name", ""))

	# 1. Rank
	var rank_str := "Broad" if is_broad else str(AlternityNum.as_int(item.get("rank", 0)))
	var rank_lbl := Label.new()
	rank_lbl.text = rank_str
	rank_lbl.add_theme_color_override("font_color", palette.muted)
	rank_lbl.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(rank_lbl)

	# 2. Power Name & Info button
	var power_cell := HBoxContainer.new()
	power_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power_cell.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	grid.add_child(power_cell)

	var name_btn := Button.new()
	name_btn.flat = true
	name_btn.text = ("    " + item_name) if indent_level > 0 else item_name
	name_btn.tooltip_text = "View details for %s" % item_name
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.clip_text = true
	name_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_btn.custom_minimum_size = Vector2(1, 0)
	name_btn.add_theme_color_override("font_color", palette.accent if is_broad else palette.text)
	name_btn.add_theme_color_override("font_hover_color", palette.accent)
	name_btn.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	name_btn.pressed.connect(func(): _open_detail(item))
	power_cell.add_child(name_btn)

	var info_btn := Button.new()
	info_btn.icon = preload("res://assets/question-square.svg")
	info_btn.expand_icon = true
	info_btn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	info_btn.tooltip_text = "View details for %s" % item_name
	info_btn.custom_minimum_size = Vector2(22, 22)
	info_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	info_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	info_btn.add_theme_color_override("icon_normal_color", palette.text)
	info_btn.add_theme_color_override("icon_hover_color", palette.accent)
	info_btn.add_theme_color_override("icon_pressed_color", palette.accent)
	info_btn.add_theme_stylebox_override("normal", Widgets.flat_style(palette.surface_soft, Color(0, 0, 0, 0), 3))
	info_btn.add_theme_stylebox_override("hover", Widgets.flat_style(palette.surface_soft.lightened(0.1), palette.accent, 3))
	info_btn.add_theme_stylebox_override("pressed", Widgets.flat_style(palette.accent, Color(0, 0, 0, 0), 3))
	info_btn.pressed.connect(func(): _open_detail(item))
	power_cell.add_child(info_btn)

	# 3. Score (O / G / A)
	var score: Dictionary = rules.fx.fx_skill_score(raw, item_name)
	var usable: bool = bool(score.get("usable", true))
	var score_lbl := Label.new()
	if usable:
		var ord_val: int = AlternityNum.as_int(score.get("ordinary", 0))
		var good_val: int = AlternityNum.as_int(score.get("good", 0))
		var amaz_val: int = AlternityNum.as_int(score.get("amazing", 0))
		score_lbl.text = "%d / %d / %d" % [ord_val, good_val, amaz_val]
		score_lbl.add_theme_color_override("font_color", palette.text)
	else:
		score_lbl.text = "-"
		score_lbl.add_theme_color_override("font_color", palette.muted)
	score_lbl.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	score_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(score_lbl)

	# 4. Die
	var die_lbl := Label.new()
	die_lbl.text = String(score.get("die", "+d0")) if usable else "-"
	die_lbl.add_theme_color_override("font_color", palette.muted)
	die_lbl.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	die_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(die_lbl)

	# 5. FX Cost
	var fx_cost_lbl := Label.new()
	if is_broad:
		fx_cost_lbl.text = "-"
	else:
		var is_perm: bool = rules.fx.is_fx_skill_permanent(raw, item_name)
		if is_perm:
			var perm_cost := AlternityNum.as_int(item.get("permanent_cost", 0))
			fx_cost_lbl.text = "%d (Perm)" % perm_cost
		else:
			var act: Dictionary = rules.fx.fx_activation_cost(raw, item_name)
			var base_pts := AlternityNum.as_int(act.get("points", 1))
			var max_pts := AlternityNum.as_int(act.get("points_max", base_pts))
			var surcharge := AlternityNum.as_int(act.get("untrained_surcharge", 0))
			if max_pts > base_pts:
				fx_cost_lbl.text = "%d-%d" % [base_pts + surcharge, max_pts + surcharge]
			else:
				fx_cost_lbl.text = str(AlternityNum.as_int(act.get("total", base_pts)))
	fx_cost_lbl.add_theme_color_override("font_color", palette.muted)
	fx_cost_lbl.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	fx_cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(fx_cost_lbl)

	# 6. Roll Button
	# Broad-skill rows have no standalone roll — the player rolls the specialty.
	# Permanent powers are always active and never need a check.
	var is_perm_for_roll: bool = (not is_broad) and rules.fx.is_fx_skill_permanent(raw, item_name)
	var roll_btn := Button.new()
	roll_btn.name = "RollButton_FX_" + item_name.replace(" ", "_")
	roll_btn.icon = preload("res://assets/dice-d20.svg")
	roll_btn.expand_icon = true
	roll_btn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	roll_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roll_btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	roll_btn.tooltip_text = "Always active — no roll needed." if is_perm_for_roll else ("Roll %s" % item_name)
	roll_btn.custom_minimum_size = Vector2(34, 28)
	roll_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	roll_btn.add_theme_stylebox_override("normal", Widgets.flat_style(palette.surface_soft, palette.accent, 4))
	roll_btn.add_theme_stylebox_override("hover", Widgets.flat_style(palette.surface_soft.lightened(0.1), palette.accent, 4))
	roll_btn.add_theme_stylebox_override("pressed", Widgets.flat_style(palette.accent, Color(0, 0, 0, 0), 4))
	roll_btn.add_theme_stylebox_override("disabled", Widgets.flat_style(palette.surface, Color(palette.muted, 0.25), 4))
	roll_btn.add_theme_color_override("icon_normal_color", palette.text)
	roll_btn.add_theme_color_override("icon_hover_color", palette.text)
	roll_btn.add_theme_color_override("icon_pressed_color", palette.text)
	roll_btn.add_theme_color_override("icon_disabled_color", Color(palette.muted, 0.35))
	roll_btn.disabled = is_broad or is_perm_for_roll or not ctx.can_roll() or not usable
	roll_btn.pressed.connect(func(): _roll_skill(item))
	grid.add_child(roll_btn)


func _group_fx_powers(rows: Array) -> Array:
	var rules: AlternityRules = ctx.rules
	var broad_map: Dictionary = {}
	var standalone: Array = []

	for item in rows:
		var is_broad: bool = String(item.get("type", "")) == "broad"
		var item_name: String = String(item.get("name", ""))
		if is_broad:
			if not broad_map.has(item_name):
				broad_map[item_name] = {"broad": item, "specialties": []}
			else:
				broad_map[item_name]["broad"] = item
		else:
			var broad_name: String = String(item.get("broad_skill", ""))
			if not broad_name.is_empty():
				if not broad_map.has(broad_name):
					var broad_def: Dictionary = rules.fx.get_broad_skill(broad_name)
					if not broad_def.is_empty():
						var broad_copy := broad_def.duplicate(true)
						broad_copy["type"] = "broad"
						broad_copy["rank"] = 1
						broad_map[broad_name] = {"broad": broad_copy, "specialties": []}
					else:
						standalone.append(item)
						continue
				broad_map[broad_name]["specialties"].append(item)
			else:
				standalone.append(item)

	var sorted_groups: Array = broad_map.values()
	sorted_groups.sort_custom(func(a, b):
		var broad_a: Dictionary = a.get("broad", {})
		var broad_b: Dictionary = b.get("broad", {})
		return String(broad_a.get("name", "")) < String(broad_b.get("name", ""))
	)
	var result: Array = []
	for group in sorted_groups:
		result.append(group)
	if not standalone.is_empty():
		result.append({"broad": {}, "specialties": standalone})
	return result


func _roll_skill(skill: Dictionary) -> void:
	if ctx == null or ctx.checks == null or ctx.doc == null:
		return
	await ctx.checks.run(ctx.doc, skill)


func _open_detail(skill: Dictionary) -> void:
	if ctx == null or ctx.router == null:
		return
	var rules: AlternityRules = ctx.rules
	var raw := ctx.doc.raw() if ctx.doc != null else {}
	var detail: Dictionary
	var title_text: String
	var is_core_skill: bool = skill.has("broad_id") or String(skill.get("type", "")) == "broad"
	var is_fx: bool = rules != null and rules.is_fx_skill(skill)
	# A rollable FX skill is a specialty (not a broad-school banner) that is not
	# permanently active. Broad FX rows open for reference only.
	var is_fx_broad: bool = is_fx and String(skill.get("type", "")) == "broad"
	var is_fx_perm: bool = is_fx and not is_fx_broad and rules.fx.is_fx_skill_permanent(raw, String(skill.get("name", "")))
	var is_rollable_skill: bool = is_core_skill or (is_fx and not is_fx_broad and not is_fx_perm)

	if rules != null and is_core_skill:
		detail = rules.skill_detail(skill, raw)
		title_text = String(detail.get("name", rules.skill_label(skill)))
	else:
		detail = skill
		title_text = String(skill.get("name", rules.skill_label(skill) if rules != null else ""))

	var answer = await ctx.router.push(DETAIL_ROUTE, {
		"palette": ctx.palette,
		"data": detail,
		"title": title_text,
		"skill": skill,
		"can_roll": ctx.can_roll() and is_rollable_skill,
	})
	if not is_instance_valid(self):
		return
	if typeof(answer) == TYPE_DICTIONARY and bool(answer.get("roll", false)):
		await _roll_skill(answer.get("skill", skill))


## One always-active power, named and described.
##
## permanent_fx_effects_summary returns {name, description} dictionaries, not
## strings. Both this tab and the FX tab passed each entry straight to String(),
## which has no Dictionary constructor -- so the section crashed for any hero who
## actually had a permanent power, and only for those heroes.
func _build_permanent_effect(box: Container, effect: Variant) -> void:
	var palette := ctx.palette
	if typeof(effect) != TYPE_DICTIONARY:
		Widgets.muted_text(box, str(effect), palette, Widgets.FONT_CAPTION)
		return
	var entry: Dictionary = effect
	var effect_name := String(entry.get("name", "")).strip_edges()
	var description := String(entry.get("description", "")).strip_edges()
	if effect_name.is_empty() and description.is_empty():
		return
	Widgets.muted_text(
		box,
		"%s: %s" % [effect_name, description] if not description.is_empty() else effect_name,
		palette, Widgets.FONT_CAPTION
	)


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

	var is_mutant := rules.mutations.mutations_enabled(raw)
	var advantages: Array = rules.mutations.selected_mutation_advantages(raw)
	var drawbacks: Array = rules.mutations.selected_mutation_drawbacks(raw)
	if not is_mutant and advantages.is_empty() and drawbacks.is_empty():
		return

	var box := Widgets.section(container, "Mutations", palette)

	# 1. Mutant Overview (Origin, Uniqueness & Point budgets)
	if is_mutant:
		var mut_data: Dictionary = raw.get("mutations", {})
		var origin_id := String(mut_data.get("origin", ""))
		var uniqueness_id := String(mut_data.get("uniqueness", ""))
		var origin_data: Dictionary = rules.mutations.get_mutation_origin_by_id(origin_id)
		var uniqueness_data: Dictionary = rules.mutations.get_mutation_uniqueness_by_id(origin_id, uniqueness_id)

		var origin_name := String(origin_data.get("name", origin_id)).strip_edges()
		var uniq_name := String(uniqueness_data.get("name", uniqueness_id)).strip_edges()
		if not origin_name.is_empty() or not uniq_name.is_empty():
			var origin_desc: String
			if not origin_name.is_empty() and not uniq_name.is_empty():
				origin_desc = "%s — %s" % [origin_name, uniq_name]
			elif not origin_name.is_empty():
				origin_desc = origin_name
			else:
				origin_desc = uniq_name
			Widgets.metric(box, "Origin", origin_desc, palette)

		var adv_used: int = rules.mutations.mutation_advantage_points_used(raw)
		var adv_total: int = AlternityNum.as_int(mut_data.get("advantage_points", 0))
		var adv_dist: String = rules.mutations.mutation_distribution_label(raw, "advantage")
		var adv_text := "%d / %d points" % [adv_used, adv_total]
		if not adv_dist.is_empty():
			adv_text += " (%s)" % adv_dist
		Widgets.metric(box, "Advantage points", adv_text, palette)

		var draw_used: int = rules.mutations.mutation_drawback_points_used(raw)
		var draw_total: int = AlternityNum.as_int(mut_data.get("drawback_points", 0))
		var draw_dist: String = rules.mutations.mutation_distribution_label(raw, "drawback")
		var draw_text := "%d / %d points" % [draw_used, draw_total]
		if not draw_dist.is_empty():
			draw_text += " (%s)" % draw_dist
		Widgets.metric(box, "Drawback points", draw_text, palette)

		Widgets.separator(box, palette)

	# 2. Advantages
	Widgets.subheading(box, "Advantages", palette)
	Widgets.muted_text(
		box,
		"Mutation powers requiring a check use the listed skill, or an untrained "
		+ "check at 1/2 the related ability score with a +d4 situation die.",
		palette, Widgets.FONT_CAPTION
	)
	if advantages.is_empty():
		Widgets.muted_text(box, "None selected.", palette, Widgets.FONT_DETAIL)
	else:
		for mutation in advantages:
			_build_mutation_entry(box, mutation, true)

	# 3. Drawbacks
	Widgets.separator(box, palette)
	Widgets.subheading(box, "Drawbacks", palette)
	Widgets.muted_text(
		box,
		"Drawbacks reducing ability scores or causing weakness affect the "
		+ "related ability from Table P51 (STR→INT, DEX→STR, CON→DEX, INT→PER, WIL→CON, PER→WIL).",
		palette, Widgets.FONT_CAPTION
	)
	if drawbacks.is_empty():
		Widgets.muted_text(box, "None selected.", palette, Widgets.FONT_DETAIL)
	else:
		for drawback in drawbacks:
			_build_mutation_entry(box, drawback, false)


func _build_mutation_entry(box: Container, entry: Dictionary, is_advantage: bool) -> void:
	var palette := ctx.palette

	var item_box := VBoxContainer.new()
	item_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_box.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	box.add_child(item_box)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", Widgets.GAP_ROW)
	item_box.add_child(header)

	var label_text := String(entry.get("name", "Unknown"))
	if bool(entry.get("gm_given", false)):
		label_text += " (GM)"

	var name_label := Label.new()
	name_label.text = label_text
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(1, 0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", palette.accent if is_advantage else palette.text)
	name_label.add_theme_font_size_override("font_size", Widgets.FONT_BODY)
	header.add_child(name_label)

	var right_cell := HBoxContainer.new()
	right_cell.size_flags_horizontal = Control.SIZE_SHRINK_END
	right_cell.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	header.add_child(right_cell)

	var info_btn := Button.new()
	info_btn.icon = preload("res://assets/question-square.svg")
	info_btn.expand_icon = true
	info_btn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	info_btn.tooltip_text = "View details for %s" % label_text
	info_btn.custom_minimum_size = Vector2(22, 22)
	info_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	info_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	info_btn.add_theme_color_override("icon_normal_color", palette.text)
	info_btn.add_theme_color_override("icon_hover_color", palette.accent)
	info_btn.add_theme_color_override("icon_pressed_color", palette.accent)
	info_btn.add_theme_stylebox_override("normal", Widgets.flat_style(palette.surface_soft, Color(0, 0, 0, 0), 3))
	info_btn.add_theme_stylebox_override("hover", Widgets.flat_style(palette.surface_soft.lightened(0.1), palette.accent, 3))
	info_btn.add_theme_stylebox_override("pressed", Widgets.flat_style(palette.accent, Color(0, 0, 0, 0), 3))
	info_btn.pressed.connect(func(): _open_mutation_detail(entry))
	right_cell.add_child(info_btn)

	var tier := String(entry.get("tier", "")).capitalize()
	var points := AlternityNum.as_int(entry.get("points", 0))
	var related := String(entry.get("related_ability", "")).strip_edges()

	var meta_parts: Array = []
	if not tier.is_empty():
		meta_parts.append(tier)
	if points > 0:
		meta_parts.append("%d %s" % [points, "pt" if points == 1 else "pts"])
	if not related.is_empty():
		meta_parts.append(related)

	var meta_label := Label.new()
	meta_label.text = " • ".join(meta_parts)
	meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	meta_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	meta_label.add_theme_color_override("font_color", palette.muted)
	meta_label.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	right_cell.add_child(meta_label)

	var description := String(entry.get("description", entry.get("summary", ""))).strip_edges()
	if not description.is_empty():
		Widgets.muted_text(item_box, description, palette, Widgets.FONT_CAPTION)


func _open_mutation_detail(mutation: Dictionary) -> void:
	if ctx == null or ctx.router == null:
		return
	var name_str := String(mutation.get("name", "Mutation"))
	var tier := String(mutation.get("tier", "")).capitalize()
	var points := AlternityNum.as_int(mutation.get("points", 0))
	var related := String(mutation.get("related_ability", "")).strip_edges()
	var roll_num := AlternityNum.as_int(mutation.get("table_roll", 0))

	var meta_parts: Array = []
	if not tier.is_empty():
		meta_parts.append("Tier: %s" % tier)
	if points > 0:
		meta_parts.append("%d %s" % [points, "point" if points == 1 else "points"])
	if not related.is_empty():
		meta_parts.append("Related Ability: %s" % related)
	if roll_num > 0:
		meta_parts.append("Table Roll: #%d" % roll_num)

	var ref_str := String(mutation.get("reference", "")).strip_edges()
	var detail_data := {
		"name": name_str,
		"meta": " • ".join(meta_parts),
		"summary": String(mutation.get("summary", mutation.get("description", ""))),
		"sources": [ref_str] if not ref_str.is_empty() else [],
	}

	await ctx.router.push(DETAIL_ROUTE, {
		"palette": ctx.palette,
		"data": detail_data,
		"title": name_str,
		"can_roll": false,
	})


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
