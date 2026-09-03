extends SheetTab
##
## The table, as a tab on the player's own sheet.
##
## This used to be a screen of its own, which meant a player at a table could
## either look at the table or look at their character, never both. A campaign
## runs for months and a player spends it doing ordinary character things --
## spending skill points, marking damage, reading a perk -- so the table belongs
## beside those, not instead of them.
##
## Everything here is read or sent; nothing about the campaign is owned by this
## device. The one thing that is owned is the character, and the tab shows what
## the table has done to it: achievement points the GM awarded land on the
## committed hero automatically, because a player at a table is playing one
## character and asking which should receive them is a question with a single
## possible answer.
##

## Only offered when this device is actually at a table.
const CAMPAIGN_SECTION := &"meta"

var _status: Label
var _chat_field: LineEdit
var _private_toggle: CheckButton
var _feed_list: VBoxContainer
var _feed_empty: Label
var _last_award: String = ""


func watched_sections() -> Array:
	# The header shows achievement points, which the GM can change from the far
	# end of a network. Everything else here is table state, not character state.
	return [CharacterDoc.ACHIEVEMENTS, CharacterDoc.META]


## Absent unless there is a table to show. A tab that renders "not connected" is
## a tab that takes up room in the bar for no reason.
func is_available_for(context: SheetContext) -> bool:
	return context != null and context.table != null


func build(container: Container) -> void:
	var table: TableSession = ctx.table
	if table == null:
		return

	# Connected once, not on every rebuild: build() runs again whenever the
	# character changes, and a fresh connection each time would multiply the
	# handlers until one award applied a dozen times.
	if not table.changed.is_connected(_on_table_changed):
		table.changed.connect(_on_table_changed)
		table.ap_applied.connect(_on_ap_applied)
		table.trouble.connect(_on_trouble)

	_build_status(container, table)
	_build_chat(container, table)
	_build_feed(container, table)
	_build_leaving(container)


func _build_status(container: Container, table: TableSession) -> void:
	var section := Widgets.section(container, table.campaign_name if not table.campaign_name.is_empty() else "The table", ctx.palette)

	_status = Widgets.text(section, _status_text(table), ctx.palette, Widgets.FONT_BODY)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(1, 0)
	_status.add_theme_color_override(
		"font_color", ctx.palette.accent if table.is_connected_to_table() else ctx.palette.warning
	)

	# Which hero is committed. A player who joined with the wrong character
	# should be able to see that at a glance rather than discover it when the GM
	# reads out the wrong durability.
	var hero := ctx.doc.get_hero_name() if ctx.doc != null else ""
	Widgets.muted_text(
		section,
		"Playing %s at this table." % (hero if not hero.is_empty() else "an unnamed hero"),
		ctx.palette,
		Widgets.FONT_CAPTION
	)

	if not _last_award.is_empty():
		var note := Widgets.text(section, _last_award, ctx.palette, Widgets.FONT_DETAIL, ctx.palette.accent)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(1, 0)


func _status_text(table: TableSession) -> String:
	if table.is_connected_to_table():
		return "At the table."
	return "Not connected. Your character is still yours to edit; nothing reaches the GM until you rejoin."


func _build_chat(container: Container, table: TableSession) -> void:
	var section := Widgets.section(container, "Say something", ctx.palette)

	_chat_field = LineEdit.new()
	_chat_field.name = "TableChatField"
	_chat_field.placeholder_text = "Message the table"
	_chat_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_field.custom_minimum_size = Vector2(0, 40)
	_chat_field.text_submitted.connect(func(_text: String): _send(table))
	section.add_child(_chat_field)

	_private_toggle = CheckButton.new()
	_private_toggle.text = "Only the GM sees this"
	_private_toggle.add_theme_color_override("font_color", ctx.palette.text)
	section.add_child(_private_toggle)

	var send := Button.new()
	send.name = "SendChatButton"
	send.text = "Send"
	send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	send.custom_minimum_size = Vector2(0, 40)
	send.clip_text = true
	send.pressed.connect(func(): _send(table))
	section.add_child(send)


func _build_feed(container: Container, table: TableSession) -> void:
	var section := Widgets.section(container, "Table log", ctx.palette)
	_feed_empty = Widgets.muted_text(section, "Nothing has happened yet.", ctx.palette)

	_feed_list = VBoxContainer.new()
	_feed_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feed_list.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	section.add_child(_feed_list)
	_render_feed(table)


func _build_leaving(container: Container) -> void:
	var leave := Button.new()
	leave.name = "LeaveTableButton"
	leave.text = "Leave the table"
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.custom_minimum_size = Vector2(0, 40)
	leave.clip_text = true
	leave.pressed.connect(_on_leave_pressed)
	container.add_child(leave)


func _render_feed(table: TableSession) -> void:
	if _feed_list == null:
		return
	for child in _feed_list.get_children():
		_feed_list.remove_child(child)
		child.queue_free()

	var recent := table.recent()
	_feed_empty.visible = recent.is_empty()
	for event in recent:
		var row := Label.new()
		row.text = table.describe(event)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(1, 0)
		row.add_theme_color_override("font_color", ctx.palette.text)
		row.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
		_feed_list.add_child(row)


# --- Reacting --------------------------------------------------------------

func _on_table_changed() -> void:
	if ctx == null or ctx.table == null or _feed_list == null or not is_instance_valid(_feed_list):
		return
	# Only the parts that move. A full rebuild would take the cursor out of the
	# message box every time anybody at the table said anything.
	_render_feed(ctx.table)
	if _status != null and is_instance_valid(_status):
		_status.text = _status_text(ctx.table)


func _on_ap_applied(amount: int, reason: String) -> void:
	_last_award = "The GM awarded you %d achievement point%s -- %s. Added to your hero." % [
		amount, "" if amount == 1 else "s", reason
	]
	# The character changed, so the sheet is rebuilding anyway; this only needs
	# to make sure the note is on screen when it does.
	refresh(true)


func _on_trouble(message: String) -> void:
	if _status == null or not is_instance_valid(_status):
		return
	_status.text = message
	_status.add_theme_color_override("font_color", ctx.palette.warning)


func _send(table: TableSession) -> void:
	if _chat_field == null:
		return
	table.send_chat(_chat_field.text, _private_toggle.button_pressed)
	_chat_field.text = ""


func _on_leave_pressed() -> void:
	if ctx != null and ctx.table != null:
		# The shell owns what happens next -- it has to take the sheet down and
		# put the character list back -- so this only says the player asked.
		ctx.table.leave_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed(&"table_chat") and _chat_field != null:
		_chat_field.grab_focus()
		get_viewport().set_input_as_handled()
