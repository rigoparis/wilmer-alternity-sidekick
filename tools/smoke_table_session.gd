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
	await _test_reconnect_loses_nothing()
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
	check_true(String(lines[0]).contains("Alice"), "and naming the player, not an id")

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
	check_true(String(lines[0]).begins_with("You"), "addressed to them rather than to an id")

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

	gm._on_start_combat_pressed()
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
	check_eq(
		AlternityNum.as_int(_table().doc.raw().get("damage", {}).get("wound", 0)), before + 4,
		"applying a miss marks nothing"
	)
	check_true(_table().incoming_attacks.is_empty(), "and it stops waiting")

	_gm_screen()._on_end_combat_pressed()
	await _wait_for(func(): return _table().active_round == null)


## Depth-first search for a named node, for asserting a screen built a control.
func _find_named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted)
		if found != null:
			return found
	return null


# --- Reconnect -------------------------------------------------------------

## Phase M2's checkpoint: a mid-session reconnect that loses nothing.
func _test_reconnect_loses_nothing() -> void:
	var table = _table()
	var campaign_id: String = _gm_screen().session().campaign_id
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
	join._join("127.0.0.1", Transport.DEFAULT_PORT, campaign_id, "The Verge")
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
