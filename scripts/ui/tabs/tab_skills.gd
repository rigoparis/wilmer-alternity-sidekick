extends SheetTab
##
## Skill points, chosen skills, and the picker to buy more.
##
## Shares SkillPicker with the Psionics tab. The old UI shared a function
## instead -- _render_skill_picker, parameterised by an is_psionics boolean that
## also switched four member variables in pairs. Two instances of a control need
## no pairs.
##

const DETAIL_ROUTE := preload("res://scenes/ui/routes/skill_detail_route.tscn")

var _budget_host: Container
var _tracker_host: Container
var _selected_host: Container
var _picker: SkillPicker
var _editing_skills: bool = false


## Declares custom scroll handling only on wide (desktop) layouts so the outer sheet
## can scroll naturally on mobile devices without inner scroll traps.
func has_custom_scroll() -> bool:
	return ctx != null and ctx.is_wide_layout


## Overridden by the Psionics tab.
func picker_mode() -> int:
	return SkillPicker.Mode.NORMAL


func heading() -> String:
	return "Skills"


func watched_sections() -> Array:
	# Skill scores derive from abilities, flaws and perks affect budget,
	# cybertech and FX skills spend SP, and achievements raise rank caps.
	return [
		CharacterDoc.SKILLS, CharacterDoc.ABILITIES,
		CharacterDoc.PERKS_FLAWS, CharacterDoc.ACHIEVEMENTS, CharacterDoc.META,
		CharacterDoc.CYBERTECH, CharacterDoc.FX, CharacterDoc.OPTIONAL_RULES,
	]


func unbind() -> void:
	super.unbind()
	_budget_host = null
	_tracker_host = null
	_selected_host = null
	_picker = null
	_editing_skills = false


## Rebuild in-place when internal hosts are valid to preserve the catalog's
## active ability tab, search filter, and scroll position.
func _rebuild() -> void:
	if _budget_host != null and is_instance_valid(_budget_host) \
			and _selected_host != null and is_instance_valid(_selected_host):
		_render_budget(_budget_host)
		if _tracker_host != null and is_instance_valid(_tracker_host):
			_render_trackers(_tracker_host)
		if _editing_skills:
			if _picker != null and is_instance_valid(_picker):
				_picker.refresh_skills()
			else:
				if ctx.is_wide_layout:
					_render_skills_panel_desktop(_selected_host)
				else:
					_render_skills_panel_mobile(_selected_host)
		else:
			if ctx.is_wide_layout:
				_render_skills_panel_desktop(_selected_host)
			else:
				_render_skills_panel_mobile(_selected_host)
		return
	super._rebuild()


func build(container: Container) -> void:
	_budget_host = null
	_tracker_host = null
	_selected_host = null
	_picker = null

	if ctx.is_wide_layout:
		_build_wide_layout(container)
	else:
		_build_compact_layout(container)


func _build_wide_layout(container: Container) -> void:
	# Top main panel: Budget and Trackers span full width
	_budget_host = VBoxContainer.new()
	_budget_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_budget_host)
	_render_budget(_budget_host)

	_tracker_host = VBoxContainer.new()
	_tracker_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_tracker_host)
	_render_trackers(_tracker_host)

	# Main panel: Selected Skills (condensed view) or Catalog (on edit)
	_selected_host = VBoxContainer.new()
	_selected_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selected_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(_selected_host)
	_render_skills_panel_desktop(_selected_host)


func _build_compact_layout(container: Container) -> void:
	# Mobile: panels on a single page scroll without inner scroll containers
	_budget_host = VBoxContainer.new()
	_budget_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_budget_host)
	_render_budget(_budget_host)

	_tracker_host = VBoxContainer.new()
	_tracker_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_tracker_host)
	_render_trackers(_tracker_host)

	_selected_host = VBoxContainer.new()
	_selected_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_selected_host)
	_render_skills_panel_mobile(_selected_host)


func _render_budget(host: Container) -> void:
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()
	_build_budget(host)


func _render_trackers(host: Container) -> void:
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()
	_build_trackers(host)


func _set_editing_skills(editing: bool) -> void:
	_editing_skills = editing
	if _selected_host != null and is_instance_valid(_selected_host):
		if ctx.is_wide_layout:
			_render_skills_panel_desktop(_selected_host)
		else:
			_render_skills_panel_mobile(_selected_host)


