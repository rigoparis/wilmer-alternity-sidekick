extends SheetTab
##
## Skill points, chosen skills, and the picker to buy more.
##
## Shares SkillPicker with the Psionics tab. The old UI shared a function
## instead -- _render_skill_picker, parameterised by an is_psionics boolean that
## also switched four member variables in pairs. Two instances of a control need
## no pairs.
##

const DETAIL_ROUTE := preload("res://scenes/ui/routes/skill_detail_route.tscn")

## Overridden by the Psionics tab.
func picker_mode() -> int:
	return SkillPicker.Mode.NORMAL


func heading() -> String:
	return "Skills"


func watched_sections() -> Array:
	# Skill scores derive from abilities, flaws grant points, and achievements
	# raise the rank cap.
	return [
		CharacterDoc.SKILLS, CharacterDoc.ABILITIES,
		CharacterDoc.PERKS_FLAWS, CharacterDoc.ACHIEVEMENTS, CharacterDoc.META,
	]


func build(container: Container) -> void:
	_build_budget(container)
	_build_trackers(container)
	_build_picker(container)


## A tab whose skills draw on a live resource puts its tracker here, between the
## budget and the catalog: the budget is a creation-time question, the catalog a
## shopping one, and the tracker the only part of the tab used mid-session. The
## Skills tab itself has no such resource.
func _build_trackers(_container: Container) -> void:
	pass


func _build_budget(container: Container) -> void:
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var summary := ctx.doc.summary()

	var box := Widgets.section(container, "%s Budget" % heading(), palette)

	# Bars, not bare numbers. Mid-build the question is always "have I got room",
	# and "18" and "30" on separate rows makes you do the subtraction yourself.
	var sp_used := AlternityNum.as_int(summary.get("skill_points_used", 0))
	var sp_left := AlternityNum.as_int(summary.get("skill_points_remaining", 0))
	Widgets.progress_metric(box, "Skill points", sp_used, sp_used + sp_left, palette)

	var broad_used := AlternityNum.as_int(summary.get("broad_skills_used", 0))
	var broad_left := AlternityNum.as_int(summary.get("broad_skills_remaining", 0))
	Widgets.progress_metric(box, "Broad skills", broad_used, broad_used + broad_left, palette)

	# Two different limits, and conflating them is what let a skill jump several
	# ranks at once, so both are stated.
	var raw := ctx.doc.raw()
	var level := AlternityNum.as_int(raw.get("achievement_level", 1), 1)
	Widgets.metric(
		box, "Specialty rank ceiling",
		str(rules.max_skill_rank_for_character(raw)), palette
	)
	Widgets.muted_text(
		box,
		"Specialties may be bought up to rank 3 while creating the hero."
			if level <= 1 else
		"After creation a specialty gains at most one rank at a time.",
		palette, Widgets.FONT_CAPTION
	)


func _build_picker(container: Container) -> void:
	var box := Widgets.section(container, heading(), ctx.palette)

	var picker := SkillPicker.new()
	box.add_child(picker)
	picker.setup(ctx, picker_mode())
	picker.change_requested.connect(func(): save_requested.emit())
	picker.detail_requested.connect(_open_detail)


func _open_detail(skill: Dictionary) -> void:
	if ctx.router == null:
		return
	var rules: AlternityRules = ctx.rules
	# skill_detail resolves rank, cost and rule notes for this character, which
	# is richer than the bare catalog record.
	var detail: Dictionary = rules.skill_detail(skill, ctx.doc.raw())
	var answer = await ctx.router.push(DETAIL_ROUTE, {
		"palette": ctx.palette,
		"data": detail,
		"title": String(detail.get("name", rules.skill_label(skill))),
		"skill": skill,
		"can_roll": ctx.can_roll(),
	})
	if not is_instance_valid(self):
		return
	# The detail view closes asking to roll rather than rolling itself: it is a
	# reference page, and a page that reached for the tray would need the runner,
	# the transport and the character it deliberately does not have.
	if typeof(answer) == TYPE_DICTIONARY and bool(answer.get("roll", false)):
		await ctx.checks.run(ctx.doc, answer.get("skill", skill))
