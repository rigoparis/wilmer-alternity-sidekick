class_name SkillPicker
extends VBoxContainer
##
## Browse broad skills and their specialties, and buy ranks.
##
## One control shared by the Skills and Psionics tabs. In the old UI this was
## _render_skill_picker, a single function parameterised by an `is_psionics`
## boolean that also switched four member variables in pairs
## (active_skill_ability_tab / active_psionic_ability_tab, skill_filter /
## psionic_filter), with the flag propagating down through _refresh_skill_rows
## and _populate_ability_skills into _add_skill_row.
##
## Here the mode is an argument and the state is the control's own, so two
## instances simply have two of everything and nothing has to be kept in pairs.
##

## The tab should persist the character.
signal change_requested

enum Mode {
	## Ordinary skills: everything that is not psionic.
	NORMAL,
	## Psionic broads and their powers.
	PSIONIC,
}

const ABILITIES := ["STR", "DEX", "CON", "INT", "WIL", "PER"]

const ICON_CHECK := preload("res://assets/check-square.svg")
const ICON_UNCHECK := preload("res://assets/check-square-empty.svg")
const ICON_MINUS := preload("res://assets/minus-square.svg")
const ICON_PLUS := preload("res://assets/add-square.svg")
const ICON_QUESTION := preload("res://assets/question-square.svg")

var _ctx: SheetContext
var _mode: int = Mode.NORMAL

var _ability := "STR"
var _query := ""

var _ability_bar: HBoxContainer
var _list: VBoxContainer
var _ability_buttons: Dictionary = {}
var _card_columns: Array[Container] = []

## Emitted with the skill record when someone asks to read one.
signal detail_requested(skill: Dictionary)


func _init() -> void:
	add_theme_constant_override("separation", Widgets.GAP_ROW)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func setup(context: SheetContext, mode: int) -> void:
	_ctx = context
	_mode = mode
	if _mode == Mode.PSIONIC:
		_ability = "WIL"
	elif _ability.is_empty():
		_ability = "STR"
	_build()


## Rebuild only the skill list rows without tearing down search or ability tabs.
func refresh_skills() -> void:
	_refresh_list()


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


func _build() -> void:
	for child in get_children():
		child.hide()
		child.queue_free()

	var search := SearchField.new()
	add_child(search)
	search.setup(_ctx.palette, "Search skills")
	search.set_query(_query)
	search.query_changed.connect(func(query: String):
		_query = query
		_refresh_list())

	# Ability tabs are hidden in psionic mode: every psionic broad is Will-based,
	# so the row would be six buttons with one useful option.
	if _mode == Mode.NORMAL:
		_build_ability_bar()

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


func _build_ability_bar() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 44)
	add_child(scroll)

	_ability_bar = HBoxContainer.new()
	_ability_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ability_bar.add_theme_constant_override("separation", 4)
	scroll.add_child(_ability_bar)

	for ability in ABILITIES:
		var button := Button.new()
		button.text = ability
		button.toggle_mode = true
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button.button_pressed = ability == _ability
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 38)
		button.pressed.connect(func(): _select_ability(ability))
		_ability_bar.add_child(button)
		_ability_buttons[ability] = button


func _select_ability(ability: String) -> void:
	if ability == _ability:
		return
	_ability = ability
	for ability_name in _ability_buttons:
		_ability_buttons[ability_name].button_pressed = ability_name == ability
	_refresh_list()


## Rebuild only the list, never the search field.
##
## This is what makes the old focus-restoration dance unnecessary: the field is
## a sibling that is never torn down, so the caret is never lost.
func _refresh_list() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.hide()
		child.queue_free()

	_reset_card_columns()

	var shown := 0
	for broad in _visible_broads():
		_build_broad(broad, _card_host(shown))
		shown += 1

	if shown == 0:
		Widgets.muted_text(_list, "No skills match.", _ctx.palette)


