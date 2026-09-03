class_name EnetTransport
extends NetTransport
##
## NetTransport over ENet on a local network. The GM device hosts; players join.
##
## Built on ENetMultiplayerPeer's packet interface rather than on MultiplayerAPI
## and @rpc, for three reasons:
##
##   * There is no scene to replicate. The whole protocol is seven message kinds
##     over an already-serialisable document; RPC's authority model, spawners and
##     synchronizers would all be scaffolding around a Dictionary.
##   * MultiplayerAPI is scoped to a SceneTree branch, so putting a host and a
##     client in one process means two scoped APIs and two node subtrees. With
##     raw packets it is two objects, which is what makes the two-peer test in
##     smoke_enet_transport possible at all.
##   * This class stays RefCounted and headless, like the rest of core/.
##
## Polling is explicit. Pass a SceneTree to _init() and the transport polls
## itself each frame; pass nothing and the caller drives poll(), which is what
## the tests do so that they are deterministic rather than frame-timed.
##
## The two rules NetTransport exists to enforce are enforced here:
##
##   1. A peer id never leaves this class. Peers are mapped to player_ids by the
##      handshake and only the stable id is emitted upward.
##   2. Rolls arrive as settled facts and are logged, never re-rolled.
##

## Bumped when the message shapes change. A peer speaking a different version is
## refused with a reason rather than left to misparse packets.
const PROTOCOL_VERSION := 1

## The port the GM hosts on unless told otherwise. Chosen in the dynamic range,
## clear of anything registered.
const DEFAULT_PORT := 47811

const MAX_CLIENTS := 16

# Message kinds. The client speaks the first three; the host speaks the rest.
const MSG_HELLO := "hello"
const MSG_ROLL := "roll"
const MSG_CHAT := "chat"

## A player device telling the GM what their hero's numbers are now.
##
## Snapshot on change, not live sync. MULTIPLAYER.md leaves the choice open and
## this is the cheaper half: a snapshot is one message when something actually
## changes, where live sync would make every CharacterDoc signal a network
## event -- and the GM only ever reads these numbers, so there is nothing a live
## connection would buy.
const MSG_CHARACTER := "character"

## A player asking to attempt a skill, and the GM's answer.
##
## Two messages rather than one because they travel in opposite directions and
## mean different things: a request is "may I, and how hard is it", a ruling is
## "here is the step". A GM calling for a check unprompted sends a ruling with no
## request in front of it, which is exactly what a ruling already is.
const MSG_CHECK_REQUEST := "check_request"
const MSG_CHECK_RULING := "check_ruling"
const MSG_WELCOME := "welcome"
const MSG_DENIED := "denied"
const MSG_EVENT := "event"
const MSG_REPLAY := "replay"

## Address a private line to the GM without knowing which seat that is.
##
## A player device is never told the seat list -- it has no business holding one
## -- so it cannot name the GM's player_id. The host resolves this on arrival, so
## what lands in the log is the real seat id and a GM handover later does not
## leave a trail of messages addressed to a sentinel.
const TO_GM := "gm"

## Whether an unrecognised player_id is seated automatically.
##
## The GM's call, per MULTIPLAYER.md: a stranger on the Wi-Fi joining a campaign
## in progress is not the normal case. Off means only players who already have a
## seat can connect.
var allow_new_players: bool = true

var _peer: ENetMultiplayerPeer
var _session: CampaignSession
var _role: Role = Role.PLAYER
var _tree: SceneTree

## Host side: peer id -> player_id. The only place the two are associated.
var _peer_to_player: Dictionary = {}
## Host side: player_id -> peer id, for addressing a private line.
var _player_to_peer: Dictionary = {}

## Client side: who this device is, and how far its log has got.
var _local_player_id: String = ""
var _local_player_name: String = ""

## Client side: what the welcome said the table was. A player joining by typed
## address has no idea which campaign it is until this arrives.
var _campaign_id: String = ""
var _campaign_name: String = ""
var _since_seq: int = 0
var _handshaken: bool = false


## `tree` is optional. Given one, the transport polls itself every frame; given
## nothing, the caller must call poll().
func _init(tree: SceneTree = null) -> void:
	_tree = tree


# --- Hosting ---------------------------------------------------------------

