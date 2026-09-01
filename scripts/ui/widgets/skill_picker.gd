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

var _ctx: SheetContext
var _mode: int = Mode.NORMAL

var _ability := "STR"
var _query := ""

var _ability_bar: HBoxContainer
var _list: VBoxContainer
var _ability_buttons: Dictionary = {}

## Emitted with the skill record when someone asks to read one.
signal detail_requested(skill: Dictionary)


func _init() -> void:
	add_theme_constant_override("separation", Widgets.GAP_ROW)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func setup(context: SheetContext, mode: int) -> void:
	_ctx = context
	_mode = mode
	# Psionics are Will-based, so opening on STR would show an empty list.
	_ability = "WIL" if mode == Mode.PSIONIC else "STR"
	_build()


func _build() -> void:
	for child in get_children():
		remove_child(child)
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
	for name in _ability_buttons:
		_ability_buttons[name].button_pressed = name == ability
	_refresh_list()


## Rebuild only the list, never the search field.
##
## This is what makes the old focus-restoration dance unnecessary: the field is
## a sibling that is never torn down, so the caret is never lost.
func _refresh_list() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	var shown := 0
	for broad in _visible_broads():
		_build_broad(broad)
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


func _specialties(broad: Dictionary) -> Array:
	var rules: AlternityRules = _ctx.rules
	var broad_id := AlternityNum.as_int(broad.get("id", -1), -1)
	var out: Array = rules.specialty_skills_by_broad_id.get(broad_id, [])
	return out


func _build_broad(broad: Dictionary) -> void:
	var rules: AlternityRules = _ctx.rules
	var palette := _ctx.palette
	var raw := _ctx.doc.raw()
	var broad_id := AlternityNum.as_int(broad.get("id", -1), -1)
	var owned: bool = rules.is_skill_selected(raw, broad_id)

	var box := Widgets.section(_list, "", palette)
	_build_row(box, broad, true)

	# Specialties are only useful once the broad is owned, and the rules require
	# it, so listing them beforehand would offer something unbuyable.
	if not owned:
		Widgets.muted_text(box, "Buy the broad skill to unlock its specialties.", palette, Widgets.FONT_CAPTION)
		return

	for specialty in _specialties(broad):
		if not rules.is_entry_available(raw, specialty):
			continue
		_build_row(box, specialty, false)


func _build_row(parent: Container, skill: Dictionary, is_broad: bool) -> void:
	var rules: AlternityRules = _ctx.rules
	var doc := _ctx.doc
	var palette := _ctx.palette
	var raw := doc.raw()

	var skill_id := AlternityNum.as_int(skill.get("id", -1), -1)
	var rank: int = rules.skill_rank(raw, skill_id)
	var max_rank: int = 1 if is_broad else rules.max_skill_rank_for_character(raw)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", Widgets.GAP_ROW)
	parent.add_child(row)

	if not is_broad:
		var indent := Control.new()
		indent.custom_minimum_size = Vector2(Widgets.PAD_PANEL, 0)
		row.add_child(indent)

	# The name is a button so reference text is one tap away.
	var name_button := Button.new()
	name_button.text = String(rules.skill_label(skill))
	name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_button.custom_minimum_size = Vector2(0, 36)
	name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if is_broad:
		name_button.add_theme_color_override("font_color", palette.accent)
	name_button.pressed.connect(func(): detail_requested.emit(skill))
	row.add_child(name_button)

	var score: Dictionary = rules.skill_score(raw, skill)
	var score_label := Label.new()
	score_label.text = "%d  %s" % [
		AlternityNum.as_int(score.get("ordinary", 0)),
		String(score.get("die", "")),
	]
	score_label.add_theme_color_override("font_color", palette.muted)
	score_label.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	row.add_child(score_label)

	var cost: int = rules.skill_cost(raw, skill)
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(96, 36)
	if rank <= 0:
		buy.text = "Buy  %d" % cost
	elif rank >= max_rank:
		buy.text = "Rank %d" % rank
		buy.disabled = true
	else:
		buy.text = "+1  %d" % rules.skill_purchase_cost(raw, skill, rank + 1)
	buy.pressed.connect(func():
		doc.apply(CharacterDoc.ALL, func(c): rules.set_skill_rank(c, skill_id, rank + 1))
		change_requested.emit())
	row.add_child(buy)

	if rank > 0:
		var sell := Button.new()
		sell.text = "-1"
		sell.custom_minimum_size = Vector2(44, 36)
		sell.pressed.connect(func():
			doc.apply(CharacterDoc.ALL, func(c): rules.set_skill_rank(c, skill_id, rank - 1))
			change_requested.emit())
		row.add_child(sell)
