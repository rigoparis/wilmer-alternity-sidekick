class_name DamageTrack
extends VBoxContainer
##
## A damage track as a row of boxes you tap, the way it is marked on paper.
##
## Replaces the NumberStepper this tab briefly used. A stepper is the wrong
## control for damage: it shows one number and hides the shape of the track, so
## you cannot see at a glance how much room is left before the next threshold --
## which is the entire reason the tracker is on screen during play. Boxes show
## capacity and consumption in the same glance, and reach any value in one tap
## instead of "- - - -".
##
## Tapping box N fills through N. Tapping the last filled box clears it, so
## stepping down by one stays a single tap.
##

## The player changed the track. Carries the new used count.
signal value_changed(value: int)

## Beyond this, boxes stop being readable on a phone and become a bar instead.
const MAX_BOXES := 40

const BOX_SIZE := Vector2(24, 24)

var _palette: ThemePalette
var _label: Label
var _boxes: HFlowContainer
var _used: int = 0
var _total: int = 0


func setup(palette: ThemePalette, title: String, used: int, total: int) -> void:
	_palette = palette
	_used = used
	_total = total
	add_theme_constant_override("separation", Widgets.GAP_TIGHT)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(header)

	var name_label := Label.new()
	name_label.text = title
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", palette.text)
	name_label.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	header.add_child(name_label)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	header.add_child(_label)

	_boxes = HFlowContainer.new()
	_boxes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boxes.add_theme_constant_override("h_separation", Widgets.GAP_TIGHT)
	_boxes.add_theme_constant_override("v_separation", Widgets.GAP_TIGHT)
	add_child(_boxes)

	_render()


## Redraw without rebuilding, so tapping a box does not cost a tab rebuild.
## How many points are currently marked off.
##
## Exists so a tab syncing a tracker to the document can tell whether anything
## actually moved without reading into the widget's own state.
func value() -> int:
	return _used


func set_value(used: int) -> void:
	_used = clampi(used, 0, maxi(_total, used))
	_render()


func _render() -> void:
	_label.text = "%d / %d" % [_used, _total]
	# Full is the state you need to notice, so it is the one that changes colour.
	_label.add_theme_color_override(
		"font_color",
		_palette.warning if (_used >= _total and _total > 0) else _palette.muted
	)

	# A track long enough to stop fitting stops being boxes. Better a readable
	# bar than four rows of squares nobody can count.
	if _total > MAX_BOXES:
		if _boxes.get_child_count() == 1 and _boxes.get_child(0) is ProgressBar:
			var existing_bar := _boxes.get_child(0) as ProgressBar
			existing_bar.max_value = maxi(1, _total)
			existing_bar.value = _used
			return

		for child in _boxes.get_children():
			_boxes.remove_child(child)
			child.queue_free()

		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = maxi(1, _total)
		bar.value = _used
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 14)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_theme_stylebox_override(
			"background", Widgets.flat_style(_palette.surface_soft, _palette.border, 4)
		)
		bar.add_theme_stylebox_override(
			"fill", Widgets.flat_style(_palette.warning, Color(0, 0, 0, 0), 4)
		)
		_boxes.add_child(bar)
		return

	# Fast path: update existing box buttons in place without destroying and re-instantiating.
	if _boxes.get_child_count() == _total:
		var can_reuse := true
		for child in _boxes.get_children():
			if not (child is Button):
				can_reuse = false
				break
		if can_reuse:
			for index in range(_total):
				var box := _boxes.get_child(index) as Button
				_apply_box_style(box, index < _used)
			return

	for child in _boxes.get_children():
		_boxes.remove_child(child)
		child.queue_free()

	for index in range(_total):
		_boxes.add_child(_make_box(index))


func _apply_box_style(box: Button, filled: bool) -> void:
	var fill := _palette.warning if filled else _palette.surface_soft
	var edge := _palette.warning if filled else _palette.border
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		box.add_theme_stylebox_override(state, Widgets.flat_style(fill, edge, 4))


func _make_box(index: int) -> Button:
	var box := Button.new()
	box.custom_minimum_size = BOX_SIZE
	box.focus_mode = Control.FOCUS_NONE
	box.tooltip_text = "%d" % (index + 1)
	_apply_box_style(box, index < _used)

	box.pressed.connect(func():
		# Tapping the box that is currently the last filled one clears it, so
		# undoing a hit is one tap rather than a trip to a stepper.
		var target := index if (index == _used - 1) else index + 1
		set_value(target)
		value_changed.emit(_used))
	return box
