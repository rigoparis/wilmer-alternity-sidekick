extends "res://tools/test_harness.gd"
##
## Two ENet peers in one process, over the loopback.
##
## MULTIPLAYER.md asks for exactly this before trusting reconnect, and it is the
## reason the transport is built on packets rather than on MultiplayerAPI: a
## scoped MultiplayerAPI per peer would need two node subtrees to talk to each
## other inside one SceneTree.
##
## Polling is driven by hand rather than by a frame signal, so each step waits
## for the packet it expects instead of hoping a fixed number of frames was
## enough. A test that sleeps for three frames and asserts is a test that fails
## on a loaded CI machine and nowhere else.
##

const Session := preload("res://scripts/core/session/campaign_session.gd")
const Transport := preload("res://scripts/core/session/enet_transport.gd")

## Away from the default so a real GM app running on this machine does not make
## the suite fail.
const PORT := 47899

var _host
var _client
var _session


func _init() -> void:
	begin_async("enet transport", 3000)
	_run.call_deferred()


func _run() -> void:
	await _test_host_reports_a_port_in_use()
	await _test_handshake_seats_a_new_player()
	await _test_roll_travels_as_a_fact()
	await _test_chat_and_private_lines()
	await _test_gm_events_reach_the_player()
	await _test_reconnect_replays_the_gap()
	await _test_unknown_player_can_be_refused()
	await _test_peer_ids_never_escape()

	_teardown()
	finish()


func _teardown() -> void:
	for peer in _peers:
		peer.leave()
	_peers.clear()
	_client = null
	_host = null


## Every transport currently in play. A peer that is not polled receives
## nothing, so an extra client has to be registered here or the test that uses
## it fails for a reason that has nothing to do with the transport.
var _peers: Array = []


func _track(transport):
	_peers.append(transport)
	return transport


func _untrack(transport) -> void:
	_peers.erase(transport)
	transport.leave()


## Pump every peer until `condition` holds, or give up after `max_polls`.
##
## Returns whether it held. Everything in this suite waits on an observable
## outcome rather than on a frame count: a test that pumps a fixed number of
## frames and then asserts is a test that fails on a loaded machine only.
func _pump_until(condition: Callable, max_polls: int = 240) -> bool:
	for _i in max_polls:
		if condition.call():
			return true
		for peer in _peers:
			peer.poll()
		await process_frame
	return condition.call()


func _new_session() -> CampaignSession:
	var session = Session.new("Loopback")
	var gm := session.add_seat("Rodri")
	session.set_gm(gm)
	return session


# --- Hosting ---------------------------------------------------------------

## A port already in use must be reported, not swallowed.
##
## This is the failure that otherwise looks exactly like a hang: create_server()
## returns ERR_CANT_CREATE and, unchecked, the GM sees an app that simply never
## accepts anyone.
func _test_host_reports_a_port_in_use() -> void:
	_session = _new_session()
	_host = _track(Transport.new())
	check_eq(_host.host(_session, PORT), OK, "the host starts on a free port")
	check_true(_host.is_connected_to_table(), "the host counts as at the table immediately")
	check_eq(_host.local_role(), Transport.Role.GM, "the hosting device is the GM")

	# The engine logs "Couldn't create an ENet host" here. That is the failure
	# being provoked, not a fault in the suite.
	var second = Transport.new()
	var reported := []
	second.transport_error.connect(func(message: String): reported.append(message))
	var result: int = second.host(_new_session(), PORT)
	check_ne(result, OK, "hosting twice on one port fails rather than hanging")
	check_eq(reported.size(), 1, "and says so")
	check_true(String(reported[0]).contains(str(PORT)), "the message names the port")
	second.leave()


# --- Handshake -------------------------------------------------------------

