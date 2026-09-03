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

## The fight changed. The whole round arrives each time, so there is nothing to
## reconcile -- this device simply holds the newest copy the GM sent.
signal round_changed

## The round is waiting on this device's action check.
signal action_check_wanted

## An attack has landed on this device and is waiting to be resolved.
##
## Raised rather than resolved here: rolling the armor is a trip to the dice
## tray, which is a screen's business. This object only holds the attack until
## somebody deals with it.
signal attack_arrived(attack: CombatAttack)

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

## The fight in progress, as the GM last sent it, or null when there is none.
##
## Named active_round rather than round because a class member called `round`
## shadows the global round() function, which parses and then confuses whoever
## next writes arithmetic in this file.
##
## Read-only here. The GM's device owns the round and assigns every phase; this
## is a copy to look at, exactly like the event log.
var active_round: ActionRound

## The round this device has already rolled an action check for, so a resend of
## the same round does not ask twice.
var _checked_round: String = ""

## Attacks sent here that nobody has resolved yet, oldest first.
##
## A queue rather than one attack: two enemies can fire in the same phase, and
## the second must not quietly replace the first.
var incoming_attacks: Array = []


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
	transport.round_updated.connect(_on_round_updated)
	transport.attack_received.connect(_on_attack_received)
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


func _on_round_updated(data: Dictionary) -> void:
	if data.is_empty():
		# The fight is over.
		active_round = null
		_checked_round = ""
		round_changed.emit()
		return

	active_round = ActionRound.from_dict(data)
	round_changed.emit()

	# Ask for an action check only when this round is actually waiting on ours,
	# and only once per round -- the GM resends the whole round on every change,
	# so a naive check would prompt again after every phase.
	if _checked_round == active_round.round_id:
		return
	if not owes_action_check():
		return
	_checked_round = active_round.round_id
	action_check_wanted.emit()


# --- Attacks ---------------------------------------------------------------

func _on_attack_received(data: Dictionary) -> void:
	var attack := CombatAttack.from_dict(data)
	incoming_attacks.append(attack)
	attack_arrived.emit(attack)
	changed.emit()


## The attack waiting at the front of the queue, or null.
func next_attack() -> CombatAttack:
	return incoming_attacks[0] if not incoming_attacks.is_empty() else null


## Apply an attack to the committed hero.
##
## This device's half of the round trip, and the half that writes to a character
## file. The GM rolled the hit and the damage; everything from here is the
## character's own -- their armor, already rolled by the caller, their toughness,
## and their damage tracks.
##
## `absorbed` is the best armor layer's roll, not the sum of them, because layers
## do not add up.
##
## Returns what apply_damage returned. Applying and reporting are separate calls
## because an Amazing hit puts an endurance check between them, and that check is
## rolled against the character as the hit left them.
func apply_attack(attack: CombatAttack, absorbed: int) -> Dictionary:
	incoming_attacks.erase(attack)
	if doc == null or rules == null or not attack.hits():
		return {}

	# Through apply() rather than around it: a lambda captures a local by value,
	# so an outcome assigned inside one would be lost on the way out, and the
	# damage would land on the sheet while the report said nothing happened.
	var toughness: String = rules.combat.toughness_of(doc.raw())
	var outcome: Dictionary = doc.apply([CharacterDoc.DAMAGE], func(character):
		return rules.apply_damage(
			character,
			attack.damage,
			attack.track_name(),
			absorbed,
			attack.firepower,
			toughness
		))
	if store != null:
		store.save(doc)
	# The GM's roster reads the character they hold, so it has to follow the
	# damage or the badge will say Unhurt at somebody who is bleeding.
	push_character()
	changed.emit()
	return outcome


## Tell the GM what the attack cost, and close it.
##
## What goes back is an outcome, never the character: the GM needs to know they
## put somebody down, not what is on their sheet.
func report_attack(attack: CombatAttack, absorbed: int, outcome: Dictionary, knocked_out: bool = false) -> void:
	var down := knocked_out
	if doc != null and rules != null:
		down = down or rules.combat.is_knocked_out(doc.raw())
	attack.resolve({
		"primary_damage": AlternityNum.as_int(outcome.get("primary_damage", 0)),
		"secondary_stun": AlternityNum.as_int(outcome.get("secondary_stun", 0)),
		"secondary_wound": AlternityNum.as_int(outcome.get("secondary_wound", 0)),
		"absorbed": absorbed,
		"negated": bool(outcome.get("negated", false)),
		"damage_type": String(outcome.get("damage_type", attack.track_name())),
		"knocked_out": down,
		"condition": rules.combat.condition_of(doc.raw()) if doc != null and rules != null else "",
	})
	if transport != null:
		transport.send_attack_result(attack.to_dict())
	changed.emit()


## Whether an Amazing hit forces this character to check for consciousness.
##
## Asked before the damage is applied, because whether the firepower rule
## degraded it is one of the two exemptions and that has to be read off the
## attack rather than off what it did.
func knockout_check_for(attack: CombatAttack) -> Dictionary:
	if doc == null or rules == null or not attack.hits():
		return {"required": false}
	var degraded: bool = rules.character_degraded_damage_grade(
		doc.raw(), attack.track_name(), attack.firepower, rules.combat.toughness_of(doc.raw())
	) != attack.track_name()
	return rules.amazing_damage_knockout(doc.raw(), attack.degree, degraded)


## Whether the round is waiting on this device's action check.
func owes_action_check() -> bool:
	if active_round == null or transport == null:
		return false
	return active_round.awaiting_checks().has(transport.local_player_id())


## Where this device stands in the fight, or {} when it is not in one.
func my_combatant() -> Dictionary:
	if active_round == null or transport == null:
		return {}
	return active_round.combatant(transport.local_player_id())


## Whether it is this device's turn in the phase now running.
func acting_now() -> bool:
	if active_round == null or transport == null:
		return false
	for entry in active_round.acting_now():
		if String(entry.get("id", "")) == transport.local_player_id():
			return true
	return false


## Send the action check this device just rolled.
func send_action_check(check: SkillCheck) -> void:
	if transport == null or check == null:
		return
	transport.send_action_check({
		"round_id": active_round.round_id if active_round != null else "",
		"degree": check.degree(),
		"check_score": check.ordinary,
		"roll": AlternityNum.as_int(check.result.get("total", 0)),
		"critical": bool(check.result.get("is_critical_failure", false)),
	})


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
