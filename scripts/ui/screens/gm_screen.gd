class_name GmScreen
extends Control
##
## What the GM looks at while running a session.
##
## Four things, in the order a GM needs them mid-session:
##
##   1. Checks -- anyone waiting on a ruling, and the button that calls for one.
##      First because somebody is holding dice until the GM answers.
##   2. The roster -- one row per player: who they are, who they are playing, the
##      numbers a GM asks for out loud, and their achievement points. Tapping a
##      row opens that character's sheet.
##   3. Chat, including private lines to one player.
##   4. The log.
##
## What is deliberately not here is everything about *running the table* as
## opposed to running the game: opening and closing it, removing a seat, leaving
## the campaign. Those live behind TableSettingsRoute, because each is rare,
## disruptive, and was previously one mis-tap from ending a session four people
## were in the middle of.
##
## Three things this screen used to be able to do and no longer can, all for the
## same reason -- the GM runs the game, the players own their characters:
##
##   * choose which hero a player is using. A player commits their own.
##   * add a seat. Joining makes one; there is nothing to add.
##   * hand the GM role to somebody else. There is one GM: the device hosting.
##
## Every number shown about a character is derived from the committed character
## through the rules engine, never recomputed here, so this screen and the sheet
## the player is looking at cannot drift apart.
##

## Leave the campaign and return to the campaign list.
signal closed

## How much of the log the feed shows. The log itself is unbounded; this is not.
const FEED_LENGTH := 60

## How often the connected-player line is redrawn, in seconds. The transport
## answers packets as they arrive; this only paces the presence display.
const PRESENCE_INTERVAL := 1.0

## How many skill shortcuts to offer. Enough to cover what a table actually
## reaches for, short enough to read at a glance.
const SHORTCUT_COUNT := 6

const AP_AWARD_ROUTE := preload("res://scenes/ui/routes/ap_award_route.tscn")
const CHECK_STEP_ROUTE := preload("res://scenes/ui/routes/check_step_route.tscn")
const CHARACTER_VIEW_ROUTE := preload("res://scenes/ui/routes/character_view_route.tscn")
const DICE_TRAY_ROUTE := preload("res://scenes/ui/routes/dice_tray_route.tscn")
const SKILL_PICK_ROUTE := preload("res://scenes/ui/routes/skill_pick_route.tscn")
const TABLE_SETTINGS_ROUTE := preload("res://scenes/ui/routes/table_settings_route.tscn")

var _session: CampaignSession
var _store: CampaignStore
var _characters: CharacterStore
var _rules
var _router: UiRouter
var _palette: ThemePalette

## The table, when it is open. Null until the GM opens it from settings; the
## screen is fully usable without one.
var _transport: EnetTransport
var _discovery: LanDiscovery
var _hosting: bool = false
var _presence_clock: float = 0.0

## Checks players are waiting on a ruling for, oldest first.
##
## A queue rather than a single pending check: at a table two players ask at
## once, and the second must not silently replace the first.
var _pending_checks: Array = []

## The fight in progress, or null. Held here for convenience; the campaign is
## where it actually lives, so a screen rebuild picks it back up.
var _fight: ActionRound
var _combat_body: VBoxContainer

var _title: Label
var _status: Label
var _checks_list: VBoxContainer
var _checks_note: Label
var _shortcut_row: GridContainer
var _roster_list: VBoxContainer
var _roster_note: Label
var _chat_field: LineEdit
var _chat_target: OptionButton
var _feed_list: VBoxContainer
var _feed_empty: Label

## Derived summaries for this render, so six rows do not each re-summarize the
## same character.
var _summary_cache: Dictionary = {}


func setup(
	session: CampaignSession,
	store: CampaignStore,
	characters: CharacterStore,
	rules,
	router: UiRouter,
	palette: ThemePalette
) -> void:
	_session = session
	_store = store
	_characters = characters
	_rules = rules
	_router = router
	_palette = palette
	# The fight lives on the campaign, so a screen rebuilt for a theme change or
	# reopened next week picks it back up rather than losing whose turn it is.
	_adopt_stored_round()
	_build()
	refresh()


func session() -> CampaignSession:
	return _session


# --- Building --------------------------------------------------------------

func _build() -> void:
	var root_box := VBoxContainer.new()
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_box.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	add_child(root_box)

	_build_header(root_box)

	var column := Widgets.page_column(root_box, _is_wide())
	column.add_theme_constant_override("separation", 20)

	_build_combat(column)
	_build_checks(column)
	_build_roster(column)
	_build_chat(column)

	var feed := Widgets.section(column, "Session log", _palette)
	_feed_empty = Widgets.muted_text(feed, "Nothing has happened yet.", _palette)
	_feed_list = VBoxContainer.new()
	_feed_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feed_list.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	feed.add_child(_feed_list)


## Campaign name, table status, and the way to the settings.
##
## One button, because everything disruptive is behind it. A header full of
## actions is how "Close" ends up next to "Award AP".
func _build_header(parent: Container) -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.PAD_PANEL)
	parent.add_child(margin)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	margin.add_child(row)

	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 0)
	row.add_child(names)

	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.custom_minimum_size = Vector2(1, 0)
	_title.add_theme_color_override("font_color", _palette.text)
	_title.add_theme_font_size_override("font_size", 22 if _is_wide() else 18)
	names.add_child(_title)

	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.custom_minimum_size = Vector2(1, 0)
	_status.add_theme_color_override("font_color", _palette.muted)
	_status.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	names.add_child(_status)

	var settings := Button.new()
	settings.name = "TableSettingsButton"
	settings.text = "Table"
	settings.custom_minimum_size = Vector2(84, 40)
	settings.tooltip_text = "Open or close the table, manage seats, leave the campaign"
	_allow_narrow(settings)
	settings.pressed.connect(_on_settings_pressed)
	row.add_child(settings)


