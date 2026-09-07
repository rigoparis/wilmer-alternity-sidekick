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


var _pool_host: Container
var _tracker_host: Container
var _selected_host: Container
var _picker: FxPicker
var _editing_powers: bool = false


## Declares custom scroll handling only on wide (desktop) layouts so the outer sheet
## can scroll naturally on mobile devices without inner scroll traps.
func has_custom_scroll() -> bool:
	return ctx != null and ctx.is_wide_layout


func watched_sections() -> Array:
	# FX draws on Will and Constitution, and the setting decides which broads
	# exist at all.
	return [CharacterDoc.FX, CharacterDoc.ABILITIES, CharacterDoc.SKILLS, CharacterDoc.META]


func unbind() -> void:
	super.unbind()
	_pool_host = null
	_tracker_host = null
	_selected_host = null
	_picker = null
	_editing_powers = false


## Rebuild in-place when internal hosts are valid to preserve the catalog's
## active category tab, search filter, and scroll position.
func _rebuild() -> void:
	var is_active := ctx.rules.fx.is_fx_active(ctx.doc.raw())
	if _pool_host != null and is_instance_valid(_pool_host) \
			and _selected_host != null and is_instance_valid(_selected_host) and is_active:
		_render_pool(_pool_host)
		if _tracker_host != null and is_instance_valid(_tracker_host):
			_render_tracker(_tracker_host)
		if _editing_powers:
			if _picker != null and is_instance_valid(_picker):
				_picker.refresh_skills()
			else:
				if ctx.is_wide_layout:
					_render_powers_panel_desktop(_selected_host)
				else:
					_render_powers_panel_mobile(_selected_host)
		else:
			if ctx.is_wide_layout:
				_render_powers_panel_desktop(_selected_host)
			else:
				_render_powers_panel_mobile(_selected_host)
		return
	super._rebuild()


func build(container: Container) -> void:
	_pool_host = null
	_tracker_host = null
	_selected_host = null
	_picker = null

	if not ctx.rules.fx.is_fx_active(ctx.doc.raw()):
		_build_pool(container)
		return

	if ctx.is_wide_layout:
		_build_wide_layout(container)
	else:
		_build_compact_layout(container)


func _build_wide_layout(container: Container) -> void:
	# 2-column layout: Left column = FX + FX Energy; Right column = Selected Powers / Catalog
	var columns_row := HBoxContainer.new()
	columns_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns_row.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	container.add_child(columns_row)

	# Left column: FX Pool card on top, FX Energy tracker card below it
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	left.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	columns_row.add_child(left)

	_pool_host = VBoxContainer.new()
	_pool_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_pool_host)
	_render_pool(_pool_host)

	_tracker_host = VBoxContainer.new()
	_tracker_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_tracker_host)
	_render_tracker(_tracker_host)

	# Right column: Selected Powers (or Catalog on Edit)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	columns_row.add_child(right)

	_selected_host = VBoxContainer.new()
	_selected_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selected_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_selected_host)
	_render_powers_panel_desktop(_selected_host)


func _build_compact_layout(container: Container) -> void:
	# Mobile: panels on a single page scroll without inner scroll containers
	_pool_host = VBoxContainer.new()
	_pool_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_pool_host)
	_render_pool(_pool_host)

	_tracker_host = VBoxContainer.new()
	_tracker_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_tracker_host)
	_render_tracker(_tracker_host)

	_selected_host = VBoxContainer.new()
	_selected_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_selected_host)
	_render_powers_panel_mobile(_selected_host)


func _render_pool(host: Container) -> void:
	for child in host.get_children():
		child.hide()
		child.queue_free()
	_build_pool(host)


