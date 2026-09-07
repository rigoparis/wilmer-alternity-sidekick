extends RouteScene
## Pull-and-release physical dice, with results kept beside the tray.

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
var _allow_reroll: bool = false
var _initial_check: Dictionary = {}

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
var _reroll_button: Button
var _done_button: Button
var _outcome_card: PanelContainer
var _aim_overlay: Control

var _resolved: Dictionary = {}
var _rolling: bool = false

# Pull gesture launch parameters
var _hand_3d: Vector3 = Vector3(0.0, 3.2, 1.8)
var _target_3d: Vector3 = Vector3(0.0, 0.5, 0.0)
var _throw_strength: float = 0.4
var _camera: Camera3D
var _frame: Control
var _instructions: Label
var _explanation: Control
var _explanation_toggle: Button

# Presentation feedback
var _impact_player: AudioStreamPlayer
var _last_impact_ms: int = -1000
var _camera_tween: Tween
var _result_labels: Control


## props:
##   palette   ThemePalette
##   rules     AlternityRules, needed to grade a check
##   check     a SkillCheck dictionary, for an action check
##   terms     [parsed notation], for a plain roll
##   label     what the roll is for
##   allow_reroll  whether the roller may discard the result before accepting it
func configure(props: Dictionary) -> void:
	_palette = props.get("palette", ThemePalette.new())
	_rules = props.get("rules", null)
	_label = String(props.get("label", "Roll"))
	_allow_reroll = bool(props.get("allow_reroll", false))

	var check_data = props.get("check", null)
	if typeof(check_data) == TYPE_DICTIONARY and not check_data.is_empty():
		_initial_check = check_data.duplicate(true)
		_check = Check.from_dict(_initial_check)

	var terms = props.get("terms", [])
	if typeof(terms) == TYPE_ARRAY:
		_terms = terms

	_build()


func preferred_presentation() -> int:
	return UiRouter.Presentation.PAGE


func title() -> String:
	return _check.skill_label if _check != null else _label


## Once in the dice rolling screen, there is no way out and no way back. Player
## results are committed; a GM may explicitly discard a preview before sending
## it, but whichever physical throw they accept is authoritative.
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

	var brief := Label.new()
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief.custom_minimum_size = Vector2(1, 0)
	brief.add_theme_color_override("font_color", _palette.muted)
	brief.text = ("d20 %s  •  Ordinary %d / Good %d / Amazing %d" % [_situation_notation(), _check.ordinary, _check.good, _check.amazing]) if _check != null else _label
	column.add_child(brief)
	_build_tray_card(column, is_wide)
	_build_outcome_card(column)
	if _check != null:
		_explanation_toggle = Button.new()
		_explanation_toggle.text = "Why these dice?"
		_explanation_toggle.flat = true
		_explanation_toggle.custom_minimum_size.y = 44
		column.add_child(_explanation_toggle)
		_explanation = VBoxContainer.new()
		column.add_child(_explanation)
		_build_modifiers_card(_explanation, is_wide)
		_explanation.hide()
		_explanation_toggle.pressed.connect(func():
			_explanation.visible = not _explanation.visible
			_explanation_toggle.text = "Hide explanation" if _explanation.visible else "Why these dice?"
		)
	else:
		_summary = brief

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


# --- Tray ---------------------------------------------------------------

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

	# One gesture hint, without a throw settings toolbar.
	_instructions = Label.new()
	_instructions.text = "Pull the dice back, then release. Or tap Throw Dice."
	_instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instructions.custom_minimum_size = Vector2(1, 0)
	_instructions.add_theme_color_override("font_color", _palette.muted)
	box.add_child(_instructions)

	# Viewport container with overlay
	var frame := PanelContainer.new()
	frame.set_meta(&"owns_touch_gesture", true)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size = Vector2(0, 350 if is_wide else 340)
	frame.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface, _palette.border, 6))
	box.add_child(frame)
	_frame = frame

	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(container)

	_viewport = SubViewport.new()
	# Smooth polygon silhouettes locally, without blurring number textures or
	# paying for supersampling across the rest of the interface.
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.transparent_bg = false
	_viewport.own_world_3d = true
	_viewport.world_3d = World3D.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_viewport)

	_tray = Tray.new()
	_viewport.add_child(_tray)
	_tray.configure(_palette)
	_source = Source.new(_tray)
	_build_impact_audio()
	_tray.impact.connect(_play_impact)
	_tray.rethrowing.connect(func(attempt: int): _tray_status.text = "Cocked die - throwing again (%d)" % attempt)
	_sync_tray_aim()

	var camera := Camera3D.new()
	_camera = camera
	camera.fov = 45.0
	var span := DiceTray.TRAY_HALF * 2.0 + 1.2
	var height := (span * 0.5) / tan(deg_to_rad(camera.fov * 0.5))
	camera.look_at_from_position(
		Vector3(0, maxf(height, DiceTray.WALL_HEIGHT + 2.0), 0.001), Vector3.ZERO, Vector3.FORWARD
	)
	_viewport.add_child(camera)
	frame.resized.connect(_fit_camera)
	_fit_camera.call_deferred()

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
	_result_labels = _ResultLabels.new(self)
	_result_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_result_labels)


