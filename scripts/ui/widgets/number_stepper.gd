class_name NumberStepper
extends HBoxContainer
##
## Minus / value / plus, clamped to a range.
##
## Used for anything bought a point at a time -- ability scores, cybertech
## tolerance, mutation points. Kept as a control rather than a builder function
## because it holds state (the current value) and has behaviour (clamping,
## disabling its buttons at the limits), which a stateless helper cannot.
##
## Emits only when the value actually changes, so a caller can connect it
## straight to a document mutation without filtering no-op presses.
##

signal value_changed(new_value: int)

var _label: Label
var _value_label: Label
var _minus: Button
var _plus: Button
var _palette: ThemePalette

var _value: int = 0
var _minimum: int = 0
var _maximum: int = 0
var _step: int = 1


func _init() -> void:
	add_theme_constant_override("separation", Widgets.GAP_ROW)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func setup(
	palette: ThemePalette,
	label_text: String,
	initial: int,
	minimum: int,
	maximum: int,
	step: int = 1
) -> void:
	_palette = palette
	_minimum = minimum
	_maximum = maxi(minimum, maximum)
	_step = maxi(1, step)
	_value = clampi(initial, _minimum, _maximum)

	_label = Label.new()
	_label.text = label_text
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(1, 0)
	_label.add_theme_color_override("font_color", palette.muted)
	_label.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	add_child(_label)

	_minus = _make_button("-")
	add_child(_minus)

	_value_label = Label.new()
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Wide enough for three digits, so the row does not jump as the value grows.
	_value_label.custom_minimum_size = Vector2(44, 0)
	_value_label.add_theme_color_override("font_color", palette.text)
	_value_label.add_theme_font_size_override("font_size", Widgets.FONT_SECTION_TITLE)
	add_child(_value_label)

	_plus = _make_button("+")
	add_child(_plus)

	_minus.pressed.connect(func(): _apply(_value - _step))
	_plus.pressed.connect(func(): _apply(_value + _step))

	_refresh()


func value() -> int:
	return _value


## Set the value without emitting, for syncing to an external change.
func set_value_silent(new_value: int) -> void:
	_value = clampi(new_value, _minimum, _maximum)
	_refresh()


## Adjust the permitted range, re-clamping the current value into it.
##
## Needed because the limits are not fixed: a profession minimum or a mutation
## can move an ability range under a stepper that is already on screen.
func set_range(minimum: int, maximum: int) -> void:
	_minimum = minimum
	_maximum = maxi(minimum, maximum)
	var clamped := clampi(_value, _minimum, _maximum)
	if clamped != _value:
		_value = clamped
		value_changed.emit(_value)
	_refresh()


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	# 42px square: a touch target, not a desktop-sized spinner arrow.
	button.custom_minimum_size = Vector2(42, 42)
	button.add_theme_font_size_override("font_size", Widgets.FONT_SECTION_TITLE)
	return button


func _apply(candidate: int) -> void:
	var clamped := clampi(candidate, _minimum, _maximum)
	if clamped == _value:
		return
	_value = clamped
	_refresh()
	value_changed.emit(_value)


func _refresh() -> void:
	if _value_label == null:
		return
	_value_label.text = str(_value)
	# Disabling at the limits makes the boundary visible rather than leaving a
	# button that looks live but does nothing.
	_minus.disabled = _value <= _minimum
	_plus.disabled = _value >= _maximum
