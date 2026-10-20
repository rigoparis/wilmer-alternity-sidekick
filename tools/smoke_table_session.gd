extends "res://tools/test_harness.gd"
##
## Two shells in one process: a GM hosting and a player joining.
##
## Phase M2's checkpoint, as close as one machine can get to it -- a roll on the
## player device appearing on the GM's feed, a private line, an AP award landing
## on the player's own hero, and a mid-session reconnect that loses nothing.
##
## The one thing this cannot prove is the broadcast half of discovery, which
## does not loop back on one host; the player here joins by address, which is the
## supported path anyway. MULTIPLAYER.md's two-device check still stands for the
## rest.
##
## Both shells use scratch directories, and separate ones: a player device and a
## GM device do not share a character folder, and pointing them at the same one
## would hide exactly the bugs this suite exists to find.
##

const SHELL := preload("res://scenes/ui/app_shell.tscn")
const Session := preload("res://scripts/core/session/campaign_session.gd")
const Transport := preload("res://scripts/core/session/enet_transport.gd")

const GM_DIR := "user://__table_gm__/"
const GM_CAMPAIGNS := "user://__table_gm_campaigns__/"
const PLAYER_DIR := "user://__table_player__/"
const PLAYER_CAMPAIGNS := "user://__table_player_campaigns__/"

var _gm_shell
var _player_shell
var _gm
var _joined_player_id: String = ""


func _init() -> void:
	begin_async("table session", 4000)
	_run.call_deferred()


func _run() -> void:
	for dir_path in [GM_DIR, GM_CAMPAIGNS, PLAYER_DIR, PLAYER_CAMPAIGNS]:
		_wipe(dir_path)

	_gm_shell = _new_shell(GM_DIR, GM_CAMPAIGNS)
	_player_shell = _new_shell(PLAYER_DIR, PLAYER_CAMPAIGNS)
	await process_frame
	await process_frame

	await _test_gm_opens_the_table()
	await _test_player_joins()
	await _test_roll_reaches_the_gm_feed()
	await _test_private_line()
	await _test_ap_lands_on_the_committed_hero()
	await _test_a_round_of_combat()
	await _test_an_attack_lands()
	await _test_simultaneous_phase_damage()
	await _test_staged_damage_crash_recovery()
	await _test_defending()

	await _test_the_scene_ends()
	await _test_automatic_reconnect()
	await _test_back_from_table_confirms()
	await _test_reconnect_loses_nothing()
	await _test_cold_start_recovers_pending_work()
	await _test_protocol_resilience_and_isolation()
	await _test_leaving_closes_the_table()

	_teardown()
	for dir_path in [GM_DIR, GM_CAMPAIGNS, PLAYER_DIR, PLAYER_CAMPAIGNS]:
		_wipe(dir_path)
	finish()


func _new_shell(store_dir: String, campaign_dir: String):
	var shell = SHELL.instantiate()
	shell.store_directory = store_dir
	shell.campaign_directory = campaign_dir
	root.add_child(shell)
	return shell


func _teardown() -> void:
	for shell in [_player_shell, _gm_shell]:
		if shell != null and is_instance_valid(shell):
			shell.queue_free()
	_gm_shell = null
	_player_shell = null


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


## Wait on an outcome rather than on a frame count. Both shells poll themselves
## from _process, so all this has to do is let frames pass.
func _wait_for(condition: Callable, max_frames: int = 300) -> bool:
	for _i in max_frames:
		if condition.call():
			return true
		await process_frame
	return condition.call()


## The player's screen at a table is their own sheet.
func _player_sheet():
	return _screen(_player_shell, "character_sheet")


## The live table the shell holds, which is where the state that used to live on
## a table screen now sits.
func _table():
	return _player_shell.table


## Answer the "which hero are you playing" prompt the way a person would.
func _commit_hero(file_name: String = "") -> void:
	var responder := func() -> void:
		var route = await _await_player_route("commit_character_route")
		if route == null:
			return
		route.close({"create": true} if file_name.is_empty() else {"file_name": file_name})
	responder.call_deferred()


func _await_player_route(fragment: String, max_frames: int = 240):
	for _i in max_frames:
		var route = _player_shell.router._host.top_route()
		if route != null and String(route.get_script().resource_path).contains(fragment):
			return route
		await process_frame
	return null


## Answer whatever route the GM shell has open, the way a person would.
func _answer_gm_route(result: Variant) -> void:
	var responder := func() -> void:
		await process_frame
		var route = _gm_shell.router._host.top_route()
		if route != null:
			route.close(result)
	responder.call_deferred()


## Re-found rather than cached.
##
## The shell owns screen lifetime and rebuilds on a resize, so a reference held
## across frames can be stale. Caching one hid that behind "previously freed"
## rather than showing which step lost it.
func _gm_screen():
	return _screen(_gm_shell, "gm_screen")


## The one seat that is not the GM's.
##
## Opening the table gives the campaign a GM seat if it has none, so the player
## is not simply "the first seat" -- and assuming they were is how a test starts
## asserting about the GM's own row.
func _player_seat() -> Dictionary:
	for seat in _gm_screen().session().seats:
		if not bool(seat.get("is_gm", false)):
			return seat
	return {}


# --- Hosting ---------------------------------------------------------------

func _test_gm_opens_the_table() -> void:
	var select = _screen(_gm_shell, "character_select")
	if not check(select != null, "the GM shell starts on the character list"):
		return
	select.campaigns_opened.emit()
	await process_frame

	var campaigns = _screen(_gm_shell, "campaign_select")
	if not check(campaigns != null, "the GM reaches the campaign list"):
		return

	var session = Session.new("The Verge")
	_gm_shell.campaigns.save(session)
	campaigns._on_open_pressed(session.campaign_id)
	await process_frame

	_gm = _gm_screen()
	if not check(_gm != null, "the GM opens the campaign"):
		return
	check_false(_gm.is_hosting(), "a campaign starts closed, usable on one device")

	_gm._toggle_hosting()
	await process_frame
	check_true(_gm.is_hosting(), "the GM can open the table")
	check_true(_gm_screen().transport() != null, "which brings up a transport")
	check_eq(_gm_screen().transport().local_role(), Transport.Role.GM, "in the GM role")

	# A table with no GM seat has nowhere to deliver a private line, so opening
	# one makes this device the GM if the campaign did not already say who was.
	check_false(_gm_screen().session().gm_seat().is_empty(), "opening the table seats a GM")
	check_eq(_gm_screen().session().seats.size(), 1, "and only that one seat so far")


# --- Joining ---------------------------------------------------------------

