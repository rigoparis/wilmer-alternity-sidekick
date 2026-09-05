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

var _req_availability: String = "Common"
var _req_urgency: String = "standard"
var _req_necessity: String = "useful"
var _req_outcome_text: String = ""
var _req_outcome_degree: String = ""


func watched_sections() -> Array:
	# Abilities are watched because carrying capacity and Strength damage derive
	# from them, and skills because armour operation reduces its penalties.
	return [CharacterDoc.EQUIPMENT, CharacterDoc.ABILITIES, CharacterDoc.SKILLS]


func build(container: Container) -> void:
	# The load totals are short and the carried list is long, so the totals take
	# the narrow side rather than an even split.
	var split := columns(container, 0.32)
	_build_summary(split[0])
	_build_carried(split[1])


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

	if rules.is_dark_matter(ctx.doc.raw()):
		_build_requisition(container)


func _build_requisition(container: Container) -> void:
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var doc := ctx.doc
	var raw := doc.raw()

	var box := Widgets.section(container, "Requisition", palette)

	Widgets.muted_text(
		box,
		"Request agency gear (Arms & Equipment Guide p. 5). Rolled against Administration-bureaucracy (or Will feat check if untrained).",
		palette,
		Widgets.FONT_CAPTION
	)

	var options := {
		"availability": _req_availability,
		"urgency": _req_urgency,
		"necessity": _req_necessity,
	}

	# Availability picker
	_requisition_picker(
		box, "Item Availability",
		[
			{"id": "Common", "name": "Common (+0)"},
			{"id": "Controlled", "name": "Controlled (+1)"},
			{"id": "Military", "name": "Military (+2)"},
			{"id": "Restricted", "name": "Restricted (+3)"},
		],
		_req_availability,
		func(val: String):
			_req_availability = val
			_rebuild()
	)

	# Urgency picker
	_requisition_picker(
		box, "Urgency",
		[
			{"id": "standard", "name": "Standard (+0)"},
			{"id": "advance", "name": "Advance notice (-1)"},
			{"id": "short_notice", "name": "Short notice (+1)"},
			{"id": "emergency", "name": "Emergency (+2)"},
		],
		_req_urgency,
		func(val: String):
			_req_urgency = val
			_rebuild()
	)

	# Necessity picker
	_requisition_picker(
		box, "Necessity",
		[
			{"id": "useful", "name": "Useful (+0)"},
			{"id": "essential", "name": "Essential (-2)"},
			{"id": "luxury", "name": "Luxury (+2)"},
		],
		_req_necessity,
		func(val: String):
			_req_necessity = val
			_rebuild()
	)

	var score_info: Dictionary = rules.requisition_check_score(raw, options)
	var ord_target := AlternityNum.as_int(score_info.get("ordinary", 10))
	var good_target := AlternityNum.as_int(score_info.get("good", 5))
	var amz_target := AlternityNum.as_int(score_info.get("amazing", 2))
	var step := AlternityNum.as_int(score_info.get("step", 0))
	var die_str := String(score_info.get("die", "+d0"))

	Widgets.metric(box, "Target score", "%d / %d / %d" % [ord_target, good_target, amz_target], palette)
	Widgets.metric(box, "Situation die", "%s (%+d step%s)" % [die_str, step, "" if abs(step) == 1 else "s"], palette)

	if not _req_outcome_text.is_empty():
		Widgets.separator(box, palette)
		var outcome_card := VBoxContainer.new()
		outcome_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var res_label := Label.new()
		res_label.text = "Result: %s" % _req_outcome_degree
		res_label.add_theme_color_override("font_color", palette.accent)
		res_label.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
		outcome_card.add_child(res_label)

		var desc_label := Label.new()
		desc_label.text = _req_outcome_text
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(1, 0)
		desc_label.add_theme_color_override("font_color", palette.text)
		desc_label.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
		outcome_card.add_child(desc_label)
		box.add_child(outcome_card)

	var roll_btn := Button.new()
	roll_btn.text = "Roll Requisition Check"
	roll_btn.custom_minimum_size = Vector2(0, 44)
	roll_btn.pressed.connect(func():
		if ctx.checks != null:
			var rolled = await ctx.checks.run_requisition_check(ctx.doc, options)
			if rolled != null:
				var degree: String = (rolled as SkillCheck).degree()
				var outcome_key := degree.to_lower().replace(" ", "_")
				_req_outcome_degree = degree
				_req_outcome_text = String(AlternityRulesConstants.REQUISITION_OUTCOMES.get(outcome_key, ""))
				_rebuild()
		else:
			var d20 := randi_range(1, 20)
			var sit := 0
			if die_str.begins_with("+d") and die_str != "+d0":
				sit = randi_range(1, int(die_str.substr(2)))
			elif die_str.begins_with("-d"):
				sit = -randi_range(1, int(die_str.substr(2)))
			var outcome := rules.resolve_requisition_check(raw, d20, sit, options)
			_req_outcome_degree = String(outcome.get("degree", "Failure"))
			_req_outcome_text = String(outcome.get("outcome_description", ""))
			_rebuild()
	)
	box.add_child(roll_btn)


func _requisition_picker(parent: Container, label_text: String, entries: Array, current_val: String, changed: Callable) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", ctx.palette.muted)
	label.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	parent.add_child(label)

	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.custom_minimum_size = Vector2(0, 42)
	parent.add_child(picker)

	var selected := 0
	for i in entries.size():
		var id := String(entries[i]["id"])
		picker.add_item(String(entries[i]["name"]), i)
		if id == current_val:
			selected = i
	picker.select(selected)

	picker.item_selected.connect(func(index: int):
		changed.call(String(entries[index]["id"]))
	)



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

	var worn := Widgets.toggle_row(controls, "Equipped", equipped, palette, true)

	# Trailing slack, so quantity and equipped stay together on the left rather
	# than being flung to opposite ends of a wide panel.
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.add_child(gap)
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
