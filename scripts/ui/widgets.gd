class_name Widgets
extends RefCounted
##
## Stateless builders for the pieces every tab draws.
##
## Successor to UIBuilder, with one deliberate difference: everything takes a
## ThemePalette instead of loose colours. UIBuilder.add_section() already
## accepted a theme source as its third argument and *no caller ever passed
## one* -- all 46 sites pass null plus three explicit colours, pulled from
## main.gd members that were themselves copies. Threading a palette removes the
## single largest source of colour coupling in the UI.
##
## Only genuinely shared pieces belong here. Measuring the old "shared widget
## block" found it was roughly 40% shared and 60% single-owner code that had
## drifted in by convention -- the four _add_form_* helpers were Equipment-only,
## and _add_tracker_row, _add_compact_abilities, _add_stat_pair_row,
## _add_labeled_value* and _add_ability_summary_cell were Summary-only. Those
## belong to their tab, not to a library.
##
## Anything with behaviour or internal state is a control instead: see
## SearchField and NumberStepper. These functions only assemble nodes.
##

## Standard spacing, so tabs do not each invent their own.
const GAP_TIGHT := 4
const GAP_ROW := 8
const GAP_SECTION := 10
const PAD_PANEL := 12

const FONT_SECTION_TITLE := 18
const FONT_SUBHEADING := 16
const FONT_BODY := 14
const FONT_DETAIL := 13
const FONT_CAPTION := 12


## A titled panel. The container returned is where content goes.
static func section(parent: Container, title: String, palette: ThemePalette) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", flat_style(palette.surface, palette.border, 8, true))
	parent.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, PAD_PANEL)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", GAP_ROW)
	margin.add_child(box)

	if not title.is_empty():
		var label := Label.new()
		label.text = title
		label.add_theme_color_override("font_color", palette.text)
		label.add_theme_font_size_override("font_size", FONT_SECTION_TITLE)
		box.add_child(label)
	return box


## Wrapping body text.
##
## The custom_minimum_size.x of 1 is load-bearing on narrow screens: without a
## non-zero width a Label reports its full unwrapped text as its minimum and
## stretches the container off the side of a 390px viewport instead of wrapping.
static func text(parent: Container, content: String, palette: ThemePalette, font_size: int = FONT_BODY, color: Color = Color.TRANSPARENT) -> Label:
	var label := Label.new()
	label.text = content
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(1, 0)
	label.add_theme_color_override("font_color", color if color.a > 0.0 else palette.text)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


static func muted_text(parent: Container, content: String, palette: ThemePalette, font_size: int = FONT_DETAIL) -> Label:
	return text(parent, content, palette, font_size, palette.muted)


static func subheading(parent: Container, content: String, palette: ThemePalette) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_color_override("font_color", palette.text)
	label.add_theme_font_size_override("font_size", FONT_SUBHEADING)
	parent.add_child(label)
	return label


static func rich_text(parent: Container, bbcode: String, palette: ThemePalette, font_size: int = FONT_DETAIL) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = bbcode
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(1, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("default_color", palette.text)
	for size_key in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		label.add_theme_font_size_override(size_key, font_size)
	parent.add_child(label)
	return label


## Name on the left, value on the right. The most-used widget in the old UI --
## 23 call sites across seven tabs.
static func metric(parent: Container, name: String, value: String, palette: ThemePalette) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", GAP_ROW)
	parent.add_child(row)

	var name_label := Label.new()
	name_label.text = name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(1, 0)
	name_label.add_theme_color_override("font_color", palette.muted)
	name_label.add_theme_font_size_override("font_size", FONT_DETAIL)
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", palette.text)
	value_label.add_theme_font_size_override("font_size", FONT_BODY)
	row.add_child(value_label)
	return row


## One cell of a data table. Header cells are accented and non-wrapping.
static func table_cell(parent: GridContainer, content: String, palette: ThemePalette, header: bool = false, alignment: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = content
	label.horizontal_alignment = alignment
	label.add_theme_color_override("font_color", palette.accent if header else palette.text)
	label.add_theme_font_size_override("font_size", FONT_CAPTION if header else FONT_DETAIL)
	if not header:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(1, 0)
	parent.add_child(label)
	return label


## A labelled on/off row.
##
## CheckButton rather than CheckBox: ThemeService deliberately strips the
## CheckBox styleboxes so the old custom check artwork can show through, which
## would leave a plain CheckBox here looking unstyled. The switch is also a
## larger touch target.
static func toggle_row(parent: Container, label_text: String, pressed: bool, palette: ThemePalette) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = label_text
	toggle.button_pressed = pressed
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.custom_minimum_size = Vector2(0, 44)
	toggle.add_theme_color_override("font_color", palette.text)
	toggle.add_theme_color_override("font_pressed_color", palette.text)
	toggle.add_theme_color_override("font_hover_color", palette.text)
	toggle.add_theme_font_size_override("font_size", FONT_DETAIL)
	parent.add_child(toggle)
	return toggle


static func separator(parent: Container, palette: ThemePalette) -> HSeparator:
	var line := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = palette.border
	style.thickness = 1
	line.add_theme_stylebox_override("separator", style)
	parent.add_child(line)
	return line


## Two side-by-side columns, for wide layouts. `left_ratio` splits the width.
static func columns(parent: Container, left_ratio: float = 0.5) -> Array:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", PAD_PANEL)
	parent.add_child(row)

	var built: Array = []
	for ratio in [left_ratio, maxf(0.1, 1.0 - left_ratio)]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.size_flags_stretch_ratio = ratio
		column.add_theme_constant_override("separation", GAP_SECTION)
		row.add_child(column)
		built.append(column)
	return built


## A tinted icon button sized for touch.
##
## 46x46 is deliberate: it clears the ~44px minimum touch target, which matters
## because this app is primarily used on phones.
static func icon_button(icon: Texture2D, palette: ThemePalette, size: Vector2 = Vector2(46, 46)) -> Button:
	var button := Button.new()
	button.icon = icon
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon = true
	button.custom_minimum_size = size
	# Mipmaps plus linear filtering keep the white SVGs crisp when scaled, which
	# is what lets them be tinted per theme rather than shipped per theme.
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for state in ["icon_normal_color", "icon_pressed_color", "icon_hover_color", "icon_focus_color"]:
		button.add_theme_color_override(state, palette.text)
	return button


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


## Format a float without a trailing ".0" when it is whole.
static func format_number(value: float) -> String:
	if is_equal_approx(value, float(int(value))):
		return str(int(value))
	return "%.2f" % value
