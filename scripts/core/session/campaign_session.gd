class_name CampaignSession
extends RefCounted
##
## A campaign that persists between sittings.
##
## Alternity campaigns run for months or years, so a session is not a lobby that
## exists while everyone is connected. It is a document the GM keeps: who is at
## the table, which character each person plays, and what has happened.
##
## The load-bearing decision is that a player is identified by a `player_id`
## generated once and stored here -- never by a network peer id. ENet assigns
## peer ids randomly per connection, so a returning player gets a different one
## every time. Reconnecting is therefore "match this peer to an existing seat",
## not "add a player", and that only works if identity outlives the connection.
##
## No networking here. This is the document; NetTransport moves it around.
##

## Bumped when the stored shape changes, so old campaign files can be migrated.
const FORMAT_VERSION := 1

# Event kinds recorded in the log.
const EVENT_ROLL := "roll"
const EVENT_CHAT := "chat"
const EVENT_NOTE := "note"
const EVENT_JOIN := "join"
const EVENT_AP_AWARD := "ap_award"
const EVENT_AP_SET := "ap_set"

## A GM called for a check. Logged because it is something the GM did at the
## table, and it stands whether or not anybody answered it.
##
## A player's own request is not logged: if they roll, the roll event carries the
## whole check, and if they change their mind nothing happened.
const EVENT_CHECK := "check"

## AP Award reasons based on core Alternity GM guidelines
const AP_REASON_COMPLETION := "Adventure Completion"
const AP_REASON_ROLEPLAYING := "Roleplaying Bonus"
const AP_REASON_HEROISM := "Heroism Bonus"
const AP_REASON_CUSTOM := "Custom Award"

## The reasons that can sensibly be given to everyone at once.
##
## Completing the adventure is something the whole party did. Roleplaying and
## heroism are things one person did, and awarding them table-wide says the
## opposite of what they mean -- so award_table_ap refuses them rather than
## leaving it to whichever screen happens to be offering the choice.
const AP_TABLE_REASONS := [AP_REASON_COMPLETION, AP_REASON_CUSTOM]

var campaign_id: String = ""
var display_name: String = "New Campaign"
var created_at: int = 0
var format_version: int = FORMAT_VERSION

## Seats at the table, one per player. See add_seat().
var seats: Array = []

## Append-only history: rolls, chat, GM notes. Never rewritten, so a session can
## be replayed or audited months later.
var events: Array = []

## Campaign-level optional rules set by the GM and synced to all players at the table.
var optional_rules: Dictionary = {}

## skill_id -> how many times the GM has called for or ruled on that skill.
##
## A table checks the same handful of things over and over -- Awareness, Stamina,
## whatever the current adventure turns on -- and making the GM walk the whole
## catalogue each time is the difference between a tool and a chore. Kept on the
## campaign rather than on the device: it describes this table's habits, and a GM
## who reinstalls should not lose them.
var check_counts: Dictionary = {}

## Highest sequence number issued so far.
##
## Tracked rather than derived from events.size() because the stored log may be
## compacted -- a year of play is unbounded, and only the tail is worth keeping.
## Deriving the next number from the array length would then reissue sequence 1
## over a trimmed log, and reconnect replay ("everything after seq N") would
## silently resend or skip.
var _last_seq: int = 0


func _init(name: String = "New Campaign") -> void:
	campaign_id = new_id()
	display_name = name
	created_at = int(Time.get_unix_time_from_system())
	optional_rules = {}


## Random identifier, used for both campaigns and players.
##
## Crypto rather than randi(): these must not collide across devices that have
## never met, and the global RNG is seeded per-process.
static func new_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


# --- Seats -----------------------------------------------------------------

## Add a player and return their permanent id.
##
## `character_file` is informational -- the name of the file on the player's own
## device. What the GM actually reads is the committed snapshot, which the player
## sends via commit_character() once they have chosen a hero.
func add_seat(player_name: String, character_file: String = "") -> String:
	var player_id := new_id()
	seats.append({
		"player_id": player_id,
		"player_name": player_name,
		# What the player committed. The GM never sets this -- see commit_character.
		"character_file": character_file,
		"character_snapshot": {},
		"is_gm": false,
		"achievement_points": 0,
		"pending_ap_awards": [],
		"joined_at": int(Time.get_unix_time_from_system()),
		"last_seen": 0,
	})
	return player_id


