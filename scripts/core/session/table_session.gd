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

## A buff or beneficial skill (e.g. Fortitude) arrived and was applied.
signal buff_applied(buff: Dictionary)

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

## An attack on this device has been resolved (damage applied or parried).
signal attack_resolved(attack: CombatAttack)

## The scene ended and this character's stun has cleared.
##
## Carries how much was cleared, so a screen can say what happened rather than a
## damage track silently emptying itself.
signal scene_ended(stun_cleared: int)

## Something went wrong that a player should see.
signal trouble(message: String)

## The player asked to leave.
##
## A signal rather than something the tab does itself: leaving means taking the
## sheet down and putting the character list back, which only the shell can do.
@warning_ignore("unused_signal")
signal leave_requested

## An incoming attack was cancelled/dismissed by the GM.
signal attack_cancelled(attack_id: String)

## How much of the feed to keep. The GM's copy is the one that has to be
## complete; this is what a player scrolls through mid-session.
const FEED_LENGTH := 60
const RECONNECT_MAX_DELAY_MS := 10_000

var transport: EnetTransport
var identity: PlayerIdentity
var store: CharacterStore
var rules

## The hero this device committed to this campaign. Owned here, and the only
var doc: CharacterDoc:
	set(value):
		if doc != value:
			_staged_attacks.clear()
			_simulated_character_state.clear()
		doc = value
		_recover_staged_attacks()


func _character_key() -> String:
	if doc == null:
		return ""
	var key := String(doc.raw().get("combat_character_key", ""))
	if key.is_empty():
		# Keep the legacy binding when adopting an existing character, but store
		# it in the document so a later name/file rename cannot strand its journal.
		key = doc.source_file if not doc.source_file.is_empty() else doc.get_hero_name()
		if key.is_empty():
			key = CampaignSession.new_id()
		doc.apply([CharacterDoc.META], func(character): character["combat_character_key"] = key)
	return key

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

## Checks the GM called for that nobody has resolved yet, oldest first.
var incoming_checks: Array = []

## Attacks applied during an active combat phase whose damage is staged until phase end.
var _staged_attacks: Array = []
var _simulated_character_state: Dictionary = {}
var _reconnect_due_msec: int = 0
var _reconnect_attempts: int = 0



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

	# A GM-owned NPC resolves locally without a network connection.
	if transport == null:
		return
	transport.event_received.connect(_on_event)
	transport.events_replayed.connect(_on_replay)
	transport.check_ruled.connect(_on_check_ruled)
	transport.round_updated.connect(_on_round_updated)
	transport.roster_changed.connect(_on_roster_changed)
	transport.attack_received.connect(_on_attack_received)
	transport.pending_work_received.connect(_on_pending_work_received)
	transport.player_connected.connect(_on_transport_connected)
	transport.phase_commit_requested.connect(_on_phase_commit_requested)
	transport.attack_cancelled.connect(_on_attack_cancelled)
	transport.transport_error.connect(_on_transport_error)


func campaign_id() -> String:
	if transport != null:
		var tid := transport.campaign_id()
		if not tid.is_empty():
			return tid
	if identity != null:
		var act := identity.active_table()
		var cid := String(act.get("campaign_id", ""))
		if not cid.is_empty():
			return cid
	return ""


func _on_roster_changed() -> void:
	changed.emit()


func is_connected_to_table() -> bool:
	return transport != null and transport.is_connected_to_table()


## Deliver whatever has arrived. Driven by whoever owns this -- the shell -- so
## the connection survives the player moving between tabs.
func poll() -> void:
	if transport == null:
		return
	transport.poll()
	if _reconnect_due_msec <= 0 or Time.get_ticks_msec() < _reconnect_due_msec:
		return
	_reconnect_due_msec = 0
	if transport.reconnect() != OK:
		_schedule_reconnect()


# --- The committed character -----------------------------------------------

## Reattach the local hero during cold-start recovery without sending before
## the transport has completed its handshake. _on_resumed_table_connected in
## the shell calls commit() once the GM has supplied the campaign rules.
func restore_character(character_doc: CharacterDoc) -> void:
	doc = character_doc


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


