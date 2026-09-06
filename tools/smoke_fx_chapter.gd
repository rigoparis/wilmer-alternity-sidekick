extends "res://tools/test_harness.gd"
##
## The FX chapter, pinned to the manual.
##
## Prices and governing abilities are now read off the book itself: Table F3 on
## p. 14, Table F6 on p. 37 and Table F7 on p. 57 of Beyond Science, each of
## which prints every skill's cost and its ability in parentheses. Where the
## catalog and the page disagreed, the page won -- 41 specialty prices, 37
## specialty abilities and 7 broad prices moved.
##
## Source: Beyond Science: A Guide to FX, Tables F3, F6 and F7.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")

## The three pillars, and which broad skills belong to each.
const PILLARS := {
	"Arcane Magic": [
		"Diabolism", "Enochian", "Hemomancy", "Hermeticism", "Illusion",
		"Mesmerism", "Necromancy", "Pyromancy",
	],
	"Faith": [
		"Alienism", "Druidism", "Hatire", "Incantation",
		"Monotheism", "Shamanism", "Taoism", "Voodoo",
	],
	"Super Hero": [
		"Body Alteration", "Brick", "Chi", "Energy", "Metaconscious", "Movement",
	],
}

## Achievement points per extra point of pool, by campaign scale.
const AP_PER_POOL_POINT := {
	"realistic": 15,
	"heroic": 10,
	"superheroic": 5,
}

## The four Alienism miracles that cannot be attempted on the broad skill alone.
## Every other Faith miracle can; no Arcane spell or Super Power can.
const TRAINED_ONLY_FAITH := [
	"Bend Space", "Gibbering Larvae", "Life Siphon", "Tongue of the Infinite Stars",
]

const MAX_SPECIALTY_RANK := 12

var _rules


func _init() -> void:
	begin("fx chapter")
	_rules = RulesScript.new()
	_rules.load_core_data()

	_test_pillars()
	_test_broad_prices()
	_test_specialty_prices_and_abilities()
	_test_untrained_by_pillar()
	_test_no_broad_is_usable_untrained()
	_test_powers_need_their_broad()
	_test_broad_carries_untrained_specialties()
	_test_activation_cost()
	_test_always_active_costs_triple()
	_test_rank_ceiling()
	_test_one_faith_one_school_many_categories()
	_test_pool_scales()
	_test_pool_rests_like_psionics()

	finish()


func _character(intellect := 12, will := 12, personality := 12) -> Dictionary:
	var character: Dictionary = _rules.default_character()
	character["abilities"]["INT"] = intellect
	character["abilities"]["WIL"] = will
	character["abilities"]["PER"] = personality
	_rules.ensure_character_shape(character)
	_rules.fx.set_fx_talent(character, true)
	_rules.fx.set_energy_pool(character, 10)
	return character


func _specialties() -> Array:
	var out := []
	for pillar in PILLARS:
		for broad_name in PILLARS[pillar]:
			out.append_array(_rules.fx.get_specialty_skills_for_broad(String(broad_name)))
	return out


## Every broad skill in the catalog, in three pillars, each naming its own.
##
## An inventory rather than a reading of one book -- Incantation and Enochian are
## Dark*Matter's and are counted here too, because the point of the check is that
## a school cannot appear or disappear without somebody saying so.
func _test_pillars() -> void:
	var counted := 0
	for pillar in PILLARS:
		for broad_name in PILLARS[pillar]:
			counted += 1
			var broad: Dictionary = _rules.fx.get_broad_skill(String(broad_name))
			if not check(not broad.is_empty(), "%s is in the catalog" % broad_name):
				continue
			check_eq(
				String(broad.get("category", "")), String(pillar),
				"%s belongs to %s" % [broad_name, pillar]
			)
			check_true(
				AlternityNum.as_int(broad.get("cost", 0)) > 0,
				"%s has a skill point price" % broad_name
			)
	check_eq(counted, 22, "the catalog names 22 broad skills")
	check_eq(_rules.fx.get_broad_skills().size(), 22, "and the catalog holds exactly those")


