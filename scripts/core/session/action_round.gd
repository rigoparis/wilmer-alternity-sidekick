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
		"score": 0,
		"actions": maxi(1, actions),
		"acted": 0,
		"out": false,
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
## `degree` is what rules.resolve_check() returned, lowercased. `score` is the
## roll total, kept because ties inside a phase break on it.
##
## A Failure or a Critical Failure is not an absence of a result -- it puts the
## combatant in the Marginal phase, which is where most of a bad round happens.
func record_check(id: String, degree: String, score: int) -> bool:
	var entry := combatant(id)
	if entry.is_empty():
		return false
	entry["degree"] = _phase_for_degree(degree)
	entry["score"] = score
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
##
## A combatant acts in the phase they rolled and in every phase after it, so the
## Amazing phase holds only the Amazing rollers while Marginal holds everybody
## still standing. Within a phase the higher action check goes first, which
## matters for who a shot is declared against -- though the results all land
## together at the end of it.
func acting_now() -> Array:
	return acting_in(phase())


func acting_in(phase_id: String) -> Array:
	var wanted := PHASES.find(phase_id)
	if wanted == -1:
		return []

	var out: Array = []
	for entry in combatants:
		if bool(entry.get("out", false)):
			continue
		var earned := PHASES.find(String(entry.get("degree", "marginal")))
		# Earned an earlier phase, so they act in this one too.
		if earned != -1 and earned <= wanted:
			out.append(entry)

	out.sort_custom(func(a, b): return AlternityNum.as_int(a.get("score", 0)) > AlternityNum.as_int(b.get("score", 0)))
	return out


## Take a combatant out of the fight.
##
## The reason the round tracks this at all: everything they had scheduled in
## later phases goes with them. Dropped in Amazing, they do not act in Good,
## Ordinary or Marginal -- which is what makes rolling well worth so much.
func knock_out(id: String, reason: String = "") -> bool:
	var entry := combatant(id)
	if entry.is_empty() or bool(entry.get("out", false)):
		return false
	entry["out"] = true
	entry["out_reason"] = reason
	return true


func revive(id: String) -> bool:
	var entry := combatant(id)
	if entry.is_empty():
		return false
	entry["out"] = false
	entry["out_reason"] = ""
	return true


func is_out(id: String) -> bool:
	return bool(combatant(id).get("out", false))


## Everyone still standing.
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
		if bool(entry.get("out", false)):
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
