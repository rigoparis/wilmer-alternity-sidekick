class_name ActionRound
extends RefCounted
##
## One 12-second action round: who acts, in which phase, and in what order.
##
## Alternity does not use a turn order. Every combatant rolls an action check,
## and how well they roll decides *which phases* they may act in -- an Amazing
## success unlocks the Amazing phase and every phase after it, a Failure leaves
## you acting only in Marginal. So the round is four passes down the table rather
## than one lap around it, and a good roll buys you earlier opportunities rather
## than simply going first.
##
## Two consequences are the whole reason this is a model and not a sorted list:
##
##   * Results apply at the end of a phase, not as each action is taken. Two
##     combatants who drop each other in the same phase both connect.
##   * A combatant taken out during a phase loses every action scheduled in the
##     phases after it. Being dropped in Amazing costs you Good, Ordinary and
##     Marginal, which is what makes acting early worth so much.
##
## Combatants are seated players for now. The shape is deliberately not "seat":
## a combatant carries its own action check and durability references, so GM-run
## NPCs can join the same round later without the round learning what an NPC is.
##
## No networking here. This is the document; the GM's device owns it and the
## players are sent a copy to read.
##

## Bumped when the stored shape changes.
const FORMAT_VERSION := 2

## The four phases, best first. A combatant acts in the phase their check
## reached and in every phase below it.
const PHASES := ["amazing", "good", "ordinary", "marginal"]

const PHASE_NAMES := {
	"amazing": "Amazing",
	"good": "Good",
	"ordinary": "Ordinary",
	"marginal": "Marginal",
}

## A combatant this device controls the character for.
const KIND_PLAYER := "player"
## Run by the GM. Not built yet -- the seam is here so the round does not have to
## change when it is.
const KIND_NPC := "npc"

## Waiting on action checks before the first phase can start.
const STATE_ROLLING := "rolling"
## Running. `phase` says which one.
const STATE_ACTIVE := "active"
const STATE_FINISHED := "finished"

## Action statuses within an active phase.
const STATUS_WAITING := "waiting"
const STATUS_COMPLETED := "completed"
const STATUS_POSTPONED := "postponed"

var round_id: String = ""
var number: int = 1
var state: String = STATE_ROLLING

## Index into PHASES. Only meaningful once state is STATE_ACTIVE.
var phase_index: int = 0

## Combatants, keyed by the id that identifies them elsewhere -- a player_id for
## a seated player.
##
## Each is {id, kind, name, degree, check_score, roll, critical, actions,
## base_actions, spent, phase_actions, dodge, out, pending_out, out_reason}.
var combatants: Array = []

## Command deduplication table persisted with the round.
var processed_commands: Dictionary = {}


func is_command_processed(command_id: String) -> bool:
	return not command_id.is_empty() and processed_commands.has(command_id)


func record_command(command_id: String, details: Dictionary = {}) -> void:
	if not command_id.is_empty():
		processed_commands[command_id] = details.duplicate(true)


func erase_command(command_id: String) -> void:
	if not command_id.is_empty():
		processed_commands.erase(command_id)


func _init(round_number: int = 1) -> void:
	round_id = CampaignSession.new_id()
	number = round_number


# --- Building the round ----------------------------------------------------

