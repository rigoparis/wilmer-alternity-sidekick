class_name SkillCheck
extends RefCounted
##
## One action check on its way from "I want to try this" to a settled result.
##
## Alternity resolves a check as a control d20 plus a situation die, against the
## hero's skill score. The situation die is the interesting part: it comes from a
## step total that two people contribute to. The character contributes their own
## accumulated modifiers -- broad-skill bonus, species, mutations, dazed penalty,
## encumbrance -- and the GM contributes difficulty. Neither half is complete on
## its own, which is why a check is a small document with a round trip in the
## middle rather than a function call.
##
## Two directions arrive at the same place:
##
##     player asks    request -> ruling -> roll
##     GM asks        call ------------- -> roll
##
## Both produce a check with a known `total_step`, and from there the tray throws
## the same two dice. The GM's own step is separate from the player's throughout
## so the log can say what the GM added, which is the part a table argues about
## a week later.
##
## No networking and no physics here. This is the document; NetTransport moves it
## and PhysicalDiceSource resolves it.
##

## Bumped when the stored shape changes.
const FORMAT_VERSION := 1

## Who asked for the check. The player's own device, or the GM.
const ORIGIN_PLAYER := "player"
const ORIGIN_GM := "gm"

## Waiting on a GM ruling. Only ever true for a player-initiated check.
const STATE_PENDING := "pending"
## Has a total step and is ready for the tray.
const STATE_READY := "ready"
## Rolled and graded.
const STATE_RESOLVED := "resolved"
## Refused by the GM, or declined by the player, or the table went away.
const STATE_CANCELLED := "cancelled"

## The step range action_step_die() covers meaningfully. Beyond -5 it caps, and
## past +7 it keeps adding d20s -- both are still legal, this is what a dial
## should offer.
const MIN_STEP := -5
const MAX_STEP := 7

var check_id: String = ""
var origin: String = ORIGIN_PLAYER
var state: String = STATE_PENDING

## Who is rolling. A stable player_id, never a peer id.
var player_id: String = ""

## What is being attempted. `skill_id` is the rules id; `skill_label` is carried
## alongside it because the GM's device may not have this character and cannot
## turn an id into "Athletics - Climb" on its own.
var skill_id: int = -1
var skill_label: String = ""

## The hero's score for this skill. Read-only to everyone but the player's own
## device -- see AGENTS.md on one owner per document.
var ordinary: int = 0
var good: int = 0
var amazing: int = 0

## Steps the character already carries, from skill_score().
var player_step: int = 0

## Itemized source of player steps (e.g. broad penalty, species, wounds, encumbrance).
var step_breakdown: Array = []

## Steps the GM has added. Positive is harder.
var gm_step: int = 0

## Why the GM ruled as they did. Optional, and worth more than the number in a
## log read a month later.
var reason: String = ""

## Set once the dice settle. See RollResult and rules.resolve_check().
var result: Dictionary = {}

var created_at: int = 0


func _init(from_player: String = "", origin_kind: String = ORIGIN_PLAYER) -> void:
	check_id = CampaignSession.new_id()
	player_id = from_player
	origin = origin_kind
	created_at = int(Time.get_unix_time_from_system())
	# A GM-initiated check has nothing to wait for -- the GM set the step when
	# they called for it.
	state = STATE_READY if origin == ORIGIN_GM else STATE_PENDING


## Build a player's request from their own character.
##
## Takes the score dictionary rather than the character, so this stays usable
## from anywhere that already has one and never needs the rules engine itself.
static func request(from_player: String, skill: Dictionary, score: Dictionary, label: String) -> SkillCheck:
	var check := SkillCheck.new(from_player, ORIGIN_PLAYER)
	check.skill_id = AlternityNum.as_int(skill.get("id", -1), -1)
	check.skill_label = label
	check.ordinary = AlternityNum.as_int(score.get("ordinary", 0))
	check.good = AlternityNum.as_int(score.get("good", 0))
	check.amazing = AlternityNum.as_int(score.get("amazing", 0))
	check.player_step = AlternityNum.as_int(score.get("step", 0))
	check.step_breakdown = score.get("step_breakdown", []).duplicate(true)
	return check


## Build a GM's call for a check.
##
## The score is unknown here -- the GM's device does not hold the character --
## so it is filled in by the player's device when it accepts. Until then the
## check knows what to roll but not what to roll against.
static func call_for(skill_label_text: String, step: int, why: String = "", skill: int = -1) -> SkillCheck:
	var check := SkillCheck.new("", ORIGIN_GM)
	check.skill_id = skill
	check.skill_label = skill_label_text
	check.gm_step = clampi(step, MIN_STEP, MAX_STEP)
	check.reason = why
	return check