## The fight, when there is one.
##
## Above Checks because during a fight this is the thing with people waiting on
## it -- a player is holding dice until the phase moves.
func _build_combat(parent: Container) -> void:
	var section := Widgets.section(parent, "Combat", _palette)
	_combat_body = VBoxContainer.new()
	_combat_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_combat_body.add_theme_constant_override("separation", Widgets.GAP_ROW)
	section.add_child(_combat_body)


func _render_combat() -> void:
	if _combat_body == null:
		return
	for child in _combat_body.get_children():
		_combat_body.remove_child(child)
		child.queue_free()

	if _fight == null:
		var note := Widgets.muted_text(
			_combat_body,
			"No fight running. Starting one asks every player for an action check.",
			_palette,
			Widgets.FONT_CAPTION
		)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(1, 0)
		var start := _small_button("Start combat", _on_start_combat_pressed)
		start.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
		_combat_body.add_child(start)
		return

	var heading := Widgets.text(_combat_body, _fight.describe(), _palette, Widgets.FONT_SUBHEADING, _palette.accent)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size = Vector2(1, 0)

	if _fight.state == ActionRound.STATE_ROLLING:
		_render_waiting_for_checks()
	else:
		_render_acting_order()

	var actions := GridContainer.new()
	actions.columns = 2
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("h_separation", Widgets.GAP_ROW)
	actions.add_theme_constant_override("v_separation", Widgets.GAP_ROW)
	_combat_body.add_child(actions)

	if _fight.state == ActionRound.STATE_ROLLING:
		var begin := _small_button("Start the round", _on_start_round_pressed)
		begin.disabled = not _fight.has_all_checks()
		if not begin.disabled:
			begin.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
		actions.add_child(begin)
	elif _fight.is_finished():
		var again := _small_button("Next round", _on_next_round_pressed)
		again.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
		actions.add_child(again)
	else:
		var advance := _small_button("End %s phase" % _fight.phase_name(), _on_advance_phase_pressed)
		advance.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
		actions.add_child(advance)

	var stop := _small_button("End combat", _on_end_combat_pressed)
	stop.add_theme_color_override("font_color", _palette.warning)
	actions.add_child(stop)


func _render_waiting_for_checks() -> void:
	var owed: Array = _fight.awaiting_checks()
	if owed.is_empty():
		Widgets.muted_text(_combat_body, "Everyone has rolled.", _palette, Widgets.FONT_CAPTION)
		return

	for player_id in owed:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", Widgets.GAP_ROW)
		_combat_body.add_child(row)

		var name_label := Label.new()
		name_label.text = "%s has not rolled" % String(_fight.combatant(String(player_id)).get("name", "Someone"))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.custom_minimum_size = Vector2(1, 0)
		name_label.add_theme_color_override("font_color", _palette.muted)
		name_label.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
		row.add_child(name_label)

		# An escape hatch for a player who has gone to make tea, rather than the
		# whole table waiting on one device.
		var roll_for = _small_button("Roll for them", _on_roll_for_pressed.bind(String(player_id)))
		roll_for.custom_minimum_size = Vector2(112, 32)
		roll_for.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_child(roll_for)


## Who acts in this phase, in the order they act.
func _render_acting_order() -> void:
	var acting: Array = _fight.acting_now()
	if acting.is_empty():
		Widgets.muted_text(
			_combat_body,
			"Nobody rolled well enough to act in this phase.",
			_palette,
			Widgets.FONT_CAPTION
		)
	var position := 0
	for entry in acting:
		position += 1
		var line := "%d. %s   (score %d)" % [
			position,
			String(entry.get("name", "Someone")),
			AlternityNum.as_int(entry.get("check_score", 0)),
		]
		# Somebody dropped this phase is still finishing what they declared, and
		# saying so is the difference between a bug and the rule.
		if bool(entry.get("pending_out", false)):
			line += "   -- going down"
		var row := Widgets.text(_combat_body, line, _palette, Widgets.FONT_DETAIL)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(1, 0)

	var sidelined: Array = []
	for entry in _fight.combatants:
		if bool(entry.get("out", false)):
			sidelined.append("%s (%s)" % [
				String(entry.get("name", "someone")),
				String(entry.get("out_reason", "out")),
			])
	if not sidelined.is_empty():
		var note := Widgets.muted_text(
			_combat_body, "Out: " + ", ".join(sidelined), _palette, Widgets.FONT_CAPTION
		)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(1, 0)


# --- Running the fight -----------------------------------------------------

## Everyone at the table who is playing a character, as combatants.
##
## The GM's own seat is not in it, and neither is anyone who has not committed a
## character -- there is nothing to roll an action check with.
func _on_start_combat_pressed() -> void:
	var fight := ActionRound.new(1)
	for seat in _session.seats:
		if bool(seat.get("is_gm", false)):
			continue
		var player_id := String(seat.get("player_id", ""))
		var snapshot := _session.committed_character(player_id)
		if not CharacterSnapshot.is_usable(snapshot):
			continue
		var summary := _summary_of(snapshot)
		fight.add_combatant(
			player_id,
			String(seat.get("player_name", "Someone")),
			AlternityNum.as_int(summary.get("action_check", {}).get("actions", 1), 1)
		)

	if fight.combatants.is_empty():
		_status.text = "Nobody has committed a character to fight with."
		_status.add_theme_color_override("font_color", _palette.warning)
		return

	_fight = fight
	_publish_round()


func _on_start_round_pressed() -> void:
	if _fight == null or not _fight.start():
		return
	_publish_round()


func _on_advance_phase_pressed() -> void:
	if _fight == null:
		return
	_fight.advance_phase()
	_publish_round()


