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
	return context.rules.is_psionic_character(context.doc.raw())
