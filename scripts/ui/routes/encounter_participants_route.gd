extends RouteScene
## Selection stays local until confirmed: unopened NPCs never enter round state.
var _choices: Array = []
var _selected: Dictionary = {}
var _confirm: Button

func title() -> String:
	return "Who is joining combat?"

func preferred_presentation() -> int:
	return UiRouter.Presentation.PAGE

func configure(props: Dictionary) -> void:
	var palette: ThemePalette = props.get("palette", ThemePalette.new())
	_choices = props.get("participants", [])
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", Widgets.flat_style(palette.surface, palette.border, 8, true))
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var content_margin := MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_right", 8)
	scroll.add_child(content_margin)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 16)
	content_margin.add_child(box)
	var title_label := Widgets.text(box, title(), palette, Widgets.FONT_SECTION_TITLE)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.custom_minimum_size.x = 1
	var note := Widgets.text(box, "Select players and NPCs. Only selected NPCs will be revealed to the table; their sheets stay private.", palette)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 1
	for entry in _choices:
		var id := String(entry.get("id", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		PortraitView.add_to(row, String(entry.get("portrait", "")), String(entry.get("name", "")), palette, 48)
		var pick := CheckBox.new()
		pick.text = "%s%s" % [String(entry.get("name", "")), " (NPC)" if entry.get("kind") == ActionRound.KIND_NPC else ""]
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		pick.clip_text = true
		pick.button_pressed = entry.get("kind") != ActionRound.KIND_NPC
		_selected[id] = pick.button_pressed
		pick.toggled.connect(func(on: bool):
			_selected[id] = on
			_update_confirm())
		row.add_child(pick)
	_confirm = Button.new()
	_confirm.text = "Start encounter"
	_confirm.custom_minimum_size.y = 44
	_confirm.pressed.connect(func():
		var selected: Array = []
		for entry in _choices:
			if bool(_selected.get(entry["id"], false)):
				selected.append(entry)
		close(selected))
	box.add_child(_confirm)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size.y = 42
	cancel.pressed.connect(func(): close())
	box.add_child(cancel)
	_update_confirm()
	_touch_pass(box)

func _update_confirm() -> void:
	if _confirm != null:
		_confirm.disabled = not _selected.values().has(true)

func _touch_pass(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_touch_pass(child)