func _render_tracker(host: Container) -> void:
	for child in host.get_children():
		child.hide()
		child.queue_free()
	_build_energy_tracker(host)


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

	var enabled: bool = rules.fx.is_fx_active(doc.raw())
	if rules.is_adept_profession(doc.raw()):
		Widgets.metric(box, "FX access", "Granted by profession", palette)
	else:
		var toggle := Widgets.toggle_row(box, "Hero is an FX Talent", enabled, palette)
		toggle.toggled.connect(func(pressed: bool):
			doc.apply([CharacterDoc.FX], func(c): rules.fx.set_fx_talent(c, pressed))
			save_requested.emit())

	if not enabled:
		return

	var pool: int = rules.fx.energy_pool(doc.raw())
	if rules.is_dark_matter(doc.raw()):
		Widgets.metric(box, "Starting FX energy pool", str(pool), palette)
	else:
		var stepper := NumberStepper.new()
		box.add_child(stepper)
		stepper.setup(palette, "Starting FX energy pool", pool, 0, 99, 1, 0, true)
		stepper.value_changed.connect(func(value: int):
			doc.apply([CharacterDoc.FX], func(c): rules.fx.set_energy_pool(c, value))
			save_requested.emit())

	# Points bought with achievement points, which is the only way the pool
	# grows after creation, and which the Achievements tab sells.
	var bought: int = rules.fx.energy_pool_bonus(doc.raw())
	if bought > 0:
		Widgets.metric(box, "Bought with achievement points", "+%d" % bought, palette)
		Widgets.metric(box, "Total pool", str(rules.fx.total_energy_pool(doc.raw())), palette)

	_build_practitioner_type_picker(box)
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
## The spendable half of the pool, tracked the way psionic energy and damage
## are. FX rests on the same table: an hour, a Resolve -- mental resolve check,
## and 1, 2 or 3 points back.
## Source: Beyond Science: A Guide to FX p. 5.
func _build_energy_tracker(container: Container) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var pool: Dictionary = rules.fx.fx_energy(doc.raw())
	var spendable := AlternityNum.as_int(pool.get("spendable", 0))
	if spendable <= 0:
		return

	var parent := Widgets.section(container, "FX Energy", palette)

	var reserved := AlternityNum.as_int(pool.get("reserved", 0))
	if reserved > 0:
		Widgets.metric(
			parent, "Held by permanent powers",
			"%d of %d" % [reserved, AlternityNum.as_int(pool.get("max", 0))], palette
		)

	var tracker := DamageTrack.new()
	parent.add_child(tracker)
	tracker.setup(palette, "Energy spent", AlternityNum.as_int(pool.get("used", 0)), spendable)
	tracker.value_changed.connect(func(value: int):
		doc.apply([CharacterDoc.FX], func(c): rules.fx.set_energy_used(c, value))
		save_requested.emit())

	Widgets.rest_row(
		parent, palette, ctx.is_wide_layout,
		func(degree: String):
			doc.apply([CharacterDoc.FX], func(c):
				if degree == "full":
					rules.fx.full_rest_energy(c)
				else:
					rules.fx.rest_energy(c, degree))
			save_requested.emit(),
		[
			["8 hours: full", "full",
				"Eight unbroken hours without using FX recover the whole pool, with no check. "
					+ "Beyond Science: A Guide to FX p. 5."],
		]
	)


func _build_primary_group_picker(parent: Container) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var raw := doc.raw()
	if not rules.fx.is_fx_adept(raw):
		return

	# Only schools the hero actually has: a primary school you do not practise
	# is what caused the problem.
	var owned: Array = []
	for broad in rules.fx.get_broad_skills_for_character(raw):
		var broad_name := String(broad.get("name", ""))
		if rules.fx.is_fx_skill_selected(raw, broad_name):
			owned.append(broad_name)
	if owned.is_empty():
		return

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

	var label := Label.new()
	label.text = "Primary school"
	label.add_theme_color_override("font_color", palette.muted)
	label.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	parent.add_child(label)

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
		"Every FX user names one primary school, and the choice cannot be changed later. "
		+ "An Adept receives the profession's 1-point discount on that broad skill and "
		+ "its specialties; Talents pay the printed price.",
		palette, Widgets.FONT_CAPTION
	)


