extends "res://tools/test_harness.gd"
##
## Skill detail content, in both the authored and the legacy shape.
##
## The legacy path is run against every FX power in the shipped data, since that
## is what the app renders today and will keep rendering until the descriptions
## are rewritten one at a time.
##

const Detail := preload("res://scripts/core/skill_detail.gd")
const DetailView := preload("res://scripts/ui/skill_detail_view.gd")
const Palette := preload("res://scripts/core/theme_palette.gd")


func _init() -> void:
	begin_async("skill detail", 300)
	_run.call_deferred()


func _run() -> void:
	_test_authored_sections()
	_test_unknown_kind_degrades()
	_test_legacy_split()
	_test_legacy_rank_benefits()
	_test_every_shipped_fx_power()
	await _test_view_renders()
	finish()


## The target shape, using Animate Dead as written in the new format.
func _test_authored_sections() -> void:
	var data := {
		"name": "Animate Dead",
		"meta": "Cost: 4 skill points / Transform spell (1 FX energy point)",
		"sections": [
			Detail.text_section("Effect", "Imbues corpses within 30 meters with basic mobility."),
			Detail.text_section("Decay Penalties", "Dead 1-6 weeks (+1 step)."),
			Detail.outcomes_section("Duration", "1 day", "1 week", "1 month"),
			Detail.text_section("Synergies", "Medical Science grants a step bonus."),
			Detail.ranks_section("Rank Benefits", [
				Detail.rank_entry(6, "More Durable Zombies", "Zombies gain +1 to each durability rating."),
				Detail.rank_entry(12, "", "Durability bonus increases to +2."),
			]),
		],
	}

	check_true(Detail.is_structured(data), "an authored record reports as structured")
	var detail := Detail.from_data(data)

	check_eq(detail.title, "Animate Dead", "title is read")
	check_true(detail.subtitle.contains("4 skill points"), "meta becomes the subtitle")
	check_eq(
		detail.section_titles(),
		["Effect", "Decay Penalties", "Duration", "Synergies", "Rank Benefits"],
		"authored section order is preserved"
	)

	var duration := detail.find_section("Duration")
	check_eq(duration.get("kind", ""), Detail.KIND_OUTCOMES, "Duration is an outcomes section")
	check_eq(duration.get("good", ""), "1 week", "outcomes keep each degree")

	var ranks := detail.find_section("Rank Benefits")
	check_eq(ranks.get("entries", []).size(), 2, "both rank entries survive")
	check_eq(ranks["entries"][0]["title"], "More Durable Zombies", "a rank entry carries its own name")
	check_eq(ranks["entries"][0]["rank"], 6, "rank numbers are coerced to int")

	# Not every skill has every section -- the stated requirement.
	var minimal := Detail.from_data({
		"name": "Simple Power",
		"sections": [Detail.text_section("Effect", "Does one thing.")],
	})
	check_eq(minimal.section_titles(), ["Effect"], "a skill may have a single section")
	check_true(minimal.find_section("Rank Benefits").is_empty(), "a missing section is simply absent")


## Data may introduce a section kind before the view knows it; the content must
## still appear rather than vanishing.
func _test_unknown_kind_degrades() -> void:
	var detail := Detail.from_data({
		"name": "Future Power",
		"sections": [{"kind": "timeline", "title": "Phases", "body": "Three phases."}],
	})
	check_eq(detail.sections.size(), 1, "an unknown kind is kept")
	check_eq(detail.sections[0]["kind"], Detail.KIND_TEXT, "an unknown kind degrades to text")
	check_eq(detail.sections[0]["body"], "Three phases.", "its content survives")

	# Malformed entries are dropped rather than crashing the view.
	var junk := Detail.from_data({"name": "Junk", "sections": ["not a dictionary", 42]})
	check_eq(junk.sections.size(), 0, "non-dictionary sections are dropped")