func _visible_broads() -> Array:
	var rules: AlternityRules = _ctx.rules
	var raw := _ctx.doc.raw()
	var out: Array = []

	for broad in rules.broad_skills:
		if typeof(broad) != TYPE_DICTIONARY:
			continue
		var is_psionic: bool = rules.is_psionic_skill(broad)
		if is_psionic != (_mode == Mode.PSIONIC):
			continue
		if not rules.is_entry_available(raw, broad):
			continue
		if _mode == Mode.NORMAL and String(broad.get("stat", "")) != _ability:
			continue
		if not _matches(broad):
			continue
		out.append(broad)

	out.sort_custom(func(a, b): return String(a.get("name", "")) < String(b.get("name", "")))
	return out


## A broad matches if it or any of its specialties matches, so searching for a
## specialty still shows the broad it lives under.
func _matches(broad: Dictionary) -> bool:
	if _query.strip_edges().is_empty():
		return true
	var needle := _query.to_lower()
	if String(broad.get("name", "")).to_lower().contains(needle):
		return true
	for specialty in _specialties(broad):
		if String(specialty.get("name", "")).to_lower().contains(needle):
			return true
	return false


## The specialties under a broad that this character may actually take.
##
## Filtered, not just listed. The broad above is checked, but a setting can gate
## a single specialty under an ungated broad -- Dark*Matter puts Cryptography
## under Investigate and Forgery under Creativity, both of which every campaign
## has -- so leaving this unfiltered offered Dark*Matter skills in a Core game.
## Nothing errors when that happens; the skill is simply there to buy.
func _specialties(broad: Dictionary) -> Array:
	var rules: AlternityRules = _ctx.rules
	var raw := _ctx.doc.raw()
	var broad_id := AlternityNum.as_int(broad.get("id", -1), -1)
	var out: Array = []
	for specialty in rules.specialty_skills_by_broad_id.get(broad_id, []):
		if rules.is_entry_available(raw, specialty):
			out.append(specialty)
	return out


## Where the next card goes.
##
## One card per row across a 1900px window puts a skill's name at one edge and
## its buy button at the other -- the row is wide, not readable. Two columns of
## cards keep each one at a width you can take in, and use the height that a
## single stacked list leaves empty.
## Single column card host.
func _card_host(_index: int) -> Container:
	return _list


func _reset_card_columns() -> void:
	_card_columns.clear()


func _build_broad(broad: Dictionary, host: Container) -> void:
	var rules: AlternityRules = _ctx.rules
	var raw := _ctx.doc.raw()
	var broad_id := AlternityNum.as_int(broad.get("id", -1), -1)
	var owned: bool = rules.is_skill_selected(raw, broad_id)

	_build_row(host, broad, true)

	if not owned:
		return

	for specialty in _specialties(broad):
		if not rules.is_entry_available(raw, specialty):
			continue
		_build_row(host, specialty, false)


