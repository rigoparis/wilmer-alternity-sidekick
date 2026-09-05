extends RouteScene
##
## Choose one skill from the catalogue.
##
## Exists because a GM calling for a check used to type the skill's name into a
## text box. That reads fine on the GM's screen and is useless on the player's:
## a typed string is not a skill, so the player's device cannot look up its score
## or work out the steps the character already carries. Every modifier the hero
## had -- broad-skill bonus, species, mutations, encumbrance, being dazed -- was
## silently dropped, and the check resolved against nothing.
##
## Picking from the catalogue means an id crosses the wire, and the player's
## device computes its own half of the roll from its own character. Which is the
## ownership rule again: the GM says what to roll and how hard, the player's
## device knows what their hero brings to it.
##
## Closes with the chosen skill Dictionary, or null if cancelled.
##

const NO_ABILITY := "All"

var _palette: ThemePalette
var _rules: AlternityRules
var _heading: String = "What should they roll?"

## Skills the GM reaches for most, offered above the search.
var _shortcuts: Array = []

var _query: String = ""
var _ability: String = NO_ABILITY
var _list: VBoxContainer
var _empty_note: Label
var _shortcuts_grid: GridContainer


## props:
##   palette    ThemePalette
##   rules      AlternityRules
##   title      String
##   shortcuts  Array of {skill_id, count}, commonest first
func configure(props: Dictionary) -> void:
	_palette = props.get("palette", ThemePalette.new())
	_rules = props.get("rules")
	_heading = String(props.get("title", _heading))
	var given = props.get("shortcuts", [])
	_shortcuts = given if typeof(given) == TYPE_ARRAY else []
	_build()


func preferred_presentation() -> int:
	return UiRouter.Presentation.PAGE


func title() -> String:
	return _heading


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface, _palette.border, 8, true))
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.PAD_PANEL)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	margin.add_child(column)

	var heading := Widgets.text(column, _heading, _palette, Widgets.FONT_SECTION_TITLE, _palette.accent)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size = Vector2(1, 0)

	_build_shortcuts(column)

	var search := SearchField.new()
	search.name = "SkillSearch"
	column.add_child(search)
	search.setup(_palette, "Search skills")
	search.query_changed.connect(func(text: String):
		_query = text.strip_edges().to_lower()
		_refresh())

	_build_ability_filter(column)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	scroll.add_child(_list)

	_empty_note = Widgets.muted_text(column, "Nothing matches that.", _palette, Widgets.FONT_CAPTION)

	var cancel := Button.new()
	cancel.name = "CancelButton"
	cancel.text = "Cancel"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.custom_minimum_size = Vector2(0, 42)
	cancel.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.border, 6))
	cancel.pressed.connect(func(): close(null))
	column.add_child(cancel)

	_refresh()


## The skills this table checks most.
##
## The whole reason the counter exists: a GM asking for Awareness for the
## fortieth time should not have to walk the catalogue to find it.
func _build_shortcuts(parent: Container) -> void:
	if _shortcuts.is_empty() or _rules == null:
		return

	Widgets.muted_text(parent, "Checked most at this table", _palette, Widgets.FONT_CAPTION)
	_shortcuts_grid = GridContainer.new()
	_shortcuts_grid.columns = 3 if _is_wide() else 2
	_shortcuts_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shortcuts_grid.add_theme_constant_override("h_separation", Widgets.GAP_ROW)
	_shortcuts_grid.add_theme_constant_override("v_separation", Widgets.GAP_ROW)
	parent.add_child(_shortcuts_grid)

	for entry in _shortcuts:
		var skill: Dictionary = _rules.get_skill_by_id(AlternityNum.as_int(entry.get("skill_id", -1), -1))
		if skill.is_empty():
			continue
		var button := Button.new()
		button.text = "%s  (%d)" % [_rules.skill_label(skill), AlternityNum.as_int(entry.get("count", 0))]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 38)
		button.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
		button.pressed.connect(func(): close(skill))
		_shortcuts_grid.add_child(button)

	Widgets.separator(parent, _palette)


func _build_ability_filter(parent: Container) -> void:
	var bar := HBoxContainer.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_constant_override("separation", 4)
	parent.add_child(bar)

	var update_filter_styles := func():
		for child in bar.get_children():
			var btn := child as Button
			if btn == null:
				continue
			var is_active: bool = btn.text == _ability
			btn.button_pressed = is_active
			btn.remove_theme_stylebox_override("normal")
			if is_active:
				btn.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.accent, _palette.accent, 6))
				btn.add_theme_color_override("font_color", _palette.surface)
			else:
				btn.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.border, 6))
				btn.add_theme_color_override("font_color", _palette.text)

	for ability in [NO_ABILITY, "STR", "DEX", "CON", "INT", "WIL", "PER"]:
		var button := Button.new()
		button.text = ability
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 38)
		button.toggle_mode = true
		button.button_pressed = ability == _ability
		button.pressed.connect(func():
			_ability = ability
			update_filter_styles.call()
			_refresh())
		bar.add_child(button)

	update_filter_styles.call()


## Whether there is room for three columns of shortcuts.
##
## configure() runs before the router presents the route, so during the first
## build there is no viewport to measure and asking for one is an error. The
## columns are rebuilt in _ready, which is the first moment the answer is real.
func _is_wide() -> bool:
	if not is_inside_tree():
		return false
	return get_viewport_rect().size.x >= ModalHost.COMPACT_WIDTH


func _ready() -> void:
	if _shortcuts_grid != null:
		_shortcuts_grid.columns = 3 if _is_wide() else 2


func _refresh() -> void:
	if _list == null or _rules == null:
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	var shown := 0
	for broad in _rules.broad_skills:
		if typeof(broad) != TYPE_DICTIONARY:
			continue
		var rows: Array = []
		if _matches(broad):
			rows.append(broad)
		for specialty in _rules.specialty_skills_by_broad_id.get(AlternityNum.as_int(broad.get("id", -1), -1), []):
			if _matches(specialty):
				rows.append(specialty)
		if rows.is_empty():
			continue

		Widgets.muted_text(_list, String(broad.get("name", "")), _palette, Widgets.FONT_CAPTION)
		for skill in rows:
			_build_row(skill)
			shown += 1

	_empty_note.visible = shown == 0


func _matches(skill: Dictionary) -> bool:
	if _ability != NO_ABILITY and String(skill.get("stat", "")) != _ability:
		return false
	if _query.is_empty():
		return true
	return _rules.skill_label(skill).to_lower().contains(_query)


func _build_row(skill: Dictionary) -> void:
	var button := Button.new()
	button.text = _rules.skill_label(skill)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 36)
	button.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.border, 6))
	button.add_theme_stylebox_override("hover", Widgets.flat_style(_palette.surface_soft.lightened(0.1), _palette.accent, 6))
	button.pressed.connect(func(): close(skill))
	_list.add_child(button)
