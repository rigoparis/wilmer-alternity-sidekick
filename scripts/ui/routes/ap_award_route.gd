extends RouteScene
##
## How many achievement points, and what for.
##
## Both halves matter. The amount is the mechanical effect; the reason is what
## makes the log worth reading a month later, which is why CampaignSession
## stores it on the award and on the event rather than treating it as a comment.
##
## Closes with {"amount": int, "reason": String}, or null when cancelled.
##
## The same route serves a single seat and the whole table -- the caller decides
## which by what it does with the answer -- and an outright correction, where
## `mode` is MODE_SET and the number is a new total rather than an increment.
##

const MODE_AWARD := "award"
const MODE_SET := "set"

## The four reasons CampaignSession records. Custom is last because it is the
## one that needs typing.
const REASONS := [
	CampaignSession.AP_REASON_COMPLETION,
	CampaignSession.AP_REASON_ROLEPLAYING,
	CampaignSession.AP_REASON_HEROISM,
	CampaignSession.AP_REASON_CUSTOM,
]

var _palette: ThemePalette
var _title: String = "Award achievement points"
var _message: String = ""
var _mode: String = MODE_AWARD
var _initial: int = 1
var _maximum: int = 99

var _stepper: NumberStepper
var _reason: String = CampaignSession.AP_REASON_COMPLETION
var _custom_field: LineEdit
var _reason_buttons: Dictionary = {}


func configure(props: Dictionary) -> void:
	_palette = props.get("palette", ThemePalette.new())
	_mode = String(props.get("mode", MODE_AWARD))
	_initial = AlternityNum.as_int(props.get("amount", 1 if _mode == MODE_AWARD else 0))
	_maximum = AlternityNum.as_int(props.get("maximum", 99), 99)
	_title = String(props.get("title", "Award achievement points" if _mode == MODE_AWARD else "Set achievement points"))
	_message = String(props.get("message", ""))
	if _mode == MODE_SET:
		_reason = "GM Adjustment"
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

	_stepper = NumberStepper.new()
	box.add_child(_stepper)
	# Zero is allowed on purpose in SET mode: correcting a seat back to nothing
	# is a legitimate adjustment. In AWARD mode it is the harmless no-op.
	_stepper.setup(_palette, "Points", _initial, 0, _maximum, 1, 0, true)

	if _mode == MODE_AWARD:
		_build_reasons(box)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", Widgets.GAP_ROW)
	box.add_child(actions)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.custom_minimum_size = Vector2(0, 42)
	cancel.pressed.connect(func(): close(null))
	actions.add_child(cancel)

	var confirm := Button.new()
	confirm.name = "ConfirmButton"
	confirm.text = "Award" if _mode == MODE_AWARD else "Set"
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.custom_minimum_size = Vector2(0, 42)
	confirm.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
	confirm.pressed.connect(_submit)
	actions.add_child(confirm)


func _build_reasons(parent: Container) -> void:
	Widgets.muted_text(parent, "Reason", _palette, Widgets.FONT_CAPTION)

	var grid := VBoxContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	parent.add_child(grid)

	for reason in REASONS:
		var button := Button.new()
		button.text = String(reason)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 38)
		button.pressed.connect(_select_reason.bind(String(reason)))
		grid.add_child(button)
		_reason_buttons[String(reason)] = button

	# Only meaningful once Custom is chosen, so it starts hidden rather than
	# sitting there inert above four buttons.
	_custom_field = LineEdit.new()
	_custom_field.placeholder_text = "What was it for?"
	_custom_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_custom_field.custom_minimum_size = Vector2(0, 40)
	_custom_field.visible = false
	parent.add_child(_custom_field)

	_select_reason(_reason)


func _select_reason(reason: String) -> void:
	_reason = reason
	for id in _reason_buttons:
		var button: Button = _reason_buttons[id]
		var chosen: bool = id == reason
		button.remove_theme_stylebox_override("normal")
		button.add_theme_stylebox_override(
			"normal",
			Widgets.flat_style(_palette.surface_soft, _palette.accent if chosen else _palette.border, 6)
		)
		button.add_theme_color_override("font_color", _palette.accent if chosen else _palette.text)
	if _custom_field != null:
		_custom_field.visible = reason == CampaignSession.AP_REASON_CUSTOM


## The reason as it will be recorded, with a typed custom reason replacing the
## placeholder label.
func chosen_reason() -> String:
	if _reason != CampaignSession.AP_REASON_CUSTOM or _custom_field == null:
		return _reason
	var typed := _custom_field.text.strip_edges()
	return typed if not typed.is_empty() else CampaignSession.AP_REASON_CUSTOM


func _submit() -> void:
	close({
		"amount": _stepper.value(),
		"reason": chosen_reason(),
		"mode": _mode,
	})