## Broad skill prices, from the three tables.
## Source: Beyond Science pp. 14, 37, 57.
const BROAD_PRICES := {
	"Diabolism": 12, "Hemomancy": 10, "Hermeticism": 9, "Illusion": 8,
	"Mesmerism": 10, "Necromancy": 10, "Pyromancy": 11,
	"Alienism": 11, "Druidism": 12, "Hatire": 14, "Monotheism": 14,
	"Shamanism": 13, "Taoism": 13, "Voodoo": 13,
	"Body Alteration": 9, "Brick": 9, "Chi": 10, "Energy": 10,
	"Metaconscious": 8, "Movement": 10,
}

## A sample of specialties spread across all three pillars, each with the
## ability the table prints in parentheses and the price beside it. These are
## the entries that moved, so they are the ones worth holding still.
## name -> [ability, skill points]
const SPECIALTY_SAMPLE := {
	# Arcane -- Table F3, p. 14
	"Binding": ["PER", 4], "Rend the weave": ["WIL", 2], "Summoning": ["PER", 5],
	"Blood debt": ["INT", 3], "Reciprocity": ["CON", 4], "Stigmata": ["CON", 3],
	"Glamour": ["INT", 4], "Ligature": ["INT", 3], "Sleep of Morpheus": ["INT", 4],
	"Clamor": ["WIL", 4], "Conceal": ["INT", 5], "Programmed response": ["INT", 2],
	"Befriend": ["PER", 4], "Dominate": ["WIL", 3], "Encourage": ["PER", 5],
	"Animate dead": ["INT", 5], "Haunt": ["INT", 5], "Speak with dead": ["INT", 2],
	"Storm of flames": ["WIL", 5], "Immolation": ["WIL", 3],
	# Faith -- Table F6, p. 37
	"Bend space": ["INT", 5], "Life endures": ["INT", 3], "Body and soul": ["WIL", 3],
	"Aura": ["PER", 4], "Guidance": ["PER", 2], "Vision": ["PER", 4],
	"Animal voice": ["PER", 3], "Spirit of the beast": ["WIL", 2],
	"Trance visions": ["PER", 2], "Venom spirit": ["WIL", 4],
	"Energy spiral": ["PER", 5], "Peace": ["PER", 5],
	"Gris-gris": ["WIL", 2], "Legba rides": ["PER", 2], "Loa of healing": ["WIL", 2],
	"Negate the spirit": ["WIL", 5], "Helpful possession": ["WIL", 4],
	# Super Power -- Table F7, p. 57
	"Invisibility": ["WIL", 5], "Stretching": ["CON", 3], "Body Armor": ["CON", 3],
	"Super Strength": ["WIL", 4], "Mighty Leap": ["STR", 2], "Power Climb": ["STR", 2],
	"Energy Resistance": ["CON", 2], "Genius": ["INT", 3],
	"Super Personality": ["INT", 4], "Teleportation": ["WIL", 3],
	"Wallcrawling": ["WIL", 2],
}


func _test_broad_prices() -> void:
	for broad_name in BROAD_PRICES:
		var broad: Dictionary = _rules.fx.get_broad_skill(String(broad_name))
		if not check(not broad.is_empty(), "%s is in the catalog" % broad_name):
			continue
		check_eq(
			AlternityNum.as_int(broad.get("cost", -1)),
			AlternityNum.as_int(BROAD_PRICES[broad_name]),
			"%s costs %d SP" % [broad_name, AlternityNum.as_int(BROAD_PRICES[broad_name])]
		)


func _test_specialty_prices_and_abilities() -> void:
	for skill_name in SPECIALTY_SAMPLE:
		var expected: Array = SPECIALTY_SAMPLE[skill_name]
		var specialty: Dictionary = _rules.fx.get_specialty_skill(String(skill_name))
		if not check(not specialty.is_empty(), "%s is in the catalog" % skill_name):
			continue
		check_eq(
			String(specialty.get("ability", "")), String(expected[0]),
			"%s is governed by %s" % [skill_name, expected[0]]
		)
		check_eq(
			AlternityNum.as_int(specialty.get("cost", -1)),
			AlternityNum.as_int(expected[1]),
			"%s costs %d SP" % [skill_name, AlternityNum.as_int(expected[1])]
		)

	# Voodoo carries seven miracles, not eight. "Ayza rides" was never in the
	# book; "Legba rides" is the one that is.
	check_eq(
		_rules.fx.get_specialty_skills_for_broad("Voodoo").size(), 7,
		"Voodoo holds seven miracles"
	)
	check_true(
		_rules.fx.get_specialty_skill("Ayza rides").is_empty(),
		"and Ayza rides is not among them"
	)
	check_false(
		_rules.fx.get_specialty_skill("Reciprocity").is_empty(),
		"Hemomancy's eighth spell is Reciprocity, spelled as the book spells it"
	)


