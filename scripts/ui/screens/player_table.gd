class_name PlayerTableScreen
extends Control
##
## What a player sees once they are at a GM's table: the feed, a chat box, and
## whatever achievement points the GM has awarded them.
##
## The mirror of GmScreen, and much smaller, because a player owns almost none
## of this. Two ownership rules decide what is here:
##
##   * The GM's device owns the campaign. Seats, the log and its sequence
##     numbers are all assigned there; this screen only receives them.
##   * This device owns the player's character. AP awarded by the GM arrives as
##     an event and is applied here -- the GM never writes to a character file
##     they cannot see.
##
## The log this screen keeps is a local copy for display, not a second authority.
## It is deliberately not written to a campaign file: two devices with two
## campaign documents is exactly the drift the one-owner rule exists to prevent.
##

## Leave the table.
signal closed

## How much of the feed to keep in memory on a player device. The GM's copy is
## the one that has to be complete.
const FEED_LENGTH := 60

var _transport: EnetTransport
var _identity: PlayerIdentity
var _store: CharacterStore
var _rules
var _palette: ThemePalette
var _campaign_name: String = ""

## The events this device has been sent, oldest first. Display only.
var _events: Array = []

## AP the GM has awarded that has not been applied to a character yet.
var _unclaimed: int = 0

var _title: Label
var _status: Label
var _feed_list: VBoxContainer
var _feed_empty: Label
var _chat_field: LineEdit
var _private_toggle: CheckButton
var _ap_note: Label
var _claim_button: Button
var _character_picker: OptionButton


func setup(
	transport: EnetTransport,
	identity: PlayerIdentity,
	store: CharacterStore,
	rules,
	palette: ThemePalette,
	campaign_name: String
) -> void:
	_transport = transport
	_identity = identity
	_store = store
	_rules = rules
	_palette = palette
	_campaign_name = campaign_name

	_transport.event_received.connect(_on_event)
	_transport.events_replayed.connect(_on_replay)
	_transport.transport_error.connect(_on_transport_error)
	_transport.player_connected.connect(_on_reconnected)

	_build()
	_render()
	set_process(true)


func campaign_name() -> String:
	return _campaign_name


func events() -> Array:
	return _events


func unclaimed_ap() -> int:
	return _unclaimed


# --- Building --------------------------------------------------------------

func _build() -> void:
	var root_box := VBoxContainer.new()
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_box.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	add_child(root_box)

	var header := MarginContainer.new()
	for side in ["left", "right", "top"]:
		header.add_theme_constant_override("margin_" + side, Widgets.PAD_PANEL)
	root_box.add_child(header)

	var header_box := VBoxContainer.new()
	header_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	header.add_child(header_box)

	_title = Label.new()
	_title.text = _campaign_name if not _campaign_name.is_empty() else "At the table"
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.custom_minimum_size = Vector2(1, 0)
	_title.add_theme_color_override("font_color", _palette.text)
	_title.add_theme_font_size_override("font_size", 22 if _is_wide() else 18)
	header_box.add_child(_title)

	_status = Label.new()
	_status.add_theme_color_override("font_color", _palette.accent)
	_status.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	header_box.add_child(_status)

	var column := Widgets.page_column(root_box, _is_wide())
	column.add_theme_constant_override("separation", 20)

	_build_ap_section(column)
	_build_chat_section(column)

	var feed := Widgets.section(column, "Table log", _palette)
	_feed_empty = Widgets.muted_text(feed, "Nothing has happened yet.", _palette)
	_feed_list = VBoxContainer.new()
	_feed_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feed_list.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	feed.add_child(_feed_list)

	var leave := Button.new()
	leave.name = "LeaveButton"
	leave.text = "Leave the table"
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.custom_minimum_size = Vector2(0, 40)
	leave.pressed.connect(_on_leave_pressed)
	column.add_child(leave)


