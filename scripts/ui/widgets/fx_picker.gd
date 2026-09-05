class_name FxPicker
extends VBoxContainer
##
## Browse FX schools, faiths and categories, and buy their powers.
##
## Shaped like SkillPicker on purpose. FX is a skill tree with the same three
## levels core skills have -- an axis to tab across, broads under it, and
## specialties under those -- so it gets the same navigation instead of the flat
## "chosen list plus two Add buttons" it had, which made you leave the tab to
## see what was even available.
##
## The axis here is category (Arcane Magic / Faith / Super Hero) rather than
## governing ability: every FX broad is Will-based, so ability tabs would be one
## useful button and five empty ones.
##
## The broad list is setting-gated in the rules layer via
## get_broad_skills_for_character, so Dark Matter faiths (Incantation) appear
## only while that setting is selected.
##

## The tab should persist the character.
signal change_requested

## Emitted with the skill record when someone asks to read one.
signal detail_requested(skill: Dictionary)

const ICON_CHECK := preload("res://assets/check-square.svg")
const ICON_UNCHECK := preload("res://assets/check-square-empty.svg")
const ICON_MINUS := preload("res://assets/minus-square.svg")
const ICON_PLUS := preload("res://assets/add-square.svg")
const ICON_QUESTION := preload("res://assets/question-square.svg")

var _ctx: SheetContext

var _category := ""
var _query := ""

var _list: VBoxContainer
var _category_buttons: Dictionary = {}
var _card_columns: Array[Container] = []


func _init() -> void:
	add_theme_constant_override("separation", Widgets.GAP_ROW)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func setup(context: SheetContext) -> void:
	_ctx = context
	var categories := _categories()
	_category = "" if categories.is_empty() else String(categories[0])
	_build()


func _make_flat_icon_btn(icon: Texture2D, min_size: Vector2, tooltip: String = "") -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = min_size
	btn.icon = icon
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	btn.tooltip_text = tooltip
	btn.add_theme_color_override("icon_normal_color", _ctx.palette.text)
	btn.add_theme_color_override("icon_hover_color", _ctx.palette.accent)
	btn.add_theme_color_override("icon_pressed_color", _ctx.palette.accent)
	btn.add_theme_color_override("icon_disabled_color", Color(_ctx.palette.muted, 0.25))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	return btn


## The categories this character can actually reach, in catalog order.
##
## Derived rather than hardcoded so a setting that adds a category, or a data
## file that renames one, does not leave a dead tab behind.
func _categories() -> Array:
	var rules: AlternityRules = _ctx.rules
	var seen: Array = []
	for broad in rules.fx.get_broad_skills_for_character(_ctx.doc.raw()):
		var category := String(broad.get("category", "")).strip_edges()
		if category.is_empty() or seen.has(category):
			continue
		seen.append(category)
	return seen


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var search := SearchField.new()
	add_child(search)
	search.setup(_ctx.palette, "Search powers")
	search.set_query(_query)
	search.query_changed.connect(func(query: String):
		_query = query
		_refresh_list())

	_build_category_bar()

	if _ctx.is_wide_layout:
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		var scroll := ScrollContainer.new()
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size = Vector2(0, 200)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		add_child(scroll)

		var margin := MarginContainer.new()
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin.add_theme_constant_override("margin_right", 14)
		scroll.add_child(margin)

		_list = VBoxContainer.new()
		_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list.add_theme_constant_override("separation", Widgets.GAP_ROW)
		margin.add_child(_list)
	else:
		_list = VBoxContainer.new()
		_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list.add_theme_constant_override("separation", Widgets.GAP_ROW)
		add_child(_list)

	_refresh_list()


func _build_category_bar() -> void:
	var categories := _categories()
	if categories.size() < 2:
		return

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 44)
	add_child(scroll)

	var bar := HBoxContainer.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_constant_override("separation", 4)
	scroll.add_child(bar)

	for category in categories:
		var name := String(category)
		var button := Button.new()
		button.text = name
		button.toggle_mode = true
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button.button_pressed = name == _category
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 38)
		button.pressed.connect(func(): _select_category(name))
		bar.add_child(button)
		_category_buttons[name] = button


func _select_category(category: String) -> void:
	if category == _category:
		return
	_category = category
	for name in _category_buttons:
		_category_buttons[name].button_pressed = name == category
	_refresh_list()


## Rebuild only the list, never the search field, so the caret is never lost.
func _refresh_list() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	_reset_card_columns()

	var shown := 0
	for broad in _visible_broads():
		_build_broad(broad, _card_host(shown))
		shown += 1

	if shown == 0:
		Widgets.muted_text(_list, "No powers match.", _ctx.palette)


