extends "res://tools/test_harness.gd"
##
## The shared widget vocabulary.
##
## SearchField gets the most attention: it exists to make the old
## focus-restoration dance unnecessary, so the test asserts the field survives
## its results being rebuilt, which is the situation that dance compensated for.
##

const Palette := preload("res://scripts/core/theme_palette.gd")
const W := preload("res://scripts/ui/widgets.gd")
const SearchFieldScript := preload("res://scripts/ui/widgets/search_field.gd")
const StepperScript := preload("res://scripts/ui/widgets/number_stepper.gd")

var _palette


func _init() -> void:
	begin_async("widgets", 400)
	_run.call_deferred()


func _run() -> void:
	_palette = Palette.new()

	_test_builders()
	_test_wrapping_guard()
	await _test_search_field()
	await _test_search_survives_rebuild()
	await _test_stepper()

	finish()


func _host() -> Control:
	var box := VBoxContainer.new()
	root.add_child(box)
	return box


func _test_builders() -> void:
	var box := _host()

	var content := W.section(box, "Abilities", _palette)
	check_true(content != null, "section returns a content container")
	check_true(content is VBoxContainer, "section content is a vertical stack")
	# Panel > Margin > VBox, so the section title lives inside the panel.
	check_true(content.get_parent().get_parent() is PanelContainer, "section wraps content in a panel")
	check_eq(content.get_child_count(), 1, "section adds its title label")

	var untitled := W.section(box, "", _palette)
	check_eq(untitled.get_child_count(), 0, "an untitled section adds no label")

	var row := W.metric(content, "Strength", "12", _palette)
	check_eq(row.get_child_count(), 2, "metric is a name and a value")
	check_eq((row.get_child(1) as Label).text, "12", "metric shows its value")
	check_eq(
		(row.get_child(1) as Label).horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT,
		"metric values are right-aligned"
	)

	var grid := GridContainer.new()
	content.add_child(grid)
	var header := W.table_cell(grid, "Rank", _palette, true)
	var cell := W.table_cell(grid, "3", _palette, false)
	check_eq(header.get_theme_color("font_color"), _palette.accent, "header cells use the accent colour")
	check_eq(cell.get_theme_color("font_color"), _palette.text, "body cells use the text colour")

	var pair := W.columns(content, 0.6)
	check_eq(pair.size(), 2, "columns returns both halves")
	check_true(pair[0].size_flags_stretch_ratio > pair[1].size_flags_stretch_ratio, "the ratio is applied")

	check_eq(W.format_number(3.0), "3", "whole floats lose the decimal")
	check_eq(W.format_number(3.25), "3.25", "fractional floats keep it")

	box.queue_free()


## Labels that report their full unwrapped width push the layout off the side of
## a 390px viewport instead of wrapping. Every text builder must guard this.
func _test_wrapping_guard() -> void:
	var box := _host()
	var long := "A rather long line of rules prose that would otherwise stretch its container well past the width of a phone screen."

	var label := W.text(box, long, _palette)
	check_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "body text wraps")
	check_true(label.custom_minimum_size.x > 0.0, "body text declares a non-zero minimum width")

	var muted := W.muted_text(box, long, _palette)
	check_true(muted.custom_minimum_size.x > 0.0, "muted text declares a non-zero minimum width")
	check_eq(muted.get_theme_color("font_color"), _palette.muted, "muted text uses the muted colour")

	var rich := W.rich_text(box, "[b]Bold[/b] then plain", _palette)
	check_true(rich.bbcode_enabled, "rich text has bbcode enabled")
	check_true(rich.fit_content, "rich text sizes to its content")
	check_true(rich.custom_minimum_size.x > 0.0, "rich text declares a non-zero minimum width")

	box.queue_free()


