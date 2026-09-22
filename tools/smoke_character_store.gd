extends "res://tools/test_harness.gd"
##
## Persistence round-trips, using an isolated scratch directory.
##
## The store defaults to user://, which holds real saved characters -- these
## tests would overwrite them. That is why CharacterStore takes its directory as
## a constructor argument.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")
const Support := preload("res://tools/golden_support.gd")
const Doc := preload("res://scripts/core/character_doc.gd")
const Store := preload("res://scripts/core/character_store.gd")

const TEST_DIR := "user://__store_test__/"

var _rules


func _init() -> void:
	begin("character store")

	_rules = RulesScript.new()
	_rules.load_core_data()

	_wipe()
	_test_save_and_load()
	_test_rename_removes_old_file()
	_test_listing()
	_test_delete()
	_test_last_opened()
	_test_import_export()
	_test_safe_filenames()
	_test_real_fixtures_round_trip()
	_test_save_location_and_adoption()
	_wipe()

	finish()


## Where saves live, and that moving that location carries heroes across.
##
## Android deletes user:// on uninstall, and every release up to v0.1.8 forced
## an uninstall by signing with a new key, so players lost everything. Saves
## move to shared storage there. Two things have to hold or that change trades
## one kind of loss for another: an unwritable target must fall back rather than
## leave the app unable to save, and relocating must bring existing characters
## with it.
func _test_save_location_and_adoption() -> void:
	# This suite runs on desktop, where user:// already outlives uninstall and
	# is a perfectly reachable folder, so the location must not move.
	check_eq(
		Store.default_directory(), Store.SAVE_DIR,
		"a desktop build keeps saving to user://"
	)

	# The Android branch, driven directly, because a desktop run never reaches
	# it through default_directory() and it is the whole point of the change.
	var docs := "user://__store_docs_test__"
	check_eq(
		Store.resolve_directory("Android", docs),
		docs.path_join(Store.SHARED_FOLDER) + "/",
		"Android saves into a named folder under Documents, which outlives uninstall"
	)
	check_eq(
		Store.resolve_directory("Android", ""),
		Store.SAVE_DIR,
		"Android with no Documents folder falls back to user:// rather than nowhere"
	)
	check_eq(
		Store.resolve_directory("Android", "/this/path/cannot/be/created"),
		Store.SAVE_DIR,
		"Android falls back to user:// when the shared folder refuses writes (permission denied)"
	)
	check_eq(
		Store.resolve_directory("Windows", docs),
		Store.SAVE_DIR,
		"and no other platform is relocated"
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(docs.path_join(Store.SHARED_FOLDER)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(docs))

	var scratch := "user://__store_move_test__/"
	check_true(Store.is_writable(scratch), "a directory it can create is writable")
	# The engine logs "Could not create directory" here. That is the refusal
	# being provoked, not a fault in the suite.
	check_false(
		Store.is_writable("/this/path/cannot/be/created/"),
		"a directory it cannot write reports unwritable rather than throwing"
	)

	# A hero saved in the old location, then the location moves.
	var legacy_name := ""
	var doc := Doc.new(_rules)
	doc.set_hero_name("Adopted Hero")
	var legacy_store = Store.new(_rules, Store.SAVE_DIR)
	var result: Dictionary = legacy_store.save(doc)
	if check_true(bool(result.get("ok", false)), "the hero saves in the old location"):
		legacy_name = String(result.get("file_name", ""))

	var moved_store = Store.new(_rules, scratch)
	var adopted: int = moved_store.adopt_legacy_saves()
	check_true(adopted >= 1, "relocating adopts the heroes already saved")
	check_true(
		FileAccess.file_exists(scratch + legacy_name),
		"and the adopted hero is readable in the new location"
	)
	check_true(
		FileAccess.file_exists(Store.SAVE_DIR + legacy_name),
		"while the original is left where it was, not moved"
	)

	# Running twice must not duplicate or clobber.
	var again: int = moved_store.adopt_legacy_saves()
	check_eq(again, 0, "a second startup adopts nothing, having nothing new to take")

	# A store pointed at a scratch directory must never adopt: tests and the
	# table-session sandbox would otherwise swallow the real save folder.
	var isolated = Store.new(_rules, TEST_DIR)
	check_eq(isolated.directory(), TEST_DIR, "an injected directory is used verbatim")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch + legacy_name))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.SAVE_DIR + legacy_name))


func _new_store():
	return Store.new(_rules, TEST_DIR)


func _wipe() -> void:
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		DirAccess.remove_absolute(TEST_DIR + file_name)


func _test_save_and_load() -> void:
	var store = _new_store()
	var doc = Doc.new(_rules)
	doc.set_hero_name("Vance Kellar")
	doc.set_career("Pilot")

	var result: Dictionary = store.save(doc)
	check_true(bool(result.get("ok", false)), "save reports success")
	check_eq(result.get("file_name", ""), "Vance_Kellar.json", "file name derives from the hero name")
	check_true(store.exists("Vance_Kellar.json"), "saved file exists")
	check_false(doc.is_dirty(), "saving marks the document clean")
	check_eq(doc.source_file, "Vance_Kellar.json", "document records where it was saved")

	var loaded = store.load_doc("Vance_Kellar.json")
	if check(loaded != null, "saved character loads back"):
		check_eq(loaded.get_hero_name(), "Vance Kellar", "hero name survives the round trip")
		check_eq(loaded.get_career(), "Pilot", "career survives the round trip")
		check_false(loaded.is_dirty(), "a freshly loaded document is clean")

	check_true(store.load_doc("no_such_file.json") == null, "loading a missing file returns null")


