extends SheetTab
##
## Cybertech: tolerance, cykosis, the required skill, and the catalog.
##
## Chosen as the first migrated tab because it was the least entangled thing in
## the old file -- one function, no private helpers, no overlay, and not one
## exclusive member variable. If the SheetTab contract is wrong, it shows up
## here with almost nothing else in the way.
##
## Every mutation goes through doc.apply() and the rebuild follows from the
## change signal. The old renderer called char_manager.save_character(
## notes_editing, notes_draft) and then _render() by hand after each edit, from
## five separate places in this tab alone -- threading the Summary tab's notes
## state through Cybertech to do it.
##

const QUALITIES := ["ordinary", "good", "amazing"]


func watched_sections() -> Array:
	# Abilities are watched because cyber tolerance derives from Constitution,
	# and species because Mechalus get +4.
	return [CharacterDoc.CYBERTECH, CharacterDoc.ABILITIES, CharacterDoc.META]


func build(container: Container) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette

	var top := Widgets.section(container, "Cybertech", palette)
	Widgets.muted_text(
		top,
		"Cybertech allows characters to enhance their bodies with technology. "
		+ "Your Cyber Tolerance is equal to your Constitution score (Mechalus get +4). "
		+ "Installing items uses up your tolerance. Items that tap into your nervous "
		+ "system (like Reflex or Fast Chips) risk giving you Cykosis, a mental strain "
		+ "that reduces your Will-based checks by -1 per point of Cykosis.",
		palette,
		Widgets.FONT_CAPTION
	)

	var enabled: bool = rules.cybertech.cybertech_enabled(doc.raw())
	var enable_toggle := Widgets.toggle_row(top, "Hero uses Cybertech", enabled, palette)
	enable_toggle.toggled.connect(func(pressed: bool):
		doc.apply([CharacterDoc.CYBERTECH], func(c): rules.cybertech.set_cybertech_enabled(c, pressed))
		save_requested.emit())

	if not enabled:
		return

	_build_metrics(top, doc, rules, palette)
	Widgets.separator(top, palette)

	var skill_purchased: bool = rules.cybertech.is_cybertech_skill_purchased(doc.raw())
	var skill_toggle := Widgets.toggle_row(
		top,
		"Purchase the Cybertech skill required to use certain cybertech for 10 skill points",
		skill_purchased,
		palette
	)
	skill_toggle.toggled.connect(func(pressed: bool):
		doc.apply([CharacterDoc.CYBERTECH], func(c): rules.cybertech.set_cybertech_skill_purchased(c, pressed))
		save_requested.emit())

	_build_catalog(container, doc, rules, palette)


func _build_metrics(parent: Container, doc: CharacterDoc, rules: AlternityRules, palette: ThemePalette) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", Widgets.GAP_ROW)
	parent.add_child(box)

	var tolerance: Dictionary = rules.cybertech.cyber_tolerance_breakdown(doc.raw())
	Widgets.metric(
		box, "Cyber Tolerance Used / Total",
		"%d / %d" % [AlternityNum.as_int(tolerance.get("used", 0)), AlternityNum.as_int(tolerance.get("total", 0))],
		palette
	)

	var left := AlternityNum.as_int(tolerance.get("left", 0))
	var center := AlternityNum.as_int(tolerance.get("center", 0))
	Widgets.metric(
		box, "Cyber Tolerance Thresholds",
		"%d / %d / %d" % [left, left + center, AlternityNum.as_int(tolerance.get("total", 0))],
		palette
	)

	var cykosis_total: int = rules.cybertech.cykosis_total(doc.raw())
	var stepper := NumberStepper.new()
	box.add_child(stepper)
	stepper.setup(
		palette,
		"Cykosis Points Used (Max %d)" % cykosis_total,
		rules.cybertech.cykosis_used(doc.raw()),
		0,
		cykosis_total
	)
	stepper.value_changed.connect(func(value: int):
		doc.apply([CharacterDoc.CYBERTECH], func(c): rules.cybertech.set_cykosis_used(c, value))
		save_requested.emit())


func _build_catalog(container: Container, doc: CharacterDoc, rules: AlternityRules, palette: ThemePalette) -> void:
	var catalog := Widgets.section(container, "Cybertech Catalog", palette)

	var installed_ids := {}
	for entry in rules.cybertech.installed_cybertech(doc.raw()):
		installed_ids[String(entry.get("item_id", ""))] = true

	for item_value in rules.cybertech_catalog:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		_build_catalog_row(catalog, item_value, installed_ids, doc, rules, palette)


func _build_catalog_row(
	parent: Container,
	item: Dictionary,
	installed_ids: Dictionary,
	doc: CharacterDoc,
	rules: AlternityRules,
	palette: ThemePalette
) -> void:
	var item_id := String(item.get("id", ""))
	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	parent.add_child(row)

	Widgets.text(row, String(item.get("name", "")), palette, Widgets.FONT_SUBHEADING, palette.accent)

	var info := "PL: %d  |  Mass: %s  |  Size: %s" % [
		AlternityNum.as_int(item.get("pl", 6), 6),
		str(item.get("mass", item.get("mass_ordinary", 0))),
		str(item.get("size", item.get("size_ordinary", 0))),
	]
	var source := String(item.get("source", ""))
	if not source.is_empty():
		info += "  |  Source: %s" % source
	Widgets.muted_text(row, info, palette, Widgets.FONT_CAPTION)
	Widgets.text(row, String(item.get("description", "")), palette)

	# HFlow so the install buttons wrap on a narrow screen instead of pushing
	# the row off the side.
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", Widgets.GAP_ROW)
	actions.add_theme_constant_override("v_separation", Widgets.GAP_ROW)
	parent.add_child(actions)

	if installed_ids.has(item_id):
		var remove := Button.new()
		remove.text = "Remove"
		remove.custom_minimum_size = Vector2(0, 40)
		remove.pressed.connect(func():
			doc.apply([CharacterDoc.CYBERTECH], func(c): rules.cybertech.remove_cybertech(c, item_id))
			save_requested.emit())
		actions.add_child(remove)
		Widgets.separator(parent, palette)
		return

	var blocked_reason := ""
	for quality in QUALITIES:
		if AlternityNum.as_int(item.get("cost_%s" % quality, 0)) <= 0:
			continue
		var verdict: Dictionary = rules.cybertech.can_install_cybertech(doc.raw(), item_id, quality)
		var allowed := bool(verdict.get("allowed", false))
		if not allowed:
			blocked_reason = String(verdict.get("reason", ""))

		var install := Button.new()
		install.text = "Install %s" % quality.capitalize()
		install.disabled = not allowed
		install.custom_minimum_size = Vector2(0, 40)
		install.pressed.connect(func():
			var result = doc.apply([CharacterDoc.CYBERTECH], func(c):
				return rules.cybertech.install_cybertech(c, item_id, quality))
			if typeof(result) == TYPE_DICTIONARY and bool(result.get("ok", false)):
				save_requested.emit())
		actions.add_child(install)

	# Saying why a button is disabled beats leaving the person to guess.
	if not blocked_reason.is_empty():
		Widgets.muted_text(parent, blocked_reason, palette, Widgets.FONT_CAPTION)

	Widgets.separator(parent, palette)