func _render_skills_panel_desktop(host: Container) -> void:
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()

	_picker = null
	var rows := _selected_skills_rows()
	var term := "Powers" if picker_mode() == SkillPicker.Mode.PSIONIC else "Skills"

	var toggle_btn := Widgets.edit_toggle_button(_editing_skills, ctx.palette)
	toggle_btn.pressed.connect(func(): _set_editing_skills(not _editing_skills))

	var title := "%s Catalog" % term if _editing_skills else "Selected %s (%d)" % [term, rows.size()]
	var box := Widgets.section_with_action(host, title, toggle_btn, ctx.palette)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Widgets.expand_section(box)

	if _editing_skills:
		_picker = SkillPicker.new()
		_picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(_picker)
		_picker.setup(ctx, picker_mode())
		_picker.change_requested.connect(func(): save_requested.emit())
		_picker.detail_requested.connect(_open_detail)
		return

	# View Mode: Selected Skills / Powers table
	if rows.is_empty():
		Widgets.muted_text(box, "No %s selected yet." % term.to_lower(), ctx.palette, Widgets.FONT_CAPTION)
		Widgets.muted_text(box, "Click 'Edit' above to open the %s catalog." % term.to_lower(), ctx.palette, Widgets.FONT_CAPTION)
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

	_populate_selected_skills_table(margin, rows)


func _render_skills_panel_mobile(host: Container) -> void:
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()

	_picker = null
	var rows := _selected_skills_rows()
	var term := "Powers" if picker_mode() == SkillPicker.Mode.PSIONIC else "Skills"

	var toggle_btn := Widgets.edit_toggle_button(_editing_skills, ctx.palette)
	toggle_btn.pressed.connect(func(): _set_editing_skills(not _editing_skills))

	var title := "%s Catalog" % term if _editing_skills else "Selected %s (%d)" % [term, rows.size()]
	var box := Widgets.section_with_action(host, title, toggle_btn, ctx.palette)

	if _editing_skills:
		_picker = SkillPicker.new()
		box.add_child(_picker)
		_picker.setup(ctx, picker_mode())
		_picker.change_requested.connect(func(): save_requested.emit())
		_picker.detail_requested.connect(_open_detail)
		return

	if rows.is_empty():
		Widgets.muted_text(box, "No %s selected yet." % term.to_lower(), ctx.palette, Widgets.FONT_CAPTION)
	else:
		_populate_selected_skills_table(box, rows)


func _populate_selected_skills_table(container: Container, rows: Array) -> void:
	var palette := ctx.palette

	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", Widgets.GAP_ROW)
	grid.add_theme_constant_override("v_separation", Widgets.GAP_TIGHT)
	container.add_child(grid)

	for title in ["Cost", "Rank", "Skill", "Score", "Die"]:
		var hdr := Label.new()
		hdr.text = title
		hdr.add_theme_color_override("font_color", palette.muted)
		hdr.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
		if title == "Skill":
			hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(hdr)

	var grouped: Dictionary = _group_selected_skills(rows)
	var sorted_groups: Array = grouped.get("groups", [])
	var standalone: Array = grouped.get("standalone", [])

	for group in sorted_groups:
		var broad: Dictionary = group.get("broad", {})
		if not broad.is_empty():
			_add_skill_grid_row(grid, broad, true, 0)
		for specialty in group.get("specialties", []):
			_add_skill_grid_row(grid, specialty, false, 1)

	for specialty in standalone:
		_add_skill_grid_row(grid, specialty, false, 0)


func _add_skill_grid_row(grid: GridContainer, skill: Dictionary, is_broad: bool, indent_level: int) -> void:
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var raw := ctx.doc.raw()
	var skill_id: int = AlternityNum.as_int(skill.get("id", -1))
	var rank: int = rules.skill_rank(raw, skill_id)
	var score: Dictionary = rules.skill_score(raw, skill)

	# 1. Cost
	var is_free: bool = is_broad and rules.is_free_species_skill(raw, skill_id)
	var total_cost: int = rules.skill_rank_total_cost(raw, skill)
	var cost_str := "Free" if (is_free or total_cost <= 0) else "%d SP" % total_cost

	var cost_lbl := Label.new()
	cost_lbl.text = cost_str
	cost_lbl.add_theme_color_override("font_color", palette.muted)
	cost_lbl.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(cost_lbl)

	# 2. Rank
	var rank_str := "Broad" if is_broad else str(rank)
	var rank_lbl := Label.new()
	rank_lbl.text = rank_str
	rank_lbl.add_theme_color_override("font_color", palette.muted)
	rank_lbl.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(rank_lbl)

	# 3. Skill Name
	var name_btn := Button.new()
	name_btn.flat = true
	var skill_name := String(skill.get("name", rules.skill_label(skill)))
	name_btn.text = ("    " + skill_name) if indent_level > 0 else skill_name
	name_btn.tooltip_text = "View details for %s" % rules.skill_label(skill)
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.clip_text = true
	name_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_btn.add_theme_color_override("font_color", palette.accent if is_broad else palette.text)
	name_btn.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	name_btn.pressed.connect(func(): _open_detail(skill))
	grid.add_child(name_btn)

	# 4. Score
	var ord_val: int = AlternityNum.as_int(score.get("ordinary", 0))
	var good_val: int = AlternityNum.as_int(score.get("good", 0))
	var amaz_val: int = AlternityNum.as_int(score.get("amazing", 0))
	var score_lbl := Label.new()
	score_lbl.text = "O %d / G %d / A %d" % [ord_val, good_val, amaz_val]
	score_lbl.add_theme_color_override("font_color", palette.text)
	score_lbl.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	score_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(score_lbl)

	# 5. Die
	var die_str: String = String(score.get("die", "+d0"))
	var die_lbl := Label.new()
	die_lbl.text = die_str
	die_lbl.add_theme_color_override("font_color", palette.muted)
	die_lbl.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	die_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(die_lbl)


