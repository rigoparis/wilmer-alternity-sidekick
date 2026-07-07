class_name OverlayOptionalRules
extends Control
const UIBuilder := preload("res://scripts/ui_builder.gd")

var panel: PanelContainer
var body: VBoxContainer
var scroll: ScrollContainer
var main_ui: Node

func build(parent: Node, p_main_ui: Node, color_surface: Color, color_border: Color, color_text: Color) -> void:
	main_ui = p_main_ui

	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(self)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			visible = false
	)
	add_child(dim)

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
	panel.custom_minimum_size = Vector2(300, 400)
	panel.add_theme_stylebox_override("panel", UIBuilder.flat_style(color_surface, color_border, 8))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Optional Rules"
	title.add_theme_color_override("font_color", color_text)
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)

	var scroll_margin := MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_theme_constant_override("margin_right", 8)
	scroll.add_child(scroll_margin)

	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	scroll_margin.add_child(body)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 44)
	close_btn.pressed.connect(func(): visible = false)
	box.add_child(close_btn)