## Add someone to the round. Returns false if they are already in it.
##
## `actions` is how many actions they get per round, which the rules engine
## already works out from CON + WIL. It is passed in rather than derived so this
## model never needs the rules engine or a character.
func add_combatant(id: String, display_name: String, actions: int = 1, kind: String = KIND_PLAYER) -> bool:
	if id.is_empty() or has_combatant(id):
		return false
	combatants.append({
		"id": id,
		"kind": kind,
		"name": display_name,
		# Empty until their action check comes in.
		"degree": "",
		# The character's own action check score -- their target number, not what
		# they rolled. This is what orders a phase; see acting_in().
		"check_score": 0,
		# What they actually rolled, kept for display. Lower is better.
		"roll": 0,
		"critical": false,
		# How many actions they get this round. Derived from CON and WIL when the
		# round is built and adjustable by the GM afterwards -- see set_actions.
		"actions": maxi(0, actions),
		# What the character's own numbers allow, which is what the next round
		# starts from. Kept separately so a GM taking an action away for being
		# stunned does not quietly cost them one for the rest of the fight.
		"base_actions": maxi(0, actions),
		# How many actions have been spent this round.
		"spent": 0,
		# Decisions per phase: phase_id -> STATUS_WAITING / STATUS_COMPLETED / STATUS_POSTPONED.
		"phase_actions": {},
		# The degree of a dodge declared this round, or "" for none. One dodge
		# covers every attack against them until the round ends.
		"dodge": "",
		"out": false,
		"pending_out": false,
		"out_reason": "",
	})
	return true


func has_combatant(id: String) -> bool:
	return not combatant(id).is_empty()


func combatant(id: String) -> Dictionary:
	for entry in combatants:
		if String(entry.get("id", "")) == id:
			return entry
	return {}


## How many actions somebody gets this round (their round budget).
##
## The GM's dial, because no model can know everything that costs an action. A
## character who is stunned, restrained, reloading or arguing with the GM has
## fewer than their sheet says, and the sheet is not where that is decided.
##
## Zero is allowed and means they do nothing this round, which is a real thing
## that happens to people. There is no upper bound for the same reason there is
## no lower one: the GM is the one who knows.
func set_actions(id: String, actions: int) -> bool:
	var entry := combatant(id)
	if entry.is_empty():
		return false
	entry["actions"] = maxi(0, actions)
	return true


## Give somebody an action or take one away.
func adjust_actions(id: String, delta: int) -> bool:
	var entry := combatant(id)
	if entry.is_empty():
		return false
	return set_actions(id, AlternityNum.as_int(entry.get("actions", 1), 1) + delta)


func actions_of(id: String) -> int:
	return AlternityNum.as_int(combatant(id).get("actions", 0))


func budget_of(id: String) -> int:
	return actions_of(id)


func spent_of(id: String) -> int:
	return AlternityNum.as_int(combatant(id).get("spent", 0))


## Real actions remaining from the character's action budget.
func actions_remaining(id: String) -> int:
	if state == STATE_FINISHED or is_out(id):
		return 0
	var entry := combatant(id)
	if entry.is_empty():
		return 0
	return maxi(0, actions_of(id) - spent_of(id))


## Phase opportunities remaining in this round: phases from current to Marginal
## where this combatant could potentially act, limited by remaining budget.
func opportunities_remaining(id: String) -> int:
	if state == STATE_FINISHED or is_out(id):
		return 0
	var entry := combatant(id)
	if entry.is_empty():
		return 0
	var rem := actions_remaining(id)
	if rem <= 0:
		return 0
	var deg := String(entry.get("degree", ""))
	if deg.is_empty():
		return 0
	var earned := PHASES.find(_phase_for_degree(deg))
	if earned == -1:
		return 0
	var start_idx := phase_index if state == STATE_ACTIVE else 0
	var count := 0
	for idx in range(start_idx, PHASES.size()):
		if idx >= earned:
			var phase_id: String = PHASES[idx]
			if idx == phase_index and state == STATE_ACTIVE:
				var st := status_in_phase(id, phase_id)
				if st != STATUS_WAITING and not st.is_empty():
					continue
			count += 1
	return mini(rem, count)


## Action status for a combatant in a specific phase.
func status_in_phase(id: String, phase_id: String) -> String:
	var entry := combatant(id)
	if entry.is_empty() or bool(entry.get("out", false)):
		return ""
	var deg := String(entry.get("degree", ""))
	if deg.is_empty():
		return ""
	var earned := PHASES.find(_phase_for_degree(deg))
	var wanted := PHASES.find(phase_id)
	if earned == -1 or wanted < earned:
		return ""
	var phase_actions: Dictionary = entry.get("phase_actions", {})
	if phase_actions.has(phase_id):
		return String(phase_actions[phase_id])
	if state == STATE_ACTIVE and phase_id == phase() and actions_remaining(id) > 0:
		return STATUS_WAITING
	return ""


