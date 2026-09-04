extends SheetTab
##
## The table, as a tab on the player's own sheet.
##
## This used to be a screen of its own, which meant a player at a table could
## either look at the table or look at their character, never both. A campaign
## runs for months and a player spends it doing ordinary character things --
## spending skill points, marking damage, reading a perk -- so the table belongs
## beside those, not instead of them.
##
## Everything here is read or sent; nothing about the campaign is owned by this
## device. The one thing that is owned is the character, and the tab shows what
## the table has done to it: achievement points the GM awarded land on the
## committed hero automatically, because a player at a table is playing one
## character and asking which should receive them is a question with a single
## possible answer.
##

## Only offered when this device is actually at a table.
const CAMPAIGN_SECTION := &"meta"

## Acrobatics - Dodge. Usable untrained, so there is always something to roll.
const SKILL_DODGE := 21

## What a character parries with: whatever they are holding, or their hands. The
## better of the two is offered, which is what a player would pick anyway.
const PARRY_SKILLS := [11, 15]

var _status: Label
var _combat_body: VBoxContainer
var _chat_field: LineEdit
var _private_toggle: CheckButton
var _feed_list: VBoxContainer
var _feed_empty: Label
var _last_award: String = ""


func watched_sections() -> Array:
	# The header shows achievement points, which the GM can change from the far
	# end of a network. Everything else here is table state, not character state.
	return [CharacterDoc.ACHIEVEMENTS, CharacterDoc.META]


## Absent unless there is a table to show. A tab that renders "not connected" is
## a tab that takes up room in the bar for no reason.
func is_available_for(context: SheetContext) -> bool:
	return context != null and context.table != null


func build(container: Container) -> void:
	var table: TableSession = ctx.table
	if table == null:
		return

	# Connected once, not on every rebuild: build() runs again whenever the
	# character changes, and a fresh connection each time would multiply the
	# handlers until one award applied a dozen times.
	if not table.changed.is_connected(_on_table_changed):
		table.changed.connect(_on_table_changed)
		table.ap_applied.connect(_on_ap_applied)
		table.scene_ended.connect(_on_scene_ended)
		table.trouble.connect(_on_trouble)
		table.round_changed.connect(_on_round_changed)
		table.action_check_wanted.connect(_on_action_check_wanted)
		table.attack_arrived.connect(_on_attack_arrived)

	_build_status(container, table)
	_build_combat(container, table)
	_build_chat(container, table)
	_build_feed(container, table)
	_build_leaving(container)


func _build_status(container: Container, table: TableSession) -> void:
	var section := Widgets.section(container, table.campaign_name if not table.campaign_name.is_empty() else "The table", ctx.palette)

	_status = Widgets.text(section, _status_text(table), ctx.palette, Widgets.FONT_BODY)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(1, 0)
	_status.add_theme_color_override(
		"font_color", ctx.palette.accent if table.is_connected_to_table() else ctx.palette.warning
	)

	# Which hero is committed. A player who joined with the wrong character
	# should be able to see that at a glance rather than discover it when the GM
	# reads out the wrong durability.
	var hero := ctx.doc.get_hero_name() if ctx.doc != null else ""
	Widgets.muted_text(
		section,
		"Playing %s at this table." % (hero if not hero.is_empty() else "an unnamed hero"),
		ctx.palette,
		Widgets.FONT_CAPTION
	)

	if not _last_award.is_empty():
		var note := Widgets.text(section, _last_award, ctx.palette, Widgets.FONT_DETAIL, ctx.palette.accent)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(1, 0)


func _status_text(table: TableSession) -> String:
	if table.is_connected_to_table():
		return "At the table."
	return "Not connected. Your character is still yours to edit; nothing reaches the GM until you rejoin."


