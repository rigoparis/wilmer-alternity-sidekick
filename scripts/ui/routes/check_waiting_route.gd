extends RouteScene
##
## Waiting for the GM to set the difficulty of a check.
##
## Displayed on the player's device when an action check has been requested in
## multiplayer. The GM sets the steps (or refuses), which closes this route with
## the ruling. A cancel button lets the player abandon waiting.
##

signal request_cancelled()

const Check := preload("res://scripts/core/session/skill_check.gd")

var _palette: ThemePalette
var _check: SkillCheck
var _title: String = "Waiting for GM..."
var _check_label: Label
var _score_label: Label
var _status_label: Label
var _on_instance_cb: Callable


func configure(props: Dictionary) -> void:
	_palette = props.get("palette", ThemePalette.new())
	_title = String(props.get("title", _title))

	var data = props.get("check", {})
	_check = Check.from_dict(data) if typeof(data) == TYPE_DICTIONARY else Check.new()

	_on_instance_cb = props.get("on_instance", Callable())
	if _on_instance_cb.is_valid():
		_on_instance_cb.call(self)

	_build()


func preferred_presentation() -> int:
	return UiRouter.Presentation.DIALOG


func title() -> String:
	return _title


func notify_ruled(ruling: SkillCheck) -> void:
	close({"ruled": true, "check": ruling})


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

	# Skill being attempted
	_check_label = Widgets.text(box, _check.skill_label, _palette, Widgets.FONT_SUBHEADING, _palette.accent)
	_check_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_check_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_check_label.custom_minimum_size = Vector2(1, 0)

	_score_label = Widgets.muted_text(
		box,
		"Score %d / %d / %d   -   your modifiers %+d" % [
			_check.ordinary, _check.good, _check.amazing, _check.player_step
		],
		_palette,
		Widgets.FONT_CAPTION
	)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_status_label = Widgets.muted_text(
		box,
		"Waiting for the GM to set the situation difficulty steps...",
		_palette,
		Widgets.FONT_CAPTION
	)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(1, 0)

	var cancel_btn := Button.new()
	cancel_btn.name = "CancelCheckButton"
	cancel_btn.text = "Cancel Request"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.custom_minimum_size = Vector2(0, 42)
	cancel_btn.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.border, 6))
	cancel_btn.pressed.connect(func():
		request_cancelled.emit()
		close({"cancelled": true})
	)
	box.add_child(cancel_btn)