## Whether a combatant can take an action in this phase.
func can_act_in(id: String, phase_id: String) -> bool:
	if is_out(id) or actions_remaining(id) <= 0:
		return false
	var entry := combatant(id)
	if entry.is_empty():
		return false
	var deg := String(entry.get("degree", ""))
	if deg.is_empty():
		return false
	var earned := PHASES.find(_phase_for_degree(deg))
	var wanted := PHASES.find(phase_id)
	if earned == -1 or wanted < earned:
		return false
	if state == STATE_ACTIVE and phase_id == phase():
		var st := status_in_phase(id, phase_id)
		return st == STATUS_WAITING or st.is_empty()
	return true


## Record an action completed in the active phase, deducting 1 slot from budget.
## Idempotent: repeated calls for an already completed action do not deduct again.
func act(id: String, phase_id: String = "") -> bool:
	if state != STATE_ACTIVE:
		return false
	var target_phase := phase_id if not phase_id.is_empty() else phase()
	if target_phase != phase():
		return false
	var entry := combatant(id)
	if entry.is_empty() or bool(entry.get("out", false)):
		return false
	var deg := String(entry.get("degree", ""))
	if deg.is_empty():
		return false
	var earned := PHASES.find(_phase_for_degree(deg))
	var wanted := PHASES.find(target_phase)
	if earned == -1 or wanted < earned:
		return false
	var phase_actions: Dictionary = entry.get("phase_actions", {})
	var current_status := String(phase_actions.get(target_phase, ""))
	if current_status == STATUS_COMPLETED:
		return true
	if current_status == STATUS_POSTPONED:
		return false
	if actions_remaining(id) <= 0:
		return false

	entry["spent"] = AlternityNum.as_int(entry.get("spent", 0)) + 1
	phase_actions[target_phase] = STATUS_COMPLETED
	entry["phase_actions"] = phase_actions
	return true


## Postpone an action to a later phase without spending an action slot.
## Idempotent: repeated calls return true without deducting.
func postpone(id: String, phase_id: String = "") -> bool:
	if state != STATE_ACTIVE:
		return false
	var target_phase := phase_id if not phase_id.is_empty() else phase()
	if target_phase != phase():
		return false
	var entry := combatant(id)
	if entry.is_empty() or bool(entry.get("out", false)):
		return false
	var deg := String(entry.get("degree", ""))
	if deg.is_empty():
		return false
	var earned := PHASES.find(_phase_for_degree(deg))
	var wanted := PHASES.find(target_phase)
	if earned == -1 or wanted < earned:
		return false
	var phase_actions: Dictionary = entry.get("phase_actions", {})
	var current_status := String(phase_actions.get(target_phase, ""))
	if current_status == STATUS_POSTPONED:
		return true
	if current_status == STATUS_COMPLETED:
		return false
	if actions_remaining(id) <= 0:
		return false

	phase_actions[target_phase] = STATUS_POSTPONED
	entry["phase_actions"] = phase_actions
	return true


## Undo a completed or postponed action in the current phase.
func undo_action(id: String, phase_id: String = "") -> bool:
	if state != STATE_ACTIVE:
		return false
	var target_phase := phase_id if not phase_id.is_empty() else phase()
	if target_phase != phase():
		return false
	var entry := combatant(id)
	if entry.is_empty():
		return false
	var phase_actions: Dictionary = entry.get("phase_actions", {})
	if not phase_actions.has(target_phase):
		return false
	var current_status := String(phase_actions[target_phase])
	if current_status == STATUS_COMPLETED:
		entry["spent"] = maxi(0, AlternityNum.as_int(entry.get("spent", 0)) - 1)
	phase_actions.erase(target_phase)
	entry["phase_actions"] = phase_actions
	return true


