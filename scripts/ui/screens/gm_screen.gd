class_name GmScreen
extends Control
##
## The GM's view of a campaign: who is at the table, what their heroes can take,
## and what has happened.
##
## Usable on one device with nobody connected, which is deliberate. A GM running
## the table from a laptop with the players using paper still wants the seat
## list, the AP ledger and the log; networking (Phase M2) adds where the events
## come from, not what this screen is.
##
## Three things it shows, in the order a GM needs them mid-session:
##
##   1. Seats -- the bound hero and the numbers a GM asks for out loud:
##      durability, action check and last resorts.
##   2. AP -- the running total per seat, and the award buttons. Awards are
##      events, so the ledger is auditable months later.
##   3. The feed -- the tail of the event log, newest first.
##
## Key numbers are read from the character's own summary rather than recomputed
## here. A GM screen that derived durability itself would drift from the sheet
## the player is looking at, and the two would disagree at the worst moment.
##

## Leave the campaign and return to the campaign list.
signal closed

## How much of the log the feed shows. The log itself is unbounded; this is not.
const FEED_LENGTH := 60

## How often the connected-player line is redrawn, in seconds. The transport
## answers packets as they arrive; this only paces the presence display.
const PRESENCE_INTERVAL := 1.0

const AP_AWARD_ROUTE := preload("res://scenes/ui/routes/ap_award_route.tscn")
const CHECK_STEP_ROUTE := preload("res://scenes/ui/routes/check_step_route.tscn")
const CONFIRM_ROUTE := preload("res://scenes/ui/routes/confirm_route.tscn")
const TEXT_PROMPT_ROUTE := preload("res://scenes/ui/routes/text_prompt_route.tscn")

var _session: CampaignSession
var _store: CampaignStore
var _characters: CharacterStore
var _rules
var _router: UiRouter
var _palette: ThemePalette

## The table, when it is open. Null until the GM starts hosting; the screen is
## fully usable without it, which is the point of building M1 before M2.
var _transport: EnetTransport
var _discovery: LanDiscovery
var _hosting: bool = false
var _table_status: Label
var _table_hint: Label
var _host_button: Button
var _chat_field: LineEdit
var _chat_target: OptionButton

## Checks players are waiting on a ruling for, oldest first.
##
## A queue rather than a single pending check: at a table, two players ask at
## once and the second must not silently replace the first.
var _pending_checks: Array = []
var _checks_section: VBoxContainer
var _checks_note: Label
var _presence_clock: float = 0.0

var _title: Label
var _seat_list: VBoxContainer
var _feed_list: VBoxContainer
var _seat_empty: Label
var _feed_empty: Label

## Bound characters for this render, so six seats do not each re-read and
## re-summarize the same file.
var _character_cache: Dictionary = {}


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

	# page_column brings its own scroll container, margins and centring gutters;
	# wrapping it in another would nest two scrollers over the same content.
	var column := Widgets.page_column(root_box, _is_wide())
	column.add_theme_constant_override("separation", 20)

	_build_table_section(column)
	_build_checks_section(column)

	var seats_section := Widgets.section(column, "Seats", _palette)
	_seat_empty = Widgets.muted_text(
		seats_section,
		"Nobody is seated yet. Add a seat for each player at the table.",
		_palette
	)
	_seat_list = VBoxContainer.new()
	_seat_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seat_list.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	seats_section.add_child(_seat_list)

	var feed_section := Widgets.section(column, "Session log", _palette)
	_feed_empty = Widgets.muted_text(feed_section, "Nothing has happened yet.", _palette)
	_feed_list = VBoxContainer.new()
	_feed_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feed_list.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	feed_section.add_child(_feed_list)


## Hosting: the one control that turns a single-device session into a table.
##
## Deliberately a section on this screen rather than a mode the screen is in.
## Everything else here works whether or not anyone is connected, and a GM whose
## Wi-Fi drops mid-session should lose the players, not the campaign.
func _build_table_section(parent: Container) -> void:
	var section := Widgets.section(parent, "Table", _palette)

	_table_status = Widgets.text(section, "Closed -- nobody can join yet.", _palette, Widgets.FONT_BODY)
	_table_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_table_status.custom_minimum_size = Vector2(1, 0)

	_table_hint = Widgets.muted_text(
		section,
		"Open the table and players on the same Wi-Fi can find this campaign.",
		_palette,
		Widgets.FONT_CAPTION
	)
	_table_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_table_hint.custom_minimum_size = Vector2(1, 0)

	_host_button = Button.new()
	_host_button.name = "HostButton"
	_host_button.text = "Open the table"
	_host_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_host_button.custom_minimum_size = Vector2(0, 40)
	_host_button.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
	_host_button.pressed.connect(_on_host_pressed)
	section.add_child(_host_button)

	_build_chat(section)