## Start hosting `session` on `port`.
##
## The create_server() result is checked rather than assumed: a port already in
## use returns ERR_CANT_CREATE and otherwise looks exactly like a silent hang,
## which is the failure a GM would report as "it just does nothing".
func host(session: CampaignSession, port: int = DEFAULT_PORT) -> Error:
	leave()
	if session == null:
		transport_error.emit("Cannot host without a campaign")
		return ERR_INVALID_PARAMETER

	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(port, MAX_CLIENTS)
	if result != OK:
		transport_error.emit("Could not host on port %d (error %d). Another copy may already be running." % [port, result])
		return result

	_peer = peer
	_session = session
	_role = Role.GM
	_handshaken = true
	_bind_peer()
	return OK


# --- Joining ---------------------------------------------------------------

## Join a hosted session, identifying as `player_id` where possible.
##
## `player_id` is the id this device was given previously; the host matches it to
## an existing seat and answers is_reconnect. Pass "" only for a genuinely new
## player, who will be seated if the GM allows it.
##
## `since_seq` is the last sequence number this device already holds, so the host
## can replay only what was missed.
func join(
	address: String,
	port: int = DEFAULT_PORT,
	player_id: String = "",
	player_name: String = "",
	since_seq: int = 0
) -> Error:
	leave()

	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(address, port)
	if result != OK:
		transport_error.emit("Could not reach %s:%d (error %d)" % [address, port, result])
		return result

	_peer = peer
	_role = Role.PLAYER
	_local_player_id = player_id
	_local_player_name = player_name
	_since_seq = since_seq
	_handshaken = false
	_bind_peer()
	return OK


func _bind_peer() -> void:
	_peer.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)
	if _tree != null and not _tree.process_frame.is_connected(poll):
		_tree.process_frame.connect(poll)


func leave() -> void:
	if _tree != null and _tree.process_frame.is_connected(poll):
		_tree.process_frame.disconnect(poll)
	if _peer != null:
		_peer.close()
	_peer = null
	_session = null
	_peer_to_player.clear()
	_player_to_peer.clear()
	_handshaken = false
	_since_seq = 0


func is_connected_to_table() -> bool:
	if _peer == null:
		return false
	if _role == Role.GM:
		return true
	# A client is not at the table until the handshake has answered: the socket
	# being up says nothing about whether the GM accepted the seat.
	return _handshaken and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func local_role() -> Role:
	return _role


func local_player_id() -> String:
	return _local_player_id


## The campaign at the other end. On the host this is the session it is serving;
## on a client it is what the welcome named, and empty until then.
func campaign_id() -> String:
	return _session.campaign_id if _session != null else _campaign_id


func campaign_name() -> String:
	return _session.display_name if _session != null else _campaign_name


## Player ids currently connected. Host side; the GM's own seat is not among
## them because the GM is not a peer of itself.
func connected_players() -> Array:
	return _player_to_peer.keys()


# --- Pumping ---------------------------------------------------------------

## Advance the connection: deliver queued packets and raise signals.
##
## Safe to call when not connected, so a caller can drive it unconditionally
## from a _process without checking state first.
func poll() -> void:
	if _peer == null:
		return

	# Checked before pumping, not after. A client whose host has gone holds a
	# peer whose ENet host is already destroyed, and calling poll() on that logs
	# an engine error every frame for as long as the screen stays open.
	if _role == Role.PLAYER and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		# Local state is kept: the whole point of a stable player_id is that
		# rejoining resumes rather than restarts.
		_handshaken = false
		return

	_peer.poll()

	while _peer.get_available_packet_count() > 0:
		# Peer first, then the packet: get_packet_peer() reports the sender of
		# the packet still queued, and reading the packet advances past it.
		var from_peer := _peer.get_packet_peer()
		var raw := _peer.get_packet()
		var message = _decode(raw)
		if typeof(message) != TYPE_DICTIONARY:
			# A malformed packet is data from somewhere else on the network, not
			# a fault of ours. Drop it rather than tearing the session down.
			continue
		if _role == Role.GM:
			_handle_as_host(from_peer, message)
		else:
			_handle_as_client(message)


# --- Sending ---------------------------------------------------------------

## Send a settled roll to the table.
##
## On the GM's own device this logs and broadcasts directly; on a player device
## it is sent to the host, which assigns the sequence number. Either way the
## faces are already decided -- nothing here re-rolls anything.
func send_roll(roll: Dictionary) -> void:
	if _role == Role.GM:
		_log_and_broadcast(CampaignSession.EVENT_ROLL, _gm_player_id(), roll)
		return
	_send_to_host({"kind": MSG_ROLL, "roll": roll})


