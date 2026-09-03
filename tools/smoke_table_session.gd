extends "res://tools/test_harness.gd"
##
## Two shells in one process: a GM hosting and a player joining.
##
## Phase M2's checkpoint, as close as one machine can get to it -- a roll on the
## player device appearing on the GM's feed, a private line, an AP award landing
## on the player's own hero, and a mid-session reconnect that loses nothing.
##
## The one thing this cannot prove is the broadcast half of discovery, which
## does not loop back on one host; the player here joins by address, which is the
## supported path anyway. MULTIPLAYER.md's two-device check still stands for the
## rest.
##
## Both shells use scratch directories, and separate ones: a player device and a
## GM device do not share a character folder, and pointing them at the same one
## would hide exactly the bugs this suite exists to find.
##

const SHELL := preload("res://scenes/ui/app_shell.tscn")
const Session := preload("res://scripts/core/session/campaign_session.gd")
const Transport := preload("res://scripts/core/session/enet_transport.gd")

const GM_DIR := "user://__table_gm__/"
const GM_CAMPAIGNS := "user://__table_gm_campaigns__/"
const PLAYER_DIR := "user://__table_player__/"
const PLAYER_CAMPAIGNS := "user://__table_player_campaigns__/"

var _gm_shell
var _player_shell
var _gm
var _joined_player_id: String = ""


func _init() -> void:
	begin_async("table session", 4000)
	_run.call_deferred()


func _run() -> void:
	for dir_path in [GM_DIR, GM_CAMPAIGNS, PLAYER_DIR, PLAYER_CAMPAIGNS]:
		_wipe(dir_path)

	_gm_shell = _new_shell(GM_DIR, GM_CAMPAIGNS)
	_player_shell = _new_shell(PLAYER_DIR, PLAYER_CAMPAIGNS)
	await process_frame
	await process_frame

	await _test_gm_opens_the_table()
	await _test_player_joins()
	await _test_roll_reaches_the_gm_feed()
	await _test_private_line()
	await _test_ap_award_reaches_the_player()
	await _test_player_applies_ap_to_their_own_hero()
	await _test_reconnect_loses_nothing()
	await _test_leaving_closes_the_table()

	_teardown()
	for dir_path in [GM_DIR, GM_CAMPAIGNS, PLAYER_DIR, PLAYER_CAMPAIGNS]:
		_wipe(dir_path)
	finish()


func _new_shell(store_dir: String, campaign_dir: String):
	var shell = SHELL.instantiate()
	shell.store_directory = store_dir
	shell.campaign_directory = campaign_dir
	root.add_child(shell)
	return shell


func _teardown() -> void:
	for shell in [_player_shell, _gm_shell]:
		if shell != null and is_instance_valid(shell):
			shell.queue_free()
	_gm_shell = null
	_player_shell = null


