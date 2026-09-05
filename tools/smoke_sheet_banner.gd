extends "res://tools/test_harness.gd"

const RulesScript := preload("res://scripts/alternity_rules.gd")
const Doc := preload("res://scripts/core/character_doc.gd")
const Context := preload("res://scripts/ui/sheet_context.gd")
const CharacterSheetScene := preload("res://scenes/ui/screens/character_sheet.tscn")
const CombatAttack := preload("res://scripts/core/session/combat_attack.gd")
const ActionRound := preload("res://scripts/core/session/action_round.gd")
const SkillCheck := preload("res://scripts/core/session/skill_check.gd")
const TableSession := preload("res://scripts/core/session/table_session.gd")
const EnetTransport := preload("res://scripts/core/session/enet_transport.gd")
const PlayerIdentity := preload("res://scripts/core/session/player_identity.gd")

var _rules: AlternityRules
var _sheet
var _table: TableSession
var _doc: CharacterDoc
var _transport: EnetTransport


func _init() -> void:
	begin_async("sheet banner", 300)
	_run.call_deferred()


func _run() -> void:
	_rules = RulesScript.new()
	_rules.load_core_data()

	_doc = Doc.new(_rules)
	var raw := _doc.raw()
	raw["name"] = "Vanguard"
	raw["abilities"] = {
		"str": {"score": 12}, "dex": {"score": 11}, "con": {"score": 10},
		"int": {"score": 10}, "wil": {"score": 10}, "per": {"score": 10}
	}

	_transport = EnetTransport.new()
	_transport._local_player_id = "player_1"
	var identity := PlayerIdentity.new()
	_table = TableSession.new(_transport, identity, null, _rules, "Test Campaign")

	var ctx := Context.new(_doc, _rules, null, ThemePalette.new(), false)
	ctx.table = _table

	_sheet = CharacterSheetScene.instantiate()
	root.add_child(_sheet)
	_sheet.setup(ctx, null)
	await process_frame

	await _test_banner_hidden_initially()
	await _test_incoming_attack_hit()
	await _test_incoming_attack_miss()
	await _test_action_check_needed()
	await _test_called_check()
	await _test_acting_now()
	await _test_table_button_switches_tab()
	await _test_attack_resolved_damage_notification()
	await _test_attack_resolved_armor_soaked()
	await _test_attack_resolved_parried()
	await _test_ap_award_notification()
	await _test_scene_ended_notification()
	await _test_trouble_notification()
	await _test_tab_switch_auto_clears_notification()

	finish()


func _test_banner_hidden_initially() -> void:
	check_false(_sheet._banner_container.visible, "banner is initially hidden")
	check_eq(_sheet._buttons["table"].text, "Table", "table tab badge is unbadged")


func _test_incoming_attack_hit() -> void:
	var attack := CombatAttack.declare("enemy_1", "Mutant", "Plasma Rifle", "Good", 4, "w", "en", "O")
	attack.damage = 4
	_table.incoming_attacks.append(attack)
	_table.attack_arrived.emit(attack)
	await process_frame

	check_true(_sheet._banner_container.visible, "banner shows for incoming attack")
	check_eq(_sheet._banner_icon.texture, _sheet.ICON_ATTACK, "banner icon is attack icon")
	check_false(_sheet._banner_label.text.contains("⚔"), "banner label has no emoji")
	check_true(_sheet._banner_label.text.contains("Attack incoming"), "banner label says attack incoming")
	check_eq(_sheet._banner_roll_btn.text, "Resolve Armor", "roll button is Resolve Armor")
	check_eq(_sheet._banner_dismiss_btn.text, "Table", "dismiss button is Table")
	check_eq(_sheet._buttons["table"].text, "Table (1)", "table badge shows (1)")

	_table.incoming_attacks.clear()
	_table.changed.emit()
	await process_frame
	check_false(_sheet._banner_container.visible, "banner clears after attack is handled")


