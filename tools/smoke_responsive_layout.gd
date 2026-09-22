extends "res://tools/test_harness.gd"
##
## Every screen, tab and route, at every window size we support, with nothing
## out of reach.
##
## The defect this exists to catch is not a wrong number, it is geometry: a tab
## laid out taller or wider than the window while nothing is able to scroll it.
## The content is built, it is just past an edge, so it renders, it passes every
## rules suite, and the only symptom is a player who cannot reach a button. It
## has now been reported three times -- FX Energy on a narrow desktop window, and
## the skills catalog at 1366x768 -- which is what a suite is for.
##
## Two ways a tab can put content out of reach, and both are checked:
##
##   * Vertically, when the tab is taller than the content area AND the sheet's
##     own scroll is switched off. A tab switches it off by returning true from
##     has_custom_scroll(), promising it scrolls its own panels instead. If it
##     over-promises -- scrolls one panel but stacks three more above it -- the
##     overflow has nowhere to go.
##   * Horizontally, always, because the sheet's scroll is vertical only. A tab
##     whose minimum width exceeds the content area is off the right edge at any
##     height.
##
## Sizes are the ones people actually run: two phones, the 1366x768 laptop that
## is still the commonest PC panel, the 1280x720 desktop default, and 1080p.
## 768 of height is the tight case -- the chrome takes its cut before a tab sees
## anything -- and it is the one that had been missed.
##

const SHELL := preload("res://scenes/ui/app_shell.tscn")
const STORE_DIR := "user://__responsive_suite_store__/"

## Rounding between a container's minimum size and the rect it is given is worth
## a pixel or two; anything past that is a real overflow.
const SLACK := 2.0

## The sizes people actually run this on, not round numbers.
##
## 1366x728 is the one that matters most: a maximised window on the commonest
## laptop panel there is. The screen is 768 tall, Windows keeps about 40px of it
## for the title bar, and the app gets the rest -- so testing 1366x768 hands the
## layout 40px it will never have on that machine, which is most of the margin
## these defects live in. Both are kept: 768 for a borderless or fullscreen
## window, 728 for the ordinary maximised one.
const SIZES := [
	[360, 800, "small phone"],
	[390, 844, "phone"],
	[412, 915, "large phone"],
	[1366, 728, "laptop maximised"],
	[1366, 768, "laptop fullscreen"],
	[1280, 720, "desktop default"],
	[1920, 1080, "full hd"],
]

## Fixtures chosen to unlock different tab sets between them: the mutant brings
## Mutations, the mindwalker Psionics, the FX talent the FX catalog.
const FIXTURES := [
	"synthetic_mutant.json",
	"synthetic_fraal_mindwalker.json",
	"synthetic_fx_talent.json",
	"real_tech_op_marco.json",
	ADEPT_FIXTURE,
]

## Built here rather than committed, because it exists to be the tallest hero we
## can make rather than to pin any rule down.
##
## Modelled on the character the 1366x768 report came from: an Adept (Tech Op),
## whose FX card carries the practitioner-type note, the campaign scale, and the
## primary-school picker that a Talent's card does not have, with powers bought
## in a school so the catalog has depth under it. That card is what pushed the
## FX Energy panel off the bottom of his screen.
const ADEPT_FIXTURE := "synthetic_fx_adept.json"
const PROFESSION_ADEPT_TECH_OP := 12

var _rules: AlternityRules
var _shell
var _sheet


func _init() -> void:
	begin_async("responsive layout", 120000)
	_run.call_deferred()


func _run() -> void:
	_rules = load("res://scripts/alternity_rules.gd").new()
	_rules.load_core_data()
	_seed_store()

	for size_spec in SIZES:
		await _check_size(int(size_spec[0]), int(size_spec[1]), String(size_spec[2]))

	finish()