func _test_player_joins() -> void:
	var select = _screen(_player_shell, "character_select")
	if not check(select != null, "the player shell starts on the character list"):
		return
	select.campaigns_opened.emit()
	await process_frame

	var campaigns = _screen(_player_shell, "campaign_select")
	if not check(campaigns != null, "the player reaches the campaign list"):
		return
	campaigns.join_requested.emit()
	await process_frame

	var join = _screen(_player_shell, "table_join")
	if not check(join != null, "which offers joining somebody else's table"):
		return
	check_eq(_player_shell.identity.player_name(), "", "this device has no name yet")

	join._name_field.text = "Alice"
	_commit_hero()
	join._join("127.0.0.1", Transport.DEFAULT_PORT, "", "")
	var at_table := await _wait_for(func(): return _table() != null and _table().doc != null)
	check_true(at_table, "joining commits a hero and reaches the table")
	if not at_table:
		return

	# The player's main screen is their own sheet, with the table as a tab on it.
	# It used to be a screen of its own, which meant a player in a months-long
	# campaign could look at the table or at their character, never both.
	check(_player_sheet() != null, "and the screen showing is their character sheet")
	var tab_ids: Array = []
	for definition in CharacterSheetScreen.TABS:
		tab_ids.append(String(definition["id"]))
	check_true(tab_ids.has("table"), "which has a Table tab among its tabs")

	check_eq(_player_shell.identity.player_name(), "Alice", "the device remembers the name given")
	check_eq(_gm_screen().session().seats.size(), 2, "the GM seated them alongside their own seat")
	_joined_player_id = String(_player_seat().get("player_id", ""))
	check_eq(String(_player_seat().get("player_name", "")), "Alice", "under the name they gave")
	check_false(bool(_player_seat().get("is_gm", false)), "and a joining player is not made GM")

	# Identity is what makes next week work, so it has to be on disk now rather
	# than only in memory.
	var campaign_id: String = _gm_screen().session().campaign_id
	check_eq(
		_player_shell.identity.player_id_for(campaign_id), _joined_player_id,
		"the device stored the id the GM issued"
	)
	var reloaded = PlayerIdentity.new(PLAYER_DIR)
	check_eq(
		reloaded.player_id_for(campaign_id), _joined_player_id,
		"and it survives a restart, which is what a reconnect depends on"
	)
	check_eq(reloaded.player_name(), "Alice", "as does the name")

	# The player's device must not have acquired a campaign file. One campaign,
	# one owner -- the GM's.
	check_eq(_player_shell.campaigns.list().size(), 0, "a player device keeps no campaign of its own")


# --- Play ------------------------------------------------------------------

func _test_roll_reaches_the_gm_feed() -> void:
	var table = _table()
	if not check(table != null, "the player is at the table"):
		return

	var before: int = _gm_screen().session().events.size()
	table.transport.send_roll({
		"notation": "d20+d4",
		"dice": [17, 3],
		"total": 20,
		"label": "Action check",
		"source": "physical",
	})

	var landed := await _wait_for(func(): return _gm_screen().session().events.size() > before)
	check_true(landed, "the roll reaches the GM")
	if not landed:
		return

	var logged: Dictionary = _gm_screen().session().events[_gm_screen().session().events.size() - 1]
	check_eq(String(logged.get("kind", "")), Session.EVENT_ROLL, "as a roll event")
	check_eq(AlternityNum.as_int(logged.get("payload", {}).get("total", 0)), 20, "with the settled total")
	check_eq(String(logged.get("player_id", "")), _joined_player_id, "attributed to the player's stable id")

	# It has to be visible, not merely stored.
	var lines: Array = []
	for child in _gm_screen()._feed_list.get_children():
		lines.append(child.text)
	check_true(lines.size() > 0, "the GM's feed has something in it")
	check_true(String(lines[0]).contains("Action check"), "the newest line is the roll")
	check_true(String(lines[0]).contains("20"), "showing its total")
	check_true(String(lines[0]).contains(_table().doc.get_hero_name()), "and naming the character, not an id")

	# And it must be on disk without waiting for anyone to press save.
	var stored = _gm_shell.campaigns.load_session(_gm_screen().session().campaign_id)
	check_eq(
		AlternityNum.as_int(stored.events[stored.events.size() - 1].get("payload", {}).get("total", 0)), 20,
		"the roll is flushed to the log as it arrives"
	)


func _test_private_line() -> void:
	var table = _table()
	var before: int = _gm_screen().session().events.size()

	table.send_chat("can I check for traps quietly?", true)

	var landed := await _wait_for(func(): return _gm_screen().session().events.size() > before)
	check_true(landed, "a private line reaches the GM")
	if not landed:
		return

	var logged: Dictionary = _gm_screen().session().events[_gm_screen().session().events.size() - 1]
	var gm_seat_id := String(_gm_screen().session().gm_seat().get("player_id", ""))
	# The player device never learns seat ids, so it addresses the GM by a
	# sentinel and the host resolves it. What lands in the log must be the real
	# seat, or events_for() would never find it again.
	check_eq(String(logged.get("payload", {}).get("to", "")), gm_seat_id,
		"addressed to the GM's actual seat, not to the sentinel the client sent")
	check_ne(String(logged.get("payload", {}).get("to", "")), Transport.TO_GM, "the sentinel does not reach the log")

	var lines: Array = []
	for child in _gm_screen()._feed_list.get_children():
		lines.append(child.text)
	check_true(String(lines[0]).contains("private"), "the GM's feed marks it as private")


## The conflict rule, made concrete.
##
## The GM awards the points; the player's device is what writes them into a
## character file. The GM never touches a hero they cannot see.
##
## There is no picker asking which hero receives them. A player at a table is
## playing the one they committed, so that was a question with a single possible
## answer -- and a button somebody had to remember to press before their sheet
## was right.
func _test_ap_lands_on_the_committed_hero() -> void:
	var table = _table()
	if not check(table.doc != null, "a hero is committed to this table"):
		return

	var before: int = AlternityNum.as_int(table.doc.raw().get("achievement_points", 0))
	var applied := []
	table.ap_applied.connect(func(amount: int, reason: String): applied.append([amount, reason]))

	# Exactly what the GM screen does when the award dialog is confirmed.
	var awarded: Dictionary = _gm_screen().session().award_ap(_joined_player_id, 3, Session.AP_REASON_HEROISM)
	_gm_screen().transport()._deliver(awarded)
	_gm_shell.campaigns.save(_gm_screen().session())

	var arrived := await _wait_for(func(): return not applied.is_empty())
	check_true(arrived, "the award reaches the player device")
	if not arrived:
		return
	check_eq(AlternityNum.as_int(applied[0][0]), 3, "with the right amount")
	check_eq(String(applied[0][1]), Session.AP_REASON_HEROISM, "and the reason")

	check_eq(
		AlternityNum.as_int(table.doc.raw().get("achievement_points", 0)), before + 3,
		"and lands on the committed hero without being asked about"
	)

	# On disk, not just in memory: the player closing the app should not lose it.
	var reloaded = _player_shell.store.load_doc(table.doc.source_file)
	check(reloaded != null, "the hero was saved")
	if reloaded != null:
		check_eq(
			AlternityNum.as_int(reloaded.raw().get("achievement_points", 0)), before + 3,
			"with the points written into the character file"
		)

	# It shows in the feed, said to them rather than about an id.
	var lines: Array = []
	for event in table.recent():
		lines.append(table.describe(event))
	check_true(lines.size() > 0, "the player's feed has something in it")
	check_true(String(lines[0]).contains("3 AP"), "and shows the award")
	check_true(String(lines[0]).contains(Session.AP_REASON_HEROISM), "and what it was for")
	check_true(String(lines[0]).begins_with(table.doc.get_hero_name()), "addressed by character name rather than an id")

	# The GM's copy is a ledger of what was given, not a second copy of the
	# character. Both counting the same points is correct.
	check_eq(_gm_screen().session().get_seat_ap(_joined_player_id), 3, "the GM's ledger still records the award")
	check_eq(_gm_shell.store.list().size(), 0, "and the GM device never gained a character file")