func seat_for(player_id: String) -> Dictionary:
	for seat in seats:
		if String(seat.get("player_id", "")) == player_id:
			return seat
	return {}


func has_seat(player_id: String) -> bool:
	return not seat_for(player_id).is_empty()


## Record the character a player has committed to this campaign.
##
## The player's device calls this, never the GM's. A GM choosing which hero
## somebody plays is the one thing the ownership rule exists to prevent, and it
## used to be possible: the GM screen had a dropdown on every seat.
##
## Returns false for an unknown player, and for a snapshot this build cannot
## read -- a seat showing a half-understood character is worse than one showing
## none.
func commit_character(player_id: String, snapshot: Dictionary) -> bool:
	var seat := seat_for(player_id)
	if seat.is_empty():
		return false
	if not CharacterSnapshot.is_usable(snapshot):
		return false
	seat["character_snapshot"] = snapshot.duplicate(true)
	seat["character_file"] = String(snapshot.get("source_file", ""))
	return true


## The character a player has committed, or {} if they have not yet.
func committed_character(player_id: String) -> Dictionary:
	var seat := seat_for(player_id)
	if seat.is_empty():
		return {}
	var snapshot = seat.get("character_snapshot", {})
	return snapshot if typeof(snapshot) == TYPE_DICTIONARY else {}


func has_committed_character(player_id: String) -> bool:
	return CharacterSnapshot.is_usable(committed_character(player_id))


func remove_seat(player_id: String) -> bool:
	for i in seats.size():
		if String(seats[i].get("player_id", "")) == player_id:
			seats.remove_at(i)
			return true
	return false


## Record that a known player is connected again.
##
## This is the whole point of stable ids: the caller matches a freshly assigned
## peer id to a seat by player_id, and the seat carries on where it left off.
## Returns false for an unrecognised player, which the caller should treat as a
## request to join rather than a reconnect.
func mark_seen(player_id: String) -> bool:
	var seat := seat_for(player_id)
	if seat.is_empty():
		return false
	seat["last_seen"] = int(Time.get_unix_time_from_system())
	return true


func gm_seat() -> Dictionary:
	for seat in seats:
		if bool(seat.get("is_gm", false)):
			return seat
	return {}


func set_gm(player_id: String) -> bool:
	var seat := seat_for(player_id)
	if seat.is_empty():
		return false
	for other in seats:
		other["is_gm"] = false
	seat["is_gm"] = true
	return true


# --- What this table checks ------------------------------------------------

## Count one more check on a skill, and return the new total.
##
## Called when the GM rules on a request or calls for a check -- both are the GM
## deciding that this skill matters right now, which is what the shortcuts are
## trying to predict.
func note_check(skill_id: int) -> int:
	if skill_id < 0:
		return 0
	var key := str(skill_id)
	var count := AlternityNum.as_int(check_counts.get(key, 0)) + 1
	check_counts[key] = count
	return count


func check_count(skill_id: int) -> int:
	return AlternityNum.as_int(check_counts.get(str(skill_id), 0))


## The skills this table checks most, commonest first.
##
## Returns [{skill_id, count}], at most `limit` of them. Ties break by skill id
## so the shortcut row does not reshuffle itself between renders for no reason.
func most_checked(limit: int = 6) -> Array:
	var rows: Array = []
	for key in check_counts:
		rows.append({
			"skill_id": AlternityNum.as_int(key, -1),
			"count": AlternityNum.as_int(check_counts[key]),
		})
	rows.sort_custom(func(a, b):
		if AlternityNum.as_int(a["count"]) == AlternityNum.as_int(b["count"]):
			return AlternityNum.as_int(a["skill_id"]) < AlternityNum.as_int(b["skill_id"])
		return AlternityNum.as_int(a["count"]) > AlternityNum.as_int(b["count"]))
	return rows.slice(0, maxi(0, limit))


# --- Event log -------------------------------------------------------------