## Super Powers are trained-only, and most Faith miracles are not.
##
## Arcane Magic is deliberately NOT asserted either way. The catalog derives its
## training flags from each entry's own description text, and that text is not
## trustworthy for this pillar: Beyond Science prints trained-only skills in a
## second colour in Table F3, and the entries it leaves in white include several
## the catalog marks trained-only. Rend the weave is the confirmed case -- its
## description on p. 17 carries the cost line and goes straight into the body,
## with no "This skill can't be used untrained." between them, where Command on
## p. 16 has exactly that line. So at least one flag is wrong, the colour
## separation is too fine to read reliably off a scan, and pinning the current
## values would only defend the error.
func _test_untrained_by_pillar() -> void:
	var faith_untrained := 0
	for specialty in _specialties():
		var name := String(specialty.get("name", ""))
		var pillar := String(specialty.get("category", ""))
		var untrained: bool = bool(specialty.get("untrained", false))
		match pillar:
			"Super Hero":
				# "Purchasing a broad skill provides no benefit other than
				# qualifying a character to buy specialty skills", and every
				# specialty in Table F7 is printed in colour. (p. 57.)
				check_false(untrained, "the power %s is trained-only" % name)
			"Faith":
				if TRAINED_ONLY_FAITH.has(name):
					check_false(untrained, "the miracle %s is trained-only" % name)
				else:
					check_true(untrained, "the miracle %s may be attempted on the faith alone" % name)
					faith_untrained += 1
	check_true(faith_untrained > 40, "most Faith miracles are reachable on the faith alone")

	for name in TRAINED_ONLY_FAITH:
		var specialty: Dictionary = _rules.fx.get_specialty_skill(String(name))
		check_eq(
			String(specialty.get("broad_skill", "")), "Alienism",
			"%s is an Alienism miracle" % name
		)


## "No FX broad skill can ever be used untrained."
func _test_no_broad_is_usable_untrained() -> void:
	var hero: Dictionary = _character()
	for pillar in PILLARS:
		for broad_name in PILLARS[pillar]:
			var score: Dictionary = _rules.fx.fx_skill_score(hero, String(broad_name))
			check_false(
				bool(score.get("usable", true)),
				"%s cannot be attempted without buying it" % broad_name
			)

	# Bought, it rolls its ability score whole -- not halved -- at the broad
	# skill's own +d4.
	_rules.fx.add_fx_skill(hero, "Illusion")
	var illusion: Dictionary = _rules.fx.fx_skill_score(hero, "Illusion")
	check_true(bool(illusion.get("usable", false)), "a bought school is usable")
	check_eq(AlternityNum.as_int(illusion.get("ordinary", 0)), 12, "and rolls INT 12 whole")
	check_eq(String(illusion.get("die", "")), "+d4", "at the broad skill's +d4")


## A power is reachable only through its own school, faith or category.
func _test_powers_need_their_broad() -> void:
	var hero: Dictionary = _character()
	var leaked := 0
	for specialty in _specialties():
		var name := String(specialty.get("name", ""))
		if bool(_rules.fx.fx_skill_score(hero, name).get("usable", false)):
			leaked += 1
			check(false, "%s is out of reach without its broad skill" % name)
	check_eq(leaked, 0, "no FX power is rollable by a hero holding no FX broad skill")

	# Holding one school opens nothing in another.
	_rules.fx.add_fx_skill(hero, "Monotheism")
	check_false(
		bool(_rules.fx.fx_skill_score(hero, "Hellfire").get("usable", false)),
		"a faith does not reach an arcane school's spells"
	)
	var reason := String(_rules.fx.fx_skill_score(hero, "Hellfire").get("reason", ""))
	check_true(reason.contains("Diabolism"), "and the refusal names the school to buy")