func _test_handshake_seats_a_new_player() -> void:
	var seated := []
	_host.player_connected.connect(func(player_id: String, is_reconnect: bool): seated.append([player_id, is_reconnect]))

	_client = _track(Transport.new())
	var welcomed := []
	_client.player_connected.connect(func(player_id: String, is_reconnect: bool): welcomed.append([player_id, is_reconnect]))

	check_eq(_client.join("127.0.0.1", PORT, "", "Alice"), OK, "the client starts connecting")
	var arrived := await _pump_until(func(): return welcomed.size() > 0)
	check_true(arrived, "the client is welcomed")
	if not arrived:
		return

	check_true(_client.is_connected_to_table(), "the client is at the table once welcomed")
	check_eq(_client.local_role(), Transport.Role.PLAYER, "the joining device is a player")
	check_eq(seated.size(), 1, "the host saw one player connect")
	check_false(bool(seated[0][1]), "a player with no id is a new arrival, not a reconnect")

	var player_id := String(welcomed[0][0])
	check_false(player_id.is_empty(), "the client is told its permanent id")
	check_eq(player_id, String(seated[0][0]), "both ends agree on that id")
	check_eq(_session.seats.size(), 2, "the host seated them")
	check_eq(
		String(_session.seat_for(player_id).get("player_name", "")), "Alice",
		"the seat carries the name they gave"
	)
	check_true(
		AlternityNum.as_int(_session.seat_for(player_id).get("last_seen", 0)) > 0,
		"connecting records last_seen"
	)
	check_eq(_host.connected_players(), [player_id], "the host lists them as connected")

	# A first-time join is worth a log line.
	var joins := 0
	for event in _session.events:
		if String(event.get("kind", "")) == Session.EVENT_JOIN:
			joins += 1
	check_eq(joins, 1, "the arrival is logged once")


# --- Rolls -----------------------------------------------------------------

## The load-bearing rule: a roll travels as a settled fact.
##
## Nothing here re-rolls or re-simulates. The faces the player saw are the faces
## the GM sees, which is also how physical dice at a table work.
func _test_roll_travels_as_a_fact() -> void:
	var received := []
	_host.roll_received.connect(func(player_id: String, roll: Dictionary): received.append([player_id, roll]))

	var settled := {
		"notation": "d20+d4",
		"dice": [17, 3],
		"total": 20,
		"label": "Action check",
		"source": "physical",
	}
	_client.send_roll(settled)
	var arrived := await _pump_until(func(): return received.size() > 0)
	check_true(arrived, "the roll reaches the GM")
	if not arrived:
		return

	var roll: Dictionary = received[0][1]
	check_eq(AlternityNum.as_int(roll.get("total", 0)), 20, "the total arrives unchanged")
	check_eq(String(roll.get("source", "")), "physical", "the source of the faces is preserved")

	# JSON has one number type, so the faces arrive as 17.0 and 3.0 -- exactly as
	# they do coming back off disk. Read them the way a consumer does rather than
	# comparing the raw Variants, which is the check that would pass here and
	# still leave the GM's feed showing "17.0".
	var parsed := RollResult.from_dict(roll)
	check_eq(parsed.dice, [17, 3] as Array[int], "the individual faces arrive, so the GM sees what the player saw")
	check_eq(parsed.total, 20, "and rebuild into the same result the player saw")
	check_eq(parsed.notation, "d20+d4", "with the notation that produced them")

	var logged: Dictionary = _session.events[_session.events.size() - 1]
	check_eq(String(logged.get("kind", "")), Session.EVENT_ROLL, "the roll is appended to the campaign log")
	check_eq(String(logged.get("player_id", "")), String(received[0][0]), "attributed to the player who rolled")
	check_eq(
		AlternityNum.as_int(logged.get("payload", {}).get("total", 0)), 20,
		"with the settled total, not a re-rolled one"
	)


# --- Chat ------------------------------------------------------------------