func _test_search_field() -> void:
	var box := _host()
	var field = SearchFieldScript.new()
	box.add_child(field)
	field.debounce_seconds = 0.0
	field.setup(_palette, "Search equipment", "Search", "pistol")
	await process_frame

	check_eq(field.query(), "pistol", "the initial query is applied")

	var seen: Array = []
	field.query_changed.connect(func(q): seen.append(q))

	var edit: LineEdit = null
	for child in field.get_children():
		if child is LineEdit:
			edit = child
	if not check(edit != null, "the field owns a LineEdit"):
		box.queue_free()
		return

	edit.text = "rifle"
	edit.text_changed.emit("rifle")
	check_eq(seen, ["rifle"], "typing emits the new query")

	# set_query is for restoring saved state, so it must stay silent.
	field.set_query("silent")
	check_eq(seen.size(), 1, "set_query does not emit")
	check_eq(field.query(), "silent", "set_query still updates the text")

	field.clear()
	check_eq(field.query(), "", "clear empties the field")
	check_eq(seen.size(), 2, "clear emits once")

	box.queue_free()


## The situation the old _request_search_refresh / _restore_search_focus /
## _focus_line_edit_at trio existed for: refreshing results used to destroy the
## search box, losing focus and caret. Owning the field separately means the
## results can be rebuilt freely and the field is simply never touched.
func _test_search_survives_rebuild() -> void:
	var box := _host()

	var field = SearchFieldScript.new()
	box.add_child(field)
	field.debounce_seconds = 0.0
	field.setup(_palette, "Search", "", "sword")

	var results := VBoxContainer.new()
	box.add_child(results)

	var rebuilds := [0]
	field.query_changed.connect(func(q):
		rebuilds[0] += 1
		for child in results.get_children():
			results.remove_child(child)
			child.queue_free()
		var label := Label.new()
		label.text = "results for %s" % q
		results.add_child(label))

	await process_frame
	var edit: LineEdit = null
	for child in field.get_children():
		if child is LineEdit:
			edit = child
	edit.grab_focus()
	edit.text = "axe"
	edit.text_changed.emit("axe")
	await process_frame

	check_eq(rebuilds[0], 1, "the results rebuilt")
	check_true(is_instance_valid(edit), "the search box was not destroyed by the rebuild")
	check_eq(field.query(), "axe", "the query survives the rebuild")
	check_true(field.get_child_count() > 0, "the field still owns its children")

	box.queue_free()


func _test_stepper() -> void:
	var box := _host()
	var stepper = StepperScript.new()
	box.add_child(stepper)
	stepper.setup(_palette, "Strength", 10, 4, 14)
	await process_frame

	check_eq(stepper.value(), 10, "the initial value is applied")

	var changes: Array = []
	stepper.value_changed.connect(func(v): changes.append(v))

	var minus: Button = null
	var plus: Button = null
	for child in stepper.get_children():
		if child is Button:
			if child.text == "-":
				minus = child
			elif child.text == "+":
				plus = child
	if not check(minus != null and plus != null, "the stepper has both buttons"):
		box.queue_free()
		return

	plus.pressed.emit()
	check_eq(stepper.value(), 11, "plus increments")
	check_eq(changes, [11], "incrementing emits once")

	minus.pressed.emit()
	check_eq(stepper.value(), 10, "minus decrements")

	# Clamping at the ceiling, and no emission for a press that changes nothing.
	stepper.set_value_silent(14)
	check_eq(changes.size(), 2, "set_value_silent does not emit")
	check_true(plus.disabled, "plus is disabled at the maximum")
	plus.pressed.emit()
	check_eq(stepper.value(), 14, "pressing plus at the maximum does nothing")
	check_eq(changes.size(), 2, "a no-op press emits nothing")

	stepper.set_value_silent(4)
	check_true(minus.disabled, "minus is disabled at the minimum")

	# Ranges move under a live stepper when a profession minimum or mutation
	# changes the legal band.
	stepper.set_value_silent(10)
	stepper.set_range(11, 16)
	check_eq(stepper.value(), 11, "narrowing the range re-clamps the value")
	check_true(changes.has(11), "re-clamping reports the change")

	box.queue_free()