## The GM's half of the conversation.
##
## Without this, private chat only works in one direction: a player can whisper
## a question and the GM has no way to answer it except out loud, which defeats
## the point of a private line at a table where everyone can hear each other.
##
## The recipient picker lists seats by name, because the GM is the one device
## that legitimately holds the seat list -- a player device never does.
func _build_chat(parent: Container) -> void:
	_chat_target = OptionButton.new()
	_chat_target.name = "ChatTargetPicker"
	_chat_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_target.custom_minimum_size = Vector2(0, 36)
	Widgets.field_row(parent, "Say to", _chat_target, _palette)

	_chat_field = LineEdit.new()
	_chat_field.name = "ChatField"
	_chat_field.placeholder_text = "Message the table"
	_chat_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_field.custom_minimum_size = Vector2(0, 40)
	_chat_field.text_submitted.connect(func(_text: String): _send_chat())
	parent.add_child(_chat_field)

	var send := Button.new()
	send.name = "SendChatButton"
	send.text = "Send"
	send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	send.custom_minimum_size = Vector2(0, 36)
	send.pressed.connect(_send_chat)
	parent.add_child(send)


## Rebuild the recipient list from the current seats.
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


## Checks waiting on the GM, and the button that starts one.
##
## Placed above the seats because mid-session this is the thing with somebody
## actually waiting on it -- a player is holding dice until the GM answers.
func _build_checks_section(parent: Container) -> void:
	var section := Widgets.section(parent, "Checks", _palette)

	_checks_note = Widgets.muted_text(section, "Nobody is waiting on a ruling.", _palette, Widgets.FONT_CAPTION)
	_checks_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_checks_note.custom_minimum_size = Vector2(1, 0)

	_checks_section = VBoxContainer.new()
	_checks_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_checks_section.add_theme_constant_override("separation", Widgets.GAP_ROW)
	section.add_child(_checks_section)

	var call_button := Button.new()
	call_button.name = "CallCheckButton"
	call_button.text = "Call for a check"
	call_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	call_button.custom_minimum_size = Vector2(0, 40)
	call_button.tooltip_text = "Ask a player, or the whole table, to roll something"
	call_button.pressed.connect(_on_call_check_pressed)
	section.add_child(call_button)


func _render_checks() -> void:
	if _checks_section == null:
		return
	for child in _checks_section.get_children():
		_checks_section.remove_child(child)
		child.queue_free()

	_checks_note.visible = _pending_checks.is_empty()
	for check in _pending_checks:
		_build_pending_check(check)


func _build_pending_check(check: SkillCheck) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
	_checks_section.add_child(panel)

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

	# The score, which is what a GM rules against. Read-only: the GM sets
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
	var straight := _seat_button("Ordinary", _on_rule_pressed.bind(check, 0))
	straight.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface, _palette.accent, 6))
	actions.add_child(straight)
	actions.add_child(_seat_button("Set steps...", _on_rule_with_steps_pressed.bind(check)))
	var refuse := _seat_button("Refuse", _on_refuse_check_pressed.bind(check))
	refuse.add_theme_color_override("font_color", _palette.warning)
	actions.add_child(refuse)


# --- Ruling ----------------------------------------------------------------

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
	if _transport != null:
		_transport.send_ruling(check.to_dict(), check.player_id)
	_render_checks()


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


## Ask a player, or the table, to roll something.
##
## The step is set here rather than after the fact, because a called check has
## nothing to wait for -- the GM already knows how hard it is.
func _on_call_check_pressed() -> void:
	if _router == null:
		return
	var named = await _router.push(TEXT_PROMPT_ROUTE, {
		"palette": _palette,
		"title": "Call for a check",
		"message": "What should they roll?",
		"placeholder": "Awareness - Perception",
		"confirm_text": "Next",
	})
	if not is_instance_valid(self) or named == null:
		return

	var call := SkillCheck.call_for(String(named), 0)
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

	# Logged because it is something the GM did, and it stands whether or not
	# anybody answers it. A player's own request is not logged: if they roll, the
	# roll carries the check, and if they change their mind nothing happened.
	_session.append_event(CampaignSession.EVENT_CHECK, "", call.to_dict())
	_store.flush_events(_session)
	_render_feed()


