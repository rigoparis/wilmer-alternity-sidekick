extends "res://tools/test_harness.gd"
##
## The campaign document that has to survive months of play.
##
## The reconnect path gets the most attention here: it is the reason player_id
## exists at all, and it is not exercised by anything else yet.
##

const Session := preload("res://scripts/core/session/campaign_session.gd")
const Rng := preload("res://scripts/core/dice/rng_source.gd")
const Notation := preload("res://scripts/core/dice/dice_notation.gd")


func _init() -> void:
	begin("campaign session")

	_test_identity()
	_test_seats()
	_test_gm()
	_test_event_log()
	_test_private_chat()
	_test_reconnect_flow()
	_test_ap_awards()
	_test_persistence()

	finish()


func _test_identity() -> void:
	# Ids must not collide across devices that have never communicated.
	var ids := {}
	for _i in 200:
		ids[Session.new_id()] = true
	check_eq(ids.size(), 200, "generated ids are unique")
	check_eq(Session.new_id().length(), 32, "ids are 32 hex characters (16 bytes)")

	var a := Session.new("Dark Matter")
	var b := Session.new("Dark Matter")
	check_ne(a.campaign_id, b.campaign_id, "two campaigns with the same name have different ids")
	check_eq(a.display_name, "Dark Matter", "campaign keeps its name")
	check_true(a.created_at > 0, "campaign records when it was created")


func _test_seats() -> void:
	var session := Session.new("Test Campaign")
	var alice := session.add_seat("Alice")
	var bob := session.add_seat("Bob", "Bob_Hero.json")

	check_eq(session.seats.size(), 2, "both seats recorded")
	check_ne(alice, bob, "each player gets a distinct id")
	check_true(session.has_seat(alice), "alice has a seat")
	check_false(session.has_seat("not-a-real-id"), "an unknown id has no seat")

	check_eq(String(session.seat_for(bob).get("character_file", "")), "Bob_Hero.json", "seat keeps its character binding")
	check_eq(String(session.seat_for(alice).get("character_file", "")), "", "a seat may start without a character")

	# A player can make their character later.
	check_true(session.bind_character(alice, "Alice_Hero.json"), "binding a character succeeds")
	check_eq(String(session.seat_for(alice).get("character_file", "")), "Alice_Hero.json", "binding takes effect")
	check_false(session.bind_character("not-a-real-id", "x.json"), "binding an unknown player fails")

	check_true(session.remove_seat(bob), "removing a seat succeeds")
	check_false(session.has_seat(bob), "removed seat is gone")
	check_false(session.remove_seat(bob), "removing twice fails")


func _test_gm() -> void:
	var session := Session.new("Test Campaign")
	var gm := session.add_seat("Game Master")
	var player := session.add_seat("Player One")

	check_true(session.gm_seat().is_empty(), "no GM until one is set")
	check_true(session.set_gm(gm), "setting a GM succeeds")
	check_eq(String(session.gm_seat().get("player_id", "")), gm, "GM seat is reported")

	# Handing over the role must not leave two GMs.
	session.set_gm(player)
	check_eq(String(session.gm_seat().get("player_id", "")), player, "GM role transfers")
	var gm_count := 0
	for seat in session.seats:
		if bool(seat.get("is_gm", false)):
			gm_count += 1
	check_eq(gm_count, 1, "exactly one seat is GM after a transfer")


func _test_event_log() -> void:
	var session := Session.new("Test Campaign")
	var player := session.add_seat("Roller")

	var source = Rng.new(42)
	var roll = source.roll(Notation.parse("d20"), "Action check")
	roll.player_id = player

	var event := session.append_roll(player, roll.to_dict())
	check_eq(event["kind"], Session.EVENT_ROLL, "roll is logged as a roll event")
	check_eq(event["seq"], 1, "first event is sequence 1")
	check_true(AlternityNum.as_int(event["at"]) > 0, "event is timestamped")
	check_eq(event["payload"]["notation"], "d20", "roll payload survives into the log")

	# Sequence numbers keep order even when timestamps tie.
	for i in range(5):
		session.append_chat(player, "message %d" % i)
	check_eq(session.events.size(), 6, "all events retained")
	var sequences: Array = []
	for e in session.events:
		sequences.append(e["seq"])
	check_eq(sequences, [1, 2, 3, 4, 5, 6], "sequence numbers are contiguous and ordered")

	# A returning player should not have to load a year of history.
	check_eq(session.recent_events(3).size(), 3, "recent_events returns the requested count")
	check_eq(session.recent_events(3)[2]["seq"], 6, "recent_events ends at the newest event")
	check_eq(session.recent_events(100).size(), 6, "asking for more than exists returns everything")
	check_eq(session.recent_events(0).size(), 0, "asking for none returns none")


func _test_private_chat() -> void:
	var session := Session.new("Test Campaign")
	var gm := session.add_seat("GM")
	var alice := session.add_seat("Alice")
	var bob := session.add_seat("Bob")
	session.set_gm(gm)

	session.append_chat(alice, "table-wide hello")
	session.append_chat(alice, "psst, GM only", gm)
	session.append_chat(gm, "replying privately", alice)
	session.append_chat(bob, "unrelated")

	# Alice sees her own messages plus what was addressed to her.
	var for_alice := session.events_for(alice)
	check_eq(for_alice.size(), 3, "alice sees her own two messages and the GM reply")

	# Bob must not see the private exchange.
	var for_bob := session.events_for(bob)
	check_eq(for_bob.size(), 1, "bob sees only his own message")
	check_eq(String(for_bob[0]["payload"]["text"]), "unrelated", "bob sees the right message")


