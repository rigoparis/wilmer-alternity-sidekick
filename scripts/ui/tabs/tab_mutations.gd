extends SheetTab
##
## Mutation origin, point budget, distribution, and the chosen mutations.
##
## Only applies to Mutant characters, which is what is_available_for expresses.
## The old UI hardcoded that same rule inside _tab_visible() in the shell, so
## the shell had to know a mutation rule to decide whether to draw a button.
##
## Catalog entries are filtered through rules.is_entry_available, so Dark Matter
## mutations only appear while that setting is selected.
##

const CATALOG_ROUTE := preload("res://scenes/ui/routes/catalog_route.tscn")

## Advantages are bought with advantage points; drawbacks fund them.
const KINDS := ["advantage", "drawback"]


func watched_sections() -> Array:
	# Mutations move ability scores and durability, and the species and setting
	# both decide whether this tab applies at all.
	return CharacterDoc.ALL


## Mutations are a Mutant-species option. Replaces the special case that was
## hardcoded into the shell's _tab_visible().
##
## Uses the passed context, not the member: this runs on a probe instance before
## bind(), so ctx is still null.
func is_available_for(context: SheetContext) -> bool:
	if context == null or context.doc == null or context.rules == null:
		return false
	return context.rules.mutations.mutations_enabled(context.doc.raw())


func build(container: Container) -> void:
	_build_origin(container)
	_build_points(container)
	for kind in KINDS:
		_build_selected(container, kind)


func _build_origin(container: Container) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var raw := doc.raw()
	var data: Dictionary = raw.get("mutations", {})

	var box := Widgets.section(container, "Origin", palette)

	var origins: Array = rules.mutations.mutation_origin_options()
	_string_picker(
		box, "Origin", origins, String(data.get("origin", "")),
		func(value: String):
			doc.apply(CharacterDoc.ALL, func(c): rules.mutations.set_mutation_origin(c, value))
			save_requested.emit()
	)

	var uniqueness: Array = rules.mutations.mutation_uniqueness_options(String(data.get("origin", "")))
	if not uniqueness.is_empty():
		_string_picker(
			box, "Uniqueness", uniqueness, String(data.get("uniqueness", "")),
			func(value: String):
				doc.apply(CharacterDoc.ALL, func(c): rules.mutations.set_mutation_uniqueness(c, value))
				save_requested.emit()
		)

	# Rolling uses the seeded RNG in the rules layer; the button is just an entry
	# point to it.
	var roll := Button.new()
	roll.text = "Roll origin and points"
	roll.custom_minimum_size = Vector2(0, 44)
	roll.pressed.connect(func():
		doc.apply(CharacterDoc.ALL, func(c):
			rules.mutations.roll_mutation_origin_and_points(c))
		save_requested.emit())
	box.add_child(roll)


func _build_points(container: Container) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var raw := doc.raw()
	var data: Dictionary = raw.get("mutations", {})

	var box := Widgets.section(container, "Points", palette)

	var advantage_points := AlternityNum.as_int(data.get("advantage_points", 0))
	var drawback_points := AlternityNum.as_int(data.get("drawback_points", 0))

	var advantage_stepper := NumberStepper.new()
	box.add_child(advantage_stepper)
	advantage_stepper.setup(palette, "Advantage points", advantage_points, 0, 99)
	advantage_stepper.value_changed.connect(func(value: int):
		doc.apply(CharacterDoc.ALL, func(c):
			rules.mutations.set_mutation_points(c, value, drawback_points))
		save_requested.emit())

	var drawback_stepper := NumberStepper.new()
	box.add_child(drawback_stepper)
	drawback_stepper.setup(palette, "Drawback points", drawback_points, 0, 99)
	drawback_stepper.value_changed.connect(func(value: int):
		doc.apply(CharacterDoc.ALL, func(c):
			rules.mutations.set_mutation_points(c, advantage_points, value))
		save_requested.emit())

	Widgets.separator(box, palette)

	for kind in KINDS:
		_build_distribution(box, kind)


## How the point budget is split across tiers, e.g. "1 Good + 2 Ordinary".
func _build_distribution(parent: Container, kind: String) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var data: Dictionary = doc.raw().get("mutations", {})
	var points := AlternityNum.as_int(
		data.get("drawback_points" if kind == "drawback" else "advantage_points", 0)
	)

	var options: Array = rules.mutations.mutation_distribution_options(kind, points)
	if options.is_empty():
		return

	var current: String = rules.mutations.mutation_distribution_id(doc.raw(), kind)
	var entries: Array = []
	for option in options:
		entries.append({
			"id": String(option.get("id", option.get("label", ""))),
			"name": String(option.get("label", option.get("id", ""))),
		})

	_string_picker(
		parent, "%s distribution" % kind.capitalize(), entries, current,
		func(value: String):
			doc.apply(CharacterDoc.ALL, func(c):
				rules.mutations.set_mutation_distribution(c, kind, value))
			save_requested.emit()
	)

	var used := AlternityNum.as_int(
		rules.mutations.mutation_drawback_points_used(doc.raw()) if kind == "drawback"
		else rules.mutations.mutation_advantage_points_used(doc.raw())
	)
	Widgets.metric(parent, "%s points used" % kind.capitalize(), "%d / %d" % [used, points], palette)