func _test_chat_and_private_lines() -> void:
	var heard := []
	_host.chat_received.connect(func(player_id: String, text: String, to: String): heard.append([player_id, text, to]))

	_client.send_chat("we take the left corridor")
	var arrived := await _pump_until(func(): return heard.size() > 0)
	check_true(arrived, "table chat reaches the GM")
	if not arrived:
		return
	check_eq(String(heard[0][1]), "we take the left corridor", "the text arrives intact")
	check_eq(String(heard[0][2]), "", "a table-wide line names no recipient")

	var gm_id := String(_session.gm_seat().get("player_id", ""))
	_client.send_chat("can I check for traps quietly?", gm_id)
	arrived = await _pump_until(func(): return heard.size() > 1)
	check_true(arrived, "a private line reaches the GM")
	if not arrived:
		return
	check_eq(String(heard[1][2]), gm_id, "and is marked as addressed to the GM")

	var logged: Dictionary = _session.events[_session.events.size() - 1]
	check_eq(
		String(logged.get("payload", {}).get("to", "")), gm_id,
		"the log records who a private line was for, so it is not mistaken for table chat later"
	)


# --- GM to player ----------------------------------------------------------

## An AP award is an ordinary event as far as the wire is concerned, which is
## what keeps the GM from needing a message kind per kind of thing that happens.
func _test_gm_events_reach_the_player() -> void:
	var events := []
	_client.event_received.connect(func(event: Dictionary): events.append(event))
	var player_id := String(_host.connected_players()[0])

	var awarded: Dictionary = _session.award_ap(player_id, 3, Session.AP_REASON_HEROISM)
	_host._deliver(awarded)
	var arrived := await _pump_until(func(): return events.size() > 0)
	check_true(arrived, "the award reaches the player device")
	if not arrived:
		return

	check_eq(String(events[0].get("kind", "")), Session.EVENT_AP_AWARD, "as an ap_award event")
	check_eq(AlternityNum.as_int(events[0].get("payload", {}).get("amount", 0)), 3, "carrying the amount")
	check_eq(
		String(events[0].get("payload", {}).get("reason", "")), Session.AP_REASON_HEROISM,
		"and the reason, which is what makes it readable a month later"
	)
	check_eq(
		AlternityNum.as_int(events[0].get("seq", 0)), AlternityNum.as_int(awarded.get("seq", 0)),
		"with the host's sequence number, not one the client invented"
	)
	check_eq(_client.last_seen_seq(), AlternityNum.as_int(awarded.get("seq", 0)),
		"the client tracks how far its log has got")


# --- Reconnect -------------------------------------------------------------