## A held broad carries the specialties beneath it that allow untrained use, at
## the broad score and the broad's die. The rest stay shut.
func _test_broad_carries_untrained_specialties() -> void:
	var believer: Dictionary = _character(12, 14, 13)
	_rules.fx.add_fx_skill(believer, "Alienism")
	var broad_score := AlternityNum.as_int(
		_rules.fx.fx_skill_score(believer, "Alienism").get("ordinary", 0)
	)
	check_eq(broad_score, 14, "Alienism rolls the higher of its two abilities")

	# Untrained-allowed: carried by the faith.
	var carried: Dictionary = _rules.fx.fx_skill_score(believer, "Eyes of the Dark Ones")
	check_true(bool(carried.get("usable", false)), "an untrained miracle is reachable on the faith")
	check_eq(
		AlternityNum.as_int(carried.get("ordinary", 0)), broad_score,
		"at the faith's own score"
	)
	check_eq(String(carried.get("die", "")), "+d4", "and the faith's +d4")
	check_true(bool(carried.get("via_broad", false)), "flagged as carried by the broad skill")

	# Trained-only: still shut, even with the faith.
	var shut: Dictionary = _rules.fx.fx_skill_score(believer, "Bend Space")
	check_false(bool(shut.get("usable", true)), "but Bend Space needs a rank of its own")

	# A rank of its own beats leaning on the faith.
	_rules.fx.add_fx_skill(believer, "Eyes of the Dark Ones")
	var trained: Dictionary = _rules.fx.fx_skill_score(believer, "Eyes of the Dark Ones")
	check_eq(
		AlternityNum.as_int(trained.get("ordinary", 0)), broad_score + 1,
		"rank 1 adds to the ability score"
	)
	check_eq(String(trained.get("die", "")), "+d0", "and drops to the specialty's +d0")
	check_false(bool(trained.get("via_broad", true)), "no longer carried by the faith")


## Every power states a cost, and leaning on the broad skill adds a point.
func _test_activation_cost() -> void:
	var hero: Dictionary = _character()
	var costed := 0
	for specialty in _specialties():
		var points := AlternityNum.as_int(specialty.get("fx_cost", 0))
		check_true(
			points >= 1 and points <= 3,
			"%s costs between 1 and 3 FX points" % specialty.get("name", "?")
		)
		if points >= 1:
			costed += 1
	check_eq(costed, _specialties().size(), "every power carries an activation cost")

	_rules.fx.add_fx_skill(hero, "Monotheism")
	var untrained_cost: Dictionary = _rules.fx.fx_activation_cost(hero, "Blessing")
	check_eq(
		AlternityNum.as_int(untrained_cost.get("untrained_surcharge", -1)), 1,
		"a miracle used on the faith alone costs an extra point"
	)
	check_eq(
		AlternityNum.as_int(untrained_cost.get("total", 0)),
		AlternityNum.as_int(untrained_cost.get("points", 0)) + 1,
		"which is added to its listed cost"
	)

	_rules.fx.add_fx_skill(hero, "Blessing")
	var trained_cost: Dictionary = _rules.fx.fx_activation_cost(hero, "Blessing")
	check_eq(
		AlternityNum.as_int(trained_cost.get("untrained_surcharge", -1)), 0,
		"and buying a rank removes the surcharge"
	)


## An always-active power reserves three times its activation cost, forever.
func _test_always_active_costs_triple() -> void:
	var permanent := 0
	for specialty in _specialties():
		if not specialty.has("permanent_cost"):
			continue
		permanent += 1
		var base := AlternityNum.as_int(specialty.get("fx_cost", 0))
		check_eq(
			AlternityNum.as_int(specialty.get("permanent_cost", -1)), base * 3,
			"%s reserves %d, three times its %d point cost"
				% [specialty.get("name", "?"), base * 3, base]
		)
	check_true(permanent > 20, "the Super Power pillar carries always-active powers")


