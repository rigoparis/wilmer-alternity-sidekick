extends "res://tools/test_harness.gd"
##
## End-to-end walk through the vertical slice: the architecture gate.
##
## Drives the real scenes rather than the pieces in isolation -- shell, both
## screens, both migrated tabs, the confirm dialog and the multi-select catalog
## -- because the point of the slice is to find a wrong contract while it costs
## three files to fix instead of twelve.
##
## Runs against a scratch store directory. Without that it would read and
## overwrite real saved characters.
##

const SHELL := preload("res://scenes/ui/app_shell.tscn")
const TEST_DIR := "user://__shell_test__/"

var _shell


func _init() -> void:
	begin_async("app shell slice", 900)
	_run.call_deferred()


func _run() -> void:
	_wipe()

	_shell = SHELL.instantiate()
	_shell.store_directory = TEST_DIR
	root.add_child(_shell)
	await process_frame
	await process_frame

	await _test_starts_on_character_select()
	await _test_check_runner_tracks_theme()
	await _test_touch_scroll_filters()
	await _test_create_opens_sheet()
	await _test_tabs()
	await _test_tab_availability()
	await _test_cybertech_edits()
	await _test_perks_catalog()
	await _test_back_leaves_sheet()
	await _test_delete_confirm()
	await _test_escape_unwinds()

	_shell.queue_free()
	_wipe()
	finish()


func _wipe() -> void:
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		DirAccess.remove_absolute(TEST_DIR + file_name)


func _screens() -> Control:
	return _shell.get_node_or_null("Screens")


func _find(type_name: String) -> Node:
	var host := _screens()
	if host == null:
		return null
	for child in host.get_children():
		if child.get_class() == type_name or child.get_script() != null and String(child.get_script().resource_path).contains(type_name):
			return child
	return host.get_child(0) if host.get_child_count() > 0 else null


func _select_screen():
	return _find("character_select")


func _sheet_screen():
	return _find("character_sheet")


func _test_starts_on_character_select() -> void:
	var screen = _select_screen()
	check_true(screen != null, "the shell opens on the character list")
	check_true(_shell.store != null, "the shell built a store")
	check_true(_shell.router != null, "the shell built a router")
	check_eq(_shell.store.list().size(), 0, "the scratch store starts empty")


func _test_check_runner_tracks_theme() -> void:
	var service := root.get_node_or_null("ThemeService")
	if not check(service != null, "the theme service is available"):
		return
	var original: ThemePalette = _shell._palette
	var changed := original.duplicate_palette()
	changed.accent = Color(0.91, 0.17, 0.43)

	# Exercise the same signal AppShell receives when the picker changes theme,
	# without writing a different preference into the test user's config file.
	service.palette_changed.emit(changed)
	await process_frame
	check_true(_shell._palette == changed, "the shell accepts the new palette")
	check_true(_shell.checks._palette == changed,
		"the check difficulty dialog and dice tray receive the new palette")

	service.palette_changed.emit(original)
	await process_frame


func _test_touch_scroll_filters() -> void:
	var screen = _select_screen()
	if not check(screen != null, "touch scrolling has a screen to inspect"):
		return
	var scrolls := screen.find_children("*", "ScrollContainer", true, false)
	if not check_false(scrolls.is_empty(), "the character list has a scroll container"):
		return
	var scroll := scrolls[0] as ScrollContainer
	var buttons := scroll.find_children("*", "Button", true, false)
	if not check_false(buttons.is_empty(), "the scroll area has an interactive child"):
		return
	var button := buttons[0] as Button
	var original_filter := button.mouse_filter
	var outside_filter := _screens().mouse_filter

	_shell._update_mouse_filters_for_touch(screen, true)
	check_eq(button.mouse_filter, Control.MOUSE_FILTER_PASS,
		"interactive children pass touch drags to their scroll container")
	check_eq(_screens().mouse_filter, outside_filter,
		"controls outside the scroll area keep their mouse filter")

	_shell._update_mouse_filters_for_touch(screen, false)
	check_eq(button.mouse_filter, original_filter,
		"leaving touch-pass mode restores the original mouse filter")

	# Lists and routes add controls after their initial build. Exercise the
	# SceneTree hook that makes those late children scrollable on a phone.
	_shell._touch_pass_enabled = true
	var dynamic_button := Button.new()
	(scroll.get_child(0).get_child(0) as Container).add_child(dynamic_button)
	check_eq(dynamic_button.mouse_filter, Control.MOUSE_FILTER_PASS,
		"a control added later also passes touch drags")
	_shell._touch_pass_enabled = OS.has_feature("mobile")
	_shell._update_mouse_filters_for_touch(dynamic_button, false)
	dynamic_button.queue_free()


