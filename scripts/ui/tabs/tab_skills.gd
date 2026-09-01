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
	_build_picker(container)


func _build_budget(container: Container) -> void:
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var summary := ctx.doc.summary()

	var box := Widgets.section(container, "%s Budget" % heading(), palette)
	Widgets.metric(box, "Skill points used", str(AlternityNum.as_int(summary.get("skill_points_used", 0))), palette)
	Widgets.metric(box, "Points remaining", str(AlternityNum.as_int(summary.get("skill_points_remaining", 0))), palette)
	Widgets.metric(
		box, "Broad skills",
		"%d / %d" % [
			AlternityNum.as_int(summary.get("broad_skills_used", 0)),
			AlternityNum.as_int(summary.get("broad_skills_used", 0)) + AlternityNum.as_int(summary.get("broad_skills_remaining", 0)),
		],
		palette
	)
	Widgets.metric(box, "Max specialty rank", str(rules.max_skill_rank_for_character(ctx.doc.raw())), palette)


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
	await ctx.router.push(DETAIL_ROUTE, {
		"palette": ctx.palette,
		"data": detail,
		"title": String(detail.get("name", rules.skill_label(skill))),
	})