func _on_next_round_pressed() -> void:
	if _fight == null:
		return
	_fight = _fight.next_round()
	_publish_round()


func _on_end_combat_pressed() -> void:
	_fight = null
	_session.clear_round()
	_store.save(_session)
	if _hosting and _transport != null:
		_transport.send_round({})
	refresh()


## An action check the GM rolled on somebody's behalf.
##
## Uses their own character, so a player who stepped away is not penalised for
## it -- the GM is standing in, not substituting a different hero.
func _on_roll_for_pressed(player_id: String) -> void:
	if _fight == null or _router == null:
		return
	var snapshot := _session.committed_character(player_id)
	var summary := _summary_of(snapshot)
	if summary.is_empty():
		return
	var score: Dictionary = summary.get("action_check", {})

	var stand_in := SkillCheck.new(player_id, SkillCheck.ORIGIN_GM)
	stand_in.skill_label = "Action check"
	stand_in.ordinary = AlternityNum.as_int(score.get("ordinary", 0))
	stand_in.good = AlternityNum.as_int(score.get("good", 0))
	stand_in.amazing = AlternityNum.as_int(score.get("amazing", 0))
	stand_in.player_step = AlternityNum.as_int(score.get("step", 0))

	var outcome = await _router.push(DICE_TRAY_ROUTE, {
		"palette": _palette,
		"rules": _rules,
		"check": stand_in.to_dict(),
	})
	if not is_instance_valid(self) or typeof(outcome) != TYPE_DICTIONARY or not outcome.has("check"):
		return
	var rolled := SkillCheck.from_dict(outcome["check"])
	_record_action_check(player_id, {
		"degree": rolled.degree(),
		"check_score": rolled.ordinary,
		"roll": AlternityNum.as_int(rolled.result.get("total", 0)),
		"critical": bool(rolled.result.get("is_critical_failure", false)),
	})


func _on_action_check_received(player_id: String, result: Dictionary) -> void:
	_record_action_check(player_id, result)


func _record_action_check(player_id: String, result: Dictionary) -> void:
	if _fight == null:
		return
	_fight.record_check(
		player_id,
		String(result.get("degree", "Failure")),
		AlternityNum.as_int(result.get("check_score", 0)),
		AlternityNum.as_int(result.get("roll", 0)),
		bool(result.get("critical", false))
	)
	_publish_round()


## Save the round and push it to the table.
##
## One place, because the campaign's copy and the players' copies must never
## disagree about whose turn it is.
func _publish_round() -> void:
	if _fight == null:
		return
	_session.set_round(_fight.to_dict())
	_store.save(_session)
	if _hosting and _transport != null:
		_transport.send_round(_fight.to_dict())
	refresh()


## Checks waiting on the GM, the call button, and the shortcuts.
func _build_checks(parent: Container) -> void:
	var section := Widgets.section(parent, "Checks", _palette)

	_checks_note = Widgets.muted_text(section, "Nobody is waiting on a ruling.", _palette, Widgets.FONT_CAPTION)
	_checks_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_checks_note.custom_minimum_size = Vector2(1, 0)

	_checks_list = VBoxContainer.new()
	_checks_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_checks_list.add_theme_constant_override("separation", Widgets.GAP_ROW)
	section.add_child(_checks_list)

	# The skills this table reaches for, straight on the main screen. A GM asking
	# for Awareness for the fortieth time should not have to open a catalogue.
	_shortcut_row = GridContainer.new()
	_shortcut_row.columns = 3 if _is_wide() else 2
	_shortcut_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shortcut_row.add_theme_constant_override("h_separation", Widgets.GAP_ROW)
	_shortcut_row.add_theme_constant_override("v_separation", Widgets.GAP_ROW)
	section.add_child(_shortcut_row)

	var call_button := Button.new()
	call_button.name = "CallCheckButton"
	call_button.text = "Call for a check"
	call_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	call_button.custom_minimum_size = Vector2(0, 40)
	call_button.tooltip_text = "Ask a player, or the whole table, to roll something"
	_allow_narrow(call_button)
	call_button.pressed.connect(_on_call_check_pressed)
	section.add_child(call_button)


func _build_roster(parent: Container) -> void:
	var section := Widgets.section(parent, "The table", _palette)

	_roster_note = Widgets.muted_text(
		section,
		"Nobody has joined yet. Open the table from Table settings, and players on the same Wi-Fi can find it.",
		_palette,
		Widgets.FONT_CAPTION
	)
	_roster_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_roster_note.custom_minimum_size = Vector2(1, 0)

	_roster_list = VBoxContainer.new()
	_roster_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_list.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	section.add_child(_roster_list)

	var table_award := Button.new()
	table_award.name = "TableAwardButton"
	table_award.text = "Award the whole party"
	table_award.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table_award.custom_minimum_size = Vector2(0, 38)
	table_award.tooltip_text = "For finishing an adventure. Roleplaying and heroism are awarded to one player."
	_allow_narrow(table_award)
	table_award.pressed.connect(_on_table_award_pressed)
	section.add_child(table_award)


func _build_chat(parent: Container) -> void:
	var section := Widgets.section(parent, "Say something", _palette)

	_chat_target = OptionButton.new()
	_chat_target.name = "ChatTargetPicker"
	_chat_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_target.custom_minimum_size = Vector2(0, 36)
	Widgets.field_row(section, "Say to", _chat_target, _palette)

	_chat_field = LineEdit.new()
	_chat_field.name = "ChatField"
	_chat_field.placeholder_text = "Message the table"
	_chat_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_field.custom_minimum_size = Vector2(0, 40)
	_chat_field.text_submitted.connect(func(_text: String): _send_chat())
	section.add_child(_chat_field)

	var send := Button.new()
	send.name = "SendChatButton"
	send.text = "Send"
	send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	send.custom_minimum_size = Vector2(0, 36)
	_allow_narrow(send)
	send.pressed.connect(_send_chat)
	section.add_child(send)


