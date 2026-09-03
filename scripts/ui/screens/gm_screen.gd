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

const AP_AWARD_ROUTE := preload("res://scenes/ui/routes/ap_award_route.tscn")
const CONFIRM_ROUTE := preload("res://scenes/ui/routes/confirm_route.tscn")
const TEXT_PROMPT_ROUTE := preload("res://scenes/ui/routes/text_prompt_route.tscn")

var _session: CampaignSession
var _store: CampaignStore
var _characters: CharacterStore
var _rules
var _router: UiRouter
var _palette: ThemePalette

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
	_render_seats()
	_render_feed()


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
func _build_key_numbers(parent: Container, seat: Dictionary) -> void:
	var summary := _summary_for(String(seat.get("character_file", "")))
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


func _on_close_pressed() -> void:
	_store.save(_session)
	closed.emit()
