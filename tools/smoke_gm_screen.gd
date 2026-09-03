extends "res://tools/test_harness.gd"
##
## The single-device half of the multiplayer feature, driven through the real
## shell: campaign list, GM screen, seats, AP awards and the event feed.
##
## Phase M1's checkpoint stated as a test -- a GM can run a session on one
## device, award AP, and reopen the campaign later with the log intact. The
## reopen is done by tearing the shell down and building a second one against
## the same directory, because "it is still in memory" is not the claim.
##
## Runs against scratch directories for both stores. Without that it would read
## and overwrite real characters and real campaigns.
##

const SHELL := preload("res://scenes/ui/app_shell.tscn")
const Session := preload("res://scripts/core/session/campaign_session.gd")

const TEST_DIR := "user://__gm_test__/"
const TEST_CAMPAIGN_DIR := "user://__gm_test_campaigns__/"

var _shell


func _init() -> void:
	begin_async("gm screen", 1200)
	_run.call_deferred()


func _run() -> void:
	_wipe(TEST_DIR)
	_wipe(TEST_CAMPAIGN_DIR)

	_shell = _new_shell()
	await process_frame
	await process_frame

	await _test_reaches_the_campaign_list()
	await _test_create_campaign()
	await _test_add_seats()
	await _test_bind_character()
	await _test_award_ap()
	await _test_table_award()
	await _test_set_ap()
	await _test_feed()
	await _test_remove_seat()
	await _test_back_unwinds()
	await _test_rename_and_delete()
	await _test_reopen_a_week_later()

	if is_instance_valid(_shell):
		_shell.queue_free()
	_wipe(TEST_DIR)
	_wipe(TEST_CAMPAIGN_DIR)
	finish()


func _new_shell():
	var shell = SHELL.instantiate()
	shell.store_directory = TEST_DIR
	shell.campaign_directory = TEST_CAMPAIGN_DIR
	root.add_child(shell)
	return shell