## Achievement points, and the one place the ownership rule becomes visible.
##
## The GM awards; this device applies. Applying is a button rather than automatic
## because it writes to a character file, and a player watching the feed on a
## phone while their sheet is open elsewhere should decide when that happens.
func _build_ap_section(parent: Container) -> void:
	var section := Widgets.section(parent, "Achievement points", _palette)

	_ap_note = Widgets.text(section, "No awards yet.", _palette, Widgets.FONT_BODY)
	_ap_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ap_note.custom_minimum_size = Vector2(1, 0)

	_character_picker = OptionButton.new()
	_character_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_character_picker.custom_minimum_size = Vector2(0, 36)
	Widgets.field_row(section, "Apply to", _character_picker, _palette)

	_claim_button = Button.new()
	_claim_button.name = "ClaimApButton"
	_claim_button.text = "Add to my hero"
	_claim_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_claim_button.custom_minimum_size = Vector2(0, 40)
	_claim_button.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
	_claim_button.pressed.connect(_on_claim_pressed)
	section.add_child(_claim_button)


func _build_chat_section(parent: Container) -> void:
	var section := Widgets.section(parent, "Say something", _palette)

	_chat_field = LineEdit.new()
	_chat_field.placeholder_text = "Message the table"
	_chat_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_field.custom_minimum_size = Vector2(0, 40)
	_chat_field.text_submitted.connect(func(_text: String): _send_chat())
	section.add_child(_chat_field)

	_private_toggle = CheckButton.new()
	_private_toggle.text = "Only the GM sees this"
	_private_toggle.add_theme_color_override("font_color", _palette.text)
	section.add_child(_private_toggle)

	var send := Button.new()
	send.name = "SendChatButton"
	send.text = "Send"
	send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	send.custom_minimum_size = Vector2(0, 40)
	send.pressed.connect(_send_chat)
	section.add_child(send)


func _is_wide() -> bool:
	return get_viewport_rect().size.x >= ModalHost.COMPACT_WIDTH


# --- Network ---------------------------------------------------------------

func _process(_delta: float) -> void:
	if _transport != null:
		_transport.poll()


func _on_event(event: Dictionary) -> void:
	_events.append(event)
	# Bounded: a player device shows the recent table, not the archive. The GM's
	# copy is the one that has to be complete.
	if _events.size() > FEED_LENGTH:
		_events = _events.slice(_events.size() - FEED_LENGTH)
	_absorb(event)
	_note_progress()
	_render()


func _on_replay(replayed: Array) -> void:
	for event in replayed:
		_events.append(event)
		_absorb(event)
	if _events.size() > FEED_LENGTH:
		_events = _events.slice(_events.size() - FEED_LENGTH)
	_note_progress()
	_render()


## Pick out of an event anything this device owns the consequences of.
##
## Only AP so far. The award is the GM's decision; the character file it lands in
## is this device's, which is why the amount is banked here rather than applied
## to whatever hero happens to be open.
func _absorb(event: Dictionary) -> void:
	if String(event.get("kind", "")) != CampaignSession.EVENT_AP_AWARD:
		return
	if String(event.get("player_id", "")) != _transport.local_player_id():
		return
	var payload: Dictionary = event.get("payload", {}) if typeof(event.get("payload")) == TYPE_DICTIONARY else {}
	_unclaimed += AlternityNum.as_int(payload.get("amount", 0))


## Remember how far this device's copy got, so a reconnect asks for the gap
## rather than the campaign.
func _note_progress() -> void:
	if _events.is_empty():
		return
	_identity.note_seq(
		_transport.campaign_id(),
		AlternityNum.as_int(_events[_events.size() - 1].get("seq", 0))
	)


func _on_reconnected(_player_id: String, is_reconnect: bool) -> void:
	_status.text = "Back at the table." if is_reconnect else "At the table."
	_status.add_theme_color_override("font_color", _palette.accent)


func _on_transport_error(message: String) -> void:
	_status.text = message
	_status.add_theme_color_override("font_color", _palette.warning)


# --- Rendering -------------------------------------------------------------

func _render() -> void:
	if _status == null:
		return
	if _status.text.is_empty():
		_status.text = "At the table."
	_render_ap()
	_render_feed()


