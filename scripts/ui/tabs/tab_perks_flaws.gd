extends SheetTab
##
## Perks and flaws: what is taken, and a catalog to take more from.
##
## Pulled into the vertical slice specifically to exercise the multi-select
## catalog route. Cybertech has no overlay and the character list only opens a
## dialog, so without this the architecture gate would never test the riskiest
## new interaction: picking several things with a live budget, presented
## full-screen on a phone and as a centred panel on a desktop.
##
## Perks with several cost tiers appear as one catalog entry per tier rather
## than opening a second picker, so the flat list stays flat.
##

const CATALOG_ROUTE := preload("res://scenes/ui/routes/catalog_route.tscn")

## Separates the perk id from its chosen cost in a catalog entry id.
const TIER_SEPARATOR := "|"


func watched_sections() -> Array:
	return [CharacterDoc.PERKS_FLAWS, CharacterDoc.SKILLS, CharacterDoc.ACHIEVEMENTS]


func build(container: Container) -> void:
	_build_budget(container)
	_build_list(container, "perk")
	_build_list(container, "flaw")


func _build_budget(container: Container) -> void:
	var rules = ctx.rules
	var palette := ctx.palette
	var raw := ctx.doc.raw()

	var box := Widgets.section(container, "Budget", palette)
	Widgets.metric(box, "Perk points spent", str(rules.perk_points_used(raw)), palette)
	Widgets.metric(box, "Skill points from flaws", "+%d" % rules.flaw_skill_points_bonus(raw), palette)
	# The three-of-each limit applies to chosen perks and flaws; GM-given ones
	# do not count against it, which is why the non_gm_* counts are used here.
	Widgets.metric(box, "Perks chosen", "%d / 3" % rules.non_gm_perk_count(raw), palette)
	Widgets.metric(box, "Flaws chosen", "%d / 3" % rules.non_gm_flaw_count(raw), palette)


func _build_list(container: Container, kind: String) -> void:
	var rules = ctx.rules
	var palette := ctx.palette
	var raw := ctx.doc.raw()
	var is_perk := kind == "perk"

	var heading := "Perks" if is_perk else "Flaws"
	var box := Widgets.section(container, heading, palette)
	Widgets.muted_text(
		box,
		"Perks cost skill points. A starting hero can choose up to three."
			if is_perk else
			"Flaws add skill points. A starting hero can choose up to three.",
		palette,
		Widgets.FONT_CAPTION
	)

	var selected: Array = rules.selected_perks(raw) if is_perk else rules.selected_flaws(raw)
	if selected.is_empty():
		Widgets.muted_text(box, "None taken yet.", palette)

	for entry in selected:
		_build_selected_row(box, entry, kind)

	var add := Button.new()
	add.text = "Add %s" % ("Perk" if is_perk else "Flaw")
	add.custom_minimum_size = Vector2(0, 44)
	add.pressed.connect(_open_catalog.bind(kind))
	box.add_child(add)


func _build_selected_row(parent: Container, entry: Dictionary, kind: String) -> void:
	var palette := ctx.palette
	var is_perk := kind == "perk"
	var definition: Dictionary = entry.get("definition", entry)
	var entry_id := String(definition.get("id", entry.get("id", "")))
	var value := AlternityNum.as_int(entry.get("value", entry.get("cost", 0)))

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", Widgets.GAP_ROW)
	parent.add_child(row)

	var label := Label.new()
	label.text = String(definition.get("name", entry_id))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(1, 0)
	label.add_theme_color_override("font_color", palette.text)
	label.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	row.add_child(label)

	var cost := Label.new()
	cost.text = ("%d SP" % value) if is_perk else ("+%d SP" % value)
	cost.add_theme_color_override("font_color", palette.accent)
	cost.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	row.add_child(cost)

	var remove := Button.new()
	remove.text = "Remove"
	remove.custom_minimum_size = Vector2(84, 36)
	remove.pressed.connect(func(): _remove(kind, entry_id))
	row.add_child(remove)


