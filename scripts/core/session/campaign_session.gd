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

## AP Award reasons based on core Alternity GM guidelines
const AP_REASON_COMPLETION := "Adventure Completion"
const AP_REASON_ROLEPLAYING := "Roleplaying Bonus"
const AP_REASON_HEROISM := "Heroism Bonus"
const AP_REASON_CUSTOM := "Custom Award"

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
## `character_file` binds the seat to a saved character; it can be set later via
## bind_character() when the player has not made one yet.
func add_seat(player_name: String, character_file: String = "") -> String:
	var player_id := new_id()
	seats.append({
		"player_id": player_id,
		"player_name": player_name,
		"character_file": character_file,
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


func bind_character(player_id: String, character_file: String) -> bool:
	var seat := seat_for(player_id)
	if seat.is_empty():
		return false
	seat["character_file"] = character_file
	return true


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


# --- Event log -------------------------------------------------------------

## Append one event. Stamps time and a monotonic sequence number so the log
## stays ordered even when two events share a timestamp.
func append_event(kind: String, player_id: String, payload: Dictionary) -> Dictionary:
	var event := {
		"seq": events.size() + 1,
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
func award_table_ap(amount: int, reason: String = AP_REASON_COMPLETION) -> Array:
	var events_out: Array = []
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
	session.events = events_data.duplicate(true) if typeof(events_data) == TYPE_ARRAY else []

	var rules_data = data.get("optional_rules", {})
	session.optional_rules = rules_data.duplicate(true) if typeof(rules_data) == TYPE_DICTIONARY else {}
	return session