## The checkpoint: a mid-session reconnect that loses nothing.
##
## The player drops, the table carries on, and rejoining replays exactly the gap.
## This is what the stable player_id and the append-only sequence are both for.
func _test_reconnect_replays_the_gap() -> void:
	var player_id := String(_host.connected_players()[0])
	var seq_before: int = _client.last_seen_seq()

	var dropped := []
	_host.player_disconnected.connect(func(id: String): dropped.append(id))

	_client.leave()
	var noticed := await _pump_until(func(): return dropped.size() > 0)
	check_true(noticed, "the host notices the player drop")
	check_eq(String(dropped[0]) if noticed else "", player_id, "and names them by their stable id")
	check_eq(_host.connected_players().size(), 0, "the host no longer lists them as connected")
	# The seat stays. A campaign is not a lobby; dropping out is not leaving.
	check_true(_session.has_seat(player_id), "their seat survives the disconnection")

	# The table carries on without them.
	_host.broadcast_event(Session.EVENT_NOTE, "", {"text": "the door gives way"})
	_host.broadcast_event(Session.EVENT_NOTE, "", {"text": "something moves inside"})
	var missed_count: int = _session.last_seq() - seq_before

	# Next week, a new process, a brand new peer id -- only the player_id
	# survived, and that is what the host matches on.
	_client = _track(Transport.new())
	var welcomed := []
	_client.player_connected.connect(func(id: String, is_reconnect: bool): welcomed.append([id, is_reconnect]))
	var replayed := []
	_client.events_replayed.connect(func(events: Array): replayed.append(events))

	_client.join("127.0.0.1", PORT, player_id, "Alice", seq_before)
	var back := await _pump_until(func(): return welcomed.size() > 0 and replayed.size() > 0)
	check_true(back, "the player rejoins and is replayed to")
	if not back:
		return

	check_true(bool(welcomed[0][1]), "the host recognises them as a reconnect, not a new player")
	check_eq(String(welcomed[0][0]), player_id, "and hands back the same stable id")
	check_eq(_session.seats.size(), 2, "reconnecting does not add a second seat")

	var events: Array = replayed[0]
	check_eq(events.size(), missed_count, "exactly what was missed is replayed")
	check_eq(
		AlternityNum.as_int(events[0].get("seq", 0)), seq_before + 1,
		"replay starts at the event after the last one the client saw"
	)
	check_eq(
		String(events[events.size() - 1].get("payload", {}).get("text", "")), "something moves inside",
		"and ends at the newest"
	)
	check_eq(_client.last_seen_seq(), _session.last_seq(), "the client is caught up")

	# A client that never dropped asks from where it is and gets nothing, which
	# is the case that a naive "replay everything" would get wrong.
	var idle = _track(Transport.new())
	var idle_replays := []
	var idle_welcomes := []
	idle.events_replayed.connect(func(events_in: Array): idle_replays.append(events_in))
	idle.player_connected.connect(func(_id: String, _r: bool): idle_welcomes.append(true))
	idle.join("127.0.0.1", PORT, "", "Bob", _session.last_seq())
	var joined := await _pump_until(func(): return idle_welcomes.size() > 0)
	check_true(joined, "a second player joins")
	# Give any replay that was going to arrive a chance to.
	await _pump_until(func(): return false, 20)
	check_eq(idle_replays.size(), 0, "a client already up to date is replayed nothing")
	_untrack(idle)
	await _pump_until(func(): return _host.connected_players().size() == 1)


# --- Refusal ---------------------------------------------------------------

func _test_unknown_player_can_be_refused() -> void:
	_host.allow_new_players = false
	var seats_before: int = _session.seats.size()

	var stranger = _track(Transport.new())
	var refusals := []
	var welcomes := []
	stranger.transport_error.connect(func(message: String): refusals.append(message))
	stranger.player_connected.connect(func(_id: String, _r: bool): welcomes.append(true))
	stranger.join("127.0.0.1", PORT, "", "Uninvited")

	var refused := await _pump_until(func(): return refusals.size() > 0)
	check_true(refused, "an unknown player is refused when the GM has closed the table")
	check_eq(welcomes.size(), 0, "and is never welcomed")
	check_eq(_session.seats.size(), seats_before, "no seat is created for them")
	check_false(stranger.is_connected_to_table(), "the stranger is not at the table")
	_untrack(stranger)

	# Closing the table is about strangers, not about locking out the people
	# already playing: a seat that exists still gets in.
	var known := String(_session.seats[1].get("player_id", ""))
	var returning = _track(Transport.new())
	var back := []
	returning.player_connected.connect(func(id: String, is_reconnect: bool): back.append([id, is_reconnect]))
	returning.join("127.0.0.1", PORT, known, "Alice", _session.last_seq())
	var admitted := await _pump_until(func(): return back.size() > 0)
	check_true(admitted, "a player who already has a seat gets in with the table closed")
	if admitted:
		check_true(bool(back[0][1]), "and is recognised as a reconnect")
		check_eq(String(back[0][0]), known, "keeping the same stable id")
	_untrack(returning)

	_host.allow_new_players = true


## A peer id is an implementation detail of one connection. Nothing above the
## transport may ever see one, or reconnect would break the moment ENet handed
## out a different number.
func _test_peer_ids_never_escape() -> void:
	for player_id in _host.connected_players():
		check_eq(String(player_id).length(), 32, "connected players are reported as 32-hex ids")
		check_false(String(player_id).is_valid_int(), "never as a peer number")
	for event in _session.events:
		var who := String(event.get("player_id", ""))
		check_false(who.is_valid_int() and not who.is_empty(), "no log event is attributed to a peer id")
