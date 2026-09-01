extends SheetTab
##
## Achievement points, level, and purchased achievement benefits.
##
## Reuses the multi-select catalog route from Perks/Flaws. The only wrinkle is
## Remove Flaw, which needs a target: rather than opening a second picker after
## the first, it is flattened into one catalog entry per removable flaw, the
## same way a perk with several cost tiers becomes one entry per tier. The list
## stays flat and one confirm applies everything.
##

const CATALOG_ROUTE := preload("res://scenes/ui/routes/catalog_route.tscn")

## Packs achievement id, target id and target value into one catalog entry id.
const FIELD_SEPARATOR := "|"


func watched_sections() -> Array:
	# Achievements buy ability scores, durability and perks, so a purchase can
	# move almost anything; and Remove Flaw depends on the perks/flaws section.
	return CharacterDoc.ALL


func build(container: Container) -> void:
	_build_progress(container)
	_build_purchased(container)


func _build_progress(container: Container) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var raw := doc.raw()

	var box := Widgets.section(container, "Achievement Progress", palette)

	var points := AlternityNum.as_int(raw.get("achievement_points", 0))
	var level: int = rules.achievements.achievement_level_for_points(points)

	Widgets.metric(box, "Achievement level", str(level), palette)
	Widgets.metric(box, "Points earned", str(points), palette)
	Widgets.metric(box, "Points spent", str(rules.achievements.achievement_points_spent(raw)), palette)
	Widgets.metric(box, "Points available", str(rules.achievements.achievement_points_available(raw)), palette)

	var to_next: int = rules.achievements.achievement_points_to_next_level(raw)
	if to_next > 0:
		Widgets.metric(box, "To next level", "%d points" % to_next, palette)

	var skill_bonus: int = rules.achievements.achievement_skill_bonus(raw)
	if skill_bonus != 0:
		Widgets.metric(box, "Skill points from level", "+%d" % skill_bonus, palette)

	Widgets.separator(box, palette)

	# The GM awards points between adventures, so this is an input rather than a
	# derived value.
	var stepper := NumberStepper.new()
	box.add_child(stepper)
	stepper.setup(palette, "Achievement points earned", points, 0, 999)
	stepper.value_changed.connect(func(value: int):
		doc.apply(CharacterDoc.ALL, func(c): rules.achievements.set_achievement_points(c, value))
		save_requested.emit())


func _build_purchased(container: Container) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette

	var box := Widgets.section(container, "Purchased Benefits", palette)

	var purchased: Array = rules.achievements.selected_achievements(doc.raw())
	if purchased.is_empty():
		Widgets.muted_text(box, "Nothing purchased yet.", palette)

	for entry in purchased:
		_build_purchased_row(box, entry)

	var add := Button.new()
	add.text = "Add Achievement Benefit"
	add.custom_minimum_size = Vector2(0, 44)
	add.pressed.connect(_open_catalog)
	box.add_child(add)


func _build_purchased_row(parent: Container, entry: Dictionary) -> void:
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var line_id := String(entry.get("line_id", ""))
	var achievement: Dictionary = rules.get_achievement_by_id(String(entry.get("achievement_id", "")))

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", Widgets.GAP_ROW)
	parent.add_child(row)

	var label := Label.new()
	label.text = String(rules.achievements.achievement_display_name(achievement, entry))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(1, 0)
	label.add_theme_color_override("font_color", palette.text)
	label.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	row.add_child(label)

	var cost := Label.new()
	cost.text = "%d SP" % AlternityNum.as_int(entry.get("cost", 0))
	cost.add_theme_color_override("font_color", palette.accent)
	cost.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	row.add_child(cost)

	var remove := Button.new()
	remove.text = "Remove"
	remove.custom_minimum_size = Vector2(84, 36)
	remove.pressed.connect(func():
		ctx.doc.apply(CharacterDoc.ALL, func(c):
			rules.achievements.remove_achievement_purchase(c, line_id))
		save_requested.emit())
	row.add_child(remove)