func _visible_broads() -> Array:
	var rules: AlternityRules = _ctx.rules
	var out: Array = []
	for broad in rules.fx.get_broad_skills_for_character(_ctx.doc.raw()):
		if String(broad.get("category", "")) != _category:
			continue
		if not _matches(broad):
			continue
		out.append(broad)
	out.sort_custom(func(a, b): return String(a.get("name", "")) < String(b.get("name", "")))
	return out


## A broad matches if it or any of its powers matches, so searching for a power
## still shows the school it lives under.
func _matches(broad: Dictionary) -> bool:
	if _query.strip_edges().is_empty():
		return true
	var needle := _query.to_lower()
	if String(broad.get("name", "")).to_lower().contains(needle):
		return true
	for specialty in _specialties(String(broad.get("name", ""))):
		if String(specialty.get("name", "")).to_lower().contains(needle):
			return true
	return false


func _specialties(broad_name: String) -> Array:
	var rules: AlternityRules = _ctx.rules
	return rules.fx.get_specialty_skills_for_broad_and_character(broad_name, _ctx.doc.raw())


## Where the next card goes.
##
## One card per row across a 1900px window puts a skill's name at one edge and
## its buy button at the other -- the row is wide, not readable. Two columns of
## cards keep each one at a width you can take in, and use the height that a
## single stacked list leaves empty.
func _card_host(_index: int) -> Container:
	return _list


func _reset_card_columns() -> void:
	_card_columns.clear()


## Rebuild only the power list rows without tearing down search or school tabs.
func refresh_skills() -> void:
	_refresh_list()


func _build_broad(broad: Dictionary, host: Container) -> void:
	var rules: AlternityRules = _ctx.rules
	var raw := _ctx.doc.raw()
	var broad_name := String(broad.get("name", ""))
	var owned: bool = rules.fx.is_fx_skill_selected(raw, broad_name)

	_build_row(host, broad, true)

	if not owned:
		return

	for specialty in _specialties(broad_name):
		_build_row(host, specialty, false)


