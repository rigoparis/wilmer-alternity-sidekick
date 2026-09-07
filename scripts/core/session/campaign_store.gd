class_name CampaignStore
extends RefCounted
##
## Reads and writes campaigns under user://campaigns/. Pure I/O -- no UI.
##
## Mirrors CharacterStore deliberately: same constructor-injected directory so
## tests do not trample real campaigns, same {ok, ...} result dictionaries, same
## signals. Anything a person learned from one applies to the other.
##
## The one structural difference is the event log. A campaign runs for months,
## and every roll appends to it, so keeping the whole document in one JSON blob
## would mean rewriting a year of history on each die throw -- growing linearly
## in a place that is hit constantly. Instead each campaign is two files:
##
##     <id>.json          seats, name, optional rules -- current state, small,
##                        rewritten whenever it changes
##     <id>.events.jsonl  the append-only log, one JSON object per line,
##                        appended to and never rewritten
##
## That split is what makes the log cheap, and it is also why nothing above may
## depend on replaying it: seats carry current state (AP totals, character
## bindings, who the GM is), so a log trimmed to its last few thousand lines
## costs history and nothing else.
##

## Emitted after a save attempt. `path` is the globalized path on success.
signal saved(campaign_id: String, path: String)
signal save_failed(campaign_id: String, reason: String)

const SAVE_DIR := "user://campaigns/"
const LAST_OPENED_NAME := "last_campaign.txt"

## Events kept in memory when loading a campaign. A year of weekly play is well
## under this; the cap exists so opening an old campaign cannot stall on a log
## that grew past anything a feed would ever show.
const DEFAULT_EVENT_TAIL := 5000

## Directory this store reads and writes, always with a trailing slash.
var _dir: String = SAVE_DIR

## campaign_id -> the highest event sequence number already on disk.
##
## Without this, flushing would have to diff the file against memory on every
## append, which is the rewrite this design exists to avoid. Keyed by sequence
## rather than by a count because the two do not line up: loading a campaign
## keeps only the tail of a long log in memory, so index 0 in memory is not
## line 0 on disk.
var _flushed_seq: Dictionary = {}

## campaign_id -> how many lines the log sidecar holds.
##
## Separate from the sequence mark because the two answer different questions:
## sequences say what has been issued, this says how much history is on disk.
## The header records it so the campaign list can show a count without opening
## the log, and it must not be recomputed from a session whose in-memory tail
## was trimmed -- that would report a year of play as five events.
var _stored_count: Dictionary = {}


func _init(storage_directory: String = SAVE_DIR) -> void:
	_dir = storage_directory if storage_directory.ends_with("/") else storage_directory + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))


func directory() -> String:
	return _dir


func _header_path(campaign_id: String) -> String:
	return _dir + campaign_id + ".json"


func _events_path(campaign_id: String) -> String:
	return _dir + campaign_id + ".events.jsonl"


func _last_opened_path() -> String:
	return _dir + LAST_OPENED_NAME


# --- Listing ---------------------------------------------------------------

## Metadata for every saved campaign, most recently modified first.
##
## Reads only the header file. The event log is never opened here: listing five
## campaigns must not mean parsing five years of rolls.
func list() -> Array:
	var found: Array = []
	var dir := DirAccess.open(_dir)
	if dir == null:
		return found

	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue

		var path := _dir + file_name
		var data = _read_json(path)
		if typeof(data) != TYPE_DICTIONARY:
			continue

		var seats = data.get("seats", [])
		var seat_count: int = seats.size() if typeof(seats) == TYPE_ARRAY else 0
		found.append({
			"campaign_id": String(data.get("campaign_id", file_name.get_basename())),
			"display_name": String(data.get("display_name", "Untitled Campaign")),
			"created_at": AlternityNum.as_int(data.get("created_at", 0)),
			"seat_count": seat_count,
			"event_count": AlternityNum.as_int(data.get("event_count", 0)),
			"mod_time": FileAccess.get_modified_time(path),
		})

	found.sort_custom(func(a, b): return a["mod_time"] > b["mod_time"])
	return found


func exists(campaign_id: String) -> bool:
	return FileAccess.file_exists(_header_path(campaign_id))