func _wipe(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name in dir.get_files():
		DirAccess.remove_absolute(dir_path + file_name)


func _screens() -> Control:
	return _shell.get_node_or_null("Screens")


func _find(script_fragment: String) -> Node:
	var host := _screens()
	if host == null:
		return null
	for child in host.get_children():
		var script = child.get_script()
		if script != null and String(script.resource_path).contains(script_fragment):
			return child
	return null


func _campaign_screen():
	return _find("campaign_select")


func _gm_screen():
	return _find("gm_screen")


## Answer whatever route is open, the way a person would.
func _answer(result: Variant) -> void:
	var responder := func() -> void:
		await process_frame
		var route = _shell.router._host.top_route()
		if route != null:
			route.close(result)
	responder.call_deferred()


# --- Getting there ---------------------------------------------------------

func _test_reaches_the_campaign_list() -> void:
	var select = _find("character_select")
	if not check(select != null, "the shell opens on the character list"):
		return
	check_true(_shell.campaigns != null, "the shell built a campaign store")
	check_eq(_shell.campaigns.list().size(), 0, "the scratch campaign store starts empty")

	select.campaigns_opened.emit()
	await process_frame
	check_true(_campaign_screen() != null, "the campaign list is reachable from the character list")
	check_true(_find("character_select") == null, "and it replaces the character list rather than stacking on it")


func _test_create_campaign() -> void:
	var screen = _campaign_screen()
	if not check(screen != null, "the campaign list is showing"):
		return

	# Cancelling the name prompt must not leave a nameless campaign behind.
	_answer(null)
	await screen._on_create_pressed()
	check_eq(_shell.campaigns.list().size(), 0, "cancelling the name prompt creates nothing")

	_answer("The Verge")
	await screen._on_create_pressed()
	await process_frame

	check_eq(_shell.campaigns.list().size(), 1, "naming it creates and saves the campaign")
	var gm = _gm_screen()
	check_true(gm != null, "creating a campaign opens the GM screen")
	if gm != null:
		check_eq(gm.session().display_name, "The Verge", "the GM screen shows the new campaign")
		check_eq(gm.session().seats.size(), 0, "a new campaign starts with no seats")


# --- Seats -----------------------------------------------------------------

func _test_add_seats() -> void:
	var gm = _gm_screen()
	if not check(gm != null, "the GM screen is showing"):
		return

	_answer(null)
	await gm._on_add_seat_pressed()
	check_eq(gm.session().seats.size(), 0, "cancelling the prompt seats nobody")

	_answer("Rodri")
	await gm._on_add_seat_pressed()
	await process_frame
	check_eq(gm.session().seats.size(), 1, "the first seat is added")
	# The person setting up a campaign on their own device is the GM; making that
	# automatic keeps the "exactly one GM" invariant true from the first seat.
	check_eq(
		String(gm.session().gm_seat().get("player_name", "")), "Rodri",
		"the first seat is made GM automatically"
	)

	_answer("Alice")
	await gm._on_add_seat_pressed()
	_answer("Bob")
	await gm._on_add_seat_pressed()
	await process_frame
	check_eq(gm.session().seats.size(), 3, "further seats are added")
	check_eq(
		String(gm.session().gm_seat().get("player_name", "")), "Rodri",
		"later seats do not take over as GM"
	)

	# Seating is persisted immediately, not on some later save.
	var stored = _shell.campaigns.load_session(gm.session().campaign_id)
	check_eq(stored.seats.size(), 3, "seats are written to disk as they are added")

	# Every join is in the log, so a GM can see who arrived when.
	var joins := 0
	for event in gm.session().events:
		if String(event.get("kind", "")) == Session.EVENT_JOIN:
			joins += 1
	check_eq(joins, 3, "each seating is logged as a join event")


func _seat_id(gm, player_name: String) -> String:
	for seat in gm.session().seats:
		if String(seat.get("player_name", "")) == player_name:
			return String(seat.get("player_id", ""))
	return ""


func _test_bind_character() -> void:
	var gm = _gm_screen()
	if not check(gm != null, "the GM screen is showing"):
		return

	# A hero to bind to. Saved through the shell's own character store so the
	# GM screen reads it exactly as it would in use.
	var doc = CharacterDoc.new(_shell.rules)
	doc.set_hero_name("Vance Kellar")
	_shell.store.save(doc)

	var alice := _seat_id(gm, "Alice")
	gm._on_character_chosen(alice, "Vance_Kellar.json")
	await process_frame

	check_eq(
		String(gm.session().seat_for(alice).get("character_file", "")), "Vance_Kellar.json",
		"the seat is bound to the character file"
	)
	var stored = _shell.campaigns.load_session(gm.session().campaign_id)
	check_eq(
		String(stored.seat_for(alice).get("character_file", "")), "Vance_Kellar.json",
		"the binding is persisted"
	)

	# The key numbers must come from the character's own summary rather than be
	# recomputed here, or the GM screen and the sheet would drift apart.
	var summary: Dictionary = gm._summary_for("Vance_Kellar.json")
	check_false(summary.is_empty(), "the bound character's summary is available")
	check_true(summary.has("durability"), "durability is read from the summary")
	check_true(summary.has("action_check"), "the action check is read from the summary")
	check_true(summary.has("last_resorts"), "last resorts are read from the summary")
	check_eq(
		AlternityNum.as_int(summary.get("durability", {}).get("stun", 0)),
		AlternityNum.as_int(doc.summary().get("durability", {}).get("stun", -1)),
		"the GM sees the same durability the sheet does"
	)

	# A binding whose file has since been deleted must not read as unbound.
	check_true(gm._summary_for("gone.json").is_empty(), "a missing character yields no numbers")
	check_eq(String(gm.session().seat_for(alice).get("character_file", "")), "Vance_Kellar.json",
		"and does not clear the binding")


# --- Achievement points ----------------------------------------------------

func _test_award_ap() -> void:
	var gm = _gm_screen()
	if not check(gm != null, "the GM screen is showing"):
		return
	var alice := _seat_id(gm, "Alice")

	_answer(null)
	await gm._on_award_pressed(alice)
	check_eq(gm.session().get_seat_ap(alice), 0, "cancelling awards nothing")

	# Zero is a no-op rather than an event; a log full of "awarded 0 AP" is noise.
	_answer({"amount": 0, "reason": Session.AP_REASON_COMPLETION})
	await gm._on_award_pressed(alice)
	check_eq(gm.session().get_seat_ap(alice), 0, "awarding zero changes nothing")
	check_eq(_count_events(gm, Session.EVENT_AP_AWARD), 0, "and logs nothing")

	_answer({"amount": 3, "reason": Session.AP_REASON_HEROISM})
	await gm._on_award_pressed(alice)
	await process_frame

	check_eq(gm.session().get_seat_ap(alice), 3, "the award lands on the seat")
	check_eq(_count_events(gm, Session.EVENT_AP_AWARD), 1, "the award is logged")
	var award := _last_event(gm, Session.EVENT_AP_AWARD)
	check_eq(String(award.get("payload", {}).get("reason", "")), Session.AP_REASON_HEROISM,
		"the reason is recorded, which is what makes the ledger readable later")
	check_eq(AlternityNum.as_int(award.get("payload", {}).get("previous_ap", -1)), 0,
		"the award records what the total was before it")

	# The player's device has to learn about this when it next connects.
	check_eq(gm.session().get_pending_ap_awards(alice).size(), 1, "the award is left pending for the player")

	var stored = _shell.campaigns.load_session(gm.session().campaign_id)
	check_eq(stored.get_seat_ap(alice), 3, "the award is persisted")


func _test_table_award() -> void:
	var gm = _gm_screen()
	var alice := _seat_id(gm, "Alice")
	var bob := _seat_id(gm, "Bob")
	var rodri := _seat_id(gm, "Rodri")

	_answer({"amount": 2, "reason": Session.AP_REASON_COMPLETION})
	await gm._on_table_award_pressed()
	await process_frame

	check_eq(gm.session().get_seat_ap(alice), 5, "the table award adds to Alice's existing total")
	check_eq(gm.session().get_seat_ap(bob), 2, "and reaches a seat with nothing yet")
	# The GM is at the table but is not a player; awarding themselves AP is not
	# what "award the table" means.
	check_eq(gm.session().get_seat_ap(rodri), 0, "the GM's own seat is skipped")


func _test_set_ap() -> void:
	var gm = _gm_screen()
	var bob := _seat_id(gm, "Bob")

	_answer(null)
	await gm._on_set_ap_pressed(bob)
	check_eq(gm.session().get_seat_ap(bob), 2, "cancelling a correction changes nothing")

	_answer({"amount": 7, "reason": "GM Adjustment", "mode": "set"})
	await gm._on_set_ap_pressed(bob)
	await process_frame
	check_eq(gm.session().get_seat_ap(bob), 7, "setting replaces the total rather than adding to it")
	var event := _last_event(gm, Session.EVENT_AP_SET)
	check_eq(AlternityNum.as_int(event.get("payload", {}).get("previous_ap", -1)), 2,
		"the correction records what it replaced")

	# Zero has to be reachable: a correction back to nothing is legitimate.
	_answer({"amount": 0, "reason": "GM Adjustment", "mode": "set"})
	await gm._on_set_ap_pressed(bob)
	check_eq(gm.session().get_seat_ap(bob), 0, "a seat can be corrected back to zero")


func _count_events(gm, kind: String) -> int:
	var count := 0
	for event in gm.session().events:
		if String(event.get("kind", "")) == kind:
			count += 1
	return count


func _last_event(gm, kind: String) -> Dictionary:
	var found: Dictionary = {}
	for event in gm.session().events:
		if String(event.get("kind", "")) == kind:
			found = event
	return found


# --- The feed --------------------------------------------------------------

func _test_feed() -> void:
	var gm = _gm_screen()
	var alice := _seat_id(gm, "Alice")

	gm.session().append_chat(alice, "table-wide hello")
	gm.session().append_chat(alice, "psst", _seat_id(gm, "Rodri"))
	gm.session().append_roll(alice, {"notation": "d20", "total": 17, "label": "Action check"})
	gm.refresh()
	await process_frame

	var lines: Array = []
	for child in gm._feed_list.get_children():
		lines.append(child.text)
	check_true(lines.size() > 0, "the feed renders the log")

	# Newest first: mid-session the GM wants the last thing that happened.
	check_true(lines[0].contains("rolled"), "the newest event is at the top")
	check_true(lines[0].contains("17"), "a roll shows its total")
	check_true(lines[0].contains("Action check"), "a roll shows what it was for")

	var joined := "\n".join(lines)
	check_true(joined.contains("table-wide hello"), "chat appears in the feed")
	# A private line must be visibly marked, or a GM reading the log later would
	# think the table saw it.
	check_true(joined.contains("private to"), "a private line is marked as private")
	check_true(joined.contains("awarded 3 AP"), "AP awards appear in the feed")
	check_true(joined.contains(Session.AP_REASON_HEROISM), "with the reason that was given")
	check_false(joined.contains(alice), "raw player ids are never shown")

	# The feed is capped; the log is not.
	for i in (gm.FEED_LENGTH + 20):
		gm.session().append_chat(alice, "filler %d" % i)
	gm.refresh()
	await process_frame
	check_eq(gm._feed_list.get_child_count(), gm.FEED_LENGTH, "the feed shows at most FEED_LENGTH lines")
	check_true(gm.session().events.size() > gm.FEED_LENGTH, "while the log itself keeps everything")


# --- Removal and navigation ------------------------------------------------

func _test_remove_seat() -> void:
	var gm = _gm_screen()
	var bob := _seat_id(gm, "Bob")

	_answer(null)
	await gm._on_remove_seat_pressed(bob, "Bob")
	check_eq(gm.session().seats.size(), 3, "cancelling keeps the seat")

	_answer(true)
	await gm._on_remove_seat_pressed(bob, "Bob")
	await process_frame
	check_eq(gm.session().seats.size(), 2, "confirming removes the seat")
	check_false(gm.session().has_seat(bob), "the seat is gone")

	# Their history stays, and must still render without a seat to name them.
	var line: String = gm._describe_event({"kind": Session.EVENT_CHAT, "player_id": bob, "at": 1, "payload": {"text": "hi"}})
	check_true(line.contains("departed"), "events from a removed seat still render readably")
	check_false(line.contains(bob), "and never fall back to showing a raw id")


func _test_back_unwinds() -> void:
	var gm = _gm_screen()
	if not check(gm != null, "the GM screen is showing"):
		return

	# Back from the GM screen goes to the campaign list, not out of the app.
	_shell._handle_back()
	await process_frame
	check_true(_campaign_screen() != null, "back from the GM screen returns to the campaign list")
	check_true(_gm_screen() == null, "and the GM screen is gone")

	# Back again reaches the character list rather than quitting.
	_shell._handle_back()
	await process_frame
	check_true(_find("character_select") != null, "back from the campaign list returns to the character list")


func _test_rename_and_delete() -> void:
	var select = _find("character_select")
	select.campaigns_opened.emit()
	await process_frame
	var screen = _campaign_screen()
	if not check(screen != null, "the campaign list is showing again"):
		return

	var listed: Array = _shell.campaigns.list()
	if not check(listed.size() == 1, "one campaign to work with"):
		return
	var campaign_id := String(listed[0]["campaign_id"])
	var events_before: int = _shell.campaigns.stored_event_count(campaign_id)
	check_true(events_before > 0, "the campaign has a log to protect")

	_answer(null)
	await screen._on_rename_pressed(campaign_id, "The Verge")
	check_eq(String(_shell.campaigns.list()[0]["display_name"]), "The Verge", "cancelling keeps the name")

	_answer("The Verge Reborn")
	await screen._on_rename_pressed(campaign_id, "The Verge")
	await process_frame
	check_eq(String(_shell.campaigns.list()[0]["display_name"]), "The Verge Reborn", "renaming takes effect")
	check_eq(
		_shell.campaigns.stored_event_count(campaign_id), events_before,
		"renaming does not disturb the log"
	)
	# The listing count has to keep describing the whole log, not whatever was
	# last held in memory.
	check_eq(
		AlternityNum.as_int(_shell.campaigns.list()[0]["event_count"]), events_before,
		"the listing still reports the full event count after a rename"
	)


# --- The checkpoint --------------------------------------------------------

## Phase M1's checkpoint: reopen the campaign a week later with the log intact.
##
## Done with a second shell against the same directory, because the claim is
## about what is on disk, not about what happens to still be in memory.
func _test_reopen_a_week_later() -> void:
	var before = _shell.campaigns.load_session(_shell.campaigns.list()[0]["campaign_id"])
	var campaign_id: String = before.campaign_id
	var seat_count: int = before.seats.size()
	var event_count: int = before.events.size()
	var alice_ap: int = before.get_seat_ap(_seat_id_of(before, "Alice"))

	_shell.queue_free()
	await process_frame
	await process_frame

	_shell = _new_shell()
	await process_frame
	await process_frame

	# The new shell reopens the last character in use, which is what launching
	# the app normally does -- there is a saved hero from the binding test. Back
	# out of the sheet the way a person would before going to the campaigns.
	if _find("character_sheet") != null:
		_shell._handle_back()
		await process_frame
	var select = _find("character_select")
	if not check(select != null, "a fresh app run reaches the character list"):
		return
	select.campaigns_opened.emit()
	await process_frame
	var screen = _campaign_screen()
	if not check(screen != null, "the new shell reaches the campaign list"):
		return
	check_eq(_shell.campaigns.list().size(), 1, "the campaign is still there in a fresh app run")

	screen._on_open_pressed(campaign_id)
	await process_frame
	var gm = _gm_screen()
	if not check(gm != null, "opening the campaign reaches the GM screen"):
		return

	check_eq(gm.session().campaign_id, campaign_id, "the same campaign reopens")
	check_eq(gm.session().display_name, "The Verge Reborn", "its name survived")
	check_eq(gm.session().seats.size(), seat_count, "its seats survived")
	check_eq(gm.session().events.size(), event_count, "its whole log survived")
	check_eq(gm.session().get_seat_ap(_seat_id(gm, "Alice")), alice_ap, "the AP ledger survived")
	check_eq(
		String(gm.session().gm_seat().get("player_name", "")), "Rodri",
		"and the GM is still the GM"
	)

	# Play carries on from where it stopped rather than restarting the log.
	var next_seq: int = AlternityNum.as_int(gm.session().append_chat(_seat_id(gm, "Alice"), "we are back").get("seq", 0))
	check_eq(next_seq, event_count + 1, "the next event continues the sequence a week later")

	# Deleting takes the log with it -- the last thing the campaign list can do.
	# Opening the campaign replaced the list screen, so go back to it first.
	_shell._handle_back()
	await process_frame
	var list_screen = _campaign_screen()
	if not check(list_screen != null, "back from the GM screen returns to the campaign list"):
		return
	_answer(true)
	await list_screen._on_delete_pressed(campaign_id, "The Verge Reborn")
	var remaining: int = _shell.campaigns.list().size()
	check_eq(remaining, 0, "deleting the campaign removes it")
	check_false(
		FileAccess.file_exists(TEST_CAMPAIGN_DIR + campaign_id + ".events.jsonl"),
		"and takes its event log with it"
	)


func _seat_id_of(session, player_name: String) -> String:
	for seat in session.seats:
		if String(seat.get("player_name", "")) == player_name:
			return String(seat.get("player_id", ""))
	return ""
