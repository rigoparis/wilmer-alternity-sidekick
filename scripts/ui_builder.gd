class_name UIBuilder
extends RefCounted

static func add_columns(parent: Container, left_ratio := 0.5) -> Array:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = left_ratio
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = max(0.1, 1.0 - left_ratio)
	right.add_theme_constant_override("separation", 10)
	row.add_child(right)
	return [left, right]

static func add_section(parent: Container, title: String, theme_manager: Object = null, default_surface: Color = Color(0.1, 0.12, 0.16), default_border: Color = Color(0.2, 0.25, 0.3), default_text: Color = Color(0.9, 0.92, 0.95)) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var c_surface = default_surface
	var c_border = default_border
	var c_text = default_text
	if theme_manager and theme_manager.has_method("get_theme_color"):
		c_surface = theme_manager.get_theme_color("color_surface")
		c_border = theme_manager.get_theme_color("color_border")
		c_text = theme_manager.get_theme_color("color_text")

	panel.add_theme_stylebox_override("panel", flat_style(c_surface, c_border, 8, true))
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	if not title.is_empty():
		var label := Label.new()
		label.text = title
		label.add_theme_color_override("font_color", c_text)
		label.add_theme_font_size_override("font_size", 18)
		box.add_child(label)
	return box

static func add_form_cell(parent: Container, label_text: String, control: Control, default_muted: Color = Color(0.5, 0.55, 0.6)) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)
	add_field(box, label_text, control, default_muted)

static func add_field(parent: Container, label_text: String, control: Control, muted_color: Color) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", muted_color)
	label.add_theme_font_size_override("font_size", 12)
	parent.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size = Vector2(0, 42)
	parent.add_child(control)

static func flat_style(background: Color, border: Color, radius: int, shadow: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_corner_radius_all(radius)
	if border.a > 0.0:
		style.border_color = border
		style.set_border_width_all(1)
	else:
		style.set_border_width_all(0)
	if shadow:
		style.shadow_color = Color(0, 0, 0, 0.4)
		style.shadow_size = 8
		style.shadow_offset = Vector2(0, 4)
	return style

static func tab_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := flat_style(background, border, radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

static func add_text(parent: Container, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(1, 0)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

static func add_rich_text(parent: Container, bbcode_text: String, font_size: int, color: Color) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = bbcode_text
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(1, 0)
	label.add_theme_color_override("default_color", color)
	label.add_theme_font_size_override("normal_font_size", font_size)
	parent.add_child(label)
	return label

static func add_indented_text(parent: VBoxContainer, text: String, font_size: int, color: Color) -> Label:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(16, 0)
	row.add_child(spacer)
	var label := add_text(row, text, font_size, color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

## Wraps the portion of `text` before the first ":" in [b]…[/b] BBCode so that
## skill / specialty names like "Stamina:" or "Computer Science - Hacking:" render bold.
static func format_note_with_bold_prefix(text: String) -> String:
	var colon_pos := text.find(":")
	if colon_pos <= 0:
		return text
	var prefix := text.left(colon_pos)
	# Only bold short prefixes that look like a skill/specialty name (≤ 45 chars).
	# Prose sentences with a mid-sentence colon will have a much longer prefix.
	if prefix.length() > 45:
		return text
	return "[b]%s[/b]%s" % [prefix, text.substr(colon_pos)]

static func add_rich_note(parent: VBoxContainer, text: String, font_size: int, color: Color) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = format_note_with_bold_prefix(text)
	label.fit_content = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("default_color", color)
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_font_size_override("bold_font_size", font_size)
	label.add_theme_font_size_override("italics_font_size", font_size)
	parent.add_child(label)
	return label

static func add_subheading(parent: VBoxContainer, text: String, text_color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_constant_override("margin_top", 4)
	label.add_theme_constant_override("margin_bottom", 2)
	parent.add_child(label)
	return label

static func number_input_value(text: String, fallback: int, minimum: int, maximum: int) -> int:
	var stripped := text.strip_edges()
	if stripped.is_empty() or not stripped.is_valid_int():
		return clampi(fallback, minimum, maximum)
	return clampi(int(stripped), minimum, maximum)

static func format_number(value: float) -> String:
	if is_equal_approx(value, float(int(value))):
		return str(int(value))
	return "%.2f" % value

static func add_thin_separator(parent: VBoxContainer, border_color: Color) -> void:
	var separator := HSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = border_color
	sep_style.thickness = 1
	separator.add_theme_stylebox_override("separator", sep_style)
	parent.add_child(separator)