## The screens either side of the sheet: the list you arrive at, the campaign
## list, the join form and the GM's table. They carry lists that grow with the
## table, and none of them was covered while only the sheet was.
func _check_screens(where: String) -> void:
	_shell = SHELL.instantiate()
	_shell.store_directory = STORE_DIR
	root.add_child(_shell)
	for _i in 12:
		await process_frame
	_assert_reachable_under(_shell, "%s/character select" % where)

	_shell._show_campaigns()
	for _i in 12:
		await process_frame
	_assert_reachable_under(_shell, "%s/campaign select" % where)

	_shell._show_table_join()
	for _i in 12:
		await process_frame
	_assert_reachable_under(_shell, "%s/table join" % where)

	_shell._open_campaign(CampaignSession.new("Fixture Table"))
	for _i in 14:
		await process_frame
	_assert_reachable_under(_shell, "%s/gm screen" % where)

	_teardown()
	await process_frame


## Every route, pushed the way the app pushes it.
##
## A route is not free to be any height it likes: ModalHost clamps it to a
## fraction of the viewport -- 0.7 for a dialog, 0.9 for a page -- and expects it
## to scroll whatever will not fit. One holding a long list that forgot its own
## ScrollContainer is cut off by the frame with no way to reach the rest, and on
## a short window that is most of it.
func _check_routes(where: String) -> void:
	_shell = SHELL.instantiate()
	_shell.store_directory = STORE_DIR
	root.add_child(_shell)
	for _i in 12:
		await process_frame

	var doc = _shell.store.load_doc(ADEPT_FIXTURE)
	if doc == null:
		fail("%s: the routes need the adept fixture and it did not load" % where)
		_teardown()
		return
	_shell._open_sheet(doc)
	for _i in 12:
		await process_frame

	for spec in _route_specs(doc):
		var route_name := String(spec["name"])
		# present_modal rather than push: push() returns only once the route
		# closes, and the point here is to look at the route while it is open.
		var top = _shell.router.present_modal(spec["scene"], spec["props"])
		for _i in 14:
			await process_frame

		if top == null or not is_instance_valid(top):
			fail("%s: route %s did not present" % [where, route_name])
			continue
		_assert_reachable_under(top, "%s/route %s" % [where, route_name])

		_shell.router.dismiss_modal(top)
		for _i in 8:
			await process_frame

	_teardown()
	await process_frame


