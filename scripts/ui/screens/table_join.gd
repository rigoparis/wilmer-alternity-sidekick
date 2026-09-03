class_name TableJoinScreen
extends Control
##
## The player's half of joining: find the GM, or type their address.
##
## Search first, typing second, and never only one of them. Discovery fails for
## boring reasons that have nothing to do with this app -- a guest network with
## client isolation, an unanswered firewall prompt, a phone that quietly stayed
## on mobile data -- and a join screen that offers no way past those is a join
## screen that strands a table for the evening.
##
## Identity is a device thing, not a campaign thing: this screen remembers the
## player_id the GM gave it last time and offers it back on the next join, which
## is what turns "a stranger appeared" into "she's back".
##

## A table was joined. The transport is handed over live, already handshaking.
signal table_joined(transport: EnetTransport, campaign_name: String)

## Leave without joining.
signal closed

## How often a question goes out while this screen is open, in seconds. A GM may
## start hosting after the player opened the screen, so asking once is not
## enough; asking every frame would flood the network for nothing.
const ASK_INTERVAL := 1.5

var _identity: PlayerIdentity
var _palette: ThemePalette

var _discovery: LanDiscovery
var _transport: EnetTransport
var _ask_clock: float = 0.0

## What the table said it was called, kept from the moment of joining so the
## table view has a title before the first event arrives.
var _joining_name: String = ""
var _joining_campaign_id: String = ""

var _name_field: LineEdit
var _address_field: LineEdit
var _status: Label
var _found_list: VBoxContainer
var _searching_note: Label


func setup(identity: PlayerIdentity, palette: ThemePalette) -> void:
	_identity = identity
	_palette = palette
	_build()
	_start_searching()


func _build() -> void:
	var root_box := VBoxContainer.new()
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_box.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	add_child(root_box)

	var column := Widgets.page_column(root_box, _is_wide())
	column.add_theme_constant_override("separation", 20)

	var intro := Widgets.section(column, "Join a table", _palette)
	var blurb := Widgets.muted_text(
		intro,
		"Your GM opens their table, and this device finds it on the same Wi-Fi.",
		_palette
	)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(1, 0)

	_name_field = LineEdit.new()
	_name_field.text = _identity.player_name()
	_name_field.placeholder_text = "Your name"
	_name_field.custom_minimum_size = Vector2(0, 40)
	Widgets.field_row(intro, "Name", _name_field, _palette)

	_status = Widgets.text(intro, "Searching for tables...", _palette, Widgets.FONT_BODY)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(1, 0)

	var found := Widgets.section(column, "Tables on this network", _palette)
	_searching_note = Widgets.muted_text(
		found,
		"Nothing yet. The GM has to open their table before it appears here.",
		_palette,
		Widgets.FONT_CAPTION
	)
	_searching_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_searching_note.custom_minimum_size = Vector2(1, 0)
	_found_list = VBoxContainer.new()
	_found_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_found_list.add_theme_constant_override("separation", Widgets.GAP_ROW)
	found.add_child(_found_list)

	# Always present, never a fallback the person has to go looking for.
	var manual := Widgets.section(column, "Or type the GM's address", _palette)
	_address_field = LineEdit.new()
	_address_field.placeholder_text = "192.168.1.24"
	_address_field.custom_minimum_size = Vector2(0, 40)
	_address_field.text_submitted.connect(func(text: String): _join(text.strip_edges(), EnetTransport.DEFAULT_PORT, "", ""))
	Widgets.field_row(manual, "Address", _address_field, _palette)

	var connect_button := Button.new()
	connect_button.name = "ConnectButton"
	connect_button.text = "Connect"
	connect_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	connect_button.custom_minimum_size = Vector2(0, 40)
	connect_button.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
	connect_button.pressed.connect(func(): _join(_address_field.text.strip_edges(), EnetTransport.DEFAULT_PORT, "", ""))
	manual.add_child(connect_button)

	var back := Button.new()
	back.name = "BackButton"
	back.text = "Back"
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.custom_minimum_size = Vector2(0, 40)
	back.pressed.connect(func(): closed.emit())
	column.add_child(back)


func _is_wide() -> bool:
	return get_viewport_rect().size.x >= ModalHost.COMPACT_WIDTH


# --- Searching -------------------------------------------------------------

