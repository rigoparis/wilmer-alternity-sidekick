extends RouteScene
##
## A yes/no question. One of the few things that genuinely is a modal.
##
## Replaces the inline confirm the character list used, where pressing Delete
## put the file into a `deleting_files` dictionary, triggered a global re-render,
## and drew a different pair of buttons inside the same card. That worked but
## made the list stateful and meant a confirmation could be left dangling if
## anything else rebuilt the screen.
##
## Closes with true for confirm and null for cancel, so a caller can write:
##
##     if await router.push(CONFIRM, {...}):
##         store.delete(file_name)
##

var _palette: ThemePalette
var _message: String = ""
var _title: String = "Are you sure?"
var _confirm_text: String = "Confirm"
var _cancel_text: String = "Cancel"
var _destructive: bool = false


func configure(props: Dictionary) -> void:
	_palette = props.get("palette", ThemePalette.new())
	_title = String(props.get("title", _title))
	_message = String(props.get("message", ""))
	_confirm_text = String(props.get("confirm_text", _confirm_text))
	_cancel_text = String(props.get("cancel_text", _cancel_text))
	# Destructive actions get the warning colour, so "Delete" never looks like
	# the safe default.
	_destructive = bool(props.get("destructive", false))
	_build()


func preferred_presentation() -> int:
	return UiRouter.Presentation.DIALOG


func title() -> String:
	return _title


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface, _palette.border, 8, true))
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	margin.add_child(box)

	var heading := Label.new()
	heading.text = _title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size = Vector2(1, 0)
	heading.add_theme_color_override("font_color", _palette.text)
	heading.add_theme_font_size_override("font_size", Widgets.FONT_SECTION_TITLE)
	box.add_child(heading)

	if not _message.is_empty():
		Widgets.muted_text(box, _message, _palette)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", Widgets.GAP_ROW)
	box.add_child(actions)

	var cancel := Button.new()
	cancel.text = _cancel_text
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.custom_minimum_size = Vector2(0, 42)
	cancel.pressed.connect(func(): close(null))
	actions.add_child(cancel)

	var confirm := Button.new()
	confirm.text = _confirm_text
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.custom_minimum_size = Vector2(0, 42)
	if _destructive:
		var accent := _palette.warning
		confirm.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, accent, 6))
		confirm.add_theme_stylebox_override("hover", Widgets.flat_style(_palette.surface_soft.lightened(0.1), accent, 6))
		confirm.add_theme_stylebox_override("pressed", Widgets.flat_style(accent, Color(0, 0, 0, 0), 6))
		confirm.add_theme_color_override("font_color", accent)
	confirm.pressed.connect(func(): close(true))
	actions.add_child(confirm)