func _is_wide() -> bool:
	return get_viewport_rect().size.x >= ModalHost.COMPACT_WIDTH


# --- Rendering -------------------------------------------------------------

func refresh() -> void:
	if _session == null or _roster_list == null:
		return
	_summary_cache.clear()
	_title.text = _session.display_name
	_render_status()
	_render_checks()
	_render_shortcuts()
	_render_combat()
	_render_roster()
	_render_chat_targets()
	_render_feed()


## Put the campaign's copy of the fight back after a rebuild.
func _adopt_stored_round() -> void:
	if _session != null and _session.has_round():
		_fight = ActionRound.from_dict(_session.current_round())


func _render_status() -> void:
	if _status == null:
		return
	if not _hosting or _transport == null:
		_status.text = "Table closed"
		_status.add_theme_color_override("font_color", _palette.muted)
		return

	var connected: Array = _transport.connected_players()
	_status.text = "Table open  -  %s" % (
		"nobody connected yet" if connected.is_empty()
		else "%d %s connected" % [connected.size(), "player" if connected.size() == 1 else "players"]
	)
	_status.add_theme_color_override("font_color", _palette.accent)


func _render_checks() -> void:
	if _checks_list == null:
		return
	for child in _checks_list.get_children():
		_checks_list.remove_child(child)
		child.queue_free()

	_checks_note.visible = _pending_checks.is_empty()
	for check in _pending_checks:
		_build_pending_check(check)


func _build_pending_check(check: SkillCheck) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
	_checks_list.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.GAP_ROW)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	margin.add_child(box)

	var who := String(_session.seat_for(check.player_id).get("player_name", "Someone"))
	var heading := Widgets.text(box, "%s wants to roll %s" % [who, check.skill_label], _palette, Widgets.FONT_BODY)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size = Vector2(1, 0)

	# The score, which is what a GM rules against. Read-only: the GM sets the
	# difficulty, never the character.
	Widgets.muted_text(
		box,
		"Score %d / %d / %d   -   their own modifiers %+d" % [
			check.ordinary, check.good, check.amazing, check.player_step
		],
		_palette,
		Widgets.FONT_CAPTION
	)

	var actions := GridContainer.new()
	actions.columns = 3 if _is_wide() else 2
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("h_separation", Widgets.GAP_ROW)
	actions.add_theme_constant_override("v_separation", Widgets.GAP_ROW)
	box.add_child(actions)

	# The common answer is "just roll it", so it is one tap and not a dialog.
	var straight := _small_button("Ordinary", _on_rule_pressed.bind(check, 0))
	straight.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface, _palette.accent, 6))
	actions.add_child(straight)
	actions.add_child(_small_button("Set steps...", _on_rule_with_steps_pressed.bind(check)))
	var refuse := _small_button("Refuse", _on_refuse_check_pressed.bind(check))
	refuse.add_theme_color_override("font_color", _palette.warning)
	actions.add_child(refuse)


func _render_shortcuts() -> void:
	if _shortcut_row == null:
		return
	for child in _shortcut_row.get_children():
		_shortcut_row.remove_child(child)
		child.queue_free()

	for entry in _session.most_checked(SHORTCUT_COUNT):
		var skill: Dictionary = _rules.get_skill_by_id(AlternityNum.as_int(entry.get("skill_id", -1), -1))
		if skill.is_empty():
			continue
		var button := _small_button(_rules.skill_label(skill), _on_shortcut_pressed.bind(skill))
		button.tooltip_text = "Called %d times at this table" % AlternityNum.as_int(entry.get("count", 0))
		_shortcut_row.add_child(button)


## One row per player: who they are, who they are playing, and their numbers.
##
## The GM's own seat is not listed. It carries no character and cannot be awarded
## points, so a row for it is a row of blanks.
func _render_roster() -> void:
	for child in _roster_list.get_children():
		_roster_list.remove_child(child)
		child.queue_free()

	var players := 0
	for seat in _session.seats:
		if bool(seat.get("is_gm", false)):
			continue
		_build_roster_card(seat)
		players += 1
	_roster_note.visible = players == 0


func _build_roster_card(seat: Dictionary) -> void:
	var player_id := String(seat.get("player_id", ""))
	var snapshot := _session.committed_character(player_id)
	var has_character := CharacterSnapshot.is_usable(snapshot)
	var connected: bool = _hosting and _transport != null and _transport.connected_players().has(player_id)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		Widgets.flat_style(_palette.surface, _palette.accent if connected else _palette.border, 8)
	)
	_roster_list.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.PAD_PANEL)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", Widgets.GAP_ROW)
	margin.add_child(box)

	var top := HBoxContainer.new()
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override("separation", Widgets.GAP_ROW)
	box.add_child(top)

	# The hero's name is the button, so the affordance and the label are the same
	# thing. A card that is silently clickable is a card nobody clicks.
	var open_sheet := Button.new()
	open_sheet.text = CharacterSnapshot.hero_name_of(snapshot) if has_character else "No character yet"
	open_sheet.alignment = HORIZONTAL_ALIGNMENT_LEFT
	open_sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_sheet.custom_minimum_size = Vector2(0, 38)
	open_sheet.disabled = not has_character
	open_sheet.tooltip_text = "Open this character's sheet"
	open_sheet.add_theme_font_size_override("font_size", Widgets.FONT_SECTION_TITLE)
	_allow_narrow(open_sheet)
	if has_character:
		open_sheet.pressed.connect(_on_open_sheet_pressed.bind(player_id))
	top.add_child(open_sheet)

	var ap := Label.new()
	ap.text = "%d AP" % _session.get_seat_ap(player_id)
	ap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ap.add_theme_color_override("font_color", _palette.accent)
	ap.add_theme_font_size_override("font_size", Widgets.FONT_SUBHEADING)
	ap.size_flags_horizontal = Control.SIZE_SHRINK_END
	top.add_child(ap)

	var subtitle := "%s%s" % [
		String(seat.get("player_name", "Someone")),
		"  -  connected" if connected else "",
	]
	Widgets.muted_text(box, subtitle, _palette, Widgets.FONT_CAPTION)

	if has_character:
		_build_key_numbers(box, snapshot)
	else:
		Widgets.muted_text(
			box, "Waiting for them to choose a hero.", _palette, Widgets.FONT_CAPTION
		)

	var actions := GridContainer.new()
	actions.columns = 2
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("h_separation", Widgets.GAP_ROW)
	actions.add_theme_constant_override("v_separation", Widgets.GAP_ROW)
	box.add_child(actions)

	var award := _small_button("Award AP", _on_award_pressed.bind(player_id))
	award.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
	actions.add_child(award)
	var adjust := _small_button("Set AP", _on_set_ap_pressed.bind(player_id))
	adjust.tooltip_text = "Correct this seat's achievement point total"
	actions.add_child(adjust)


