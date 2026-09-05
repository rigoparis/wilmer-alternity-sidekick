extends RouteScene
##
## A committed character's sheet, as the GM sees it. Read-only.
##
## Renders the same Summary tab a player looks at, from the same rules engine and
## the same document -- because a GM and a player disagreeing about a durability
## track mid-fight is the failure this whole feature exists to avoid, and two
## renderers would eventually disagree.
##
## Read-only is enforced by what this holds rather than by hiding buttons. The
## document is built from the committed snapshot with no `source_file`, so there
## is nothing for a save to write to, and the context carries no CheckRunner, so
## nothing here can roll on somebody else's behalf. The Summary tab happens to be
## a reporting view with no edit controls, but that is not what makes this safe.
##
## Closes with null. There is nothing to bring back.
##

const SUMMARY_TAB := preload("res://scenes/ui/tabs/tab_summary.tscn")

var _palette: ThemePalette
var _rules: AlternityRules
var _doc: CharacterDoc
var _heading: String = "Character"
var _subtitle: String = ""
var _tab: SheetTab


## props:
##   palette    ThemePalette
##   rules      AlternityRules
##   snapshot   the committed CharacterSnapshot
##   player     the player's name, for the header
func configure(props: Dictionary) -> void:
	_palette = props.get("palette", ThemePalette.new())
	_rules = props.get("rules")
	var snapshot: Dictionary = props.get("snapshot", {})
	_doc = CharacterSnapshot.doc_of(snapshot, _rules)
	_heading = CharacterSnapshot.hero_name_of(snapshot)
	if _heading.is_empty():
		_heading = "Character"

	var who := String(props.get("player", ""))
	_subtitle = "%s -- sent from their device %s" % [
		who if not who.is_empty() else "Their hero",
		CharacterSnapshot.freshness(snapshot),
	]
	_build()


func preferred_presentation() -> int:
	return UiRouter.Presentation.PAGE


func title() -> String:
	return _heading


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface, _palette.border, 8))
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.PAD_PANEL)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", Widgets.GAP_ROW)
	margin.add_child(column)

	var heading := Widgets.text(column, _heading, _palette, Widgets.FONT_SECTION_TITLE, _palette.accent)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size = Vector2(1, 0)

	# When the copy was taken. A GM reading a stale durability track as current is
	# the one way a committed snapshot can mislead, so it says its own age.
	var subtitle := Widgets.muted_text(column, _subtitle, _palette, Widgets.FONT_CAPTION)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.custom_minimum_size = Vector2(1, 0)

	if _doc == null or _rules == null:
		Widgets.muted_text(
			column,
			"This character was sent by a version of the app this one cannot read.",
			_palette
		)
		_build_close(column)
		return

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var host := VBoxContainer.new()
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(host)

	# No router and no CheckRunner: this context cannot open a catalog or roll,
	# which is what keeps a read-only view read-only.
	var context := SheetContext.new(_doc, _rules, null, _palette, _is_wide())
	_tab = SUMMARY_TAB.instantiate()
	_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.add_child(_tab)
	_tab.bind(context)

	_build_close(column)


func _build_close(parent: Container) -> void:
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Done"
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.custom_minimum_size = Vector2(0, 42)
	close_button.pressed.connect(func(): close(null))
	parent.add_child(close_button)


## Whether there is room for two columns of summary info.
##
## configure() runs before the router presents the route, so during the first
## build there is no viewport to measure and asking for one is an error. The
## sheet context is rebound in _ready, which is the first moment the answer is real.
func _is_wide() -> bool:
	if not is_inside_tree():
		return false
	return get_viewport_rect().size.x >= ModalHost.COMPACT_WIDTH


func _ready() -> void:
	if _tab != null and _doc != null and _rules != null:
		var context := SheetContext.new(_doc, _rules, null, _palette, _is_wide())
		_tab.bind(context)
		_tab.refresh(true)