func _render_ap() -> void:
	_ap_note.text = (
		"No awards yet."
		if _unclaimed <= 0
		else "%d achievement point%s waiting." % [_unclaimed, "" if _unclaimed == 1 else "s"]
	)
	_claim_button.disabled = _unclaimed <= 0

	# Rebuilt each time: the person may have made a hero on another screen since
	# this one was drawn.
	var chosen := _character_picker.get_selected_id()
	_character_picker.clear()
	var index := 0
	for entry in _store.list():
		_character_picker.add_item(String(entry.get("hero_name", "Unnamed")), index)
		_character_picker.set_item_metadata(index, String(entry.get("file_name", "")))
		index += 1
	if index == 0:
		_character_picker.add_item("(no heroes on this device)", 0)
		_character_picker.set_item_metadata(0, "")
		_claim_button.disabled = true
	elif chosen >= 0 and chosen < index:
		_character_picker.select(chosen)


func _render_feed() -> void:
	for child in _feed_list.get_children():
		_feed_list.remove_child(child)
		child.queue_free()

	_feed_empty.visible = _events.is_empty()
	var recent := _events.duplicate()
	# Newest first, the same as the GM's feed.
	recent.reverse()
	for event in recent:
		var row := Label.new()
		row.text = _describe(event)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(1, 0)
		row.add_theme_color_override("font_color", _palette.text)
		row.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
		_feed_list.add_child(row)


## One line of table log.
##
## A player device has no seat list, so it cannot turn a player_id into a name.
## It says "you" for its own and leaves the rest unnamed rather than printing a
## 32-character id at somebody.
func _describe(event: Dictionary) -> String:
	var payload: Dictionary = event.get("payload", {}) if typeof(event.get("payload")) == TYPE_DICTIONARY else {}
	var mine: bool = String(event.get("player_id", "")) == _transport.local_player_id()
	var who := "You" if mine else "Someone"

	match String(event.get("kind", "")):
		CampaignSession.EVENT_ROLL:
			var label := String(payload.get("label", ""))
			var what := label if not label.is_empty() else String(payload.get("notation", ""))
			return "%s rolled %s: %d" % [who, what, AlternityNum.as_int(payload.get("total", 0))]
		CampaignSession.EVENT_CHAT:
			var private_line := not String(payload.get("to", "")).is_empty()
			return "%s%s: %s" % [who, " (private)" if private_line else "", String(payload.get("text", ""))]
		CampaignSession.EVENT_AP_AWARD:
			if not mine:
				return "Someone was awarded achievement points"
			return "You were awarded %d AP -- %s" % [
				AlternityNum.as_int(payload.get("amount", 0)),
				String(payload.get("reason", "")),
			]
		CampaignSession.EVENT_AP_SET:
			return "Your achievement points were set to %d" % AlternityNum.as_int(payload.get("new_ap", 0)) if mine else "A total was adjusted"
		CampaignSession.EVENT_JOIN:
			return "You joined" if mine else "Someone joined"
		CampaignSession.EVENT_NOTE:
			return String(payload.get("text", ""))
	return String(event.get("kind", ""))


# --- Actions ---------------------------------------------------------------

func _send_chat() -> void:
	var text := _chat_field.text.strip_edges()
	if text.is_empty() or _transport == null:
		return
	# A private line is addressed to the GM's seat, which the host resolves; this
	# device does not know seat ids and must not have to.
	_transport.send_chat(text, EnetTransport.TO_GM if _private_toggle.button_pressed else "")
	_chat_field.text = ""


## Apply banked awards to a hero on this device.
##
## The conflict rule made concrete: the GM's award is an event, and the player's
## device is what writes it into a character file.
func _on_claim_pressed() -> void:
	if _unclaimed <= 0 or _character_picker.get_selected() < 0:
		return
	var file_name := String(_character_picker.get_item_metadata(_character_picker.get_selected()))
	if file_name.is_empty():
		return
	var doc = _store.load_doc(file_name)
	if doc == null:
		_status.text = "That hero could not be opened."
		_status.add_theme_color_override("font_color", _palette.warning)
		return

	var granted := _unclaimed
	doc.apply(CharacterDoc.ALL, func(character):
		character["achievement_points"] = AlternityNum.as_int(character.get("achievement_points", 0)) + granted)
	_store.save(doc)

	_unclaimed = 0
	_status.text = "%d AP added to %s." % [granted, doc.get_hero_name()]
	_status.add_theme_color_override("font_color", _palette.accent)
	_render()


func _on_leave_pressed() -> void:
	closed.emit()


func _exit_tree() -> void:
	if _transport != null:
		_transport.leave()
		_transport = null
	set_process(false)