func _fit_camera() -> void:
	if _camera == null or _frame == null:
		return
	if not _resolved.is_empty():
		_focus_result()
		return
	var aspect := _frame.size.x / maxf(_frame.size.y, 1.0)
	var span := (DiceTray.TRAY_HALF * 2.0 + 1.2) / minf(aspect, 1.0)
	var height := span * 0.5 / tan(deg_to_rad(_camera.fov * 0.5)) + 3.0
	_camera.position = Vector3(0, height, 0.001)


func _focus_result() -> void:
	var positions := _tray.die_positions()
	if positions.is_empty():
		return
	var low := positions[0]
	var high := positions[0]
	for point in positions:
		low = low.min(point)
		high = high.max(point)
	var center := (low + high) * 0.5
	var aspect := _frame.size.x / maxf(_frame.size.y, 1.0)
	var span := maxf(6.5, maxf(high.z - low.z + 3.5, (high.x - low.x + 3.5) / aspect))
	var height := maxf(DiceTray.WALL_HEIGHT + 2.0, span * 0.5 / tan(deg_to_rad(_camera.fov * 0.5)) + high.y)
	if _camera_tween != null:
		_camera_tween.kill()
	_camera_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(_camera, "position", Vector3(center.x, height, center.z + 0.001), 0.45)
	_result_labels.set_process(true)


func _build_impact_audio() -> void:
	# A small procedural wooden clack, independent of the simulation RNG.
	var samples := PackedByteArray()
	var sound_rng := RandomNumberGenerator.new()
	sound_rng.seed = 17
	for i in 2205:
		var t := float(i) / 22050.0
		var sample := (sound_rng.randf_range(-1.0, 1.0) * 0.6 + sin(t * TAU * 950.0) * 0.4) * exp(-t * 85.0)
		var value := int(sample * 20000.0)
		samples.append(value & 255)
		samples.append((value >> 8) & 255)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = samples
	_impact_player = AudioStreamPlayer.new()
	_impact_player.stream = stream
	_impact_player.max_polyphony = 4
	add_child(_impact_player)


func _play_impact(strength: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_impact_ms < 45:
		return
	_last_impact_ms = now
	_impact_player.volume_db = lerpf(-27.0, -12.0, strength)
	_impact_player.pitch_scale = lerpf(0.85, 1.15, strength)
	_impact_player.play()


func _sync_tray_aim() -> void:
	if _tray != null:
		_tray.set_aim(_hand_3d, _target_3d)
		_tray.set_throw_strength(_throw_strength)


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

	_reroll_button = Button.new()
	_reroll_button.name = "RerollButton"
	_reroll_button.text = "Throw Again"
	_reroll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reroll_button.custom_minimum_size = Vector2(0, 48)
	_reroll_button.visible = false
	_reroll_button.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.border, 8))
	_reroll_button.add_theme_font_size_override("font_size", Widgets.FONT_SUBHEADING)
	_reroll_button.add_theme_color_override("font_color", _palette.text)
	_reroll_button.pressed.connect(_on_reroll_pressed)
	actions.add_child(_reroll_button)

	_done_button = Button.new()
	_done_button.name = "DoneButton"
	_done_button.text = "Send Result" if _allow_reroll else "Continue"
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
	if _rolling or not _resolved.is_empty():
		return
	_rolling = true
	_roll_button.disabled = true
	_roll_button.text = "Rolling..."
	_tray_status.text = "Rolling…"
	# Keep the tray in the same screen position at the instant of launch.
	_instructions.modulate.a = 0.0
	if _explanation != null:
		_explanation.hide()
		_explanation_toggle.hide()
	_scroll.scroll_vertical = 0
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
	_tray_status.text = "Result" if not _tray.was_forced() else "Result • time limit reached"
	_tray_status.add_theme_color_override("font_color", _palette.accent)
	_outcome_card.visible = true
	_roll_button.visible = false
	_reroll_button.visible = _allow_reroll
	_done_button.visible = true
	_done_button.grab_focus()

	_context_note.visible = not _context_note.text.is_empty()
	_focus_result()
	_outcome_card.modulate.a = 0.0
	create_tween().tween_property(_outcome_card, "modulate:a", 1.0, 0.22)
	_scroll.scroll_vertical = 0


