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
const FORMAT_VERSION := 1

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

var round_id: String = ""
var number: int = 1
var state: String = STATE_ROLLING

## Index into PHASES. Only meaningful once state is STATE_ACTIVE.
var phase_index: int = 0

## Combatants, keyed by the id that identifies them elsewhere -- a player_id for
## a seated player.
##
## Each is {id, kind, name, degree, score, actions, acted, out, out_reason}.
var combatants: Array = []


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
		"actions": maxi(1, actions),
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
## explicit that ties are broken "in order of their action check scores -- highest
## score first", meaning the character's score, not the die.
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
func _phase_for_degree(degree: String) -> String:
	var lowered := degree.to_lower()
	if PHASES.has(lowered):
		return lowered
	return "marginal"


func has_all_checks() -> bool:
	for entry in combatants:
		if String(entry.get("degree", "")).is_empty():
			return false
	return not combatants.is_empty()


## Who has not rolled yet, so a GM can chase them or roll for them.
func awaiting_checks() -> Array:
	var out: Array = []
	for entry in combatants:
		if String(entry.get("degree", "")).is_empty():
			out.append(String(entry.get("id", "")))
	return out


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


## Everyone who may act in one phase, in order.
##
## Two rules decide who is in the list. A combatant acts in the phase their check
## reached and in every phase after it -- so a good roll buys earlier
## opportunities, not just an earlier turn. But they only get one action per
## phase, and only as many actions as their Constitution and Will allow: a
## character with three actions who rolled Amazing acts in Amazing, Good and
## Ordinary, and is finished before Marginal.
##
## Order inside the phase is by the character's own action check score, highest
## first, with one exception -- a Critical Failure goes last in Marginal
## regardless of how good their score is.
func acting_in(phase_id: String) -> Array:
	var wanted := PHASES.find(phase_id)
	if wanted == -1:
		return []

	var out: Array = []
	for entry in combatants:
		# Only actually out. Somebody dropped during this phase still completes
		# what they declared; see knock_out().
		if bool(entry.get("out", false)):
			continue
		var earned := PHASES.find(String(entry.get("degree", "marginal")))
		if earned == -1 or earned > wanted:
			continue
		# One action per phase, starting at the phase they earned.
		if wanted - earned >= AlternityNum.as_int(entry.get("actions", 1), 1):
			continue
		out.append(entry)

	out.sort_custom(_before)
	return out


## Sort order inside a phase.
##
## Highest action check score first. A Critical Failure is sorted behind
## everybody, which only ever matters in Marginal -- the one phase a critical
## failure can act in.
func _before(a: Dictionary, b: Dictionary) -> bool:
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
## Returns the phase now current, or "" when the round is over.
func advance_phase() -> String:
	if state != STATE_ACTIVE:
		return ""
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
func next_round() -> ActionRound:
	var following := ActionRound.new(number + 1)
	for entry in combatants:
		following.add_combatant(
			String(entry.get("id", "")),
			String(entry.get("name", "")),
			AlternityNum.as_int(entry.get("actions", 1), 1),
			String(entry.get("kind", KIND_PLAYER))
		)
		if bool(entry.get("out", false)) or bool(entry.get("pending_out", false)):
			following.knock_out(String(entry.get("id", "")), String(entry.get("out_reason", "")))
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
	}


static func from_dict(data: Dictionary) -> ActionRound:
	var round_object := ActionRound.new(AlternityNum.as_int(data.get("number", 1), 1))
	round_object.round_id = String(data.get("round_id", CampaignSession.new_id()))
	round_object.state = String(data.get("state", STATE_ROLLING))
	round_object.phase_index = AlternityNum.as_int(data.get("phase_index", 0))
	var listed = data.get("combatants", [])
	round_object.combatants = listed.duplicate(true) if typeof(listed) == TYPE_ARRAY else []
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