## The fight, from this player's side.
##
## Read-only: the GM's device owns the round. What this adds beyond mirroring the
## board is the one thing only this player cares about -- which phases their roll
## bought them, and whether it is their turn now.
func _build_combat(container: Container, table: TableSession) -> void:
	var section := Widgets.section(container, "Combat", ctx.palette)
	_combat_body = VBoxContainer.new()
	_combat_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_combat_body.add_theme_constant_override("separation", Widgets.GAP_ROW)
	section.add_child(_combat_body)
	_render_combat(table)


func _render_combat(table: TableSession) -> void:
	if _combat_body == null or not is_instance_valid(_combat_body):
		return
	for child in _combat_body.get_children():
		_combat_body.remove_child(child)
		child.queue_free()

	# First, because somebody is waiting on it and because an attack can arrive
	# when there is no round running at all -- an ambush is not a phase.
	_render_incoming(table)

	var fight: ActionRound = table.active_round
	if fight == null:
		if table.incoming_attacks.is_empty():
			Widgets.muted_text(_combat_body, "No fight running.", ctx.palette, Widgets.FONT_CAPTION)
		return

	var heading := Widgets.text(_combat_body, fight.describe(), ctx.palette, Widgets.FONT_SUBHEADING, ctx.palette.accent)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size = Vector2(1, 0)

	var mine: Dictionary = table.my_combatant()
	if mine.is_empty():
		Widgets.muted_text(_combat_body, "You are not in this fight.", ctx.palette, Widgets.FONT_CAPTION)
		return

	if bool(mine.get("out", false)):
		var down := Widgets.text(
			_combat_body,
			"You are out of the fight: %s" % String(mine.get("out_reason", "down")),
			ctx.palette,
			Widgets.FONT_DETAIL,
			ctx.palette.warning
		)
		down.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		down.custom_minimum_size = Vector2(1, 0)
		return

	if table.owes_action_check():
		var prompt := Widgets.text(
			_combat_body,
			"The GM called for initiative. Roll your action check.",
			ctx.palette,
			Widgets.FONT_BODY
		)
		prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		prompt.custom_minimum_size = Vector2(1, 0)

		var roll := Button.new()
		roll.name = "RollActionCheckButton"
		roll.text = "Roll action check"
		roll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		roll.custom_minimum_size = Vector2(0, 40)
		roll.clip_text = true
		roll.add_theme_stylebox_override("normal", Widgets.flat_style(ctx.palette.surface_soft, ctx.palette.accent, 6))
		roll.pressed.connect(_on_roll_action_check_pressed)
		_combat_body.add_child(roll)
		return

	# What the roll actually bought them. A player who cannot see which phases
	# they reached cannot tell a good action check from a bad one.
	_render_my_phases(fight, mine)

	if table.acting_now():
		var turn := Widgets.text(_combat_body, "It is your turn now.", ctx.palette, Widgets.FONT_BODY, ctx.palette.accent)
		turn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		turn.custom_minimum_size = Vector2(1, 0)

	_render_dodge(table, fight, mine)

	var order: Array = []
	for entry in fight.acting_now():
		order.append(String(entry.get("name", "someone")))
	if not order.is_empty():
		var line := Widgets.muted_text(
			_combat_body, "This phase: " + " . ".join(order), ctx.palette, Widgets.FONT_CAPTION
		)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(1, 0)