## The reason player_id exists. A peer id would be different on every
## connection, so the seat has to be found by the stable id instead.
func _test_reconnect_flow() -> void:
	var session := Session.new("Long Campaign")
	var alice := session.add_seat("Alice", "Alice_Hero.json")
	session.append_chat(alice, "see you next week")

	# Weeks later, a new process, a brand new peer id -- only the stored
	# player_id survives.
	var restored := Session.from_dict(JSON.parse_string(JSON.stringify(session.to_dict())))

	check_true(restored.has_seat(alice), "the seat is found by the stored player id")
	check_true(restored.mark_seen(alice), "a known player is recognised as a reconnect")
	check_true(
		AlternityNum.as_int(restored.seat_for(alice).get("last_seen", 0)) > 0,
		"reconnecting records last_seen"
	)
	check_eq(
		String(restored.seat_for(alice).get("character_file", "")), "Alice_Hero.json",
		"the character binding survives the gap"
	)
	check_eq(restored.events_for(alice).size(), 1, "history is still attributed to the player")

	# An unknown id is a new player, not a reconnect -- the caller needs that
	# distinction to decide between seating them and resuming them.
	check_false(restored.mark_seen(Session.new_id()), "an unknown id is not a reconnect")


func _test_ap_awards() -> void:
	var session := Session.new("AP Test Campaign")
	var gm := session.add_seat("GM")
	var bob := session.add_seat("Bob", "Bob_Hero.json")
	var carol := session.add_seat("Carol", "Carol_Hero.json")
	session.set_gm(gm)

	# 1. Direct AP Award to individual seat
	var award_event := session.award_ap(bob, 3, Session.AP_REASON_COMPLETION)
	check_eq(award_event["kind"], Session.EVENT_AP_AWARD, "award event recorded")
	check_eq(session.get_seat_ap(bob), 3, "Bob has 3 AP after award")
	check_eq(session.get_pending_ap_awards(bob).size(), 1, "Bob has 1 pending award")

	# 2. Table-wide AP Award (e.g. roleplaying bonus for everyone)
	session.award_table_ap(1, Session.AP_REASON_ROLEPLAYING)
	check_eq(session.get_seat_ap(bob), 4, "Bob now has 4 AP (3 + 1)")
	check_eq(session.get_seat_ap(carol), 1, "Carol has 1 AP from table award")
	check_eq(session.get_seat_ap(gm), 0, "GM does not receive player AP awards")

	# 3. Disconnected Player persistence: awards survive disconnection & serialization
	var serialized := session.to_dict()
	var restored := Session.from_dict(JSON.parse_string(JSON.stringify(serialized)))
	check_eq(restored.get_seat_ap(bob), 4, "Bob AP survives persistence")
	check_eq(restored.get_pending_ap_awards(bob).size(), 2, "Pending awards survive persistence")

	# 4. Claiming pending awards
	var claimed := restored.claim_pending_ap_awards(bob)
	check_eq(claimed.size(), 2, "Claimed 2 awards for Bob")
	check_eq(restored.get_pending_ap_awards(bob).size(), 0, "Pending awards cleared after claim")

	# 5. GM Manual AP override
	session.set_seat_ap(carol, 15, "GM Level Set")
	check_eq(session.get_seat_ap(carol), 15, "Carol AP manually overridden to 15")


func _test_persistence() -> void:
	var session := Session.new("Persisted Campaign")
	var gm := session.add_seat("GM")
	var player := session.add_seat("Player", "Hero.json")
	session.set_gm(gm)
	session.set_campaign_optional_rule("psionic_talents", true)
	session.set_campaign_optional_rule("dazed", true)
	var source = Rng.new(7)
	session.append_roll(player, source.roll(Notation.parse("2d20"), "Attack").to_dict())
	session.append_chat(player, "hello")

	# Through JSON, since that is how it will be stored and sent.
	var restored := Session.from_dict(JSON.parse_string(JSON.stringify(session.to_dict())))

	check_eq(restored.campaign_id, session.campaign_id, "campaign id survives")
	check_eq(restored.display_name, session.display_name, "campaign name survives")
	check_eq(restored.created_at, session.created_at, "creation time survives")
	check_eq(restored.format_version, Session.FORMAT_VERSION, "format version is recorded")
	check_eq(restored.seats.size(), 2, "seats survive")
	check_eq(restored.events.size(), 2, "events survive")
	check_eq(String(restored.gm_seat().get("player_id", "")), gm, "GM assignment survives")
	check_eq(bool(restored.get_campaign_optional_rules().get("psionic_talents", false)), true, "campaign optional rule psionic_talents survives")
	check_eq(bool(restored.get_campaign_optional_rules().get("dazed", false)), true, "campaign optional rule dazed survives")
	check_eq(
		restored.events[0]["payload"]["dice"].size(), 2,
		"the recorded dice faces survive, so the GM sees what the player saw"
	)

	# A malformed file must not crash the load path.
	var empty := Session.from_dict({})
	check_eq(empty.seats.size(), 0, "an empty document yields no seats")
	check_eq(empty.events.size(), 0, "an empty document yields no events")
	var junk := Session.from_dict({"seats": "not an array", "events": 42})
	check_eq(junk.seats.size(), 0, "a malformed seats field is ignored")
	check_eq(junk.events.size(), 0, "a malformed events field is ignored")