## Cast a buff or beneficial skill (e.g. Fortitude) on a table ally.
func send_buff(target_player_id: String, buff: Dictionary) -> void:
	if transport == null:
		return
	var my_name := doc.get_hero_name() if doc != null else "Character"
	buff["caster_name"] = my_name
	transport.send_buff(target_player_id, buff)


## List of allies/other players seated at the table available for targeting.
func table_allies() -> Array:
	var allies: Array = []
	var my_id := transport.local_player_id() if transport != null else ""
	if transport != null:
		for s in transport.table_seats():
			var pid := String(s.get("player_id", ""))
			if pid == my_id or bool(s.get("is_gm", false)):
				continue
			var char_name := String(s.get("character_name", "")).strip_edges()
			var p_name := String(s.get("player_name", "Ally")).strip_edges()
			var display := char_name if not char_name.is_empty() else p_name
			if not char_name.is_empty() and char_name != p_name:
				display = "%s (%s)" % [char_name, p_name]
			allies.append({
				"id": pid,
				"name": display,
			})
	if active_round != null:
		for c in active_round.combatants:
			var cid := String(c.get("id", ""))
			if cid == my_id:
				continue
			var already := false
			for a in allies:
				if String(a.get("id", "")) == cid:
					already = true
					break
			if not already:
				allies.append({
					"id": cid,
					"name": String(c.get("name", "Combatant")),
				})
	return allies


func leave() -> void:
	if transport != null:
		transport.leave()
		transport = null
	_reconnect_due_msec = 0
	_reconnect_attempts = 0


# --- Incoming --------------------------------------------------------------

func _on_transport_error(message: String) -> void:
	trouble.emit(message)
	_schedule_reconnect()
	changed.emit()


func _schedule_reconnect() -> void:
	if transport == null or not transport.needs_reconnect() or _reconnect_due_msec > 0:
		return
	var delay := mini(1_000 * (1 << mini(_reconnect_attempts, 3)), RECONNECT_MAX_DELAY_MS)
	_reconnect_attempts += 1
	_reconnect_due_msec = Time.get_ticks_msec() + delay


func _on_transport_connected(player_id: String, is_reconnect: bool) -> void:
	_reconnect_due_msec = 0
	_reconnect_attempts = 0
	if identity != null and transport != null:
		identity.remember(campaign_id(), player_id, transport.last_seen_seq(), campaign_name)
	_recover_staged_attacks()
	if is_reconnect:
		changed.emit()

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
	var check := SkillCheck.from_dict(data)
	if check.origin == SkillCheck.ORIGIN_GM:
		var my_id := transport.local_player_id() if transport != null else ""
		if check.player_id.is_empty() or check.player_id == my_id:
			var exists := false
			for c in incoming_checks:
				if (c as SkillCheck).check_id == check.check_id:
					exists = true
					break
			if not exists:
				incoming_checks.append(check)
	check_arrived.emit(check)
	changed.emit()


## Dismiss a check called by the GM without rolling it.
func dismiss_called_check(check: SkillCheck) -> void:
	if check == null:
		return
	for i in incoming_checks.size():
		if (incoming_checks[i] as SkillCheck).check_id == check.check_id:
			incoming_checks.remove_at(i)
			if transport != null:
				transport.dismiss_check(check.check_id)
			changed.emit()
			return


## Clear a called check that has been rolled.
func resolve_called_check(check: SkillCheck) -> void:
	dismiss_called_check(check)


func _on_round_updated(data: Dictionary) -> void:
	if data.is_empty():
		# The fight is over.
		commit_staged_damage()
		active_round = null
		_checked_round = ""
		round_changed.emit()
		changed.emit()
		return

	var incoming_round := ActionRound.from_dict(data)
	if active_round != null:
		if active_round.round_id != incoming_round.round_id or active_round.phase() != incoming_round.phase() or active_round.state != incoming_round.state:
			commit_staged_damage()
	active_round = incoming_round
	round_changed.emit()
	changed.emit()

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
	if identity != null and identity.is_attack_cancelled(campaign_id(), attack.attack_id):
		return
	var progress := identity.attack_progress(campaign_id(), attack.attack_id) if identity != null else {}
	var resolved = progress.get("resolved", {}) if typeof(progress) == TYPE_DICTIONARY else {}
	if typeof(resolved) == TYPE_DICTIONARY and not resolved.is_empty():
		# The GM did not receive the previous result. Re-send the settled fact;
		# never ask the player to absorb and apply the same damage again.
		transport.send_attack_result(resolved)
		return
	for existing in incoming_attacks:
		if (existing as CombatAttack).attack_id == attack.attack_id:
			return
	incoming_attacks.append(attack)
	attack_arrived.emit(attack)
	changed.emit()