## Attacks waiting on this device, and the button that resolves one.
##
## The card says everything the GM already decided -- who, with what, how well it
## landed -- and nothing about what it will cost, because that is not known until
## this device rolls its own armor.
func _render_incoming(table: TableSession) -> void:
	for attack in table.incoming_attacks:
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
		_combat_body.add_child(card)

		var line := Widgets.text(
			card, (attack as CombatAttack).describe(), ctx.palette, Widgets.FONT_BODY,
			ctx.palette.warning if (attack as CombatAttack).hits() else ctx.palette.muted
		)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(1, 0)

		if not (attack as CombatAttack).hits():
			var shrug := _small_button("Dismiss", _on_dismiss_attack_pressed.bind(attack))
			card.add_child(shrug)
			continue

		# What they will be rolling, said before they roll it. Armor that absorbs
		# nothing is worth knowing about in advance.
		var layers: Array = ctx.rules.combat.armor_layers(ctx.doc.raw(), (attack as CombatAttack).impact_type)
		var names: Array = []
		for layer in layers:
			names.append("%s %s" % [String(layer.get("name", "Armor")), String(layer.get("notation", ""))])
		var armor := Widgets.muted_text(
			card,
			("Your armor: " + ", ".join(names)) if not names.is_empty() else "You have nothing to soak it with.",
			ctx.palette,
			Widgets.FONT_CAPTION
		)
		armor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		armor.custom_minimum_size = Vector2(1, 0)

		var resolve := Button.new()
		resolve.name = "ResolveAttackButton"
		resolve.text = "Resolve it"
		resolve.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resolve.custom_minimum_size = Vector2(0, 40)
		resolve.clip_text = true
		resolve.add_theme_stylebox_override("normal", Widgets.flat_style(ctx.palette.surface_soft, ctx.palette.accent, 6))
		resolve.pressed.connect(_on_resolve_attack_pressed.bind(attack))
		card.add_child(resolve)

		# A parry answers one attack rather than the round, so it is offered here
		# rather than on the phase board -- and only against something close
		# enough to turn aside.
		var parry_skill: Dictionary = _parry_skill()
		if (attack as CombatAttack).is_melee and _can_defend(attack) and not parry_skill.is_empty():
			var parry := Button.new()
			parry.name = "ParryButton"
			parry.text = "Parry with %s" % ctx.rules.skill_label(parry_skill)
			parry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			parry.custom_minimum_size = Vector2(0, 36)
			parry.clip_text = true
			parry.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			parry.pressed.connect(_on_parry_pressed.bind(attack))
			card.add_child(parry)

			var note := Widgets.muted_text(
				card,
				"A parry as good as the attack stops it outright. A worse one does nothing, and it costs an action either way.",
				ctx.palette,
				Widgets.FONT_CAPTION
			)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.custom_minimum_size = Vector2(1, 0)


func _small_button(label: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 34)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.pressed.connect(handler)
	return button


## An attack arrived while the player was looking at something else.
func _on_attack_arrived(_attack: CombatAttack) -> void:
	_on_round_changed()


## A miss still travelled here, so it still has to be cleared away.
func _on_dismiss_attack_pressed(attack: CombatAttack) -> void:
	if ctx == null or ctx.table == null:
		return
	ctx.table.apply_attack(attack, 0)
	ctx.table.report_attack(attack, 0, {})
	_on_round_changed()


## Whether this attack can be defended against at all.
##
## The GM decided it when they declared: somebody who never saw it coming, or who
## is pinned, or who is being hit from behind, is not turning anything aside.
func _can_defend(attack: CombatAttack) -> bool:
	if ctx == null or ctx.doc == null:
		return false
	var defence: Dictionary = ctx.rules.combat.target_defence(
		ctx.doc.raw(), attack.is_melee, attack.sees_attacker, attack.from_rear, attack.pinned
	)
	return bool(defence.get("can_parry", false))


## What this character parries with: the better of what they hold and their hands.
func _parry_skill() -> Dictionary:
	if ctx == null or ctx.doc == null:
		return {}
	var best: Dictionary = {}
	var best_score := -1
	for skill_id in PARRY_SKILLS:
		var skill: Dictionary = ctx.rules.get_skill_by_id(skill_id)
		if skill.is_empty():
			continue
		var score: Dictionary = ctx.rules.skill_score(ctx.doc.raw(), skill)
		if not bool(score.get("usable", false)):
			continue
		var ordinary := AlternityNum.as_int(score.get("ordinary", 0))
		if ordinary > best_score:
			best_score = ordinary
			best = skill
	return best