## The GM's answer to a request. Returns false if this check was not waiting for
## one, so a ruling arriving twice cannot move a resolved check backwards.
func rule(step: int, why: String = "") -> bool:
	if state != STATE_PENDING:
		return false
	gm_step = clampi(step, MIN_STEP, MAX_STEP)
	reason = why
	state = STATE_READY
	return true


## Fill in the score on a GM-called check, on the player's device.
##
## The player's device is the only one that can: it owns the character. This is
## the same ownership rule that keeps AP awards one-directional, seen from the
## other end.
func accept(score: Dictionary) -> bool:
	if state != STATE_READY or origin != ORIGIN_GM:
		return false
	ordinary = AlternityNum.as_int(score.get("ordinary", 0))
	good = AlternityNum.as_int(score.get("good", 0))
	amazing = AlternityNum.as_int(score.get("amazing", 0))
	player_step = AlternityNum.as_int(score.get("step", 0))
	step_breakdown = score.get("step_breakdown", []).duplicate(true)
	return true


func cancel(why: String = "") -> void:
	if state == STATE_RESOLVED:
		return
	state = STATE_CANCELLED
	if not why.is_empty():
		reason = why


## Both halves of the step, which is what decides the situation die.
func total_step() -> int:
	return player_step + gm_step


## Whether this check is worth rolling.
##
## A skill the hero cannot attempt at all has an ordinary score of zero, and
## rolling against zero is not a check -- it is a guaranteed failure dressed up
## as one.
func is_rollable() -> bool:
	return state == STATE_READY and ordinary > 0


## Record the settled outcome. `graded` is what rules.resolve_check() returned.
func resolve(graded: Dictionary) -> void:
	result = graded.duplicate(true)
	state = STATE_RESOLVED


func degree() -> String:
	return String(result.get("degree", ""))


func is_success() -> bool:
	return bool(result.get("is_success", false))


# --- Wire and log ----------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"format_version": FORMAT_VERSION,
		"check_id": check_id,
		"origin": origin,
		"state": state,
		"player_id": player_id,
		"skill_id": skill_id,
		"skill_label": skill_label,
		"ordinary": ordinary,
		"good": good,
		"amazing": amazing,
		"player_step": player_step,
		"step_breakdown": step_breakdown.duplicate(true),
		"gm_step": gm_step,
		"total_step": total_step(),
		"reason": reason,
		"result": result.duplicate(true),
		"created_at": created_at,
	}


static func from_dict(data: Dictionary) -> SkillCheck:
	var check := SkillCheck.new()
	check.check_id = String(data.get("check_id", CampaignSession.new_id()))
	check.origin = String(data.get("origin", ORIGIN_PLAYER))
	check.state = String(data.get("state", STATE_PENDING))
	check.player_id = String(data.get("player_id", ""))
	check.skill_id = AlternityNum.as_int(data.get("skill_id", -1), -1)
	check.skill_label = String(data.get("skill_label", ""))
	check.ordinary = AlternityNum.as_int(data.get("ordinary", 0))
	check.good = AlternityNum.as_int(data.get("good", 0))
	check.amazing = AlternityNum.as_int(data.get("amazing", 0))
	check.player_step = AlternityNum.as_int(data.get("player_step", 0))
	var bd = data.get("step_breakdown", [])
	check.step_breakdown = bd.duplicate(true) if typeof(bd) == TYPE_ARRAY else []
	check.gm_step = AlternityNum.as_int(data.get("gm_step", 0))
	check.reason = String(data.get("reason", ""))
	check.created_at = AlternityNum.as_int(data.get("created_at", 0))
	var stored = data.get("result", {})
	check.result = stored.duplicate(true) if typeof(stored) == TYPE_DICTIONARY else {}
	return check


## One line describing what was asked and what the GM made of it.
##
## Built here rather than in a screen because both the GM's feed and the player's
## feed want the same sentence, and two of them would drift.
func describe() -> String:
	var what := skill_label if not skill_label.is_empty() else "a check"
	var step := gm_step
	var difficulty := ""
	if step > 0:
		difficulty = " (+%d step%s harder)" % [step, "" if step == 1 else "s"]
	elif step < 0:
		difficulty = " (%d step%s easier)" % [step, "" if step == -1 else "s"]
	var tail := ""
	if not reason.is_empty():
		tail = " -- %s" % reason
	return "%s%s%s" % [what, difficulty, tail]
