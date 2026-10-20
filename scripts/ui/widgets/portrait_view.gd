class_name PortraitView
extends RefCounted

static func add_to(parent: Node, encoded: String, display_name: String, palette: ThemePalette, edge: int = 80) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(edge, edge)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", Widgets.flat_style(palette.surface_soft, palette.border, 8))
	parent.add_child(panel)
	var img := CharacterPortrait.decode(encoded)
	if img != null:
		var view := TextureRect.new()
		view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.generate_mipmaps()
		view.texture = ImageTexture.create_from_image(img)
		view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		panel.add_child(view)
	else:
		var initial := Label.new()
		initial.text = display_name.strip_edges().left(1).to_upper()
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		initial.add_theme_color_override("font_color", palette.accent)
		initial.add_theme_font_size_override("font_size", 28)
		panel.add_child(initial)
	panel.tooltip_text = display_name
	return panel
