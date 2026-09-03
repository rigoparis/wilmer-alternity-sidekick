class_name TableSession
extends RefCounted
##
## Everything a player device holds while it is at somebody's table.
##
## Pulled out of a screen on purpose. A player at a table is still playing their
## character -- editing skills, spending points, marking damage -- so the table
## cannot be a screen they have to leave the sheet to look at. It is a tab on the
## sheet, and the connection has to outlive whatever tab is showing.
##
## Two ownership rules decide what lives here:
##
##   * The GM's device owns the campaign. Seats, the log and its sequence
##     numbers are all assigned there; this only receives them.
##   * This device owns the character. Achievement points awarded by the GM
##     arrive as events and are applied here, to the hero committed to this
##     campaign -- the GM never writes to a character file they cannot see.
##
## The event list here is a local copy for display, not a second authority. It is
## deliberately never written to a campaign file: two devices with two campaign
## documents is exactly the drift the one-owner rule exists to prevent.
##

## Anything the table tab renders has changed.
signal changed

## The GM awarded points, and they have been applied to the committed hero.
signal ap_applied(amount: int, reason: String)

## The GM asked for a check, or answered one.
signal check_arrived(check: SkillCheck)

## Something went wrong that a player should see.
signal trouble(message: String)

## The player asked to leave.
##
## A signal rather than something the tab does itself: leaving means taking the
## sheet down and putting the character list back, which only the shell can do.
signal leave_requested

## How much of the feed to keep. The GM's copy is the one that has to be
## complete; this is what a player scrolls through mid-session.
const FEED_LENGTH := 60

var transport: EnetTransport
var identity: PlayerIdentity
var store: CharacterStore
var rules

## The hero this device committed to this campaign. Owned here, and the only
## copy anybody writes to.
var doc: CharacterDoc

var campaign_name: String = ""

## Events this device has been sent, oldest first. Display only.
var events: Array = []


func _init(
	p_transport: EnetTransport,
	p_identity: PlayerIdentity,
	p_store: CharacterStore,
	p_rules,
	p_campaign_name: String = ""
) -> void:
	transport = p_transport
	identity = p_identity
	store = p_store
	rules = p_rules
	campaign_name = p_campaign_name

	transport.event_received.connect(_on_event)
	transport.events_replayed.connect(_on_replay)
	transport.check_ruled.connect(_on_check_ruled)
	transport.transport_error.connect(func(message: String): trouble.emit(message))


func campaign_id() -> String:
	return transport.campaign_id() if transport != null else ""


func is_connected_to_table() -> bool:
	return transport != null and transport.is_connected_to_table()


## Deliver whatever has arrived. Driven by whoever owns this -- the shell -- so
## the connection survives the player moving between tabs.
func poll() -> void:
	if transport != null:
		transport.poll()


# --- The committed character -----------------------------------------------

## Bind a hero to this table and tell the GM about it.
##
## Brings the character into line with the campaign's optional rules first.
## Several of those change ability limits and the starting skill budget, so a
## hero built under different ones has wrong numbers for this table rather than
## merely different preferences.
##
## Returns the rules that were changed, so a screen can say what it did.
func commit(character_doc: CharacterDoc) -> Dictionary:
	doc = character_doc
	var applied := _apply_campaign_rules()
	push_character()
	changed.emit()
	return applied


func _apply_campaign_rules() -> Dictionary:
	var applied := {}
	if doc == null or rules == null or transport == null:
		return applied
	var table_rules := transport.campaign_optional_rules()
	if table_rules.is_empty():
		return applied

	doc.apply(CharacterDoc.ALL, func(character):
		for rule_id in table_rules:
			var wanted := bool(table_rules[rule_id])
			var current: Dictionary = character.get("optional_rules", {})
			if bool(current.get(rule_id, false)) == wanted:
				continue
			rules.set_optional_rule(character, String(rule_id), wanted)
			applied[rule_id] = wanted)

	if not applied.is_empty() and store != null:
		store.save(doc)
	return applied


## Send the GM the current state of the committed hero.
##
## Snapshot on change: called on commit and after anything here edits the
## character. The GM only ever reads it.
func push_character() -> void:
	if doc == null or transport == null:
		return
	transport.send_character(CharacterSnapshot.of_doc(doc))


# --- Talking to the table --------------------------------------------------

func send_chat(text: String, private_to_gm: bool = false) -> void:
	if transport == null or text.strip_edges().is_empty():
		return
	# A player device is never told the seat list, so it addresses the GM by a
	# sentinel and the host resolves it to the real seat.
	transport.send_chat(text.strip_edges(), EnetTransport.TO_GM if private_to_gm else "")