## Renaming the hero renames the file. Without cleanup the old one would linger
## and the character would appear twice in the select list.
func _test_rename_removes_old_file() -> void:
	var store = _new_store()
	var doc = Doc.new(_rules)
	doc.set_hero_name("Original Name")
	store.save(doc)
	check_true(store.exists("Original_Name.json"), "original file written")

	doc.set_hero_name("New Name")
	var result: Dictionary = store.save(doc)
	check_eq(result.get("file_name", ""), "New_Name.json", "rename writes under the new name")
	check_true(store.exists("New_Name.json"), "renamed file exists")
	check_false(store.exists("Original_Name.json"), "the old file is removed on rename")


func _test_listing() -> void:
	_wipe()
	var store = _new_store()
	for hero in ["Alpha Hero", "Beta Hero", "Gamma Hero"]:
		var doc = Doc.new(_rules)
		doc.set_hero_name(hero)
		doc.set_profession_id(5)
		store.save(doc)

	var listing: Array = store.list()
	check_eq(listing.size(), 3, "list returns every saved character")

	var names: Array = []
	for entry in listing:
		names.append(entry["hero_name"])
	names.sort()
	check_eq(names, ["Alpha Hero", "Beta Hero", "Gamma Hero"], "list reports hero names")

	var first: Dictionary = listing[0]
	for key in ["file_name", "hero_name", "species_id", "profession_id", "level", "mod_time"]:
		check_true(first.has(key), "list entry has %s" % key)
	check_eq(first["profession_id"], 5, "list reads profession from the saved file")

	# Levels come from the embedded summary block rather than a recomputation.
	check_true(AlternityNum.as_int(first["level"]) >= 1, "list reports an achievement level")


func _test_delete() -> void:
	_wipe()
	var store = _new_store()
	var doc = Doc.new(_rules)
	doc.set_hero_name("Doomed Hero")
	store.save(doc)

	check_true(store.delete("Doomed_Hero.json"), "delete reports success")
	check_false(store.exists("Doomed_Hero.json"), "deleted file is gone")
	check_eq(store.list().size(), 0, "deleted character leaves the listing")
	check_false(store.delete("Doomed_Hero.json"), "deleting a missing file reports failure")


func _test_last_opened() -> void:
	_wipe()
	var store = _new_store()
	check_eq(store.last_opened(), "", "no last-opened character initially")

	var doc = Doc.new(_rules)
	doc.set_hero_name("Recent Hero")
	store.save(doc)
	check_eq(store.last_opened(), "Recent_Hero.json", "saving records the last opened character")

	# Deleting the tracked character must not leave a pointer to a missing file,
	# which would send the app to a character that no longer exists on launch.
	store.delete("Recent_Hero.json")
	check_eq(store.last_opened(), "", "deleting the tracked character clears the pointer")

	# A pointer to a file removed some other way is also ignored.
	store.set_last_opened("Vanished.json")
	check_eq(store.last_opened(), "", "a stale pointer to a missing file is ignored")


func _test_import_export() -> void:
	var store = _new_store()
	var doc = Doc.new(_rules)
	doc.set_hero_name("Shared Hero")
	doc.set_notes("Session notes")

	var text := store.export_json(doc)
	check_true(text.contains("Shared Hero"), "export contains the hero name")
	check_true(text.contains("summary"), "export embeds the summary block")

	var imported = store.import_json(text)
	if check(imported != null, "exported JSON imports back"):
		check_eq(imported.get_hero_name(), "Shared Hero", "imported hero name matches")
		check_eq(imported.get_notes(), "Session notes", "imported notes match")
		check_eq(imported.source_file, "", "an imported document has no source file yet")

	check_true(store.import_json("not json at all") == null, "invalid JSON imports as null")
	check_true(store.import_json("[1, 2, 3]") == null, "a JSON array is not a character")


func _test_safe_filenames() -> void:
	check_eq(Store.safe_filename("Simple"), "Simple", "plain name is unchanged")
	check_eq(Store.safe_filename("Two Words"), "Two_Words", "spaces become underscores")
	check_eq(Store.safe_filename("Hyphen-Name"), "Hyphen_Name", "hyphens become underscores")
	check_eq(Store.safe_filename("Bad/Slash:Name"), "BadSlashName", "invalid characters are dropped")
	check_eq(Store.safe_filename(""), "", "empty name stays empty")

	# An unnameable hero still has to save somewhere.
	var doc = Doc.new(_rules)
	doc.set_hero_name("///")
	check_eq(Store.file_name_for(doc), "hero.json", "a name with no usable characters falls back to hero.json")


## The end-to-end guarantee: a real saved character survives save/load through
## the new stack without changing.
func _test_real_fixtures_round_trip() -> void:
	_wipe()
	var store = _new_store()
	for name in ["real_tech_op_marco", "real_tech_op_thomas"]:
		var original = Doc.from_dict(_rules, Support.load_json(Support.fixture_path(name)))
		var before := Support.canonical(original.to_dict())

		var result: Dictionary = store.save(original)
		if not check(bool(result.get("ok", false)), "%s saves" % name):
			continue

		var reloaded = store.load_doc(String(result["file_name"]))
		if not check(reloaded != null, "%s reloads" % name):
			continue

		check_eq(
			Support.canonical(reloaded.to_dict()), before,
			"%s survives save and reload unchanged" % name
		)