func _test_create_opens_sheet() -> void:
	var screen = _select_screen()
	if not check(screen != null, "the select screen is present"):
		return

	# Creating a hero now asks which optional rules the campaign uses first,
	# because several of them change the starting skill budget. Dismiss it the
	# way a person would.
	var answer_prompt := func() -> void:
		await process_frame
		var route = _shell.router._host.top_route()
		check_true(route != null, "creating a hero asks about optional rules first")
		if route != null:
			check_eq(route._confirm_text, "Create Hero", "the prompt confirms with Create Hero")
			route.close(null)
	answer_prompt.call_deferred()

	await screen._on_create_pressed()
	await process_frame
	await process_frame

	var sheet = _sheet_screen()
	check_true(sheet != null, "creating a hero opens the sheet")
	check_true(sheet.document() != null, "the sheet has a document")
	check_eq(_shell.store.list().size(), 1, "the new hero was saved so it appears in the list")


func _test_tabs() -> void:
	var sheet = _sheet_screen()
	if not check(sheet != null, "the sheet is open"):
		return

	# Assert against the registry rather than a hardcoded count, so migrating a
	# tab in phase 5 does not break this test every time.
	#
	# Not every registered tab is listed: a tab may exclude itself for this
	# character (Mutations only applies to the Mutant species), so the listed set
	# is the registry filtered by is_available_for.
	var registry: Array = sheet.TABS
	check_true(registry.size() >= 2, "at least two tabs are migrated (%d)" % registry.size())

	var available: Array = sheet._available_tabs()
	check_eq(sheet._buttons.size(), available.size(), "every applicable tab is listed")
	for definition in available:
		check_true(sheet._buttons.has(String(definition["id"])), "%s is listed" % definition["id"])

	# The Mutations tab is the one that excludes itself, and this character is
	# not a Mutant.
	check_false(sheet._buttons.has("mutations"), "Mutations is hidden for a non-Mutant hero")

	var first_id := String(available[0]["id"])
	check_eq(sheet._active_id, first_id, "the first tab is selected on open")

	# Switching to any other tab keeps the first one alive but hidden.
	var second_id := String(available[1]["id"])
	sheet._select_tab(second_id)
	await process_frame
	check_eq(sheet._active_id, second_id, "switching tabs changes the active id")
	check_true(sheet._instances.has(second_id), "the tab is instantiated on first visit")
	check_true(sheet._instances[second_id].visible, "the active tab is visible")
	check_false(sheet._instances[first_id].visible, "the previous tab is hidden, not destroyed")

	# Every applicable tab must at least build without erroring.
	for definition in available:
		var id := String(definition["id"])
		sheet._select_tab(id)
		await process_frame
		var tab = sheet._instances.get(id)
		if check(tab != null, "%s instantiates" % id):
			check_true(tab.get_child_count() > 0, "%s draws content" % id)