# --- Load / save -----------------------------------------------------------

## Load one campaign, newest `max_events` log lines included. Returns null if
## the header is missing or unparseable.
##
## A missing or truncated event log is not an error: the header carries current
## state, so a campaign whose log was lost still opens with the right seats and
## AP totals and simply has no history to show.
func load_session(campaign_id: String, max_events: int = DEFAULT_EVENT_TAIL) -> CampaignSession:
	var data = _read_json(_header_path(campaign_id))
	if typeof(data) != TYPE_DICTIONARY:
		return null

	# The header never holds events; keep from_dict from adopting a stale copy
	# if an older file happened to embed them.
	data.erase("events")
	var session := CampaignSession.from_dict(data)

	var on_disk := _read_events(campaign_id)
	_flushed_seq[session.campaign_id] = _highest_seq(on_disk)
	_stored_count[session.campaign_id] = on_disk.size()
	if max_events > 0 and on_disk.size() > max_events:
		on_disk = on_disk.slice(on_disk.size() - max_events)
	session.adopt_events(on_disk)

	# The header's own high-water mark stands in when the tail was trimmed away,
	# so the next appended event cannot reuse a sequence number already spent.
	session.restore_last_seq(AlternityNum.as_int(data.get("last_seq", 0)))

	return session


## Flush any events not yet on disk, then write the header.
##
## Returns {ok, campaign_id, path, reason}. Log first, header second, so the
## header's counts describe a log that is already written; an interruption
## between them leaves history on disk that the header undercounts, which the
## next load corrects by reading the file.
func save(session: CampaignSession) -> Dictionary:
	if session == null:
		return {"ok": false, "campaign_id": "", "path": "", "reason": "no session"}

	flush_events(session)

	var payload := session.to_dict()
	# Events live in the sidecar. Two copies would drift the moment one of them
	# was appended to.
	payload.erase("events")
	# What is on disk, not what is in memory: a session loaded with only its
	# recent tail still has a full log behind it.
	payload["event_count"] = AlternityNum.as_int(_stored_count.get(session.campaign_id, session.events.size()))
	payload["last_seq"] = session.last_seq()

	var path := _header_path(session.campaign_id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var reason := "Cannot open %s for writing (error %d)" % [path, FileAccess.get_open_error()]
		save_failed.emit(session.campaign_id, reason)
		return {"ok": false, "campaign_id": session.campaign_id, "path": "", "reason": reason}

	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

	flush_events(session)

	var global_path := ProjectSettings.globalize_path(path)
	saved.emit(session.campaign_id, global_path)
	return {"ok": true, "campaign_id": session.campaign_id, "path": global_path, "reason": ""}


## Append to the log every event this store has not yet written. Returns how
## many lines were added.
##
## Cheap enough to call after each roll, which is the point: the log is the one
## part of a campaign that must not wait for an explicit save.
func flush_events(session: CampaignSession) -> int:
	if session == null:
		return 0
	# A store that has not seen this campaign before -- a fresh app run saving a
	# session it did not load -- must read the file's high-water mark first, or
	# it would append the whole in-memory log a second time.
	if not _flushed_seq.has(session.campaign_id):
		var on_disk := _read_events(session.campaign_id)
		_flushed_seq[session.campaign_id] = _highest_seq(on_disk)
		_stored_count[session.campaign_id] = on_disk.size()

	var already := AlternityNum.as_int(_flushed_seq.get(session.campaign_id, 0))
	var pending: Array = []
	for event in session.events:
		if AlternityNum.as_int(event.get("seq", 0)) > already:
			pending.append(event)
	if pending.is_empty():
		return 0

	var path := _events_path(session.campaign_id)
	var file := FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("CampaignStore: cannot append events to %s (error %d)" % [path, FileAccess.get_open_error()])
		return 0
	file.seek_end()
	for event in pending:
		# One object per line, so appending never rewrites and a corrupt line
		# costs one event rather than the file.
		file.store_line(JSON.stringify(event))
	file.close()

	_flushed_seq[session.campaign_id] = maxi(already, _highest_seq(pending))
	_stored_count[session.campaign_id] = AlternityNum.as_int(_stored_count.get(session.campaign_id, 0)) + pending.size()
	return pending.size()


## Record one event and flush it immediately. The normal path for a roll or a
## chat line arriving mid-session.
func record(session: CampaignSession, kind: String, player_id: String, payload: Dictionary) -> Dictionary:
	var event := session.append_event(kind, player_id, payload)
	flush_events(session)
	return event


## Change a campaign's name without touching its log.
##
## A header-only edit, so renaming a year-old campaign costs one small file
## write rather than reading and re-counting thousands of events.
func rename(campaign_id: String, display_name: String) -> bool:
	var data = _read_json(_header_path(campaign_id))
	if typeof(data) != TYPE_DICTIONARY:
		return false
	data["display_name"] = display_name

	var file := FileAccess.open(_header_path(campaign_id), FileAccess.WRITE)
	if file == null:
		push_error("CampaignStore: cannot rename %s (error %d)" % [campaign_id, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "	"))
	file.close()
	return true


func delete(campaign_id: String) -> bool:
	if not exists(campaign_id):
		return false
	if DirAccess.remove_absolute(_header_path(campaign_id)) != OK:
		return false
	var events_path := _events_path(campaign_id)
	if FileAccess.file_exists(events_path):
		DirAccess.remove_absolute(events_path)
	_flushed_seq.erase(campaign_id)
	_stored_count.erase(campaign_id)
	if last_opened() == campaign_id:
		clear_last_opened()
	return true


## Rewrite the stored log keeping only its newest `keep` lines.
##
## The one operation that does rewrite the sidecar, and the answer to a log that
## grows without bound. Sequence numbers are preserved, so a client replaying
## from a number older than what survives simply gets less history back.
func compact(campaign_id: String, keep: int) -> int:
	var all := _read_events(campaign_id)
	if keep < 0 or all.size() <= keep:
		return 0
	var dropped := all.size() - keep
	var kept: Array = all.slice(dropped)

	var path := _events_path(campaign_id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("CampaignStore: cannot compact %s (error %d)" % [path, FileAccess.get_open_error()])
		return 0
	for event in kept:
		file.store_line(JSON.stringify(event))
	file.close()

	_flushed_seq[campaign_id] = _highest_seq(kept)
	_stored_count[campaign_id] = kept.size()
	return dropped


## How many events are on disk for a campaign, whether or not it is loaded.
func stored_event_count(campaign_id: String) -> int:
	return _read_events(campaign_id).size()


# --- Last opened -----------------------------------------------------------

## Campaign to reopen on launch, or "" if none.
func last_opened() -> String:
	var file := FileAccess.open(_last_opened_path(), FileAccess.READ)
	if file == null:
		return ""
	var id := file.get_as_text().strip_edges()
	# Guard against a stale pointer to a campaign that has since been deleted.
	return id if not id.is_empty() and exists(id) else ""


func set_last_opened(campaign_id: String) -> void:
	var file := FileAccess.open(_last_opened_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(campaign_id)
		file.close()


func clear_last_opened() -> void:
	if FileAccess.file_exists(_last_opened_path()):
		DirAccess.remove_absolute(_last_opened_path())


# --- Reading ---------------------------------------------------------------

## Parse the log sidecar. Malformed lines are skipped rather than failing the
## load: one bad append must not cost a campaign its whole history.
func _read_events(campaign_id: String) -> Array:
	var out: Array = []
	var file := FileAccess.open(_events_path(campaign_id), FileAccess.READ)
	if file == null:
		return out
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parsed = _parse(line)
		if typeof(parsed) == TYPE_DICTIONARY:
			out.append(parsed)
	file.close()
	return out


func _highest_seq(entries: Array) -> int:
	var highest := 0
	for event in entries:
		highest = maxi(highest, AlternityNum.as_int(event.get("seq", 0)))
	return highest


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return _parse(file.get_as_text())


## JSON.parse() rather than JSON.parse_string(): the latter pushes an engine
## error on malformed input, and a log line half-written when a device lost
## power is an ordinary outcome to skip, not a fault to log on every load.
func _parse(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.get_data()
