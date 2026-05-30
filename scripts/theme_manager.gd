extends Node

const CONFIG_PATH = "user://theme_config.cfg"

var themes = {
	"Cyber-Dark": preload("res://themes/cyber_dark.tres"),
	"Cyber-Light": preload("res://themes/cyber_light.tres"),
	"80s Synthwave": preload("res://themes/synthwave.tres")
}

var theme_names = ["Cyber-Dark", "Cyber-Light", "80s Synthwave"]

var current_theme_index: int = 0

signal theme_changed

func _ready():
	load_theme_config()
	call_deferred("apply_theme")

func set_theme(index: int):
	if index >= 0 and index < theme_names.size() and current_theme_index != index:
		current_theme_index = index
		save_theme_config()
		apply_theme()
		theme_changed.emit()

func apply_theme():
	var theme_name = theme_names[current_theme_index]
	var theme_res = themes[theme_name]
	if get_tree() != null:
		get_tree().root.theme = theme_res

func load_theme_config():
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	if err == OK:
		var loaded_index = config.get_value("settings", "theme_index", 0)
		if loaded_index >= 0 and loaded_index < theme_names.size():
			current_theme_index = loaded_index

func save_theme_config():
	var config = ConfigFile.new()
	config.set_value("settings", "theme_index", current_theme_index)
	config.save(CONFIG_PATH)

func get_theme_color(color_name: String) -> Color:
	var theme_res = themes[theme_names[current_theme_index]]
	if theme_res.has_color(color_name, "Theme"):
		return theme_res.get_color(color_name, "Theme")
	return Color.WHITE
