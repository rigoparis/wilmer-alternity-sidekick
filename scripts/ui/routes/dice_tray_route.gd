extends RouteScene
##
## The dice tray route, presented as an authoritative tabletop dice throw console.
##
## Hosts the 3D tray in a SubViewport inside the Control tree with an interactive
## aim and trajectory HUD overlay.
##
## Core Rules and Constraints:
##   * COMMITTED THROW (No way out, no way back): Once a player enters this
##     screen, the action is committed. is_dismissible() returns false, and there
##     is no Back or Cancel button. The player MUST throw the dice, and the
##     settled result cannot be backed out or re-rolled.
##   * STEP BREAKDOWN EXPLANATION: Clearly explains where player carried step
##     modifiers originate (broad skill, species traits, profession perks,
##     dazed/wound penalties, encumbrance, armor) alongside GM situation steps,
##     and how they combine to determine the Situation Die.
##   * APPROACH A HAND THROW: Dice are thrown from a simulated hand placed on
##     the border (Left, Bottom, or Right rim). Players can drag the hand position,
##     drag the target reticle in the tray, view the wall-bounce ricochet preview,
##     and select throw power (Soft, Medium, Hard, Max).
##   * OPTION C WITH TOGGLE: Aim and click "Throw Dice", or enable "Release to throw"
##     to launch instantly upon dragging and releasing.
##   * AUTHORITATIVE SIMULATION: Results are read from where the dice settle in
##     3D physics. Numbers are never revealed before the dice stop tumbling.
##

const Check := preload("res://scripts/core/session/skill_check.gd")
const Tray := preload("res://scripts/core/dice/dice_tray.gd")
const Source := preload("res://scripts/core/dice/physical_dice_source.gd")

var _palette: ThemePalette
var _rules: AlternityRules

## Set for an action check. Null for a plain roll -- damage, a mutation table.
var _check: SkillCheck

## What to throw when this is not a check.
var _terms: Array = []
var _label: String = ""

var _tray: DiceTray
var _source: PhysicalDiceSource
var _viewport: SubViewport
var _tray_status: Label
var _scroll: ScrollContainer

var _summary: Label
var _outcome: Label
var _detail: Label
var _context_note: Label
var _roll_button: Button
var _done_button: Button
var _outcome_card: PanelContainer
var _aim_overlay: Control

var _resolved: Dictionary = {}
var _rolling: bool = false

# Aim & Throw Parameters (Approach A)
var _hand_3d: Vector3 = Vector3(3.6, 3.2, 1.2)
var _target_3d: Vector3 = Vector3(0.0, 0.5, 0.0)
var _force_tier: int = 2 # 1=Soft, 2=Medium, 3=Hard, 4=Max
var _release_to_throw: bool = false

# Power buttons references
var _power_buttons: Array[Button] = []


## props:
##   palette   ThemePalette
##   rules     AlternityRules, needed to grade a check
##   check     a SkillCheck dictionary, for an action check
##   terms     [parsed notation], for a plain roll
##   label     what the roll is for
func configure(props: Dictionary) -> void:
	_palette = props.get("palette", ThemePalette.new())
	_rules = props.get("rules", null)
	_label = String(props.get("label", "Roll"))

	var check_data = props.get("check", null)
	if typeof(check_data) == TYPE_DICTIONARY and not check_data.is_empty():
		_check = Check.from_dict(check_data)

	var terms = props.get("terms", [])
	if typeof(terms) == TYPE_ARRAY:
		_terms = terms

	_build()


func preferred_presentation() -> int:
	return UiRouter.Presentation.PAGE


func title() -> String:
	return _check.skill_label if _check != null else _label


## Once in the dice rolling screen, there is no way out and no way back.
## The player HAS to throw the dice and the result is authoritative.
func is_dismissible() -> bool:
	return false


func _is_wide() -> bool:
	if not is_inside_tree():
		return false
	return get_viewport_rect().size.x >= 700.0


# --- Building --------------------------------------------------------------

func _build() -> void:
	var is_wide := _is_wide()

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.background, Color.TRANSPARENT, 0))
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.page_margin(is_wide))
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", Widgets.GAP_ROW)
	margin.add_child(outer)

	# 1. Header Bar
	_build_header(outer)

	# 2. Scrollable Body
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", Widgets.GAP_ROW)
	_scroll.add_child(column)

	if _check != null:
		if is_wide:
			# Desktop: Place Targets and Modifiers side by side to conserve vertical space!
			var cards_row := HBoxContainer.new()
			cards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cards_row.add_theme_constant_override("separation", Widgets.GAP_ROW)
			column.add_child(cards_row)

			var targets_card := _build_targets_card(cards_row, is_wide)
			targets_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			targets_card.size_flags_stretch_ratio = 1.0

			var mods_card := _build_modifiers_card(cards_row, is_wide)
			mods_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mods_card.size_flags_stretch_ratio = 1.0
		else:
			# Mobile: Stack vertically
			_build_targets_card(column, is_wide)
			_build_modifiers_card(column, is_wide)
	else:
		_build_plain_roll_card(column)

	# 3D Tray Card with interactive aim controls
	_build_tray_card(column, is_wide)

	# Outcome Card (revealed post-settle)
	_build_outcome_card(column)

	# 3. Pinned Action Bar at the bottom
	_build_action_bar(outer)

	_update_touch_filters(_scroll)
	if _aim_overlay != null:
		_aim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP


func _build_header(parent: Container) -> void:
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", Widgets.GAP_ROW)
	parent.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	header.add_child(title_box)

	var heading := Label.new()
	heading.text = title().to_upper()
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size = Vector2(1, 0)
	heading.add_theme_color_override("font_color", _palette.accent)
	heading.add_theme_font_size_override("font_size", Widgets.FONT_SECTION_TITLE)
	title_box.add_child(heading)

	var category := Label.new()
	category.text = "ACTION CHECK (INITIATIVE)" if (_check != null and _check.skill_label.to_lower().contains("action check")) else ("SKILL CHECK" if _check != null else "DICE ROLL")
	category.add_theme_color_override("font_color", _palette.muted)
	category.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	title_box.add_child(category)

	# Lock / Commitment Pill
	var commit_pill := PanelContainer.new()
	commit_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	commit_pill.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface_soft, _palette.warning, 12))
	header.add_child(commit_pill)

	var pill_margin := MarginContainer.new()
	pill_margin.add_theme_constant_override("margin_left", 8)
	pill_margin.add_theme_constant_override("margin_right", 8)
	pill_margin.add_theme_constant_override("margin_top", 4)
	pill_margin.add_theme_constant_override("margin_bottom", 4)
	commit_pill.add_child(pill_margin)

	var commit_label := Label.new()
	commit_label.text = "ROLL COMMITTED"
	commit_label.add_theme_color_override("font_color", _palette.warning)
	commit_label.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	pill_margin.add_child(commit_label)


# --- Targets Card ----------------------------------------------------------

func _build_targets_card(parent: Container, is_wide: bool) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface, _palette.border, 8))
	parent.add_child(card)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	margin.add_child(box)

	var label := Label.new()
	label.text = "TARGET SUCCESS DEGREES"
	label.add_theme_color_override("font_color", _palette.text)
	label.add_theme_font_size_override("font_size", Widgets.FONT_SUBHEADING)
	box.add_child(label)

	var is_act := _check.skill_label.to_lower().contains("action check")

	var targets_row := HBoxContainer.new()
	targets_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	targets_row.add_theme_constant_override("separation", 4)
	box.add_child(targets_row)

	var degrees := [
		{
			"name": "Ordinary",
			"score": _check.ordinary,
			"desc": "Ordinary Phase" if is_act else "Standard success",
			"color": _palette.text,
		},
		{
			"name": "Good",
			"score": _check.good,
			"desc": "Good Phase" if is_act else "Superior success",
			"color": _palette.accent,
		},
		{
			"name": "Amazing",
			"score": _check.amazing,
			"desc": "Amazing Phase" if is_act else "Critical / best",
			"color": _palette.accent,
		},
	]

	for entry in degrees:
		var pill := PanelContainer.new()
		pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pill.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface_soft, _palette.border, 6))
		targets_row.add_child(pill)

		var pm := MarginContainer.new()
		pm.add_theme_constant_override("margin_left", 4)
		pm.add_theme_constant_override("margin_right", 4)
		pm.add_theme_constant_override("margin_top", 6)
		pm.add_theme_constant_override("margin_bottom", 6)
		pill.add_child(pm)

		var pb := VBoxContainer.new()
		pb.add_theme_constant_override("separation", 1)
		pm.add_child(pb)

		var title_lbl := Label.new()
		title_lbl.text = String(entry["name"])
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_lbl.add_theme_color_override("font_color", entry["color"])
		title_lbl.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
		pb.add_child(title_lbl)

		var val_lbl := Label.new()
		val_lbl.text = "<= %d" % AlternityNum.as_int(entry["score"])
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.add_theme_color_override("font_color", _palette.accent if entry["name"] != "Ordinary" else _palette.text)
		val_lbl.add_theme_font_size_override("font_size", Widgets.FONT_BODY if is_wide else Widgets.FONT_CAPTION)
		pb.add_child(val_lbl)

		var sub_lbl := Label.new()
		sub_lbl.text = String(entry["desc"])
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub_lbl.custom_minimum_size = Vector2(1, 0)
		sub_lbl.add_theme_color_override("font_color", _palette.muted)
		sub_lbl.add_theme_font_size_override("font_size", 10)
		pb.add_child(sub_lbl)

	var footnote := Label.new()
	footnote.text = ("Over %d: Marginal Phase (acts last)" % _check.ordinary) if is_act else ("Over %d: Failure (Marginal/Failure to achieve task)" % _check.ordinary)
	footnote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footnote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footnote.custom_minimum_size = Vector2(1, 0)
	footnote.add_theme_color_override("font_color", _palette.muted)
	footnote.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	box.add_child(footnote)

	return card


# --- Modifiers & Explanation Card ------------------------------------------