func _build_header(parent: Container) -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.PAD_PANEL)
	parent.add_child(margin)

	# Stacked on a phone for the same reason the sheet header is: a campaign name
	# and four actions do not fit across 390px without squeezing the name to one
	# letter per line.
	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", Widgets.GAP_ROW)
	margin.add_child(outer)

	var title_row := HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	outer.add_child(title_row)

	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.custom_minimum_size = Vector2(1, 0)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", _palette.text)
	_title.add_theme_font_size_override("font_size", 22 if _is_wide() else 18)
	title_row.add_child(_title)

	# A grid rather than a row. Three buttons across a 390px phone ran the last
	# one off the side of the screen, and the scroll container has horizontal
	# scrolling disabled, so it was not merely cramped -- it was unreachable.
	var actions := GridContainer.new()
	actions.columns = 3 if _is_wide() else 2
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("h_separation", Widgets.GAP_ROW)
	actions.add_theme_constant_override("v_separation", Widgets.GAP_ROW)
	if _is_wide():
		title_row.add_child(actions)
	else:
		outer.add_child(actions)

	var add_seat := _header_button("AddSeatButton", "Add seat", _on_add_seat_pressed)
	actions.add_child(add_seat)

	var table_ap := _header_button("TableAwardButton", "Award table", _on_table_award_pressed)
	table_ap.tooltip_text = "Award achievement points to every player seat at once"
	actions.add_child(table_ap)

	var close_button := _header_button("CloseCampaignButton", "Close", _on_close_pressed)
	actions.add_child(close_button)


func _header_button(node_name: String, label: String, handler: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 40)
	button.pressed.connect(handler)
	return button


func _is_wide() -> bool:
	return get_viewport_rect().size.x >= ModalHost.COMPACT_WIDTH


# --- Rendering -------------------------------------------------------------

func refresh() -> void:
	if _session == null or _seat_list == null:
		return
	_character_cache.clear()
	_title.text = _session.display_name
	_render_table()
	_render_chat_targets()
	_render_checks()
	_render_seats()
	_render_feed()


func _render_table() -> void:
	if _table_status == null:
		return
	if not _hosting or _transport == null:
		_table_status.text = "Closed -- nobody can join yet."
		_table_status.add_theme_color_override("font_color", _palette.muted)
		_table_hint.text = "Open the table and players on the same Wi-Fi can find this campaign."
		_host_button.text = "Open the table"
		return

	var names: Array = []
	for player_id in _transport.connected_players():
		names.append(String(_session.seat_for(String(player_id)).get("player_name", "someone")))

	_table_status.text = "Open on port %d -- %s" % [
		EnetTransport.DEFAULT_PORT,
		"nobody connected yet" if names.is_empty() else ", ".join(names) + " connected",
	]
	_table_status.add_theme_color_override("font_color", _palette.accent)
	# The addresses are worth showing even when discovery works: reading one out
	# is the only thing left when a guest network blocks broadcast.
	_table_hint.text = "Players can search for this table, or type: %s" % _local_addresses()
	_host_button.text = "Close the table"


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


func _render_seats() -> void:
	for child in _seat_list.get_children():
		_seat_list.remove_child(child)
		child.queue_free()

	_seat_empty.visible = _session.seats.is_empty()
	for seat in _session.seats:
		_build_seat_card(seat)