## The attack waiting at the front of the queue, or null.
func next_attack() -> CombatAttack:
	return incoming_attacks[0] if not incoming_attacks.is_empty() else null


## Whether attacks should stage damage until the end of the phase.
## In an active combat phase, damage applies simultaneously at phase end per PHB p. 50.
func is_phase_staging_active(attack: CombatAttack) -> bool:
	if active_round == null or active_round.state != ActionRound.STATE_ACTIVE:
		return false
	if attack == null or attack.phase.is_empty():
		return false
	return attack.round_id == active_round.round_id and attack.phase == active_round.phase()


## Apply an attack to the committed hero.
##
## This device's half of the round trip, and the half that writes to a character
## file. The GM rolled the hit and the damage; everything from here is the
## character's own -- their armor, already rolled by the caller, their toughness,
## and their damage tracks.
##
func _on_attack_cancelled(attack_id: String) -> void:
	for i in range(incoming_attacks.size() - 1, -1, -1):
		if incoming_attacks[i].attack_id == attack_id:
			incoming_attacks.remove_at(i)
	for i in range(_staged_attacks.size() - 1, -1, -1):
		var atk: CombatAttack = _staged_attacks[i].get("attack")
		if atk != null and atk.attack_id == attack_id:
			_staged_attacks.remove_at(i)
	_recalculate_simulated_damage()
	if identity != null:
		identity.remember_attack_cancelled(campaign_id(), attack_id)
	attack_cancelled.emit(attack_id)
	changed.emit()


func _recalculate_simulated_damage() -> void:
	if doc == null or rules == null or _staged_attacks.is_empty():
		_simulated_character_state.clear()
		return
	_simulated_character_state = doc.raw().duplicate(true)
	for staged in _staged_attacks:
		var atk: CombatAttack = staged.get("attack")
		var abs_val: int = AlternityNum.as_int(staged.get("absorbed", 0))
		var parried_val: bool = bool(staged.get("parried", false))
		if atk != null and atk.hits() and not parried_val:
			var toughness: String = rules.combat.toughness_of(_simulated_character_state)
			rules.apply_damage(
				_simulated_character_state,
				atk.damage,
				atk.track_name(),
				abs_val,
				atk.firepower,
				toughness
			)


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
func apply_attack(attack: CombatAttack, absorbed: int, parried: bool = false) -> Dictionary:
	incoming_attacks.erase(attack)
	var cid := campaign_id()
	if identity != null and identity.is_attack_cancelled(cid, attack.attack_id):
		changed.emit()
		return {}
	var progress := identity.attack_progress(cid, attack.attack_id) if identity != null else {}
	if not progress.is_empty():
		changed.emit()
		var stored = progress.get("outcome", {})
		return stored.duplicate(true) if typeof(stored) == TYPE_DICTIONARY else {}
	var char_key := _character_key()
	var my_pid := transport.local_player_id() if transport != null else ""
	if doc == null or rules == null or not attack.hits() or parried:
		# A parry that beat the attack stops it outright: no primary damage, so
		# there is nothing to apply and nothing to save.
		if identity != null:
			identity.remember_attack_applied(cid, attack.to_dict(), absorbed, {}, parried, char_key, my_pid)
			identity.remember_attack_committed(cid, attack.attack_id)
		changed.emit()
		return {}

	if is_phase_staging_active(attack):
		if _simulated_character_state.is_empty():
			_simulated_character_state = doc.raw().duplicate(true)
		var toughness: String = rules.combat.toughness_of(_simulated_character_state)
		var outcome: Dictionary = rules.apply_damage(
			_simulated_character_state,
			attack.damage,
			attack.track_name(),
			absorbed,
			attack.firepower,
			toughness
		)
		_staged_attacks.append({
			"attack": attack,
			"absorbed": absorbed,
			"outcome": outcome,
			"parried": parried,
		})
		if identity != null:
			identity.remember_attack_applied(cid, attack.to_dict(), absorbed, outcome, parried, char_key, my_pid)
		changed.emit()
		return outcome

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
	if identity != null:
		identity.remember_attack_applied(cid, attack.to_dict(), absorbed, outcome, parried, char_key, my_pid)
		identity.remember_attack_committed(cid, attack.attack_id)
	# The GM's roster reads the character they hold, so it has to follow the
	# damage or the badge will say Unhurt at somebody who is bleeding.
	push_character()
	changed.emit()
	return outcome


