extends "res://tools/test_harness.gd"
##
## The whole check, end to end, through two real shells and real physics.
##
## A player picks a skill, the GM sets the difficulty, the dice tumble, and the
## graded result lands on the GM's feed. Every part of that has its own suite
## already; this is the one that proves they join up, which is where a flow
## crossing a screen, a network round trip and a simulation usually goes wrong.
##
## Both directions are covered, because both were asked for: the player asking
## and the GM calling for a check unprompted.
##

const SHELL := preload("res://scenes/ui/app_shell.tscn")
const Session := preload("res://scripts/core/session/campaign_session.gd")
const Check := preload("res://scripts/core/session/skill_check.gd")
const Transport := preload("res://scripts/core/session/enet_transport.gd")

const GM_DIR := "user://__check_gm__/"
const GM_CAMPAIGNS := "user://__check_gm_campaigns__/"
const PLAYER_DIR := "user://__check_player__/"
const PLAYER_CAMPAIGNS := "user://__check_player_campaigns__/"

var _gm_shell
var _player_shell
var _doc: CharacterDoc


func _init() -> void:
	# Real dice, so a couple of seconds per throw. The watchdog is here to catch
	# a hang, not to pace the suite.
	begin_async("check flow", 30000)
	_run.call_deferred()


func _run() -> void:
	for dir_path in [GM_DIR, GM_CAMPAIGNS, PLAYER_DIR, PLAYER_CAMPAIGNS]:
		_wipe(dir_path)

	_gm_shell = _new_shell(GM_DIR, GM_CAMPAIGNS)
	_player_shell = _new_shell(PLAYER_DIR, PLAYER_CAMPAIGNS)
	await process_frame
	await process_frame

	await _test_solo_check_needs_no_table()
	await _test_open_the_table()
	await _test_player_asks_and_gm_rules()
	await _test_gm_refuses()
	await _test_gm_calls_for_a_check()

	for shell in [_player_shell, _gm_shell]:
		if shell != null and is_instance_valid(shell):
			shell.queue_free()
	for dir_path in [GM_DIR, GM_CAMPAIGNS, PLAYER_DIR, PLAYER_CAMPAIGNS]:
		_wipe(dir_path)
	finish()


func _new_shell(store_dir: String, campaign_dir: String):
	var shell = SHELL.instantiate()
	shell.store_directory = store_dir
	shell.campaign_directory = campaign_dir
	root.add_child(shell)
	return shell