## Discard the GM's preview locally and make a fresh physical throw. Nothing is
## returned to the caller until Send Result is pressed, so rejected results
## never reach the transport or the campaign log.
func _on_reroll_pressed() -> void:
	if not _allow_reroll or _rolling or _resolved.is_empty():
		return
	_resolved.clear()
	if not _initial_check.is_empty():
		_check = Check.from_dict(_initial_check)
	_reroll_button.visible = false
	_done_button.visible = false
	_outcome_card.visible = false
	if _camera_tween != null:
		_camera_tween.kill()
	_fit_camera()
	if _result_labels != null:
		_result_labels.queue_redraw()
	_on_roll_pressed()


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
	_detail.text = "Control %d  %s situation  =  %d" % [control_face, sit_sign_str, total_roll]
	_outcome.text = "%s — %d" % [outcome_title, total_roll]

	var notes: Array = []
	var is_act := _check.skill_label.to_lower().contains("action check")
	if is_act:
		_outcome.text = "%s PHASE — %d" % [degree.to_upper(), total_roll]

	if is_crit_fail:
		notes.append("Natural 20 on Control Die: Critical Failure! Table G8 weapon mishap or setback occurs.")
	elif is_auto_succ:
		notes.append("Natural 1 on Control Die succeeds automatically!")

	if situation.rerolls > 0:
		notes.append("Cocked die detected: throw voided and re-thrown %d time%s." % [situation.rerolls, "" if situation.rerolls == 1 else "s"])

	_context_note.text = "\n".join(notes)


func _update_touch_filters(node: Node) -> void:
	for child in node.get_children():
		# This full-frame decoration is above the grip in draw order. PASS
		# bubbles to its parent, not to the grip sibling underneath it.
		if child == _result_labels:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			continue
		if child == _aim_overlay:
			child.mouse_filter = Control.MOUSE_FILTER_STOP
			continue
		if child is SubViewportContainer or child == _viewport:
			continue
		if child is Control and not (child is Button or child is LineEdit or child is TextEdit):
			child.mouse_filter = Control.MOUSE_FILTER_PASS
		_update_touch_filters(child)