# --- Dodging ---------------------------------------------------------------

## Record a dodge, by how well it was rolled.
## The degree of the dodge a combatant rolled, covering every attack against
## them for the rest of the round.
func declare_dodge(id: String, degree: String) -> bool:
	var entry := combatant(id)
	if entry.is_empty() or bool(entry.get("out", false)):
		return false
	entry["dodge"] = degree
	return true



## The degree of the dodge somebody declared this round, or "" if they have not.
func dodge_of(id: String) -> String:
	return String(combatant(id).get("dodge", ""))


func is_dodging(id: String) -> bool:
	return not dodge_of(id).is_empty()


func remove_combatant(id: String) -> bool:
	for i in combatants.size():
		if String(combatants[i].get("id", "")) == id:
			combatants.remove_at(i)
			return true
	return false


# --- Action checks ---------------------------------------------------------

## Record what a combatant's action check came to.
##
## `degree` is what rules.resolve_check() returned. `check_score` is the
## character's own action check score -- their target number -- and `roll` is
## what the dice actually showed.
##
## Both are stored because they are different things and only one of them orders
## a phase. An earlier version sorted by the roll, which is backwards in a
## roll-under system: it put the worst rollers first. Player's Handbook p. 50 is
## explicit that same-degree ties use action check scores, highest first, meaning
## the character's score, not the die. Applying that comparison across degrees
## is our agreed table policy; see _before_in_phase().
##
## A Failure or a Critical Failure is not an absence of a result -- it puts the
## combatant in the Marginal phase, which is where most of a bad round happens.
## A Critical Failure additionally goes last in that phase, whatever their score.
func record_check(id: String, degree: String, check_score: int, roll: int = 0, is_critical: bool = false) -> bool:
	var entry := combatant(id)
	if entry.is_empty():
		return false
	var lowered := degree.to_lower()
	entry["degree"] = _phase_for_degree(lowered)
	entry["check_score"] = check_score
	entry["roll"] = roll
	entry["critical"] = is_critical or lowered.contains("critical")
	return true


## Which phase a degree of success unlocks.
##
## Everything that is not one of the three successes lands in Marginal, which is
## the phase for a marginal success and for an outright failure alike.
static func _phase_for_degree(degree: String) -> String:
	var lowered := degree.to_lower()
	if PHASES.has(lowered):
		return lowered
	return "marginal"


func has_all_checks() -> bool:
	for entry in combatants:
		if bool(entry.get("out", false)):
			continue
		if String(entry.get("degree", "")).is_empty():
			return false
	return not combatants.is_empty()


## Who has not rolled yet, so a GM can chase them or roll for them.
func awaiting_checks() -> Array:
	var out: Array = []
	for entry in combatants:
		if bool(entry.get("out", false)):
			continue
		if String(entry.get("degree", "")).is_empty():
			out.append(String(entry.get("id", "")))
	return out


func place_npc(id: String, phase_id: String, check_score: int) -> bool:
	var entry := combatant(id)
	if state != STATE_ROLLING or entry.get("kind") != KIND_NPC or not PHASES.has(phase_id):
		return false
	record_check(id, phase_id, check_score)
	entry["manual"] = true
	return true


# --- Running ---------------------------------------------------------------

## Begin the round at the Amazing phase.
##
## Refuses while anyone still owes an action check: starting without them would
## silently drop those combatants out of the phases they had earned.
func start() -> bool:
	if state != STATE_ROLLING or not has_all_checks():
		return false
	state = STATE_ACTIVE
	phase_index = 0
	return true


func phase() -> String:
	return String(PHASES[phase_index]) if state == STATE_ACTIVE and phase_index < PHASES.size() else ""


func phase_name() -> String:
	return String(PHASE_NAMES.get(phase(), ""))


## Everyone who may act in the current phase, in the order they act.
func acting_now() -> Array:
	return acting_in(phase())