## What each route needs in order to render something worth measuring.
##
## Filled with real catalogue data wherever a route shows a list: an empty list
## is short enough to fit any window and would prove nothing.
func _route_specs(doc) -> Array:
	var palette = _shell._palette
	var rules = _shell.rules
	var raw: Dictionary = doc.raw()

	var entries: Array = []
	for skill in rules.skills:
		entries.append({
			"id": str(skill.get("id", "")),
			"name": String(skill.get("name", "")),
			"summary": String(skill.get("description", "")).substr(0, 120),
			"meta": "Cost %d" % AlternityNum.as_int(skill.get("cost", 0)),
			"taken": false,
			"disabled": false,
			"reason": "",
		})
		if entries.size() >= 60:
			break

	var check := SkillCheck.call_for("Athletics", 0, "Climbing the hull")
	var first_skill: Dictionary = {}
	var detail: Dictionary = {}
	var skills: Array = rules.skills
	if not skills.is_empty():
		first_skill = skills[0]
		detail = rules.skill_detail(first_skill, raw)

	return [
		{"name": "confirm", "scene": load("res://scenes/ui/routes/confirm_route.tscn"), "props": {
			"palette": palette, "title": "Delete hero?",
			"message": "This cannot be undone, and the character file is removed from this device.",
			"confirm_text": "Delete", "cancel_text": "Keep", "destructive": true}},
		{"name": "text prompt", "scene": load("res://scenes/ui/routes/text_prompt_route.tscn"), "props": {
			"palette": palette, "title": "Rename hero", "message": "What should this hero be called?",
			"placeholder": "Hero name", "text": "Matthieu de Cendres",
			"confirm_text": "Rename", "cancel_text": "Cancel"}},
		{"name": "catalog", "scene": load("res://scenes/ui/routes/catalog_route.tscn"), "props": {
			"palette": palette, "title": "Skills", "entries": entries}},
		{"name": "optional rules", "scene": load("res://scenes/ui/routes/optional_rules_route.tscn"), "props": {
			"palette": palette, "rules": rules, "character": raw, "confirm_text": "Done"}},
		{"name": "theme", "scene": load("res://scenes/ui/routes/theme_route.tscn"), "props": {
			"palette": palette, "service": _shell.get_node_or_null("/root/ThemeService")}},
		{"name": "skill detail", "scene": load("res://scenes/ui/routes/skill_detail_route.tscn"), "props": {
			# "data" only: the route builds its own Detail from it, and handing it
			# a Dictionary as "detail" makes it read .title off a Dictionary.
			"palette": palette, "data": detail, "skill": first_skill,
			"title": String(detail.get("name", "Skill")), "can_roll": true}},
		{"name": "import character", "scene": load("res://scenes/ui/routes/import_character_route.tscn"), "props": {
			"palette": palette, "store": _shell.store}},
		{"name": "ap award", "scene": load("res://scenes/ui/routes/ap_award_route.tscn"), "props": {
			"palette": palette, "mode": "award", "amount": 3, "maximum": 20,
			"title": "Award achievement points", "message": "For getting the party off the station.",
			"reasons": ["Good roleplay", "Solved the problem", "Survived the scene"]}},
		{"name": "skill pick", "scene": load("res://scenes/ui/routes/skill_pick_route.tscn"), "props": {
			"palette": palette, "rules": rules, "title": "Call for a check", "shortcuts": []}},
		{"name": "check step", "scene": load("res://scenes/ui/routes/check_step_route.tscn"), "props": {
			"palette": palette, "rules": rules, "note": "Wet rock, and in the dark.",
			"title": "Athletics", "confirm_text": "Roll", "check": check}},
		{"name": "check waiting", "scene": load("res://scenes/ui/routes/check_waiting_route.tscn"), "props": {
			"palette": palette, "title": "Waiting on the table", "check": check}},
		{"name": "combat attack", "scene": load("res://scenes/ui/routes/combat_attack_route.tscn"), "props": {
			"palette": palette, "rules": rules, "target_id": "p2", "target_name": "Sela Anwar"}},
		{"name": "combat blast", "scene": load("res://scenes/ui/routes/combat_blast_route.tscn"), "props": {
			"palette": palette, "rules": rules, "combatants": []}},
		{"name": "dice tray", "scene": load("res://scenes/ui/routes/dice_tray_route.tscn"), "props": {
			"palette": palette, "rules": rules, "label": "Athletics",
			"allow_reroll": true, "check": check, "terms": []}},
		{"name": "character view", "scene": load("res://scenes/ui/routes/character_view_route.tscn"), "props": {
			"palette": palette, "rules": rules,
			"snapshot": CharacterSnapshot.of_doc(doc), "player": "Rodri"}},
		{"name": "commit character", "scene": load("res://scenes/ui/routes/commit_character_route.tscn"), "props": {
			"palette": palette, "rules": rules, "store": _shell.store,
			"campaign_name": "Fixture Table", "optional_rules": []}},
		{"name": "table settings", "scene": load("res://scenes/ui/routes/table_settings_route.tscn"), "props": {
			"palette": palette, "session": CampaignSession.new("Fixture Table"),
			# connected is the list of players; addresses is one readable string.
			"hosting": true, "connected": [],
			"addresses": "192.168.1.24, 10.0.0.8", "router": _shell.router}},
	]