func _build_modifiers_card(parent: Container, is_wide: bool) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface, _palette.border, 8))
	parent.add_child(card)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	margin.add_child(box)

	var title_lbl := Label.new()
	title_lbl.text = "STEP MODIFIERS & SITUATION DIE"
	title_lbl.add_theme_color_override("font_color", _palette.text)
	title_lbl.add_theme_font_size_override("font_size", Widgets.FONT_SUBHEADING)
	box.add_child(title_lbl)

	# Hero steps
	var hero_section := VBoxContainer.new()
	hero_section.add_theme_constant_override("separation", 2)
	box.add_child(hero_section)

	var hero_head := Label.new()
	hero_head.text = "Hero Carried Modifiers (%+d step%s):" % [_check.player_step, "" if absi(_check.player_step) == 1 else "s"]
	hero_head.add_theme_color_override("font_color", _palette.accent if _check.player_step < 0 else (_palette.warning if _check.player_step > 0 else _palette.text))
	hero_head.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	hero_section.add_child(hero_head)

	if not _check.step_breakdown.is_empty():
		for item in _check.step_breakdown:
			var item_step := AlternityNum.as_int(item.get("step", 0))
			var row := Label.new()
			var detail_str := String(item.get("detail", ""))
			row.text = "   • %s: %+d step%s%s" % [
				String(item.get("source", "")),
				item_step,
				"" if absi(item_step) == 1 else "s",
				(" (%s)" % detail_str) if not detail_str.is_empty() else ""
			]
			row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.custom_minimum_size = Vector2(1, 0)
			row.add_theme_color_override("font_color", _palette.accent if item_step < 0 else (_palette.warning if item_step > 0 else _palette.muted))
			row.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
			hero_section.add_child(row)
	elif _check.player_step != 0:
		var row := Label.new()
		row.text = "   • Carried modifiers from species, traits, training or health conditions."
		row.add_theme_color_override("font_color", _palette.muted)
		row.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
		hero_section.add_child(row)
	else:
		var row := Label.new()
		row.text = "   • Trained specialty: +0 steps (no broad skill or health penalties)."
		row.add_theme_color_override("font_color", _palette.muted)
		row.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
		hero_section.add_child(row)

	# GM steps
	var gm_section := VBoxContainer.new()
	gm_section.add_theme_constant_override("separation", 2)
	box.add_child(gm_section)

	var gm_head := Label.new()
	gm_head.text = "GM / Environment Modifiers (%+d step%s):" % [_check.gm_step, "" if absi(_check.gm_step) == 1 else "s"]
	gm_head.add_theme_color_override("font_color", _palette.accent if _check.gm_step < 0 else (_palette.warning if _check.gm_step > 0 else _palette.text))
	gm_head.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	gm_section.add_child(gm_head)

	var gm_row := Label.new()
	if not _check.reason.is_empty():
		gm_row.text = "   • Reason: \"%s\"" % _check.reason
	elif _check.gm_step != 0:
		gm_row.text = "   • Difficulty step ruled by GM for current environmental conditions."
	else:
		gm_row.text = "   • Standard conditions (no GM difficulty steps added)."
	gm_row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gm_row.custom_minimum_size = Vector2(1, 0)
	gm_row.add_theme_color_override("font_color", _palette.muted)
	gm_row.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	gm_section.add_child(gm_row)

	# Formula Banner
	var formula_box := PanelContainer.new()
	formula_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	formula_box.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
	box.add_child(formula_box)

	var f_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		f_margin.add_theme_constant_override("margin_" + side, 6)
	formula_box.add_child(f_margin)

	var f_box := VBoxContainer.new()
	f_box.add_theme_constant_override("separation", 2)
	f_margin.add_child(f_box)

	var total_step := _check.total_step()
	var sit_die := _situation_notation()
	var net_lbl := Label.new()
	net_lbl.text = "Hero (%+d) + GM (%+d) = %+d Net Step" % [_check.player_step, _check.gm_step, total_step]
	net_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	net_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	net_lbl.custom_minimum_size = Vector2(1, 0)
	net_lbl.add_theme_color_override("font_color", _palette.text)
	net_lbl.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	f_box.add_child(net_lbl)

	var dice_readout := Label.new()
	dice_readout.text = ("1d20 (Control)  +  %s (Situation)" % sit_die) if not is_wide else ("Control Die: 1d20   +   Situation Die: %s" % sit_die)
	dice_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dice_readout.custom_minimum_size = Vector2(1, 0)
	dice_readout.add_theme_color_override("font_color", _palette.accent)
	dice_readout.add_theme_font_size_override("font_size", Widgets.FONT_SUBHEADING if is_wide else Widgets.FONT_DETAIL)
	f_box.add_child(dice_readout)

	# Rules Primer Note
	var primer := Label.new()
	primer.text = "Alternity Rule: Roll equal to or under your score. Negative steps (-d4, -d6) are bonuses subtracting from your d20; positive steps (+d4, +d6) are penalties adding to your d20."
	primer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	primer.custom_minimum_size = Vector2(1, 0)
	primer.add_theme_color_override("font_color", _palette.muted)
	primer.add_theme_font_size_override("font_size", 11)
	box.add_child(primer)

	# Summary label preserved for smoke test assertion compatibility
	_summary = Label.new()
	_summary.text = _describe_what_is_being_rolled()
	_summary.visible = false
	box.add_child(_summary)

	return card


# --- Plain Roll Card -------------------------------------------------------

func _build_plain_roll_card(parent: Container) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface, _palette.border, 8))
	parent.add_child(card)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.PAD_PANEL)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	margin.add_child(box)

	var heading := Label.new()
	heading.text = "UNREFERENCED DICE ROLL"
	heading.add_theme_color_override("font_color", _palette.text)
	heading.add_theme_font_size_override("font_size", Widgets.FONT_SUBHEADING)
	box.add_child(heading)

	var desc := Label.new()
	desc.text = "Rolling %s with physical 3D simulation." % _label
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(1, 0)
	desc.add_theme_color_override("font_color", _palette.muted)
	desc.add_theme_font_size_override("font_size", Widgets.FONT_BODY)
	box.add_child(desc)

	_summary = Label.new()
	_summary.text = _label
	_summary.visible = false
	box.add_child(_summary)


