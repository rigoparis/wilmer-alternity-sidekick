extends "res://tools/test_harness.gd"

##
## Automated smoke test suite for the core Perks chapter.
##
## Every value below is transcribed from the scanned page, not read back out of
## PERK_DEFINITIONS -- a suite that sources its expectations from the data under
## test cannot fail. Table P26 is on Player's Handbook p. 103; the perk
## descriptions run pp. 103-107.
##
## The page map was read off the scans directly:
##   p. 103  Table P26, Alien Artifact (begins)
##   p. 104  Alien Artifact (ends), Ambidextrous, Animal Friend, Celebrity,
##           Concentration, Danger Sense, Faith, Filthy Rich (begins)
##   p. 105  Filthy Rich (ends), Fists of Iron, Fortitude, Good Luck,
##           Great Looks, Heightened Ability, Observant, Photo Memory,
##           Powerful Ally, Psionic Awareness
##   p. 106  Reflexes, Reputation, Tough as Nails, Vigor (begins)
##   p. 107  Vigor (ends), Willpower
##

const AlternityRules = preload("res://scripts/alternity_rules.gd")


## Table P26, column for column: id -> [cost_options, ability, activation].
## Alien Artifact's Ability column prints an em dash, not "Special" -- the
## "Special" in its row belongs to the Type column.
const TABLE_P26 := {
	"alien_artifact": [[8], "—", "Special"],
	"ambidextrous": [[4], "DEX", "Active"],
	"animal_friend": [[4], "WIL", "Conscious"],
	"celebrity": [[3], "PER", "Conscious"],
	"concentration": [[3], "INT", "Conscious"],
	"danger_sense": [[4], "WIL", "Active"],
	"faith": [[5], "WIL", "Conscious"],
	"filthy_rich": [[6], "PER", "Conscious"],
	"fists_of_iron": [[2, 5], "STR", "Active"],
	"fortitude": [[4], "CON", "Active"],
	"good_luck": [[3], "WIL", "Conscious"],
	"great_looks": [[3], "PER", "Active"],
	"heightened_ability": [[10], "Special", "Active"],
	"observant": [[3], "WIL", "Active"],
	"photo_memory": [[3], "INT", "Conscious"],
	"powerful_ally": [[4], "PER", "Conscious"],
	"psionic_awareness": [[3], "INT", "Active"],
	"reflexes": [[4], "DEX", "Active"],
	"reputation": [[3], "WIL", "Active"],
	"tough_as_nails": [[4], "STR", "Active"],
	"vigor": [[2, 3, 4], "CON", "Active"],
	"willpower": [[4], "WIL", "Active"],
}

## The page each perk's description actually occupies.
const PERK_PAGES := {
	"alien_artifact": "p. 103-104",
	"ambidextrous": "p. 104",
	"animal_friend": "p. 104",
	"celebrity": "p. 104",
	"concentration": "p. 104",
	"danger_sense": "p. 104",
	"faith": "p. 104",
	"filthy_rich": "p. 104-105",
	"fists_of_iron": "p. 105",
	"fortitude": "p. 105",
	"good_luck": "p. 105",
	"great_looks": "p. 105",
	"heightened_ability": "p. 105",
	"observant": "p. 105",
	"photo_memory": "p. 105",
	"powerful_ally": "p. 105",
	"psionic_awareness": "p. 105",
	"reflexes": "p. 106",
	"reputation": "p. 106",
	"tough_as_nails": "p. 106",
	"vigor": "p. 106-107",
	"willpower": "p. 107",
}


