class_name CheckRunner
extends RefCounted
##
## Runs an action check from "I want to try this" to a settled result.
##
## The flow crosses a screen, a network round trip and a physics simulation, and
## none of those three should have to know about the other two. A skill row wants
## to say "roll this"; the GM screen wants to say "here is the step"; the tray
## wants two dice and a target number. This is what joins them.
##
## Three paths, one ending:
##
##   at a table     request -> wait for the GM's step -> tray -> broadcast
##   GM called it   the step is already set -> tray -> broadcast
##   no table       the player sets the step themselves -> tray -> local only
##
## The no-table path is not a degraded mode. Every other part of this feature was
## built to work on one device first, and a player rolling against their own
## sheet in solo prep is an ordinary thing to do.
##

## The GM has not answered within this many seconds.
##
## Not a failure: the ruling may still arrive. It exists so a player is told
## something is happening rather than watching a silent screen, and so a GM who
## walked away does not strand the table.
const RULING_PATIENCE := 20.0

const TRAY_ROUTE := preload("res://scenes/ui/routes/dice_tray_route.tscn")
const CHECK_STEP_ROUTE := preload("res://scenes/ui/routes/check_step_route.tscn")
const CHECK_WAITING_ROUTE := preload("res://scenes/ui/routes/check_waiting_route.tscn")

var _rules: AlternityRules
var _router: UiRouter
var _palette: ThemePalette

## The table, when there is one. Null means solo, which is a supported way to
## play rather than an error.
var _transport: EnetTransport

## Rulings that arrived, keyed by check id, so a reply is matched to its request
## rather than to whatever was asked most recently.
var _rulings: Dictionary = {}
var _listening: bool = false


func _init(rules: AlternityRules, router: UiRouter, palette: ThemePalette) -> void:
	_rules = rules
	_router = router
	_palette = palette


## Point the runner at a table, or at nothing.
func use_transport(transport: EnetTransport) -> void:
	if _transport != null and _listening and is_instance_valid(_transport):
		if _transport.check_ruled.is_connected(_on_check_ruled):
			_transport.check_ruled.disconnect(_on_check_ruled)
	_transport = transport
	_listening = false
	_rulings.clear()
	if _transport != null:
		_transport.check_ruled.connect(_on_check_ruled)
		_listening = true


func has_table() -> bool:
	return _transport != null and _transport.is_connected_to_table()


# --- Starting a check ------------------------------------------------------

## Roll `skill` for the character in `doc`.
##
## Returns the resolved SkillCheck, or null if the person backed out. The caller
## does not need to know which of the three paths was taken.
func run(doc: CharacterDoc, skill: Dictionary):
	if doc == null or _rules == null:
		return null

	var score: Dictionary = _rules.skill_score(doc.raw(), skill)
	if not bool(score.get("usable", false)):
		# A skill this hero cannot attempt is not a check. Say so rather than
		# throwing dice against a score of zero.
		await _explain_unusable(skill, score)
		return null

	var check := SkillCheck.request(_local_player_id(), skill, score, _rules.skill_label(skill))

	if has_table():
		if not await _await_ruling(check):
			return null
	else:
		# Nobody to ask. The player sets the difficulty themselves, which is the
		# same dial the GM would have used.
		if not await _ask_for_own_step(check):
			return null

	return await _throw(check, doc)


## Roll a check the GM asked for. `check` arrives with its step already set.
func run_called(check: SkillCheck, doc: CharacterDoc, skill: Dictionary):
	if doc == null or check == null:
		return null
	var score: Dictionary = _rules.skill_score(doc.raw(), skill)
	if not bool(score.get("usable", false)):
		await _explain_unusable(skill, score)
		return null
	check.accept(score)
	return await _throw(check, doc)


# --- The three paths -------------------------------------------------------

## Ask the GM, and wait. Returns false if the person gave up waiting.
## Roll this character's action check for a round of combat.
##
## An action check is an ordinary check with two differences: it is rolled
## against the character's own action check score rather than a skill, and there
## is nothing to ask the GM -- the difficulty of acting is whatever the character
## carries. So it skips the ruling round trip and goes straight to the tray.
##
## Returns the settled SkillCheck, or null if the throw was abandoned. The caller
## reads `degree()` for the phase and `ordinary` for the score that orders it.
func run_action_check(doc: CharacterDoc):
	if doc == null or _rules == null:
		return null
	var score: Dictionary = _rules.action_check(doc.raw())

	var check := SkillCheck.new(_local_player_id(), SkillCheck.ORIGIN_GM)
	check.skill_label = "Action check"
	check.ordinary = AlternityNum.as_int(score.get("ordinary", 0))
	check.good = AlternityNum.as_int(score.get("good", 0))
	check.amazing = AlternityNum.as_int(score.get("amazing", 0))
	# Everything the character brings to acting quickly -- species, cybertech,
	# armor, and how hurt they are -- is already netted into this by the rules.
	check.player_step = AlternityNum.as_int(score.get("step", 0))

	if not check.is_rollable():
		return null
	return await _throw(check, doc)


## Roll this character's requisition check for equipment in Dark*Matter.
##
## Rolled against Administration-bureaucracy (or Will feat check if untrained),
## with step modifiers for availability, urgency, and necessity.
func run_requisition_check(doc: CharacterDoc, options: Dictionary = {}):
	if doc == null or _rules == null:
		return null
	var score: Dictionary = _rules.requisition_check_score(doc.raw(), options)

	var check := SkillCheck.new(_local_player_id(), SkillCheck.ORIGIN_GM)
	check.skill_id = AlternityRulesConstants.REQUISITION_SKILL_ID
	check.skill_label = "Requisition check"
	check.ordinary = AlternityNum.as_int(score.get("ordinary", 10))
	check.good = AlternityNum.as_int(score.get("good", 5))
	check.amazing = AlternityNum.as_int(score.get("amazing", 2))
	check.player_step = AlternityNum.as_int(score.get("step", 0))

	if not check.is_rollable():
		return null
	return await _throw(check, doc)



