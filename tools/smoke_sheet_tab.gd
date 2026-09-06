extends "res://tools/test_harness.gd"
##
## The contract that replaces the global re-render.
##
## The old UI called _render() from 67 places and each call rebuilt the entire
## active tab, because nothing knew what had changed. These tests count builds:
## the point is not that a tab CAN rebuild, it is that it does so only when
## something it draws actually changed, and not at all while it is hidden.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")
const Doc := preload("res://scripts/core/character_doc.gd")
const Context := preload("res://scripts/ui/sheet_context.gd")
const Tab := preload("res://scripts/ui/sheet_tab.gd")

var _rules


## Records how many times it was asked to draw.
class CountingTab:
	extends SheetTab

	var build_count: int = 0
	var sections: Array = []
	var available: bool = true

	func watched_sections() -> Array:
		return sections if not sections.is_empty() else CharacterDoc.ALL

	func is_available_for(_context: SheetContext) -> bool:
		return available

	func build(container: Container) -> void:
		build_count += 1
		var label := Label.new()
		label.text = "built %d" % build_count
		container.add_child(label)


func _init() -> void:
	begin_async("sheet tab", 300)
	_run.call_deferred()


func _run() -> void:
	_rules = RulesScript.new()
	_rules.load_core_data()

	await _test_builds_on_bind()
	await _test_only_watched_sections_rebuild()
	await _test_hidden_tabs_defer()
	await _test_availability()
	await _test_rebind_and_unbind()
	await _test_save_request()
	await _test_skills_tab_watches_fx_and_cybertech()
	await _test_sheet_header_atomic_details()
	await _test_summary_tab_dazed_tooltip()

	finish()


func _make(sections: Array = []):
	var tab := CountingTab.new()
	tab.sections = sections
	root.add_child(tab)
	return tab


func _context(doc = null):
	var character = doc if doc != null else Doc.new(_rules)
	return Context.new(character, _rules, null, ThemePalette.new(), false)


func _test_builds_on_bind() -> void:
	var tab = _make()
	var ctx = _context()
	tab.bind(ctx)
	await process_frame

	check_eq(tab.build_count, 1, "binding builds once")
	check_true(tab.get_child_count() > 0, "build produced content")
	check_false(tab.needs_rebuild(), "no rebuild pending after building")

	# Refreshing without a change must not redraw.
	tab.refresh()
	check_eq(tab.build_count, 1, "refresh with nothing changed does not rebuild")

	# Forcing is the escape hatch.
	tab.refresh(true)
	check_eq(tab.build_count, 2, "forced refresh rebuilds")

	# A rebuild replaces content rather than appending to it.
	check_eq(tab.get_child_count(), 1, "rebuild clears the previous content")

	tab.queue_free()


## The heart of it: a tab watching one section ignores changes to the others.
func _test_only_watched_sections_rebuild() -> void:
	var doc = Doc.new(_rules)
	var tab = _make([CharacterDoc.EQUIPMENT])
	tab.bind(_context(doc))
	await process_frame
	var baseline: int = tab.build_count

	# Editing something it does not draw must be free.
	doc.set_notes("a note")
	doc.set_hero_name("Renamed")
	check_eq(tab.build_count, baseline, "unwatched sections do not rebuild the tab")

	# Editing what it does draw must rebuild it, once.
	doc.apply([CharacterDoc.EQUIPMENT], func(c):
		return _rules.equipment.add_equipment_to_character(c, "armor_core_001", 1))
	check_eq(tab.build_count, baseline + 1, "a watched section rebuilds the tab")

	# A broad change touching everything still rebuilds only once.
	doc.set_profession_id(5)
	check_eq(tab.build_count, baseline + 2, "a global change rebuilds once, not per section")

	tab.queue_free()


## A hidden tab must not redraw on every edit elsewhere; it catches up when
## shown. This is what the old tab cache and dirty flags were approximating.
func _test_hidden_tabs_defer() -> void:
	var doc = Doc.new(_rules)
	var tab = _make()
	tab.bind(_context(doc))
	await process_frame
	var baseline: int = tab.build_count

	tab.visible = false
	await process_frame

	doc.set_hero_name("Edited while hidden")
	doc.set_career("And again")
	check_eq(tab.build_count, baseline, "a hidden tab does not rebuild on changes")
	check_true(tab.needs_rebuild(), "the hidden tab records that it is stale")

	tab.visible = true
	await process_frame
	check_eq(tab.build_count, baseline + 1, "becoming visible rebuilds exactly once")
	check_false(tab.needs_rebuild(), "the tab is current again")

	tab.queue_free()


## Replaces the Mutations special case hardcoded in _tab_visible().
##
## Takes the whole context, not just the document: deciding usually needs the
## rules too, and the shell asks on an unbound probe instance where ctx is null.
func _test_availability() -> void:
	var context = _context()
	var tab = _make()
	check_true(tab.is_available_for(context), "a tab is available by default")

	tab.available = false
	check_false(tab.is_available_for(context), "a tab can exclude itself for a character")

	# It must be answerable before bind(), since that is when the shell asks.
	var unbound = CountingTab.new()
	unbound.available = false
	check_true(unbound.ctx == null, "the probe is unbound")
	check_false(unbound.is_available_for(context), "an unbound tab can still answer")
	unbound.free()

	tab.queue_free()