# --- Combat ----------------------------------------------------------------

## A whole round, driven from the GM's screen and read on the player's.
##
## The point is that both sides agree about a structure neither of them owns
## alone: the GM assigns the phases, the player supplies the check that decides
## theirs, and what each screen shows is derived from the same round.
func _test_a_round_of_combat() -> void:
	var gm = _gm_screen()
	var table = _table()
	if not check(gm != null and table != null, "the GM and a player are at the table"):
		return

	await _start_selected_combat(gm)
	var started := await _wait_for(func(): return table.active_round != null)
	check_true(started, "starting combat reaches the player")
	if not started:
		return

	# Only the player is in it: the GM runs the game rather than playing in it.
	check_eq(table.active_round.combatants.size(), 1, "the player is the only combatant")
	check_eq(gm._fight.combatants.size(), 1, "and the GM agrees")
	check_true(table.owes_action_check(), "the round is waiting on their action check")
	check_false(gm._fight.has_all_checks(), "which the GM can see is outstanding")

	# The round is on the campaign, not just on the screen, so reopening it later
	# does not lose whose turn it is.
	check_true(gm.session().has_round(), "the fight is stored on the campaign")
	var stored = _gm_shell.campaigns.load_session(gm.session().campaign_id)
	check_true(stored.has_round(), "and persisted, so it survives a reopen")

	# The player answers. Sent through the session rather than the tray, because
	# what is being tested is the round, not the physics.
	var answer := SkillCheck.new(table.transport.local_player_id(), SkillCheck.ORIGIN_GM)
	answer.ordinary = 13
	answer.resolve({"degree": "Good", "total": 6, "is_critical_failure": false})
	table.send_action_check(answer)

	var recorded := await _wait_for(func(): return _gm_screen()._fight.has_all_checks())
	check_true(recorded, "the check reaches the GM")
	if not recorded:
		return
	gm = _gm_screen()
	check_eq(
		String(gm._fight.combatant(_joined_player_id).get("degree", "")), "good",
		"and sets the phase they earned"
	)
	check_eq(
		AlternityNum.as_int(gm._fight.combatant(_joined_player_id).get("check_score", 0)), 13,
		"with the score that orders the phase"
	)

	# The GM starts the round; the player sees the board.
	gm._on_start_round_pressed()
	var running := await _wait_for(func(): return table.active_round != null and table.active_round.state == ActionRound.STATE_ACTIVE)
	check_true(running, "starting the round reaches the player")
	if not running:
		return
	check_eq(table.active_round.phase(), "amazing", "which opens at the Amazing phase")
	check_false(table.acting_now(), "where a Good roller does not act")
	check_false(table.owes_action_check(), "and owes nothing further")

	# Advancing to their phase.
	_gm_screen()._on_advance_phase_pressed()
	var theirs := await _wait_for(func(): return table.active_round != null and table.active_round.phase() == "good")
	check_true(theirs, "the phase change reaches the player")
	if not theirs:
		return
	check_true(table.acting_now(), "and now it is their turn")

	# Ending the fight puts the board away rather than leaving a stale one up.
	_gm_screen()._on_end_combat_pressed()
	var over := await _wait_for(func(): return table.active_round == null)
	check_true(over, "ending combat reaches the player")
	check_false(gm.session().has_round(), "and the campaign forgets the fight")


# --- An attack, both halves ------------------------------------------------

## The round trip the ownership rule is really about.
##
## The GM declares and rolls; the damage is applied on the device that owns the
## character, by that device, and what comes back is an outcome rather than a
## sheet. Nothing here goes through the dice tray: what is being tested is who
## does what, not the physics.
func _test_an_attack_lands() -> void:
	var gm = _gm_screen()
	var table = _table()
	if not check(gm != null and table != null and table.doc != null, "a player is at the table with a hero"):
		return

	var before := AlternityNum.as_int(table.doc.raw().get("damage", {}).get("wound", 0))

	var attack := CombatAttack.declare(
		_joined_player_id, "A thug", "Charge pistol", "Good", 6, "w", "hi", "O"
	)
	gm.transport().send_attack(attack.to_dict(), _joined_player_id)

	var arrived := await _wait_for(func(): return not _table().incoming_attacks.is_empty())
	check_true(arrived, "the attack reaches the seat it was addressed to")
	if not arrived:
		return

	table = _table()
	var landed: CombatAttack = table.next_attack()
	check_eq(landed.attacker_name, "A thug", "carrying who swung")
	check_eq(landed.damage, 6, "and what was rolled")
	check_false(landed.is_resolved(), "and nothing has been applied yet")
	check_eq(
		AlternityNum.as_int(table.doc.raw().get("damage", {}).get("wound", 0)), before,
		"the character is untouched until this device does it"
	)

	# And the player has something to press. The card is on the sheet they are
	# already looking at, not on a screen they have to go and find.
	var sheet = _player_sheet()
	if sheet != null:
		sheet._select_tab("table")
		await process_frame
		await process_frame
		var button := _find_named(sheet, "ResolveAttackButton")
		check(button != null, "the Table tab offers a way to resolve it")

	# The knockout check is asked for before the damage, and a Good hit does not
	# force one.
	check_false(
		bool(table.knockout_check_for(landed).get("required", false)),
		"a Good hit forces no endurance check"
	)

	# Two points of armor, as though a layer had been rolled here.
	var outcome: Dictionary = table.apply_attack(landed, 2)
	check_eq(AlternityNum.as_int(outcome.get("primary_damage", 0)), 4, "the armor comes off the damage")
	check_eq(
		AlternityNum.as_int(table.doc.raw().get("damage", {}).get("wound", 0)), before + 4,
		"and the rest lands on this device's own hero"
	)
	check_true(table.incoming_attacks.is_empty(), "and the attack is no longer waiting")

	table.report_attack(landed, 2, outcome)
	var logged := await _wait_for(func():
		for event in _gm_screen().session().events:
			if String(event.get("kind", "")) == CampaignSession.EVENT_ATTACK:
				return true
		return false)
	check_true(logged, "and the outcome reaches the GM")
	if not logged:
		return

	gm = _gm_screen()
	var recorded: Dictionary = {}
	for event in gm.session().events:
		if String(event.get("kind", "")) == CampaignSession.EVENT_ATTACK:
			recorded = event
	var resolved := CombatAttack.from_dict(recorded.get("payload", {}))
	check_eq(String(recorded.get("player_id", "")), _joined_player_id, "against the seat it landed on")
	check_true(resolved.is_resolved(), "resolved")
	check_eq(AlternityNum.as_int(resolved.result.get("absorbed", 0)), 2, "saying what the armor stopped")
	check_eq(AlternityNum.as_int(resolved.result.get("primary_damage", 0)), 4, "and what got through")
	check_false(bool(resolved.result.get("knocked_out", false)), "and that they are still standing")
	check_false(resolved.result.has("damage"), "and nothing about their sheet")

	# The GM's copy of the character has to follow the damage, or the roster will
	# say Unhurt at somebody who is bleeding.
	var followed := await _wait_for(func():
		var held = CharacterSnapshot.character_of(_gm_screen().session().committed_character(_joined_player_id))
		return AlternityNum.as_int(held.get("damage", {}).get("wound", 0)) == before + 4)
	check_true(followed, "and the GM's copy of the character follows it")

	# A miss travels too, and clearing it away costs the character nothing.
	var missed := CombatAttack.declare(_joined_player_id, "A thug", "Charge pistol", "Failure", 0, "w", "hi", "O")
	_gm_screen().transport().send_attack(missed.to_dict(), _joined_player_id)
	var missed_arrived := await _wait_for(func(): return not _table().incoming_attacks.is_empty())
	check_true(missed_arrived, "a miss reaches them as well")
	if not missed_arrived:
		return
	var shrugged: CombatAttack = _table().next_attack()
	check_false(shrugged.hits(), "and says plainly that it missed")
	_table().apply_attack(shrugged, 0)
	_table().report_attack(shrugged, 0, {})
	check_eq(
		AlternityNum.as_int(_table().doc.raw().get("damage", {}).get("wound", 0)), before + 4,
		"applying a miss marks nothing"
	)
	check_true(_table().incoming_attacks.is_empty(), "and it stops waiting")

	_gm_screen()._on_end_combat_pressed()
	await _wait_for(func(): return _table().active_round == null)


