extends "res://tools/test_harness.gd"
##
## Campaign persistence round-trips, using an isolated scratch directory.
##
## The store defaults to user://campaigns/, which will hold real campaigns --
## these tests would overwrite them. That is why CampaignStore takes its
## directory as a constructor argument, the same as CharacterStore.
##
## The interesting cases here are all about the sidecar log: that appending
## never rewrites, that a second store instance does not duplicate it, and that
## compaction cannot make the next event reuse a sequence number.
##

const Session := preload("res://scripts/core/session/campaign_session.gd")
const Store := preload("res://scripts/core/session/campaign_store.gd")

const TEST_DIR := "user://__campaign_store_test__/"


func _init() -> void:
	begin("campaign store")

	_wipe()
	_test_save_and_load()
	_test_events_are_a_sidecar()
	_test_append_only()
	_test_second_store_does_not_duplicate()
	_test_listing()
	_test_delete()
	_test_last_opened()
	_test_tail_limit()
	_test_compaction_preserves_sequence()
	_test_rename()
	_test_missing_and_corrupt()
	_wipe()

	finish()


func _new_store():
	return Store.new(TEST_DIR)


func _wipe() -> void:
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		DirAccess.remove_absolute(TEST_DIR + file_name)


func _events_file(campaign_id: String) -> String:
	return TEST_DIR + campaign_id + ".events.jsonl"


