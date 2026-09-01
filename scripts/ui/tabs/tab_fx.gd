extends SheetTab
##
## FX: the energy pool, chosen schools and faiths, and their powers.
##
## The broad-skill list is setting-gated, so Dark Matter faiths (Incantation)
## only appear while that setting is selected. That filtering happens in the
## rules layer via get_broad_skills_for_character, not here, so every view that
## lists FX broads gets it.
##
## Tapping a power opens its reference text as a bottom sheet, rendered by
## SkillDetailView from the typed section schema -- the same renderer core
## skills use, replacing the two divergent detail panels the old UI had.
##

const CATALOG_ROUTE := preload("res://scenes/ui/routes/catalog_route.tscn")
const DETAIL_ROUTE := preload("res://scenes/ui/routes/skill_detail_route.tscn")


func watched_sections() -> Array:
	# FX draws on Will and Constitution, and the setting decides which broads
	# exist at all.
	return [CharacterDoc.FX, CharacterDoc.ABILITIES, CharacterDoc.SKILLS, CharacterDoc.META]


func build(container: Container) -> void:
	_build_pool(container)
	if not ctx.rules.fx.is_fx_talent(ctx.doc.raw()):
		return
	_build_selected(container)


func _build_pool(container: Container) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette

	var box := Widgets.section(container, "FX", palette)
	Widgets.muted_text(
		box,
		"FX covers Arcane Magic, Faith and Super Powers. Powers are fuelled by an "
		+ "energy pool that recovers with rest.",
		palette,
		Widgets.FONT_CAPTION
	)

	var enabled: bool = rules.fx.is_fx_talent(doc.raw())
	var toggle := Widgets.toggle_row(box, "Hero uses FX", enabled, palette)
	toggle.toggled.connect(func(pressed: bool):
		doc.apply([CharacterDoc.FX], func(c): rules.fx.set_fx_talent(c, pressed))
		save_requested.emit())

	if not enabled:
		return

	var pool: int = rules.fx.energy_pool(doc.raw())
	var stepper := NumberStepper.new()
	box.add_child(stepper)
	stepper.setup(palette, "FX energy pool", pool, 0, 99)
	stepper.value_changed.connect(func(value: int):
		doc.apply([CharacterDoc.FX], func(c): rules.fx.set_energy_pool(c, value))
		save_requested.emit())

	# Always-active powers permanently reserve part of the pool, so the usable
	# figure is the one that matters in play.
	var drain: int = rules.fx.permanent_fx_energy_drain(doc.raw())
	if drain > 0:
		Widgets.metric(box, "Reserved by permanent powers", "-%d" % drain, palette)
		Widgets.metric(box, "Usable pool", str(maxi(0, pool - drain)), palette)

	Widgets.metric(box, "Skill points spent on FX", str(rules.fx.fx_skill_purchase_points_used(doc.raw())), palette)

	for effect in rules.fx.permanent_fx_effects_summary(doc.raw()):
		Widgets.muted_text(box, String(effect), palette, Widgets.FONT_CAPTION)


func _build_selected(container: Container) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette

	var box := Widgets.section(container, "Powers", palette)

	var selected: Array = rules.fx.selected_fx_skills(doc.raw())
	if selected.is_empty():
		Widgets.muted_text(box, "No FX skills chosen yet.", palette)

	for skill in selected:
		_build_selected_row(box, skill)

	var add_broad := Button.new()
	add_broad.text = "Add School / Faith / Category"
	add_broad.custom_minimum_size = Vector2(0, 44)
	add_broad.pressed.connect(_open_broad_catalog)
	box.add_child(add_broad)

	var add_power := Button.new()
	add_power.text = "Add Power"
	add_power.custom_minimum_size = Vector2(0, 44)
	add_power.pressed.connect(_open_power_catalog)
	box.add_child(add_power)


