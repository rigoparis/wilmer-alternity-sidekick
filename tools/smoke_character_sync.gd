extends "res://tools/test_harness.gd"
##
## The two seams MULTIPLAYER.md marks as expensive to get wrong later: the
## character sync policy, and the conflict rule.
##
## Both are really one rule stated twice -- one owner per document -- so both are
## tested here rather than in separate suites where the connection between them
## would be invisible:
##
##   * The player's device owns the character file and is its only writer. What
##     crosses the wire is a read-only snapshot.
##   * The GM's device owns the campaign and assigns every sequence number. AP
##     awards are events the player's device applies.
##
## What makes these worth a suite of their own is that breaking either one fails
## silently. Two writers do not error; they diverge, and the divergence shows up
## weeks later as a character sheet nobody can explain.
##

const Session := preload("res://scripts/core/session/campaign_session.gd")
const Transport := preload("res://scripts/core/session/enet_transport.gd")
const Snapshot := preload("res://scripts/core/session/character_snapshot.gd")
const Store := preload("res://scripts/core/character_store.gd")
const RulesScript := preload("res://scripts/alternity_rules.gd")

const PORT := 47897
const TEST_DIR := "user://__sync_test__/"

var _rules
var _peers: Array = []
var _host
var _client
var _session


func _init() -> void:
	begin_async("character sync", 2500)
	_run.call_deferred()


func _run() -> void:
	_wipe()
	_rules = RulesScript.new()
	_rules.load_core_data()

	_test_snapshot_is_read_only()
	_test_snapshot_is_validated()
	await _test_snapshot_reaches_the_gm()
	await _test_snapshot_survives_a_reopen()
	await _test_only_the_player_writes_the_character()

	for peer in _peers:
		peer.leave()
	_peers.clear()
	_wipe()
	finish()


func _wipe() -> void:
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		DirAccess.remove_absolute(TEST_DIR + file_name)


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


func _new_hero(hero_name: String) -> CharacterDoc:
	var doc := CharacterDoc.new(_rules)
	doc.set_hero_name(hero_name)
	return doc


# --- What a snapshot is ----------------------------------------------------

## A snapshot carries what a GM asks for out loud, and nothing they could edit.
##
## The exclusions are the point. Sending skills or equipment would invite a GM to
## change them, and the moment two devices can write one character the rule that
## keeps them consistent is gone.
func _test_snapshot_is_read_only() -> void:
	var doc := _new_hero("Vance Kellar")
	var snapshot := Snapshot.of_doc(doc)

	check_true(Snapshot.is_usable(snapshot), "a snapshot of a real hero is usable")
	check_eq(String(snapshot.get("hero_name", "")), "Vance Kellar", "it names the hero")
	for key in ["durability", "action_check", "last_resorts", "damage"]:
		check_true(snapshot.has(key), "it carries %s, which a GM asks for" % key)
	for key in ["skills", "equipment", "perks", "flaws", "achievements", "abilities"]:
		check_false(snapshot.has(key), "it does not carry %s, which a GM would want to edit" % key)

	# The numbers must be the character's own, not a second calculation of them.
	var summary := doc.summary()
	check_eq(
		AlternityNum.as_int(snapshot.get("durability", {}).get("stun", -1)),
		AlternityNum.as_int(summary.get("durability", {}).get("stun", -2)),
		"durability comes from the character's own summary"
	)
	check_eq(
		AlternityNum.as_int(snapshot.get("action_check", {}).get("ordinary", -1)),
		AlternityNum.as_int(summary.get("action_check", {}).get("ordinary", -2)),
		"and so does the action check"
	)

	check_true(Snapshot.age_seconds(snapshot) >= 0, "a snapshot knows when it was taken")
	check_true(Snapshot.age_seconds(snapshot) < 5, "and a fresh one is fresh")
	check_true(Snapshot.of_doc(null).is_empty(), "there is no snapshot of no character")


## A snapshot arrives from another device, so it is checked rather than trusted.
##
## The version check matters more than it looks: a snapshot from a future build
## shown as zeroes would read as a real character with no durability at all,
## which is worse than showing nothing.
func _test_snapshot_is_validated() -> void:
	check_false(Snapshot.is_usable({}), "an empty snapshot is not usable")
	check_false(Snapshot.is_usable({"hero_name": "Nobody"}), "a snapshot with no version is not usable")
	check_false(
		Snapshot.is_usable({"format_version": Snapshot.FORMAT_VERSION + 1, "durability": {}}),
		"a snapshot from a version this build does not know is refused"
	)
	check_false(
		Snapshot.is_usable({"format_version": Snapshot.FORMAT_VERSION, "durability": "not a dictionary"}),
		"a malformed snapshot is refused rather than half-read"
	)
	check_eq(Snapshot.age_seconds({}), -1, "an ageless snapshot reports -1 rather than guessing")


# --- Over the wire ---------------------------------------------------------