## Ask the GM to set the difficulty of a check.
##
## The reply comes back as `check_ruled`. With no table open there is nobody to
## ask, and the caller is expected to set the step itself rather than wait -- see
## the roll screen, which stays usable on one device.
func request_check(check: Dictionary) -> void:
	if _role == Role.GM:
		return
	_send_to_host({"kind": MSG_CHECK_REQUEST, "check": check})


## Answer a request, or call for a check unprompted.
##
## Host side. `to_player_id` empty means the whole table, which is only
## meaningful for a check the GM is calling -- a ruling answers one request and
## carries the asker's id inside it.
func send_ruling(check: Dictionary, to_player_id: String = "") -> void:
	if _role != Role.GM:
		push_error("EnetTransport.send_ruling is the host's job")
		return
	var message := {"kind": MSG_CHECK_RULING, "check": check}
	if to_player_id.is_empty():
		_send_to_peer(MultiplayerPeer.TARGET_PEER_BROADCAST, message)
		return
	var target := AlternityNum.as_int(_player_to_peer.get(to_player_id, 0))
	if target > 0:
		_send_to_peer(target, message)


## Push this device's character numbers to the GM.
##
## `snapshot` is a summary, not a character: enough for the GM to read out a
## durability track, and nothing they could edit. The player's device stays the
## only writer of the character file, which is the conflict rule this exists
## under.
func send_character(snapshot: Dictionary) -> void:
	if _role == Role.GM:
		return
	_send_to_host({"kind": MSG_CHARACTER, "snapshot": snapshot})


## Send a chat message. Empty `to_player_id` means the whole table.
func send_chat(text: String, to_player_id: String = "") -> void:
	if _role == Role.GM:
		_log_and_broadcast(CampaignSession.EVENT_CHAT, _gm_player_id(), {"text": text, "to": to_player_id})
		return
	_send_to_host({"kind": MSG_CHAT, "text": text, "to": to_player_id})


## Host side: record an event and push it to whoever should see it.
##
## The one place a log event is created during play, so the host is the sole
## assigner of sequence numbers. Two devices numbering their own events would
## produce two different histories that could never be reconciled.
func broadcast_event(kind: String, player_id: String, payload: Dictionary) -> Dictionary:
	if _role != Role.GM:
		push_error("EnetTransport.broadcast_event is the host's job")
		return {}
	return _log_and_broadcast(kind, player_id, payload)


func _log_and_broadcast(kind: String, player_id: String, payload: Dictionary) -> Dictionary:
	if _session == null:
		return {}
	var event := _session.append_event(kind, player_id, payload)
	_deliver(event)
	return event


## Send one event to the peers entitled to see it.
##
## A private line goes only to the seat it names. The GM already holds it -- the
## host is where the log lives -- so nothing is sent back to the sender either.
func _deliver(event: Dictionary) -> void:
	if _peer == null:
		return
	var payload = event.get("payload", {})
	var to := ""
	if typeof(payload) == TYPE_DICTIONARY:
		to = String(payload.get("to", ""))

	var message := {"kind": MSG_EVENT, "event": event}
	if to.is_empty():
		_send_to_peer(MultiplayerPeer.TARGET_PEER_BROADCAST, message)
		return

	var target := AlternityNum.as_int(_player_to_peer.get(to, 0))
	if target > 0:
		_send_to_peer(target, message)
	# The author sees their own private line echoed back, so their feed matches
	# the GM's. Skipped when the author is the GM, who is not a peer.
	var author := String(event.get("player_id", ""))
	var author_peer := AlternityNum.as_int(_player_to_peer.get(author, 0))
	if author_peer > 0 and author_peer != target:
		_send_to_peer(author_peer, message)


# --- Host handlers ---------------------------------------------------------

