extends RouteScene
##
## Ask for one line of text. The counterpart to ConfirmRoute, which asks for a
## yes.
##
## Exists because naming a campaign and renaming one are the same question asked
## twice, and neither is worth a screen. Closes with the trimmed text, or null
## when cancelled or left empty -- so a caller can write:
##
##     var name = await router.push(TEXT_PROMPT, {...})
##     if name != null:
##         session.display_name = name
##
## Empty is deliberately null rather than "": a person who clears the field and
## presses OK has not chosen a name, and a campaign called "" is unfindable in
## a list.
##

var _palette: ThemePalette
var _title: String = "Enter a name"
var _message: String = ""
var _placeholder: String = ""
var _initial: String = ""
var _confirm_text: String = "OK"
var _cancel_text: String = "Cancel"

var _field: LineEdit


func configure(props: Dictionary) -> void:
	_palette = props.get("palette", ThemePalette.new())
	_title = String(props.get("title", _title))
	_message = String(props.get("message", ""))
	_placeholder = String(props.get("placeholder", ""))
	_initial = String(props.get("text", ""))
	_confirm_text = String(props.get("confirm_text", _confirm_text))
	_cancel_text = String(props.get("cancel_text", _cancel_text))
	_build()


func preferred_presentation() -> int:
	return UiRouter.Presentation.DIALOG


func title() -> String:
	return _title


## The text currently typed, for tests and for a caller that wants to peek.
func current_text() -> String:
	return "" if _field == null else _field.text.strip_edges()


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

	_field = LineEdit.new()
	_field.text = _initial
	_field.placeholder_text = _placeholder
	_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field.custom_minimum_size = Vector2(0, 42)
	# Enter submits, which is what a one-field dialog is for.
	_field.text_submitted.connect(func(_text: String): _submit())
	box.add_child(_field)
	# Deferred: the field is not in the tree yet, and grabbing focus before it
	# is does nothing at all.
	_field.grab_focus.call_deferred()
	_field.select_all.call_deferred()

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
	confirm.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
	confirm.pressed.connect(_submit)
	actions.add_child(confirm)


func _submit() -> void:
	var text := current_text()
	close(null if text.is_empty() else text)
