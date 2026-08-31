extends "res://tools/test_harness.gd"
##
## UI smoke test for optional rules workflow:
## 1. Creation prompt before starting character creation
## 2. Mid-run editing with dynamic recalculations
## 3. Multiplayer campaign GM vs player locked states
##

func _init() -> void:
	begin_async("optional rules UI workflow", 300)
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://main.tscn")
	if not check(packed != null, "main.tscn loads"):
		finish()
		return

	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame

	# 1. Test New Hero creation optional rules prompt
	scene.char_manager.active_character_file = ""
	scene._render()
	await process_frame

	check_false(scene.optional_rules_overlay.visible, "Optional rules overlay initially hidden")

	scene._prompt_new_character_optional_rules()
	await process_frame

	check_true(scene.optional_rules_overlay.visible, "Optional rules overlay opens on new hero prompt")
	check_eq(scene.optional_rules_overlay.mode, OverlayOptionalRules.Mode.NEW_HERO, "Overlay is in NEW_HERO mode")
	check_eq(scene.optional_rules_overlay.primary_btn.text, "Create Hero", "Primary button text is 'Create Hero'")

	# Toggle 2A and Psionic Talents in draft
	scene.optional_rules_overlay._on_rule_toggled("2a", true)
	scene.optional_rules_overlay._on_rule_toggled("psionic_talents", true)
	check_true(bool(scene.optional_rules_overlay.draft_rules.get("2a", false)), "Draft 2A enabled")
	check_true(bool(scene.optional_rules_overlay.draft_rules.get("psionic_talents", false)), "Draft Psionic Talents enabled")

	# Confirm creation
	scene.optional_rules_overlay._on_primary_pressed()
	await process_frame

	check_false(scene.optional_rules_overlay.visible, "Overlay closes after confirmation")
	check_eq(scene.active_tab, "Basics", "Active tab is Basics after hero creation")
	check_true(scene.rules.optional_rule_enabled(scene.character, "2a"), "Created character has 2A enabled")
	check_true(scene.rules.optional_rule_enabled(scene.character, "psionic_talents"), "Created character has Psionic Talents enabled")

	# 2. Test Mid-run editing & live recalculation
	scene._show_optional_rules()
	await process_frame

	check_true(scene.optional_rules_overlay.visible, "Optional rules overlay opens mid-run")
	check_eq(scene.optional_rules_overlay.mode, OverlayOptionalRules.Mode.MID_RUN, "Overlay is in MID_RUN mode")

	# Disable 2A mid-run and verify immediate recalculation
	scene.character["abilities"]["INT"] = 10
	var starting_sp_before: int = scene.rules.starting_skill_budget(scene.character)
	scene.optional_rules_overlay._on_rule_toggled("2a", false)
	var starting_sp_after: int = scene.rules.starting_skill_budget(scene.character)
	check_ne(starting_sp_before, starting_sp_after, "Starting skill budget recalculates immediately on toggle")
	check_false(scene.rules.optional_rule_enabled(scene.character, "2a"), "2A disabled mid-run")

	scene.optional_rules_overlay.visible = false

	# 3. Test Campaign session GM vs Player lock
	var session = CampaignSession.new("Test Ops Campaign")
	session.set_campaign_optional_rule("dazed", true)

	# GM perspective
	scene.optional_rules_overlay.show_for_campaign(session, true)
	check_true(scene.optional_rules_overlay.primary_btn.visible, "GM has Apply Rules button")
	check_false(scene.optional_rules_overlay.is_gm_locked, "GM is not locked")

	# Player perspective
	scene.optional_rules_overlay.show_for_campaign(session, false)
	check_true(scene.optional_rules_overlay.is_gm_locked, "Player is GM-locked")
	check_true(scene.optional_rules_overlay.lock_notice_panel.visible, "Lock notice banner visible to player")
	check_false(scene.optional_rules_overlay.primary_btn.visible, "Player does not see Apply button")

	scene.optional_rules_overlay.visible = false

	finish()