func _build_row(parent: Container, skill: Dictionary, is_broad: bool) -> void:
	var rules: AlternityRules = _ctx.rules
	var doc := _ctx.doc
	var palette := _ctx.palette
	var raw := doc.raw()

	var skill_id := AlternityNum.as_int(skill.get("id", -1), -1)
	var rank: int = rules.skill_rank(raw, skill_id)
	var max_rank: int = 1 if is_broad else rules.max_rank_for_skill(raw, skill_id)

	if is_broad:
		if parent.get_child_count() > 0:
			var sep := Control.new()
			sep.custom_minimum_size = Vector2(0, 4)
			parent.add_child(sep)

		var broad_row := HBoxContainer.new()
		broad_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		broad_row.add_theme_constant_override("separation", Widgets.GAP_ROW)
		parent.add_child(broad_row)

		var broad_check_btn := _make_flat_icon_btn(
			ICON_CHECK if rank > 0 else ICON_UNCHECK,
			Vector2(32, 32),
			"Sell broad skill" if rank > 0 else "Buy broad skill"
		)
		broad_check_btn.add_theme_color_override("icon_normal_color", palette.accent if rank > 0 else Color(palette.muted, 0.4))
		broad_check_btn.pressed.connect(func():
			if rank <= 0:
				doc.apply(CharacterDoc.ALL, func(c): rules.set_skill_rank(c, skill_id, 1))
			else:
				doc.apply(CharacterDoc.ALL, func(c): rules.set_skill_rank(c, skill_id, 0))
			change_requested.emit()
		)
		broad_row.add_child(broad_check_btn)

		var full_label := String(rules.skill_label(skill))
		var broad_name_lbl := Label.new()
		broad_name_lbl.text = full_label
		broad_name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		broad_name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		broad_name_lbl.custom_minimum_size = Vector2(1, 0)
		broad_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		broad_name_lbl.add_theme_color_override("font_color", palette.text)
		broad_name_lbl.add_theme_font_size_override("font_size", Widgets.FONT_BODY)
		broad_row.add_child(broad_name_lbl)

		var broad_detail_btn := _make_flat_icon_btn(
			ICON_QUESTION,
			Vector2(34, 34),
			"View details for %s" % full_label
		)
		broad_detail_btn.add_theme_color_override("icon_normal_color", Color(palette.muted, 0.8))
		broad_detail_btn.pressed.connect(func(): detail_requested.emit(skill))
		broad_row.add_child(broad_detail_btn)

		var cost_lbl := Label.new()
		cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cost_lbl.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
		if rank > 0:
			if rules.is_free_species_skill(raw, skill_id):
				cost_lbl.text = "Free"
			else:
				var spent: int = rules.skill_cost(raw, skill)
				cost_lbl.text = "Spent %d" % spent
			cost_lbl.add_theme_color_override("font_color", palette.accent)
		else:
			if rules.is_free_species_skill(raw, skill_id):
				cost_lbl.text = "Free"
			else:
				var cost: int = rules.skill_cost(raw, skill)
				cost_lbl.text = "Cost %d" % cost
			cost_lbl.add_theme_color_override("font_color", palette.muted)
		broad_row.add_child(cost_lbl)
		return

	# Specialty row
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", Widgets.GAP_ROW)
	parent.add_child(row)

	var indent := Control.new()
	indent.custom_minimum_size = Vector2(18, 0)
	row.add_child(indent)

	var check_btn := _make_flat_icon_btn(
		ICON_CHECK if rank > 0 else ICON_UNCHECK,
		Vector2(32, 32),
		"Sell specialty" if rank > 0 else "Buy specialty"
	)
	check_btn.add_theme_color_override("icon_normal_color", palette.accent if rank > 0 else Color(palette.muted, 0.4))
	check_btn.pressed.connect(func():
		if rank <= 0:
			doc.apply(CharacterDoc.ALL, func(c): rules.set_skill_rank(c, skill_id, 1))
		else:
			doc.apply(CharacterDoc.ALL, func(c): rules.set_skill_rank(c, skill_id, 0))
		change_requested.emit()
	)
	row.add_child(check_btn)

	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.custom_minimum_size = Vector2(1, 0)
	name_box.add_theme_constant_override("separation", 0)
	row.add_child(name_box)

	var name_str := String(skill.get("name", ""))
	var name_lbl := Label.new()
	name_lbl.text = name_str
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_color_override("font_color", palette.text)
	name_lbl.add_theme_font_size_override("font_size", Widgets.FONT_BODY)
	name_box.add_child(name_lbl)

	var next_cost: int = rules.next_skill_rank_cost(raw, skill)
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
		doc.apply(CharacterDoc.ALL, func(c): rules.set_skill_rank(c, skill_id, rank - 1))
		change_requested.emit()
	)
	row.add_child(minus_btn)

	var plus_btn := _make_flat_icon_btn(ICON_PLUS, Vector2(34, 34), "Increase rank")
	plus_btn.disabled = (rank >= max_rank)
	plus_btn.pressed.connect(func():
		doc.apply(CharacterDoc.ALL, func(c): rules.set_skill_rank(c, skill_id, rank + 1))
		change_requested.emit()
	)
	row.add_child(plus_btn)

	var detail_btn := _make_flat_icon_btn(
		ICON_QUESTION,
		Vector2(34, 34),
		"View details for %s" % name_str
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