func _remove(kind: String, entry_id: String) -> void:
	var rules = ctx.rules
	# Selecting with a value of 0 is how the rules layer clears a choice.
	ctx.doc.apply([CharacterDoc.PERKS_FLAWS], func(c):
		if kind == "perk":
			rules.set_perk_selected(c, entry_id, 0)
		else:
			rules.set_flaw_selected(c, entry_id, 0))
	save_requested.emit()


func _open_catalog(kind: String) -> void:
	if ctx.router == null:
		return
	var is_perk := kind == "perk"
	var chosen = await ctx.router.push(CATALOG_ROUTE, {
		"palette": ctx.palette,
		"title": "Choose Perks" if is_perk else "Choose Flaws",
		"entries": _catalog_entries(kind),
		"budget_fn": _budget_text.bind(kind),
	})

	# The tab can be rebuilt or the sheet closed while the catalog is open.
	if not is_instance_valid(self) or ctx == null or ctx.doc == null:
		return
	if typeof(chosen) != TYPE_ARRAY or chosen.is_empty():
		return

	var rules = ctx.rules
	ctx.doc.apply([CharacterDoc.PERKS_FLAWS], func(c):
		for entry_id in chosen:
			var parts := String(entry_id).split(TIER_SEPARATOR)
			var id := parts[0]
			var value := AlternityNum.as_int(parts[1] if parts.size() > 1 else 0)
			if is_perk:
				rules.set_perk_selected(c, id, value)
			else:
				rules.set_flaw_selected(c, id, value))
	save_requested.emit()


## One entry per cost tier, so a perk offering 4 or 8 points appears twice with
## its price rather than needing a second picker to choose between them.
func _catalog_entries(kind: String) -> Array:
	var rules = ctx.rules
	var raw := ctx.doc.raw()
	var is_perk := kind == "perk"
	var source: Dictionary = rules.perks_by_id if is_perk else rules.flaws_by_id

	var ids: Array = source.keys()
	ids.sort()

	var entries: Array = []
	for id in ids:
		var definition: Dictionary = source[id]
		var taken: bool = rules.is_perk_selected(raw, id) if is_perk else rules.is_flaw_selected(raw, id)
		var options: Array = definition.get("cost_options" if is_perk else "bonus_options", [])
		if options.is_empty():
			options = [0]

		for option in options:
			var value := AlternityNum.as_int(option)
			entries.append({
				"id": "%s%s%d" % [id, TIER_SEPARATOR, value],
				"name": String(definition.get("name", id)),
				"summary": String(definition.get("summary", "")),
				"meta": ("%d SP" % value) if is_perk else ("+%d SP" % value),
				"taken": taken,
			})
	return entries


## Live header text while choosing. Shows what the selection would cost on top
## of what is already spent, which is the thing you previously had to close the
## catalog to find out.
func _budget_text(selected_ids: Array, kind: String) -> String:
	var rules = ctx.rules
	var raw := ctx.doc.raw()
	var is_perk := kind == "perk"

	var pending := 0
	for entry_id in selected_ids:
		var parts := String(entry_id).split(TIER_SEPARATOR)
		pending += AlternityNum.as_int(parts[1] if parts.size() > 1 else 0)

	if is_perk:
		var spent: int = rules.perk_points_used(raw)
		return "Spent %d SP  +  %d selected  =  %d SP  (%d / 3 perks)" % [
			spent, pending, spent + pending, rules.non_gm_perk_count(raw) + selected_ids.size(),
		]

	var bonus: int = rules.flaw_skill_points_bonus(raw)
	return "Gained +%d SP  +  %d selected  =  +%d SP  (%d / 3 flaws)" % [
		bonus, pending, bonus + pending, rules.non_gm_flaw_count(raw) + selected_ids.size(),
	]