## Throw a piece of dice notation on the tray and hand back the total.
##
## Not a check: armor and damage are numbers, with no score to beat and no degree
## to read, so there is nothing to ask the GM and nothing to broadcast.
##
## Returns -1 when the throw was abandoned, which a caller must not read as a
## zero -- rolling no armor at all and walking away from the tray are different
## answers.
func roll_notation(notation: String, label: String) -> int:
	if _router == null:
		return -1
	var term := DiceNotation.parse(notation)
	if not bool(term.get("ok", false)):
		return -1
	var outcome = await _router.push(TRAY_ROUTE, {
		"palette": _palette,
		"rules": _rules,
		"terms": [term],
		"label": label,
	})
	if typeof(outcome) != TYPE_DICTIONARY or not outcome.has("total"):
		return -1
	return AlternityNum.as_int(outcome.get("total", 0))


func _await_ruling(check: SkillCheck) -> bool:
	_transport.request_check(check.to_dict())

	var waiting_route: RouteScene = null
	var user_cancelled := false

	if _router != null:
		waiting_route = _router.present_modal(CHECK_WAITING_ROUTE, {
			"palette": _palette,
			"check": check.to_dict(),
			"title": "Waiting for GM...",
		}, UiRouter.Presentation.DIALOG)
		if waiting_route != null and waiting_route.has_signal("request_cancelled"):
			waiting_route.connect("request_cancelled", func(): user_cancelled = true)

	var waited := 0.0
	var tree := Engine.get_main_loop() as SceneTree
	var ruling_received: SkillCheck = null

	while waited < RULING_PATIENCE:
		if user_cancelled:
			break

		if _rulings.has(check.check_id):
			ruling_received = _rulings[check.check_id]
			_rulings.erase(check.check_id)
			break

		if tree == null:
			break
		await tree.process_frame
		waited += tree.root.get_process_delta_time()

	if waiting_route != null and _router != null:
		_router.dismiss_modal(waiting_route)

	if user_cancelled:
		return false

	if ruling_received != null:
		if ruling_received.state == SkillCheck.STATE_CANCELLED:
			return false
		check.gm_step = ruling_received.gm_step
		check.reason = ruling_received.reason
		check.state = SkillCheck.STATE_READY
		return true

	# The GM did not answer. Rather than hang, let the player set it and get on
	# with the game -- a table can always argue about the number afterwards.
	return await _ask_for_own_step(check, "The GM has not answered. Set it yourself for now.")


func _ask_for_own_step(check: SkillCheck, note: String = "") -> bool:
	if _router == null:
		check.rule(0)
		return true
	var chosen = await _router.push(CHECK_STEP_ROUTE, {
		"palette": _palette,
		"rules": _rules,
		"check": check.to_dict(),
		"note": note,
		"title": "How hard is it?",
		"confirm_text": "Roll",
	})
	if typeof(chosen) != TYPE_DICTIONARY:
		return false
	check.rule(AlternityNum.as_int(chosen.get("step", 0)), String(chosen.get("reason", "")))
	return true


func _throw(check: SkillCheck, doc: CharacterDoc):
	if _router == null:
		return null
	var outcome = await _router.push(TRAY_ROUTE, {
		"palette": _palette,
		"rules": _rules,
		"check": check.to_dict(),
	})
	if typeof(outcome) != TYPE_DICTIONARY or not outcome.has("check"):
		return null

	var resolved := SkillCheck.from_dict(outcome["check"])
	_broadcast(resolved, outcome, doc)
	return resolved


## Send the settled result to the table, as a fact.
##
## The roll carries the whole check with it, so the GM's feed can say what was
## attempted and against what -- a bare total would be unreadable a week later.
func _broadcast(check: SkillCheck, outcome: Dictionary, doc: CharacterDoc) -> void:
	if not has_table():
		return
	var control: Dictionary = outcome.get("control", {})
	var payload := control.duplicate(true)
	payload["label"] = check.skill_label
	payload["check"] = check.to_dict()
	if doc != null:
		payload["character_id"] = doc.get_hero_name()
	_transport.send_roll(payload)


func _on_check_ruled(data: Dictionary) -> void:
	var check := SkillCheck.from_dict(data)
	_rulings[check.check_id] = check
	check_arrived.emit(check)


## A check the GM called for, which nobody on this device asked for.
##
## Raised rather than handled here: whether an unprompted check interrupts the
## player is a screen's decision, not this object's.
signal check_arrived(check: SkillCheck)


func _local_player_id() -> String:
	return _transport.local_player_id() if _transport != null else ""


func _explain_unusable(skill: Dictionary, score: Dictionary) -> void:
	if _router == null:
		return
	var reason := String(score.get("reason", ""))
	if reason.is_empty():
		reason = "%s cannot be attempted by this hero." % _rules.skill_label(skill)
	await _router.push(preload("res://scenes/ui/routes/confirm_route.tscn"), {
		"palette": _palette,
		"title": "Not a check this hero can make",
		"message": reason,
		"confirm_text": "Understood",
		"cancel_text": "Back",
	})