## Append one event. Stamps time and a monotonic sequence number so the log
## stays ordered even when two events share a timestamp.
func append_event(kind: String, player_id: String, payload: Dictionary) -> Dictionary:
	_last_seq += 1
	var event := {
		"seq": _last_seq,
		"kind": kind,
		"player_id": player_id,
		"at": int(Time.get_unix_time_from_system()),
		"payload": payload,
	}
	events.append(event)
	return event


## Record a completed roll. Takes the serialized RollResult, which is what
## arrives from a player device once their dice have settled.
func append_roll(player_id: String, roll: Dictionary) -> Dictionary:
	return append_event(EVENT_ROLL, player_id, roll)


## Record a chat message. `to_player_id` empty means the whole table; set it for
## a private line between one player and the GM.
func append_chat(player_id: String, text: String, to_player_id: String = "") -> Dictionary:
	return append_event(EVENT_CHAT, player_id, {"text": text, "to": to_player_id})


## Events involving a player, newest last. Includes private messages addressed
## to them as well as their own.
func events_for(player_id: String) -> Array:
	var out: Array = []
	for event in events:
		if String(event.get("player_id", "")) == player_id:
			out.append(event)
			continue
		var payload = event.get("payload", {})
		if typeof(payload) == TYPE_DICTIONARY and String(payload.get("to", "")) == player_id:
			out.append(event)
	return out


## The most recent `count` events, for showing a returning player what they
## missed without loading a year of history.
func recent_events(count: int) -> Array:
	if count <= 0 or events.is_empty():
		return []
	return events.slice(maxi(0, events.size() - count))


## Everything issued after `seq`, which is what a reconnecting client asks for.
##
## The client remembers the last sequence number it saw; the host replays from
## there. Nothing is re-derived from the payloads -- seats already carry current
## state -- so a gap caused by log compaction costs history, never correctness.
func events_since(seq: int) -> Array:
	var out: Array = []
	for event in events:
		if AlternityNum.as_int(event.get("seq", 0)) > seq:
			out.append(event)
	return out


## Highest sequence number issued, whether or not that event is still in memory.
func last_seq() -> int:
	return _last_seq


## Raise the sequence high-water mark without adding an event.
##
## Needed when a stored log has been compacted: the header remembers how far the
## campaign got, and the surviving lines start later than that. Only ever raises
## it -- lowering would reissue numbers that are already spent.
func restore_last_seq(seq: int) -> void:
	_last_seq = maxi(_last_seq, seq)


## Replace the in-memory log with events that already carry sequence numbers.
##
## Used by the store when loading, and by a client applying a replay. Sequence
## numbers are preserved rather than reassigned, and the counter advances to the
## highest one seen so later appends cannot collide with a trimmed prefix.
func adopt_events(loaded: Array) -> void:
	events = loaded.duplicate(true)
	for event in events:
		_last_seq = maxi(_last_seq, AlternityNum.as_int(event.get("seq", 0)))


## Append an event that was issued elsewhere, keeping its sequence number.
##
## Returns false for one already present, so a replay that overlaps what the
## client already has is idempotent rather than duplicating the tail.
func adopt_event(event: Dictionary) -> bool:
	var seq := AlternityNum.as_int(event.get("seq", 0))
	for existing in events:
		if AlternityNum.as_int(existing.get("seq", 0)) == seq:
			return false
	events.append(event.duplicate(true))
	_last_seq = maxi(_last_seq, seq)
	return true


## Drop all but the newest `keep` events from memory.
##
## Safe because seats carry current state: AP totals, character bindings and GM
## designation all live on the seat, not in the log. Sequence numbers of what
## remains are untouched, so replay still lines up.
func trim_events(keep: int) -> int:
	if keep < 0 or events.size() <= keep:
		return 0
	var dropped := events.size() - keep
	events = events.slice(dropped)
	return dropped