func _build_seat_card(seat: Dictionary) -> void:
	var player_id := String(seat.get("player_id", ""))
	var is_gm := bool(seat.get("is_gm", false))

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The GM's own seat is outlined in the accent so it is findable at a glance
	# in a list where every other row looks the same.
	panel.add_theme_stylebox_override(
		"panel",
		Widgets.flat_style(_palette.surface, _palette.accent if is_gm else _palette.border, 8)
	)
	_seat_list.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.PAD_PANEL)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", Widgets.GAP_ROW)
	margin.add_child(box)

	var name_row := HBoxContainer.new()
	name_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_theme_constant_override("separation", Widgets.GAP_ROW)
	box.add_child(name_row)

	var name_label := Label.new()
	name_label.text = String(seat.get("player_name", "Unnamed"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size = Vector2(1, 0)
	name_label.add_theme_color_override("font_color", _palette.text)
	name_label.add_theme_font_size_override("font_size", Widgets.FONT_SECTION_TITLE)
	name_row.add_child(name_label)

	if is_gm:
		var badge := Label.new()
		badge.text = "GM"
		badge.add_theme_color_override("font_color", _palette.accent)
		badge.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
		name_row.add_child(badge)

	var ap_label := Label.new()
	ap_label.text = "%d AP" % _session.get_seat_ap(player_id)
	ap_label.add_theme_color_override("font_color", _palette.accent)
	ap_label.add_theme_font_size_override("font_size", Widgets.FONT_SUBHEADING)
	name_row.add_child(ap_label)

	_build_character_row(box, seat)
	_build_key_numbers(box, seat)
	_build_seat_actions(box, seat)


## The bound hero, and a way to change it.
##
## An OptionButton rather than a picker route: the list is every saved character
## on this device, which on a GM's machine is a handful, and binding a seat is
## something done once per campaign rather than mid-play.
func _build_character_row(parent: Container, seat: Dictionary) -> void:
	var player_id := String(seat.get("player_id", ""))
	var bound := String(seat.get("character_file", ""))

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", Widgets.GAP_ROW)
	parent.add_child(row)

	var label := Label.new()
	label.text = "Hero"
	label.add_theme_color_override("font_color", _palette.muted)
	label.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
	row.add_child(label)

	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.custom_minimum_size = Vector2(0, 36)
	picker.add_item("(none)")
	picker.set_item_metadata(0, "")
	var selected := 0
	var index := 1
	for entry in _characters.list():
		var file_name := String(entry.get("file_name", ""))
		picker.add_item(String(entry.get("hero_name", file_name)))
		picker.set_item_metadata(index, file_name)
		if file_name == bound:
			selected = index
		index += 1

	# A binding whose file has since been deleted must still be visible; silently
	# showing "(none)" would look like the GM had unbound it.
	if selected == 0 and not bound.is_empty():
		picker.add_item("%s (missing)" % bound)
		picker.set_item_metadata(index, bound)
		selected = index

	picker.select(selected)
	picker.item_selected.connect(func(chosen: int): _on_character_chosen(player_id, String(picker.get_item_metadata(chosen))))
	row.add_child(picker)


## Durability, action check and last resorts -- what a GM asks a player for.
##
## Two sources, in order. A hero bound to a file on this device is read from that
## file. Otherwise the seat may carry a snapshot the player's device pushed,
## which is the ordinary case at a real table: the player made their hero on
## their own phone and the GM has never had a copy.
func _build_key_numbers(parent: Container, seat: Dictionary) -> void:
	var summary := _summary_for(String(seat.get("character_file", "")))
	var from_snapshot := false

	if summary.is_empty():
		var snapshot = seat.get("character_snapshot", {})
		if typeof(snapshot) == TYPE_DICTIONARY and CharacterSnapshot.is_usable(snapshot):
			summary = snapshot
			from_snapshot = true

	if summary.is_empty():
		Widgets.muted_text(parent, "No hero bound, so no numbers to show.", _palette, Widgets.FONT_CAPTION)
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

	if not from_snapshot:
		return

	# Say where the numbers came from and how old they are. A snapshot is a fact
	# about the past, and a GM reading a stale durability track as current is the
	# one way this policy can mislead.
	var age := CharacterSnapshot.age_seconds(summary)
	var freshness := "just now" if age >= 0 and age < 60 else (
		"%d minutes ago" % int(age / 60.0) if age >= 60 else "at some point"
	)
	Widgets.muted_text(
		parent,
		"%s, sent from their device %s." % [String(summary.get("hero_name", "Their hero")), freshness],
		_palette,
		Widgets.FONT_CAPTION
	)


func _metric(parent: Container, name: String, value: String) -> void:
	var box := VBoxContainer.new()
	# Expanding is load-bearing. A GridContainer sizes a column to the widest
	# minimum among its children and only stretches it for a child that expands;
	# the wrapping labels inside report a 1px minimum, so without this the column
	# collapsed and "Durability" came out one letter per line.
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	parent.add_child(box)
	Widgets.muted_text(box, name, _palette, Widgets.FONT_CAPTION)
	Widgets.text(box, value, _palette, Widgets.FONT_SUBHEADING)


func _build_seat_actions(parent: Container, seat: Dictionary) -> void:
	var player_id := String(seat.get("player_id", ""))
	var is_gm := bool(seat.get("is_gm", false))

	# Up to four buttons per seat, which is more than a phone row holds; the same
	# grid treatment as the header, two per row when narrow.
	var actions := GridContainer.new()
	actions.columns = 4 if _is_wide() else 2
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("h_separation", Widgets.GAP_ROW)
	actions.add_theme_constant_override("v_separation", Widgets.GAP_ROW)
	parent.add_child(actions)

	var award := _seat_button("Award AP", _on_award_pressed.bind(player_id))
	award.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
	actions.add_child(award)

	var adjust := _seat_button("Set", _on_set_ap_pressed.bind(player_id))
	adjust.tooltip_text = "Correct this seat's achievement point total"
	actions.add_child(adjust)

	if not is_gm:
		actions.add_child(_seat_button("Make GM", _on_make_gm_pressed.bind(player_id)))

	var remove := _seat_button(
		"Remove",
		_on_remove_seat_pressed.bind(player_id, String(seat.get("player_name", "")))
	)
	remove.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.warning, 6))
	remove.add_theme_color_override("font_color", _palette.warning)
	actions.add_child(remove)