## Turn one attack aside, or fail to.
##
## The comparison is of degrees, not of numbers: a parry as good as the attack
## stops it completely, and a worse one does nothing at all. Either way the
## attack is answered here and then resolved normally -- a failed parry does not
## excuse the character from taking the hit.
func _on_parry_pressed(attack: CombatAttack) -> void:
	if ctx == null or ctx.table == null or ctx.checks == null or ctx.doc == null:
		return
	var skill: Dictionary = _parry_skill()
	if skill.is_empty():
		return

	var check := SkillCheck.call_for(ctx.rules.skill_label(skill), 0, "Parrying", AlternityNum.as_int(skill.get("id", -1), -1))
	var rolled = await ctx.checks.run_called(check, ctx.doc, skill)
	if not is_instance_valid(self) or rolled == null:
		return

	if not ctx.rules.combat.parry_blocks(attack.degree, (rolled as SkillCheck).degree()):
		# It got through. The attack still has to be resolved, so hand them
		# straight on to doing that rather than leaving the card looking answered.
		_on_trouble("The parry was not good enough -- the attack still lands.")
		await _on_resolve_attack_pressed(attack)
		return

	var outcome: Dictionary = ctx.table.apply_attack(attack, 0, true)
	ctx.table.report_attack(attack, 0, outcome, false, true)
	_on_round_changed()


## Resolve one attack, in the order the rules put it.
##
## Armor first, because absorption comes off the damage before anything else.
## Then the damage lands on this device's own sheet. Then, if it was an Amazing
## hit, the endurance check to stay standing -- rolled after the damage, because
## being hurt is part of what makes it hard to stay conscious.
func _on_resolve_attack_pressed(attack: CombatAttack) -> void:
	if ctx == null or ctx.table == null or ctx.checks == null or ctx.doc == null:
		return

	var absorbed := 0
	for layer in ctx.rules.combat.armor_layers(ctx.doc.raw(), attack.impact_type):
		var rolled: int = await ctx.checks.roll_notation(
			String(layer.get("notation", "")),
			"%s absorbs" % String(layer.get("name", "Armor"))
		)
		if not is_instance_valid(self):
			return
		# Walking away from the tray is not an answer, and the attack stays in the
		# queue until it gets one.
		if rolled < 0:
			return
		# Layers do not add up: every one is rolled, and the best of them answers.
		absorbed = maxi(absorbed, rolled)

	var knockout: Dictionary = ctx.table.knockout_check_for(attack)
	var outcome: Dictionary = ctx.table.apply_attack(attack, absorbed)

	var down := false
	if bool(knockout.get("required", false)) and not bool(outcome.get("negated", false)):
		down = not await _survives_the_hit(knockout)
		if not is_instance_valid(self):
			return

	ctx.table.report_attack(attack, absorbed, outcome, down)
	_on_round_changed()
	save_requested.emit()


## The Stamina-endurance check an Amazing hit forces.
##
## Returns true when they stay standing, which is also what an abandoned roll
## returns -- refusing to throw the dice must not be a way to be knocked out.
func _survives_the_hit(knockout: Dictionary) -> bool:
	var skill: Dictionary = ctx.rules.get_skill_by_id(AlternityNum.as_int(knockout.get("skill_id", -1), -1))
	if skill.is_empty():
		return true
	var check := SkillCheck.call_for(
		ctx.rules.skill_label(skill),
		0,
		String(knockout.get("reason", "")),
		AlternityNum.as_int(knockout.get("skill_id", -1), -1)
	)
	var rolled = await ctx.checks.run_called(check, ctx.doc, skill)
	if rolled == null:
		return true
	return (rolled as SkillCheck).is_success()


