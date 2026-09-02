extends "res://scripts/ui/tabs/tab_skills.gd"
##
## Psionic broads and their powers.
##
## Identical to the Skills tab apart from which half of the catalog it shows, so
## it inherits rather than duplicating. The old UI expressed the same
## relationship as a boolean threaded through five functions.
##

func picker_mode() -> int:
	return SkillPicker.Mode.PSIONIC


func heading() -> String:
	return "Psionics"


## Psionics only applies to characters with psionic potential -- a Mindwalker,
## or a species with the talent. Showing the tab otherwise offers powers that
## cannot be bought.
func is_available_for(context: SheetContext) -> bool:
	if context == null or context.doc == null or context.rules == null:
		return false
	var raw: Dictionary = context.doc.raw()
	var rules: AlternityRules = context.rules
	return (
		rules.is_psionic_character(raw)
		or rules.optional_rule_enabled(raw, "psionic_talents")
		or rules.is_perk_selected(raw, "superior_talent")
		or rules.is_setting_available(raw, "Dark*Matter")
	)


## The energy pool, as a thing you spend from rather than a number you read.
##
## The app computed the pool size from the first commit and gave no way to use
## it. Every power costs points, so the pool is the whole constraint on how
## often a Mindwalker can act -- and a psion at the table was tracking it on
## paper beside an app that knew the number.
func _build_trackers(container: Container) -> void:
	var doc := ctx.doc
	var rules: AlternityRules = ctx.rules
	var palette := ctx.palette
	var pool: Dictionary = rules.psionic_energy(doc.raw())
	var maximum := AlternityNum.as_int(pool.get("max", 0))
	if maximum <= 0:
		return

	var box := Widgets.section(container, "Psionic Energy", palette)

	# Boxes rather than a stepper, matching damage and last resorts: what a
	# psion needs mid-scene is how many powers they have left, which is a shape,
	# not a figure.
	var tracker := DamageTrack.new()
	box.add_child(tracker)
	tracker.setup(palette, "Spent", AlternityNum.as_int(pool.get("used", 0)), maximum)
	tracker.value_changed.connect(func(value: int):
		doc.apply([CharacterDoc.DAMAGE], func(c): rules.set_psionic_energy_used(c, value))
		save_requested.emit())

	Widgets.metric(box, "Pool", str(maximum), palette)
	Widgets.rest_row(
		box, palette, ctx.is_wide_layout,
		func(degree: String):
			doc.apply([CharacterDoc.DAMAGE], func(c):
				if degree == "full":
					rules.full_rest_psionic_energy(c)
				else:
					rules.rest_psionic_energy(c, degree))
			save_requested.emit(),
		[
			["Critical -1", "critical failure",
				"A Critical Failure on the hourly check costs a point, or a point of fatigue "
					+ "if there is none left to lose. Player's Handbook p. 228."],
			["8 hours: full", "full",
				"Eight unbroken hours without using a psionic skill recover the whole pool, "
					+ "with no check. Player's Handbook p. 228."],
		]
	)
