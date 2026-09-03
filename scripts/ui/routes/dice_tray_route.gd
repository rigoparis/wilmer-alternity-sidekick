extends RouteScene
##
## The tray, presented as somewhere you go to roll.
##
## Hosts the 3D tray in a SubViewport inside the Control tree, so the rest of the
## app stays a 2D UI and this is the only place a camera exists. The route waits
## for the dice to settle and closes with what they showed.
##
## Two things it is careful about:
##
##   * The number is never shown before the dice stop. The whole premise of a
##     physical tray is that the player watches the result happen, and a panel
##     that filled in early would make the tumbling decorative.
##   * There is always a way out. The tray guarantees a result -- it forces one
##     on timeout -- but the person can still leave, and leaving cancels rather
##     than inventing an outcome.
##
## Closes with {check, control, situation, graded} for an action check, or
## {results} for a plain roll, or null if dismissed before the dice settled.
##

const Check := preload("res://scripts/core/session/skill_check.gd")
const Tray := preload("res://scripts/core/dice/dice_tray.gd")
const Source := preload("res://scripts/core/dice/physical_dice_source.gd")

## How much of the route's height the tray takes. The rest is the check summary
## and the result.
const VIEWPORT_RATIO := 0.52

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

var _summary: Label
var _outcome: Label
var _detail: Label
var _roll_button: Button
var _done_button: Button

var _resolved: Dictionary = {}
var _rolling: bool = false


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


## A roll in progress must not be dismissed out from under the dice: the tray
## would keep simulating into a freed scene, and the player would lose a result
## that was about to exist anyway.
func is_dismissible() -> bool:
	return not _rolling


# --- Building --------------------------------------------------------------

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
	box.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	margin.add_child(box)

	var heading := Label.new()
	heading.text = title()
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size = Vector2(1, 0)
	heading.add_theme_color_override("font_color", _palette.text)
	heading.add_theme_font_size_override("font_size", Widgets.FONT_SECTION_TITLE)
	box.add_child(heading)

	_summary = Widgets.muted_text(box, _describe_what_is_being_rolled(), _palette, Widgets.FONT_DETAIL)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size = Vector2(1, 0)

	_build_viewport(box)

	_outcome = Widgets.text(box, "", _palette, 26, _palette.accent)
	_outcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outcome.custom_minimum_size = Vector2(1, 34)

	_detail = Widgets.muted_text(box, "", _palette, Widgets.FONT_DETAIL)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(1, 0)

	var actions := HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", Widgets.GAP_ROW)
	box.add_child(actions)

	var leave := Button.new()
	leave.name = "LeaveButton"
	leave.text = "Back"
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.custom_minimum_size = Vector2(0, 44)
	leave.pressed.connect(_on_leave_pressed)
	actions.add_child(leave)

	_roll_button = Button.new()
	_roll_button.name = "RollButton"
	_roll_button.text = "Throw"
	_roll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roll_button.custom_minimum_size = Vector2(0, 44)
	_roll_button.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
	_roll_button.pressed.connect(_on_roll_pressed)
	actions.add_child(_roll_button)

	_done_button = Button.new()
	_done_button.name = "DoneButton"
	_done_button.text = "Send"
	_done_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_done_button.custom_minimum_size = Vector2(0, 44)
	_done_button.visible = false
	_done_button.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
	_done_button.pressed.connect(func(): close(_resolved))
	actions.add_child(_done_button)