func _wipe(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name in dir.get_files():
		DirAccess.remove_absolute(dir_path + file_name)


func _screen(shell, fragment: String) -> Node:
	var host: Node = shell.get_node_or_null("Screens")
	if host == null:
		return null
	for child in host.get_children():
		var script = child.get_script()
		if script != null and String(script.resource_path).contains(fragment):
			return child
	return null


## Wait on an outcome rather than on a frame count. Both shells poll themselves
## from _process, so all this has to do is let frames pass.
func _wait_for(condition: Callable, max_frames: int = 300) -> bool:
	for _i in max_frames:
		if condition.call():
			return true
		await process_frame
	return condition.call()


func _player_table():
	return _screen(_player_shell, "player_table")


## Answer whatever route the GM shell has open, the way a person would.
func _answer_gm_route(result: Variant) -> void:
	var responder := func() -> void:
		await process_frame
		var route = _gm_shell.router._host.top_route()
		if route != null:
			route.close(result)
	responder.call_deferred()


## Re-found rather than cached.
##
## The shell owns screen lifetime and rebuilds on a resize, so a reference held
## across frames can be stale. Caching one hid that behind "previously freed"
## rather than showing which step lost it.
func _gm_screen():
	return _screen(_gm_shell, "gm_screen")


## The one seat that is not the GM's.
##
## Opening the table gives the campaign a GM seat if it has none, so the player
## is not simply "the first seat" -- and assuming they were is how a test starts
## asserting about the GM's own row.
func _player_seat() -> Dictionary:
	for seat in _gm_screen().session().seats:
		if not bool(seat.get("is_gm", false)):
			return seat
	return {}


# --- Hosting ---------------------------------------------------------------

func _test_gm_opens_the_table() -> void:
	var select = _screen(_gm_shell, "character_select")
	if not check(select != null, "the GM shell starts on the character list"):
		return
	select.campaigns_opened.emit()
	await process_frame

	var campaigns = _screen(_gm_shell, "campaign_select")
	if not check(campaigns != null, "the GM reaches the campaign list"):
		return

	var session = Session.new("The Verge")
	_gm_shell.campaigns.save(session)
	campaigns._on_open_pressed(session.campaign_id)
	await process_frame

	_gm = _gm_screen()
	if not check(_gm != null, "the GM opens the campaign"):
		return
	check_false(_gm.is_hosting(), "a campaign starts closed, usable on one device")

	_gm._toggle_hosting()
	await process_frame
	check_true(_gm.is_hosting(), "the GM can open the table")
	check_true(_gm_screen().transport() != null, "which brings up a transport")
	check_eq(_gm_screen().transport().local_role(), Transport.Role.GM, "in the GM role")

	# A table with no GM seat has nowhere to deliver a private line, so opening
	# one makes this device the GM if the campaign did not already say who was.
	check_false(_gm_screen().session().gm_seat().is_empty(), "opening the table seats a GM")
	check_eq(_gm_screen().session().seats.size(), 1, "and only that one seat so far")


# --- Joining ---------------------------------------------------------------

func _test_player_joins() -> void:
	var select = _screen(_player_shell, "character_select")
	if not check(select != null, "the player shell starts on the character list"):
		return
	select.campaigns_opened.emit()
	await process_frame

	var campaigns = _screen(_player_shell, "campaign_select")
	if not check(campaigns != null, "the player reaches the campaign list"):
		return
	campaigns.join_requested.emit()
	await process_frame

	var join = _screen(_player_shell, "table_join")
	if not check(join != null, "which offers joining somebody else's table"):
		return
	check_eq(_player_shell.identity.player_name(), "", "this device has no name yet")

	join._name_field.text = "Alice"
	join._join("127.0.0.1", Transport.DEFAULT_PORT, "", "")
	var at_table := await _wait_for(func(): return _player_table() != null)
	check_true(at_table, "joining reaches the player's table view")
	if not at_table:
		return

	check_eq(_player_shell.identity.player_name(), "Alice", "the device remembers the name given")
	check_eq(_gm_screen().session().seats.size(), 2, "the GM seated them alongside their own seat")
	_joined_player_id = String(_player_seat().get("player_id", ""))
	check_eq(String(_player_seat().get("player_name", "")), "Alice", "under the name they gave")
	check_false(bool(_player_seat().get("is_gm", false)), "and a joining player is not made GM")

	# Identity is what makes next week work, so it has to be on disk now rather
	# than only in memory.
	var campaign_id: String = _gm_screen().session().campaign_id
	check_eq(
		_player_shell.identity.player_id_for(campaign_id), _joined_player_id,
		"the device stored the id the GM issued"
	)
	var reloaded = PlayerIdentity.new(PLAYER_DIR)
	check_eq(
		reloaded.player_id_for(campaign_id), _joined_player_id,
		"and it survives a restart, which is what a reconnect depends on"
	)
	check_eq(reloaded.player_name(), "Alice", "as does the name")

	# The player's device must not have acquired a campaign file. One campaign,
	# one owner -- the GM's.
	check_eq(_player_shell.campaigns.list().size(), 0, "a player device keeps no campaign of its own")


# --- Play ------------------------------------------------------------------

func _test_roll_reaches_the_gm_feed() -> void:
	var table = _player_table()
	if not check(table != null, "the player is at the table"):
		return

	var before: int = _gm_screen().session().events.size()
	table._transport.send_roll({
		"notation": "d20+d4",
		"dice": [17, 3],
		"total": 20,
		"label": "Action check",
		"source": "physical",
	})

	var landed := await _wait_for(func(): return _gm_screen().session().events.size() > before)
	check_true(landed, "the roll reaches the GM")
	if not landed:
		return

	var logged: Dictionary = _gm_screen().session().events[_gm_screen().session().events.size() - 1]
	check_eq(String(logged.get("kind", "")), Session.EVENT_ROLL, "as a roll event")
	check_eq(AlternityNum.as_int(logged.get("payload", {}).get("total", 0)), 20, "with the settled total")
	check_eq(String(logged.get("player_id", "")), _joined_player_id, "attributed to the player's stable id")

	# It has to be visible, not merely stored.
	var lines: Array = []
	for child in _gm_screen()._feed_list.get_children():
		lines.append(child.text)
	check_true(lines.size() > 0, "the GM's feed has something in it")
	check_true(String(lines[0]).contains("Action check"), "the newest line is the roll")
	check_true(String(lines[0]).contains("20"), "showing its total")
	check_true(String(lines[0]).contains("Alice"), "and naming the player, not an id")

	# And it must be on disk without waiting for anyone to press save.
	var stored = _gm_shell.campaigns.load_session(_gm_screen().session().campaign_id)
	check_eq(
		AlternityNum.as_int(stored.events[stored.events.size() - 1].get("payload", {}).get("total", 0)), 20,
		"the roll is flushed to the log as it arrives"
	)


func _test_private_line() -> void:
	var table = _player_table()
	var before: int = _gm_screen().session().events.size()

	table._chat_field.text = "can I check for traps quietly?"
	table._private_toggle.button_pressed = true
	table._send_chat()

	var landed := await _wait_for(func(): return _gm_screen().session().events.size() > before)
	check_true(landed, "a private line reaches the GM")
	if not landed:
		return

	var logged: Dictionary = _gm_screen().session().events[_gm_screen().session().events.size() - 1]
	var gm_seat_id := String(_gm_screen().session().gm_seat().get("player_id", ""))
	# The player device never learns seat ids, so it addresses the GM by a
	# sentinel and the host resolves it. What lands in the log must be the real
	# seat, or events_for() would never find it again.
	check_eq(String(logged.get("payload", {}).get("to", "")), gm_seat_id,
		"addressed to the GM's actual seat, not to the sentinel the client sent")
	check_ne(String(logged.get("payload", {}).get("to", "")), Transport.TO_GM, "the sentinel does not reach the log")
	check_eq(_chat_field_text(table), "", "the message box is cleared after sending")

	var lines: Array = []
	for child in _gm_screen()._feed_list.get_children():
		lines.append(child.text)
	check_true(String(lines[0]).contains("private"), "the GM's feed marks it as private")


func _chat_field_text(table) -> String:
	return table._chat_field.text


func _test_ap_award_reaches_the_player() -> void:
	var table = _player_table()
	check_eq(table.unclaimed_ap(), 0, "the player has no awards yet")

	# Exactly what the GM screen does when the award dialog is confirmed.
	var awarded: Dictionary = _gm_screen().session().award_ap(_joined_player_id, 3, Session.AP_REASON_HEROISM)
	_gm_screen().transport()._deliver(awarded)
	_gm_shell.campaigns.save(_gm_screen().session())

	var arrived := await _wait_for(func(): return table.unclaimed_ap() > 0)
	check_true(arrived, "the award reaches the player device")
	if not arrived:
		return
	check_eq(table.unclaimed_ap(), 3, "with the right amount")

	var lines: Array = []
	for child in table._feed_list.get_children():
		lines.append(child.text)
	check_true(String(lines[0]).contains("3 AP"), "the player's feed shows the award")
	check_true(String(lines[0]).contains(Session.AP_REASON_HEROISM), "and what it was for")
	check_true(String(lines[0]).begins_with("You"), "addressed to them rather than to an id")


## The conflict rule, made concrete.
##
## The GM awarded the points; the player's device is what writes them into a
## character file. The GM never touches a hero they cannot see.
func _test_player_applies_ap_to_their_own_hero() -> void:
	var table = _player_table()

	var doc = CharacterDoc.new(_player_shell.rules)
	doc.set_hero_name("Vance Kellar")
	_player_shell.store.save(doc)
	var before: int = AlternityNum.as_int(doc.raw().get("achievement_points", 0))

	table._render_ap()
	await process_frame
	check_false(table._claim_button.disabled, "the claim button is live once there is something to claim")

	table._on_claim_pressed()
	await process_frame

	var reloaded = _player_shell.store.load_doc("Vance_Kellar.json")
	check(reloaded != null, "the hero is still there")
	if reloaded == null:
		return
	check_eq(
		AlternityNum.as_int(reloaded.raw().get("achievement_points", 0)), before + 3,
		"the awarded points landed on the player's own character file"
	)
	check_eq(table.unclaimed_ap(), 0, "and are no longer waiting")
	check_true(table._claim_button.disabled, "so the button goes quiet")

	# The GM's copy is unchanged: the seat ledger is the GM's record of what was
	# given, not a second copy of the character.
	check_eq(_gm_screen().session().get_seat_ap(_joined_player_id), 3, "the GM's ledger still records the award")
	check_eq(_gm_shell.store.list().size(), 0, "and the GM device never gained a character file")


# --- Reconnect -------------------------------------------------------------

## Phase M2's checkpoint: a mid-session reconnect that loses nothing.
func _test_reconnect_loses_nothing() -> void:
	var table = _player_table()
	var campaign_id: String = _gm_screen().session().campaign_id
	var seq_before: int = AlternityNum.as_int(
		_player_shell.identity.for_campaign(campaign_id).get("last_seq", 0)
	)
	check_true(seq_before > 0, "the device knows how far its copy got")

	# The player walks out of the room. Back to the campaign list, which tears
	# the table view down and with it the connection.
	table.closed.emit()
	var gone := await _wait_for(func(): return _gm_screen().transport().connected_players().is_empty())
	check_true(gone, "the GM sees them drop")
	check_true(_gm_screen().session().has_seat(_joined_player_id), "their seat survives")
	check_eq(_gm_screen().session().get_seat_ap(_joined_player_id), 3, "and so does their AP")

	# The table carries on without them.
	_gm_screen().transport().broadcast_event(Session.EVENT_NOTE, "", {"text": "the door gives way"})
	_gm_screen().transport().broadcast_event(Session.EVENT_NOTE, "", {"text": "something moves inside"})
	var missed: int = _gm_screen().session().last_seq() - seq_before

	var campaigns = _screen(_player_shell, "campaign_select")
	if not check(campaigns != null, "the player is back at the campaign list"):
		return
	campaigns.join_requested.emit()
	await process_frame
	var join = _screen(_player_shell, "table_join")
	if not check(join != null, "and can join again"):
		return

	# The same device, a brand new peer id. Only the stored player_id survived,
	# and it is what the host matches on.
	join._join("127.0.0.1", Transport.DEFAULT_PORT, campaign_id, "The Verge")
	var back := await _wait_for(func(): return _player_table() != null)
	check_true(back, "the player rejoins")
	if not back:
		return

	check_eq(_gm_screen().session().seats.size(), 2, "rejoining does not create a third seat")
	check_eq(
		String(_player_seat().get("player_id", "")), _joined_player_id,
		"they came back to the same seat"
	)

	var rejoined = _player_table()
	var caught_up := await _wait_for(func(): return rejoined.events().size() >= missed)
	check_true(caught_up, "and is sent what they missed")
	if not caught_up:
		return
	check_eq(rejoined.events().size(), missed, "exactly what they missed, not the whole campaign")

	var texts: Array = []
	for event in rejoined.events():
		texts.append(String(event.get("payload", {}).get("text", "")))
	check_true(texts.has("the door gives way"), "including the first thing they missed")
	check_true(texts.has("something moves inside"), "and the last")

	check_eq(
		AlternityNum.as_int(_player_shell.identity.for_campaign(campaign_id).get("last_seq", 0)),
		_gm_screen().session().last_seq(),
		"and the device is caught up for next time"
	)


func _test_leaving_closes_the_table() -> void:
	# Closing the campaign must take the socket with it, or the GM's device keeps
	# answering for a campaign nobody is looking at.
	var gm = _gm_screen()
	if not check(gm != null and gm.is_hosting(), "the table is open before closing"):
		return
	# Held across the close: the screen itself is freed by the shell, so it is
	# the transport that has to be asked whether the socket went with it.
	var transport = gm.transport()
	# Leaving is a settings action now, not a header button -- closing a table
	# four people are at should not be one mis-tap away.
	_answer_gm_route({"action": "leave"})
	await gm._on_settings_pressed()
	await process_frame
	check_true(_gm_screen() == null, "closing the campaign leaves the GM screen")
	check_false(transport.is_connected_to_table(), "and closes the table with it")

	var lonely = Transport.new()
	var failures := []
	var welcomes := []
	lonely.transport_error.connect(func(_m: String): failures.append(true))
	lonely.player_connected.connect(func(_id: String, _r: bool): welcomes.append(true))
	lonely.join("127.0.0.1", Transport.DEFAULT_PORT, "", "Too late")
	for _i in 60:
		lonely.poll()
		await process_frame
	check_eq(welcomes.size(), 0, "and nobody can join a closed table")
	lonely.leave()