func _test_incoming_attack_miss() -> void:
	var miss := CombatAttack.declare("enemy_1", "Mutant", "Pistol", "Failure", 0, "w", "hi", "O")
	_table.incoming_attacks.append(miss)
	_table.attack_arrived.emit(miss)
	await process_frame

	check_true(_sheet._banner_container.visible, "banner shows for incoming miss")
	check_eq(_sheet._banner_icon.texture, _sheet.ICON_ATTACK, "banner icon is attack icon for miss")
	check_true(_sheet._banner_label.text.contains("missed"), "banner label notes miss")
	check_eq(_sheet._banner_roll_btn.text, "Dismiss", "roll button is Dismiss for a miss")
	check_eq(_sheet._banner_dismiss_btn.text, "Table", "dismiss button is Table")

	_table.incoming_attacks.clear()
	_table.changed.emit()
	await process_frame


func _test_action_check_needed() -> void:
	var round_obj := ActionRound.new(2)
	round_obj.add_combatant("player_1", "Vanguard", 2)
	_table.active_round = round_obj
	_table.round_changed.emit()
	await process_frame

	check_true(_table.owes_action_check(), "table session owes action check")
	check_true(_sheet._banner_container.visible, "banner shows for action check needed")
	check_eq(_sheet._banner_icon.texture, _sheet.ICON_DICE, "banner icon is dice icon for action check")
	check_false(_sheet._banner_label.text.contains("⚔"), "action check banner has no emoji")
	check_true(_sheet._banner_label.text.contains("Round 2 started"), "banner says round 2 started")
	check_true(_sheet._banner_label.text.contains("Roll initiative"), "banner prompts for initiative")
	check_eq(_sheet._banner_roll_btn.text, "Roll Initiative", "roll button is Roll Initiative")
	check_eq(_sheet._banner_dismiss_btn.text, "Table", "dismiss button is Table")
	check_eq(_sheet._buttons["table"].text, "Table (1)", "badge shows Table (1)")

	# Complete action check locally
	round_obj.record_check("player_1", "good", 12, 5, false)
	_table.round_changed.emit()
	await process_frame

	check_false(_table.owes_action_check(), "table session no longer owes action check")
	_table.active_round = null
	_table.round_changed.emit()
	await process_frame


func _test_called_check() -> void:
	var check_obj := SkillCheck.call_for("Awareness - perception", 1, "Look around", 101)
	check_obj.check_id = "check_99"
	_table.incoming_checks.append(check_obj)
	_table.check_arrived.emit(check_obj)
	await process_frame

	check_true(_sheet._banner_container.visible, "banner shows for called check")
	check_eq(_sheet._banner_icon.texture, _sheet.ICON_DICE, "banner icon is dice icon for called check")
	check_false(_sheet._banner_label.text.contains("🎲"), "called check banner has no emoji")
	check_true(_sheet._banner_label.text.contains("Awareness - perception"), "banner names the skill")
	check_eq(_sheet._banner_roll_btn.text, "Roll Now", "roll button is Roll Now")
	check_eq(_sheet._banner_dismiss_btn.text, "Dismiss", "dismiss button is Dismiss")
	check_eq(_sheet._buttons["table"].text, "Table (1)", "table badge shows (1)")

	_sheet._on_banner_dismiss_pressed()
	await process_frame

	check_false(_sheet._banner_container.visible, "dismissing called check hides banner")
	check_true(_table.incoming_checks.is_empty(), "incoming_checks is empty after dismissal")


func _test_acting_now() -> void:
	var round_obj := ActionRound.new(1)
	round_obj.add_combatant("player_1", "Vanguard", 2)
	round_obj.record_check("player_1", "good", 12, 5, false)
	round_obj.start()
	while round_obj.phase_name() != "Good" and round_obj.phase_index < ActionRound.PHASES.size() - 1:
		round_obj.advance_phase()
	_table.active_round = round_obj
	_table.round_changed.emit()
	await process_frame

	check_true(_table.acting_now(), "player is acting now in this phase")
	check_true(_sheet._banner_container.visible, "banner shows for player turn")
	check_eq(_sheet._banner_icon.texture, _sheet.ICON_ATTACK, "acting now icon is attack icon")
	check_false(_sheet._banner_label.text.contains("⚔"), "acting now banner has no emoji")
	check_true(_sheet._banner_label.text.contains("It is your turn to act!"), "banner label says it is your turn")
	check_eq(_sheet._banner_roll_btn.text, "Open Table", "button is Open Table")
	check_false(_sheet._banner_dismiss_btn.visible, "dismiss button hidden for turn banner")
	check_eq(_sheet._buttons["table"].text, "Table (1)", "badge shows Table (1)")

	_table.active_round = null
	_table.round_changed.emit()
	await process_frame


