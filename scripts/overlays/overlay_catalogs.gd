class_name OverlayCatalogs
extends Control
const UIBuilder := preload("res://scripts/ui_builder.gd")

var panel: PanelContainer
var body: VBoxContainer
var scroll: ScrollContainer
var main_ui: Node
var title_label: Label
var search_edit: LineEdit

func build(parent: Node, p_main_ui: Node, color_surface: Color, color_border: Color, color_text: Color, title_text: String) -> void:
	main_ui = p_main_ui

	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(self)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			visible = false
	)
	add_child(shade)

	var overlay_margin := MarginContainer.new()
	overlay_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_margin.add_theme_constant_override("margin_left", 12)
	overlay_margin.add_theme_constant_override("margin_right", 12)
	overlay_margin.add_theme_constant_override("margin_top", 12)
	overlay_margin.add_theme_constant_override("margin_bottom", 12)
	add_child(overlay_margin)

	var center := CenterContainer.new()
	overlay_margin.add_child(center)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 0)
	panel.add_theme_stylebox_override("panel", UIBuilder.flat_style(color_surface, color_border, 8))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	title_label = Label.new()
	title_label.text = title_text
	title_label.add_theme_color_override("font_color", color_text)
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)

	search_edit = LineEdit.new()
	search_edit.placeholder_text = "Search..."
	search_edit.custom_minimum_size = Vector2(0, 42)
	box.add_child(search_edit)

	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)

	var scroll_margin := MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_theme_constant_override("margin_right", 12)
	scroll.add_child(scroll_margin)

	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	scroll_margin.add_child(body)

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 42)
	close.pressed.connect(func(): visible = false)
	box.add_child(close)