func _build_selected(container: Container, kind: String) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var is_advantage := kind == "advantage"

	var box := Widgets.section(container, "Advantages" if is_advantage else "Drawbacks", palette)

	var selected: Array = (
		rules.mutations.selected_mutation_advantages(doc.raw()) if is_advantage
		else rules.mutations.selected_mutation_drawbacks(doc.raw())
	)
	if selected.is_empty():
		Widgets.muted_text(box, "None chosen yet.", palette)

	for mutation in selected:
		_build_selected_row(box, mutation, kind)

	var add := Button.new()
	add.text = "Add %s" % ("Advantage" if is_advantage else "Drawback")
	add.custom_minimum_size = Vector2(0, 44)
	add.pressed.connect(_open_catalog.bind(kind))
	box.add_child(add)


func _build_selected_row(parent: Container, mutation: Dictionary, kind: String) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var mutation_id := String(mutation.get("id", ""))

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", Widgets.GAP_ROW)
	parent.add_child(row)

	var label := Label.new()
	label.text = String(mutation.get("name", mutation_id))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(1, 0)
	label.add_theme_color_override("font_color", palette.text)
	label.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	row.add_child(label)

	var tier := String(mutation.get("tier", ""))
	if not tier.is_empty():
		var tier_label := Label.new()
		tier_label.text = tier.capitalize()
		tier_label.add_theme_color_override("font_color", palette.accent)
		tier_label.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
		row.add_child(tier_label)

	var remove := Button.new()
	remove.text = "Remove"
	remove.custom_minimum_size = Vector2(84, 36)
	remove.pressed.connect(func():
		doc.apply(CharacterDoc.ALL, func(c):
			if kind == "advantage":
				rules.mutations.remove_mutation_advantage(c, mutation_id)
			else:
				rules.mutations.remove_mutation_drawback(c, mutation_id))
		save_requested.emit())
	row.add_child(remove)


func _open_catalog(kind: String) -> void:
	if ctx.router == null:
		return
	var is_advantage := kind == "advantage"
	var chosen = await ctx.router.push(CATALOG_ROUTE, {
		"palette": ctx.palette,
		"title": "Mutation Advantages" if is_advantage else "Mutation Drawbacks",
		"entries": _catalog_entries(kind),
		"budget_fn": _budget_text.bind(kind),
	})

	if not is_instance_valid(self) or ctx == null or ctx.doc == null:
		return
	if typeof(chosen) != TYPE_ARRAY or chosen.is_empty():
		return

	var rules: AlternityRules = ctx.rules
	ctx.doc.apply(CharacterDoc.ALL, func(c):
		for mutation_id in chosen:
			if is_advantage:
				rules.mutations.add_mutation_advantage(c, String(mutation_id))
			else:
				rules.mutations.add_mutation_drawback(c, String(mutation_id)))
	save_requested.emit()


func _catalog_entries(kind: String) -> Array:
	var rules: AlternityRules = ctx.rules
	var raw := ctx.doc.raw()
	var is_advantage := kind == "advantage"
	var source: Array = rules.mutation_advantages if is_advantage else rules.mutation_drawbacks

	var entries: Array = []
	for mutation in source:
		if typeof(mutation) != TYPE_DICTIONARY:
			continue
		# Dark Matter mutations only appear while that setting is selected.
		if not rules.is_entry_available(raw, mutation):
			continue

		var mutation_id := String(mutation.get("id", ""))
		var verdict: Dictionary = (
			rules.mutations.can_add_mutation_advantage(raw, mutation) if is_advantage
			else rules.mutations.can_add_mutation_drawback(raw, mutation)
		)
		var allowed := bool(verdict.get("allowed", false))
		var reason := String(verdict.get("reason", ""))

		entries.append({
			"id": mutation_id,
			"name": String(mutation.get("name", mutation_id)),
			"summary": String(mutation.get("summary", mutation.get("description", ""))),
			"meta": String(mutation.get("tier", "")).capitalize(),
			# "Already selected" is a reason, not a disabled state to hide.
			"taken": reason.to_lower().contains("already"),
			"disabled": not allowed,
			"reason": reason,
		})
	return entries


func _budget_text(_selected_ids: Array, kind: String) -> String:
	var rules: AlternityRules = ctx.rules
	var raw := ctx.doc.raw()
	var is_advantage := kind == "advantage"

	var remaining := AlternityNum.as_int(
		rules.mutations.mutation_advantage_points_remaining(raw) if is_advantage
		else rules.mutations.mutation_drawback_points_remaining(raw)
	)
	return "%d %s point(s) remaining" % [remaining, kind]


## Dropdown over entries carrying a string "id" and a "name" or "label".
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
		picker.add_item(String(entry.get("name", entry.get("label", id))), i)
		if id == current_id:
			selected_index = i
	if selected_index >= 0:
		picker.select(selected_index)

	picker.item_selected.connect(func(index: int): changed.call(String(ids[index])))