func _test_simultaneous_phase_damage() -> void:
	var gm = _gm_screen()
	var table = _table()
	if not check(gm != null and table != null and table.doc != null, "a player is at the table with a hero"):
		return

	# Start combat round
	gm._fight = ActionRound.new(1)
	gm._fight.add_combatant(_joined_player_id, "Player", 2, ActionRound.KIND_PLAYER)
	gm._fight.record_check(_joined_player_id, "good", 14, 5)
	gm._publish_round()
	gm._on_start_round_pressed()
	gm._on_advance_phase_pressed() # Now in Good phase

	var running := await _wait_for(func(): return table.active_round != null and table.active_round.phase() == "good")
	check_true(running, "combat is in Good phase on player side")
	if not running:
		return

	var before_wound := AlternityNum.as_int(table.doc.raw().get("damage", {}).get("wound", 0))

	# Attack declared in Good phase against player
	var attack := CombatAttack.declare(_joined_player_id, "Alien", "Plasma blast", "Good", 6, "w", "hi", "O")
	attack.round_id = gm._fight.round_id
	attack.phase = "good"
	gm.transport().send_attack(attack.to_dict(), _joined_player_id)

	var arrived := await _wait_for(func(): return not _table().incoming_attacks.is_empty())
	check_true(arrived, "combat attack reaches player")
	if not arrived:
		return

	var landed: CombatAttack = table.next_attack()
	check_eq(landed.phase, "good", "attack carries active phase")

	# Player resolves attack with 2 points absorbed
	var outcome: Dictionary = table.apply_attack(landed, 2)
	check_true(table.is_phase_staging_active(landed), "phase staging is active during combat phase")
	check_true(table.has_staged_damage(), "attack damage is staged")
	check_eq(
		AlternityNum.as_int(table.doc.raw().get("damage", {}).get("wound", 0)), before_wound,
		"player doc is untouched during the phase per PHB p. 50 simultaneous resolution"
	)
	check_eq(table.rules.dazed_penalty(table.doc.raw()), 0, "no same-phase dazed penalty applied to player doc")


	table.report_attack(landed, 2, outcome)
	var resolved_by_gm := await _wait_for(func():
		return _gm_screen().session().pending_attacks_for(_joined_player_id).is_empty()
	)
	check_true(resolved_by_gm, "attack resolved on GM session")

	# GM advances phase from Good to Ordinary
	_gm_screen()._on_advance_phase_pressed()
	var advanced := await _wait_for(func(): return table.active_round != null and table.active_round.phase() == "ordinary")

	check_true(advanced, "phase advances to ordinary on player side")

	check_false(table.has_staged_damage(), "staged damage committed upon phase advance")
	check_eq(
		AlternityNum.as_int(table.doc.raw().get("damage", {}).get("wound", 0)), before_wound + 4,
		"committed damage now appears on player doc in next phase"
	)

	# Clean up combat
	_gm_screen()._on_end_combat_pressed()
	await _wait_for(func(): return table.active_round == null)


func _test_staged_damage_crash_recovery() -> void:
	var gm = _gm_screen()
	var table = _table()
	if not check(gm != null and table != null and table.doc != null, "player and GM are ready"):
		return

	# Start combat round in Good phase
	gm._fight = ActionRound.new(2)
	gm._fight.add_combatant(_joined_player_id, "Player", 2, ActionRound.KIND_PLAYER)
	gm._fight.record_check(_joined_player_id, "good", 14, 5)
	gm._publish_round()
	gm._on_start_round_pressed()
	gm._on_advance_phase_pressed() # Good phase

	var running := await _wait_for(func(): return table.active_round != null and table.active_round.phase() == "good")
	if not check(running, "combat is in Good phase"):
		return

	# Reset damage on doc so we test clean staging without hitting track caps
	table.doc.apply([CharacterDoc.DAMAGE], func(c):
		c["damage"] = {"stun": 0, "wound": 0, "mortal": 0, "fatigue": 0}
		c["applied_attacks"] = []
	)
	table.store.save(table.doc)
	var before_wound := AlternityNum.as_int(table.doc.raw().get("damage", {}).get("wound", 0))

	# Attack declared in Good phase
	var attack := CombatAttack.declare(_joined_player_id, "Boss", "Heavy Laser", "Good", 6, "w", "hi", "O")
	attack.round_id = gm._fight.round_id
	attack.phase = "good"
	gm.transport().send_attack(attack.to_dict(), _joined_player_id)

	var arrived := await _wait_for(func(): return not _table().incoming_attacks.is_empty())
	if not check(arrived, "heavy attack reaches player"):
		return

	var landed: CombatAttack = table.next_attack()
	var outcome: Dictionary = table.apply_attack(landed, 2)
	table.report_attack(landed, 2, outcome)

	check_true(table.has_staged_damage(), "attack is staged in memory")
	check_eq(AlternityNum.as_int(table.doc.raw().get("damage", {}).get("wound", 0)), before_wound, "doc unchanged before commit")

	# Simulate crash / process restart by constructing a fresh TableSession with a fresh PlayerIdentity loaded from disk
	var cid: String = table.campaign_id()
	var reloaded_ident := PlayerIdentity.new(table.identity.directory())
	var fresh_doc = table.store.load_doc(table.doc.source_file)
	var fresh_session := TableSession.new(null, reloaded_ident, table.store, table.rules, table.campaign_name)
	fresh_session.doc = fresh_doc

	check_true(fresh_session.has_staged_damage(), "fresh session recovers staged attacks from uncommitted journal")
	check_eq(AlternityNum.as_int(fresh_doc.raw().get("damage", {}).get("wound", 0)), before_wound, "fresh doc still has uncommitted wounds")

	# Reconcile from host where attack is still pending or not should NOT erase uncommitted attacks
	reloaded_ident.reconcile_attacks(cid, [])
	check_false(reloaded_ident.uncommitted_attacks(cid).is_empty(), "reconciliation refuses to erase uncommitted attacks")

	# Commit staged damage on fresh session
	fresh_session.commit_staged_damage()
	check_eq(AlternityNum.as_int(fresh_doc.raw().get("damage", {}).get("wound", 0)), before_wound + 4, "committed damage applied to character")
	check_true(reloaded_ident.uncommitted_attacks(cid).is_empty(), "uncommitted journal cleared after commit")
	check_true(fresh_doc.has_applied_attack(landed.attack_id), "character doc marks applied attack ID")

	# Re-commit / repeated crash recovery does not reapply duplicate damage
	fresh_session.commit_staged_damage()
	check_eq(AlternityNum.as_int(fresh_doc.raw().get("damage", {}).get("wound", 0)), before_wound + 4, "no duplicate damage on re-commit")

	# Clean up combat
	_gm_screen()._on_end_combat_pressed()
	await _wait_for(func(): return table.active_round == null)




