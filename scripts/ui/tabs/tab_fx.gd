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
## Browsing is FxPicker, which is shaped like the Skills tab: a bar of
## categories to tab across, schools under the selected one, and their powers
## nested beneath. It replaces a flat list of what was already chosen plus two
## "Add" buttons that sent you to a catalog route to see what existed at all.
##

const DETAIL_ROUTE := preload("res://scenes/ui/routes/skill_detail_route.tscn")


func watched_sections() -> Array:
	# FX draws on Will and Constitution, and the setting decides which broads
	# exist at all.
	return [CharacterDoc.FX, CharacterDoc.ABILITIES, CharacterDoc.SKILLS, CharacterDoc.META]


func build(container: Container) -> void:
	_build_pool(container)
	if not ctx.rules.fx.is_fx_talent(ctx.doc.raw()):
		return
	_build_picker(container)


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
	stepper.setup(palette, "Starting FX energy pool", pool, 0, 99)
	stepper.value_changed.connect(func(value: int):
		doc.apply([CharacterDoc.FX], func(c): rules.fx.set_energy_pool(c, value))
		save_requested.emit())

	# Points bought with achievement points, which is the only way the pool
	# grows after creation, and which the Achievements tab sells.
	var bought: int = rules.fx.energy_pool_bonus(doc.raw())
	if bought > 0:
		Widgets.metric(box, "Bought with achievement points", "+%d" % bought, palette)
		Widgets.metric(box, "Total pool", str(rules.fx.total_energy_pool(doc.raw())), palette)

	_build_scale_picker(box)
	_build_primary_group_picker(box)

	# Always-active powers permanently reserve part of the pool, so the usable
	# figure is the one that matters in play.
	var drain: int = rules.fx.permanent_fx_energy_drain(doc.raw())
	if drain > 0:
		Widgets.metric(box, "Reserved by permanent powers", "-%d" % drain, palette)
		Widgets.metric(
			box, "Usable pool",
			str(maxi(0, rules.fx.total_energy_pool(doc.raw()) - drain)), palette
		)

	Widgets.metric(box, "Skill points spent on FX", str(rules.fx.fx_skill_purchase_points_used(doc.raw())), palette)

	# Each entry is a {name, description} dictionary. Passing one to String()
	# has no valid constructor and took the whole tab down for any hero with a
	# permanent power -- which is why this only ever failed on a real character.
	for effect in rules.fx.permanent_fx_effects_summary(doc.raw()):
		if typeof(effect) != TYPE_DICTIONARY:
			Widgets.muted_text(box, str(effect), palette, Widgets.FONT_CAPTION)
			continue
		var entry: Dictionary = effect
		var effect_name := String(entry.get("name", "")).strip_edges()
		var description := String(entry.get("description", "")).strip_edges()
		if effect_name.is_empty() and description.is_empty():
			continue
		Widgets.muted_text(
			box,
			"%s: %s" % [effect_name, description] if not description.is_empty() else effect_name,
			palette, Widgets.FONT_CAPTION
		)


## Which school the hero's FX is centred on.
##
## Powers outside it cost double, so this is not decoration -- and until now it
## could be neither seen nor set, which left one real character paying twice for
## powers in schools they owned.
func _build_primary_group_picker(parent: Container) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var raw := doc.raw()

	# Only schools the hero actually has: a primary school you do not practise
	# is what caused the problem.
	var owned: Array = []
	for broad in rules.fx.get_broad_skills_for_character(raw):
		var broad_name := String(broad.get("name", ""))
		if rules.fx.is_fx_skill_selected(raw, broad_name):
			owned.append(broad_name)
	if owned.is_empty():
		return

	var label := Label.new()
	label.text = "Primary school"
	label.add_theme_color_override("font_color", palette.muted)
	label.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	parent.add_child(label)

	var current := rules.fx.primary_broad_group(raw)

	# Once named, it is fixed: it is the hero's tradition, not a purchase to
	# re-optimise. So the control disappears rather than offering a change it
	# would refuse.
	if not current.is_empty():
		Widgets.metric(parent, "Primary school", current, palette)
		Widgets.muted_text(
			parent,
			"Chosen when you took up FX and fixed from then on. Powers from any "
			+ "other school cost double.",
			palette, Widgets.FONT_CAPTION
		)
		return

	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.custom_minimum_size = Vector2(0, 42)
	picker.add_item("Not chosen yet", 0)
	for index in owned.size():
		picker.add_item(String(owned[index]), index + 1)
	picker.select(0)
	picker.item_selected.connect(func(index: int):
		if index <= 0:
			return
		doc.apply([CharacterDoc.FX], func(c):
			rules.fx.set_primary_broad_group(c, String(owned[index - 1])))
		save_requested.emit())
	parent.add_child(picker)

	Widgets.muted_text(
		parent,
		"Every FX user names one primary school. Powers from any other school "
		+ "cost double, and the choice cannot be changed later. Until you "
		+ "choose, every power is priced at list -- cheaper than the rules allow.",
		palette, Widgets.FONT_CAPTION
	)


## What the campaign charges in achievement points for a point of FX pool.
##
## A campaign-wide decision rather than a character one, but it is recorded per
## character because that is where this app keeps everything a table agrees on.
func _build_scale_picker(parent: Container) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette

	var label := Label.new()
	label.text = "Campaign FX scale"
	label.add_theme_color_override("font_color", palette.muted)
	label.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	parent.add_child(label)

	var current := rules.fx_campaign_scale(doc.raw())
	var scales: Array = AlternityRules.FX_CAMPAIGN_SCALES

	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.custom_minimum_size = Vector2(0, 42)
	var selected := 0
	for index in scales.size():
		var entry: Dictionary = scales[index]
		picker.add_item(
			"%s  -  %d AP per point" % [
				String(entry.get("name", "")),
				AlternityNum.as_int(entry.get("ap_per_point", 0)),
			],
			index
		)
		if String(entry.get("id", "")) == current:
			selected = index
	picker.select(selected)
	picker.item_selected.connect(func(index: int):
		var entry: Dictionary = scales[index]
		doc.apply(CharacterDoc.ALL, func(c):
			rules.set_fx_campaign_scale(c, String(entry.get("id", ""))))
		save_requested.emit())
	parent.add_child(picker)

	Widgets.muted_text(
		parent,
		"Enlarging the pool is bought with achievement points, not skill points, "
		+ "so it costs progress toward your next level. The pool can never pass "
		+ "twice its starting value.",
		palette, Widgets.FONT_CAPTION
	)


func _build_picker(container: Container) -> void:
	var box := Widgets.section(container, "Powers", ctx.palette)

	var picker := FxPicker.new()
	box.add_child(picker)
	picker.setup(ctx)
	picker.change_requested.connect(func(): save_requested.emit())
	picker.detail_requested.connect(_open_detail)


func _open_detail(skill: Dictionary) -> void:
	if ctx.router == null:
		return
	await ctx.router.push(DETAIL_ROUTE, {
		"palette": ctx.palette,
		"data": skill,
		"title": String(skill.get("name", "")),
	})