func _seat_button(label: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 36)
	button.pressed.connect(handler)
	return button


func _render_feed() -> void:
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


## The bound character's computed summary, or {} when nothing is bound or the
## file has gone.
func _summary_for(file_name: String) -> Dictionary:
	if file_name.is_empty() or _characters == null:
		return {}
	if _character_cache.has(file_name):
		return _character_cache[file_name]
	var doc = _characters.load_doc(file_name)
	var summary: Dictionary = doc.summary() if doc != null else {}
	_character_cache[file_name] = summary
	return summary


# --- Actions ---------------------------------------------------------------

func _on_add_seat_pressed() -> void:
	if _router == null:
		return
	var chosen = await _router.push(TEXT_PROMPT_ROUTE, {
		"palette": _palette,
		"title": "Who is joining?",
		"message": "The player's name, not the hero's.",
		"placeholder": "Player name",
		"confirm_text": "Add seat",
	})
	if not is_instance_valid(self) or chosen == null:
		return

	var player_id := _session.add_seat(String(chosen))
	# The first seat in an empty campaign is the person setting it up, which on a
	# single device is always the GM. Saying so saves a step and makes the "one
	# GM" invariant true from the start rather than after a click.
	if _session.seats.size() == 1:
		_session.set_gm(player_id)
	_session.append_event(CampaignSession.EVENT_JOIN, player_id, {"player_name": String(chosen)})
	_store.save(_session)
	refresh()


func _on_character_chosen(player_id: String, file_name: String) -> void:
	_session.bind_character(player_id, file_name)
	_store.save(_session)
	refresh()


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
	refresh()


func _on_table_award_pressed() -> void:
	if _router == null:
		return
	var result = await _router.push(AP_AWARD_ROUTE, {
		"palette": _palette,
		"title": "Award the table",
		"message": "Every player seat receives this. The GM's own seat does not.",
		"amount": 1,
	})
	if not is_instance_valid(self) or typeof(result) != TYPE_DICTIONARY:
		return

	var amount := AlternityNum.as_int(result.get("amount", 0))
	if amount <= 0:
		return
	_session.award_table_ap(amount, String(result.get("reason", CampaignSession.AP_REASON_COMPLETION)))
	_store.save(_session)
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
	refresh()


func _on_make_gm_pressed(player_id: String) -> void:
	_session.set_gm(player_id)
	_store.save(_session)
	refresh()


func _on_remove_seat_pressed(player_id: String, player_name: String) -> void:
	if _router == null:
		return
	var confirmed = await _router.push(CONFIRM_ROUTE, {
		"palette": _palette,
		"title": "Remove %s?" % player_name,
		"message": "Their seat and its achievement points go. What they did stays in the log.",
		"confirm_text": "Remove",
		"destructive": true,
	})
	if not is_instance_valid(self):
		return
	if confirmed == true:
		_session.remove_seat(player_id)
		_store.save(_session)
		refresh()


func _on_host_pressed() -> void:
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
		_transport.transport_error.connect(_on_transport_error)

	if _transport.host(_session, EnetTransport.DEFAULT_PORT) != OK:
		# The reason is already on screen, put there by _on_transport_error.
		refresh()
		return

	_hosting = true
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
		_render_table()


func _on_player_connected(_player_id: String, is_reconnect: bool) -> void:
	# A first-time join was seated by the handshake, so the campaign changed on
	# disk. A reconnect only touched last_seen, which is still worth keeping.
	_store.save(_session)
	if not is_reconnect:
		_character_cache.clear()
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
	_render_table()


## A player pushed their hero's numbers.
##
## Saved because the snapshot lives on the seat: a GM who reopens the campaign
## next week should still see what the character looked like, rather than an
## empty row until that player happens to connect again.
func _on_character_received(_player_id: String, _snapshot: Dictionary) -> void:
	_store.save(_session)
	_render_seats()


func _on_transport_error(message: String) -> void:
	if _table_status == null:
		return
	_table_status.text = message
	_table_status.add_theme_color_override("font_color", _palette.warning)


func _exit_tree() -> void:
	# Leaving the screen closes the table. A socket outliving the screen that owns
	# it would keep answering for a campaign nobody is looking at.
	_stop_hosting()


func _on_close_pressed() -> void:
	_stop_hosting()
	_store.save(_session)
	closed.emit()