## Durability, action check and last resorts -- what a GM asks a player for.
##
## Derived from the committed character through the rules engine, so this screen
## and the player's own sheet cannot disagree about a number.
func _build_key_numbers(parent: Container, snapshot: Dictionary) -> void:
	var summary := _summary_of(snapshot)
	if summary.is_empty():
		Widgets.muted_text(
			parent,
			"Sent by a version of the app this one cannot read.",
			_palette,
			Widgets.FONT_CAPTION
		)
		return

	var durability: Dictionary = summary.get("durability", {})
	var action: Dictionary = summary.get("action_check", {})
	var resorts: Dictionary = summary.get("last_resorts", {})

	var grid := GridContainer.new()
	grid.columns = 3 if _is_wide() else 1
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", Widgets.GAP_SECTION)
	grid.add_theme_constant_override("v_separation", Widgets.GAP_TIGHT)
	parent.add_child(grid)

	_metric(grid, "Durability", "%d/%d/%d/%d" % [
		AlternityNum.as_int(durability.get("stun", 0)),
		AlternityNum.as_int(durability.get("wound", 0)),
		AlternityNum.as_int(durability.get("mortal", 0)),
		AlternityNum.as_int(durability.get("fatigue", 0)),
	])
	_metric(grid, "Action check", "%d/%d/%d %s" % [
		AlternityNum.as_int(action.get("ordinary", 0)),
		AlternityNum.as_int(action.get("good", 0)),
		AlternityNum.as_int(action.get("amazing", 0)),
		String(action.get("die", "")),
	])
	_metric(grid, "Last resorts", "%d of %d" % [
		AlternityNum.as_int(resorts.get("available", 0)),
		AlternityNum.as_int(resorts.get("max", 0)),
	])


func _metric(parent: Container, name: String, value: String) -> void:
	var box := VBoxContainer.new()
	# Expanding is load-bearing. A GridContainer sizes a column to the widest
	# minimum among its children and only stretches it for a child that expands;
	# the wrapping labels inside report a 1px minimum, so without this the column
	# collapses and "Durability" comes out one letter per line.
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	parent.add_child(box)
	Widgets.muted_text(box, name, _palette, Widgets.FONT_CAPTION)
	Widgets.text(box, value, _palette, Widgets.FONT_SUBHEADING)


## The rules-derived summary of a committed character, cached for this render.
func _summary_of(snapshot: Dictionary) -> Dictionary:
	var key := String(snapshot.get("hero_name", "")) + "@" + str(snapshot.get("taken_at", 0))
	if _summary_cache.has(key):
		return _summary_cache[key]
	var character := CharacterSnapshot.character_of(snapshot)
	var summary: Dictionary = _rules.summary(character) if not character.is_empty() else {}
	_summary_cache[key] = summary
	return summary


## Rebuild the chat recipient list from the current seats.
##
## Selection is preserved by player_id rather than by index: a seat removed above
## the chosen one would otherwise silently retarget a private line at somebody
## else.
func _render_chat_targets() -> void:
	if _chat_target == null:
		return
	var previous := ""
	if _chat_target.get_selected() >= 0:
		previous = String(_chat_target.get_item_metadata(_chat_target.get_selected()))

	_chat_target.clear()
	_chat_target.add_item("Everyone")
	_chat_target.set_item_metadata(0, "")
	var restore := 0
	var index := 1
	for seat in _session.seats:
		if bool(seat.get("is_gm", false)):
			continue
		var player_id := String(seat.get("player_id", ""))
		_chat_target.add_item("Only %s" % String(seat.get("player_name", "this seat")))
		_chat_target.set_item_metadata(index, player_id)
		if player_id == previous:
			restore = index
		index += 1
	_chat_target.select(restore)


func _render_feed() -> void:
	if _feed_list == null:
		return
	for child in _feed_list.get_children():
		_feed_list.remove_child(child)
		child.queue_free()

	var recent: Array = _session.recent_events(FEED_LENGTH)
	_feed_empty.visible = recent.is_empty()

	# Newest first: mid-session the GM cares about the last thing that happened,
	# and scrolling to the bottom of a year of play to find it is absurd.
	recent.reverse()
	for event in recent:
		var row := Label.new()
		row.text = _describe_event(event)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(1, 0)
		row.add_theme_color_override("font_color", _palette.text)
		row.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
		_feed_list.add_child(row)