func _build_selected_row(parent: Container, skill: Dictionary) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var skill_name := String(skill.get("name", ""))

	var block := VBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	parent.add_child(block)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", Widgets.GAP_ROW)
	block.add_child(header)

	# The name is a button: tapping a power is how you read what it does.
	var name_button := Button.new()
	name_button.text = skill_name
	name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_button.custom_minimum_size = Vector2(0, 36)
	name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_button.pressed.connect(_open_detail.bind(skill))
	header.add_child(name_button)

	var rank := AlternityNum.as_int(skill.get("rank", 0))
	var rank_label := Label.new()
	rank_label.text = "Rank %d" % rank
	rank_label.add_theme_color_override("font_color", palette.accent)
	rank_label.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	header.add_child(rank_label)

	var remove := Button.new()
	remove.text = "Remove"
	remove.custom_minimum_size = Vector2(84, 36)
	remove.pressed.connect(func():
		doc.apply([CharacterDoc.FX], func(c): rules.fx.remove_fx_skill(c, skill_name))
		save_requested.emit())
	header.add_child(remove)

	# Only some powers can be made always-active, so the control appears only
	# where it applies rather than being drawn disabled everywhere.
	if rules.fx.can_fx_skill_be_permanent(skill_name):
		var permanent: bool = rules.fx.is_fx_skill_permanent(doc.raw(), skill_name)
		var toggle := Widgets.toggle_row(block, "Always active (reserves pool)", permanent, palette)
		toggle.toggled.connect(func(pressed: bool):
			doc.apply([CharacterDoc.FX], func(c):
				rules.fx.set_fx_skill_permanent(c, skill_name, pressed))
			save_requested.emit())

	Widgets.separator(block, palette)


func _open_detail(skill: Dictionary) -> void:
	if ctx.router == null:
		return
	await ctx.router.push(DETAIL_ROUTE, {
		"palette": ctx.palette,
		"data": skill,
	})


func _open_broad_catalog() -> void:
	if ctx.router == null:
		return
	var rules: AlternityRules = ctx.rules
	var raw := ctx.doc.raw()

	var entries: Array = []
	# Already setting-filtered by the rules layer, so Dark Matter faiths only
	# appear when that setting is selected.
	for broad in rules.fx.get_broad_skills_for_character(raw):
		var name := String(broad.get("name", ""))
		entries.append({
			"id": name,
			"name": name,
			"summary": String(broad.get("category", "")),
			"meta": "%d SP" % rules.fx.fx_skill_cost(raw, name),
			"taken": rules.fx.is_fx_skill_selected(raw, name),
		})

	var chosen = await ctx.router.push(CATALOG_ROUTE, {
		"palette": ctx.palette,
		"title": "Schools, Faiths and Categories",
		"entries": entries,
	})
	_apply_chosen(chosen)


func _open_power_catalog() -> void:
	if ctx.router == null:
		return
	var rules: AlternityRules = ctx.rules
	var raw := ctx.doc.raw()

	var entries: Array = []
	# Powers are only offered under a broad the hero actually has: FX specialty
	# skills cannot be used without their parent.
	for broad in rules.fx.get_broad_skills_for_character(raw):
		var broad_name := String(broad.get("name", ""))
		if not rules.fx.is_fx_skill_selected(raw, broad_name):
			continue
		for specialty in rules.fx.get_specialty_skills_for_broad_and_character(broad_name, raw):
			var name := String(specialty.get("name", ""))
			entries.append({
				"id": name,
				"name": name,
				"summary": "%s  |  %s" % [broad_name, String(specialty.get("category", ""))],
				"meta": "%d SP" % rules.fx.fx_skill_cost(raw, name),
				"taken": rules.fx.is_fx_skill_selected(raw, name),
			})

	if entries.is_empty():
		await ctx.router.push(DETAIL_ROUTE, {
			"palette": ctx.palette,
			"title": "No powers available",
			"data": {
				"name": "No powers available",
				"description": "Add a school, faith or category first. FX powers can only be taken under a broad skill the hero already has.",
			},
		})
		return

	var chosen = await ctx.router.push(CATALOG_ROUTE, {
		"palette": ctx.palette,
		"title": "FX Powers",
		"entries": entries,
	})
	_apply_chosen(chosen)


func _apply_chosen(chosen: Variant) -> void:
	if not is_instance_valid(self) or ctx == null or ctx.doc == null:
		return
	if typeof(chosen) != TYPE_ARRAY or chosen.is_empty():
		return

	var rules: AlternityRules = ctx.rules
	ctx.doc.apply([CharacterDoc.FX], func(c):
		for skill_name in chosen:
			rules.fx.add_fx_skill(c, String(skill_name)))
	save_requested.emit()