func _build_practitioner_type_picker(parent: Container) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var raw := doc.raw()

	if rules.fx.is_fx_adept(raw):
		var profession := rules.get_profession_by_id(AlternityNum.as_int(raw.get("profession_id", 0)))
		Widgets.metric(parent, "Practitioner type", String(profession.get("name", "FX Adept")), palette)
		var pool_note := (
			"This secondary Adept profession uses a Talent-sized starting pool. "
			if String(profession.get("adept_role", "")) == "secondary"
			else "A primary Adept uses the campaign's full starting pool. "
		)
		var rank_note := "Specialties may advance to Rank 12, subject to level."
		if rules.is_dark_matter(raw) and not rules.optional_rule_enabled(raw, "dm_adept_unrestricted_ranks"):
			rank_note = "Chosen-school specialties cap at Rank 6; other schools cap at Rank 3."
		Widgets.muted_text(
			parent,
			pool_note + "The chosen broad skill and its specialties receive the 1-point Adept discount. " + rank_note,
			palette,
			Widgets.FONT_CAPTION
		)
		return

	if rules.is_dark_matter(raw):
		Widgets.muted_text(
			parent,
			"In Dark*Matter, all FX users are FX Talents (+1 SP surcharge on FX skills; 1 specialty to Rank 6, others to Rank 3).",
			palette,
			Widgets.FONT_CAPTION
		)
		return

	Widgets.metric(parent, "Practitioner type", "FX Talent", palette)
	Widgets.muted_text(
		parent,
		"FX Talents pay printed list price for every FX skill. Up to two specialties may reach Rank 6; all others cap at Rank 3.",
		palette,
		Widgets.FONT_CAPTION
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


func _set_editing_powers(editing: bool) -> void:
	_editing_powers = editing
	if _selected_host != null and is_instance_valid(_selected_host):
		if ctx.is_wide_layout:
			_render_powers_panel_desktop(_selected_host)
		else:
			_render_powers_panel_mobile(_selected_host)


func _render_powers_panel_desktop(host: Container) -> void:
	for child in host.get_children():
		child.hide()
		child.queue_free()

	_picker = null
	var rows := ctx.rules.fx.selected_fx_skills(ctx.doc.raw())
	var fx_enabled: bool = ctx.rules.fx.is_fx_active(ctx.doc.raw())

	var toggle_btn := Widgets.edit_toggle_button(_editing_powers, ctx.palette)
	toggle_btn.disabled = not fx_enabled
	toggle_btn.pressed.connect(func(): _set_editing_powers(not _editing_powers))

	var title := "Powers Catalog" if _editing_powers else "Selected Powers (%d)" % rows.size()
	var box := Widgets.section_with_action(host, title, toggle_btn, ctx.palette)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Widgets.expand_section(box)

	if _editing_powers:
		_picker = FxPicker.new()
		_picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(_picker)
		_picker.setup(ctx)
		_picker.change_requested.connect(func(): save_requested.emit())
		_picker.detail_requested.connect(_open_detail)
		return

	# View Mode: Selected Powers table
	if rows.is_empty():
		Widgets.muted_text(box, "No powers selected yet.", ctx.palette, Widgets.FONT_CAPTION)
		Widgets.muted_text(box, "Click 'Edit' above to open the powers catalog.", ctx.palette, Widgets.FONT_CAPTION)
		return

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 14)
	scroll.add_child(margin)

	_populate_selected_powers_table(margin, rows)


func _render_powers_panel_mobile(host: Container) -> void:
	for child in host.get_children():
		child.hide()
		child.queue_free()

	_picker = null
	var rows := ctx.rules.fx.selected_fx_skills(ctx.doc.raw())
	var fx_enabled: bool = ctx.rules.fx.is_fx_active(ctx.doc.raw())

	var toggle_btn := Widgets.edit_toggle_button(_editing_powers, ctx.palette)
	toggle_btn.disabled = not fx_enabled
	toggle_btn.pressed.connect(func(): _set_editing_powers(not _editing_powers))

	var title := "Powers Catalog" if _editing_powers else "Selected Powers (%d)" % rows.size()
	var box := Widgets.section_with_action(host, title, toggle_btn, ctx.palette)

	if _editing_powers:
		_picker = FxPicker.new()
		box.add_child(_picker)
		_picker.setup(ctx)
		_picker.change_requested.connect(func(): save_requested.emit())
		_picker.detail_requested.connect(_open_detail)
		return

	if rows.is_empty():
		Widgets.muted_text(box, "No powers selected yet.", ctx.palette, Widgets.FONT_CAPTION)
	else:
		_populate_selected_powers_table(box, rows)


