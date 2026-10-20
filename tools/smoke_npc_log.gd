extends "res://tools/test_harness.gd"

const DIR := "user://__npc_log_test__/"

class AnswerRouter extends UiRouter:
	var answers: Array = []
	func push(_scene: PackedScene, _props: Dictionary = {}, _presentation: int = Presentation.AUTO) -> Variant:
		return answers.pop_front() if not answers.is_empty() else null

func _init() -> void:
	begin_async("NPCs and roll evidence", 1000)
	_run.call_deferred()

func _run() -> void:
	var rules := AlternityRules.new()
	rules.load_core_data()
	var session := CampaignSession.new("NPC test")
	var campaigns := CampaignStore.new(DIR)
	var doc := CharacterDoc.new(rules)
	doc.apply([CharacterDoc.META], func(c): c["hero_name"] = "Guard")
	var id := session.add_npc(doc.to_dict())
	check_eq(session.seats.size(), 0, "NPC does not acquire a player seat")
	var store := NpcCharacterStore.new(rules, session, campaigns, id)
	doc.apply([CharacterDoc.META], func(c): c["hero_name"] = "Captain")
	check_true(store.save(doc).get("ok", false), "NPC editor saves in campaign")
	var reopened := campaigns.load_session(session.campaign_id)
	check_eq(reopened.npcs[id]["hero_name"], "Captain", "NPC survives disk reload")
	check_true(CampaignSession.from_dict({}).npcs.is_empty(), "old campaigns load without NPCs")

	var die := {"notation": "-d4", "dice": [3], "sign": -1, "modifier": 0, "total": -3, "source": "physical", "rerolls": 2}
	var check_roll := SkillCheck.call_for("Athletics", 2, "Wet ground")
	check_roll.resolve({"degree": "Good", "total": 4, "control": {"notation": "d20", "dice": [7], "total": 7}, "situation": die})
	var attack := CombatAttack.declare(id, "Raider", "Club", "Ordinary", 2, "s", "li", "O")
	attack.details = {"target_name": "Captain", "to_hit": check_roll.to_dict(), "damage_roll": {"results": [die]}}
	var restored := CombatAttack.from_dict(JSON.parse_string(JSON.stringify(attack.to_dict())))
	check_eq(restored.details.to_hit.result.situation.dice[0], 3.0, "individual faces survive JSON")
	check_eq(restored.details.to_hit.reason, "Wet ground", "GM reason survives JSON")
	check_eq(restored.details.to_hit.result.situation.rerolls, 2.0, "cocked rethrows survive JSON")
	attack.details.target_name = "Changed later"
	check_eq(restored.details.target_name, "Captain", "recorded identity is independent")

	var declaration_route = preload("res://scenes/ui/routes/combat_attack_route.tscn").instantiate()
	declaration_route.configure({"palette": ThemePalette.new(), "rules": rules, "npcs": session.npcs})
	root.add_child(declaration_route)
	var weapon: Dictionary = {}
	for item in rules.equipment.filtered_equipment({"category": "Weapons"}):
		if AlternityNum.as_int(item.get("combat", {}).get("skill_id", -1)) == 31:
			weapon = item
			break
	check_false(weapon.is_empty(), "pistol fixture found")
	declaration_route._attacker_id = id
	declaration_route._choose_weapon(weapon)
	var skill_score: Dictionary = rules.skill_score(doc.raw(), rules.get_skill_by_id(31))
	check_eq(declaration_route._score_stepper.value(), AlternityNum.as_int(skill_score.get("ordinary", 0)), "NPC attack uses its real skill score")
	check_eq(declaration_route.net_steps(), AlternityNum.as_int(skill_score.get("step", 0)) + declaration_route._range_step(), "NPC skill and range steps both apply")
	check_false(declaration_route._attacker_field.editable, "NPC identity cannot be replaced with free text")
	declaration_route.queue_free()

	var router := AnswerRouter.new()
	var gm := GmScreen.new()
	root.add_child(gm)
	gm.setup(session, campaigns, CharacterStore.new(rules, DIR + "heroes/"), rules, router, ThemePalette.new())
	var twin := CharacterDoc.from_dict(rules, doc.to_dict())
	twin.apply([CharacterDoc.ABILITIES], func(c): c["abilities"]["CON"] = 15)
	check_true(gm._summary_of(CharacterSnapshot.of_doc(doc)) != gm._summary_of(CharacterSnapshot.of_doc(twin)), "same-named NPCs cannot share a stale summary")
	router.answers.append([{ "id": id, "name": doc.get_hero_name(), "kind": ActionRound.KIND_NPC, "actions": 2, "portrait": "" }])
	await gm._on_start_combat_pressed()
	check_true(gm._fight.has_combatant(id), "NPC participates without players")
	check_eq(gm._fight.combatant(id).kind, ActionRound.KIND_NPC, "NPC identity remains distinct")
	await gm._send_attack(restored)
	check_true(restored.is_resolved(), "GM resolves NPC damage locally")
	check_eq(session.events.back().payload.details.target_name, "Captain", "complete attack enters log")
	check_true(session.npcs[id] != doc.to_dict(), "NPC damage persists in campaign")
	check_eq(session.seats.size(), 0, "NPC damage never writes player seats")

	var npc_route = preload("res://scenes/ui/routes/npc_sheet_route.tscn").instantiate()
	npc_route.configure({"session": session, "npc_id": id, "store": campaigns, "rules": rules, "router": router, "palette": ThemePalette.new()})
	root.add_child(npc_route)
	await process_frame
	var sheet = npc_route.get_child(0)
	check_eq(sheet.document().get_hero_name(), "Captain", "NPC full editor opens saved sheet")
	sheet.document().apply([CharacterDoc.META], func(c): c["hero_name"] = "Renamed Captain")
	check_eq(campaigns.load_session(session.campaign_id).npcs[id].hero_name, "Renamed Captain", "route Back cannot discard edits")
	var runner: CheckRunner = sheet._ctx.checks
	runner._broadcast(check_roll, {"check": check_roll.to_dict()}, sheet.document())
	check_eq(session.events.back().payload.character_name, "Renamed Captain", "NPC checks preserve thrower's name")
	check_eq(session.events.back().payload.check.result.situation.total, -3, "NPC checks preserve signed situation die")
	var logged: Dictionary = session.events.back().duplicate(true)
	session.remove_npc(id)
	check_eq(logged.payload.character_name, "Renamed Captain", "removing NPC cannot erase historical identity")
	npc_route.queue_free()
	gm.queue_free()
	await process_frame
	campaigns.delete(session.campaign_id)
	finish()