func _build_row(parent: Container, skill: Dictionary, is_broad: bool) -> void:
	var rules: AlternityRules = _ctx.rules
	var doc := _ctx.doc
	var palette := _ctx.palette
	var raw := doc.raw()
	var skill_name := String(skill.get("name", ""))
	var rank: int = rules.fx.fx_skill_rank(raw, skill_name)
	var owned: bool = rules.fx.is_fx_skill_selected(raw, skill_name)
	var max_rank := 1 if is_broad else AlternityRules.MAX_SPECIALTY_RANK

	if is_broad:
		if parent.get_child_count() > 0:
			var sep := Control.new()
			sep.custom_minimum_size = Vector2(0, 4)
			parent.add_child(sep)

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", Widgets.GAP_ROW)
		parent.add_child(row)

		var check_btn := _make_flat_icon_btn(
			ICON_CHECK if owned else ICON_UNCHECK,
			Vector2(32, 32),
			"Drop school" if owned else "Take school"
		)
		check_btn.add_theme_color_override("icon_normal_color", palette.accent if owned else Color(palette.muted, 0.4))
		check_btn.pressed.connect(func():
			if not owned:
				doc.apply([CharacterDoc.FX], func(c): rules.fx.add_fx_skill(c, skill_name))
			else:
				doc.apply([CharacterDoc.FX], func(c): rules.fx.remove_fx_skill(c, skill_name))
			change_requested.emit()
		)
		row.add_child(check_btn)

		var name_lbl := Label.new()
		name_lbl.text = skill_name
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.add_theme_color_override("font_color", palette.text)
		name_lbl.add_theme_font_size_override("font_size", Widgets.FONT_BODY)
		row.add_child(name_lbl)

		var detail_btn := _make_flat_icon_btn(
			ICON_QUESTION,
			Vector2(34, 34),
			"View details for %s" % skill_name
		)
		detail_btn.add_theme_color_override("icon_normal_color", Color(palette.muted, 0.8))
		detail_btn.pressed.connect(func(): detail_requested.emit(skill))
		row.add_child(detail_btn)

		var slack := Control.new()
		slack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slack)

		var cost_lbl := Label.new()
		cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cost_lbl.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
		if owned:
			var spent: int = rules.fx.fx_skill_cost_for_rank(raw, skill_name, 1)
			cost_lbl.text = "Spent %d" % spent
			cost_lbl.add_theme_color_override("font_color", palette.accent)
		else:
			var cost: int = rules.fx.fx_skill_cost_for_rank(raw, skill_name, 1)
			cost_lbl.text = "Cost %d" % cost
			cost_lbl.add_theme_color_override("font_color", palette.muted)
		row.add_child(cost_lbl)
		return

	# Specialty power row
	var item_container := VBoxContainer.new()
	item_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_container.add_theme_constant_override("separation", 2)
	parent.add_child(item_container)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", Widgets.GAP_ROW)
	item_container.add_child(row)

	var indent := Control.new()
	indent.custom_minimum_size = Vector2(18, 0)
	row.add_child(indent)

	var check_btn := _make_flat_icon_btn(
		ICON_CHECK if rank > 0 else ICON_UNCHECK,
		Vector2(32, 32),
		"Sell power" if rank > 0 else "Buy power"
	)
	check_btn.add_theme_color_override("icon_normal_color", palette.accent if rank > 0 else Color(palette.muted, 0.4))
	check_btn.pressed.connect(func():
		if rank <= 0:
			doc.apply([CharacterDoc.FX], func(c): rules.fx.add_fx_skill(c, skill_name))
		else:
			doc.apply([CharacterDoc.FX], func(c): rules.fx.remove_fx_skill(c, skill_name))
		change_requested.emit()
	)
	row.add_child(check_btn)

	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.custom_minimum_size = Vector2(130, 0)
	name_box.add_theme_constant_override("separation", 0)
	row.add_child(name_box)

	var name_lbl := Label.new()
	name_lbl.text = skill_name
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_color_override("font_color", palette.text)
	name_lbl.add_theme_font_size_override("font_size", Widgets.FONT_BODY)
	name_box.add_child(name_lbl)

	var next_cost: int = rules.fx.fx_skill_cost(raw, skill_name)
	var sub_text := ""
	if rank >= max_rank:
		sub_text = "At maximum rank"
	elif rank <= 0:
		sub_text = "Buy %d SP" % next_cost
	else:
		sub_text = "Next rank %d SP" % next_cost

	var sub_lbl := Label.new()
	sub_lbl.text = sub_text
	sub_lbl.add_theme_color_override("font_color", palette.muted)
	sub_lbl.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	name_box.add_child(sub_lbl)

	var minus_btn := _make_flat_icon_btn(ICON_MINUS, Vector2(34, 34), "Reduce rank")
	minus_btn.disabled = (rank <= 0)
	minus_btn.pressed.connect(func():
		doc.apply([CharacterDoc.FX], func(c): rules.fx.remove_fx_skill(c, skill_name))
		change_requested.emit()
	)
	row.add_child(minus_btn)

	var plus_btn := _make_flat_icon_btn(ICON_PLUS, Vector2(34, 34), "Increase rank")
	plus_btn.disabled = (rank >= max_rank)
	plus_btn.pressed.connect(func():
		doc.apply([CharacterDoc.FX], func(c): rules.fx.add_fx_skill(c, skill_name))
		change_requested.emit()
	)
	row.add_child(plus_btn)

	var detail_btn := _make_flat_icon_btn(
		ICON_QUESTION,
		Vector2(34, 34),
		"View details for %s" % skill_name
	)
	detail_btn.add_theme_color_override("icon_normal_color", Color(palette.muted, 0.8))
	detail_btn.pressed.connect(func(): detail_requested.emit(skill))
	row.add_child(detail_btn)

	var slack := Control.new()
	slack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slack)

	var rank_lbl := Label.new()
	rank_lbl.text = "Rank %d" % rank
	rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank_lbl.custom_minimum_size = Vector2(48, 0)
	rank_lbl.add_theme_color_override("font_color", palette.text if rank > 0 else palette.muted)
	rank_lbl.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	row.add_child(rank_lbl)

	if owned and rules.fx.can_fx_skill_be_permanent(skill_name):
		var perm_row := HBoxContainer.new()
		perm_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_container.add_child(perm_row)

		var perm_indent := Control.new()
		perm_indent.custom_minimum_size = Vector2(50, 0)
		perm_row.add_child(perm_indent)

		var permanent: bool = rules.fx.is_fx_skill_permanent(raw, skill_name)
		var toggle := Widgets.toggle_row(perm_row, "Always active (reserves pool)", permanent, palette, true)
		toggle.toggled.connect(func(pressed: bool):
			doc.apply([CharacterDoc.FX], func(c):
				rules.fx.set_fx_skill_permanent(c, skill_name, pressed))
			change_requested.emit()
		)