# --- 3D Tray Card with Interactive Aim (Approach A) ------------------------

func _build_tray_card(parent: Container, is_wide: bool) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface, _palette.border, 8, true))
	parent.add_child(card)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	# Header row
	var header_row := HBoxContainer.new()
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(header_row)

	var tray_lbl := Label.new()
	tray_lbl.text = "PHYSICAL DICE TRAY"
	tray_lbl.add_theme_color_override("font_color", _palette.muted)
	tray_lbl.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	header_row.add_child(tray_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)

	_tray_status = Label.new()
	_tray_status.text = "Ready to throw"
	_tray_status.add_theme_color_override("font_color", _palette.accent)
	_tray_status.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	header_row.add_child(_tray_status)

	# Controls Bar for Approach A: Side Hand Picker + Power Selector + Release Toggle
	_build_aim_controls_bar(box, is_wide)

	# Viewport container with overlay
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size = Vector2(0, 350 if is_wide else 250)
	frame.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface, _palette.border, 6))
	box.add_child(frame)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(container)

	_viewport = SubViewport.new()
	_viewport.transparent_bg = false
	_viewport.own_world_3d = true
	_viewport.world_3d = World3D.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_viewport)

	_tray = Tray.new()
	_viewport.add_child(_tray)
	_tray.configure(_palette)
	_source = Source.new(_tray)
	_sync_tray_aim()

	var camera := Camera3D.new()
	camera.fov = 45.0
	var span := DiceTray.TRAY_HALF * 2.0 + 1.2
	var height := (span * 0.5) / tan(deg_to_rad(camera.fov * 0.5))
	camera.look_at_from_position(
		Vector3(0, maxf(height, DiceTray.WALL_HEIGHT + 2.0), 0.001), Vector3.ZERO, Vector3.FORWARD
	)
	_viewport.add_child(camera)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-60, -35, 0)
	key.light_energy = 1.3
	_viewport.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-65, 140, 0)
	fill.light_energy = 0.8
	_viewport.add_child(fill)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = _palette.surface
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _palette.surface_soft
	env.ambient_light_energy = 1.0
	environment.environment = env
	_viewport.add_child(environment)

	# Interactive Aim Overlay
	_aim_overlay = _AimOverlay.new(self)
	_aim_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(_aim_overlay)


func _build_aim_controls_bar(parent: Container, is_wide: bool) -> void:
	_power_buttons.clear()
	var powers := ["Soft", "Med", "Hard", "Max"]

	if is_wide:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 6)
		parent.add_child(row)

		# Hand Side Quick Switch
		var hand_lbl := Label.new()
		hand_lbl.text = "Hand:"
		hand_lbl.add_theme_color_override("font_color", _palette.muted)
		hand_lbl.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
		row.add_child(hand_lbl)

		var sides := [
			["Left", Vector3(-3.6, 3.2, 0.0)],
			["Top", Vector3(0.0, 3.2, -3.6)],
			["Bottom", Vector3(0.0, 3.2, 3.6)],
			["Right", Vector3(3.6, 3.2, 0.0)],
		]
		for entry in sides:
			var btn := Button.new()
			btn.text = String(entry[0])
			btn.custom_minimum_size = Vector2(46, 26)
			btn.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
			var hand_pos: Vector3 = entry[1]
			btn.pressed.connect(func():
				_hand_3d = hand_pos
				_sync_tray_aim()
				if _aim_overlay != null:
					_aim_overlay.queue_redraw()
			)
			row.add_child(btn)

		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)

		# Power Selector [Soft | Med | Hard | Max]
		var power_lbl := Label.new()
		power_lbl.text = "Power:"
		power_lbl.add_theme_color_override("font_color", _palette.muted)
		power_lbl.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
		row.add_child(power_lbl)

		for i in powers.size():
			var tier := i + 1
			var p_btn := Button.new()
			p_btn.text = powers[i]
			p_btn.custom_minimum_size = Vector2(46, 26)
			p_btn.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
			p_btn.pressed.connect(func(): _set_power(tier))
			_power_buttons.append(p_btn)
			row.add_child(p_btn)

		# Release to throw toggle
		var rel_btn := Button.new()
		rel_btn.text = "Flick to Throw: OFF"
		rel_btn.custom_minimum_size = Vector2(110, 26)
		rel_btn.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
		rel_btn.pressed.connect(func():
			_release_to_throw = not _release_to_throw
			rel_btn.text = "Flick to Throw: ON" if _release_to_throw else "Flick to Throw: OFF"
			rel_btn.add_theme_color_override("font_color", _palette.accent if _release_to_throw else _palette.text)
		)
		row.add_child(rel_btn)
	else:
		# Mobile: 2 compact rows
		var row1 := HBoxContainer.new()
		row1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row1.add_theme_constant_override("separation", 4)
		parent.add_child(row1)

		var hand_lbl := Label.new()
		hand_lbl.text = "Hand:"
		hand_lbl.add_theme_color_override("font_color", _palette.muted)
		hand_lbl.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
		row1.add_child(hand_lbl)

		var sides := [
			["Left", Vector3(-3.6, 3.2, 0.0)],
			["Top", Vector3(0.0, 3.2, -3.6)],
			["Bottom", Vector3(0.0, 3.2, 3.6)],
			["Right", Vector3(3.6, 3.2, 0.0)],
		]
		for entry in sides:
			var btn := Button.new()
			btn.text = String(entry[0])
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(0, 26)
			btn.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
			var hand_pos: Vector3 = entry[1]
			btn.pressed.connect(func():
				_hand_3d = hand_pos
				_sync_tray_aim()
				if _aim_overlay != null:
					_aim_overlay.queue_redraw()
			)
			row1.add_child(btn)

		var rel_btn := Button.new()
		rel_btn.text = "Flick: OFF"
		rel_btn.custom_minimum_size = Vector2(76, 26)
		rel_btn.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
		rel_btn.pressed.connect(func():
			_release_to_throw = not _release_to_throw
			rel_btn.text = "Flick: ON" if _release_to_throw else "Flick: OFF"
			rel_btn.add_theme_color_override("font_color", _palette.accent if _release_to_throw else _palette.text)
		)
		row1.add_child(rel_btn)

		var row2 := HBoxContainer.new()
		row2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_theme_constant_override("separation", 4)
		parent.add_child(row2)

		var power_lbl := Label.new()
		power_lbl.text = "Power:"
		power_lbl.add_theme_color_override("font_color", _palette.muted)
		power_lbl.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
		row2.add_child(power_lbl)

		for i in powers.size():
			var tier := i + 1
			var p_btn := Button.new()
			p_btn.text = powers[i]
			p_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			p_btn.custom_minimum_size = Vector2(0, 26)
			p_btn.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
			p_btn.pressed.connect(func(): _set_power(tier))
			_power_buttons.append(p_btn)
			row2.add_child(p_btn)

	_refresh_power_buttons()