## The combatant currently up to act in the active phase, or {} if none.
func current_actor() -> Dictionary:
	if state != STATE_ACTIVE:
		return {}
	for entry in acting_now():
		var id := String(entry.get("id", ""))
		if status_in_phase(id, phase()) == STATUS_WAITING:
			return entry
	return {}


## Everyone participating in one phase, in order.
##
## Under the action ledger, a participant acts in the phase their check unlocked
## and later phases, provided they have actions remaining from their round budget.
## At most one action slot is spent per phase; postponing preserves the slot for
## a later phase without spending.
##
## Order inside the phase is by the character's own action check score, highest
## first, with one exception -- a Critical Failure goes last in Marginal
## regardless of how good their score is. Ties are adjudicated by the GM.
func acting_in(phase_id: String) -> Array:
	var wanted := PHASES.find(phase_id)
	if wanted == -1:
		return []

	var out: Array = []
	for entry in combatants:
		if bool(entry.get("out", false)):
			continue
		var deg := String(entry.get("degree", ""))
		if deg.is_empty():
			continue
		var earned := PHASES.find(_phase_for_degree(deg))
		if earned == -1 or earned > wanted:
			continue

		var id := String(entry.get("id", ""))
		var phase_actions: Dictionary = entry.get("phase_actions", {})
		if phase_actions.has(phase_id):
			var st := String(phase_actions[phase_id])
			if st == STATUS_COMPLETED or st == STATUS_WAITING:
				out.append(entry)
			continue

		if state == STATE_ACTIVE and wanted < phase_index:
			continue

		var rem := actions_remaining(id)
		if rem <= 0:
			continue

		var start_phase := phase_index if state == STATE_ACTIVE else 0
		var prior_count := 0
		for idx in range(start_phase, wanted):
			if idx >= earned:
				var p_id: String = PHASES[idx]
				var p_st := String(phase_actions.get(p_id, ""))
				if p_st != STATUS_POSTPONED:
					prior_count += 1
		if prior_count < rem:
			out.append(entry)


	out.sort_custom(func(a: Dictionary, b: Dictionary): return _before_in_phase(a, b, phase_id))
	return out


## Table policy: compare scores across success degrees, without priority for
## earlier eligibility or saved actions. The GM resolves equal scores per phase.
func _before_in_phase(a: Dictionary, b: Dictionary, phase_id: String) -> bool:
	var public_a: Dictionary = a.get("phase_order", {})
	var public_b: Dictionary = b.get("phase_order", {})
	if public_a.has(phase_id) and public_b.has(phase_id):
		return int(public_a[phase_id]) < int(public_b[phase_id])
	if tied(a, b):
		var ties_a: Dictionary = a.get("tie_order", {})
		var ties_b: Dictionary = b.get("tie_order", {})
		return int(ties_a.get(phase_id, 0)) < int(ties_b.get(phase_id, 0))
	return _before(a, b)


func tied(a: Dictionary, b: Dictionary) -> bool:
	return not a.is_empty() and not b.is_empty() and a.has("check_score") and b.has("check_score") \
		and int(a["check_score"]) == int(b["check_score"]) \
		and bool(a.get("critical", false)) == bool(b.get("critical", false))


## Move one tied participant directly ahead of another in this phase only.
func resolve_tie_before(id: String, other_id: String) -> bool:
	if state != STATE_ACTIVE or id == other_id or not tied(combatant(id), combatant(other_id)):
		return false
	var ordered := acting_now()
	var ids: Array = []
	for entry in ordered:
		ids.append(String(entry["id"]))
	if not ids.has(id) or not ids.has(other_id):
		return false
	ids.erase(id)
	ids.insert(ids.find(other_id), id)
	for index in ids.size():
		var entry := combatant(ids[index])
		var ranks: Dictionary = entry.get("tie_order", {})
		ranks[phase()] = index
		entry["tie_order"] = ranks
	return true