func _test_rank_ceiling() -> void:
	var hero: Dictionary = _character()
	_rules.fx.set_practitioner_type(hero, "adept")
	hero["achievement_level"] = 10
	_rules.fx.add_fx_skill(hero, "Monotheism")
	for _i in 20:
		_rules.fx.add_fx_skill(hero, "Blessing")
	check_eq(
		_rules.fx.fx_skill_rank(hero, "Blessing"), MAX_SPECIALTY_RANK,
		"an FX specialty stops at rank 12"
	)


## One faith at a time; one arcane school at a time; Super Power categories may
## be mixed freely.
func _test_one_faith_one_school_many_categories() -> void:
	var believer: Dictionary = _character()
	_rules.fx.add_fx_skill(believer, "Monotheism")
	check_false(_complains(believer, "only one Faith"), "one faith is fine")
	_rules.fx.add_fx_skill(believer, "Voodoo")
	check_true(_complains(believer, "only one Faith"), "two faiths are not")

	var arcanist: Dictionary = _character()
	_rules.fx.add_fx_skill(arcanist, "Pyromancy")
	check_false(_complains(arcanist, "one school at a time"), "one school is fine")
	_rules.fx.add_fx_skill(arcanist, "Necromancy")
	check_true(_complains(arcanist, "one school at a time"), "two schools are not")

	var superhero: Dictionary = _character()
	for category in PILLARS["Super Hero"]:
		_rules.fx.add_fx_skill(superhero, String(category))
	check_false(
		_complains(superhero, "only one Faith") or _complains(superhero, "one school at a time"),
		"all six Super Power categories may be held at once"
	)

	# A specialty without its parent is called out wherever it came from.
	var stray: Dictionary = _character()
	_rules.fx.add_fx_skill(stray, "Monotheism")
	stray["fx"]["selected_skills"]["Hellfire"] = 2
	check_true(_complains(stray, "requires the Diabolism"), "an orphaned spell is reported")


func _complains(character: Dictionary, fragment: String) -> bool:
	for message in _rules.validate(character):
		if String(message).contains(fragment):
			return true
	return false


## Enlarging the pool is bought with achievement points, at a price set by the
## campaign's scale, and can never pass twice the starting value.
func _test_pool_scales() -> void:
	for scale_id in AP_PER_POOL_POINT:
		var found := false
		for scale in AlternityRules.FX_CAMPAIGN_SCALES:
			if String(scale.get("id", "")) != String(scale_id):
				continue
			found = true
			check_eq(
				AlternityNum.as_int(scale.get("ap_per_point", -1)),
				AlternityNum.as_int(AP_PER_POOL_POINT[scale_id]),
				"a %s campaign charges %d AP per point of pool"
					% [scale_id, AlternityNum.as_int(AP_PER_POOL_POINT[scale_id])]
			)
		check_true(found, "the %s scale exists" % scale_id)
	check_eq(
		AlternityRules.FX_CAMPAIGN_SCALES.size(), 3,
		"there are three campaign scales"
	)

	var hero: Dictionary = _character()
	_rules.fx.set_energy_pool(hero, 10)
	check_eq(
		_rules.achievements.fx_energy_pool_increase_limit(hero), 10,
		"the pool may be doubled, and no further"
	)


## FX rests on the same table psionic energy does.
func _test_pool_rests_like_psionics() -> void:
	var hero: Dictionary = _character()
	_rules.fx.set_energy_pool(hero, 10)
	check_eq(_rules.fx.spend_energy(hero, 6), 6, "spending 6 takes 6")
	check_eq(_rules.fx.rest_energy(hero, "ordinary"), 1, "an Ordinary hour returns 1")
	check_eq(_rules.fx.rest_energy(hero, "good"), 2, "a Good hour returns 2")
	check_eq(_rules.fx.rest_energy(hero, "amazing"), 3, "an Amazing hour returns 3")
	check_eq(_rules.fx.rest_energy(hero, "failure"), 0, "a failed hour returns nothing")
	check_eq(
		AlternityNum.as_int(_rules.fx.fx_energy(hero).get("used", -1)), 0,
		"and six hours of rest clear six points of spend"
	)
