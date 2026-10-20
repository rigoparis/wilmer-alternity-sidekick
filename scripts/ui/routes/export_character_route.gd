extends RouteScene
##
## Hand a hero to the player as something they can keep: a .json file saved
## wherever they choose, or the same JSON as text on the clipboard.
##
## Its own route rather than a single Share tap. The old button copied to the
## clipboard and opened a save dialog in one go, so on a phone the only thing
## the player saw was a system picker with no word of what it was for. Choosing
## explicitly is what lets someone back up every hero before reinstalling.
##
## Saving goes through the system picker. On Android that is the Storage Access
## Framework, which writes wherever the player points it -- Downloads, Documents,
## a cloud drive -- without the app holding any storage permission at all.
## Plain .json rather than an extension of our own: Android picks the file type
## from the extension, and an unknown one becomes a generic binary that some
## pickers and chat apps refuse to offer back for import.
##
## Closes with null; there is nothing for the caller to apply.
##

var _palette: ThemePalette
var _store: CharacterStore
var _doc: CharacterDoc

var _panel: PanelContainer
var _status: Label


## props: palette, store, doc.
func configure(props: Dictionary) -> void:
	_palette = props.get("palette", ThemePalette.new())
	_store = props.get("store", null)
	_doc = props.get("doc", null)
	_build()


func preferred_presentation() -> int:
	return UiRouter.Presentation.DIALOG


func title() -> String:
	return "Export Hero"


func _hero_name() -> String:
	return _doc.get_hero_name() if _doc != null else "this hero"


## The dialog's height is its content's. ModalHost sizes a dialog from the
## route's minimum and otherwise hands it 70% of the screen, which for four
## controls is mostly empty panel.
func _get_minimum_size() -> Vector2:
	if _panel == null:
		return Vector2.ZERO
	return Vector2(0, _panel.get_combined_minimum_size().y)


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface, _palette.border, 8, true))
	add_child(panel)
	_panel = panel
	# Wrapped text is only as tall as it is once it has a width, so measure
	# again after each layout pass. Settles in one step: the width never changes.
	resized.connect(func(): _remeasure.call_deferred())

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	margin.add_child(box)

	var heading := Label.new()
	heading.text = "Export %s" % _hero_name()
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size = Vector2(1, 0)
	heading.add_theme_color_override("font_color", _palette.text)
	heading.add_theme_font_size_override("font_size", Widgets.FONT_SECTION_TITLE)
	box.add_child(heading)

	Widgets.muted_text(
		box,
		"Save the hero as a file you can keep, back up or send to a friend, or copy it as text to paste into a chat. Import Hero takes either one back.",
		_palette
	)

	var save := Button.new()
	save.name = "SaveFileButton"
	save.text = "Save as file..."
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.custom_minimum_size = Vector2(0, 42)
	save.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
	save.pressed.connect(_on_save_file)
	box.add_child(save)

	var copy := Button.new()
	copy.name = "CopyTextButton"
	copy.text = "Copy as text"
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.custom_minimum_size = Vector2(0, 42)
	copy.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.border, 6))
	copy.pressed.connect(_on_copy)
	box.add_child(copy)

	_status = Widgets.text(box, "", _palette, Widgets.FONT_CAPTION, _palette.muted)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(1, 0)

	var done := Button.new()
	done.text = "Done"
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.custom_minimum_size = Vector2(0, 42)
	done.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.border, 6))
	done.pressed.connect(func(): close(null))
	box.add_child(done)


var _measured_height: float = -1.0


func _remeasure() -> void:
	var height := _get_minimum_size().y
	if is_equal_approx(height, _measured_height):
		return
	_measured_height = height
	update_minimum_size()
	size_hint_changed.emit()


func _export_text() -> String:
	if _store == null or _doc == null:
		return ""
	return _store.export_json(_doc)


func _on_copy() -> void:
	var text := _export_text()
	if text.is_empty():
		return
	DisplayServer.clipboard_set(text)
	_report("Copied. Paste it somewhere outside the app, such as a chat or a note, to keep it.", false)


func _on_save_file() -> void:
	var text := _export_text()
	if text.is_empty():
		return
	var file_name := CharacterStore.file_name_for(_doc)

	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		var error := DisplayServer.file_dialog_show(
			"Save Hero",
			OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS),
			file_name,
			false,
			DisplayServer.FILE_DIALOG_MODE_SAVE_FILE,
			PackedStringArray(["*.json;Character files;application/json"]),
			_on_file_chosen.bind(text)
		)
		if error == OK:
			return

	# No system picker (a headless or web build). Downloads is the one folder a
	# person can reliably find from outside the app.
	var downloads := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if downloads.is_empty():
		_report("This device has no file picker. Use Copy as text instead.", true)
		return
	var path := downloads.path_join(file_name)
	if _write(path, text):
		_report("Saved to %s" % path, false)
	else:
		_report("Could not save to %s. Use Copy as text instead." % downloads, true)


func _on_file_chosen(accepted: bool, paths: PackedStringArray, _filter: int, text: String) -> void:
	if not is_instance_valid(self) or is_closed():
		return
	if not accepted or paths.is_empty():
		return
	var chosen := String(paths[0])
	if _write(chosen, text):
		_report("Saved %s" % display_name(chosen), false)
	else:
		_report("Could not write %s" % display_name(chosen), true)


## A readable name for what the picker returned. On Android that is a content
## URI such as content://.../document/primary%3ADownload%2FHero.json, whose
## last segment means nothing to a player until it is decoded.
static func display_name(path: String) -> String:
	return path.uri_decode().get_file()


func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


func _report(message: String, is_error: bool) -> void:
	if _status == null or not is_instance_valid(_status):
		return
	_status.text = message
	_status.add_theme_color_override("font_color", _palette.warning if is_error else _palette.accent)
	_remeasure.call_deferred()
