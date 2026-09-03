extends "res://tools/test_harness.gd"
##
## Finding the GM without typing an IP, over the loopback.
##
## Discovery is the convenience half of joining, so the cases that matter are
## the ones where it goes wrong: another app already on the port, a packet from
## something else on the network, a version mismatch, and a GM who has quit.
## Every one of those has to fail into "type the address instead" rather than
## into a wrong answer.
##

const Session := preload("res://scripts/core/session/campaign_session.gd")
const Discovery := preload("res://scripts/core/session/lan_discovery.gd")

var _peers: Array = []


func _init() -> void:
	begin_async("lan discovery", 2000)
	_run.call_deferred()


func _run() -> void:
	await _test_a_player_finds_the_gm()
	await _test_a_busy_port_is_reported()
	await _test_foreign_packets_are_ignored()
	await _test_a_departed_host_ages_out()

	for peer in _peers:
		peer.stop()
	_peers.clear()
	finish()


func _track(peer):
	_peers.append(peer)
	return peer


func _pump_until(condition: Callable, max_polls: int = 240) -> bool:
	for _i in max_polls:
		if condition.call():
			return true
		for peer in _peers:
			peer.poll()
		await process_frame
	return condition.call()


# --- The happy path --------------------------------------------------------

func _test_a_player_finds_the_gm() -> void:
	var session = Session.new("The Verge")
	var host = _track(Discovery.new())
	var started: int = host.advertise(session, 47811)
	# An early return here must still release the port, or every later test in
	# this suite fails for a reason that has nothing to do with what it checks.
	if not check_eq(started, OK, "the GM can advertise on this machine"):
		host.stop()
		_peers.clear()
		return

	var player = _track(Discovery.new())
	var found := []
	player.host_found.connect(func(address: String, port: int, name: String, id: String):
		found.append({"address": address, "port": port, "name": name, "id": id}))
	if not check_eq(player.search(), OK, "a player can search"):
		host.stop()
		_peers.clear()
		return

	# Aimed at the loopback rather than broadcast: see LanDiscovery.ask().
	player.ask("127.0.0.1")
	var answered := await _pump_until(func(): return found.size() > 0)
	check_true(answered, "the GM answers the question")
	if not answered:
		host.stop()
		player.stop()
		_peers.clear()
		return

	check_eq(String(found[0]["name"]), "The Verge", "the answer names the campaign, so a player knows what they are joining")
	check_eq(String(found[0]["id"]), session.campaign_id, "and identifies it")
	# The answer has to carry the ENet port, not the discovery port: they are
	# different on purpose so a discovery packet can never reach the game socket.
	check_eq(AlternityNum.as_int(found[0]["port"]), 47811, "the answer carries the port to actually join on")
	check_ne(AlternityNum.as_int(found[0]["port"]), Discovery.DISCOVERY_PORT, "which is not the discovery port")
	check_false(String(found[0]["address"]).is_empty(), "and an address to join at")

	# Asking repeatedly must refresh one entry rather than grow the list once per
	# second while a join screen sits open.
	for _i in 3:
		player.ask("127.0.0.1")
		await _pump_until(func(): return false, 10)
	check_eq(player.hosts().size(), 1, "repeated questions keep one entry per host")
	check_eq(found.size(), 1, "and only announce a host the first time it is heard")

	host.stop()
	player.stop()
	_peers.clear()


# --- Failing usefully ------------------------------------------------------

## Discovery losing its port must not take hosting down with it.
##
## A second copy of the app, or anything else on the port, is the ordinary case.
## The GM should be told players will have to type an address, not left with a
## session that silently refuses to be found.
func _test_a_busy_port_is_reported() -> void:
	var squatter := PacketPeerUDP.new()
	if not check_eq(squatter.bind(Discovery.DISCOVERY_PORT), OK, "the discovery port can be occupied for this test"):
		return

	var host = Discovery.new()
	var complaints := []
	host.discovery_error.connect(func(message: String): complaints.append(message))
	var result: int = host.advertise(Session.new("Blocked"), 47811)

	check_ne(result, OK, "advertising on a busy port fails rather than pretending")
	check_eq(complaints.size(), 1, "and says so")
	check_true(
		String(complaints[0]).to_lower().contains("typing"),
		"pointing at the fallback, since hosting itself is unaffected"
	)
	check_false(host.is_running(), "nothing is left half-open")

	host.stop()
	squatter.close()


func _test_foreign_packets_are_ignored() -> void:
	var session = Session.new("Quiet")
	var host = _track(Discovery.new())
	if not check_eq(host.advertise(session, 47811), OK, "the GM advertises again"):
		host.stop()
		_peers.clear()
		return

	var player = _track(Discovery.new())
	var found := []
	player.host_found.connect(func(a: String, p: int, n: String, i: String): found.append(n))
	if not check_eq(player.search(), OK, "a player searches again"):
		host.stop()
		_peers.clear()
		return

	# Something else on the network, broadcasting on the same port. It must not
	# be answered, and it must not be mistaken for a host.
	var noise := PacketPeerUDP.new()
	noise.bind(0)
	noise.set_broadcast_enabled(true)
	noise.set_dest_address("127.0.0.1", Discovery.DISCOVERY_PORT)
	noise.put_packet("this is not JSON at all".to_utf8_buffer())
	noise.put_packet(JSON.stringify({"q": "some-other-app"}).to_utf8_buffer())
	# Our shape, a version we do not speak. Answering it would be worse than
	# ignoring it: the player would be offered a table it cannot talk to.
	noise.put_packet(JSON.stringify({
		"q": Discovery.MAGIC,
		"protocol": Discovery.PROTOCOL_VERSION + 99,
	}).to_utf8_buffer())
	await _pump_until(func(): return false, 30)

	check_eq(found.size(), 0, "none of that is reported as a host")
	check_eq(player.hosts().size(), 0, "and none of it is listed")

	# The real question still works afterwards, so the noise did not wedge it.
	player.ask("127.0.0.1")
	var answered := await _pump_until(func(): return found.size() > 0)
	check_true(answered, "a genuine question is still answered after the noise")
	check_eq(String(found[0]) if answered else "", "Quiet", "with the right campaign")

	noise.close()
	host.stop()
	player.stop()
	_peers.clear()


## A GM who quit must stop being offered, or a player taps a table that is not
## there and waits for a connection that will never open.
func _test_a_departed_host_ages_out() -> void:
	var player = Discovery.new()
	check_eq(player.search(), OK, "a player searches")

	# Record an answer as though it arrived, then age it past the timeout. Faking
	# the clock rather than waiting six seconds keeps the suite quick.
	player._record({
		"a": Discovery.MAGIC,
		"protocol": Discovery.PROTOCOL_VERSION,
		"campaign_name": "Gone Fishing",
		"campaign_id": "abc",
		"port": 47811,
	}, "192.168.1.50")
	check_eq(player.hosts().size(), 1, "a host that answered is listed")

	player._found["192.168.1.50"]["seen_at"] = (
		int(Time.get_unix_time_from_system()) - Discovery.HOST_TIMEOUT_SECONDS - 1
	)
	check_eq(player.hosts().size(), 0, "a host that has gone quiet drops off the list")

	player.stop()
	check_false(player.is_running(), "stopping closes the socket")
	check_eq(player.hosts().size(), 0, "and forgets what it found")