func _handle_as_host(from_peer: int, message: Dictionary) -> void:
	var kind := String(message.get("kind", ""))
	match kind:
		MSG_HELLO:
			_handle_hello(from_peer, message)
		MSG_ROLL:
			var player_id := String(_peer_to_player.get(from_peer, ""))
			# A packet from a peer that never handshook has no seat behind it and
			# is dropped: without this an unannounced peer could write to the log.
			if player_id.is_empty():
				return
			var roll: Dictionary = message.get("roll", {}) if typeof(message.get("roll")) == TYPE_DICTIONARY else {}
			var event := _log_and_broadcast(CampaignSession.EVENT_ROLL, player_id, roll)
			roll_received.emit(player_id, roll)
			event_received.emit(event)
		MSG_CHECK_REQUEST:
			var player_id := String(_peer_to_player.get(from_peer, ""))
			if player_id.is_empty():
				return
			var check: Dictionary = message.get("check", {}) if typeof(message.get("check")) == TYPE_DICTIONARY else {}
			# The asker is whoever the socket says it is, not whoever the message
			# claims: a device must not be able to request a check as somebody
			# else and have the GM's ruling go to them.
			check["player_id"] = player_id
			check_requested.emit(player_id, check)
		MSG_CHARACTER:
			var player_id := String(_peer_to_player.get(from_peer, ""))
			if player_id.is_empty():
				return
			var snapshot: Dictionary = message.get("snapshot", {}) if typeof(message.get("snapshot")) == TYPE_DICTIONARY else {}
			# Stored on the seat rather than logged. It is current state, and
			# putting a full snapshot in an append-only log on every character
			# edit is how a year of play stops fitting on a phone.
			var seat := _session.seat_for(player_id)
			if not seat.is_empty():
				seat["character_snapshot"] = snapshot
			character_received.emit(player_id, snapshot)
		MSG_CHAT:
			var player_id := String(_peer_to_player.get(from_peer, ""))
			if player_id.is_empty():
				return
			var to := _resolve_recipient(String(message.get("to", "")))
			var text := String(message.get("text", ""))
			var event := _log_and_broadcast(CampaignSession.EVENT_CHAT, player_id, {"text": text, "to": to})
			chat_received.emit(player_id, text, to)
			event_received.emit(event)


## The handshake, and the whole reason player_id exists.
##
## The peer id in hand is fresh and meaningless; the id inside the message is the
## one that survived since last week. Matching them is what turns a new
## connection into a returning player.
func _handle_hello(from_peer: int, message: Dictionary) -> void:
	if AlternityNum.as_int(message.get("protocol", 0)) != PROTOCOL_VERSION:
		_send_to_peer(from_peer, {
			"kind": MSG_DENIED,
			"reason": "This app is a different version from the GM's.",
		})
		return

	var claimed := String(message.get("player_id", ""))
	var player_name := String(message.get("player_name", "Player"))
	var is_reconnect := not claimed.is_empty() and _session.has_seat(claimed)

	var player_id := claimed
	if not is_reconnect:
		if not allow_new_players:
			_send_to_peer(from_peer, {
				"kind": MSG_DENIED,
				"reason": "The GM is not seating new players.",
			})
			return
		player_id = _session.add_seat(player_name)

	# One connection per seat. A second device claiming a seat that is already
	# connected would otherwise leave the map pointing at whichever arrived last
	# and silently strand the first.
	var existing := AlternityNum.as_int(_player_to_peer.get(player_id, 0))
	if existing > 0 and existing != from_peer:
		_peer_to_player.erase(existing)
		_peer.disconnect_peer(existing)

	_peer_to_player[from_peer] = player_id
	_player_to_peer[player_id] = from_peer
	_session.mark_seen(player_id)

	var seat := _session.seat_for(player_id)
	_send_to_peer(from_peer, {
		"kind": MSG_WELCOME,
		"player_id": player_id,
		"player_name": String(seat.get("player_name", player_name)),
		"is_reconnect": is_reconnect,
		"campaign_id": _session.campaign_id,
		"campaign_name": _session.display_name,
		"last_seq": _session.last_seq(),
	})

	# Replay what they missed. A first-time joiner asks from 0 and gets the tail
	# the host still holds, which is history rather than state -- their seat
	# already carries the AP and the character binding.
	var since := AlternityNum.as_int(message.get("since_seq", 0))
	var missed := _session.events_since(since)
	if not missed.is_empty():
		_send_to_peer(from_peer, {"kind": MSG_REPLAY, "events": missed})

	if not is_reconnect:
		# A new seat is worth a log line; a returning one is not, or a campaign
		# would accumulate a join event per week per player.
		_log_and_broadcast(CampaignSession.EVENT_JOIN, player_id, {"player_name": player_name})

	player_connected.emit(player_id, is_reconnect)


## Turn what a client addressed a line to into a seat id.
##
## Only the GM sentinel needs translating; anything else is already a player_id
## or is the empty string that means the whole table.
func _resolve_recipient(to: String) -> String:
	if to != TO_GM:
		return to
	return _gm_player_id()


