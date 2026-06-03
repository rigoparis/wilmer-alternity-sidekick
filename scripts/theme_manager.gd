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

func apply_theme():
	var theme_name = theme_names[current_theme_index]
	var theme_res = themes[theme_name]
	
	var empty_style = StyleBoxEmpty.new()
	theme_res.set_stylebox("normal", "CheckBox", empty_style)
	theme_res.set_stylebox("pressed", "CheckBox", empty_style)
	theme_res.set_stylebox("hover", "CheckBox", empty_style)
	theme_res.set_stylebox("hover_pressed", "CheckBox", empty_style)
	theme_res.set_stylebox("focus", "CheckBox", empty_style)
	theme_res.set_stylebox("disabled", "CheckBox", empty_style)
	
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style = theme_res.get_stylebox(state, "Button")
		if style is StyleBoxFlat:
			style.content_margin_left = 12
			style.content_margin_right = 12
			style.content_margin_top = 4
			style.content_margin_bottom = 4
			
	for state in ["normal", "focus", "read_only"]:
		var style: StyleBox
		if theme_res.has_stylebox(state, "LineEdit"):
			style = theme_res.get_stylebox(state, "LineEdit").duplicate()
		else:
			style = StyleBoxFlat.new()
			var is_focus = (state == "focus")
			style.bg_color = theme_res.get_color("color_surface", "Theme") if theme_res.has_color("color_surface", "Theme") else Color(0.1, 0.1, 0.1)
			style.border_color = theme_res.get_color("color_accent" if is_focus else "color_border", "Theme") if theme_res.has_color("color_accent", "Theme") else Color(0.5, 0.5, 0.5)
			style.set_border_width_all(1)
			style.set_corner_radius_all(8)
		
		if style is StyleBoxFlat:
			style.content_margin_left = 12
			style.content_margin_right = 12
			style.content_margin_top = 8
			style.content_margin_bottom = 8
		theme_res.set_stylebox(state, "LineEdit", style)
			
	if get_tree() != null:
		get_tree().root.theme = theme_res
	theme_changed.emit()

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