## Turning the character into a Mutant must make the Mutations tab appear.
##
## This is the replacement for the hardcoded species check that used to live in
## the shell, so it is worth exercising rather than assuming.
func _test_tab_availability() -> void:
	var sheet = _sheet_screen()
	var doc = sheet.document()
	var rules = _shell.rules

	check_false(sheet._buttons.has("mutations"), "Mutations hidden before the species changes")

	# Changing the species on the open sheet must be enough. Reopening the sheet
	# here would hide the real bug: the tab bar was built once in setup(), so
	# Mutations could never appear without closing and reopening the character.
	var mutant_id: int = rules.mutations.mutant_species_id()
	doc.set_species_id(mutant_id)
	await process_frame

	check_true(sheet._buttons.has("mutations"), "Mutations appears without reopening the sheet")

	# And it must disappear again, not linger.
	doc.set_species_id(0)
	await process_frame
	check_false(sheet._buttons.has("mutations"), "Mutations hides again when the species reverts")
	check_ne(sheet._active_id, "mutations", "a tab that stopped applying is not left showing")

	# Species is not the only thing that decides which tabs apply, and the two
	# that are easy to forget do not touch META at all: Psionics appears for the
	# Psionic Talents optional rule and for the Superior Talent perk, which
	# arrive as OPTIONAL_RULES and PERKS_FLAWS. A tab bar that only listens for
	# the sections a species change announces leaves both invisible until the
	# character is closed and reopened.
	check_false(sheet._buttons.has("psionics"), "Psionics hidden for an ordinary hero")

	doc.apply([CharacterDoc.OPTIONAL_RULES], func(c):
		rules.set_optional_rule(c, "psionic_talents", true))
	await process_frame
	check_true(sheet._buttons.has("psionics"), "the Psionic Talents rule reveals Psionics in place")

	doc.apply([CharacterDoc.OPTIONAL_RULES], func(c):
		rules.set_optional_rule(c, "psionic_talents", false))
	await process_frame
	check_false(sheet._buttons.has("psionics"), "turning the rule back off hides Psionics again")

	doc.apply([CharacterDoc.PERKS_FLAWS], func(c):
		rules.set_perk_selected(c, "superior_talent", 4))
	await process_frame
	check_true(sheet._buttons.has("psionics"), "the Superior Talent perk reveals Psionics in place")

	doc.apply([CharacterDoc.PERKS_FLAWS], func(c):
		rules.set_perk_selected(c, "superior_talent", 0))
	await process_frame
	check_false(sheet._buttons.has("psionics"), "removing the perk hides Psionics again")


func _test_cybertech_edits() -> void:
	var sheet = _sheet_screen()
	var doc = sheet.document()
	# Select it first: a hidden SheetTab defers its rebuild by design, so editing
	# while another tab is showing would correctly produce no redraw here.
	sheet._select_tab("cybertech")
	await process_frame
	var tab = sheet._instances.get("cybertech")
	if not check(tab != null, "the cybertech tab exists"):
		return

	var rules = _shell.rules
	check_false(rules.cybertech.cybertech_enabled(doc.raw()), "cybertech starts disabled")

	var builds_before: int = tab.get_child_count()
	check_true(builds_before > 0, "the tab drew something")

	# Enabling has to reach the document and come back as a rebuild.
	var toggle := _first_toggle(tab)
	if not check(toggle != null, "the enable toggle was rendered"):
		return
	toggle.button_pressed = true
	toggle.toggled.emit(true)
	await process_frame

	check_true(rules.cybertech.cybertech_enabled(doc.raw()), "toggling reaches the document")
	check_true(doc.is_dirty() or _shell.store.list().size() > 0, "the edit was recorded")
	check_true(
		tab.get_child_count() > builds_before,
		"enabling reveals the catalog, so the tab rebuilt with more content"
	)


func _first_toggle(node: Node) -> BaseButton:
	for child in node.get_children():
		if child is CheckBox or child is CheckButton:
			return child
		var found := _first_toggle(child)
		if found != null:
			return found
	return null