## Depth-first search for a named node, for asserting a screen built a control.
func _find_named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted)
		if found != null:
			return found
	return null


# --- Defending -------------------------------------------------------------

## The two defences, which are not the same shape.
##
## A dodge is declared once and covers the round, so it travels to the GM on its
## own and lands on the round -- the GM rolls the attacks, so the penalty has to
## be in their hands before the next one. A parry answers a single attack and is
## decided on the device that owns the character, like everything else about it.
##
## And the actions dial, which is the GM's: nothing in the app can know
## everything that costs an action, so the number is theirs to set.
func _test_defending() -> void:
	var gm = _gm_screen()
	var table = _table()
	if not check(gm != null and table != null and table.doc != null, "a player is at the table"):
		return

	await _start_selected_combat(gm)
	var started := await _wait_for(func(): return _table().active_round != null)
	if not check(started, "combat starts"):
		return
	table = _table()

	var answer := SkillCheck.new(table.transport.local_player_id(), SkillCheck.ORIGIN_GM)
	answer.ordinary = 13
	answer.resolve({"degree": "Good", "total": 6, "is_critical_failure": false})
	table.send_action_check(answer)
	var recorded := await _wait_for(func(): return _gm_screen()._fight.has_all_checks())
	if not check(recorded, "the action check reaches the GM"):
		return
	_gm_screen()._on_start_round_pressed()
	var running := await _wait_for(func():
		return _table().active_round != null and _table().active_round.state == ActionRound.STATE_ACTIVE)
	if not check(running, "the round starts"):
		return

	# The GM's dial. It reaches the player, because the phase board is drawn from
	# the round the GM sends and the number decides which phases they reach.
	table = _table()
	var before: int = table.active_round.actions_of(_joined_player_id)
	_gm_screen()._on_actions_pressed(_joined_player_id, -1)
	var fewer := await _wait_for(func():
		return _table().active_round.actions_of(_joined_player_id) == before - 1)
	check_true(fewer, "the GM taking an action away reaches the player")
	_gm_screen()._on_actions_pressed(_joined_player_id, 1)
	var restored := await _wait_for(func():
		return _table().active_round.actions_of(_joined_player_id) == before)
	check_true(restored, "and so does giving it back")

	# The dodge, declared on the player's device.
	table = _table()
	check_false(table.is_dodging(), "nobody is dodging to begin with")
	var dodge := SkillCheck.new(table.transport.local_player_id(), SkillCheck.ORIGIN_GM)
	dodge.ordinary = 11
	dodge.resolve({"degree": "Good", "total": 5, "is_success": true})
	table.send_dodge(dodge)
	check_true(table.is_dodging(), "the local board says so at once, without waiting for the GM")

	var told := await _wait_for(func(): return _gm_screen()._fight.is_dodging(_joined_player_id))
	check_true(told, "and the GM is told")
	if not told:
		return
	check_eq(
		_gm_screen()._fight.dodge_of(_joined_player_id), "Good",
		"with the degree, which is what the penalty is worked out from"
	)
	check_eq(
		_gm_screen()._rules.combat.dodge_step("Good"), 2,
		"a Good dodge is worth two steps against everyone shooting at them"
	)

	# Which the GM's own copy keeps, so a reopened campaign does not forget it.
	var stored = _gm_shell.campaigns.load_session(_gm_screen().session().campaign_id)
	check_true(
		ActionRound.from_dict(stored.current_round()).is_dodging(_joined_player_id),
		"and it is stored with the round"
	)

	# A parry: one attack, decided here, and it stops the attack outright when it
	# is as good as it.
	var wound_before := AlternityNum.as_int(table.doc.raw().get("damage", {}).get("wound", 0))
	var swung := CombatAttack.declare(_joined_player_id, "A thug", "Knife", "Ordinary", 5, "w", "li", "O")
	swung.is_melee = true
	_gm_screen().transport().send_attack(swung.to_dict(), _joined_player_id)
	var incoming := await _wait_for(func(): return not _table().incoming_attacks.is_empty())
	if not check(incoming, "the melee attack arrives"):
		return

	table = _table()
	var parried: CombatAttack = table.next_attack()
	check_true(
		_gm_screen()._rules.combat.parry_blocks(parried.degree, "Good"),
		"a Good parry beats an Ordinary attack"
	)
	check_false(
		_gm_screen()._rules.combat.parry_blocks(parried.degree, "Marginal"),
		"a marginal one does not"
	)

	var outcome: Dictionary = table.apply_attack(parried, 0, true)
	check_true(outcome.is_empty(), "a parried attack has nothing to apply")
	check_eq(
		AlternityNum.as_int(table.doc.raw().get("damage", {}).get("wound", 0)), wound_before,
		"so the character is untouched"
	)
	table.report_attack(parried, 0, outcome, false, true)
	check_true(parried.describe().contains("parried"), "and the line says it was parried")

	var reported := await _wait_for(func():
		for event in _gm_screen().session().events:
			var payload = event.get("payload", {})
			if typeof(payload) == TYPE_DICTIONARY and bool(payload.get("result", {}).get("parried", false)):
				return true
		return false)
	check_true(reported, "and the GM is told it was turned aside")

	# A new round is a new dodge: it covers this one and no more.
	while not _gm_screen()._fight.is_finished():
		await _gm_screen()._on_advance_phase_pressed()
	_gm_screen()._on_next_round_pressed()
	var fresh := await _wait_for(func():
		return _table().active_round != null and _table().active_round.number > 1)
	check_true(fresh, "the next round reaches the player")
	check_false(_table().is_dodging(), "and they are not still dodging in it")

	_gm_screen()._on_end_combat_pressed()
	await _wait_for(func(): return _table().active_round == null)


# --- The scene ending ------------------------------------------------------