## Commit all staged damage from the phase to the character document and save.
func commit_staged_damage() -> Dictionary:
	if _staged_attacks.is_empty():
		return {"ok": true, "committed_ids": []}
	if doc == null or rules == null:
		return {"ok": false, "committed_ids": [], "reason": "Character unavailable"}
	if identity != null and store == null:
		return {"ok": false, "committed_ids": [], "reason": "Character storage unavailable"}
	var committed_attack_ids: Array = []
	for item in _staged_attacks:
		var attack: CombatAttack = item.get("attack")
		var absorbed: int = AlternityNum.as_int(item.get("absorbed", 0))
		var parried: bool = bool(item.get("parried", false))
		if attack != null:
			if attack.hits() and not parried and not doc.has_applied_attack(attack.attack_id):
				var toughness: String = rules.combat.toughness_of(doc.raw())
				doc.apply([CharacterDoc.DAMAGE], func(character):
					var res = rules.apply_damage(
						character,
						attack.damage,
						attack.track_name(),
						absorbed,
						attack.firepower,
						toughness
					)
					var applied: Array = character.get("applied_attacks", [])
					if not applied.has(attack.attack_id):
						applied.append(attack.attack_id)
						character["applied_attacks"] = applied
					return res
				)
			committed_attack_ids.append(attack.attack_id)
	if store != null:
		var save_res: Dictionary = store.save(doc)
		if not bool(save_res.get("ok", false)):
			return {"ok": false, "committed_ids": [], "reason": String(save_res.get("reason", "Save failed"))}
	_staged_attacks.clear()
	_simulated_character_state.clear()
	if identity != null:
		var cid := campaign_id()
		if not cid.is_empty():
			for attack_id in committed_attack_ids:
				identity.remember_attack_committed(cid, attack_id)
	push_character()
	changed.emit()
	return {"ok": true, "committed_ids": committed_attack_ids}


func _recover_staged_attacks() -> void:
	if identity == null or doc == null or rules == null:
		return
	var cid := campaign_id()
	if cid.is_empty():
		return
	var char_key := _character_key()
	var uncommitted: Array = identity.uncommitted_attacks(cid, char_key)
	if uncommitted.is_empty():
		return
	var added := false
	for item in uncommitted:
		var attack_dict: Dictionary = item.get("attack", {})
		var attack := CombatAttack.from_dict(attack_dict)
		var attack_id := attack.attack_id
		if attack_id.is_empty() or identity.is_attack_cancelled(cid, attack_id):
			continue
		if doc.has_applied_attack(attack_id):
			identity.remember_attack_committed(cid, attack_id)
			continue
		var already := false
		for existing in _staged_attacks:
			var ea: CombatAttack = existing.get("attack")
			if ea != null and ea.attack_id == attack_id:
				already = true
				break
		if not already:
			_staged_attacks.append({
				"attack": attack,
				"absorbed": AlternityNum.as_int(item.get("absorbed", 0)),
				"outcome": item.get("outcome", {}),
				"parried": bool(item.get("parried", false)),
			})
			added = true
	if added or (not _staged_attacks.is_empty() and _simulated_character_state.is_empty()):
		_recalculate_simulated_damage()
		changed.emit()


func has_staged_damage() -> bool:
	return not _staged_attacks.is_empty()


func staged_attacks() -> Array:
	return _staged_attacks.duplicate(true)