func _test_table_button_switches_tab() -> void:
	check_eq(_sheet.active_tab_id(), "basics", "sheet starts on basics tab")

	var attack := CombatAttack.declare("enemy_1", "Mutant", "Rifle", "Good", 3, "w", "hi", "O")
	_table.incoming_attacks.append(attack)
	_table.attack_arrived.emit(attack)
	await process_frame

	_sheet._on_banner_dismiss_pressed()
	await process_frame

	check_eq(_sheet.active_tab_id(), "table", "clicking Table button on banner switched to table tab")
	_table.incoming_attacks.clear()
	_table.changed.emit()
	await process_frame


func _test_attack_resolved_damage_notification() -> void:
	# Switch back to basics tab so we can test navigating to summary
	_sheet.restore_tab("basics")
	await process_frame
	check_eq(_sheet.active_tab_id(), "basics", "reset to basics tab")

	var attack := CombatAttack.declare("player_1", "Mutant Boss", "Charge Pistol", "Good", 4, "w", "hi", "O")
	var outcome: Dictionary = {
		"primary_damage": 4,
		"secondary_stun": 2,
		"secondary_wound": 0,
		"damage_type": "wound",
		"negated": false
	}
	_table.report_attack(attack, 2, outcome, false)
	await process_frame

	check_true(_sheet._banner_container.visible, "banner shows for damage taken notification")
	check_eq(_sheet._banner_icon.texture, _sheet.ICON_ATTACK, "damage notification icon is attack icon")
	check_false(_sheet._banner_label.text.contains("💥"), "damage banner has no emoji")
	check_true(_sheet._banner_label.text.contains("Took 4 Wound"), "banner shows damage details")
	check_true(_sheet._banner_label.text.contains("(2 soaked by armor)"), "banner shows armor soaked info")
	check_true(_sheet._banner_label.text.contains("2 Stun"), "banner shows secondary stun")
	check_true(_sheet._banner_label.text.contains("Charge Pistol"), "banner names attacker weapon")
	check_eq(_sheet._banner_roll_btn.text, "View Summary", "action button is View Summary")
	check_true(_sheet._banner_dismiss_btn.visible, "dismiss button is visible")
	check_eq(_sheet._buttons["summary"].text, "Summary (!)", "summary tab badge is badged (!)")

	# Click "View Summary"
	_sheet._on_banner_roll_pressed()
	await process_frame

	check_eq(_sheet.active_tab_id(), "summary", "navigated to summary tab")
	check_false(_sheet._banner_container.visible, "banner dismissed after viewing")
	check_eq(_sheet._buttons["summary"].text, "Summary", "summary badge cleared")


func _test_attack_resolved_armor_soaked() -> void:
	var attack := CombatAttack.declare("player_1", "Thug", "Pipe", "Ordinary", 3, "s", "li", "O")
	var outcome: Dictionary = {
		"primary_damage": 0,
		"secondary_stun": 0,
		"secondary_wound": 0,
		"damage_type": "stun",
		"negated": true
	}
	_table.report_attack(attack, 3, outcome, false)
	await process_frame

	check_true(_sheet._banner_container.visible, "banner shows for armor soaked hit")
	check_eq(_sheet._banner_icon.texture, _sheet.ICON_ATTACK, "armor soaked notification icon is attack icon")
	check_false(_sheet._banner_label.text.contains("🛡"), "armor soaked banner has no emoji")
	check_true(_sheet._banner_label.text.contains("Armor soaked all 3 damage"), "banner mentions armor soaked all damage")
	check_true(_sheet._banner_label.text.contains("Pipe"), "banner mentions weapon")

	_sheet._on_banner_dismiss_pressed()
	await process_frame
	check_false(_sheet._banner_container.visible, "banner dismissed")


