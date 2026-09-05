extends RouteScene
##
## Pick a colour theme. A genuine dialog: small, quick, interrupting.
##
## Applies immediately on selection rather than on confirm, because the whole
## point is seeing the theme, and a preview you have to accept is worse than one
## you can simply change back.
##

var _palette: ThemePalette
var _service: Node


func configure(props: Dictionary) -> void:
	_palette = props.get("palette", ThemePalette.new())
	_service = props.get("service", null)
	_build()


func preferred_presentation() -> int:
	return UiRouter.Presentation.DIALOG


func title() -> String:
	return "Theme"


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
	box.add_theme_constant_override("separation", Widgets.GAP_ROW)
	margin.add_child(box)

	var heading := Label.new()
	heading.text = title()
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size = Vector2(1, 0)
	heading.add_theme_color_override("font_color", _palette.accent)
	heading.add_theme_font_size_override("font_size", Widgets.FONT_SECTION_TITLE)
	box.add_child(heading)

	if _service == null:
		Widgets.muted_text(box, "Theme service unavailable.", _palette)
	else:
		var current: int = _service.current_theme_index
		var names: Array = _service.theme_names
		var buttons: Array[Button] = []
		for i in names.size():
			var button := Button.new()
			button.text = String(names[i])
			button.toggle_mode = true
			var is_active: bool = (i == current)
			button.button_pressed = is_active
			button.custom_minimum_size = Vector2(0, 44)
			button.add_theme_stylebox_override(
				"normal",
				Widgets.flat_style(_palette.surface_soft, _palette.accent if is_active else _palette.border, 6)
			)
			button.add_theme_color_override("font_color", _palette.accent if is_active else _palette.text)
			var index: int = i
			button.pressed.connect(func():
				_service.set_theme(index)
				for b_idx in buttons.size():
					var b := buttons[b_idx]
					var active := (b_idx == index)
					b.button_pressed = active
					b.add_theme_stylebox_override(
						"normal",
						Widgets.flat_style(_palette.surface_soft, _palette.accent if active else _palette.border, 6)
					)
					b.add_theme_color_override("font_color", _palette.accent if active else _palette.text)
			)
			buttons.append(button)
			box.add_child(button)

	var done := Button.new()
	done.text = "Close"
	done.custom_minimum_size = Vector2(0, 44)
	done.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.border, 6))
	done.pressed.connect(func(): close(null))
	box.add_child(done)