# One real pointer owns a gesture. Synthetic duplicate events are ignored.
class _AimOverlay extends Control:
	var _host: Node
	var _dragging := false
	var _pointer := -2
	var _start := Vector2.ZERO
	var _pull := Vector2.ZERO

	func _init(host: Node) -> void:
		_host = host
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		resized.connect(_cancel)

	func _grip() -> Vector2:
		if _host._camera == null or not _host._camera.is_inside_tree():
			return Vector2(size.x * 0.5, size.y * 0.65)
		return _host._camera.unproject_position(_host._hand_3d)

	func _max_pull() -> float:
		# Leave space for the grip and ring below the player's finger.
		return maxf(20.0, minf(60.0, size.y - _grip().y - 44.0))

	func _power() -> float:
		return clampf(_pull.length() / _max_pull(), 0.0, 1.0)

	func _cancel() -> void:
		_dragging = false
		_pointer = -2
		_pull = Vector2.ZERO
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
			_cancel()

	func _gui_input(event: InputEvent) -> void:
		if _host._rolling or not _host._resolved.is_empty():
			return
		if event.device == -1:
			return
		var pos := Vector2.ZERO
		var down := false
		var up := false
		var pointer := -1
		if event is InputEventMouseButton:
			if event.button_index != MOUSE_BUTTON_LEFT:
				return
			pos = event.position
			down = event.pressed
			up = not event.pressed
		elif event is InputEventMouseMotion:
			pos = event.position
		elif event is InputEventScreenTouch:
			pointer = event.index
			pos = event.position
			down = event.pressed
			up = not event.pressed
			if event.canceled and pointer == _pointer:
				_cancel()
				return
		elif event is InputEventScreenDrag:
			pointer = event.index
			pos = event.position
		else:
			return
		accept_event()
		if down:
			if not _dragging and pos.distance_to(_grip()) <= 54.0:
				_dragging = true
				_pointer = pointer
				_start = pos
		elif _dragging and pointer == _pointer:
			var max_pull := _max_pull()
			_pull = (pos - _start).limit_length(max_pull)
			_pull.y = maxf(0.0, _pull.y)
			if up:
				var launch := _pull.y >= 14.0
				if launch:
					_host._throw_strength = _power()
					_host._target_3d = Vector3(clampf(-_pull.x / maxf(_pull.y, 20.0) * 3.0, -3.0, 3.0), 0.5, -1.5)
				_cancel()
				if launch:
					_host._on_roll_pressed()
		queue_redraw()

	func _draw() -> void:
		if _host._rolling or not _host._resolved.is_empty():
			return
		var grip := _grip()
		var accent: Color = _host._palette.accent
		var held := grip + _pull
		if _dragging:
			draw_circle(grip, 5, accent)
			draw_line(grip, held, accent, 1.5, true)
		draw_circle(held, 32, _host._palette.surface_soft)
		draw_arc(held, 32, 0, TAU, 48, accent, 2, true)
		for offset in [Vector2(-12, -7), Vector2(7, 5)]:
			draw_rect(Rect2(held + offset - Vector2(8, 8), Vector2(16, 16)), accent, false, 2)
		if _dragging and _pull.y >= 14:
			var direction := -_pull.normalized()
			var tip := grip + direction * (35 + _pull.length() * 0.6)
			draw_line(grip, tip, accent, 3, true)
			var side := direction.orthogonal() * 7
			draw_colored_polygon(PackedVector2Array([tip, tip - direction * 12 + side, tip - direction * 12 - side]), accent)
			draw_arc(held, 38, -PI * 0.5, -PI * 0.5 + TAU * _power(), 48, accent, 3, true)
		else:
			draw_line(grip + Vector2(0, 42), grip + Vector2(0, 68), accent, 2, true)
			draw_line(grip + Vector2(0, 68), grip + Vector2(-6, 60), accent, 2, true)
			draw_line(grip + Vector2(0, 68), grip + Vector2(6, 60), accent, 2, true)


class _ResultLabels extends Control:
	var _host: Node

	func _init(host: Node) -> void:
		_host = host
		set_process(false)

	func _process(_delta: float) -> void:
		queue_redraw()
		if _host._camera_tween == null or not _host._camera_tween.is_running():
			set_process(false)

	func _draw() -> void:
		if _host._resolved.is_empty():
			return
		var positions: Array[Vector3] = _host._tray.die_positions()
		var faces: Array = _host._tray.read_now()
		var font := get_theme_default_font()
		var projected: Array[Vector2] = []
		var occupied: Array[Rect2] = []
		for point in positions:
			var screen: Vector2 = _host._camera.unproject_position(point)
			projected.append(screen)
			occupied.append(Rect2(screen - Vector2(25, 25), Vector2(50, 50)))
		for i in positions.size():
			var label := str(faces[i]["number"])
			if _host._check != null:
				label = ("Control " if i == 0 else "Situation ") + label
			var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			var rect := Rect2()
			for offset in [Vector2(0, 42), Vector2(0, -42), Vector2(0, 72), Vector2(0, -72), Vector2(95, 0), Vector2(-95, 0)]:
				var point: Vector2 = projected[i] + offset
				point.x = clampf(point.x - width * 0.5, 6, maxf(6, _host._frame.size.x - width - 6))
				point.y = clampf(point.y, 24, _host._frame.size.y - 8)
				rect = Rect2(point - Vector2(5, 17), Vector2(width + 10, 24))
				var clear := true
				for other in occupied:
					if other.intersects(rect.grow(3)):
						clear = false
						break
				if clear:
					break
			occupied.append(rect)
			draw_line(projected[i], rect.get_center(), _host._palette.muted, 1, true)
			draw_style_box(Widgets.flat_style(_host._palette.surface, _host._palette.border, 4), rect)
			draw_string(font, rect.position + Vector2(5, 17), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, _host._palette.text)
