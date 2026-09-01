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
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.add_theme_font_size_override("font_size", FONT_DETAIL)

	# The switch shows the state; the row does not. Inheriting the theme's
	# Button styles filled an enabled toggle with the accent colour and left
	# pale text on top of it, which was both loud and hard to read.
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		toggle.add_theme_stylebox_override(state, flat_style(palette.surface_soft, palette.border, 6))
	for state in ["font_color", "font_pressed_color", "font_hover_color", "font_focus_color"]:
		toggle.add_theme_color_override(state, palette.text)

	parent.add_child(toggle)
	return toggle


## Label and control on one line, with the label close to what it labels.
##
## Stacked label-above-control wastes vertical space and, for short controls like
## a quantity stepper, pushes the label so far from its input that they stop
## reading as a pair.
static func field_row(parent: Container, label_text: String, control: Control, palette: ThemePalette) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", GAP_ROW)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", palette.muted)
	label.add_theme_font_size_override("font_size", FONT_CAPTION)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


## A budget as a bar plus its numbers.
##
## Restores what the old UI showed for skill points, broad skills and perk/flaw
## counts. A bare "12 / 30" makes you do the arithmetic; the bar is the thing
## you actually read mid-build to see whether you have room.
static func progress_metric(
	parent: Container,
	label_text: String,
	used: int,
	total: int,
	palette: ThemePalette,
	over_is_bad: bool = true
) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", GAP_TIGHT)
	parent.add_child(box)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(header)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", palette.muted)
	name_label.add_theme_font_size_override("font_size", FONT_CAPTION)
	header.add_child(name_label)

	var over := used > total
	var value_label := Label.new()
	value_label.text = "%d / %d" % [used, total]
	value_label.add_theme_color_override(
		"font_color",
		palette.warning if (over and over_is_bad) else palette.text
	)
	value_label.add_theme_font_size_override("font_size", FONT_DETAIL)
	header.add_child(value_label)

	var bar := ProgressBar.new()
	bar.min_value = 0
	# Clamp so an over-spend fills the bar rather than overflowing it; the
	# number beside it is what reports by how much.
	bar.max_value = maxi(1, maxi(total, used))
	bar.value = used
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.add_theme_stylebox_override("background", flat_style(palette.surface_soft, Color(0, 0, 0, 0), 4))
	bar.add_theme_stylebox_override(
		"fill",
		flat_style(palette.warning if (over and over_is_bad) else palette.accent, Color(0, 0, 0, 0), 4)
	)
	box.add_child(bar)
	return box



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


## The margin a screen's content sits inside, chosen by width.
##
## A phone wants every pixel; a desktop window wants the content to stop short of
## the frame. Both were previously PAD_PANEL, which is why the desktop layout
## read as a phone screen stretched sideways.
static func page_margin(is_wide: bool) -> int:
	return 24 if is_wide else PAD_PANEL


## The readable width a page's content is capped at on a wide screen.
##
## Not a phone-width strip -- that wastes a desktop window -- but not the full
## 1900px either, because a single column of that width is unreadable. Tabs that
## can use more space should split into columns rather than widen further.
const CONTENT_MAX_WIDTH := 1100.0


## A screen's scrollable content column: margins, a width cap, and centring.
##
## Returns the VBox to fill. Every screen built its own scroll/margin/column
## sandwich by hand, each with slightly different padding.
static func page_column(parent: Container, is_wide: bool) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := page_margin(is_wide)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, pad)
	scroll.add_child(margin)

	# On a wide window the column is centred inside spacers rather than pinned
	# left, so a maximised desktop window does not leave content hugging one edge.
	var host: Container = margin
	if is_wide:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin.add_child(row)
		row.add_child(_spacer())
		var capped := VBoxContainer.new()
		capped.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		capped.custom_minimum_size = Vector2(0, 0)
		capped.size_flags_stretch_ratio = 6.0
		row.add_child(capped)
		row.add_child(_spacer())
		host = capped

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", GAP_SECTION)
	host.add_child(column)
	return column


static func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 1.0
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


## A collapsible titled section.
##
## FoldableContainer is built in as of Godot 4.5, so this is the engine's
## accordion rather than a Button wired to a VBox's visibility. Returns the box
## to fill.
static func accordion(
	parent: Container,
	title: String,
	palette: ThemePalette,
	folded: bool = true
) -> VBoxContainer:
	var fold := FoldableContainer.new()
	fold.title = title
	fold.folded = folded
	fold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fold.add_theme_color_override("title_font_color", palette.text)
	fold.add_theme_font_size_override("title_font_size", FONT_SUBHEADING)
	fold.add_theme_stylebox_override("panel", flat_style(palette.surface, palette.border, 8))
	for state in ["title_panel", "title_hover_panel", "title_collapsed_panel"]:
		fold.add_theme_stylebox_override(state, flat_style(palette.surface_soft, palette.border, 8))
	parent.add_child(fold)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, PAD_PANEL)
	fold.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", GAP_ROW)
	margin.add_child(box)
	return box


## A button whose label says what it does and what it costs.
##
## "+1  2" was the old label for "raise this rank by one, for two skill points",
## which reads as two unrelated numbers. Price goes after an en dash with its
## unit attached, so the button is legible without knowing the convention.
static func cost_button(action: String, cost: int, unit: String = "SP") -> Button:
	var button := Button.new()
	button.text = "%s - %d %s" % [action, cost, unit] if cost > 0 else action
	button.custom_minimum_size = Vector2(0, 36)
	button.clip_text = true
	return button