func _set_power(tier: int) -> void:
	_force_tier = tier
	_sync_tray_aim()
	_refresh_power_buttons()
	if _aim_overlay != null:
		_aim_overlay.queue_redraw()


func _refresh_power_buttons() -> void:
	for i in _power_buttons.size():
		var tier := i + 1
		var btn := _power_buttons[i]
		if tier == _force_tier:
			btn.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 4))
			btn.add_theme_color_override("font_color", _palette.accent)
		else:
			btn.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.border, 4))
			btn.add_theme_color_override("font_color", _palette.muted)


func _sync_tray_aim() -> void:
	if _tray != null:
		_tray.set_aim(_hand_3d, _target_3d, _force_tier)


# --- Outcome Card ----------------------------------------------------------

func _build_outcome_card(parent: Container) -> void:
	_outcome_card = PanelContainer.new()
	_outcome_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_outcome_card.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface, _palette.accent, 8))
	_outcome_card.visible = false
	parent.add_child(_outcome_card)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.PAD_PANEL)
	_outcome_card.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	_outcome = Label.new()
	_outcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_outcome.custom_minimum_size = Vector2(1, 32)
	_outcome.add_theme_color_override("font_color", _palette.accent)
	_outcome.add_theme_font_size_override("font_size", 24)
	box.add_child(_outcome)

	_detail = Label.new()
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(1, 0)
	_detail.add_theme_color_override("font_color", _palette.text)
	_detail.add_theme_font_size_override("font_size", Widgets.FONT_BODY)
	box.add_child(_detail)

	_context_note = Label.new()
	_context_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_context_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_context_note.custom_minimum_size = Vector2(1, 0)
	_context_note.add_theme_color_override("font_color", _palette.muted)
	_context_note.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	box.add_child(_context_note)


# --- Action Bar (Pinned Bottom) --------------------------------------------

func _build_action_bar(parent: Container) -> void:
	var actions := HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", Widgets.GAP_ROW)
	parent.add_child(actions)

	_roll_button = Button.new()
	_roll_button.name = "RollButton"
	_roll_button.text = "Throw Dice"
	_roll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roll_button.custom_minimum_size = Vector2(0, 48)
	_roll_button.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 8))
	_roll_button.add_theme_font_size_override("font_size", Widgets.FONT_SUBHEADING)
	_roll_button.add_theme_color_override("font_color", _palette.accent)
	_roll_button.pressed.connect(_on_roll_pressed)
	actions.add_child(_roll_button)

	_done_button = Button.new()
	_done_button.name = "DoneButton"
	_done_button.text = "Confirm & Send"
	_done_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_done_button.custom_minimum_size = Vector2(0, 48)
	_done_button.visible = false
	_done_button.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 8))
	_done_button.add_theme_font_size_override("font_size", Widgets.FONT_SUBHEADING)
	_done_button.add_theme_color_override("font_color", _palette.accent)
	_done_button.pressed.connect(func(): close(_resolved))
	actions.add_child(_done_button)


# --- Helpers ---------------------------------------------------------------

func _describe_what_is_being_rolled() -> String:
	if _check == null:
		return _label

	var parts: Array = ["Score %d / %d / %d" % [_check.ordinary, _check.good, _check.amazing]]
	if _check.player_step != 0:
		parts.append("your modifiers %+d" % _check.player_step)
	if _check.gm_step != 0:
		parts.append("GM %+d" % _check.gm_step)
	parts.append("situation die %s" % _situation_notation())
	if not _check.reason.is_empty():
		parts.append(_check.reason)
	return "  -  ".join(parts)