## Copies the committed fixtures into a scratch store, so the suite never reads
## or writes a real saved character.
##
## Copied as files rather than saved through the store, because save() names the
## file after the hero and these are addressed by their fixture names.
func _seed_store() -> void:
	DirAccess.make_dir_recursive_absolute(STORE_DIR)
	var store = CharacterStore.new(_rules, STORE_DIR)
	for entry in store.list():
		store.delete(String(entry["file_name"]))
	for fixture in FIXTURES:
		if fixture == ADEPT_FIXTURE:
			continue
		var text := FileAccess.get_file_as_string("res://tests/fixtures/characters/%s" % fixture)
		if text.is_empty():
			fail("fixture %s is missing or empty" % fixture)
			continue
		var file := FileAccess.open(STORE_DIR + fixture, FileAccess.WRITE)
		if file == null:
			fail("could not seed %s into the scratch store" % fixture)
			continue
		file.store_string(text)
		file.close()
	_seed_fx_adept()
	store.clear_last_opened()


func _seed_fx_adept() -> void:
	var doc := CharacterDoc.new(_rules)
	doc.set_hero_name("Matthieu de Cendres")
	doc.set_profession_id(PROFESSION_ADEPT_TECH_OP)
	doc.apply(CharacterDoc.ALL, func(c):
		c["abilities"]["WIL"] = 12
		c["abilities"]["CON"] = 11
		c["achievement_level"] = 4
		_rules.set_fx_campaign_scale(c, "superheroic")
		_rules.fx.set_energy_pool(c, 10)
		# Every school the hero may take, with powers under each: the catalog at
		# its tallest, which is the state that overflowed.
		for broad in _rules.fx.get_broad_skills_for_character(c):
			var broad_name := String(broad.get("name", ""))
			_rules.fx.add_fx_skill(c, broad_name)
			for power in _rules.fx.get_specialty_skills_for_broad_and_character(broad_name, c):
				_rules.fx.add_fx_skill(c, String(power.get("name", ""))))
	var text := JSON.stringify(doc.to_dict(), "	")
	var file := FileAccess.open(STORE_DIR + ADEPT_FIXTURE, FileAccess.WRITE)
	if file == null:
		fail("could not seed the FX adept")
		return
	file.store_string(text)
	file.close()


func _check_size(width: int, height: int, label: String) -> void:
	var window := root.get_window()
	window.size = Vector2i(width, height)
	window.content_scale_size = Vector2i(width, height)
	await process_frame
	await process_frame

	var where := "%s %dx%d" % [label, width, height]
	await _check_screens(where)
	for fixture in FIXTURES:
		await _check_character(fixture, where)
	await _check_routes(where)


func _check_character(fixture: String, where: String) -> void:
	_shell = SHELL.instantiate()
	_shell.store_directory = STORE_DIR
	root.add_child(_shell)
	for _i in 10:
		await process_frame

	var file_name := ""
	for entry in _shell.store.list():
		if String(entry["file_name"]) == fixture:
			file_name = fixture
	if file_name.is_empty():
		fail("%s: fixture %s did not reach the store" % [where, fixture])
		_teardown()
		return

	var doc = _shell.store.load_doc(file_name)
	if doc == null:
		fail("%s: could not load %s" % [where, fixture])
		_teardown()
		return

	_shell._open_sheet(doc)
	for _i in 12:
		await process_frame
	_sheet = _shell._screens.get_child(0)

	var hero := "%s/%s" % [where, fixture.trim_suffix(".json")]
	for definition in _sheet._available_tabs():
		var id := String(definition["id"])
		_sheet._select_tab(id)
		for _i in 14:
			await process_frame
		_assert_reachable(id, hero, "")

		# The catalogs are the reported case, and they are a different layout
		# from the selected-list the tab opens on, so they are entered here
		# rather than trusted to be the same shape.
		var tab = _sheet._instances.get(id)
		if tab != null and tab.has_method("_set_editing_skills"):
			tab._set_editing_skills(true)
			for _i in 14:
				await process_frame
			_assert_reachable(id, hero, " (catalog)")
			_assert_names_readable(tab, "%s: %s catalog" % [hero, id])
			tab._set_editing_skills(false)
		elif tab != null and tab.has_method("_set_editing_powers"):
			tab._set_editing_powers(true)
			for _i in 14:
				await process_frame
			_assert_reachable(id, hero, " (catalog)")
			_assert_names_readable(tab, "%s: %s catalog" % [hero, id])
			tab._set_editing_powers(false)

	_teardown()
	await process_frame