## Award achievement points to a player seat.
## Works whether the player is currently connected or disconnected.
func award_ap(player_id: String, amount: int, reason: String = AP_REASON_COMPLETION) -> Dictionary:
	var safe_amount: int = max(0, amount)
	var seat := seat_for(player_id)
	var prev_ap: int = AlternityNum.as_int(seat.get("achievement_points", 0)) if not seat.is_empty() else 0
	var new_ap: int = prev_ap + safe_amount

	if not seat.is_empty():
		seat["achievement_points"] = new_ap
		var pending: Array = seat.get("pending_ap_awards", [])
		pending.append({
			"amount": safe_amount,
			"reason": reason,
			"at": int(Time.get_unix_time_from_system()),
		})
		seat["pending_ap_awards"] = pending

	return append_event(EVENT_AP_AWARD, player_id, {
		"amount": safe_amount,
		"reason": reason,
		"previous_ap": prev_ap,
		"new_ap": new_ap,
	})


## Award achievement points to all seats (e.g. all heroes completing an adventure).
##
## Refuses a reason that only makes sense for one person: a "Heroism Bonus" for
## everybody is not a heroism bonus. Returns an empty array in that case, so a
## caller that ignores the result awards nothing rather than the wrong thing.
func award_table_ap(amount: int, reason: String = AP_REASON_COMPLETION) -> Array:
	var events_out: Array = []
	if not AP_TABLE_REASONS.has(reason):
		push_warning("CampaignSession: %s is awarded to one player, not the table" % reason)
		return events_out
	for seat in seats:
		var pid := String(seat.get("player_id", ""))
		if not pid.is_empty() and not bool(seat.get("is_gm", false)):
			events_out.append(award_ap(pid, amount, reason))
	return events_out


## Manually set a seat's total achievement points.
func set_seat_ap(player_id: String, total_ap: int, reason: String = "GM Adjustment") -> Dictionary:
	var safe_ap: int = max(0, total_ap)
	var seat := seat_for(player_id)
	var prev_ap: int = AlternityNum.as_int(seat.get("achievement_points", 0)) if not seat.is_empty() else 0

	if not seat.is_empty():
		seat["achievement_points"] = safe_ap

	return append_event(EVENT_AP_SET, player_id, {
		"previous_ap": prev_ap,
		"new_ap": safe_ap,
		"reason": reason,
	})


func get_seat_ap(player_id: String) -> int:
	var seat := seat_for(player_id)
	return AlternityNum.as_int(seat.get("achievement_points", 0)) if not seat.is_empty() else 0


func get_pending_ap_awards(player_id: String) -> Array:
	var seat := seat_for(player_id)
	return seat.get("pending_ap_awards", []).duplicate(true) if not seat.is_empty() else []


func claim_pending_ap_awards(player_id: String) -> Array:
	var seat := seat_for(player_id)
	if seat.is_empty():
		return []
	var pending: Array = seat.get("pending_ap_awards", []).duplicate(true)
	seat["pending_ap_awards"] = []
	return pending


func set_campaign_optional_rule(rule_id: String, enabled: bool) -> void:
	optional_rules[rule_id] = enabled


func get_campaign_optional_rules() -> Dictionary:
	return optional_rules.duplicate(true)


# --- Persistence -----------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"format_version": format_version,
		"campaign_id": campaign_id,
		"display_name": display_name,
		"created_at": created_at,
		"seats": seats.duplicate(true),
		"events": events.duplicate(true),
		"optional_rules": optional_rules.duplicate(true),
		"check_counts": check_counts.duplicate(true),
	}


static func from_dict(data: Dictionary) -> CampaignSession:
	var session := CampaignSession.new()
	session.format_version = AlternityNum.as_int(data.get("format_version", 1), 1)
	session.campaign_id = String(data.get("campaign_id", new_id()))
	session.display_name = String(data.get("display_name", "New Campaign"))
	session.created_at = AlternityNum.as_int(data.get("created_at", 0))

	var seats_data = data.get("seats", [])
	session.seats = seats_data.duplicate(true) if typeof(seats_data) == TYPE_ARRAY else []

	var events_data = data.get("events", [])
	session.adopt_events(events_data if typeof(events_data) == TYPE_ARRAY else [])

	var rules_data = data.get("optional_rules", {})
	session.optional_rules = rules_data.duplicate(true) if typeof(rules_data) == TYPE_DICTIONARY else {}

	var counts = data.get("check_counts", {})
	session.check_counts = counts.duplicate(true) if typeof(counts) == TYPE_DICTIONARY else {}
	return session
