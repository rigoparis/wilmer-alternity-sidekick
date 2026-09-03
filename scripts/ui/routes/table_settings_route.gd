extends RouteScene
##
## Running the table, as opposed to running the game.
##
## Everything here was on the GM's main screen and should not have been. Opening
## and closing the table, removing a seat, leaving the campaign: all rare, all
## disruptive, and all one mis-tap away from ending a session that four people
## are in the middle of. A GM reaches for these deliberately or not at all.
##
## What is deliberately absent is transferring the GM role. There is one GM per
## campaign and it is the device hosting; a button that hands that over mid
## session has no good outcome, and the seat list has no business offering it.
##
## Closes with a Dictionary naming what the GM chose:
##
##     {"action": "toggle_hosting"}
##     {"action": "remove_seat", "player_id": ...}
##     {"action": "leave"}
##
## or null for "nothing, I was just looking". The caller performs the action --
## this route only asks, because closing a table means tearing down a socket that
## belongs to the screen, not to a dialog.
##

const CONFIRM_ROUTE := preload("res://scenes/ui/routes/confirm_route.tscn")

var _palette: ThemePalette
var _session: CampaignSession
var _hosting: bool = false
var _connected: Array = []
var _addresses: String = ""
var _router: UiRouter


## props:
##   palette    ThemePalette
##   session    CampaignSession
##   hosting    bool
##   connected  Array of player_ids currently connected
##   addresses  String, this device's addresses for the read-it-out fallback
##   router     UiRouter, for the confirmations
func configure(props: Dictionary) -> void:
	_palette = props.get("palette", ThemePalette.new())
	_session = props.get("session")
	_hosting = bool(props.get("hosting", false))
	var given = props.get("connected", [])
	_connected = given if typeof(given) == TYPE_ARRAY else []
	_addresses = String(props.get("addresses", ""))
	_router = props.get("router")
	_build()


func preferred_presentation() -> int:
	return UiRouter.Presentation.PAGE


func title() -> String:
	return "Table settings"


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

	_build_connection(column)
	_build_seats(column)
	_build_leaving(column)

	var done := Button.new()
	done.name = "DoneButton"
	done.text = "Done"
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.custom_minimum_size = Vector2(0, 42)
	done.pressed.connect(func(): close(null))
	column.add_child(done)


func _build_connection(parent: Container) -> void:
	var section := Widgets.section(parent, "The table", _palette)

	var status := Widgets.text(
		section,
		"Open -- players on this network can join." if _hosting else "Closed -- nobody can join.",
		_palette
	)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(1, 0)
	status.add_theme_color_override("font_color", _palette.accent if _hosting else _palette.muted)

	if _hosting and not _addresses.is_empty():
		# Worth showing even when discovery works: reading an address out is the
		# only thing left when a guest network blocks broadcast.
		var hint := Widgets.muted_text(
			section,
			"Players can search for this table, or type: %s" % _addresses,
			_palette,
			Widgets.FONT_CAPTION
		)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(1, 0)

	var toggle := Button.new()
	toggle.name = "ToggleHostingButton"
	toggle.text = "Close the table" if _hosting else "Open the table"
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.custom_minimum_size = Vector2(0, 42)
	if _hosting:
		toggle.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.warning, 6))
		toggle.add_theme_color_override("font_color", _palette.warning)
	else:
		toggle.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
	toggle.pressed.connect(_on_toggle_hosting)
	section.add_child(toggle)


## Seats, and the only thing that can be done to one.
##
## No character dropdown: a player commits their own hero, and a GM reaching in
## to change it is exactly the ownership violation the rest of this feature is
## built to prevent. Removing somebody who is genuinely gone is a different
## thing, and it is here rather than on the main screen because it is rare.
func _build_seats(parent: Container) -> void:
	var section := Widgets.section(parent, "Seats", _palette)
	if _session == null or _session.seats.is_empty():
		Widgets.muted_text(section, "Nobody has joined yet.", _palette, Widgets.FONT_CAPTION)
		return

	for seat in _session.seats:
		if bool(seat.get("is_gm", false)):
			continue
		var player_id := String(seat.get("player_id", ""))
		var player_name := String(seat.get("player_name", "Someone"))

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", Widgets.GAP_ROW)
		section.add_child(row)

		var label := VBoxContainer.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_constant_override("separation", 0)
		row.add_child(label)
		Widgets.text(label, player_name, _palette, Widgets.FONT_BODY)
		var hero := CharacterSnapshot.hero_name_of(_session.committed_character(player_id))
		Widgets.muted_text(
			label,
			("playing %s" % hero if not hero.is_empty() else "no character committed")
			+ ("  -  connected" if _connected.has(player_id) else ""),
			_palette,
			Widgets.FONT_CAPTION
		)

		var remove := Button.new()
		remove.text = "Remove"
		remove.custom_minimum_size = Vector2(92, 38)
		remove.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.warning, 6))
		remove.add_theme_color_override("font_color", _palette.warning)
		remove.pressed.connect(_on_remove_pressed.bind(player_id, player_name))
		row.add_child(remove)


func _build_leaving(parent: Container) -> void:
	var section := Widgets.section(parent, "This campaign", _palette)
	var note := Widgets.muted_text(
		section,
		"Leaving closes the table and returns to the campaign list. Nothing is lost -- the log and every seat are saved.",
		_palette,
		Widgets.FONT_CAPTION
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(1, 0)

	var leave := Button.new()
	leave.name = "LeaveCampaignButton"
	leave.text = "Leave the campaign"
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.custom_minimum_size = Vector2(0, 42)
	leave.pressed.connect(func(): close({"action": "leave"}))
	section.add_child(leave)


# --- Actions ---------------------------------------------------------------

## Closing a table with people at it is confirmed; opening one is not.
##
## The asymmetry is the point. Opening is harmless and undoable; closing drops
## everybody mid-session, which is the mis-tap this whole route exists to make
## hard.
func _on_toggle_hosting() -> void:
	if not _hosting or _router == null or _connected.is_empty():
		close({"action": "toggle_hosting"})
		return

	var confirmed = await _router.push(CONFIRM_ROUTE, {
		"palette": _palette,
		"title": "Close the table?",
		"message": "%d %s connected. They will be dropped, and their seats and history are kept." % [
			_connected.size(), "player is" if _connected.size() == 1 else "players are"
		],
		"confirm_text": "Close it",
		"destructive": true,
	})
	if not is_instance_valid(self):
		return
	if confirmed == true:
		close({"action": "toggle_hosting"})


func _on_remove_pressed(player_id: String, player_name: String) -> void:
	if _router == null:
		close({"action": "remove_seat", "player_id": player_id})
		return

	var confirmed = await _router.push(CONFIRM_ROUTE, {
		"palette": _palette,
		"title": "Remove %s?" % player_name,
		"message": "Their seat, their committed character and their achievement points go. What they did stays in the log.",
		"confirm_text": "Remove",
		"destructive": true,
	})
	if not is_instance_valid(self):
		return
	if confirmed == true:
		close({"action": "remove_seat", "player_id": player_id})