## One line of log, readable without knowing the payload shape.
func _describe_event(event: Dictionary) -> String:
	var kind := String(event.get("kind", ""))
	var who := _player_name(String(event.get("player_id", "")))
	var payload: Dictionary = event.get("payload", {}) if typeof(event.get("payload")) == TYPE_DICTIONARY else {}
	var stamp := _time_of(AlternityNum.as_int(event.get("at", 0)))

	match kind:
		CampaignSession.EVENT_ROLL:
			var label := String(payload.get("label", ""))
			var notation := String(payload.get("notation", ""))
			var what := label if not label.is_empty() else notation
			# A check roll says what it was against. A bare total is unreadable a
			# week later, and the degree is the part a table actually remembers.
			var check_data = payload.get("check", {})
			if typeof(check_data) == TYPE_DICTIONARY and not check_data.is_empty():
				var check := SkillCheck.from_dict(check_data)
				var degree := check.degree()
				if not degree.is_empty():
					return "%s  %s rolled %s: %s" % [stamp, who, check.describe(), degree]
			return "%s  %s rolled %s: %d" % [
				stamp, who, what, AlternityNum.as_int(payload.get("total", 0))
			]
		CampaignSession.EVENT_CHAT:
			var to := String(payload.get("to", ""))
			var prefix := "%s  %s" % [stamp, who]
			if not to.is_empty():
				# Private lines are marked, so a GM reading the log later knows
				# the table did not see it.
				prefix += " (private to %s)" % _player_name(to)
			return "%s: %s" % [prefix, String(payload.get("text", ""))]
		CampaignSession.EVENT_AP_AWARD:
			return "%s  %s awarded %d AP (%s) -- now %d" % [
				stamp, who,
				AlternityNum.as_int(payload.get("amount", 0)),
				String(payload.get("reason", "")),
				AlternityNum.as_int(payload.get("new_ap", 0)),
			]
		CampaignSession.EVENT_AP_SET:
			return "%s  %s AP set to %d (was %d)" % [
				stamp, who,
				AlternityNum.as_int(payload.get("new_ap", 0)),
				AlternityNum.as_int(payload.get("previous_ap", 0)),
			]
		CampaignSession.EVENT_CHECK:
			return "%s  the GM called for %s" % [stamp, SkillCheck.from_dict(payload).describe()]
		CampaignSession.EVENT_JOIN:
			return "%s  %s joined" % [stamp, who]
		CampaignSession.EVENT_NOTE:
			return "%s  note: %s" % [stamp, String(payload.get("text", ""))]
	return "%s  %s: %s" % [stamp, kind, who]


func _time_of(unix: int) -> String:
	if unix <= 0:
		return "--:--"
	var t := Time.get_datetime_dict_from_unix_time(unix)
	return "%02d:%02d" % [t["hour"], t["minute"]]


func _player_name(player_id: String) -> String:
	if player_id.is_empty():
		return "the table"
	var seat := _session.seat_for(player_id)
	# A removed seat still has events in the log; showing a raw 32-hex id would
	# be unreadable, so say plainly that they are gone.
	return String(seat.get("player_name", "a departed player")) if not seat.is_empty() else "a departed player"


func _small_button(label: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 36)
	_allow_narrow(button)
	button.pressed.connect(handler)
	return button


## Let a button be narrower than its own text.
##
## A Button reports its full text width as its minimum, so a row of them pushes
## its container past the screen and the last one is simply unreachable -- the
## page column has horizontal scrolling disabled. Skill names are the worst of
## it: "Armor Operation - Combat armor" is wider than a phone on its own, and
## the shortcut row holds six of them.
func _allow_narrow(button: Button) -> void:
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


# --- Checks ----------------------------------------------------------------

func _on_check_requested(_player_id: String, data: Dictionary) -> void:
	var check := SkillCheck.from_dict(data)
	_pending_checks.append(check)
	_render_checks()


func _drop_pending(check: SkillCheck) -> void:
	for i in _pending_checks.size():
		if (_pending_checks[i] as SkillCheck).check_id == check.check_id:
			_pending_checks.remove_at(i)
			return


func _on_rule_pressed(check: SkillCheck, step: int, reason: String = "") -> void:
	check.rule(step, reason)
	_drop_pending(check)
	# Ruling on a skill is the GM deciding it matters right now, which is what
	# the shortcuts are trying to predict.
	_note_check_skill(check.skill_id)
	if _transport != null:
		_transport.send_ruling(check.to_dict(), check.player_id)
	_render_checks()
	_render_shortcuts()


func _on_rule_with_steps_pressed(check: SkillCheck) -> void:
	if _router == null:
		return
	var chosen = await _router.push(CHECK_STEP_ROUTE, {
		"palette": _palette,
		"rules": _rules,
		"check": check.to_dict(),
		"title": "How hard is it?",
		"confirm_text": "Send",
	})
	if not is_instance_valid(self) or typeof(chosen) != TYPE_DICTIONARY:
		return
	_on_rule_pressed(check, AlternityNum.as_int(chosen.get("step", 0)), String(chosen.get("reason", "")))


func _on_refuse_check_pressed(check: SkillCheck) -> void:
	check.cancel("The GM says no.")
	_drop_pending(check)
	if _transport != null:
		_transport.send_ruling(check.to_dict(), check.player_id)
	_render_checks()


## Call for a check on a skill from the shortcut row.
func _on_shortcut_pressed(skill: Dictionary) -> void:
	await _call_check_for(skill)


## Call for a check, choosing the skill from the catalogue.
##
## A skill rather than a typed name, because the player's device has to look the
## skill up to know what their hero brings to it. A string cannot be looked up,
## and every modifier the character carried was silently dropped when this was a
## text box.
func _on_call_check_pressed() -> void:
	if _router == null:
		return
	var skill = await _router.push(SKILL_PICK_ROUTE, {
		"palette": _palette,
		"rules": _rules,
		"title": "What should they roll?",
		"shortcuts": _session.most_checked(SHORTCUT_COUNT),
	})
	if not is_instance_valid(self) or typeof(skill) != TYPE_DICTIONARY or skill.is_empty():
		return
	await _call_check_for(skill)