func _test_attack_resolved_parried() -> void:
	var attack := CombatAttack.declare("player_1", "Ninja", "Katana", "Good", 5, "w", "hi", "O")
	var outcome: Dictionary = {}
	_table.report_attack(attack, 0, outcome, false, true)
	await process_frame

	check_true(_sheet._banner_container.visible, "banner shows for parried hit")
	check_eq(_sheet._banner_icon.texture, _sheet.ICON_ATTACK, "parried notification icon is attack icon")
	check_false(_sheet._banner_label.text.contains("🛡"), "parried banner has no emoji")
	check_true(_sheet._banner_label.text.contains("Parried Ninja's Katana!"), "banner announces parry")

	_sheet._on_banner_dismiss_pressed()
	await process_frame
	check_false(_sheet._banner_container.visible, "banner dismissed")


func _test_ap_award_notification() -> void:
	# Ensure on basics tab
	_sheet.restore_tab("basics")
	await process_frame

	_table.ap_applied.emit(3, "Heroic stand")
	await process_frame

	check_true(_sheet._banner_container.visible, "banner shows for AP award")
	check_eq(_sheet._banner_icon.texture, _sheet.ICON_DICE, "ap award notification icon is dice icon")
	check_false(_sheet._banner_label.text.contains("⭐"), "ap award banner has no emoji")
	check_true(_sheet._banner_label.text.contains("awarded you 3 achievement points"), "banner notes 3 AP awarded")
	check_true(_sheet._banner_label.text.contains("Heroic stand"), "banner notes award reason")
	check_eq(_sheet._banner_roll_btn.text, "View Achievements", "action button is View Achievements")
	check_eq(_sheet._buttons["achievements"].text, "Achievements (+3)", "achievements tab badged (+3)")

	# Clicking "View Achievements"
	_sheet._on_banner_roll_pressed()
	await process_frame

	check_eq(_sheet.active_tab_id(), "achievements", "navigated to achievements tab")
	check_false(_sheet._banner_container.visible, "banner dismissed")
	check_eq(_sheet._buttons["achievements"].text, "Achievements", "achievements badge cleared")


func _test_scene_ended_notification() -> void:
	_table.scene_ended.emit(4)
	await process_frame

	check_true(_sheet._banner_container.visible, "banner shows for scene ended")
	check_eq(_sheet._banner_icon.texture, _sheet.ICON_DICE, "scene ended notification icon is dice icon")
	check_false(_sheet._banner_label.text.contains("🌅"), "scene ended banner has no emoji")
	check_true(_sheet._banner_label.text.contains("scene ended -- 4 Stun cleared"), "banner notes stun cleared")
	check_eq(_sheet._banner_roll_btn.text, "View Summary", "action button is View Summary")

	_sheet._on_banner_dismiss_pressed()
	await process_frame
	check_false(_sheet._banner_container.visible, "banner dismissed")


func _test_trouble_notification() -> void:
	_table.trouble.emit("Host table closed.")
	await process_frame

	check_true(_sheet._banner_container.visible, "banner shows for table trouble")
	check_eq(_sheet._banner_icon.texture, _sheet.ICON_DICE, "trouble notification icon is dice icon")
	check_false(_sheet._banner_label.text.contains("⚠️"), "trouble banner has no emoji")
	check_true(_sheet._banner_label.text.contains("Host table closed."), "banner contains trouble message")
	check_eq(_sheet._banner_roll_btn.text, "Open Table", "action button is Open Table")

	_sheet._on_banner_dismiss_pressed()
	await process_frame
	check_false(_sheet._banner_container.visible, "banner dismissed")


func _test_tab_switch_auto_clears_notification() -> void:
	_sheet.restore_tab("basics")
	await process_frame

	_table.ap_applied.emit(2, "Clever tactic")
	await process_frame

	check_true(_sheet._banner_container.visible, "banner visible before tab switch")
	check_eq(_sheet._buttons["achievements"].text, "Achievements (+2)", "achievements badged (+2)")

	# Manually select the achievements tab
	_sheet._select_tab("achievements")
	await process_frame

	check_false(_sheet._banner_container.visible, "banner automatically cleared when visiting achievements tab")
	check_eq(_sheet._buttons["achievements"].text, "Achievements", "achievements badge cleared")