## Sort order inside a phase.
##
## Highest action check score first. A Critical Failure is sorted behind
## everybody, which only ever matters in Marginal -- the one phase a critical
## failure can act in.
func _before(a: Dictionary, b: Dictionary) -> bool:
	if a.has("initiative_order") and b.has("initiative_order"):
		return int(a["initiative_order"]) < int(b["initiative_order"])
	var a_critical := bool(a.get("critical", false))
	var b_critical := bool(b.get("critical", false))
	if a_critical != b_critical:
		return b_critical
	return AlternityNum.as_int(a.get("check_score", 0)) > AlternityNum.as_int(b.get("check_score", 0))


## Take a combatant out of the fight, as of the end of this phase.
##
## Deferred on purpose. A phase resolves as a unit: everything declared in it
## happens, and the consequences land together when it closes. Two combatants who
## drop each other in the same phase both connect, and somebody shot in the Good
## phase still completes the action they had declared there.
##
## What being dropped costs is the phases after it -- which is what makes rolling
## well worth so much. Dropped in Amazing, they do not act in Good, Ordinary or
## Marginal.
func knock_out(id: String, reason: String = "") -> bool:
	var entry := combatant(id)
	if entry.is_empty() or bool(entry.get("out", false)) or bool(entry.get("pending_out", false)):
		return false
	entry["pending_out"] = true
	entry["out_reason"] = reason
	# Outside a running phase there is nothing to finish, so it lands at once.
	if state != STATE_ACTIVE:
		_apply_pending()
	return true


## Whether a combatant has been dropped this phase but is still finishing it.
func is_falling(id: String) -> bool:
	return bool(combatant(id).get("pending_out", false))


## Close out everyone dropped during the phase that just ended.
func _apply_pending() -> void:
	for entry in combatants:
		if bool(entry.get("pending_out", false)):
			entry["pending_out"] = false
			entry["out"] = true


func revive(id: String) -> bool:
	var entry := combatant(id)
	if entry.is_empty():
		return false
	entry["out"] = false
	entry["pending_out"] = false
	entry["out_reason"] = ""
	return true


func is_out(id: String) -> bool:
	return bool(combatant(id).get("out", false))


## Everyone still standing, which includes anyone dropped in the current phase
## and still finishing it.
func standing() -> Array:
	var out: Array = []
	for entry in combatants:
		if not bool(entry.get("out", false)):
			out.append(entry)
	return out


## Close the current phase and move to the next.
##
## This is where results are meant to have been applied: the phase resolves as a
## unit, so two combatants who drop each other in the same phase both connect.
## Eligible participants who did not act are marked postponed to preserve their
## unspent budget for later phases.
## Returns the phase now current, or "" when the round is over.
func advance_phase() -> String:
	if state != STATE_ACTIVE:
		return ""
	var curr_phase := phase()
	for entry in acting_now():
		var id := String(entry.get("id", ""))
		var phase_actions: Dictionary = entry.get("phase_actions", {})
		if not phase_actions.has(curr_phase):
			phase_actions[curr_phase] = STATUS_POSTPONED
			entry["phase_actions"] = phase_actions
	# The phase is over, so its results land now -- including anybody dropped
	# during it, who has just finished the action they had declared.
	_apply_pending()
	phase_index += 1
	if phase_index >= PHASES.size():
		state = STATE_FINISHED
		phase_index = PHASES.size() - 1
		return ""
	return phase()


func is_finished() -> bool:
	return state == STATE_FINISHED


## The round after this one, carrying the same combatants forward.
##
## Everyone starts owing a fresh action check, because they do. Whoever was
## knocked out stays out: coming back is a thing that happens to a character, and
## the GM says when.
##
## Two things deliberately do not carry over. A dodge covers one round and this
## is a different one. And the action count goes back to what the character's own
## Constitution and Will allow, so a GM who took an action away for being stunned
## does not have to remember to give it back a round later.
func next_round() -> ActionRound:
	var following := ActionRound.new(number + 1)
	for entry in combatants:
		following.add_combatant(
			String(entry.get("id", "")),
			String(entry.get("name", "")),
			AlternityNum.as_int(entry.get("base_actions", entry.get("actions", 1)), 1),
			String(entry.get("kind", KIND_PLAYER))
		)
		if bool(entry.get("out", false)) or bool(entry.get("pending_out", false)):
			following.knock_out(String(entry.get("id", "")), String(entry.get("out_reason", "")))
		following.combatant(String(entry.get("id", "")))["portrait"] = String(entry.get("portrait", ""))
	return following