## The one assertion this suite exists to make: nothing is drawn where it cannot
## be reached.
##
## Asked of the rendered rectangles rather than of anybody's minimum size,
## because minimum sizes are what the layout *asked* for and this is a question
## about what it *got*. An earlier version of this suite compared the tab's
## combined minimum against the content area and passed clean while the reported
## defect was on screen.
##
## A control is reachable when it is inside the window, or when something
## between it and the root can scroll the axis it is outside on. So the test
## walks up from each control looking for a ScrollContainer that scrolls that
## axis, and only when there is none does being past the edge count.
func _assert_reachable(id: String, hero: String, mode: String) -> void:
	var tab = _sheet._instances.get(id)
	if tab == null or not is_instance_valid(tab):
		fail("%s: tab %s did not instantiate" % [hero, id])
		return
	_assert_reachable_under(tab, "%s: %s%s" % [hero, id, mode])


## A catalog whose entries cannot be told apart is not a catalog.
##
## The companion to the reachability check: that one asks whether content is on
## the screen, this one whether it says anything once it is there. A list where
## most rows read "Call the sk...", "Child of th...", "Kinship of ..." passes
## every other assertion in this file.
##
## Read off the rendered labels rather than from the picker's own stacking
## decision, deliberately. Asking `_stacked` would only confirm the measurement
## agrees with itself; measuring what was actually drawn fails if the decision,
## the threshold or the row layout is wrong, whichever of them broke.
##
## Name labels are the ones set in FONT_BODY. The lines under them -- the cost
## and the check scores -- are FONT_CAPTION and are meant to trim on a narrow
## phone, so they are not counted.
const NAME_TRUNCATION_LIMIT := 0.5


func _assert_names_readable(tab: Node, what: String) -> void:
	var names: Array = []
	_collect_name_labels(tab, names)
	if names.size() < 4:
		# Too few rows on screen to say anything about the list as a whole.
		return

	var truncated := 0
	for entry in names:
		var label: Label = entry
		var font: Font = label.get_theme_font("font")
		if font == null:
			continue
		var needed := font.get_string_size(
			label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, Widgets.FONT_BODY
		).x
		if needed > label.size.x + 1.0:
			truncated += 1

	var fraction := float(truncated) / float(names.size())
	check(
		fraction <= NAME_TRUNCATION_LIMIT,
		"%s: %d of %d visible entry names are cut off (%.0f%%) -- at that rate the rows stop naming anything, and the row should have given the name a line of its own"
			% [what, truncated, names.size(), fraction * 100.0]
	)


