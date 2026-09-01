extends RouteScene
##
## Reference text for one skill or FX power.
##
## Presented as a SHEET: sized to content, bottom-anchored on a phone. That
## choice exists because this content varies enormously -- some powers are two
## lines, others run a full page -- and a fixed-height panel would either crop
## the long ones or float over the short ones.
##
## Read-only, so it closes with null; nothing here changes the character.
##

const Detail := preload("res://scripts/core/skill_detail.gd")
const DetailView := preload("res://scripts/ui/skill_detail_view.gd")

var _palette: ThemePalette
var _title: String = ""


## props: palette, and either `detail` (a SkillDetail) or `data` (a raw record).
func configure(props: Dictionary) -> void:
	_palette = props.get("palette", ThemePalette.new())

	var detail = props.get("detail", null)
	if detail == null:
		detail = Detail.from_data(props.get("data", {}))
	_title = detail.title if not detail.title.is_empty() else String(props.get("title", "Details"))

	_build(detail)


func preferred_presentation() -> int:
	return UiRouter.Presentation.SHEET


func title() -> String:
	return _title


func _build(detail) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface, _palette.border, 8))
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.PAD_PANEL)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", Widgets.GAP_ROW)
	margin.add_child(box)

	var heading := Label.new()
	heading.text = _title
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size = Vector2(1, 0)
	heading.add_theme_color_override("font_color", _palette.text)
	heading.add_theme_font_size_override("font_size", 20)
	box.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	# Right margin so the scrollbar does not sit on top of the text.
	var scroll_margin := MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_theme_constant_override("margin_right", Widgets.PAD_PANEL)
	scroll.add_child(scroll_margin)

	var view = DetailView.new()
	scroll_margin.add_child(view)
	view.render(detail, _palette)

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(func(): close_route())
	box.add_child(close)


## Named to avoid shadowing RouteScene.close() from inside the lambda above.
func close_route() -> void:
	close(null)