func leave() -> void:
	if transport != null:
		transport.leave()
		transport = null


# --- Incoming --------------------------------------------------------------

func _on_event(event: Dictionary) -> void:
	_absorb(event)
	_remember(event)
	changed.emit()


func _on_replay(replayed: Array) -> void:
	for event in replayed:
		_absorb(event)
		_remember(event)
	changed.emit()


func _on_check_ruled(data: Dictionary) -> void:
	check_arrived.emit(SkillCheck.from_dict(data))


func _remember(event: Dictionary) -> void:
	events.append(event)
	if events.size() > FEED_LENGTH:
		events = events.slice(events.size() - FEED_LENGTH)
	# Remember how far this device's copy got, so a reconnect asks for the gap
	# rather than the whole campaign.
	identity.note_seq(campaign_id(), AlternityNum.as_int(event.get("seq", 0)))


## Apply anything in an event that this device owns the consequences of.
##
## Only achievement points so far, and they land on the committed hero without
## being asked about. A player at a table is playing one character -- the one
## they committed -- so a picker asking which hero should receive the award is
## a question with one possible answer.
func _absorb(event: Dictionary) -> void:
	if String(event.get("kind", "")) != CampaignSession.EVENT_AP_AWARD:
		return
	if String(event.get("player_id", "")) != transport.local_player_id():
		return

	var payload: Dictionary = event.get("payload", {}) if typeof(event.get("payload")) == TYPE_DICTIONARY else {}
	var amount := AlternityNum.as_int(payload.get("amount", 0))
	var reason := String(payload.get("reason", ""))
	if amount <= 0:
		return

	if doc == null:
		# Nothing committed yet. The GM's seat ledger still records the award, so
		# nothing is lost -- it lands when the player commits and reconnects.
		trouble.emit("The GM awarded %d AP, but no hero is committed to this table yet." % amount)
		return

	doc.apply(CharacterDoc.ALL, func(character):
		character["achievement_points"] = AlternityNum.as_int(character.get("achievement_points", 0)) + amount)
	if store != null:
		store.save(doc)
	# The GM's roster shows the hero's numbers, and achievement points change
	# them, so the copy the GM holds has to follow.
	push_character()
	ap_applied.emit(amount, reason)


## The most recent events, newest first, ready to render.
func recent() -> Array:
	var out := events.duplicate()
	out.reverse()
	return out


## One line of table log.
##
## A player device holds no seat list, so it cannot turn a player_id into a name.
## It says "you" for its own and leaves the rest unnamed rather than printing a
## 32-character id at somebody.
func describe(event: Dictionary) -> String:
	var payload: Dictionary = event.get("payload", {}) if typeof(event.get("payload")) == TYPE_DICTIONARY else {}
	var mine: bool = transport != null and String(event.get("player_id", "")) == transport.local_player_id()
	var who := "You" if mine else "Someone"

	match String(event.get("kind", "")):
		CampaignSession.EVENT_ROLL:
			var check_data = payload.get("check", {})
			if typeof(check_data) == TYPE_DICTIONARY and not check_data.is_empty():
				var check := SkillCheck.from_dict(check_data)
				if not check.degree().is_empty():
					return "%s rolled %s: %s" % [who, check.describe(), check.degree()]
			var label := String(payload.get("label", ""))
			var what := label if not label.is_empty() else String(payload.get("notation", ""))
			return "%s rolled %s: %d" % [who, what, AlternityNum.as_int(payload.get("total", 0))]
		CampaignSession.EVENT_CHAT:
			var private_line := not String(payload.get("to", "")).is_empty()
			return "%s%s: %s" % [who, " (private)" if private_line else "", String(payload.get("text", ""))]
		CampaignSession.EVENT_AP_AWARD:
			if not mine:
				return "Someone was awarded achievement points"
			return "You were awarded %d AP -- %s" % [
				AlternityNum.as_int(payload.get("amount", 0)),
				String(payload.get("reason", "")),
			]
		CampaignSession.EVENT_AP_SET:
			return "Your achievement points were set to %d" % AlternityNum.as_int(payload.get("new_ap", 0)) if mine else "A total was adjusted"
		CampaignSession.EVENT_CHECK:
			return "The GM called for %s" % SkillCheck.from_dict(payload).describe()
		CampaignSession.EVENT_JOIN:
			return "You joined" if mine else "Someone joined"
		CampaignSession.EVENT_NOTE:
			return String(payload.get("text", ""))
	return String(event.get("kind", ""))