func _open_catalog() -> void:
	if ctx.router == null:
		return
	var chosen = await ctx.router.push(CATALOG_ROUTE, {
		"palette": ctx.palette,
		"title": "Achievement Benefits",
		"entries": _catalog_entries(),
		"budget_fn": _budget_text,
	})

	if not is_instance_valid(self) or ctx == null or ctx.doc == null:
		return
	if typeof(chosen) != TYPE_ARRAY or chosen.is_empty():
		return

	var rules: AlternityRules = ctx.rules
	ctx.doc.apply(CharacterDoc.ALL, func(c):
		for entry_id in chosen:
			var parts := String(entry_id).split(FIELD_SEPARATOR)
			var achievement_id := parts[0]
			var target_id := parts[1] if parts.size() > 1 else ""
			var target_value := AlternityNum.as_int(parts[2] if parts.size() > 2 else 0)
			rules.achievements.add_achievement_purchase(c, achievement_id, target_id, target_value))
	save_requested.emit()


## One entry per purchasable benefit, with Remove Flaw expanded per flaw.
##
## Entries that cannot be bought yet are kept and disabled with the reason, so
## the level or point gate is visible rather than the benefit simply missing.
func _catalog_entries() -> Array:
	var rules: AlternityRules = ctx.rules
	var raw := ctx.doc.raw()
	var entries: Array = []

	for achievement in rules.achievement_catalog:
		if typeof(achievement) != TYPE_DICTIONARY:
			continue
		if not rules.is_entry_available(raw, achievement):
			continue

		var achievement_id := String(achievement.get("id", ""))
		if achievement_id == "remove_flaw":
			entries.append_array(_remove_flaw_entries(achievement))
			continue

		var verdict: Dictionary = rules.achievements.can_purchase_achievement(raw, achievement)
		var cost: int = rules.achievements.achievement_purchase_cost(raw, achievement)
		entries.append({
			"id": achievement_id,
			"name": String(achievement.get("name", achievement_id)),
			"summary": String(achievement.get("summary", "")),
			"meta": "%d SP" % cost,
			"disabled": not bool(verdict.get("allowed", false)),
			"reason": String(verdict.get("reason", "")),
		})

	return entries


## Remove Flaw needs a target, so it becomes one entry per selected flaw rather
## than a second picker opened after the first.
func _remove_flaw_entries(achievement: Dictionary) -> Array:
	var rules: AlternityRules = ctx.rules
	var raw := ctx.doc.raw()
	var achievement_id := String(achievement.get("id", ""))

	var flaws: Array = rules.selected_flaws(raw)
	if flaws.is_empty():
		return [{
			"id": "%s%s%s" % [achievement_id, FIELD_SEPARATOR, "none"],
			"name": String(achievement.get("name", "Remove Flaw")),
			"summary": String(achievement.get("summary", "")),
			"meta": "-",
			"disabled": true,
			"reason": "No selected flaw is available to remove.",
		}]

	var out: Array = []
	for flaw in flaws:
		var flaw_id := String(flaw.get("id", ""))
		var bonus := AlternityNum.as_int(flaw.get("bonus", flaw.get("value", 0)))
		var verdict: Dictionary = rules.achievements.can_purchase_achievement(raw, achievement, flaw_id, bonus)
		out.append({
			"id": "%s%s%s%s%d" % [achievement_id, FIELD_SEPARATOR, flaw_id, FIELD_SEPARATOR, bonus],
			"name": "Remove %s" % String(flaw.get("name", flaw_id)),
			"summary": String(achievement.get("summary", "")),
			# Removing a flaw costs double the points it granted.
			"meta": "%d SP" % rules.achievements.achievement_purchase_cost(raw, achievement, bonus),
			"disabled": not bool(verdict.get("allowed", false)),
			"reason": String(verdict.get("reason", "")),
		})
	return out


func _budget_text(selected_ids: Array) -> String:
	var rules: AlternityRules = ctx.rules
	var raw := ctx.doc.raw()
	var available: int = rules.achievements.achievement_points_available(raw)

	var pending := 0
	for entry_id in selected_ids:
		var parts := String(entry_id).split(FIELD_SEPARATOR)
		var achievement: Dictionary = rules.get_achievement_by_id(parts[0])
		var target_value := AlternityNum.as_int(parts[2] if parts.size() > 2 else 0)
		pending += rules.achievements.achievement_purchase_cost(raw, achievement, target_value)

	var remaining := available - pending
	return "Available %d SP  -  %d selected  =  %d SP remaining" % [available, pending, remaining]
