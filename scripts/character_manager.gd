class_name CharacterManager
extends RefCounted

signal character_updated
signal request_save
signal save_completed(path: String, success: bool)

var character: Dictionary = {}
var active_character_file: String = ""
var rules: RefCounted

func _init():
	pass

func set_rules(p_rules: RefCounted):
	rules = p_rules

func get_character() -> Dictionary:
	return character

func set_character(p_character: Dictionary) -> void:
	character = p_character
	if rules: rules.ensure_character_shape(character)
	character_updated.emit()

func load_character_from_file(file_name: String) -> bool:
	var path := "user://" + file_name
	if not FileAccess.file_exists(path): return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return false
	var content_str := file.get_as_text()
	var json := JSON.new()
	if json.parse(content_str) != OK: return false
	var data_parsed = json.get_data()
	if typeof(data_parsed) == TYPE_DICTIONARY:
		set_character(data_parsed)
		active_character_file = file_name
		return true
	return false

func notify_updated():
	character_updated.emit()

func apply_change_ability(ability: String, delta: int) -> void:
	var abilities: Dictionary = character.get("abilities", {})
	var score: int = rules._as_int(abilities.get(ability, 10))

	var limits: Array = rules.ability_limits(character, ability)
	var min_score: int = rules._as_int(limits[0]) if limits.size() > 0 else 4
	var max_score: int = rules._as_int(limits[1]) if limits.size() > 1 else 14

	score = clampi(score + delta, min_score, max_score)
	abilities[ability] = score
	character["abilities"] = abilities
	rules.clamp_trackers(character)
	notify_updated()
	request_save.emit()

func save_character(notes_editing: bool = false, notes_draft: String = "") -> void:
	if notes_editing: character["notes"] = notes_draft
	var safe_name := safe_filename(String(character.get("hero_name", "hero")))
	if safe_name.is_empty(): safe_name = "hero"
	var filename := safe_name + ".json"
	var path := "user://" + filename
	if not active_character_file.is_empty() and active_character_file != filename:
		var old_path := "user://" + active_character_file
		if FileAccess.file_exists(old_path) and old_path != path:
			DirAccess.remove_absolute(old_path)
	active_character_file = filename
	var tracker := FileAccess.open("user://last_character.txt", FileAccess.WRITE)
	if tracker != null: tracker.store_string(filename)
	var payload := character.duplicate(true)
	if rules: payload["summary"] = rules.summary(character)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		save_completed.emit("", false)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	save_completed.emit(ProjectSettings.globalize_path(path), true)

func safe_filename(name: String) -> String:
	var safe := ""
	for i in range(name.length()):
		var c := name[i]
		if c.is_valid_filename() and c != " " and c != "-": safe += c
		elif c == " " or c == "-": safe += "_"
	return safe

func share_character() -> void:
	if character.is_empty(): return
	var payload := character.duplicate(true)
	if rules: payload["summary"] = rules.summary(character)
	var json_str := JSON.stringify(payload)
	var encoded := Marshalls.utf8_to_base64(json_str)
	var url := "https://wilmer-alternity-sidekick.vercel.app/?data=" + encoded
	OS.shell_open(url)
