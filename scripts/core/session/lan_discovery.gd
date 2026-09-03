class_name LanDiscovery
extends RefCounted
##
## Finding the GM on the local network, so nobody has to read an IP address off
## a laptop and type it into a phone.
##
## A UDP broadcast question and a unicast answer:
##
##     player  -->  255.255.255.255:47812   {"q": "alternity-table", ...}
##     GM      -->  back to the asker        {"a": ..., campaign, port, ...}
##
## Deliberately separate from EnetTransport. Discovery is a convenience that
## fails in ordinary, boring ways -- a guest network with client isolation, a
## firewall prompt nobody answered, a phone on mobile data -- and none of those
## should stop a GM reading out an IP and a player typing it in. Manual entry is
## the supported fallback, not a degraded mode.
##
## Both halves poll explicitly, like EnetTransport, so a test can drive them
## deterministically rather than waiting on frames.
##

## A host answered. `address` and `port` are what to hand to EnetTransport.join.
signal host_found(address: String, port: int, campaign_name: String, campaign_id: String)

## Discovery could not start. Not fatal -- fall back to typing an address.
signal discovery_error(message: String)

## The question port. Distinct from the ENet port so a discovery packet can
## never be mistaken for game traffic.
const DISCOVERY_PORT := 47812

## Marks our packets, so anything else broadcasting on this port is ignored
## rather than misparsed.
const MAGIC := "alternity-table"

## Where a question goes when no address is given.
const BROADCAST_ADDRESS := "255.255.255.255"

const PROTOCOL_VERSION := 1

## How long a host stays in the list after its last answer. A GM who closes the
## app should disappear from a player's list rather than sit there unjoinable.
const HOST_TIMEOUT_SECONDS := 6

var _socket: PacketPeerUDP

## Host side: what to answer with.
var _campaign_name: String = ""
var _campaign_id: String = ""
var _game_port: int = 0
var _answering: bool = false

## Client side: address -> {address, port, campaign_name, campaign_id, seen_at}.
var _found: Dictionary = {}


# --- Host side -------------------------------------------------------------

## Answer discovery questions on behalf of a hosted campaign.
##
## `game_port` is the ENet port the answer advertises, which is not this one.
func advertise(session: CampaignSession, game_port: int) -> Error:
	stop()
	if session == null:
		return ERR_INVALID_PARAMETER

	var socket := PacketPeerUDP.new()
	var result := socket.bind(DISCOVERY_PORT)
	if result != OK:
		# Losing discovery is survivable; hosting is not affected. Say so and let
		# the GM read out an address.
		discovery_error.emit(
			"Could not listen for players on the network (error %d). They can still join by typing this device's address." % result
		)
		return result

	_socket = socket
	_campaign_name = session.display_name
	_campaign_id = session.campaign_id
	_game_port = game_port
	_answering = true
	return OK


# --- Player side -----------------------------------------------------------

## Start looking for hosts. Call ask() to send a question, then poll().
func search() -> Error:
	stop()
	var socket := PacketPeerUDP.new()
	# Port 0 means "any free port": a player device must not fight the host for
	# the discovery port, and two players on one machine must not fight either.
	var result := socket.bind(0)
	if result != OK:
		discovery_error.emit(
			"Could not search the network (error %d). Ask the GM for their address instead." % result
		)
		return result
	socket.set_broadcast_enabled(true)
	_socket = socket
	_answering = false
	return OK


## Broadcast one question. Cheap; call it every second or so while a join screen
## is open, since a GM may start hosting after the player opened the screen.
##
## `address` exists so a question can be aimed at one machine. Broadcast is the
## real behaviour, but it cannot be exercised in a test: a packet sent to
## 255.255.255.255 does not come back to another socket on the same host under
## Windows, so the suite asks 127.0.0.1 and the broadcast itself is left to the
## two-device check that MULTIPLAYER.md already calls for.
func ask(address: String = BROADCAST_ADDRESS) -> void:
	if _socket == null or _answering:
		return
	_socket.set_dest_address(address, DISCOVERY_PORT)
	_socket.put_packet(JSON.stringify({
		"q": MAGIC,
		"protocol": PROTOCOL_VERSION,
	}).to_utf8_buffer())


## Hosts heard from recently, newest answer first. Entries older than
## HOST_TIMEOUT_SECONDS are dropped, so a GM who quit stops being offered.
func hosts() -> Array:
	var now := int(Time.get_unix_time_from_system())
	var live: Array = []
	for key in _found.keys():
		var entry: Dictionary = _found[key]
		if now - AlternityNum.as_int(entry.get("seen_at", 0)) > HOST_TIMEOUT_SECONDS:
			_found.erase(key)
			continue
		live.append(entry)
	live.sort_custom(func(a, b): return AlternityNum.as_int(a["seen_at"]) > AlternityNum.as_int(b["seen_at"]))
	return live


# --- Both sides ------------------------------------------------------------

## Deliver whatever has arrived. Safe to call when not searching or advertising.
func poll() -> void:
	if _socket == null:
		return
	while _socket.get_available_packet_count() > 0:
		# The packet first, then the sender. PacketPeerUDP fills in the address and
		# port as part of receiving, so reading them beforehand yields ":0" and the
		# answer goes nowhere. (ENet's peer accessor is the other way round, which
		# is exactly why this is worth stating.)
		var message = _decode(_socket.get_packet())
		var from_address := _socket.get_packet_ip()
		var from_port := _socket.get_packet_port()
		if typeof(message) != TYPE_DICTIONARY:
			continue
		if _answering:
			_answer(message, from_address, from_port)
		else:
			_record(message, from_address)


func _answer(message: Dictionary, address: String, port: int) -> void:
	# Only our own question, and only a version we speak. Broadcast traffic is
	# shared with everything else on the network.
	if String(message.get("q", "")) != MAGIC:
		return
	if AlternityNum.as_int(message.get("protocol", 0)) != PROTOCOL_VERSION:
		return
	# Unicast back to the asker rather than broadcasting the answer: every other
	# device on the network has no use for it.
	_socket.set_dest_address(address, port)
	_socket.put_packet(JSON.stringify({
		"a": MAGIC,
		"protocol": PROTOCOL_VERSION,
		"campaign_name": _campaign_name,
		"campaign_id": _campaign_id,
		"port": _game_port,
	}).to_utf8_buffer())


func _record(message: Dictionary, address: String) -> void:
	if String(message.get("a", "")) != MAGIC:
		return
	if AlternityNum.as_int(message.get("protocol", 0)) != PROTOCOL_VERSION:
		return
	var entry := {
		"address": address,
		"port": AlternityNum.as_int(message.get("port", 0)),
		"campaign_name": String(message.get("campaign_name", "A campaign")),
		"campaign_id": String(message.get("campaign_id", "")),
		"seen_at": int(Time.get_unix_time_from_system()),
	}
	# Keyed by address, so repeated questions refresh one entry rather than
	# growing the list once per second.
	var known: bool = _found.has(address)
	_found[address] = entry
	if not known:
		host_found.emit(address, entry["port"], entry["campaign_name"], entry["campaign_id"])


func stop() -> void:
	if _socket != null:
		_socket.close()
	_socket = null
	_answering = false
	_found.clear()


func is_running() -> bool:
	return _socket != null


func _decode(raw: PackedByteArray) -> Variant:
	var json := JSON.new()
	if json.parse(raw.get_string_from_utf8()) != OK:
		return null
	return json.get_data()
