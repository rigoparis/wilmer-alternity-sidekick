extends RouteScene
##
## Setting the difficulty of a check, in steps.
##
## The same dial serves both people who can turn it: the GM ruling on a player's
## request, and a player rolling with no table open. Deliberately one route
## rather than two, because it is one decision -- how much harder or easier than
## ordinary this is -- and two would drift.
##
## Steps, not a difficulty ladder. Alternity has no printed Easy/Hard table to
## map onto; the GM adds or subtracts steps as the situation warrants, and the
## step total picks the situation die. Inventing a ladder here would put words in
## the rulebook's mouth.
##
## Closes with {step, reason}, or null if cancelled.
##

const Check := preload("res://scripts/core/session/skill_check.gd")

var _palette: ThemePalette
var _rules: AlternityRules
var _check: SkillCheck
var _note: String = ""
var _title: String = "How hard is it?"
var _confirm_text: String = "Set"

var _stepper: NumberStepper
var _reason_field: LineEdit
var _preview: Label


func configure(props: Dictionary) -> void:
	_palette = props.get("palette", ThemePalette.new())
	_rules = props.get("rules", null)
	_note = String(props.get("note", ""))
	_title = String(props.get("title", _title))
	_confirm_text = String(props.get("confirm_text", _confirm_text))

	var data = props.get("check", {})
	_check = Check.from_dict(data) if typeof(data) == TYPE_DICTIONARY else Check.new()
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
	heading.add_theme_color_override("font_color", _palette.accent)
	heading.add_theme_font_size_override("font_size", Widgets.FONT_SECTION_TITLE)
	box.add_child(heading)

	# What is being attempted, and what the hero brings to it. A GM ruling
	# without the score in front of them is guessing.
	var what := Widgets.text(box, _check.skill_label, _palette, Widgets.FONT_SUBHEADING, _palette.accent)
	what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	what.custom_minimum_size = Vector2(1, 0)

	var score := Widgets.muted_text(
		box,
		"Score %d / %d / %d   -   their own modifiers %+d" % [
			_check.ordinary, _check.good, _check.amazing, _check.player_step
		],
		_palette,
		Widgets.FONT_CAPTION
	)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if not _check.step_breakdown.is_empty():
		var bd_items: Array = []
		for item in _check.step_breakdown:
			var item_step: int = AlternityNum.as_int(item.get("step", 0))
			bd_items.append("%s (%+d)" % [String(item.get("source", "")), item_step])
		var bd_label := Widgets.muted_text(box, "Carried modifiers: " + ", ".join(bd_items), _palette, Widgets.FONT_CAPTION)
		bd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bd_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bd_label.custom_minimum_size = Vector2(1, 0)

	if not _note.is_empty():
		var note := Widgets.muted_text(box, _note, _palette, Widgets.FONT_CAPTION)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(1, 0)

	_stepper = NumberStepper.new()
	_stepper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_stepper)
	_stepper.setup(_palette, "Steps", _check.gm_step, Check.MIN_STEP, Check.MAX_STEP, 1, 0, true)
	_stepper.value_changed.connect(func(_v: int): _refresh_preview())

	# The die the step total actually produces. Steps are the input, but the die
	# is what lands on the tray, and showing it stops the dial being abstract.
	_preview = Widgets.text(box, "", _palette, Widgets.FONT_SUBHEADING)
	_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_refresh_preview()

	_reason_field = LineEdit.new()
	_reason_field.text = _check.reason
	_reason_field.placeholder_text = "Why? (optional)"
	_reason_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reason_field.custom_minimum_size = Vector2(0, 40)
	_reason_field.text_submitted.connect(func(_t: String): _submit())
	box.add_child(_reason_field)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", Widgets.GAP_ROW)
	box.add_child(actions)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.custom_minimum_size = Vector2(0, 42)
	cancel.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.border, 6))
	cancel.pressed.connect(func(): close(null))
	actions.add_child(cancel)

	var confirm := Button.new()
	confirm.name = "ConfirmButton"
	confirm.text = _confirm_text
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.custom_minimum_size = Vector2(0, 42)
	confirm.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
	confirm.pressed.connect(_submit)
	actions.add_child(confirm)


func _refresh_preview() -> void:
	if _preview == null:
		return
	var total := _check.player_step + _stepper.value()
	var die := _rules.action_step_die(total) if _rules != null else "+d0"
	var wording := "ordinary"
	if _stepper.value() > 0:
		wording = "harder"
	elif _stepper.value() < 0:
		wording = "easier"
	_preview.text = "d20 %s   (%s, %d steps in total)" % [die, wording, total]


## The step the GM chose, for a caller that wants it without waiting.
func chosen_step() -> int:
	return 0 if _stepper == null else _stepper.value()


func _submit() -> void:
	close({
		"step": _stepper.value(),
		"reason": _reason_field.text.strip_edges(),
		"check_id": _check.check_id,
	})