func _line_count(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var count := 0
	while not file.eof_reached():
		if not file.get_line().strip_edges().is_empty():
			count += 1
	file.close()
	return count


# --- Round trip ------------------------------------------------------------

func _test_save_and_load() -> void:
	var store = _new_store()
	var session = Session.new("The Long Haul")
	var alice := session.add_seat("Alice", "Vance_Kellar.json")
	var gm := session.add_seat("Rodri")
	session.set_gm(gm)
	session.set_campaign_optional_rule("dark_matter", true)
	session.append_chat(alice, "rolling for initiative")
	session.award_ap(alice, 3, Session.AP_REASON_HEROISM)

	var result: Dictionary = store.save(session)
	check_true(bool(result.get("ok", false)), "save reports success")
	check_eq(result.get("campaign_id", ""), session.campaign_id, "result carries the campaign id")

	var loaded = store.load_session(session.campaign_id)
	check(loaded != null, "campaign loads back")
	if loaded == null:
		return
	check_eq(loaded.display_name, "The Long Haul", "display name round-trips")
	check_eq(loaded.campaign_id, session.campaign_id, "campaign id round-trips")
	check_eq(loaded.created_at, session.created_at, "created_at round-trips")
	check_eq(loaded.seats.size(), 2, "both seats round-trip")
	check_eq(String(loaded.gm_seat().get("player_id", "")), gm, "GM designation round-trips")
	check_eq(loaded.get_seat_ap(alice), 3, "seat AP round-trips")
	check_true(bool(loaded.get_campaign_optional_rules().get("dark_matter", false)), "optional rules round-trip")
	check_eq(loaded.events.size(), 2, "both events round-trip")
	check_eq(String(loaded.events[0].get("kind", "")), Session.EVENT_CHAT, "the chat event is first")
	check_eq(String(loaded.events[1].get("kind", "")), Session.EVENT_AP_AWARD, "the AP award is second")
	check_eq(loaded.last_seq(), 2, "sequence high-water mark round-trips")

	# A returning player's pending awards must survive the trip; without them the
	# player device would never learn about AP granted while it was away.
	check_eq(loaded.get_pending_ap_awards(alice).size(), 1, "pending AP awards round-trip")


func _test_events_are_a_sidecar() -> void:
	var store = _new_store()
	var session = Session.new("Sidecar")
	session.append_chat(session.add_seat("Bo"), "hello")
	store.save(session)

	var header = JSON.parse_string(FileAccess.get_file_as_string(TEST_DIR + session.campaign_id + ".json"))
	check(typeof(header) == TYPE_DICTIONARY, "header parses as JSON")
	if typeof(header) != TYPE_DICTIONARY:
		return
	# The whole point of the split: one growing file, appended to, and a small
	# header that is safe to rewrite.
	check_false(header.has("events"), "the header does not carry the event log")
	check_eq(AlternityNum.as_int(header.get("event_count", -1)), 1, "the header records the event count")
	check_eq(AlternityNum.as_int(header.get("last_seq", -1)), 1, "the header records the sequence high-water mark")
	check_true(FileAccess.file_exists(_events_file(session.campaign_id)), "the log is written as a sidecar")
	check_eq(_line_count(_events_file(session.campaign_id)), 1, "one event is one line")


func _test_append_only() -> void:
	var store = _new_store()
	var session = Session.new("Append")
	var pid := session.add_seat("Cy")
	store.save(session)

	var path := _events_file(session.campaign_id)
	for i in 5:
		store.record(session, Session.EVENT_ROLL, pid, {"total": i})
	check_eq(_line_count(path), 5, "each recorded event adds exactly one line")

	# Saving again must not re-append what is already there.
	store.save(session)
	store.save(session)
	check_eq(_line_count(path), 5, "repeated saves do not duplicate the log")

	var loaded = store.load_session(session.campaign_id)
	check_eq(loaded.events.size(), 5, "all five events load back")
	check_eq(AlternityNum.as_int(loaded.events[4].get("payload", {}).get("total", -1)), 4, "the newest event is last")


func _test_second_store_does_not_duplicate() -> void:
	var store = _new_store()
	var session = Session.new("Two Stores")
	var pid := session.add_seat("Del")
	session.append_chat(pid, "one")
	session.append_chat(pid, "two")
	store.save(session)

	# A later app run: a brand-new store instance holding a session it never
	# loaded. Nothing in memory says how much is already on disk, so the store
	# has to read the file's high-water mark before appending.
	var fresh = _new_store()
	fresh.save(session)
	check_eq(_line_count(_events_file(session.campaign_id)), 2, "a fresh store does not re-append the log")

	session.append_chat(pid, "three")
	fresh.save(session)
	check_eq(_line_count(_events_file(session.campaign_id)), 3, "a fresh store still appends what is new")


func _test_listing() -> void:
	_wipe()
	var store = _new_store()
	var first = Session.new("First")
	first.add_seat("A")
	store.save(first)
	var second = Session.new("Second")
	second.add_seat("B")
	second.add_seat("C")
	second.append_chat("", "x")
	store.save(second)

	var listed: Array = store.list()
	check_eq(listed.size(), 2, "both campaigns are listed")
	var by_id: Dictionary = {}
	for entry in listed:
		by_id[String(entry.get("campaign_id", ""))] = entry
	check_true(by_id.has(first.campaign_id), "the first campaign is listed")
	check_eq(String(by_id.get(second.campaign_id, {}).get("display_name", "")), "Second", "listing carries the display name")
	check_eq(AlternityNum.as_int(by_id.get(second.campaign_id, {}).get("seat_count", -1)), 2, "listing carries the seat count")
	check_eq(AlternityNum.as_int(by_id.get(second.campaign_id, {}).get("event_count", -1)), 1, "listing carries the event count")
	# Listing must stay cheap; reading the log to count seats would defeat that.
	check_true(store.exists(first.campaign_id), "exists() finds a saved campaign")
	check_false(store.exists("nope"), "exists() rejects an unknown id")


func _test_delete() -> void:
	var store = _new_store()
	var session = Session.new("Doomed")
	session.append_chat(session.add_seat("E"), "last words")
	store.save(session)
	check_true(FileAccess.file_exists(_events_file(session.campaign_id)), "the log exists before deletion")

	check_true(store.delete(session.campaign_id), "delete reports success")
	check_false(store.exists(session.campaign_id), "the header is gone")
	check_false(FileAccess.file_exists(_events_file(session.campaign_id)), "the log sidecar goes with it")
	check_false(store.delete(session.campaign_id), "deleting twice reports failure")


func _test_last_opened() -> void:
	var store = _new_store()
	var session = Session.new("Remembered")
	store.save(session)

	check_eq(store.last_opened(), "", "nothing is remembered to begin with")
	store.set_last_opened(session.campaign_id)
	check_eq(store.last_opened(), session.campaign_id, "the last opened campaign is remembered")

	# A pointer at a deleted campaign must not survive; reopening it would fail.
	store.delete(session.campaign_id)
	check_eq(store.last_opened(), "", "a pointer to a deleted campaign is dropped")


func _test_tail_limit() -> void:
	var store = _new_store()
	var session = Session.new("Long Running")
	var pid := session.add_seat("F")
	for i in 40:
		session.append_chat(pid, "line %d" % i)
	store.save(session)

	var tail = store.load_session(session.campaign_id, 10)
	check_eq(tail.events.size(), 10, "only the requested tail is loaded")
	check_eq(AlternityNum.as_int(tail.events[0].get("seq", 0)), 31, "the tail starts where it should")
	check_eq(tail.last_seq(), 40, "the sequence mark reflects the whole log, not the tail")

	# The load-bearing part: appending after a trimmed load must not reuse a
	# sequence number that is already spent on disk.
	var next: Dictionary = tail.append_chat(pid, "after")
	check_eq(AlternityNum.as_int(next.get("seq", 0)), 41, "the next event continues the sequence")
	check_eq(store.flush_events(tail), 1, "only the new event is flushed")
	check_eq(_line_count(_events_file(session.campaign_id)), 41, "the file grew by exactly one line")

	var all = store.load_session(session.campaign_id, 0)
	check_eq(all.events.size(), 41, "a zero limit loads the whole log")

	# Saving a session that only holds its tail must not tell the header the
	# campaign is ten events long. The list would then report a year of play as
	# a handful of lines.
	store.save(tail)
	var header = JSON.parse_string(FileAccess.get_file_as_string(TEST_DIR + session.campaign_id + ".json"))
	check_eq(AlternityNum.as_int(header.get("event_count", -1)), 41,
		"the header counts the whole log, not the loaded tail")
	check_eq(_line_count(_events_file(session.campaign_id)), 41,
		"saving a trimmed session does not rewrite or duplicate the log")


func _test_compaction_preserves_sequence() -> void:
	var store = _new_store()
	var session = Session.new("Compacted")
	var pid := session.add_seat("G")
	for i in 30:
		session.append_chat(pid, "line %d" % i)
	store.save(session)

	check_eq(store.compact(session.campaign_id, 5), 25, "compaction reports how much it dropped")
	check_eq(_line_count(_events_file(session.campaign_id)), 5, "only the newest events survive on disk")
	check_eq(store.compact(session.campaign_id, 500), 0, "compacting below the kept count does nothing")

	var loaded = store.load_session(session.campaign_id)
	check_eq(loaded.events.size(), 5, "the compacted log loads")
	check_eq(AlternityNum.as_int(loaded.events[0].get("seq", 0)), 26, "surviving sequence numbers are untouched")
	check_eq(loaded.last_seq(), 30, "the header's high-water mark survives compaction")
	var next: Dictionary = loaded.append_chat(pid, "after compaction")
	check_eq(AlternityNum.as_int(next.get("seq", 0)), 31, "appending after compaction does not reuse a sequence")

	# Seats, not the log, carry current state -- which is what makes dropping
	# history safe at all.
	check_eq(loaded.seats.size(), 1, "compaction does not touch seats")

	store.flush_events(loaded)
	check_eq(_line_count(_events_file(session.campaign_id)), 6, "the new event appends to the compacted file")


## Renaming touches the header and nothing else. A year-old campaign must not
## have to read its log to change one string.
func _test_rename() -> void:
	var store = _new_store()
	var session = Session.new("Working Title")
	var pid := session.add_seat("Ivy")
	for i in 12:
		session.append_chat(pid, "line %d" % i)
	store.save(session)

	check_true(store.rename(session.campaign_id, "The Verge"), "rename reports success")
	check_eq(_line_count(_events_file(session.campaign_id)), 12, "renaming does not touch the log")

	var loaded = store.load_session(session.campaign_id)
	check_eq(loaded.display_name, "The Verge", "the new name is stored")
	check_eq(loaded.events.size(), 12, "the log survives a rename")
	check_eq(loaded.last_seq(), 12, "the sequence mark survives a rename")
	check_eq(loaded.seats.size(), 1, "seats survive a rename")
	check_false(store.rename("does-not-exist", "Nope"), "renaming an unknown campaign fails")


func _test_missing_and_corrupt() -> void:
	var store = _new_store()
	check(store.load_session("does-not-exist") == null, "loading an unknown campaign returns null")

	var session = Session.new("Torn")
	var pid := session.add_seat("H")
	session.append_chat(pid, "intact")
	store.save(session)

	# A half-written line is an ordinary outcome of a device losing power
	# mid-append. It must cost that one event, not the campaign.
	var file := FileAccess.open(_events_file(session.campaign_id), FileAccess.READ_WRITE)
	file.seek_end()
	file.store_line("{\"seq\": 2, \"kind\": \"chat\"")
	file.close()

	var loaded = store.load_session(session.campaign_id)
	check(loaded != null, "a campaign with a corrupt log line still loads")
	check_eq(loaded.events.size(), 1, "the unparseable line is skipped")
	check_eq(loaded.seats.size(), 1, "seats survive a corrupt log")

	# A campaign whose log was lost entirely still has to open.
	DirAccess.remove_absolute(_events_file(session.campaign_id))
	var no_log = store.load_session(session.campaign_id)
	check(no_log != null, "a campaign with no log at all still loads")
	check_eq(no_log.events.size(), 0, "it simply has no history")
	check_eq(no_log.seats.size(), 1, "and its seats are intact")

	# With the log gone there is no surviving event to recover the sequence from,
	# so the header is the only thing standing between the next roll and a
	# sequence number that was already spent. A reconnecting client asking for
	# "everything after seq 1" would otherwise be handed the wrong events.
	check_eq(no_log.last_seq(), 1, "the header alone restores the sequence mark")
	check_eq(AlternityNum.as_int(no_log.append_chat(pid, "after the loss").get("seq", 0)), 2,
		"the next event continues past the lost log rather than restarting")