## The 3D tray, in its own viewport.
##
## A SubViewport rather than a Camera3D in the main scene: this app is a 2D UI
## with one 3D corner, and putting a camera in the shell would make every screen
## share a 3D world it has no use for.
func _build_viewport(parent: Container) -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.custom_minimum_size = Vector2(0, 220)
	parent.add_child(container)

	_viewport = SubViewport.new()
	_viewport.transparent_bg = false
	_viewport.own_world_3d = true
	_viewport.world_3d = World3D.new()
	# The dice have to keep simulating while the player watches them.
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_viewport)

	_tray = Tray.new()
	_viewport.add_child(_tray)
	_tray.configure(_palette)
	# No signal connection here: the route awaits PhysicalDiceSource, which awaits
	# the tray. One listener, one place the result is assembled.
	_source = Source.new(_tray)

	var camera := Camera3D.new()
	camera.fov = 45.0
	# Framed to the tray rather than parked at a guessed height. The height that
	# makes a 9-unit tray fill a 45-degree view is arithmetic, and hardcoding a
	# number instead is how the dice ended up as specks the first time.
	#
	# Vertical FOV, so this frames the tray's depth; a wide window gets margins at
	# the sides, which is the right way round -- a phone is the tight case.
	var span := DiceTray.TRAY_HALF * 2.0 + 1.0
	var height := (span * 0.5) / tan(deg_to_rad(camera.fov * 0.5))
	# Straight down. Every die is read by what points up, so the camera shows the
	# player exactly what the tray is about to read.
	#
	# look_at_from_position rather than look_at: a route is configured before the
	# router adds it to the tree, and look_at on a node outside the tree fails and
	# leaves the camera pointing at the horizon.
	camera.look_at_from_position(
		Vector3(0, maxf(height, DiceTray.WALL_HEIGHT + 2.0), 0.001), Vector3.ZERO, Vector3.FORWARD
	)
	_viewport.add_child(camera)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-62, -35, 0)
	key.light_energy = 1.5
	_viewport.add_child(key)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = _palette.background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _palette.surface_soft
	env.ambient_light_energy = 1.2
	environment.environment = env
	_viewport.add_child(environment)


# --- What is being rolled --------------------------------------------------

func _describe_what_is_being_rolled() -> String:
	if _check == null:
		return _label

	var parts: Array = ["Score %d / %d / %d" % [_check.ordinary, _check.good, _check.amazing]]
	# Both halves of the step, named. A single number would leave the player
	# unable to tell a hard situation from an encumbered hero.
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
	_outcome.text = ""
	_detail.text = ""

	if _check != null:
		await _roll_check()
	else:
		await _roll_plain()

	if not is_instance_valid(self):
		return
	_rolling = false
	_roll_button.visible = false
	_done_button.visible = true
	_done_button.grab_focus()


func _roll_check() -> void:
	var control_term := DiceNotation.parse("d20")
	var situation_term := DiceNotation.parse(_situation_notation())
	var results: Array = await _source.roll_group([control_term, situation_term], _check.skill_label)
	if not is_instance_valid(self) or results.size() < 2:
		return

	var control: RollResult = results[0]
	var situation: RollResult = results[1]
	var control_face: int = control.dice[0] if not control.dice.is_empty() else 20

	# The rules grade it. A route that decided Good or Amazing itself would be a
	# second implementation of the one table everything else reads.
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

	_outcome.text = str(total)
	var faces: Array = []
	for result in results:
		for face in (result as RollResult).dice:
			faces.append(str(face))
	_detail.text = "  ".join(faces) if not faces.is_empty() else "no dice"


func _show_check_outcome(control_face: int, situation: RollResult, graded: Dictionary) -> void:
	var degree := String(graded.get("degree", ""))
	_outcome.text = degree
	_outcome.add_theme_color_override(
		"font_color",
		_palette.accent if bool(graded.get("is_success", false)) else _palette.warning
	)

	var parts: Array = ["control %d" % control_face]
	if not situation.dice.is_empty():
		parts.append("situation %s%d" % ["+" if situation.sign > 0 else "-", absi(situation.total)])
	parts.append("total %d vs %d" % [AlternityNum.as_int(graded.get("total", 0)), _check.ordinary])
	if bool(graded.get("is_critical_failure", false)):
		parts.append("a 20 on the control die is a critical failure")
	elif bool(graded.get("is_auto_success", false)):
		parts.append("a 1 on the control die succeeds automatically")
	if situation.rerolls > 0:
		# Honest about it. The throw was voided and re-thrown, and the log will
		# say so too.
		parts.append("re-thrown %d time%s" % [situation.rerolls, "" if situation.rerolls == 1 else "s"])
	_detail.text = "  -  ".join(parts)


func _on_leave_pressed() -> void:
	# Leaving before the dice settle cancels rather than inventing an outcome.
	close(_resolved if not _resolved.is_empty() else null)