func _test_snapshot_reaches_the_gm() -> void:
	_session = Session.new("Sync")
	_session.set_gm(_session.add_seat("Rodri"))

	_host = _track(Transport.new())
	if not check_eq(_host.host(_session, PORT), OK, "the GM hosts"):
		return

	var received := []
	_host.character_received.connect(func(player_id: String, snapshot: Dictionary): received.append([player_id, snapshot]))

	_client = _track(Transport.new())
	var welcomed := []
	_client.player_connected.connect(func(_id: String, _r: bool): welcomed.append(true))
	_client.join("127.0.0.1", PORT, "", "Alice")
	if not check_true(await _pump_until(func(): return welcomed.size() > 0), "a player joins"):
		return

	var doc := _new_hero("Vance Kellar")
	_client.send_character(Snapshot.of_doc(doc))
	if not check_true(await _pump_until(func(): return received.size() > 0), "the snapshot reaches the GM"):
		return

	var player_id := String(received[0][0])
	check_eq(String(received[0][1].get("hero_name", "")), "Vance Kellar", "carrying the hero's name")
	check_true(Snapshot.is_usable(received[0][1]), "and arriving usable through JSON")

	# Stored on the seat, not appended to the log. A full snapshot per character
	# edit is how a year of play stops fitting on a phone.
	var seat: Dictionary = _session.seat_for(player_id)
	check_true(seat.has("character_snapshot"), "the seat holds the snapshot")
	check_eq(
		String(seat.get("character_snapshot", {}).get("hero_name", "")), "Vance Kellar",
		"with the right hero"
	)
	var snapshot_events := 0
	for event in _session.events:
		if typeof(event.get("payload")) == TYPE_DICTIONARY and event["payload"].has("durability"):
			snapshot_events += 1
	check_eq(snapshot_events, 0, "and nothing was written to the append-only log")

	# On change means on change: a second snapshot replaces the first rather than
	# accumulating.
	doc.set_hero_name("Vance Kellar the Elder")
	_client.send_character(Snapshot.of_doc(doc))
	if not check_true(await _pump_until(func(): return received.size() > 1), "a later snapshot arrives"):
		return
	check_eq(
		String(_session.seat_for(player_id).get("character_snapshot", {}).get("hero_name", "")),
		"Vance Kellar the Elder",
		"the seat holds the newest snapshot"
	)
	check_eq(_session.seats.size(), 2, "and no seat was added by any of it")


## A GM reopening next week should still see what the character looked like,
## rather than an empty row until that player happens to connect again.
func _test_snapshot_survives_a_reopen() -> void:
	var store := CampaignStore.new(TEST_DIR)
	store.save(_session)

	var reloaded := store.load_session(_session.campaign_id)
	if not check(reloaded != null, "the campaign reloads"):
		return

	var player_seat := {}
	for seat in reloaded.seats:
		if not bool(seat.get("is_gm", false)):
			player_seat = seat
	check_false(player_seat.is_empty(), "the player's seat is there")
	var stored = player_seat.get("character_snapshot", {})
	check_true(Snapshot.is_usable(stored), "and its snapshot survived the round trip")
	check_eq(
		String(stored.get("hero_name", "")), "Vance Kellar the Elder",
		"with the numbers the player last sent"
	)


# --- The conflict rule -----------------------------------------------------

## One owner per document, tested from both ends.
##
## The GM awards AP into the campaign; the player's device is what writes it into
## a character file. Neither ever touches the other's document, which is what
## makes "they disagree" impossible rather than merely unlikely.
func _test_only_the_player_writes_the_character() -> void:
	var characters := Store.new(_rules, TEST_DIR)
	var doc := _new_hero("Vance Kellar")
	characters.save(doc)
	var before: int = AlternityNum.as_int(doc.raw().get("achievement_points", 0))

	var player_id := ""
	for seat in _session.seats:
		if not bool(seat.get("is_gm", false)):
			player_id = String(seat.get("player_id", ""))

	var awarded: Dictionary = _session.award_ap(player_id, 4, Session.AP_REASON_COMPLETION)
	_host._deliver(awarded)

	var events := []
	_client.event_received.connect(func(event: Dictionary): events.append(event))
	if not check_true(await _pump_until(func(): return events.size() > 0), "the award reaches the player"):
		return

	# The GM's side changed the campaign and nothing else. A GM device that wrote
	# to a character file it can see would be the bug this rule prevents.
	check_eq(_session.get_seat_ap(player_id), 4, "the GM's ledger records the award")
	var untouched = characters.load_doc("Vance_Kellar.json")
	check_eq(
		AlternityNum.as_int(untouched.raw().get("achievement_points", 0)), before,
		"and the character file is untouched until the player applies it"
	)

	# The player's device applies it, exactly as PlayerTableScreen does.
	var granted := AlternityNum.as_int(events[0].get("payload", {}).get("amount", 0))
	check_eq(granted, 4, "the event carries the amount to apply")
	untouched.apply(CharacterDoc.ALL, func(character):
		character["achievement_points"] = AlternityNum.as_int(character.get("achievement_points", 0)) + granted)
	characters.save(untouched)

	var applied = characters.load_doc("Vance_Kellar.json")
	check_eq(
		AlternityNum.as_int(applied.raw().get("achievement_points", 0)), before + 4,
		"the player's device is what wrote the points into the character"
	)
	# The ledger is the GM's record of what was given, not a second copy of the
	# character. The two counting the same points is expected and correct.
	check_eq(_session.get_seat_ap(player_id), 4, "the GM's ledger still says what it gave")