## The GM says when the shooting stopped; each device works out what that means
## for its own character.
##
## Stun is the one track that comes back on its own and it comes back all at
## once, taking the unconsciousness with it. Nothing else moves: a scene ending
## does not mend a wound, and a dying character is still dying when the room
## goes quiet.
func _test_the_scene_ends() -> void:
	var gm = _gm_screen()
	var table = _table()
	if not check(gm != null and table != null and table.doc != null, "a player is at the table"):
		return

	# Hurt them on their own device, the way an attack would have.
	table.doc.apply([CharacterDoc.DAMAGE], func(character):
		var tracks: Dictionary = character.get("damage", {})
		tracks["stun"] = AlternityNum.as_int(_player_shell.rules.durability(character).get("stun", 0))
		tracks["wound"] = 4
		tracks["mortal"] = 1
		character["damage"] = tracks)
	check_true(_player_shell.rules.combat.is_knocked_out(table.doc.raw()), "a full stun track is unconsciousness")

	gm._on_end_scene_pressed()
	var cleared := await _wait_for(func():
		return AlternityNum.as_int(_table().doc.raw().get("damage", {}).get("stun", 0)) == 0)
	check_true(cleared, "ending the scene clears the stun on the player's own device")
	if not cleared:
		return

	table = _table()
	check_false(_player_shell.rules.combat.is_knocked_out(table.doc.raw()), "so they are awake again")
	check_eq(
		AlternityNum.as_int(table.doc.raw().get("damage", {}).get("wound", 0)), 4,
		"wounds are untouched"
	)
	check_true(_player_shell.rules.combat.is_dying(table.doc.raw()), "and a dying hero is still dying")

	# It is written to the player's own file, not merely to the copy in memory.
	var reopened = _player_shell.store.load_doc(table.doc.source_file)
	if reopened != null:
		check_eq(
			AlternityNum.as_int(reopened.raw().get("damage", {}).get("stun", 0)), 0,
			"and saved, so it survives closing the app"
		)

	# The GM's copy follows, because their roster reads the character they hold.
	var followed := await _wait_for(func():
		var held = CharacterSnapshot.character_of(_gm_screen().session().committed_character(_joined_player_id))
		return AlternityNum.as_int(held.get("damage", {}).get("stun", 0)) == 0)
	check_true(followed, "and the GM's copy follows it")

	# It is in the log, so a player who reconnects is replayed it rather than
	# quietly keeping their stun.
	var logged := false
	for event in _gm_screen().session().events:
		if String(event.get("kind", "")) == CampaignSession.EVENT_SCENE_END:
			logged = true
	check_true(logged, "and the scene ending is in the log")


# --- Reconnect -------------------------------------------------------------

func _test_automatic_reconnect() -> void:
	var table = _table()
	var transport = table.transport
	var seats_before: int = _gm_screen().session().seats.size()
	# Model the socket Android leaves behind after suspending the process beyond
	# its timeout. The TableSession must reopen this same transport, so every
	# signal consumer and the visible character sheet remains attached.
	transport._peer.close()
	var scheduled := await _wait_for(func(): return table._reconnect_due_msec > 0)
	check_true(scheduled, "a dropped socket schedules a reconnect")
	if not scheduled:
		return
	# Do not make a regression test wait on wall-clock backoff.
	table._reconnect_due_msec = Time.get_ticks_msec()
	var restored := await _wait_for(func(): return table.is_connected_to_table())
	check_true(restored, "the table reconnects without leaving the character sheet")
	check_true(table.transport == transport, "reconnect keeps the existing session wiring")
	check_eq(_gm_screen().session().seats.size(), seats_before, "automatic reconnect does not add a seat")


func _test_back_from_table_confirms() -> void:
	var before = _table()
	check_false(
		bool(ProjectSettings.get_setting("application/config/quit_on_go_back", true)),
		"Android Back does not auto-quit before the shell can handle it"
	)
	_player_shell._handle_back()
	await process_frame
	check_eq(_player_shell.router.depth(), 1, "Back at a table asks before disconnecting")
	check_true(_table() == before, "the table remains connected while the question is open")
	var route = _player_shell.router._host.top_route()
	if route != null:
		route.close(null)
	await process_frame
	check_true(_table() == before, "choosing Stay keeps the player at the table")


## Phase M2's checkpoint: a mid-session reconnect that loses nothing.
func _test_reconnect_loses_nothing() -> void:
	var table = _table()
	var campaign_id: String = _gm_screen().session().campaign_id
	# Leave while initiative is still owed. Rejoining has to restore this current
	# state, not merely the event history.
	await _start_selected_combat(_gm_screen())
	var rolling := await _wait_for(func(): return table.active_round != null and table.owes_action_check())
	check_true(rolling, "initiative is waiting when the player disconnects")
	var seq_before: int = AlternityNum.as_int(
		_player_shell.identity.for_campaign(campaign_id).get("last_seq", 0)
	)
	check_true(seq_before > 0, "the device knows how far its copy got")

	# The player walks out of the room. Back to the campaign list, which tears
	# the table view down and with it the connection.
	_player_shell._leave_table()
	var gone := await _wait_for(func(): return _gm_screen().transport().connected_players().is_empty())
	check_true(gone, "the GM sees them drop")
	check_true(_gm_screen().session().has_seat(_joined_player_id), "their seat survives")
	check_eq(_gm_screen().session().get_seat_ap(_joined_player_id), 3, "and so does their AP")

	# The table carries on without them.
	_gm_screen().transport().broadcast_event(Session.EVENT_NOTE, "", {"text": "the door gives way"})
	_gm_screen().transport().broadcast_event(Session.EVENT_NOTE, "", {"text": "something moves inside"})
	var missed: int = _gm_screen().session().last_seq() - seq_before

	var campaigns = _screen(_player_shell, "campaign_select")
	if not check(campaigns != null, "the player is back at the campaign list"):
		return
	campaigns.join_requested.emit()
	await process_frame
	var join = _screen(_player_shell, "table_join")
	if not check(join != null, "and can join again"):
		return

	# The same device, a brand new peer id. Only the stored player_id survived,
	# and it is what the host matches on.
	_commit_hero()
	join._join("127.0.0.1", Transport.DEFAULT_PORT, "", "")
	var back := await _wait_for(func(): return _table() != null and _table().doc != null)
	check_true(back, "the player rejoins")
	if not back:
		return

	check_eq(_gm_screen().session().seats.size(), 2, "rejoining does not create a third seat")
	check_eq(
		String(_player_seat().get("player_id", "")), _joined_player_id,
		"they came back to the same seat"
	)

	var rejoined = _table()
	check_true(rejoined.active_round != null, "the current fight arrives in the reconnect welcome")
	check_true(rejoined.owes_action_check(), "the returning player is prompted for the initiative still owed")
	var caught_up := await _wait_for(func(): return rejoined.events.size() >= missed)
	check_true(caught_up, "and is sent what they missed")
	if not caught_up:
		return
	check_eq(rejoined.events.size(), missed, "exactly what they missed, not the whole campaign")

	var texts: Array = []
	for event in rejoined.events:
		texts.append(String(event.get("payload", {}).get("text", "")))
	check_true(texts.has("the door gives way"), "including the first thing they missed")
	check_true(texts.has("something moves inside"), "and the last")

	check_eq(
		AlternityNum.as_int(_player_shell.identity.for_campaign(campaign_id).get("last_seq", 0)),
		_gm_screen().session().last_seq(),
		"and the device is caught up for next time"
	)
	_gm_screen()._on_end_combat_pressed()
	await _wait_for(func(): return _table().active_round == null)