func _on_peer_connected(peer_id: int) -> void:
	# Nothing to do until they say who they are. The socket is up; the seat is
	# not decided until the hello arrives.
	if _role == Role.PLAYER and peer_id == MultiplayerPeer.TARGET_PEER_SERVER:
		_send_to_host({
			"kind": MSG_HELLO,
			"protocol": PROTOCOL_VERSION,
			"player_id": _local_player_id,
			"player_name": _local_player_name,
			"since_seq": _since_seq,
		})


func _on_peer_disconnected(peer_id: int) -> void:
	if _role == Role.PLAYER:
		if peer_id == MultiplayerPeer.TARGET_PEER_SERVER:
			_handshaken = false
			transport_error.emit("Lost the connection to the GM.")
		return

	var player_id := String(_peer_to_player.get(peer_id, ""))
	_peer_to_player.erase(peer_id)
	if player_id.is_empty():
		return
	# Only if this peer is still the one holding the seat; a reconnect that
	# displaced an old peer must not have the old peer's cleanup unseat it.
	if AlternityNum.as_int(_player_to_peer.get(player_id, 0)) == peer_id:
		_player_to_peer.erase(player_id)
	player_disconnected.emit(player_id)


# --- Client handlers -------------------------------------------------------

func _handle_as_client(message: Dictionary) -> void:
	match String(message.get("kind", "")):
		MSG_WELCOME:
			_local_player_id = String(message.get("player_id", _local_player_id))
			_local_player_name = String(message.get("player_name", _local_player_name))
			_campaign_id = String(message.get("campaign_id", ""))
			_campaign_name = String(message.get("campaign_name", ""))
			_handshaken = true
			player_connected.emit(_local_player_id, bool(message.get("is_reconnect", false)))
		MSG_DENIED:
			_handshaken = false
			transport_error.emit(String(message.get("reason", "The GM refused the connection.")))
		MSG_REPLAY:
			var events = message.get("events", [])
			if typeof(events) != TYPE_ARRAY or events.is_empty():
				return
			_note_seq(events[events.size() - 1])
			events_replayed.emit(events)
		MSG_CHECK_RULING:
			var check = message.get("check", {})
			if typeof(check) != TYPE_DICTIONARY:
				return
			check_ruled.emit(check)
		MSG_EVENT:
			var event = message.get("event", {})
			if typeof(event) != TYPE_DICTIONARY:
				return
			_note_seq(event)
			_emit_specific(event)
			event_received.emit(event)


## Remember how far this device's log has got, so a later rejoin asks for the
## right window rather than the whole campaign.
func _note_seq(event: Dictionary) -> void:
	_since_seq = maxi(_since_seq, AlternityNum.as_int(event.get("seq", 0)))


func _emit_specific(event: Dictionary) -> void:
	var payload: Dictionary = event.get("payload", {}) if typeof(event.get("payload")) == TYPE_DICTIONARY else {}
	var who := String(event.get("player_id", ""))
	match String(event.get("kind", "")):
		CampaignSession.EVENT_ROLL:
			roll_received.emit(who, payload)
		CampaignSession.EVENT_CHAT:
			chat_received.emit(who, String(payload.get("text", "")), String(payload.get("to", "")))


## How far this device's log has got, to hand back to join() next time.
func last_seen_seq() -> int:
	return _since_seq


# --- Wire ------------------------------------------------------------------

func _gm_player_id() -> String:
	return "" if _session == null else String(_session.gm_seat().get("player_id", ""))


func _send_to_host(message: Dictionary) -> void:
	_send_to_peer(MultiplayerPeer.TARGET_PEER_SERVER, message)


func _send_to_peer(target: int, message: Dictionary) -> void:
	if _peer == null:
		return
	_peer.set_target_peer(target)
	_peer.put_packet(JSON.stringify(message).to_utf8_buffer())


## JSON rather than var_to_bytes: the payloads are the same Dictionaries the
## campaign file stores, and a packet that can be read in a capture is worth more
## than the bytes it saves. JSON.parse() rather than parse_string() so a stray
## packet from something else on the network is dropped quietly instead of
## pushing an engine error per packet.
func _decode(raw: PackedByteArray) -> Variant:
	var json := JSON.new()
	if json.parse(raw.get_string_from_utf8()) != OK:
		return null
	return json.get_data()
