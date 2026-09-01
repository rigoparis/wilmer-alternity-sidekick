extends SheetTab
##
## Carried gear, and a catalog to add from.
##
## The largest catalog in the app: 259 items with filters on text, Progress
## Level, category and class. The filters live on the catalog route rather than
## on the tab, which is where the old UI kept them -- six member variables
## (equipment_filter_text, _pl_min, _pl_max, _category, _class, _sources) that
## belonged to one screen but sat in the shell alongside every other tab.
##
## Cyber gear is ordinary equipment: it lives here and modifies attack or
## defense, unlike cybertech, which is surgically installed and has its own tab.
##

const CATALOG_ROUTE := preload("res://scenes/ui/routes/catalog_route.tscn")


func watched_sections() -> Array:
	# Abilities are watched because carrying capacity and Strength damage derive
	# from them, and skills because armour operation reduces its penalties.
	return [CharacterDoc.EQUIPMENT, CharacterDoc.ABILITIES, CharacterDoc.SKILLS]


func build(container: Container) -> void:
	_build_summary(container)
	_build_carried(container)


func _build_summary(container: Container) -> void:
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var summary: Dictionary = rules.equipment.equipment_summary(ctx.doc.raw())

	var box := Widgets.section(container, "Load", palette)
	Widgets.metric(box, "Total mass", "%s kg" % Widgets.format_number(AlternityNum.as_float(summary.get("total_mass", 0.0))), palette)
	Widgets.metric(box, "Total cost", "$%s" % Widgets.format_number(AlternityNum.as_float(summary.get("total_cost", 0.0))), palette)

	var penalty: int = rules.equipment.equipped_armor_action_penalty(ctx.doc.raw())
	if penalty != 0:
		Widgets.metric(box, "Armour action penalty", "%+d steps" % penalty, palette)


func _build_carried(container: Container) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette

	var box := Widgets.section(container, "Carried", palette)

	var carried: Array = rules.equipment.carried_equipment(doc.raw())
	if carried.is_empty():
		Widgets.muted_text(box, "Nothing carried yet.", palette)

	for row in carried:
		_build_carried_row(box, row)

	var add := Button.new()
	add.text = "Add Equipment"
	add.custom_minimum_size = Vector2(0, 44)
	add.pressed.connect(_open_catalog)
	box.add_child(add)


func _build_carried_row(parent: Container, row: Dictionary) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette

	var line_id := String(row.get("line_id", ""))
	var item: Dictionary = row.get("item", {})
	var quantity := AlternityNum.as_int(row.get("quantity", 1), 1)
	var equipped := bool(row.get("equipped", false))

	var block := VBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	parent.add_child(block)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", Widgets.GAP_ROW)
	block.add_child(header)

	var name_label := Label.new()
	name_label.text = String(item.get("name", "Unknown item"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(1, 0)
	name_label.add_theme_color_override("font_color", palette.text)
	name_label.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	header.add_child(name_label)

	var remove := Button.new()
	remove.text = "Remove"
	remove.custom_minimum_size = Vector2(84, 36)
	remove.pressed.connect(func():
		doc.apply([CharacterDoc.EQUIPMENT], func(c):
			rules.equipment.remove_carried_equipment(c, line_id))
		save_requested.emit())
	header.add_child(remove)

	Widgets.muted_text(block, _describe(item), palette, Widgets.FONT_CAPTION)

	var controls := HBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", Widgets.GAP_ROW)
	block.add_child(controls)

	var stepper := NumberStepper.new()
	controls.add_child(stepper)
	stepper.setup(palette, "Qty", quantity, 1, 999)
	stepper.value_changed.connect(func(value: int):
		doc.apply([CharacterDoc.EQUIPMENT], func(c):
			rules.equipment.update_carried_equipment(
				c, line_id, value, equipped,
				String(row.get("slot", "")), String(row.get("notes", ""))
			))
		save_requested.emit())

	var worn := Widgets.toggle_row(controls, "Equipped", equipped, palette)
	worn.toggled.connect(func(pressed: bool):
		doc.apply([CharacterDoc.EQUIPMENT], func(c):
			rules.equipment.update_carried_equipment(
				c, line_id, quantity, pressed,
				String(row.get("slot", "")), String(row.get("notes", ""))
			))
		save_requested.emit())

	Widgets.separator(block, palette)


func _describe(item: Dictionary) -> String:
	var parts: Array = []
	var pl := AlternityNum.as_int(item.get("pl", -1), -1)
	if pl >= 0:
		parts.append("PL %d" % pl)
	var category := String(item.get("category", ""))
	if not category.is_empty():
		parts.append(category)
	var mass := AlternityNum.as_float(item.get("mass", 0.0))
	if mass > 0.0:
		parts.append("%s kg" % Widgets.format_number(mass))
	var cost := AlternityNum.as_float(item.get("cost", 0.0))
	if cost > 0.0:
		parts.append("$%s" % Widgets.format_number(cost))

	var combat = item.get("combat", null)
	if typeof(combat) == TYPE_DICTIONARY:
		var damage := String(combat.get("damage", "")).strip_edges()
		if not damage.is_empty():
			parts.append(damage)

	return "  |  ".join(parts)


func _open_catalog() -> void:
	if ctx.router == null:
		return
	var chosen = await ctx.router.push(CATALOG_ROUTE, {
		"palette": ctx.palette,
		"title": "Equipment Catalog",
		"entries": _catalog_entries(),
		"budget_fn": _budget_text,
	})

	if not is_instance_valid(self) or ctx == null or ctx.doc == null:
		return
	if typeof(chosen) != TYPE_ARRAY or chosen.is_empty():
		return

	var rules: AlternityRules = ctx.rules
	ctx.doc.apply([CharacterDoc.EQUIPMENT], func(c):
		for item_id in chosen:
			rules.equipment.add_equipment_to_character(c, String(item_id), 1))
	save_requested.emit()


## The whole catalog, filtered by setting. Text search happens in the route.
##
## Items are not marked "taken": unlike a perk, the same item can legitimately
## be carried more than once, so adding a second is a normal thing to do.
func _catalog_entries() -> Array:
	var rules: AlternityRules = ctx.rules
	var raw := ctx.doc.raw()
	var entries: Array = []

	for item in rules.equipment_catalog:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if not rules.is_entry_available(raw, item):
			continue
		entries.append({
			"id": String(item.get("id", "")),
			"name": String(item.get("name", "?")),
			"summary": _describe(item),
			"meta": "$%s" % Widgets.format_number(AlternityNum.as_float(item.get("cost", 0.0))),
		})
	return entries


func _budget_text(selected_ids: Array) -> String:
	var rules: AlternityRules = ctx.rules
	var raw := ctx.doc.raw()
	var summary: Dictionary = rules.equipment.equipment_summary(raw)

	var pending_cost := 0.0
	var pending_mass := 0.0
	for item_id in selected_ids:
		var item: Dictionary = rules.get_equipment_item_by_id(String(item_id))
		pending_cost += AlternityNum.as_float(item.get("cost", 0.0))
		pending_mass += AlternityNum.as_float(item.get("mass", 0.0))

	var carried_mass := AlternityNum.as_float(summary.get("total_mass", 0.0))
	return "Selected $%s / %s kg   -   carried %s kg" % [
		Widgets.format_number(pending_cost),
		Widgets.format_number(pending_mass),
		Widgets.format_number(carried_mass),
	]