func _wipe(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name in dir.get_files():
		DirAccess.remove_absolute(dir_path + file_name)


func _screen(shell, fragment: String) -> Node:
	var host: Node = shell.get_node_or_null("Screens")
	if host == null:
		return null
	for child in host.get_children():
		var script = child.get_script()
		if script != null and String(script.resource_path).contains(fragment):
			return child
	return null


func _gm_screen():
	return _screen(_gm_shell, "gm_screen")


func _wait_for(condition: Callable, max_frames: int = 900) -> bool:
	for _i in max_frames:
		if condition.call():
			return true
		await process_frame
	return condition.call()


## The top open route, whatever it is.
func _top(shell):
	return shell.router._host.top_route()


## Wait for a route whose script path contains `fragment`, then hand it back.
func _await_route(shell, fragment: String, max_frames: int = 900):
	var found = await _wait_for(func():
		var route = _top(shell)
		return route != null and String(route.get_script().resource_path).contains(fragment), max_frames)
	return _top(shell) if found else null


func _skill(skill_id: int) -> Dictionary:
	return _player_shell.rules.get_skill_by_id(skill_id)


func _hero() -> CharacterDoc:
	if _doc == null:
		_doc = CharacterDoc.new(_player_shell.rules)
		_doc.set_hero_name("Vance Kellar")
		_player_shell.store.save(_doc)
	return _doc


# --- Solo ------------------------------------------------------------------

## No table open. The player sets the step themselves and rolls -- not a
## degraded mode, just the way a check works on one device.
func _test_solo_check_needs_no_table() -> void:
	var runner = _player_shell.checks
	check(runner != null, "the shell owns a check runner")
	if runner == null:
		return
	check_false(runner.has_table(), "with no table to ask")

	var skill := _skill(1)
	var score: Dictionary = _player_shell.rules.skill_score(_hero().raw(), skill)
	if not check_true(bool(score.get("usable", false)), "the test skill can be attempted"):
		return

	var resolved = null
	var driver := func() -> void:
		# The step dial, standing in for the GM.
		var dial = await _await_route(_player_shell, "check_step_route")
		if dial == null:
			return
		check_true(dial._stepper != null, "the player is offered a step dial")
		dial.close({"step": 2, "reason": "the ledge is wet"})

		# Then the tray.
		var tray = await _await_route(_player_shell, "dice_tray_route")
		if tray == null:
			return
		check_true(tray._roll_button != null, "and then the tray")
		check_true(
			tray._summary.text.contains("GM +2"),
			"which shows the step that was set -- got '%s'" % tray._summary.text
		)
		tray._on_roll_pressed()
		await _wait_for(func(): return not tray._resolved.is_empty(), 3000)
		tray.close(tray._resolved)
	driver.call_deferred()

	resolved = await runner.run(_hero(), skill)
	check(resolved != null, "a solo check resolves")
	if resolved == null:
		return

	check_eq(resolved.state, Check.STATE_RESOLVED, "and comes back settled")
	check_eq(resolved.gm_step, 2, "with the step the player set")
	check_eq(resolved.player_step, AlternityNum.as_int(score.get("step", 0)), "and the character's own")
	check_false(resolved.degree().is_empty(), "graded by the rules")
	check_true(
		resolved.degree() in ["Amazing", "Good", "Ordinary", "Marginal", "Failure", "Critical Failure"],
		"to one of the degrees the rules define -- got '%s'" % resolved.degree()
	)


# --- At a table ------------------------------------------------------------

func _test_open_the_table() -> void:
	var select = _screen(_gm_shell, "character_select")
	select.campaigns_opened.emit()
	await process_frame
	var campaigns = _screen(_gm_shell, "campaign_select")
	if not check(campaigns != null, "the GM reaches the campaign list"):
		return

	var session = Session.new("The Verge")
	_gm_shell.campaigns.save(session)
	campaigns._on_open_pressed(session.campaign_id)
	await process_frame
	var gm = _gm_screen()
	if not check(gm != null, "and opens the campaign"):
		return
	gm._toggle_hosting()
	await process_frame
	check_true(gm.is_hosting(), "the table is open")

	# The player joins.
	var player_select = _screen(_player_shell, "character_select")
	player_select.campaigns_opened.emit()
	await process_frame
	_screen(_player_shell, "campaign_select").join_requested.emit()
	await process_frame
	var join = _screen(_player_shell, "table_join")
	if not check(join != null, "the player reaches the join screen"):
		return
	join._name_field.text = "Alice"
	join._join("127.0.0.1", Transport.DEFAULT_PORT, "", "")

	var at_table := await _wait_for(func(): return _screen(_player_shell, "player_table") != null)
	check_true(at_table, "and joins the table")
	check_true(_player_shell.checks.has_table(), "so a check now has a GM to ask")


## The flow the whole feature was asked for.
func _test_player_asks_and_gm_rules() -> void:
	var gm = _gm_screen()
	if not check(gm != null and gm.is_hosting(), "the table is still open"):
		return

	var skill := _skill(1)
	var resolved = null

	var driver := func() -> void:
		# The GM's side: the request appears in their queue with the score.
		var arrived := await _wait_for(func(): return not gm._pending_checks.is_empty())
		if not check_true(arrived, "the request reaches the GM's queue"):
			return
		var pending: SkillCheck = gm._pending_checks[0]
		check_eq(pending.skill_label, _player_shell.rules.skill_label(skill), "naming the skill")
		check_true(pending.ordinary > 0, "and carrying the score to rule against")
		check_eq(String(gm._session.seat_for(pending.player_id).get("player_name", "")), "Alice",
			"attributed to the player who asked")

		# The GM rules: two steps harder.
		gm._on_rule_pressed(pending, 2, "the ledge is wet")
		check_true(gm._pending_checks.is_empty(), "and the queue empties")

		# The player's side: straight to the tray, no step dial -- the GM
		# answered, so there is nothing for the player to decide.
		var tray = await _await_route(_player_shell, "dice_tray_route", 2000)
		if tray == null:
			return
		check_true(
			tray._summary.text.contains("the ledge is wet"),
			"the tray shows the GM's reason -- got '%s'" % tray._summary.text
		)
		tray._on_roll_pressed()
		await _wait_for(func(): return not tray._resolved.is_empty(), 3000)
		tray.close(tray._resolved)
	driver.call_deferred()

	resolved = await _player_shell.checks.run(_hero(), skill)
	check(resolved != null, "the check resolves")
	if resolved == null:
		return
	check_eq(resolved.gm_step, 2, "with the step the GM set, not one the player chose")
	check_eq(resolved.reason, "the ledge is wet", "and the GM's reason")

	# And the settled result reaches the table as a fact.
	var landed := await _wait_for(func():
		for event in gm._session.events:
			if String(event.get("kind", "")) == Session.EVENT_ROLL:
				return true
		return false)
	check_true(landed, "the roll reaches the GM's log")
	if not landed:
		return

	var logged: Dictionary = {}
	for event in gm._session.events:
		if String(event.get("kind", "")) == Session.EVENT_ROLL:
			logged = event
	var carried: Dictionary = logged.get("payload", {}).get("check", {})
	check_false(carried.is_empty(), "carrying the whole check, not just a total")
	check_eq(AlternityNum.as_int(carried.get("gm_step", 0)), 2, "including what the GM added")
	check_false(String(carried.get("result", {}).get("degree", "")).is_empty(), "and the degree it came to")

	# The feed says what was attempted and how it went, not a bare number.
	gm._render_feed()
	await process_frame
	var line := String(gm._feed_list.get_child(0).text)
	check_true(line.contains(resolved.degree()), "the GM's feed shows the degree -- got '%s'" % line)
	check_true(line.contains("Alice"), "and who rolled it")


func _test_gm_refuses() -> void:
	var gm = _gm_screen()
	var skill := _skill(1)

	var driver := func() -> void:
		var arrived := await _wait_for(func(): return not gm._pending_checks.is_empty())
		if not check_true(arrived, "a second request reaches the GM"):
			return
		gm._on_refuse_check_pressed(gm._pending_checks[0])
	driver.call_deferred()

	var resolved = await _player_shell.checks.run(_hero(), skill)
	# A refusal ends the check rather than falling through to a roll. A player
	# who was told no must not end up throwing dice anyway.
	check(resolved == null, "a refused check does not roll")
	check_eq(_player_shell.router.depth(), 0, "and leaves no route open")


# --- The other direction ---------------------------------------------------

func _test_gm_calls_for_a_check() -> void:
	var gm = _gm_screen()
	var called := []
	_player_shell.checks.check_arrived.connect(func(check: SkillCheck): called.append(check))

	# A real skill out of the catalogue, not a typed string. That is the whole
	# change: an id crosses the wire, so the player's device can look the skill up
	# and work out what their own hero brings to it.
	var skill: Dictionary = _gm_shell.rules.broad_skills[0]
	var skill_label: String = _gm_shell.rules.skill_label(skill)
	var skill_id := AlternityNum.as_int(skill.get("id", -1), -1)

	var driver := func() -> void:
		var picker = await _await_route(_gm_shell, "skill_pick_route")
		if picker == null:
			return
		picker.close(skill)
		var dial = await _await_route(_gm_shell, "check_step_route")
		if dial == null:
			return
		dial.close({"step": 1, "reason": "the corridor is dark"})
	driver.call_deferred()

	await gm._on_call_check_pressed()
	var arrived := await _wait_for(func(): return not called.is_empty())
	check_true(arrived, "a called check reaches the player's device")
	if not arrived:
		return

	var incoming: SkillCheck = called[0]
	check_eq(incoming.origin, Check.ORIGIN_GM, "marked as the GM asking")
	check_eq(incoming.skill_label, skill_label, "naming what to roll")
	# The id is the part that matters. A typed name cannot be looked up, so every
	# modifier the character carried -- broad-skill bonus, species, mutations,
	# encumbrance, being dazed -- was silently dropped when this was a text box.
	check_eq(incoming.skill_id, skill_id, "and carrying the skill id, not just its name")
	check_true(incoming.skill_id >= 0, "which the player's device can look up")
	check_eq(incoming.gm_step, 1, "with the step already set")
	check_eq(incoming.reason, "the corridor is dark", "and the reason")
	# The GM's device has no copy of the character, so it cannot supply a score.
	check_eq(incoming.ordinary, 0, "and no score, which only the player's device has")
	check_false(incoming.is_rollable(), "so it is not rollable until that arrives")

	# It is in the log too, because the GM did it and it stands whether or not
	# anybody answers.
	var logged := false
	for event in gm._session.events:
		if String(event.get("kind", "")) == Session.EVENT_CHECK:
			logged = true
	check_true(logged, "and the call is logged")

	# Calling a check is the GM saying this skill matters right now, which is
	# what the shortcut row on the main screen is trying to predict.
	check_eq(gm.session().check_count(skill_id), 1, "the call is counted against that skill")

	# Ruling on the player's request earlier in this suite counted a skill too,
	# so this is not the only entry -- both are things the GM decided mattered.
	var top: Array = gm.session().most_checked(6)
	var listed := false
	for entry in top:
		if AlternityNum.as_int(entry["skill_id"]) == skill_id:
			listed = true
			check_eq(AlternityNum.as_int(entry["count"]), 1, "with the right count")
	check_true(listed, "so it appears among the most-checked skills")
	check_true(top.size() >= 2, "alongside the skill the GM ruled on earlier")
