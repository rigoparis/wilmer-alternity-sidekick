extends RouteScene
##
## A searchable catalog you pick several things from, then confirm.
##
## Deliberately generic: perks, flaws, mutations, achievements and equipment are
## all "filter a long list, choose some, apply them". The old UI had four
## near-identical catalog overlays, each with its own filter member, its own
## refresh function and its own row builder.
##
## Two changes from those:
##
##   * Multi-select. Adding three perks at character creation used to mean
##     opening the catalog three times, because picking one closed it.
##   * A live budget in the header. The cost of what you have selected updates
##     as you pick, so affordability is visible while choosing -- previously you
##     had to close the catalog to find out.
##
## Full-screen on a phone, which is what makes room for that header. It closes
## with an Array of chosen ids, or null if cancelled.
##

var _palette: ThemePalette
var _heading: String = "Catalog"
var _entries: Array = []

## Called with the currently selected ids; returns the header text.
var _budget_fn: Callable = Callable()

var _selected: Dictionary = {}
var _query: String = ""

var _budget_label: Label
var _list: VBoxContainer
var _confirm: Button
var _empty_note: Label


## props:
##   palette      ThemePalette
##   title        String
##   entries      Array of { id, name, summary, meta, taken, disabled, reason }
##   budget_fn    Callable(Array selected_ids) -> String, optional
func configure(props: Dictionary) -> void:
	_palette = props.get("palette", ThemePalette.new())
	_heading = String(props.get("title", _heading))
	_entries = props.get("entries", [])
	if props.has("budget_fn") and props["budget_fn"] is Callable:
		_budget_fn = props["budget_fn"]
	_build()


func preferred_presentation() -> int:
	return UiRouter.Presentation.PAGE


func title() -> String:
	return _heading


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface, _palette.border, 8))
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.PAD_PANEL)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", Widgets.GAP_ROW)
	margin.add_child(box)

	var heading := Label.new()
	heading.text = _heading
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", _palette.text)
	heading.add_theme_font_size_override("font_size", 20)
	box.add_child(heading)

	_budget_label = Label.new()
	_budget_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_budget_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_budget_label.custom_minimum_size = Vector2(1, 0)
	_budget_label.add_theme_color_override("font_color", _palette.accent)
	_budget_label.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	box.add_child(_budget_label)

	var search := SearchField.new()
	box.add_child(search)
	search.setup(_palette, "Search...")
	search.query_changed.connect(func(query: String):
		_query = query
		_refresh_list())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	# A right margin keeps the scrollbar from sitting on top of the text, which
	# is the problem the old overlays worked around with symmetric margins.
	var list_margin := MarginContainer.new()
	list_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_margin.add_theme_constant_override("margin_right", Widgets.PAD_PANEL)
	scroll.add_child(list_margin)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", Widgets.GAP_ROW)
	list_margin.add_child(_list)

	_empty_note = Widgets.muted_text(box, "Nothing matches that search.", _palette)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", Widgets.GAP_ROW)
	box.add_child(actions)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.custom_minimum_size = Vector2(0, 44)
	cancel.pressed.connect(func(): close(null))
	actions.add_child(cancel)

	_confirm = Button.new()
	_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm.custom_minimum_size = Vector2(0, 44)
	_confirm.pressed.connect(func(): close(_selected_ids()))
	actions.add_child(_confirm)

	_refresh_list()
	_refresh_budget()


func _selected_ids() -> Array:
	var ids: Array = []
	for entry in _entries:
		var id := String(entry.get("id", ""))
		if _selected.has(id):
			ids.append(id)
	return ids


func _matches(entry: Dictionary) -> bool:
	if _query.strip_edges().is_empty():
		return true
	var needle := _query.to_lower()
	for field in ["name", "summary", "meta"]:
		if String(entry.get(field, "")).to_lower().contains(needle):
			return true
	return false


func _refresh_list() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	var shown := 0
	for entry in _entries:
		if not _matches(entry):
			continue
		shown += 1
		_build_row(entry)

	if _empty_note != null:
		_empty_note.visible = shown == 0


func _build_row(entry: Dictionary) -> void:
	var id := String(entry.get("id", ""))
	var taken := bool(entry.get("taken", false))
	var disabled := bool(entry.get("disabled", false)) or taken

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var outline := _palette.accent if _selected.has(id) else _palette.border
	panel.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface_soft, outline, 6))
	_list.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.GAP_ROW)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(header)

	var name_label := Label.new()
	name_label.text = String(entry.get("name", ""))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(1, 0)
	name_label.add_theme_color_override("font_color", _palette.muted if disabled else _palette.text)
	name_label.add_theme_font_size_override("font_size", Widgets.FONT_SUBHEADING)
	header.add_child(name_label)

	var meta := String(entry.get("meta", ""))
	if not meta.is_empty():
		var meta_label := Label.new()
		meta_label.text = meta
		meta_label.add_theme_color_override("font_color", _palette.accent)
		meta_label.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
		header.add_child(meta_label)

	var summary := String(entry.get("summary", ""))
	if not summary.is_empty():
		Widgets.muted_text(box, summary, _palette, Widgets.FONT_CAPTION)

	var reason := String(entry.get("reason", ""))
	if taken:
		Widgets.muted_text(box, "Already taken.", _palette, Widgets.FONT_CAPTION)
	elif disabled and not reason.is_empty():
		Widgets.muted_text(box, reason, _palette, Widgets.FONT_CAPTION)

	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.button_pressed = _selected.has(id)
	toggle.disabled = disabled
	toggle.text = "Selected" if _selected.has(id) else "Select"
	toggle.custom_minimum_size = Vector2(0, 40)
	toggle.toggled.connect(func(pressed: bool):
		if pressed:
			_selected[id] = true
		else:
			_selected.erase(id)
		toggle.text = "Selected" if pressed else "Select"
		panel.add_theme_stylebox_override(
			"panel",
			Widgets.flat_style(_palette.surface_soft, _palette.accent if pressed else _palette.border, 6)
		)
		_refresh_budget())
	box.add_child(toggle)


## Recompute the header from the current selection. This is the whole point of
## the full-screen layout: the cost of what you are choosing is visible while
## you choose it.
func _refresh_budget() -> void:
	var count := _selected.size()
	_confirm.text = "Add %d" % count if count > 0 else "Done"
	_confirm.disabled = false

	if _budget_label == null:
		return
	if _budget_fn.is_valid():
		_budget_label.text = String(_budget_fn.call(_selected_ids()))
	else:
		_budget_label.text = "%d selected" % count