func _populate_selected_powers_table(container: Container, rows: Array) -> void:
	var palette := ctx.palette

	var grid := GridContainer.new()
	grid.columns = 6
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", Widgets.GAP_ROW)
	grid.add_theme_constant_override("v_separation", Widgets.GAP_TIGHT)
	container.add_child(grid)

	for title in ["Cost", "Rank", "Power", "Score", "Die", "FX Cost"]:
		var hdr := Label.new()
		hdr.text = title
		hdr.add_theme_color_override("font_color", palette.muted)
		hdr.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
		if title == "Power":
			hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(hdr)

	var groups := _group_selected_powers(rows)
	for group in groups:
		var broad: Dictionary = group.get("broad", {})
		if not broad.is_empty():
			_add_power_grid_row(grid, broad, true, 0)
		for spec in group.get("specialties", []):
			_add_power_grid_row(grid, spec, false, 1 if not broad.is_empty() else 0)


func _add_power_grid_row(grid: GridContainer, item: Dictionary, is_broad: bool, indent_level: int) -> void:
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var raw := ctx.doc.raw()
	var item_name: String = String(item.get("name", ""))

	# 1. Cost
	var total_cost := 0
	if is_broad:
		total_cost = rules.fx.fx_skill_cost_for_rank(raw, item_name, 1)
		if total_cost <= 0:
			total_cost = AlternityNum.as_int(item.get("cost", 0))
	else:
		total_cost = rules.fx.fx_skill_total_cost(raw, item_name)
	var cost_str := "Free" if total_cost <= 0 else "%d SP" % total_cost

	var cost_lbl := Label.new()
	cost_lbl.text = cost_str
	cost_lbl.add_theme_color_override("font_color", palette.muted)
	cost_lbl.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(cost_lbl)

	# 2. Rank
	var rank_str := "Broad" if is_broad else str(AlternityNum.as_int(item.get("rank", 0)))
	var rank_lbl := Label.new()
	rank_lbl.text = rank_str
	rank_lbl.add_theme_color_override("font_color", palette.muted)
	rank_lbl.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(rank_lbl)

	# 3. Power Name
	var name_btn := Button.new()
	name_btn.flat = true
	name_btn.text = ("    " + item_name) if indent_level > 0 else item_name
	name_btn.tooltip_text = "View details for %s" % item_name
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.clip_text = true
	name_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_btn.add_theme_color_override("font_color", palette.accent if is_broad else palette.text)
	name_btn.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	name_btn.pressed.connect(func(): _open_detail(item))
	grid.add_child(name_btn)

	# 4. Score
	var score: Dictionary = rules.fx.fx_skill_score(raw, item_name)
	var usable: bool = bool(score.get("usable", true))
	var score_lbl := Label.new()
	if usable:
		var ord_val: int = AlternityNum.as_int(score.get("ordinary", 0))
		var good_val: int = AlternityNum.as_int(score.get("good", 0))
		var amaz_val: int = AlternityNum.as_int(score.get("amazing", 0))
		score_lbl.text = "O %d / G %d / A %d" % [ord_val, good_val, amaz_val]
		score_lbl.add_theme_color_override("font_color", palette.text)
	else:
		score_lbl.text = "-"
		score_lbl.add_theme_color_override("font_color", palette.muted)
	score_lbl.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	score_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(score_lbl)

	# 5. Die
	var die_lbl := Label.new()
	die_lbl.text = String(score.get("die", "+d0")) if usable else "-"
	die_lbl.add_theme_color_override("font_color", palette.muted)
	die_lbl.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	die_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(die_lbl)

	# 6. FX Cost
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


func _group_selected_powers(rows: Array) -> Array:
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


func _build_picker(container: Container) -> void:
	var box := Widgets.section(container, "Powers", ctx.palette)
	if ctx.is_wide_layout:
		Widgets.expand_section(box)

	_picker = FxPicker.new()
	if ctx.is_wide_layout:
		_picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_picker)
	_picker.setup(ctx)
	_picker.change_requested.connect(func(): save_requested.emit())
	_picker.detail_requested.connect(_open_detail)


func _open_detail(skill: Dictionary) -> void:
	if ctx.router == null:
		return
	await ctx.router.push(DETAIL_ROUTE, {
		"palette": ctx.palette,
		"data": skill,
		"title": String(skill.get("name", "")),
	})