func _start_searching() -> void:
	_discovery = LanDiscovery.new()
	if _discovery.search() != OK:
		# Not fatal. The address box below is the whole reason it is not.
		_status.text = "Cannot search this network. Type the GM's address instead."
		_status.add_theme_color_override("font_color", _palette.warning)
		_discovery = null
		set_process(_transport != null)
		return
	_discovery.host_found.connect(func(_a: String, _p: int, _n: String, _i: String): _render_found())
	_discovery.ask()
	set_process(true)


func _process(delta: float) -> void:
	if _discovery != null:
		_discovery.poll()
		_ask_clock += delta
		if _ask_clock >= ASK_INTERVAL:
			_ask_clock = 0.0
			_discovery.ask()
			# Hosts age out of the list on their own, so a GM who quit stops
			# being offered rather than sitting there unjoinable.
			_render_found()
	if _transport != null:
		_transport.poll()


func _render_found() -> void:
	if _found_list == null or _discovery == null:
		return
	for child in _found_list.get_children():
		_found_list.remove_child(child)
		child.queue_free()

	var hosts: Array = _discovery.hosts()
	_searching_note.visible = hosts.is_empty()
	for entry in hosts:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", Widgets.GAP_ROW)
		_found_list.add_child(row)

		var label := VBoxContainer.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_constant_override("separation", 0)
		row.add_child(label)
		Widgets.text(label, String(entry.get("campaign_name", "A campaign")), _palette, Widgets.FONT_SUBHEADING)
		Widgets.muted_text(label, String(entry.get("address", "")), _palette, Widgets.FONT_CAPTION)

		var join_button := Button.new()
		join_button.text = "Join"
		join_button.custom_minimum_size = Vector2(88, 40)
		join_button.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
		join_button.pressed.connect(_join.bind(
			String(entry.get("address", "")),
			AlternityNum.as_int(entry.get("port", EnetTransport.DEFAULT_PORT)),
			String(entry.get("campaign_id", "")),
			String(entry.get("campaign_name", "A campaign"))
		))
		row.add_child(join_button)


# --- Joining ---------------------------------------------------------------

func _join(address: String, port: int, campaign_id: String, campaign_name: String) -> void:
	if address.is_empty():
		_status.text = "Type the address the GM read out, or wait for their table to appear."
		_status.add_theme_color_override("font_color", _palette.warning)
		return

	var player_name := _name_field.text.strip_edges()
	if player_name.is_empty():
		player_name = "Player"
	_identity.set_player_name(player_name)

	_status.text = "Connecting to %s..." % address
	_status.add_theme_color_override("font_color", _palette.text)

	_joining_name = campaign_name
	_joining_campaign_id = campaign_id

	_transport = EnetTransport.new()
	_transport.player_connected.connect(_on_welcomed)
	_transport.transport_error.connect(_on_error)

	# The id and sequence this device already holds for that campaign. Handing
	# them over is what makes the GM see a returning player rather than a new
	# one, and what limits the replay to the gap.
	var known := _identity.for_campaign(campaign_id)
	var result: int = _transport.join(
		address,
		port,
		String(known.get("player_id", "")),
		player_name,
		AlternityNum.as_int(known.get("last_seq", 0))
	)
	if result != OK:
		_transport = null
		return
	set_process(true)


func _on_welcomed(player_id: String, is_reconnect: bool) -> void:
	# The GM is the authority on identity: a first join is where this device learns
	# the id it will present for the rest of the campaign. A join by typed address
	# has no campaign_id until the welcome arrives, which is why remember() takes
	# it from the transport rather than from what was tapped.
	var campaign_id := _transport.campaign_id()
	if _joining_name.is_empty():
		_joining_name = _transport.campaign_name()
	_identity.remember(campaign_id, player_id, 0, _joining_name)
	_status.text = "Welcome back." if is_reconnect else "You are at the table."
	_status.add_theme_color_override("font_color", _palette.accent)

	var transport := _transport
	# Handed over rather than closed: the connection this screen opened is the
	# one the table view carries on with.
	_transport = null
	_stop()
	table_joined.emit(transport, _joining_name)


func _on_error(message: String) -> void:
	_status.text = message
	_status.add_theme_color_override("font_color", _palette.warning)
	if _transport != null and not _transport.is_connected_to_table():
		_transport.leave()
		_transport = null


func _stop() -> void:
	if _discovery != null:
		_discovery.stop()
		_discovery = null
	set_process(false)


func _exit_tree() -> void:
	# A transport still held here was never handed on, so nothing else will close
	# it. Leaving the screen must not leak a half-open connection.
	if _transport != null:
		_transport.leave()
		_transport = null
	_stop()
