extends RouteScene
##
## Bring in a character shared as JSON: pasted, from the clipboard, or a file.
##
## Closes with the parsed CharacterDoc, or null if cancelled. Parsing happens
## here so the person sees why something failed while the text is still in front
## of them, rather than being dropped back to the list with nothing to fix.
##

var _palette: ThemePalette
var _store: CharacterStore

var _edit: TextEdit
var _status: Label
var _dialog: FileDialog


## props: palette, store.
func configure(props: Dictionary) -> void:
	_palette = props.get("palette", ThemePalette.new())
	_store = props.get("store", null)
	_build()


func preferred_presentation() -> int:
	return UiRouter.Presentation.PAGE


func title() -> String:
	return "Import Hero"


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface, _palette.border, 8, true))
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
	heading.text = title()
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", _palette.accent)
	heading.add_theme_font_size_override("font_size", 20)
	box.add_child(heading)

	Widgets.muted_text(
		box,
		"Paste a shared character, or load one from a file.",
		_palette,
		Widgets.FONT_CAPTION
	)

	_edit = TextEdit.new()
	_edit.placeholder_text = "{\"name\": \"...\"}"
	_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_edit.custom_minimum_size = Vector2(0, 180)
	_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(_edit)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", Widgets.GAP_ROW)
	box.add_child(tools)

	var paste := Button.new()
	paste.text = "Paste from clipboard"
	paste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paste.custom_minimum_size = Vector2(0, 38)
	paste.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.border, 6))
	paste.pressed.connect(_on_paste)
	tools.add_child(paste)

	var browse := Button.new()
	browse.text = "Load from file..."
	browse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browse.custom_minimum_size = Vector2(0, 38)
	browse.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.border, 6))
	browse.pressed.connect(_on_browse)
	tools.add_child(browse)

	_status = Widgets.text(box, "", _palette, Widgets.FONT_CAPTION, _palette.warning)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(1, 0)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", Widgets.GAP_ROW)
	box.add_child(actions)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.custom_minimum_size = Vector2(0, 44)
	cancel.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.border, 6))
	cancel.pressed.connect(func(): close(null))
	actions.add_child(cancel)

	var confirm := Button.new()
	confirm.text = "Import"
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.custom_minimum_size = Vector2(0, 44)
	confirm.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
	confirm.pressed.connect(_on_import)
	actions.add_child(confirm)


func _on_paste() -> void:
	_edit.text = DisplayServer.clipboard_get()
	_report("Pasted %d characters." % _edit.text.length(), false)


func _on_browse() -> void:
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.filters = PackedStringArray(["*.json ; Character files"])
		_dialog.use_native_dialog = true
		_dialog.file_selected.connect(_on_file_selected)
		add_child(_dialog)
	_dialog.popup_centered_ratio(0.8)


func _on_file_selected(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_report("Could not open %s" % path, true)
		return
	_edit.text = file.get_as_text()
	_report("Loaded %s" % path.get_file(), false)


func _on_import() -> void:
	if _store == null:
		_report("No store available.", true)
		return

	var text := _edit.text.strip_edges()
	if text.is_empty():
		_report("Nothing to import yet.", true)
		return

	var doc = _store.import_json(text)
	if doc == null:
		# import_json parses without pushing an engine error, so a bad paste is
		# reported here rather than in the log.
		_report("That does not look like a character file.", true)
		return

	close(doc)


func _report(message: String, is_error: bool) -> void:
	_status.text = message
	_status.add_theme_color_override("font_color", _palette.warning if is_error else _palette.muted)