func _selected_skills_rows() -> Array:
	var rules: AlternityRules = ctx.rules
	var raw := ctx.doc.raw()
	var rows: Array = []
	var is_psi := picker_mode() == SkillPicker.Mode.PSIONIC
	for skill in rules.selected_skills(raw):
		if rules.is_psionic_skill(skill) == is_psi:
			rows.append(skill)
	return rows


func _group_selected_skills(rows: Array) -> Dictionary:
	var rules: AlternityRules = ctx.rules
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
						broad_copy["rank"] = rules.skill_rank(ctx.doc.raw(), broad_id)
						broad_copy["score"] = rules.skill_score(ctx.doc.raw(), broad_def)
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
		group["specialties"].sort_custom(func(a, b):
			return String(a.get("name", "")) < String(b.get("name", ""))
		)

	standalone.sort_custom(func(a, b):
		return String(a.get("name", "")) < String(b.get("name", ""))
	)

	return {"groups": sorted_groups, "standalone": standalone}


## A tab whose skills draw on a live resource puts its tracker here, between the
## budget and the catalog: the budget is a creation-time question, the catalog a
## shopping one, and the tracker the only part of the tab used mid-session. The
## Skills tab itself has no such resource.
func _build_trackers(_container: Container) -> void:
	pass


func _build_budget(container: Container) -> void:
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var summary := ctx.doc.summary()

	var box := Widgets.section(container, "%s Budget" % heading(), palette)

	# Bars, not bare numbers. Mid-build the question is always "have I got room",
	# and "18" and "30" on separate rows makes you do the subtraction yourself.
	var sp_used := AlternityNum.as_int(summary.get("skill_points_used", 0))
	var sp_left := AlternityNum.as_int(summary.get("skill_points_remaining", 0))
	Widgets.progress_metric(box, "Skill points", sp_used, sp_used + sp_left, palette)

	var broad_used := AlternityNum.as_int(summary.get("broad_skills_used", 0))
	var broad_left := AlternityNum.as_int(summary.get("broad_skills_remaining", 0))
	Widgets.progress_metric(box, "Broad skills", broad_used, broad_used + broad_left, palette)

	# Two different limits, and conflating them is what let a skill jump several
	# ranks at once, so both are stated.
	var raw := ctx.doc.raw()
	var level := AlternityNum.as_int(raw.get("achievement_level", 1), 1)
	Widgets.metric(
		box, "Specialty rank ceiling",
		str(rules.max_skill_rank_for_character(raw)), palette
	)
	Widgets.muted_text(
		box,
		"Specialties may be bought up to rank 3 while creating the hero."
			if level <= 1 else
		"After creation a specialty gains at most one rank at a time.",
		palette, Widgets.FONT_CAPTION
	)



func _open_detail(skill: Dictionary) -> void:
	if ctx.router == null:
		return
	var rules: AlternityRules = ctx.rules
	# skill_detail resolves rank, cost and rule notes for this character, which
	# is richer than the bare catalog record.
	var detail: Dictionary = rules.skill_detail(skill, ctx.doc.raw())
	var answer = await ctx.router.push(DETAIL_ROUTE, {
		"palette": ctx.palette,
		"data": detail,
		"title": String(detail.get("name", rules.skill_label(skill))),
		"skill": skill,
		"can_roll": ctx.can_roll(),
	})
	if not is_instance_valid(self):
		return
	# The detail view closes asking to roll rather than rolling itself: it is a
	# reference page, and a page that reached for the tray would need the runner,
	# the transport and the character it deliberately does not have.
	if typeof(answer) == TYPE_DICTIONARY and bool(answer.get("roll", false)):
		await ctx.checks.run(ctx.doc, answer.get("skill", skill))