# --- Wire and log ----------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"format_version": FORMAT_VERSION,
		"round_id": round_id,
		"number": number,
		"state": state,
		"phase_index": phase_index,
		"combatants": combatants.duplicate(true),
		"processed_commands": processed_commands.duplicate(true),
	}


## Send ordering, not private NPC action-check scores. Full data stays on host.
func to_public_dict() -> Dictionary:
	var data := to_dict()
	var ordered: Array = combatants.duplicate(true)
	ordered.sort_custom(_before)
	for entry in data["combatants"]:
		entry["phase_order"] = {}
		for phase_id in PHASES:
			var phase_entries := acting_in(phase_id)
			for index in phase_entries.size():
				if phase_entries[index]["id"] == entry["id"]:
					entry["phase_order"][phase_id] = index
		for index in ordered.size():
			if ordered[index]["id"] == entry["id"]:
				entry["initiative_order"] = index
		if entry.get("kind") == KIND_NPC:
			entry.erase("check_score")
	return data


static func from_dict(data: Dictionary) -> ActionRound:
	var round_object := ActionRound.new(AlternityNum.as_int(data.get("number", 1), 1))
	round_object.round_id = String(data.get("round_id", CampaignSession.new_id()))
	round_object.state = String(data.get("state", STATE_ROLLING))
	round_object.phase_index = AlternityNum.as_int(data.get("phase_index", 0))
	var stored_cmds = data.get("processed_commands", {})
	round_object.processed_commands = stored_cmds.duplicate(true) if typeof(stored_cmds) == TYPE_DICTIONARY else {}
	var stored_version: int = AlternityNum.as_int(data.get("format_version", 1), 1)
	var listed = data.get("combatants", [])
	round_object.combatants = listed.duplicate(true) if typeof(listed) == TYPE_ARRAY else []
	for entry in round_object.combatants:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var actions_val: int = AlternityNum.as_int(entry.get("actions", 1), 1)
		if not entry.has("base_actions"):
			entry["base_actions"] = actions_val
		if stored_version < 2:
			var deg := String(entry.get("degree", ""))
			var earned := PHASES.find(_phase_for_degree(deg)) if not deg.is_empty() else -1
			var phase_actions: Dictionary = {}
			var spent := 0
			if round_object.state == STATE_ACTIVE and earned != -1:
				for p in range(0, round_object.phase_index):
					if p >= earned and spent < actions_val:
						phase_actions[PHASES[p]] = STATUS_COMPLETED
						spent += 1
			elif round_object.state == STATE_FINISHED and earned != -1:
				for p in range(0, PHASES.size()):
					if p >= earned and spent < actions_val:
						phase_actions[PHASES[p]] = STATUS_COMPLETED
						spent += 1
			entry["spent"] = spent
			entry["phase_actions"] = phase_actions
		else:
			if not entry.has("spent"):
				entry["spent"] = 0
			if not entry.has("phase_actions") or typeof(entry.get("phase_actions")) != TYPE_DICTIONARY:
				entry["phase_actions"] = {}
	return round_object


## One line describing where the round is, for a feed or a header.
func describe() -> String:
	match state:
		STATE_ROLLING:
			var waiting := awaiting_checks().size()
			if waiting == 0:
				return "Round %d -- ready to start" % number
			return "Round %d -- waiting on %d action check%s" % [number, waiting, "" if waiting == 1 else "s"]
		STATE_ACTIVE:
			return "Round %d -- %s phase" % [number, phase_name()]
	return "Round %d -- over" % number