## The dodge, and what it costs.
##
## Offered only while they have an action to spend it on, and said out loud in
## the button's own caption: one dodge covers every attack for the rest of the
## round, it takes the action for this phase, and everything they do afterwards
## is one step worse. That is a real decision, and a button that only said
## "Dodge" would hide both halves of it.
func _render_dodge(table: TableSession, fight: ActionRound, mine: Dictionary) -> void:
	if table.is_dodging():
		var already := Widgets.text(
			_combat_body,
			"You are dodging (%s). It covers every attack until the round ends." % fight.dodge_of(String(mine.get("id", ""))),
			ctx.palette,
			Widgets.FONT_DETAIL,
			ctx.palette.accent
		)
		already.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		already.custom_minimum_size = Vector2(1, 0)
		return

	if AlternityNum.as_int(mine.get("actions", 0)) <= 0:
		Widgets.muted_text(
			_combat_body, "You have no actions left this round.", ctx.palette, Widgets.FONT_CAPTION
		)
		return

	var dodge := Button.new()
	dodge.name = "DodgeButton"
	dodge.text = "Dodge"
	dodge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dodge.custom_minimum_size = Vector2(0, 40)
	dodge.clip_text = true
	dodge.pressed.connect(_on_dodge_pressed)
	_combat_body.add_child(dodge)

	var cost := Widgets.muted_text(
		_combat_body,
		"Costs your action this phase and puts +%d step on everything after it. One dodge covers every attack for the rest of the round."
			% ctx.rules.combat.DODGE_LATER_PENALTY,
		ctx.palette,
		Widgets.FONT_CAPTION
	)
	cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cost.custom_minimum_size = Vector2(1, 0)


func _on_dodge_pressed() -> void:
	if ctx == null or ctx.table == null or ctx.checks == null or ctx.doc == null:
		return
	var skill: Dictionary = ctx.rules.get_skill_by_id(SKILL_DODGE)
	if skill.is_empty():
		return
	var check := SkillCheck.call_for(ctx.rules.skill_label(skill), 0, "Dodging", SKILL_DODGE)
	var rolled = await ctx.checks.run_called(check, ctx.doc, skill)
	if not is_instance_valid(self) or rolled == null:
		return
	ctx.table.send_dodge(rolled)
	_on_round_changed()


## Which phases this player acts in.
##
## Their earned phase and every one after it, limited by how many actions they
## have -- the same rule the round enforces, said out loud so the number on the
## sheet means something.
func _render_my_phases(fight: ActionRound, mine: Dictionary) -> void:
	var earned := String(mine.get("degree", ""))
	if earned.is_empty():
		return
	var reached: Array = []
	for phase_id in ActionRound.PHASES:
		for entry in fight.acting_in(String(phase_id)):
			if String(entry.get("id", "")) == String(mine.get("id", "")):
				reached.append(String(ActionRound.PHASE_NAMES.get(phase_id, phase_id)))
				break

	var text := "You rolled %s, so you act in: %s" % [
		String(ActionRound.PHASE_NAMES.get(earned, earned)),
		", ".join(reached) if not reached.is_empty() else "nothing this round",
	]
	var line := Widgets.text(_combat_body, text, ctx.palette, Widgets.FONT_DETAIL)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(1, 0)


func _on_round_changed() -> void:
	if ctx != null and ctx.table != null:
		_render_combat(ctx.table)


## The GM started a round and this device owes a check.
##
## Rolled from a button rather than thrown at the player: a tray opening by
## itself while they are reading their sheet is an ambush, not a prompt.
func _on_action_check_wanted() -> void:
	_on_round_changed()


func _on_roll_action_check_pressed() -> void:
	if ctx == null or ctx.table == null or ctx.checks == null:
		return
	var rolled = await ctx.checks.run_action_check(ctx.doc)
	if not is_instance_valid(self) or rolled == null:
		return
	ctx.table.send_action_check(rolled)
	_on_round_changed()