func _init() -> void:
	begin("perks chapter audit")
	var rules := AlternityRules.new()
	rules.load_core_data()

	print("--- 1. Table P26: cost, ability and type (PHB p. 103) ---")
	for perk_id in TABLE_P26:
		var row: Array = TABLE_P26[perk_id]
		var perk: Dictionary = rules.get_perk_by_id(perk_id)
		if not check_eq(perk.is_empty(), false, "core perk '%s' exists" % perk_id):
			continue
		check_eq(perk.get("cost_options"), row[0], "%s costs %s SP" % [perk_id, row[0]])
		check_eq(String(perk.get("ability", "")), row[1], "%s is ability %s" % [perk_id, row[1]])
		check_eq(String(perk.get("activation", "")), row[2], "%s is type %s" % [perk_id, row[2]])
		check_eq(String(perk.get("setting", "")), "", "core perk '%s' has no setting gate" % perk_id)
		check_eq(String(perk.get("supplement", "")), "", "core perk '%s' has no supplement gate" % perk_id)

	print("--- 2. Page citations match the printed layout ---")
	for perk_id in PERK_PAGES:
		var perk: Dictionary = rules.get_perk_by_id(perk_id)
		var source := String(perk.get("source", ""))
		var want: String = PERK_PAGES[perk_id]
		check_eq(
			source,
			"Player's Handbook %s; Table P26." % want,
			"%s cites %s" % [perk_id, want]
		)

	print("--- 3. Every perk carries a source the sheet can show ---")
	# The catalog and the taken-perk rows print this string verbatim, so an
	# empty one is a blank line in the UI rather than a missing citation.
	for perk_id in rules.perks_by_id:
		var perk: Dictionary = rules.perks_by_id[perk_id]
		check_eq(
			String(perk.get("source", "")).strip_edges().is_empty(),
			false,
			"perk '%s' has a non-empty source" % perk_id
		)

	print("--- 4. Table D2: the seven new Dark*Matter perks (DM p. 59) ---")
	# Table D2 reprints every core perk and underlines the ones new to the
	# setting. These seven are the underlined rows; nothing else in the table is
	# a Dark*Matter perk, which is why an eighth would be a fabrication.
	var table_d2 := {
		"gearhead": [[4], "PER", "Active"],
		"hidden_identity": [[3, 6], "PER", "Active"],
		"high_tech": [[4], "—", "Special"],
		"networked": [[2], "PER", "Active"],
		"second_sight": [[4], "WIL", "Conscious"],
		"superior_talent": [[4, 6], "WIL", "Active"],
		"well_traveled": [[4], "PER", "Conscious"],
	}
	for perk_id in table_d2:
		var row: Array = table_d2[perk_id]
		var perk: Dictionary = rules.get_perk_by_id(perk_id)
		if not check_eq(perk.is_empty(), false, "dark matter perk '%s' exists" % perk_id):
			continue
		check_eq(perk.get("cost_options"), row[0], "%s costs %s SP" % [perk_id, row[0]])
		check_eq(String(perk.get("ability", "")), row[1], "%s is ability %s" % [perk_id, row[1]])
		check_eq(String(perk.get("activation", "")), row[2], "%s is type %s" % [perk_id, row[2]])
		check_eq(perk.get("setting"), "Dark Matter", "%s is gated to Dark Matter" % perk_id)

	# High Tech's Ability column is a dash and its Type is Special, exactly as
	# with Alien Artifact -- the two are easy to conflate.
	check_eq(String(rules.get_perk_by_id("high_tech").get("ability", "")), "—",
		"high tech ability column is an em dash")

	print("--- 5. Table F1: the five FX perks (Beyond Science p. 5) ---")
	# Table F1 is the whole list. Six perks that used to ship here were in no
	# book at all, so this asserts the exact set rather than only the survivors:
	# a fabrication added later has to fail this.
	var table_f1 := {
		"fx_awareness": [[3], "INT", "Active"],
		"fx_mastery": [[4], "Varies", "Active"],
		"fx_resistance": [[5], "Varies", "Active"],
		"mentor": [[4], "PER", "Conscious"],
		"rapid_fx_recovery": [[5], "WIL", "Active"],
	}
	for perk_id in table_f1:
		var row: Array = table_f1[perk_id]
		var perk: Dictionary = rules.get_perk_by_id(perk_id)
		if not check_eq(perk.is_empty(), false, "FX perk '%s' exists" % perk_id):
			continue
		check_eq(perk.get("cost_options"), row[0], "%s costs %s SP" % [perk_id, row[0]])
		check_eq(String(perk.get("ability", "")), row[1], "%s is ability %s" % [perk_id, row[1]])
		check_eq(String(perk.get("activation", "")), row[2], "%s is type %s" % [perk_id, row[2]])
		check_eq(perk.get("supplement"), "beyond_science", "%s comes from Beyond Science" % perk_id)

	var fx_perk_ids: Array = []
	for perk_id in rules.perks_by_id:
		if String(rules.perks_by_id[perk_id].get("supplement", "")) == "beyond_science":
			fx_perk_ids.append(String(perk_id))
	fx_perk_ids.sort()
	var expected_f1: Array = table_f1.keys()
	expected_f1.sort()
	check_eq(fx_perk_ids, expected_f1, "Beyond Science ships exactly the five Table F1 perks")

	# The six that were invented. Named individually so a reintroduction says
	# which one came back.
	for ghost in [
		"combat_master", "efficient_fx_energy", "extended_fx_duration",
		"improved_fx_area", "improved_fx_range", "increased_fx_energy",
		"fast_fx_recovery",
	]:
		check_eq(
			rules.get_perk_by_id(ghost).is_empty(), true,
			"'%s' is not a perk in any book" % ghost
		)

	print("--- 6. Table D21: the twelve robot perks (Dataware p. 77) ---")
	# Table D21 has 22 rows, but 10 carry an asterisk meaning "this is the
	# Player's Handbook perk, also open to robots". Only these 12 are new, and
	# seven entries that used to ship under this supplement were in no book.
	var table_d21 := {
		"detachable_system": [[3], "CON", "Conscious", 6],
		"emancipated": [[5], "PER", "Active", 7],
		"fuzzy_logic": [[4], "PER", "Conscious", 7],
		"hidden_system": [[4], "DEX", "Conscious", 0],
		"language_module": [[6], "INT", "Conscious", 8],
		"lightweight_alloy": [[3], "DEX", "Active", 0],
		"memory_implants": [[4], "PER", "Active", 8],
		"nanite_self_repair": [[4, 7, 10], "CON", "Active", 7],
		"redundant_systems": [[6], "CON", "Active", 0],
		"remote_backups": [[5], "INT", "Active", 0],
		"self_editing_program": [[4], "INT", "Conscious", 6],
		"superior_tech": [[5], "CON", "Active", 0],
	}
	for perk_id in table_d21:
		var row: Array = table_d21[perk_id]
		var perk: Dictionary = rules.get_perk_by_id(perk_id)
		if not check_eq(perk.is_empty(), false, "robot perk '%s' exists" % perk_id):
			continue
		check_eq(perk.get("cost_options"), row[0], "%s costs %s SP" % [perk_id, row[0]])
		check_eq(String(perk.get("ability", "")), row[1], "%s is ability %s" % [perk_id, row[1]])
		check_eq(String(perk.get("activation", "")), row[2], "%s is type %s" % [perk_id, row[2]])
		check_eq(perk.get("supplement"), "dataware", "%s comes from Dataware" % perk_id)
		# A dash in the PL column is stored as no key at all.
		check_eq(
			AlternityNum.as_int(perk.get("pl", 0)), row[3],
			"%s requires PL %s" % [perk_id, "none" if row[3] == 0 else str(row[3])]
		)

	var robot_perk_ids: Array = []
	for perk_id in rules.perks_by_id:
		if String(rules.perks_by_id[perk_id].get("supplement", "")) == "dataware":
			robot_perk_ids.append(String(perk_id))
	robot_perk_ids.sort()
	var expected_d21: Array = table_d21.keys()
	expected_d21.sort()
	check_eq(robot_perk_ids, expected_d21, "Dataware ships exactly the twelve Table D21 perks")

	for ghost in [
		"adaptive_programming", "composite_structure", "environmental_shielding",
		"heavy_chassis", "modular_mounts", "overclocked", "reinforced_casing",
		"self_repair",
	]:
		check_eq(
			rules.get_perk_by_id(ghost).is_empty(), true,
			"'%s' is not a perk in any book" % ghost
		)

	print("--- 7. Alien Artifact's ability is a dash, not its type ---")
	# Regression guard: the Ability column reads "—" while the Type column reads
	# "Special". Copying the type into the ability field made it look like
	# Heightened Ability, which really is ability "Special".
	check_eq(String(rules.get_perk_by_id("alien_artifact").get("ability", "")), "—",
		"alien artifact ability column is an em dash")
	check_eq(String(rules.get_perk_by_id("heightened_ability").get("ability", "")), "Special",
		"heightened ability is the only core perk with ability Special")

	finish()
