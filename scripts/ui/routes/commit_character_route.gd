extends RouteScene
##
## Which hero am I playing at this table?
##
## Asked once, on joining, because a campaign is something a character is *in*.
## Before this the GM chose from a dropdown of heroes on their own device, which
## could only ever offer characters the GM happened to have and let them put a
## player on one the player had never seen.
##
## Closes with:
##
##     {"file_name": "Vance_Kellar.json"}   play this one
##     {"create": true}                     make a new one first
##
## or null if the player backed out, in which case they are connected with no
## character committed -- which the table tab says plainly rather than pretending.
##
## The campaign's optional rules are named here rather than sprung afterwards.
## Several of them change ability limits and the starting skill budget, so a hero
## built without them does not merely differ in taste -- their numbers are wrong
## for this table, and TableSession.commit() will change them.
##

var _palette: ThemePalette
var _rules: AlternityRules
var _store: CharacterStore
var _campaign_name: String = ""
var _optional_rules: Dictionary = {}


## props:
##   palette         ThemePalette
##   rules           AlternityRules
##   store           CharacterStore
##   campaign_name   String
##   optional_rules  Dictionary of rule_id -> enabled, from the welcome
func configure(props: Dictionary) -> void:
	_palette = props.get("palette", ThemePalette.new())
	_rules = props.get("rules")
	_store = props.get("store")
	_campaign_name = String(props.get("campaign_name", "this table"))
	var given = props.get("optional_rules", {})
	_optional_rules = given if typeof(given) == TYPE_DICTIONARY else {}
	_build()


func preferred_presentation() -> int:
	return UiRouter.Presentation.PAGE


func title() -> String:
	return "Choose your hero"


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface, _palette.border, 8))
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.PAD_PANEL)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	scroll.add_child(column)

	var heading := Widgets.text(column, "Joining %s" % _campaign_name, _palette, Widgets.FONT_SECTION_TITLE, _palette.accent)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size = Vector2(1, 0)

	var blurb := Widgets.muted_text(
		column,
		"Pick the hero you are playing in this campaign. The GM sees their sheet; only you can change it.",
		_palette
	)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(1, 0)

	_build_rules_notice(column)
	_build_existing(column)

	var create := Button.new()
	create.name = "CreateHeroButton"
	create.text = "Create a new hero"
	create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create.custom_minimum_size = Vector2(0, 44)
	create.clip_text = true
	create.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
	create.pressed.connect(func(): close({"create": true}))
	column.add_child(create)

	var later := Button.new()
	later.name = "LaterButton"
	later.text = "Not yet"
	later.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	later.custom_minimum_size = Vector2(0, 40)
	later.clip_text = true
	later.pressed.connect(func(): close(null))
	column.add_child(later)


## What this table plays with, said before a character is chosen.
##
## Not a formality: these change what a hero is allowed to be, and an existing
## character will be brought into line on commit. A player deserves to see that
## coming rather than find their sheet altered.
func _build_rules_notice(parent: Container) -> void:
	var enabled: Array = []
	for rule_id in _optional_rules:
		if bool(_optional_rules[rule_id]):
			enabled.append(_rule_label(String(rule_id)))
	if enabled.is_empty():
		return

	var section := Widgets.section(parent, "This campaign uses", _palette)
	var note := Widgets.text(section, ", ".join(enabled), _palette, Widgets.FONT_DETAIL)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(1, 0)

	var warning := Widgets.muted_text(
		section,
		"Your hero will be brought into line with these when you join.",
		_palette,
		Widgets.FONT_CAPTION
	)
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.custom_minimum_size = Vector2(1, 0)


func _rule_label(rule_id: String) -> String:
	for rule in AlternityRules.OPTIONAL_RULES:
		if typeof(rule) == TYPE_DICTIONARY and String(rule.get("id", "")) == rule_id:
			return String(rule.get("name", rule_id))
	return rule_id


func _build_existing(parent: Container) -> void:
	var saved: Array = _store.list() if _store != null else []
	if saved.is_empty():
		Widgets.muted_text(
			parent,
			"There are no heroes on this device yet.",
			_palette,
			Widgets.FONT_CAPTION
		)
		return

	var section := Widgets.section(parent, "Heroes on this device", _palette)
	for entry in saved:
		var file_name := String(entry.get("file_name", ""))
		var button := Button.new()
		button.text = "%s  -  level %d" % [
			String(entry.get("hero_name", "Unnamed")),
			AlternityNum.as_int(entry.get("level", 1), 1),
		]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 40)
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(func(): close({"file_name": file_name}))
		section.add_child(button)