func _collect_name_labels(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Label:
			var label := child as Label
			if (
				label.is_visible_in_tree()
				and not label.text.strip_edges().is_empty()
				and label.size.x > 0.0
				and label.get_theme_font_size("font_size") == Widgets.FONT_BODY
				and label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS
			):
				out.append(label)
		_collect_name_labels(child, out)


## The same question asked of any subtree: a screen, a pushed route, or one tab.
func _assert_reachable_under(subject: Node, what: String) -> void:
	if subject == null or not is_instance_valid(subject):
		fail("%s: nothing to measure" % what)
		return

	var window_rect := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var worst_below: Dictionary = {}
	var worst_right: Dictionary = {}
	# Seeded from above the tab, because the scroll that saves a phone is the
	# sheet's own and it is the tab's ancestor, not its descendant.
	var inherited := _scrollable_above(subject)
	_collect_unreachable(
		subject, window_rect, worst_below, worst_right,
		bool(inherited["vertical"]), bool(inherited["horizontal"])
	)

	check(
		worst_below.is_empty(),
		"%s has content below the bottom of the window with nothing able to scroll to it -- %s is %.0fpx past the edge (window %.0fpx tall)"
			% [
				what, String(worst_below.get("what", "")),
				float(worst_below.get("over", 0.0)), window_rect.size.y,
			]
	)
	check(
		worst_right.is_empty(),
		"%s has content past the right edge with nothing able to scroll to it -- %s is %.0fpx past (window %.0fpx wide)"
			% [
				what, String(worst_right.get("what", "")),
				float(worst_right.get("over", 0.0)), window_rect.size.x,
			]
	)


## Depth-first over the visible controls, recording the furthest one that has
## drifted outside the window on an axis nothing can scroll.
func _collect_unreachable(
	node: Node, window_rect: Rect2, worst_below: Dictionary, worst_right: Dictionary,
	v_scrollable: bool = false, h_scrollable: bool = false
) -> void:
	if node is ScrollContainer:
		var sc := node as ScrollContainer
		v_scrollable = v_scrollable or sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
		h_scrollable = h_scrollable or sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED

	if node is Control and node != _sheet:
		var control := node as Control
		# An empty rect is a spacer or a control that has not been laid out; it
		# has nothing to read and no user can miss it.
		if control.is_visible_in_tree() and control.size.x > 0.0 and control.size.y > 0.0:
			var rect := control.get_global_rect()
			# Only things a player could actually be looking for. A container is
			# often stretched past its own content by a size flag, and empty space
			# below the fold is not lost content -- what matters is whether a
			# control that draws or takes input ended up down there.
			var is_content := _draws_or_takes_input(control)
			if not v_scrollable:
				var over_y := rect.end.y - window_rect.end.y
				if is_content and over_y > SLACK and over_y > float(worst_below.get("over", 0.0)):
					worst_below["over"] = over_y
					worst_below["what"] = _describe(control)
			if not h_scrollable:
				var over_x := rect.end.x - window_rect.end.x
				if is_content and over_x > SLACK and over_x > float(worst_right.get("over", 0.0)):
					worst_right["over"] = over_x
					worst_right["what"] = _describe(control)

	for child in node.get_children():
		_collect_unreachable(child, window_rect, worst_below, worst_right, v_scrollable, h_scrollable)


## Whether this control is something a player reads, touches, or sees the edge
## of -- as opposed to a plain box that merely holds them.
##
## Cards and scroll viewports count. A section card whose bottom runs off the
## screen is the reported symptom: the catalog inside it still scrolls, so every
## row is technically reachable, but the card has been squeezed to a sliver with
## no bottom border and the panel below it is nowhere. Judging only the leaves
## called that healthy.
func _draws_or_takes_input(control: Control) -> bool:
	return (
		control is Button
		or control is Label
		or control is RichTextLabel
		or control is LineEdit
		or control is TextEdit
		or control is Range
		or control is TextureRect
		or control is Separator
		or control is PanelContainer
		or control is ScrollContainer
	)


## Which axes something between this node and the root can already scroll.
func _scrollable_above(node: Node) -> Dictionary:
	var vertical := false
	var horizontal := false
	var walker := node.get_parent()
	while walker != null:
		if walker is ScrollContainer:
			var sc := walker as ScrollContainer
			vertical = vertical or sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
			horizontal = horizontal or sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
		walker = walker.get_parent()
	return {"vertical": vertical, "horizontal": horizontal}


## Enough to find the thing on screen: what it is and, where it has one, what it
## says.
func _describe(control: Control) -> String:
	var text := ""
	if control is Button:
		text = (control as Button).text
	elif control is Label:
		text = (control as Label).text
	elif control is LineEdit:
		text = (control as LineEdit).placeholder_text
	text = text.strip_edges().replace("
", " ")
	if text.length() > 40:
		text = text.substr(0, 37) + "..."
	var trail := PackedStringArray()
	var walker: Node = control
	while walker != null and walker is Control and trail.size() < 5:
		trail.insert(0, walker.get_class())
		walker = walker.get_parent()
	var path := " > ".join(trail)
	if text.is_empty():
		return path
	return "%s \"%s\"" % [path, text]


func _teardown() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.queue_free()
	_shell = null
	_sheet = null