## Tell the GM what the attack cost, and close it.
##
## What goes back is an outcome, never the character: the GM needs to know they
## put somebody down, not what is on their sheet.
func report_attack(
	attack: CombatAttack,
	absorbed: int,
	outcome: Dictionary,
	knocked_out: bool = false,
	parried: bool = false
) -> void:
	var progress := identity.attack_progress(campaign_id(), attack.attack_id) if identity != null else {}
	if not progress.is_empty():
		absorbed = AlternityNum.as_int(progress.get("absorbed", absorbed))
		parried = bool(progress.get("parried", parried))
	var down := knocked_out or bool(outcome.get("knocked_out", false))
	if doc != null and rules != null:
		var char_state := _simulated_character_state if not _simulated_character_state.is_empty() else doc.raw()
		down = down or rules.combat.is_knocked_out(char_state)
	attack.details["armor_rule"] = "Roll every armor layer; only the highest absorption applies."
	attack.resolve({
		"parried": parried,
		"primary_damage": AlternityNum.as_int(outcome.get("primary_damage", 0)),
		"secondary_stun": AlternityNum.as_int(outcome.get("secondary_stun", 0)),
		"secondary_wound": AlternityNum.as_int(outcome.get("secondary_wound", 0)),
		"absorbed": absorbed,
		"negated": bool(outcome.get("negated", false)),
		"damage_type": String(outcome.get("damage_type", attack.track_name())),
		"knocked_out": down,
		"endurance_failed": bool(outcome.get("endurance_failed", false)),
		"condition": rules.combat.condition_of(doc.raw()) if doc != null and rules != null else "",
	})
	if identity != null:
		identity.remember_attack_resolved(campaign_id(), attack.to_dict())
	if transport != null:
		transport.send_attack_result(attack.to_dict())
	attack_resolved.emit(attack)
	changed.emit()



func _on_pending_work_received(_checks: Array, attacks: Array) -> void:
	var ids: Array = []
	for attack in attacks:
		if typeof(attack) == TYPE_DICTIONARY:
			ids.append(String(attack.get("attack_id", "")))
	# Clean up incoming attacks dismissed by GM
	for i in range(incoming_attacks.size() - 1, -1, -1):
		var atk = incoming_attacks[i]
		if not ids.has(atk.attack_id):
			incoming_attacks.remove_at(i)
			attack_cancelled.emit(atk.attack_id)
	# Clean up staged attacks dismissed by GM
	var staged_changed := false
	for i in range(_staged_attacks.size() - 1, -1, -1):
		var satk: CombatAttack = _staged_attacks[i].get("attack")
		if satk != null and not ids.has(satk.attack_id):
			_staged_attacks.remove_at(i)
			if identity != null:
				identity.remember_attack_cancelled(campaign_id(), satk.attack_id)
			attack_cancelled.emit(satk.attack_id)
			staged_changed = true
	if staged_changed:
		_recalculate_simulated_damage()
	if identity != null:
		identity.reconcile_attacks(campaign_id(), ids)
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


## Tell the GM this character is dodging, and how well.
##
## Sent rather than applied: the dodge is a step penalty on every attack against
## them for the rest of the round, and the GM's device is the one rolling those
## attacks. The local copy of the round is updated too, so the board says so
## without waiting for the GM to send it back.
func send_dodge(check: SkillCheck) -> void:
	if transport == null or check == null:
		return
	var degree := check.degree()
	if active_round != null:
		active_round.declare_dodge(transport.local_player_id(), degree)
		round_changed.emit()
	transport.send_defence({
		"round_id": active_round.round_id if active_round != null else "",
		"kind": "dodge",
		"degree": degree,
		"roll": AlternityNum.as_int(check.result.get("total", 0)),
	})


## Tell the GM that this player is postponing their action in this phase.
func send_postpone(phase_id: String) -> void:
	var my_id := transport.local_player_id() if transport != null else ""
	var round_id := active_round.round_id if active_round != null else ""
	var command_id := CampaignSession.new_id()
	if active_round != null and not my_id.is_empty():
		active_round.postpone(my_id, phase_id)
		round_changed.emit()
	if transport != null:
		transport.send_postpone(round_id, phase_id, command_id)
	changed.emit()