func _test_cold_start_recovers_pending_work() -> void:
	var gm = _gm_screen()
	var session = gm.session()
	var called := SkillCheck.call_for("Awareness", 1, "Something moved", 1)
	called.player_id = _joined_player_id
	session.queue_called_check(called.to_dict(), _joined_player_id)
	gm.transport().send_ruling(called.to_dict(), _joined_player_id)

	var attack := CombatAttack.declare(
		_joined_player_id, "A raider", "Knife", "Good", 2, "s", "li", "O"
	)
	gm.transport().send_attack(attack.to_dict(), _joined_player_id)
	_gm_shell.campaigns.save(session)
	check_eq(session.pending_checks_for(_joined_player_id).size(), 1, "the GM persists a called check")
	check_eq(session.pending_attacks_for(_joined_player_id).size(), 1, "the GM persists an unanswered attack")

	var saved_table: Dictionary = _player_shell.identity.active_table()
	var character_file := String(saved_table.get("character_file", ""))
	check_false(character_file.is_empty(), "the player persists which local hero was at the table")
	_player_shell.queue_free()
	_player_shell = null
	await process_frame
	await process_frame

	_player_shell = _new_shell(PLAYER_DIR, PLAYER_CAMPAIGNS)
	var resumed := await _wait_for(func():
		return _table() != null and _table().is_connected_to_table() and _table().doc != null)
	check_true(resumed, "a new app process automatically rejoins the last table")
	if not resumed:
		return
	check_eq(_gm_screen().session().seats.size(), 2, "cold-start recovery keeps the same seat")
	check_eq(_table().doc.source_file, character_file, "and reopens the committed local hero")
	check_eq(_table().incoming_checks.size(), 1, "the unanswered GM check is restored")
	check_eq(_table().incoming_attacks.size(), 1, "the unanswered attack is restored")

	_table().dismiss_called_check(_table().incoming_checks[0])
	var dismissed := await _wait_for(func():
		return _gm_screen().session().pending_checks_for(_joined_player_id).is_empty())
	check_true(dismissed, "dismissing a restored check clears the GM's durable copy")

	var before := AlternityNum.as_int(_table().doc.raw().get("damage", {}).get("stun", 0))
	var pending: CombatAttack = _table().next_attack()
	var outcome: Dictionary = _table().apply_attack(pending, 1)
	var after := AlternityNum.as_int(_table().doc.raw().get("damage", {}).get("stun", 0))
	check_true(after >= before, "the restored attack is applied on the owning device")

	# Simulate Android killing the process after damage was saved but before its
	# result reached the GM. The next process must not apply that damage twice.
	_player_shell.queue_free()
	_player_shell = null
	await process_frame
	await process_frame
	_player_shell = _new_shell(PLAYER_DIR, PLAYER_CAMPAIGNS)
	var resumed_again := await _wait_for(func():
		return _table() != null and _table().is_connected_to_table() and not _table().incoming_attacks.is_empty())
	check_true(resumed_again, "an interrupted attack resolution is offered again")
	if not resumed_again:
		return
	var resent: CombatAttack = _table().next_attack()
	var recovered_outcome: Dictionary = _table().apply_attack(resent, 99)
	check_eq(
		AlternityNum.as_int(recovered_outcome.get("primary_damage", -1)),
		AlternityNum.as_int(outcome.get("primary_damage", -2)),
		"the saved outcome is reused after restart"
	)
	check_eq(
		AlternityNum.as_int(_table().doc.raw().get("damage", {}).get("stun", 0)), after,
		"and the same attack cannot damage the hero twice"
	)
	_table().report_attack(resent, 99, recovered_outcome)
	var settled := await _wait_for(func():
		return _gm_screen().session().pending_attacks_for(_joined_player_id).is_empty())
	check_true(settled, "the recovered result settles the GM's pending attack")