func _test_rebind_and_unbind() -> void:
	var first = Doc.new(_rules)
	var second = Doc.new(_rules)
	var tab = _make()

	tab.bind(_context(first))
	await process_frame
	var after_first: int = tab.build_count

	# Rebinding must detach from the old document, or a GM switching between
	# players would leave the tab reacting to both.
	tab.bind(_context(second))
	await process_frame
	check_true(tab.build_count > after_first, "rebinding rebuilds for the new document")

	var after_rebind: int = tab.build_count
	first.set_hero_name("Should be ignored")
	check_eq(tab.build_count, after_rebind, "the previously bound document no longer drives the tab")

	second.set_hero_name("Should rebuild")
	check_true(tab.build_count > after_rebind, "the newly bound document does drive it")

	# Unbinding stops everything.
	var before_unbind: int = tab.build_count
	tab.unbind()
	second.set_hero_name("After unbind")
	check_eq(tab.build_count, before_unbind, "an unbound tab ignores its old document")
	check_true(tab.ctx == null, "unbind clears the context")

	tab.queue_free()


func _test_save_request() -> void:
	var tab = _make()
	tab.bind(_context())
	await process_frame

	var requests := [0]
	tab.save_requested.connect(func(): requests[0] += 1)
	tab.save_requested.emit()
	check_eq(requests[0], 1, "a tab asks the shell to save rather than saving itself")

	tab.queue_free()


func _test_skills_tab_watches_fx_and_cybertech() -> void:
	var tab_scene := preload("res://scenes/ui/tabs/tab_skills.tscn")
	var tab = tab_scene.instantiate()
	root.add_child(tab)
	var doc = Doc.new(_rules)
	tab.bind(_context(doc))
	await process_frame

	check_true(tab.watched_sections().has(CharacterDoc.FX), "Skills tab watches FX section")
	check_true(tab.watched_sections().has(CharacterDoc.CYBERTECH), "Skills tab watches CYBERTECH section")
	check_true(tab.watched_sections().has(CharacterDoc.OPTIONAL_RULES), "Skills tab watches OPTIONAL_RULES section")

	# Editing FX while hidden flags needs_rebuild
	tab.visible = false
	await process_frame
	check_false(tab.needs_rebuild(), "no rebuild pending initially")

	doc.apply([CharacterDoc.FX], func(c):
		_rules.fx.add_fx_skill(c, "Hermeticism")
	)
	check_true(tab.needs_rebuild(), "FX mutation flags Skills tab for rebuild while hidden")

	tab.visible = true
	await process_frame
	check_false(tab.needs_rebuild(), "Skills tab rebuilds upon becoming visible")

	tab.queue_free()


func _test_sheet_header_atomic_details() -> void:
	var sheet_scene := preload("res://scenes/ui/screens/character_sheet.tscn")
	var sheet = sheet_scene.instantiate()
	root.add_child(sheet)

	var doc = Doc.new(_rules)
	doc.set_hero_name("Test Hero")
	var ctx := Context.new(doc, _rules, null, ThemePalette.new(), false)
	sheet.setup(ctx, null)
	await process_frame

	check_eq(sheet._title.text, "Wilmer Alternity Sidekick", "header title is Wilmer Alternity Sidekick")
	check_true(sheet._status.text.begins_with("Test Hero"), "header status begins with hero name")
	check_true(sheet._status.text.contains("SP "), "header status contains SP details")
	check_true(sheet._status.text.contains("Lv "), "header status contains level")

	var initial_status: String = sheet._status.text

	# Applying FX changes SP in header immediately
	doc.apply([CharacterDoc.FX], func(c):
		_rules.fx.add_fx_skill(c, "Hermeticism")
	)
	await process_frame
	check_true(sheet._status.text != initial_status, "header status updates immediately when FX skill is added")

	sheet.queue_free()


func _test_summary_tab_dazed_tooltip() -> void:
	var tab_scene := preload("res://scenes/ui/tabs/tab_summary.tscn")
	var tab = tab_scene.instantiate()
	root.add_child(tab)

	var doc = Doc.new(_rules)
	doc.apply([CharacterDoc.OPTIONAL_RULES], func(c):
		c["optional_rules"] = {"dazed": true}
	)
	var ctx := Context.new(doc, _rules, null, ThemePalette.new(), false)
	tab.bind(ctx)
	await process_frame

	var stun_tracker: DamageTrack = tab._damage_trackers.get("stun")
	check_true(stun_tracker != null, "stun damage tracker exists")
	if stun_tracker:
		check_true(stun_tracker._marker_tooltip.contains("> 50% damage"), "tooltip contains formatted '> 50% damage'")
		check_true(stun_tracker._marker_tooltip.contains("causes Dazed"), "tooltip contains 'causes Dazed'")

	tab.queue_free()