func _on_phase_commit_requested(round_id: String, phase_id: String, operation_id: String = "", expected_attack_ids: Array = []) -> void:
	if active_round != null and (active_round.round_id != round_id or active_round.phase() != phase_id):
		return
	var commit_res := commit_staged_damage()
	if not bool(commit_res.get("ok", true)):
		# Persistence failed: withhold acknowledgment so work remains recoverable
		return
	var attack_ids: Array = commit_res.get("committed_ids", []).duplicate()
	var cid := campaign_id()

	# Re-acknowledge committed and no-damage attacks repeatably
	if not expected_attack_ids.is_empty():
		for aid in expected_attack_ids:
			var aid_str := String(aid)
			if attack_ids.has(aid_str):
				continue
			if doc != null and doc.has_applied_attack(aid_str):
				attack_ids.append(aid_str)
			elif identity != null:
				var prog: Dictionary = identity.attack_progress(cid, aid_str)
				if _can_acknowledge_attack(prog, round_id, phase_id):
					attack_ids.append(aid_str)
	else:
		if identity != null and not cid.is_empty():
			for item in identity.attacks_for_phase(cid, round_id, phase_id):
				var atk_dict: Dictionary = item.get("attack", {})
				var aid_str := String(atk_dict.get("attack_id", ""))
				if not aid_str.is_empty() and not attack_ids.has(aid_str):
					if doc != null and doc.has_applied_attack(aid_str):
						attack_ids.append(aid_str)
					elif _can_acknowledge_attack(item, round_id, phase_id):
						attack_ids.append(aid_str)

	var down := false
	var cond := ""
	if doc != null and rules != null:
		down = bool(rules.combat.is_knocked_out(doc.raw()))
		cond = rules.combat.condition_of(doc.raw())
	if identity != null and not cid.is_empty():
		for aid in attack_ids:
			var prog: Dictionary = identity.attack_progress(cid, aid)
			var raw_outcome: Variant = prog.get("outcome")
			var outcome: Dictionary = raw_outcome if raw_outcome is Dictionary else {}
			if bool(outcome.get("knocked_out", false)) or bool(outcome.get("endurance_failed", false)):
				down = true
			var raw_resolved: Variant = prog.get("resolved")
			var resolved: Dictionary = raw_resolved if raw_resolved is Dictionary else {}
			var raw_res_result: Variant = resolved.get("result")
			var res_result: Dictionary = raw_res_result if raw_res_result is Dictionary else {}
			if bool(resolved.get("knocked_out", false)) or bool(resolved.get("endurance_failed", false)) or bool(res_result.get("knocked_out", false)) or bool(res_result.get("endurance_failed", false)):
				down = true
	if down and cond.is_empty():
		cond = "knocked out"

	if transport != null:
		transport.send_phase_committed({
			"operation_id": operation_id,
			"round_id": round_id,
			"phase": phase_id,
			"knocked_out": down,
			"condition": cond,
			"attack_ids": attack_ids,
		})



func _can_acknowledge_attack(progress: Dictionary, round_id: String, phase_id: String) -> bool:
	var attack: Dictionary = progress.get("attack", {})
	return not bool(progress.get("cancelled", false)) \
		and bool(progress.get("committed", false)) \
		and String(progress.get("character_key", "")) == _character_key() \
		and String(attack.get("round_id", "")) == round_id \
		and String(attack.get("phase", "")) == phase_id


## Whether this device's character has already dodged this round.
func is_dodging() -> bool:
	if active_round == null or transport == null:
		return false
	return active_round.is_dodging(transport.local_player_id())


## Send the action check this device just rolled.
func send_action_check(check: SkillCheck, expected_round_id: String = "") -> void:
	if transport == null or check == null:
		return
	if not expected_round_id.is_empty() and (active_round == null or active_round.round_id != expected_round_id):
		return
	if active_round != null:
		active_round.record_check(
			transport.local_player_id(),
			check.degree(),
			check.ordinary,
			AlternityNum.as_int(check.result.get("total", 0)),
			bool(check.result.get("is_critical_failure", false))
		)
		round_changed.emit()
		changed.emit()
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
	var kind := String(event.get("kind", ""))
	if kind == CampaignSession.EVENT_SCENE_END:
		_end_the_scene()
		return
	if kind == CampaignSession.EVENT_BUFF:
		_absorb_buff(event)
		return
	if kind == CampaignSession.EVENT_AP_SET:
		if transport != null and String(event.get("player_id", "")) == transport.local_player_id() and doc != null:
			var payload_set: Dictionary = event.get("payload", {}) if typeof(event.get("payload")) == TYPE_DICTIONARY else {}
			var new_ap := AlternityNum.as_int(payload_set.get("new_ap", 0))
			doc.apply(CharacterDoc.ALL, func(character):
				character["achievement_points"] = new_ap)
			if store != null:
				store.save(doc)
			push_character()
			ap_applied.emit(new_ap, "Total adjusted by GM")
		return
	if kind != CampaignSession.EVENT_AP_AWARD:
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