func _call_check_for(skill: Dictionary) -> void:
	var skill_id := AlternityNum.as_int(skill.get("id", -1), -1)
	var call := SkillCheck.call_for(_rules.skill_label(skill), 0, "", skill_id)

	var chosen = await _router.push(CHECK_STEP_ROUTE, {
		"palette": _palette,
		"rules": _rules,
		"check": call.to_dict(),
		"title": "How hard is it?",
		"confirm_text": "Ask the table",
	})
	if not is_instance_valid(self) or typeof(chosen) != TYPE_DICTIONARY:
		return

	call.gm_step = clampi(AlternityNum.as_int(chosen.get("step", 0)), SkillCheck.MIN_STEP, SkillCheck.MAX_STEP)
	call.reason = String(chosen.get("reason", ""))
	if _transport != null and _hosting:
		# Empty recipient means the whole table.
		_transport.send_ruling(call.to_dict())

	_note_check_skill(skill_id)
	# Logged because it is something the GM did, and it stands whether or not
	# anybody answers it. A player's own request is not logged: if they roll, the
	# roll carries the check, and if they change their mind nothing happened.
	_session.append_event(CampaignSession.EVENT_CHECK, "", call.to_dict())
	_store.save(_session)
	_render_feed()
	_render_shortcuts()


func _note_check_skill(skill_id: int) -> void:
	if skill_id < 0 or _session == null:
		return
	_session.note_check(skill_id)


# --- The roster ------------------------------------------------------------

func _on_open_sheet_pressed(player_id: String) -> void:
	if _router == null:
		return
	var seat := _session.seat_for(player_id)
	await _router.push(CHARACTER_VIEW_ROUTE, {
		"palette": _palette,
		"rules": _rules,
		"snapshot": _session.committed_character(player_id),
		"player": String(seat.get("player_name", "")),
	})


func _on_award_pressed(player_id: String) -> void:
	if _router == null:
		return
	var seat := _session.seat_for(player_id)
	var result = await _router.push(AP_AWARD_ROUTE, {
		"palette": _palette,
		"title": "Award %s" % String(seat.get("player_name", "this seat")),
		"amount": 1,
	})
	if not is_instance_valid(self) or typeof(result) != TYPE_DICTIONARY:
		return

	var amount := AlternityNum.as_int(result.get("amount", 0))
	if amount <= 0:
		return
	_session.award_ap(player_id, amount, String(result.get("reason", CampaignSession.AP_REASON_COMPLETION)))
	_store.save(_session)
	_broadcast_recent()
	refresh()


## Award the whole party at once.
##
## Only the reasons that mean something collectively are offered. Roleplaying and
## heroism are things one person did, and awarding them table-wide says the
## opposite of what they mean.
func _on_table_award_pressed() -> void:
	if _router == null:
		return
	var result = await _router.push(AP_AWARD_ROUTE, {
		"palette": _palette,
		"title": "Award the whole party",
		"message": "For finishing an adventure. Roleplaying and heroism go to one player.",
		"amount": 1,
		"reasons": CampaignSession.AP_TABLE_REASONS,
	})
	if not is_instance_valid(self) or typeof(result) != TYPE_DICTIONARY:
		return

	var amount := AlternityNum.as_int(result.get("amount", 0))
	if amount <= 0:
		return
	_session.award_table_ap(amount, String(result.get("reason", CampaignSession.AP_REASON_COMPLETION)))
	_store.save(_session)
	_broadcast_recent()
	refresh()


func _on_set_ap_pressed(player_id: String) -> void:
	if _router == null:
		return
	var seat := _session.seat_for(player_id)
	var result = await _router.push(AP_AWARD_ROUTE, {
		"palette": _palette,
		"mode": "set",
		"title": "Set %s's total" % String(seat.get("player_name", "seat")),
		"message": "Replaces the running total rather than adding to it.",
		"amount": _session.get_seat_ap(player_id),
		"maximum": 999,
	})
	if not is_instance_valid(self) or typeof(result) != TYPE_DICTIONARY:
		return

	_session.set_seat_ap(player_id, AlternityNum.as_int(result.get("amount", 0)))
	_store.save(_session)
	_broadcast_recent()
	refresh()


## Push whatever the GM just appended out to the table.
##
## An award is an event like any other, and the player's device applies it to
## their committed character. Without this the ledger and the player's sheet
## would only agree the next time they reconnected.
func _broadcast_recent() -> void:
	if not _hosting or _transport == null or _session.events.is_empty():
		return
	_transport._deliver(_session.events[_session.events.size() - 1])


# --- Chat ------------------------------------------------------------------

func _send_chat() -> void:
	var text := _chat_field.text.strip_edges()
	if text.is_empty() or _session == null:
		return

	var to := ""
	if _chat_target.get_selected() >= 0:
		to = String(_chat_target.get_item_metadata(_chat_target.get_selected()))

	if _hosting and _transport != null:
		# Hosting: the transport logs it and delivers it, so the GM's own line
		# gets a sequence number from the same place every other event does.
		_transport.send_chat(text, to)
	else:
		# Not hosting. Still worth recording -- a GM running the table on one
		# device uses the log as their notes.
		_session.append_chat(String(_session.gm_seat().get("player_id", "")), text, to)
	_store.flush_events(_session)
	_chat_field.text = ""
	_render_feed()