func _situation_notation() -> String:
	if _check == null or _rules == null:
		return "+d0"
	return _rules.action_step_die(_check.total_step())


# --- Rolling ---------------------------------------------------------------

func _on_roll_pressed() -> void:
	if _rolling:
		return
	_rolling = true
	_roll_button.disabled = true
	_roll_button.text = "Rolling..."
	_tray_status.text = "Tumbling... resolving physics"
	_tray_status.add_theme_color_override("font_color", _palette.warning)
	if _aim_overlay != null:
		_aim_overlay.visible = false
	_outcome_card.visible = false
	_outcome.text = ""
	_detail.text = ""
	_context_note.text = ""

	_sync_tray_aim()

	if _check != null:
		await _roll_check()
	else:
		await _roll_plain()

	if not is_instance_valid(self):
		return
	_rolling = false
	_tray_status.text = "Settled"
	_tray_status.add_theme_color_override("font_color", _palette.accent)
	_outcome_card.visible = true
	_roll_button.visible = false
	_done_button.visible = true
	_done_button.grab_focus()

	# Auto-scroll so the outcome card is brought cleanly into view
	if _scroll != null and is_instance_valid(_scroll):
		var tree := get_tree()
		if tree != null:
			await tree.process_frame
			if is_instance_valid(_scroll) and is_instance_valid(_outcome_card):
				_scroll.ensure_control_visible(_outcome_card)


func _roll_check() -> void:
	var control_term := DiceNotation.parse("d20")
	var situation_term := DiceNotation.parse(_situation_notation())
	var results: Array = await _source.roll_group([control_term, situation_term], _check.skill_label)
	if not is_instance_valid(self) or results.size() < 2:
		return

	var control: RollResult = results[0]
	var situation: RollResult = results[1]
	var control_face: int = control.dice[0] if not control.dice.is_empty() else 20

	var graded: Dictionary = _rules.resolve_check(
		control_face, situation.total, _check.ordinary, _situation_notation()
	)
	_check.resolve(graded)

	_resolved = {
		"check": _check.to_dict(),
		"control": control.to_dict(),
		"situation": situation.to_dict(),
		"graded": graded,
	}
	_show_check_outcome(control_face, situation, graded)


func _roll_plain() -> void:
	var results: Array = await _source.roll_group(_terms, _label)
	if not is_instance_valid(self):
		return
	var payload: Array = []
	var total := 0
	for result in results:
		payload.append(result.to_dict())
		total += (result as RollResult).total
	_resolved = {"results": payload, "total": total}

	_outcome.text = "Total: %d" % total
	_outcome.add_theme_color_override("font_color", _palette.accent)

	var faces: Array = []
	for result in results:
		for face in (result as RollResult).dice:
			faces.append(str(face))
	_detail.text = "Dice results: [%s]" % [", ".join(faces) if not faces.is_empty() else "none"]
	_context_note.text = "Result recorded for %s." % _label


func _show_check_outcome(control_face: int, situation: RollResult, graded: Dictionary) -> void:
	var degree := String(graded.get("degree", ""))
	var is_success := bool(graded.get("is_success", false))
	var is_crit_fail := bool(graded.get("is_critical_failure", false))
	var is_auto_succ := bool(graded.get("is_auto_success", false))

	var outcome_title := degree.to_upper()
	if not outcome_title.ends_with("SUCCESS") and is_success:
		outcome_title += " SUCCESS"
	_outcome.text = outcome_title
	_outcome.add_theme_color_override(
		"font_color",
		_palette.accent if is_success else _palette.warning
	)

	var total_roll := AlternityNum.as_int(graded.get("total", 0))
	var sit_sign_str := ("%+d" % situation.total) if not situation.dice.is_empty() else "+0"
	_detail.text = "1d20 [%d]   +   %s [%s]   =   Total: %d   vs   Target: %d" % [
		control_face,
		_situation_notation(),
		sit_sign_str,
		total_roll,
		_check.ordinary,
	]

	var notes: Array = []
	var is_act := _check.skill_label.to_lower().contains("action check")
	if is_act:
		notes.append("Hero acts in the %s Phase!" % degree)

	if is_crit_fail:
		notes.append("Natural 20 on Control Die: Critical Failure! Table G8 weapon mishap or setback occurs.")
	elif is_auto_succ:
		notes.append("Natural 1 on Control Die succeeds automatically!")

	if situation.rerolls > 0:
		notes.append("Cocked die detected: throw voided and re-thrown %d time%s." % [situation.rerolls, "" if situation.rerolls == 1 else "s"])

	_context_note.text = "\n".join(notes)


func _update_touch_filters(node: Node) -> void:
	for child in node.get_children():
		if child == _aim_overlay:
			child.mouse_filter = Control.MOUSE_FILTER_STOP
			continue
		if child is SubViewportContainer or child == _viewport:
			continue
		if child is Control and not (child is Button or child is LineEdit or child is TextEdit):
			child.mouse_filter = Control.MOUSE_FILTER_PASS
		_update_touch_filters(child)


# --- Inner Class: 2D Interactive Aim Overlay (Approach A) ------------------

