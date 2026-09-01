extends RouteScene
##
## Toggle the optional rules a campaign uses.
##
## A PAGE rather than a dialog: each rule carries a paragraph of explanation and
## there are several, so on a phone this needs the full screen. The old UI drew
## it as a centred overlay with 12px side margins, which is what forced the
## scroll-margin workarounds.
##
## Closes with the set of rules that changed, or null if nothing did, so the
## caller only invalidates the sheet when something actually moved.
##

var _palette: ThemePalette
var _rules: AlternityRules
var _character: Dictionary = {}
var _changed: Dictionary = {}
var _confirm_text: String = "Done"


## props: palette, rules, character (the raw dictionary, read-only here).
func configure(props: Dictionary) -> void:
	_palette = props.get("palette", ThemePalette.new())
	_rules = props.get("rules", null)
	_character = props.get("character", {})
	# The new-hero flow relabels this to "Create Hero", since there the button
	# does not just close a settings screen -- it makes the character.
	_confirm_text = String(props.get("confirm_text", _confirm_text))
	_build()


func preferred_presentation() -> int:
	return UiRouter.Presentation.PAGE


func title() -> String:
	return "Optional Rules"


func _build() -> void:
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
	heading.text = title()
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", _palette.text)
	heading.add_theme_font_size_override("font_size", 20)
	box.add_child(heading)

	Widgets.muted_text(
		box,
		"These change how the rules work for this hero. Ask your GM before enabling one.",
		_palette,
		Widgets.FONT_CAPTION
	)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	var scroll_margin := MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_theme_constant_override("margin_right", Widgets.PAD_PANEL)
	scroll.add_child(scroll_margin)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	scroll_margin.add_child(list)

	var enabled: Dictionary = _character.get("optional_rules", {})
	for rule in AlternityRules.OPTIONAL_RULES:
		_build_rule(list, rule, bool(enabled.get(String(rule.get("id", "")), false)))

	var done := Button.new()
	done.text = _confirm_text
	done.custom_minimum_size = Vector2(0, 44)
	done.pressed.connect(func(): close(_changed if not _changed.is_empty() else null))
	box.add_child(done)


func _build_rule(parent: Container, rule: Dictionary, enabled: bool) -> void:
	var rule_id := String(rule.get("id", ""))
	var block := Widgets.section(parent, String(rule.get("name", rule_id)), _palette)

	Widgets.muted_text(block, String(rule.get("summary", "")), _palette, Widgets.FONT_CAPTION)
	Widgets.text(block, String(rule.get("description", "")), _palette, Widgets.FONT_CAPTION)

	var toggle := Widgets.toggle_row(block, "Enabled", enabled, _palette)
	toggle.toggled.connect(func(pressed: bool):
		# Record only the net change: toggling twice leaves nothing to apply.
		if pressed == enabled:
			_changed.erase(rule_id)
		else:
			_changed[rule_id] = pressed)