## Put the cursor in the message box.
##
## Bound to an input action rather than to a raw key: the project has an Input
## Map, and reaching past it for a keycode is how a shortcut becomes unrebindable.
func focus_chat() -> void:
	if _chat_field != null:
		_chat_field.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"table_chat"):
		focus_chat()
		get_viewport().set_input_as_handled()


# --- Settings --------------------------------------------------------------

func _on_settings_pressed() -> void:
	if _router == null:
		return
	var connected: Array = _transport.connected_players() if _hosting and _transport != null else []
	var answer = await _router.push(TABLE_SETTINGS_ROUTE, {
		"palette": _palette,
		"session": _session,
		"hosting": _hosting,
		"connected": connected,
		"addresses": _local_addresses(),
		"router": _router,
	})
	if not is_instance_valid(self) or typeof(answer) != TYPE_DICTIONARY:
		return

	match String(answer.get("action", "")):
		"toggle_hosting":
			_toggle_hosting()
		"remove_seat":
			_session.remove_seat(String(answer.get("player_id", "")))
			_store.save(_session)
			refresh()
		"leave":
			_stop_hosting()
			_store.save(_session)
			closed.emit()


## Every address this device can be reached at, for the read-it-out fallback.
##
## Loopback is filtered out: 127.0.0.1 is the one address guaranteed not to work
## from another device, and offering it is worse than offering nothing. IPv6 is
## dropped too -- reading one aloud is not a thing anyone will do successfully.
func _local_addresses() -> String:
	var usable: Array = []
	for address in IP.get_local_addresses():
		var text := String(address)
		if text.begins_with("127.") or text.contains(":"):
			continue
		usable.append(text)
	return "this device's IP address" if usable.is_empty() else ", ".join(usable)


# --- Hosting ---------------------------------------------------------------

func _toggle_hosting() -> void:
	if _hosting:
		_stop_hosting()
		refresh()
		return

	# A campaign made from the campaign list has no seats at all, and a table with
	# no GM seat has nowhere to put a private line -- the host resolves "to the
	# GM" against this seat, and without it a whispered message would be
	# broadcast to everyone. Hosting is what makes this device the GM, so this is
	# the moment to say so.
	if _session.gm_seat().is_empty():
		_session.set_gm(_session.add_seat("Game Master"))
		_store.save(_session)

	if _transport == null:
		_transport = EnetTransport.new()
		_transport.player_connected.connect(_on_player_connected)
		_transport.player_disconnected.connect(_on_player_disconnected)
		_transport.event_received.connect(_on_networked_event)
		_transport.character_received.connect(_on_character_received)
		_transport.check_requested.connect(_on_check_requested)
		_transport.action_check_received.connect(_on_action_check_received)
		_transport.transport_error.connect(_on_transport_error)

	if _transport.host(_session, EnetTransport.DEFAULT_PORT) != OK:
		# The reason is already on screen, put there by _on_transport_error.
		refresh()
		return

	_hosting = true
	# A fight already in progress goes out as soon as there is anybody to send it
	# to, so a player joining mid-session sees the board rather than nothing.
	if _fight != null:
		_transport.send_round(_fight.to_dict())
	# Discovery is allowed to fail on its own: a table that cannot be searched for
	# can still be joined by address.
	_discovery = LanDiscovery.new()
	_discovery.advertise(_session, EnetTransport.DEFAULT_PORT)
	set_process(true)
	refresh()


func _stop_hosting() -> void:
	_hosting = false
	# Nobody is waiting on a ruling any more, and a queue left standing would
	# offer to answer players who are no longer connected.
	_pending_checks.clear()
	if _transport != null:
		_transport.leave()
	if _discovery != null:
		_discovery.stop()
		_discovery = null
	set_process(false)


## Whether the table is open, for the shell and for tests.
func is_hosting() -> bool:
	return _hosting


func transport() -> EnetTransport:
	return _transport


## Poll the table.
##
## Both sockets take their packets here rather than off a frame signal, so
## tearing this screen down stops the network with it and cannot leave a socket
## pumping into a freed screen.
func _process(delta: float) -> void:
	if not _hosting:
		return
	if _transport != null:
		_transport.poll()
	if _discovery != null:
		_discovery.poll()

	_presence_clock += delta
	if _presence_clock >= PRESENCE_INTERVAL:
		_presence_clock = 0.0
		_render_status()


func _on_player_connected(_player_id: String, is_reconnect: bool) -> void:
	# A first-time join was seated by the handshake, so the campaign changed on
	# disk. A reconnect only touched last_seen, which is still worth keeping.
	_store.save(_session)
	# Somebody arriving mid-fight gets the board straight away. The round is sent
	# whole, so there is nothing else they need to catch up.
	if _fight != null and _transport != null:
		_transport.send_round(_fight.to_dict())
	if not is_reconnect:
		_summary_cache.clear()
	refresh()


func _on_player_disconnected(_player_id: String) -> void:
	refresh()


## An event arrived from a player device.
##
## Flushed rather than saved: no seat changed, and the log is the one part of a
## campaign that must not wait for an explicit save.
func _on_networked_event(_event: Dictionary) -> void:
	_store.flush_events(_session)
	_render_feed()
	_render_status()


## A player committed a character, or sent an updated copy of one.
##
## Saved because the character lives on the seat: a GM who reopens the campaign
## next week should still see the sheet, rather than an empty row until that
## player happens to connect again.
func _on_character_received(_player_id: String, _snapshot: Dictionary) -> void:
	_store.save(_session)
	_summary_cache.clear()
	_render_roster()


func _on_transport_error(message: String) -> void:
	if _status == null:
		return
	_status.text = message
	_status.add_theme_color_override("font_color", _palette.warning)


func _exit_tree() -> void:
	# Leaving the screen closes the table. A socket outliving the screen that owns
	# it would keep answering for a campaign nobody is looking at.
	_stop_hosting()