func _test_protocol_resilience_and_isolation() -> void:
	var tbl = _table()
	if not check(tbl != null, "table session exists for protocol resilience test"):
		return
	var cid: String = tbl.campaign_id()
	check_false(cid.is_empty(), "table has active campaign ID")

	var received_packets: Array = []
	var listener = func(pid: String, data: Dictionary):
		received_packets.append({"player_id": pid, "data": data})
	_gm_screen().transport().phase_committed_received.connect(listener)

	# 1. Misses: repeatable acknowledgments
	var miss_atk := CombatAttack.declare(_joined_player_id, "Enemy", "Pistol", "Failure", 0, "s", "li", "O")
	miss_atk.round_id = "test-round-1"
	miss_atk.phase = "ordinary"
	tbl.apply_attack(miss_atk, 0)
	check_true(tbl.identity.has_attack_applied(cid, miss_atk.attack_id), "miss recorded in identity applied")

	received_packets.clear()
	tbl._on_phase_commit_requested("test-round-1", "ordinary", "op-1", [miss_atk.attack_id])
	var arrived: bool = await _wait_for(func(): return not received_packets.is_empty())
	check_true(arrived, "phase commit arrived at GM for miss")
	if not received_packets.is_empty():
		var ack_ids: Array = received_packets[0]["data"].get("attack_ids", [])
		check_true(ack_ids.has(miss_atk.attack_id), "miss attack ID acknowledged on first commit request")

	# Retry of commit request for miss
	received_packets.clear()
	tbl._on_phase_commit_requested("test-round-1", "ordinary", "op-1", [miss_atk.attack_id])
	arrived = await _wait_for(func(): return not received_packets.is_empty())
	check_true(arrived, "retry phase commit arrived at GM for miss")
	if not received_packets.is_empty():
		var retry_ids: Array = received_packets[0]["data"].get("attack_ids", [])
		check_true(retry_ids.has(miss_atk.attack_id), "miss attack ID acknowledged on retry commit request")

	# 2. Hit attack: staged, committed, and retry repeatable acknowledgment
	var hit_atk := CombatAttack.declare(_joined_player_id, "Enemy", "Laser", "Good", 3, "w", "hi", "O")
	hit_atk.round_id = "test-round-1"
	hit_atk.phase = "ordinary"
	if tbl.active_round == null:
		tbl.active_round = ActionRound.new(1)
		tbl.active_round.round_id = "test-round-1"
		tbl.active_round.state = ActionRound.STATE_ACTIVE
		tbl.active_round.phase_index = ActionRound.PHASES.find("ordinary")
	tbl.apply_attack(hit_atk, 0)
	check_true(tbl.has_staged_damage(), "hit attack is staged")
	var commit_res: Dictionary = tbl.commit_staged_damage()
	check_true(bool(commit_res.get("ok", false)), "staged damage commit succeeded")

	received_packets.clear()
	tbl._on_phase_commit_requested("test-round-1", "ordinary", "op-2", [hit_atk.attack_id])
	arrived = await _wait_for(func(): return not received_packets.is_empty())
	check_true(arrived, "phase commit arrived at GM for hit")
	if not received_packets.is_empty():
		var ack_hit_ids: Array = received_packets[0]["data"].get("attack_ids", [])
		check_true(ack_hit_ids.has(hit_atk.attack_id), "hit attack ID acknowledged after commit")

	# Retry of commit request for hit after staged attacks cleared
	received_packets.clear()
	tbl._on_phase_commit_requested("test-round-1", "ordinary", "op-2", [hit_atk.attack_id])
	arrived = await _wait_for(func(): return not received_packets.is_empty())
	check_true(arrived, "retry phase commit arrived at GM for hit")
	if not received_packets.is_empty():
		var retry_hit_ids: Array = received_packets[0]["data"].get("attack_ids", [])
		check_true(retry_hit_ids.has(hit_atk.attack_id), "hit attack ID acknowledged on retry after memory cleared")

	_gm_screen().transport().phase_committed_received.disconnect(listener)

	# 3. Two-campaign and two-character isolation
	var bound_key: String = tbl._character_key()
	var saved_source: String = tbl.doc.source_file
	tbl.doc.source_file = "renamed-character.json"
	check_eq(tbl._character_key(), bound_key, "renaming the character file preserves pending-effect identity")
	var renamed_copy := CharacterDoc.from_dict(tbl.rules, tbl.doc.to_dict(), "renamed-character.json")
	check_eq(String(renamed_copy.raw().get("combat_character_key", "")), bound_key, "stable combat identity survives character serialization")
	tbl.doc.source_file = saved_source
	var own_progress: Dictionary = tbl.identity.attack_progress(cid, hit_atk.attack_id)
	check_true(tbl._can_acknowledge_attack(own_progress, "test-round-1", "ordinary"), "durable own commit can be acknowledged")
	var wrong_hero := own_progress.duplicate(true)
	wrong_hero["character_key"] = "another-character.json"
	check_false(tbl._can_acknowledge_attack(wrong_hero, "test-round-1", "ordinary"), "another character's result cannot be acknowledged")
	var only_prepared := own_progress.duplicate(true)
	only_prepared["committed"] = false
	check_false(tbl._can_acknowledge_attack(only_prepared, "test-round-1", "ordinary"), "prepared is not proof of durable commit")
	check_false(tbl._can_acknowledge_attack(own_progress, "old-round", "ordinary"), "wrong round cannot be acknowledged")
	var cancelled_progress := own_progress.duplicate(true)
	cancelled_progress["cancelled"] = true
	check_false(tbl._can_acknowledge_attack(cancelled_progress, "test-round-1", "ordinary"), "cancelled work cannot be acknowledged")
	var other_camp := "campaign_isolation_test"
	var other_char_key := "OtherHero.json"
	var foreign_atk := CombatAttack.declare("foreign_player", "Enemy", "Blaster", "Good", 5, "w", "hi", "O")
	tbl.identity.remember_attack_applied(other_camp, foreign_atk.to_dict(), 0, {"wound": 5}, false, other_char_key, "foreign_player")

	var foreign_uncommitted: Array = tbl.identity.uncommitted_attacks(cid, tbl._character_key())
	for item in foreign_uncommitted:
		var a: Dictionary = item.get("attack", {})
		check_false(String(a.get("attack_id", "")) == foreign_atk.attack_id, "foreign attack is never recovered in active campaign")

	var other_uncommitted: Array = tbl.identity.uncommitted_attacks(other_camp, tbl._character_key())
	check_true(other_uncommitted.is_empty(), "different character in other campaign has no uncommitted attacks")

	# 4. Storage failure handling
	var original_store = tbl.store
	var mock_script := GDScript.new()
	mock_script.source_code = "extends \"res://scripts/core/character_store.gd\"\nfunc save(_doc): return {'ok': false, 'reason': 'Simulated disk failure'}\n"
	mock_script.reload()
	tbl.store = mock_script.new("user://tmp_fail/")

	var fail_atk := CombatAttack.declare(_joined_player_id, "Enemy", "Laser", "Good", 2, "w", "hi", "O")
	fail_atk.round_id = "test-round-fail"
	fail_atk.phase = "ordinary"
	if tbl.active_round != null:
		tbl.active_round.round_id = "test-round-fail"
	tbl.apply_attack(fail_atk, 0)
	check_true(tbl.has_staged_damage(), "staged damage present for save failure test")

	var failed_commit: Dictionary = tbl.commit_staged_damage()
	check_false(bool(failed_commit.get("ok", true)), "commit_staged_damage reports failure when store.save fails")
	check_true(tbl.has_staged_damage(), "staged attacks retained in memory on store save failure")
	check_false(tbl.identity.is_attack_committed(cid, fail_atk.attack_id), "journal entry not marked committed on save failure")

	# Commit request withholds acknowledgment when commit fails
	var failed_commit_ack: Array = []
	var fail_listener = func(pid: String, data: Dictionary): failed_commit_ack.append({"player_id": pid, "data": data})
	_gm_screen().transport().phase_committed_received.connect(fail_listener)
	tbl._on_phase_commit_requested("test-round-fail", "ordinary", "op-fail", [fail_atk.attack_id])
	await process_frame
	await process_frame
	check_true(failed_commit_ack.is_empty(), "commit acknowledgment withheld when character save fails")
	_gm_screen().transport().phase_committed_received.disconnect(fail_listener)

	# Restore real store and clear fail_atk
	tbl.store = original_store
	var success_commit: Dictionary = tbl.commit_staged_damage()
	check_true(bool(success_commit.get("ok", false)), "commit succeeds when real store restored")


func _test_leaving_closes_the_table() -> void:
	# Closing the campaign must take the socket with it, or the GM's device keeps
	# answering for a campaign nobody is looking at.
	var gm = _gm_screen()
	if not check(gm != null and gm.is_hosting(), "the table is open before closing"):
		return
	# Held across the close: the screen itself is freed by the shell, so it is
	# the transport that has to be asked whether the socket went with it.
	var transport = gm.transport()
	# Leaving is a settings action now, not a header button -- closing a table
	# four people are at should not be one mis-tap away.
	_answer_gm_route({"action": "leave"})
	await gm._on_settings_pressed()
	await process_frame
	check_true(_gm_screen() == null, "closing the campaign leaves the GM screen")
	check_false(transport.is_connected_to_table(), "and closes the table with it")

	var lonely = Transport.new()
	var failures := []
	var welcomes := []
	lonely.transport_error.connect(func(_m: String): failures.append(true))
	lonely.player_connected.connect(func(_id: String, _r: bool): welcomes.append(true))
	lonely.join("127.0.0.1", Transport.DEFAULT_PORT, "", "Too late")
	for _i in 60:
		lonely.poll()
		await process_frame
	check_eq(welcomes.size(), 0, "and nobody can join a closed table")
	lonely.leave()


func _start_selected_combat(gm) -> void:
	gm._on_start_combat_pressed()
	await process_frame
	var picker = gm._router._host.top_route()
	if picker != null and picker.get("_confirm") != null:
		picker._confirm.pressed.emit()
	await process_frame
	await process_frame
	gm._router.pop()
	await process_frame