## A buff or beneficial skill (e.g. Fortitude) arrived for this character.
func _absorb_buff(event: Dictionary) -> void:
	var payload: Dictionary = event.get("payload", {}) if typeof(event.get("payload")) == TYPE_DICTIONARY else {}
	var target_id := String(payload.get("target_player_id", ""))
	var my_id := transport.local_player_id() if transport != null else ""
	if (target_id == my_id or (target_id.is_empty() and String(event.get("player_id", "")) == my_id)) and doc != null:
		var temp_boxes: Dictionary = payload.get("temporary_durability", {})
		if not temp_boxes.is_empty():
			doc.apply([CharacterDoc.DAMAGE], func(character):
				character["temporary_durability"] = temp_boxes.duplicate(true)
			)
			if store != null:
				store.save(doc)
			push_character()
			buff_applied.emit(payload)


## The shooting has stopped: clear the stun and wake up.
##
## Applied here rather than by the GM for the same reason damage is: this device
## owns the character. The GM says when the scene ended; what that does to a
## particular hero is worked out where the hero lives.
##
## Only stun. A scene ending does not mend a wound, and a dying character is
## still dying when the room goes quiet.
func _end_the_scene() -> void:
	if doc == null or rules == null:
		return
	var cleared: int = doc.apply([CharacterDoc.DAMAGE], func(character):
		return rules.combat.end_scene(character))
	if cleared <= 0:
		return
	if store != null:
		store.save(doc)
	push_character()
	scene_ended.emit(cleared)


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
	var who := _event_name(String(event.get("player_id", "")), payload)

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
				return "%s was awarded achievement points" % who
			return "%s was awarded %d AP -- %s" % [
				who,
				AlternityNum.as_int(payload.get("amount", 0)),
				String(payload.get("reason", "")),
			]
		CampaignSession.EVENT_AP_SET:
			return "%s's achievement points were set to %d" % [who, AlternityNum.as_int(payload.get("new_ap", 0))]
		CampaignSession.EVENT_SCENE_END:
			return "The scene ended -- your stun clears"
		CampaignSession.EVENT_CHECK:
			return "The GM asked %s for %s" % [String(payload.get("target_name", "Everyone")), SkillCheck.from_dict(payload).describe()]
		CampaignSession.EVENT_JOIN:
			return "%s joined" % who
		CampaignSession.EVENT_NOTE:
			return String(payload.get("text", ""))
		CampaignSession.EVENT_BUFF:
			var caster := who
			var target_name := _event_name(String(payload.get("target_player_id", "")), {"character_name": payload.get("target_name", "")})
			var skill := String(payload.get("skill_name", "a spell"))
			var degree := String(payload.get("degree", ""))
			return "%s cast %s on %s (%s)!" % [caster, skill, target_name, degree]
	return String(event.get("kind", ""))


func _event_name(player_id: String, payload: Dictionary) -> String:
	var saved := String(payload.get("character_name", "")).strip_edges()
	if not saved.is_empty():
		return saved
	if transport != null:
		if player_id == transport.local_player_id() and doc != null:
			return doc.get_hero_name()
		for seat in transport.table_seats():
			if String(seat.get("player_id", "")) == player_id:
				if bool(seat.get("is_gm", false)):
					return "GM"
				var hero := String(seat.get("character_name", "")).strip_edges()
				return hero if not hero.is_empty() else String(seat.get("player_name", "Character"))
	if active_round != null and active_round.has_combatant(player_id):
		return String(active_round.combatant(player_id).get("name", "Character"))
	return String(payload.get("player_name", "GM" if player_id.is_empty() else "Departed character"))
