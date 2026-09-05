extends RouteScene
##
## Toggle the optional rules a campaign uses.
##
## A PAGE rather than a dialog: each rule carries a paragraph of explanation and
## there are several, so on a phone this needs the full screen. The old UI drew
## it as a centred overlay with 12px side margins, which is what forced the
## scroll-margin workarounds.
##
## Closes with {"rules": {id: bool}, "supplements": {id: bool}} carrying only what
## changed, or null if nothing did, so the caller only invalidates the sheet when
## something actually moved.
##
## Rules and supplements sit on the same screen because a GM settles them in the
## same breath -- "we are using the dazed rule and we have Beyond Science on the
## table" -- but they are different questions and the screen says so. A rule
## changes how something already in the app works; a supplement decides whether a
## whole book's worth of content exists at all.
##

var _palette: ThemePalette
var _rules: AlternityRules
var _character: Dictionary = {}
var _changed: Dictionary = {}
var _changed_supplements: Dictionary = {}
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
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size = Vector2(1, 0)
	heading.add_theme_color_override("font_color", _palette.accent)
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

	_build_supplements(list)

	var rules_heading := Widgets.text(list, "Optional rules", _palette, Widgets.FONT_SECTION_TITLE, _palette.accent)
	rules_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_heading.custom_minimum_size = Vector2(1, 0)

	var enabled: Dictionary = _character.get("optional_rules", {})
	for rule in AlternityRules.OPTIONAL_RULES:
		_build_rule(list, rule, bool(enabled.get(String(rule.get("id", "")), false)))

	var done := Button.new()
	done.text = _confirm_text
	done.custom_minimum_size = Vector2(0, 44)
	done.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
	done.pressed.connect(func(): close(_result()))
	box.add_child(done)


func _result():
	if _changed.is_empty() and _changed_supplements.is_empty():
		return null
	return {"rules": _changed, "supplements": _changed_supplements}


## The books on the table, above the rules, because they are the larger question.
##
## A supplement decides whether content exists; an optional rule decides how
## existing content behaves. Turning Beyond Science off removes nineteen FX
## schools from the catalog, which is a much bigger thing to do by accident than
## any single toggle below it.
func _build_supplements(parent: Container) -> void:
	var heading := Widgets.text(parent, "Books in play", _palette, Widgets.FONT_SECTION_TITLE, _palette.accent)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size = Vector2(1, 0)

	for supplement in AlternityRules.SUPPLEMENTS:
		var supplement_id := String(supplement.get("id", ""))
		var enabled: bool = (
			_rules.supplement_enabled(_character, supplement_id) if _rules != null
			else bool(supplement.get("default", false))
		)
		var block := Widgets.section(parent, String(supplement.get("name", supplement_id)), _palette)
		Widgets.muted_text(block, String(supplement.get("summary", "")), _palette, Widgets.FONT_CAPTION)
		Widgets.text(block, String(supplement.get("description", "")), _palette, Widgets.FONT_CAPTION)

		var toggle := Widgets.toggle_row(block, _supplement_state_label(enabled), enabled, _palette)
		toggle.toggled.connect(func(pressed: bool):
			toggle.text = _supplement_state_label(pressed)
			if pressed == enabled:
				_changed_supplements.erase(supplement_id)
			else:
				_changed_supplements[supplement_id] = pressed)


func _supplement_state_label(enabled: bool) -> String:
	return "On the table" if enabled else "Not in play"


func _build_rule(parent: Container, rule: Dictionary, enabled: bool) -> void:
	var rule_id := String(rule.get("id", ""))
	var block := Widgets.section(parent, String(rule.get("name", rule_id)), _palette)

	Widgets.muted_text(block, String(rule.get("summary", "")), _palette, Widgets.FONT_CAPTION)
	Widgets.text(block, String(rule.get("description", "")), _palette, Widgets.FONT_CAPTION)

	# The label used to read "Enabled" whether the rule was on or off, so the row
	# named a state it was not necessarily in and you had to read the switch to
	# know which. It now says what is true.
	var toggle := Widgets.toggle_row(block, _rule_state_label(enabled), enabled, _palette)
	toggle.toggled.connect(func(pressed: bool):
		toggle.text = _rule_state_label(pressed)
		# Record only the net change: toggling twice leaves nothing to apply.
		if pressed == enabled:
			_changed.erase(rule_id)
		else:
			_changed[rule_id] = pressed)


func _rule_state_label(enabled: bool) -> String:
	return "Using this rule" if enabled else "Not using this rule"