class _AimOverlay extends Control:
	var _host: Node
	var _dragging_hand: bool = false
	var _dragging_target: bool = false

	func _init(host: Node) -> void:
		_host = host
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _to_2d(p3d: Vector3) -> Vector2:
		var rect_sz := size
		var center := rect_sz * 0.5
		var scale_factor := (minf(rect_sz.x, rect_sz.y) * 0.44) / DiceTray.TRAY_HALF
		return center + Vector2(p3d.x * scale_factor, p3d.z * scale_factor)

	func _to_3d(p2d: Vector2) -> Vector3:
		var rect_sz := size
		var center := rect_sz * 0.5
		var scale_factor := (minf(rect_sz.x, rect_sz.y) * 0.44) / DiceTray.TRAY_HALF
		if is_zero_approx(scale_factor):
			return Vector3.ZERO
		return Vector3((p2d.x - center.x) / scale_factor, 0.5, (p2d.y - center.y) / scale_factor)

	func _set_drag_state(dragging_hand: bool, dragging_target: bool) -> void:
		_dragging_hand = dragging_hand
		_dragging_target = dragging_target
		# Do NOT toggle _scroll.vertical_scroll_mode here. Changing it alters
		# the ScrollContainer's minimum size, which propagates through
		# ModalHost._relayout → _center and resizes the whole route. The overlay
		# already calls accept_event() on every touch/mouse event, so the scroll
		# container never receives the gesture in the first place.
		queue_redraw()

	func _snap_hand(p3d: Vector3) -> Vector3:
		var bound := DiceTray.TRAY_HALF - 0.8
		var cx := clampf(p3d.x, -bound, bound)
		var cz := clampf(p3d.z, -bound, bound)

		# Distance to each of the four walls (Left, Right, Top, Bottom)
		var d_left := absf(cx - (-bound))
		var d_right := absf(cx - bound)
		var d_top := absf(cz - (-bound))
		var d_bottom := absf(cz - bound)

		var min_d := minf(minf(d_left, d_right), minf(d_top, d_bottom))
		var out := Vector3(cx, 3.2, cz)

		if is_equal_approx(min_d, d_left):
			out.x = -bound
			out.z = cz
		elif is_equal_approx(min_d, d_right):
			out.x = bound
			out.z = cz
		elif is_equal_approx(min_d, d_top):
			out.z = -bound
			out.x = cx
		else:
			out.z = bound
			out.x = cx

		return out

	func _gui_input(event: InputEvent) -> void:
		if _host._rolling:
			return

		var pos := Vector2.ZERO
		var is_down := false
		var is_up := false
		var is_motion := false

		# With emulate_touch_from_mouse enabled (project setting), every mouse
		# click also generates an InputEventScreenTouch and every mouse drag an
		# InputEventScreenDrag. Processing both doubles every interaction. Handle
		# mouse events unconditionally (they arrive on every platform) and only
		# fall through to Screen* events when there is no mouse equivalent --
		# i.e. on a real touchscreen.
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index != MOUSE_BUTTON_LEFT:
				return
			pos = mb.position
			is_down = mb.pressed
			is_up = not mb.pressed
		elif event is InputEventMouseMotion:
			pos = (event as InputEventMouseMotion).position
			is_motion = true
		elif event is InputEventScreenTouch:
			# On a real device these are the primary events; on desktop they are
			# emulated duplicates. Godot tags emulated events with device == -1.
			if event.device == -1:
				accept_event()
				return
			var st := event as InputEventScreenTouch
			pos = st.position
			is_down = st.pressed
			is_up = not st.pressed
		elif event is InputEventScreenDrag:
			if event.device == -1:
				accept_event()
				return
			pos = (event as InputEventScreenDrag).position
			is_motion = true
		else:
			return

		accept_event()

		if is_down:
			var hand_2d: Vector2 = _to_2d(_host._hand_3d)
			var target_2d: Vector2 = _to_2d(_host._target_3d)
			var dist_hand := pos.distance_to(hand_2d)
			var dist_target := pos.distance_to(target_2d)

			# Generous grab radii for fingers and mouse
			var grab_radius := 44.0

			if dist_hand <= grab_radius and dist_hand <= dist_target:
				_set_drag_state(true, false)
			elif dist_target <= grab_radius:
				_set_drag_state(false, true)
			else:
				var pt_3d := _to_3d(pos)
				var inner_bound: float = DiceTray.TRAY_HALF - 1.2
				if absf(pt_3d.x) <= inner_bound and absf(pt_3d.z) <= inner_bound:
					_host._target_3d = _clamp_target(pt_3d)
					_host._sync_tray_aim()
					_set_drag_state(false, true)
				elif dist_hand < 64.0:
					# Forgiving proximity grab for hand near rim
					_host._hand_3d = _snap_hand(pt_3d)
					_host._sync_tray_aim()
					_set_drag_state(true, false)

		elif is_motion:
			if _dragging_hand:
				_host._hand_3d = _snap_hand(_to_3d(pos))
				_host._sync_tray_aim()
				queue_redraw()
			elif _dragging_target:
				_host._target_3d = _clamp_target(_to_3d(pos))
				_host._sync_tray_aim()
				queue_redraw()

		elif is_up:
			var was_dragging := _dragging_hand or _dragging_target
			_set_drag_state(false, false)
			if was_dragging and _host._release_to_throw:
				_host._on_roll_pressed()

	func _clamp_target(p3d: Vector3) -> Vector3:
		var bound: float = DiceTray.TRAY_HALF - 0.8
		return Vector3(clampf(p3d.x, -bound, bound), 0.5, clampf(p3d.z, -bound, bound))

	func _draw() -> void:
		if _host._rolling or _host._palette == null:
			return

		var hand_pos: Vector2 = _to_2d(_host._hand_3d)
		var target_pos: Vector2 = _to_2d(_host._target_3d)
		var accent_col: Color = _host._palette.accent
		var line_col := Color(accent_col.r, accent_col.g, accent_col.b, 0.85)

		# Power width
		var line_width: float = 1.5 + float(_host._force_tier) * 0.9

		# Wall bounce calculation in 3D
		var wall_bound: float = DiceTray.TRAY_HALF - 0.5
		var dir_3d: Vector3 = (_host._target_3d - _host._hand_3d).normalized()
		var bounce_result: Dictionary = _find_wall_bounce(_host._hand_3d, dir_3d, wall_bound)

		if bounce_result.has("hit"):
			var hit_2d := _to_2d(bounce_result["hit"])
			draw_line(hand_pos, hit_2d, line_col, line_width, true)
			# Draw ricochet bounce line
			var bounce_end_2d := _to_2d(bounce_result["end"])
			draw_dashed_line(hit_2d, bounce_end_2d, Color(accent_col.r, accent_col.g, accent_col.b, 0.45), line_width * 0.8, 6.0)
			# Bounce point marker
			draw_circle(hit_2d, 4.0, _host._palette.warning)
		else:
			draw_line(hand_pos, target_pos, line_col, line_width, true)

		# Hand Grip Marker (Circle + Glow + Grip Dot + Directional Arrow)
		var is_active_hand := _dragging_hand
		var hand_radius: float = 16.0 if not is_active_hand else 19.0

		if is_active_hand:
			draw_circle(hand_pos, hand_radius + 6.0, Color(accent_col.r, accent_col.g, accent_col.b, 0.25))

		draw_circle(hand_pos, hand_radius, _host._palette.surface_soft)
		draw_arc(hand_pos, hand_radius, 0, TAU, 28, accent_col, 2.4 if is_active_hand else 1.8, true)
		draw_circle(hand_pos, 6.0, accent_col)

		# Direction indicator arrow on hand pointing toward target
		var launch_dir := (target_pos - hand_pos).normalized()
		if launch_dir.length_squared() > 0.01:
			var tip := hand_pos + launch_dir * (hand_radius + 9.0)
			var base_pt := hand_pos + launch_dir * (hand_radius + 2.0)
			var side_offset := Vector2(-launch_dir.y, launch_dir.x) * 5.0
			draw_colored_polygon(
				PackedVector2Array([tip, base_pt + side_offset, base_pt - side_offset]),
				accent_col
			)

		# Target Reticle
		var is_active_target := _dragging_target
		if is_active_target:
			draw_circle(target_pos, 18.0, Color(accent_col.r, accent_col.g, accent_col.b, 0.25))

		draw_circle(target_pos, 11.0, Color(accent_col.r, accent_col.g, accent_col.b, 0.2))
		draw_arc(target_pos, 11.0, 0, TAU, 24, accent_col, 2.2 if is_active_target else 1.8, true)
		draw_line(target_pos - Vector2(16, 0), target_pos + Vector2(16, 0), accent_col, 1.4)
		draw_line(target_pos - Vector2(0, 16), target_pos + Vector2(0, 16), accent_col, 1.4)


	func _find_wall_bounce(origin_3d: Vector3, dir_3d: Vector3, bound: float) -> Dictionary:
		var t_hit := 999.0
		var hit_norm := Vector3.ZERO

		# Left wall x = -bound
		if dir_3d.x < -0.001:
			var t := (-bound - origin_3d.x) / dir_3d.x
			if t > 0.05 and t < t_hit:
				var z_at := origin_3d.z + dir_3d.z * t
				if absf(z_at) <= bound + 0.1:
					t_hit = t
					hit_norm = Vector3(1, 0, 0)
		# Right wall x = +bound
		if dir_3d.x > 0.001:
			var t := (bound - origin_3d.x) / dir_3d.x
			if t > 0.05 and t < t_hit:
				var z_at := origin_3d.z + dir_3d.z * t
				if absf(z_at) <= bound + 0.1:
					t_hit = t
					hit_norm = Vector3(-1, 0, 0)
		# Top wall z = -bound
		if dir_3d.z < -0.001:
			var t := (-bound - origin_3d.z) / dir_3d.z
			if t > 0.05 and t < t_hit:
				var x_at := origin_3d.x + dir_3d.x * t
				if absf(x_at) <= bound + 0.1:
					t_hit = t
					hit_norm = Vector3(0, 0, 1)
		# Bottom wall z = +bound
		if dir_3d.z > 0.001:
			var t := (bound - origin_3d.z) / dir_3d.z
			if t > 0.05 and t < t_hit:
				var x_at := origin_3d.x + dir_3d.x * t
				if absf(x_at) <= bound + 0.1:
					t_hit = t
					hit_norm = Vector3(0, 0, -1)

		if t_hit < 900.0:
			var hit_pt := origin_3d + dir_3d * t_hit
			var ref_dir := dir_3d.bounce(hit_norm).normalized()
			var bounce_len := 3.5
			return {
				"hit": hit_pt,
				"end": hit_pt + ref_dir * bounce_len,
			}
		return {}