func _build_chat(container: Container, table: TableSession) -> void:
	var section := Widgets.section(container, "Say something", ctx.palette)

	_chat_field = LineEdit.new()
	_chat_field.name = "TableChatField"
	_chat_field.placeholder_text = "Message the table"
	_chat_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_field.custom_minimum_size = Vector2(0, 40)
	_chat_field.text_submitted.connect(func(_text: String): _send(table))
	section.add_child(_chat_field)

	_private_toggle = CheckButton.new()
	_private_toggle.text = "Only the GM sees this"
	_private_toggle.add_theme_color_override("font_color", ctx.palette.text)
	section.add_child(_private_toggle)

	var send := Button.new()
	send.name = "SendChatButton"
	send.text = "Send"
	send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	send.custom_minimum_size = Vector2(0, 40)
	send.clip_text = true
	send.pressed.connect(func(): _send(table))
	section.add_child(send)


func _build_feed(container: Container, table: TableSession) -> void:
	var section := Widgets.section(container, "Table log", ctx.palette)
	_feed_empty = Widgets.muted_text(section, "Nothing has happened yet.", ctx.palette)

	_feed_list = VBoxContainer.new()
	_feed_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feed_list.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	section.add_child(_feed_list)
	_render_feed(table)


func _build_leaving(container: Container) -> void:
	var leave := Button.new()
	leave.name = "LeaveTableButton"
	leave.text = "Leave the table"
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.custom_minimum_size = Vector2(0, 40)
	leave.clip_text = true
	leave.pressed.connect(_on_leave_pressed)
	container.add_child(leave)


func _render_feed(table: TableSession) -> void:
	if _feed_list == null:
		return
	for child in _feed_list.get_children():
		_feed_list.remove_child(child)
		child.queue_free()

	var recent := table.recent()
	_feed_empty.visible = recent.is_empty()
	for event in recent:
		var row := Label.new()
		row.text = table.describe(event)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(1, 0)
		row.add_theme_color_override("font_color", ctx.palette.text)
		row.add_theme_font_size_override("font_size", Widgets.FONT_DETAIL)
		_feed_list.add_child(row)


# --- Reacting --------------------------------------------------------------

func _on_table_changed() -> void:
	if ctx == null or ctx.table == null or _feed_list == null or not is_instance_valid(_feed_list):
		return
	# Only the parts that move. A full rebuild would take the cursor out of the
	# message box every time anybody at the table said anything.
	_render_feed(ctx.table)
	if _status != null and is_instance_valid(_status):
		_status.text = _status_text(ctx.table)


func _on_ap_applied(amount: int, reason: String) -> void:
	_last_award = "The GM awarded you %d achievement point%s -- %s. Added to your hero." % [
		amount, "" if amount == 1 else "s", reason
	]
	# The character changed, so the sheet is rebuilding anyway; this only needs
	# to make sure the note is on screen when it does.
	refresh(true)


## The GM ended the scene and this hero's stun cleared.
##
## Worth saying out loud: a damage track emptying itself while somebody is
## looking at another tab is otherwise indistinguishable from a bug.
func _on_scene_ended(stun_cleared: int) -> void:
	_last_award = "The scene ended -- %d stun cleared. Anybody it knocked out is awake." % stun_cleared
	refresh(true)


func _on_trouble(message: String) -> void:
	if _status == null or not is_instance_valid(_status):
		return
	_status.text = message
	_status.add_theme_color_override("font_color", ctx.palette.warning)


func _send(table: TableSession) -> void:
	if _chat_field == null:
		return
	table.send_chat(_chat_field.text, _private_toggle.button_pressed)
	_chat_field.text = ""


func _on_leave_pressed() -> void:
	if ctx != null and ctx.table != null:
		# The shell owns what happens next -- it has to take the sheet down and
		# put the character list back -- so this only says the player asked.
		ctx.table.leave_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed(&"table_chat") and _chat_field != null:
		_chat_field.grab_focus()
		get_viewport().set_input_as_handled()
