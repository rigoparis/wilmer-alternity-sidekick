class_name CharacterStore
extends RefCounted
##
## Reads and writes characters under user://. Pure I/O -- no UI, no dialogs.
##
## Extracted from CharacterManager, which mixed persistence with state
## ownership (now CharacterDoc) and took UI state as arguments: save_character()
## carried notes_editing and notes_draft, threaded through 14 call sites from
## unrelated tabs. The document owns its notes now, so saving takes a document
## and nothing else.
##
## The on-disk format is unchanged: one JSON file per character named after the
## hero, plus a "summary" block written alongside so the character-select list
## can show levels without recomputing every sheet.
##

## Emitted after a save attempt. `path` is the globalized path on success.
signal saved(file_name: String, path: String)
signal save_failed(file_name: String, reason: String)

const SAVE_DIR := "user://"
const LAST_OPENED_NAME := "last_character.txt"

var _rules

## Directory this store reads and writes, always with a trailing slash.
##
## Injectable so tests can point at a scratch directory. Without that, running
## the store tests would overwrite real saved characters in user://.
var _dir: String = SAVE_DIR


func _init(rules, directory: String = SAVE_DIR) -> void:
	_rules = rules
	_dir = directory if directory.ends_with("/") else directory + "/"
	if _dir != SAVE_DIR:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))


func _last_opened_path() -> String:
	return _dir + LAST_OPENED_NAME


# --- Listing ---------------------------------------------------------------

## Metadata for every saved character, most recently modified first.
##
## Reads the "summary" block embedded at save time rather than recomputing;
## summary() is expensive and this runs once per file on the select screen.
## Falls back to the top-level achievement_level for files saved before the
## summary block existed.
func list() -> Array:
	var saved: Array = []
	var dir := DirAccess.open(_dir)
	if dir == null:
		return saved

	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue

		var path := _dir + file_name
		var data = _read_json(path)
		if typeof(data) != TYPE_DICTIONARY:
			continue

		var summary: Dictionary = data.get("summary", {}) if typeof(data.get("summary")) == TYPE_DICTIONARY else {}
		var level := AlternityNum.as_int(summary.get("achievement_level", 1), 1)
		if level == 1:
			level = AlternityNum.as_int(data.get("achievement_level", 1), 1)

		saved.append({
			"file_name": file_name,
			"hero_name": String(data.get("hero_name", "New Hero")),
			"species_id": AlternityNum.as_int(data.get("species_id", 0)),
			"profession_id": AlternityNum.as_int(data.get("profession_id", 0)),
			"level": level,
			"mod_time": FileAccess.get_modified_time(path),
		})

	saved.sort_custom(func(a, b): return a["mod_time"] > b["mod_time"])
	return saved


func exists(file_name: String) -> bool:
	return FileAccess.file_exists(_dir + file_name)


# --- Load / save -----------------------------------------------------------

## Load one character. Returns null if the file is missing or unparseable.
func load_doc(file_name: String):
	var data = _read_json(_dir + file_name)
	if typeof(data) != TYPE_DICTIONARY:
		return null
	# The stored summary is a snapshot for the list view; the document
	# recomputes its own, so drop it rather than carry a stale copy.
	data.erase("summary")
	return CharacterDoc.from_dict(_rules, data, file_name)


## Write a character to user://, returning {ok, file_name, path, reason}.
##
## Renaming the hero renames the file, so the previous one is removed -- without
## that, renaming would leave a duplicate behind under the old name.
func save(doc: CharacterDoc) -> Dictionary:
	var file_name := file_name_for(doc)
	var path := _dir + file_name

	var previous := doc.source_file
	if not previous.is_empty() and previous != file_name:
		var previous_path := _dir + previous
		if FileAccess.file_exists(previous_path):
			DirAccess.remove_absolute(previous_path)

	# Order matters: summary() settles the character (it writes
	# achievement_points_available back onto it) before to_dict() snapshots it.
	var summary := doc.summary()
	var payload := doc.to_dict()
	payload["summary"] = summary

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var reason := "Cannot open %s for writing (error %d)" % [path, FileAccess.get_open_error()]
		save_failed.emit(file_name, reason)
		return {"ok": false, "file_name": file_name, "path": "", "reason": reason}

	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

	doc.source_file = file_name
	doc.mark_saved()
	set_last_opened(file_name)

	var global_path := ProjectSettings.globalize_path(path)
	saved.emit(file_name, global_path)
	return {"ok": true, "file_name": file_name, "path": global_path, "reason": ""}


func delete(file_name: String) -> bool:
	var path := _dir + file_name
	if not FileAccess.file_exists(path):
		return false
	var error := DirAccess.remove_absolute(path)
	if error != OK:
		return false
	if last_opened() == file_name:
		clear_last_opened()
	return true


# --- Import / export -------------------------------------------------------

## Serialized form for sharing, including the summary block so a recipient can
## list it without recomputing.
func export_json(doc: CharacterDoc) -> String:
	var summary := doc.summary()
	var payload := doc.to_dict()
	payload["summary"] = summary
	return JSON.stringify(payload, "\t")


## Build a document from pasted or imported JSON. Returns null if it does not
## parse as a character.
##
## Uses JSON.parse() rather than JSON.parse_string(): the latter pushes an
## engine error on malformed input, and a person pasting the wrong thing into
## the import box is an ordinary outcome to report in the UI, not a fault to log.
func import_json(text: String):
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return null
	data.erase("summary")
	return CharacterDoc.from_dict(_rules, data)


# --- Last opened -----------------------------------------------------------

## File name of the character to reopen on launch, or "" if none.
func last_opened() -> String:
	var file := FileAccess.open(_last_opened_path(), FileAccess.READ)
	if file == null:
		return ""
	var name := file.get_as_text().strip_edges()
	# Guard against a stale pointer to a character that has since been deleted.
	return name if not name.is_empty() and exists(name) else ""


func set_last_opened(file_name: String) -> void:
	var file := FileAccess.open(_last_opened_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(file_name)
		file.close()


func clear_last_opened() -> void:
	if FileAccess.file_exists(_last_opened_path()):
		DirAccess.remove_absolute(_last_opened_path())


# --- Naming ----------------------------------------------------------------

## The file a document saves to, derived from the hero name.
static func file_name_for(doc: CharacterDoc) -> String:
	var safe := safe_filename(doc.get_hero_name())
	if safe.is_empty():
		safe = "hero"
	return safe + ".json"


## Reduce a hero name to something safe on every target filesystem. Spaces and
## hyphens become underscores; anything else invalid is dropped.
static func safe_filename(name: String) -> String:
	var safe := ""
	for i in name.length():
		var c := name[i]
		if c == " " or c == "-":
			safe += "_"
		elif c.is_valid_filename():
			safe += c
	return safe


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())