## The legacy prose carries its labels inline; splitting them is what makes the
## old data render as sections without being rewritten first.
func _test_legacy_split() -> void:
	var detail := Detail.from_data({
		"name": "Animate dead",
		"description": "Governing Ability: Will (WIL). Player Notes: This spell imbues one or more dead bodies with enough life energy to allow them movement.",
		"rank_benefits": {},
	})

	check_false(Detail.is_structured({"description": "x"}), "a legacy record is not structured")
	check_eq(
		detail.section_titles(), ["Governing Ability", "Player Notes"],
		"inline labels become section titles"
	)
	check_true(
		String(detail.find_section("Player Notes").get("body", "")).begins_with("This spell imbues"),
		"the body after a label becomes that section"
	)

	# A colon mid-sentence must not be mistaken for a label. Splitting only on
	# known labels is what prevents this; a general "Capitalised words followed
	# by a colon" rule turns this sentence into a section titled "The hero faces
	# a choice", which is the false positive the old heuristic made.
	var prose := Detail.from_data({
		"name": "Prose",
		"description": "The hero faces a choice: press on or retreat, and either way the risk is real.",
	})
	check_eq(prose.sections.size(), 1, "prose with a mid-sentence colon stays one section")
	check_eq(prose.sections[0]["title"], "", "no spurious section title is invented")

	# Text before the first label is kept.
	var lead := Detail.from_data({
		"name": "Lead",
		"description": "An opening sentence. Player Notes: the rest.",
	})
	check_eq(lead.sections.size(), 2, "lead text is kept as its own section")
	check_eq(lead.sections[0]["title"], "", "lead text is untitled")

	check_eq(Detail.from_data({"name": "Empty"}).sections.size(), 0, "a record with no content has no sections")


func _test_legacy_rank_benefits() -> void:
	var detail := Detail.from_data({
		"name": "Ranked",
		"description": "Does a thing.",
		# Keys are strings, so a naive sort would put 12 before 6.
		"rank_benefits": {"12": "At rank 12, more.", "6": "At rank 6, some."},
	})

	var ranks := detail.find_section("Rank Benefits")
	if not check(not ranks.is_empty(), "legacy rank_benefits become a ranks section"):
		return
	var entries: Array = ranks["entries"]
	check_eq(entries.size(), 2, "both thresholds are kept")
	check_eq(entries[0]["rank"], 6, "thresholds sort numerically, not as strings")
	check_eq(entries[1]["rank"], 12, "the higher threshold comes second")
	check_eq(entries[0]["title"], "", "legacy entries have no per-benefit name")
	check_true(String(entries[0]["body"]).contains("rank 6"), "the body is carried over")


## Every FX power in the shipped data must produce something renderable.
func _test_every_shipped_fx_power() -> void:
	var file := FileAccess.open("res://data/rules/fx_core.json", FileAccess.READ)
	if not check(file != null, "fx_core.json opens"):
		return
	var data = JSON.parse_string(file.get_as_text())
	if not check(typeof(data) == TYPE_DICTIONARY, "fx_core.json parses"):
		return

	var powers: Dictionary = data.get("specialty_skills", {})
	check_true(powers.size() > 100, "found the FX catalog (%d powers)" % powers.size())

	var empty: Array = []
	var labelled := 0
	var with_ranks := 0
	for name in powers:
		var detail := Detail.from_data(powers[name])
		if detail.is_empty():
			if empty.size() < 6:
				empty.append(name)
			continue
		for section_title in detail.section_titles():
			if not String(section_title).is_empty():
				labelled += 1
				break
		if not detail.find_section("Rank Benefits").is_empty():
			with_ranks += 1

	check_true(empty.is_empty(), "every FX power yields sections (empty: %s)" % str(empty))
	# Roughly 109 of 140 carry "Governing Ability:", so most should split.
	check_true(
		labelled > powers.size() * 0.7,
		"most powers split into titled sections (%d of %d)" % [labelled, powers.size()]
	)
	check_true(with_ranks > 0, "some powers have rank benefits (%d)" % with_ranks)


func _test_view_renders() -> void:
	var palette = Palette.new()
	var view = DetailView.new()
	root.add_child(view)

	var detail := Detail.from_data({
		"name": "Animate Dead",
		"meta": "Cost: 4 skill points",
		"sections": [
			Detail.text_section("Effect", "Imbues corpses with mobility."),
			Detail.outcomes_section("Duration", "1 day", "1 week", "1 month"),
			Detail.ranks_section("Rank Benefits", [
				Detail.rank_entry(6, "More Durable Zombies", "Zombies gain +1 durability."),
			]),
		],
	})
	view.render(detail, palette)
	await process_frame
	check_true(view.get_child_count() > 0, "the view produced content")
	var first_render := view.get_child_count()

	# Rendering again replaces rather than appends.
	view.render(detail, palette)
	await process_frame
	check_eq(view.get_child_count(), first_render, "re-rendering replaces the previous content")

	# A skill with nothing recorded says so instead of rendering blank.
	view.render(Detail.from_data({"name": "Bare"}), palette)
	await process_frame
	check_true(view.get_child_count() > 0, "an empty detail still renders a message")

	view.queue_free()