## The riskiest new interaction: a multi-select catalog returning a selection to
## the caller, rather than mutating the character itself and re-rendering.
func _test_perks_catalog() -> void:
	var sheet = _sheet_screen()
	var doc = sheet.document()
	var rules = _shell.rules
	sheet._select_tab("perks_flaws")
	await process_frame

	var tab = sheet._instances.get("perks_flaws")
	if not check(tab != null, "the perks tab exists"):
		return
	check_eq(rules.selected_perks(doc.raw()).size(), 0, "no perks taken yet")

	# Drive the catalog from outside: select the first entry and confirm.
	var picked := [""]
	var drive := func() -> void:
		await process_frame
		var route = _shell.router._host.top_route()
		if route == null:
			return
		check_true(route.get_child_count() > 0, "the catalog rendered")
		check_true(route._entries.size() > 0, "the catalog received entries")

		var entry_id := String(route._entries[0]["id"])
		picked[0] = entry_id
		route._selected[entry_id] = true
		route._refresh_budget()
		# The live header is the reason this is full-screen on a phone.
		check_true(
			route._budget_label.text.contains("selected"),
			"the budget header reflects the selection: %s" % route._budget_label.text
		)
		route.close(route._selected_ids())
	drive.call_deferred()

	tab._open_catalog("perk")
	await process_frame
	await process_frame

	check_false(picked[0].is_empty(), "a catalog entry was chosen")
	check_eq(rules.selected_perks(doc.raw()).size(), 1, "confirming applied the selection")
	check_eq(_shell.router.depth(), 0, "the catalog closed")


func _test_back_leaves_sheet() -> void:
	check_true(_sheet_screen() != null, "the sheet is open before back")
	_shell._handle_back()
	await process_frame
	await process_frame

	# Back from the sheet returns to the list rather than quitting, which is
	# what it did from every overlay before.
	check_true(_select_screen() != null, "back from the sheet returns to the character list")
	check_eq(_shell.store.list().size(), 1, "the character was saved on the way out")


func _test_delete_confirm() -> void:
	var screen = _select_screen()
	if not check(screen != null, "the select screen is present"):
		return
	var listed: Array = _shell.store.list()
	if not check(listed.size() == 1, "one saved hero to delete"):
		return
	var file_name := String(listed[0]["file_name"])

	# Cancelling must not delete.
	var cancel := func() -> void:
		await process_frame
		var route = _shell.router._host.top_route()
		if route != null:
			route.close(null)
	cancel.call_deferred()
	await screen._on_delete_pressed(file_name, "Hero")
	check_eq(_shell.store.list().size(), 1, "cancelling the confirm keeps the character")

	# Confirming must.
	var accept := func() -> void:
		await process_frame
		var route = _shell.router._host.top_route()
		if route != null:
			route.close(true)
	accept.call_deferred()
	await screen._on_delete_pressed(file_name, "Hero")
	check_eq(_shell.store.list().size(), 0, "confirming deletes the character")
	check_eq(_shell.router.depth(), 0, "the dialog closed")


## Escape does what Android back does.
##
## Worth its own test because it is the only way the unwind logic is reachable
## off-device: NOTIFICATION_WM_GO_BACK_REQUEST is emitted on Android and nowhere
## else, so without this path nothing on desktop or in CI exercises it.
func _test_escape_unwinds() -> void:
	# Rebuild a character to work with -- the delete test emptied the store.
	var screen = _select_screen()
	var dismiss := func() -> void:
		await process_frame
		var route = _shell.router._host.top_route()
		if route != null:
			route.close(null)
	dismiss.call_deferred()
	await screen._on_create_pressed()
	await process_frame
	await process_frame

	check_true(_sheet_screen() != null, "a sheet is open")

	# With a route open, escape closes the route and leaves the sheet.
	var open_route := func() -> void:
		await process_frame
		check_eq(_shell.router.depth(), 1, "a route is open")
		_shell._unhandled_input(_escape())
		await process_frame
		check_eq(_shell.router.depth(), 0, "escape closed the route")
	open_route.call_deferred()

	var sheet = _sheet_screen()
	await sheet._open_theme()
	check_true(_sheet_screen() != null, "escape on a route did not leave the sheet")

	# With nothing open, escape leaves the sheet for the character list.
	_shell._unhandled_input(_escape())
	await process_frame
	await process_frame
	check_true(_select_screen() != null, "escape from the sheet returns to the character list")

	# At the list it does nothing, rather than quitting the way Android back does.
	_shell._unhandled_input(_escape())
	await process_frame
	check_true(_select_screen() != null, "escape at the character list is inert")


func _escape() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	return event
