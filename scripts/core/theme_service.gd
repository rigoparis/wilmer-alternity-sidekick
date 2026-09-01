extends Node
##
## Autoload. Owns the active theme and the palette derived from it.
##
## Replaces ThemeManager, which had a real defect: apply_theme() mutated the
## *preloaded* Theme resources in place. Preloads are cached and shared, so the
## adjustments accumulated -- the LineEdit branch did
##
##     style = theme_res.get_stylebox(state, "LineEdit").duplicate()
##     ...modify...
##     theme_res.set_stylebox(state, "LineEdit", style)
##
## which duplicates the previous duplicate every time it runs. Switching themes
## back and forth grew a chain of styleboxes, each built from the last.
##
## Here the preloaded resources are treated as read-only masters. Each theme is
## prepared once into a working copy, cached, and reused; preparing again always
## starts from the pristine master, so it is idempotent.
##
## The legacy surface ThemeManager exposed (theme_changed, get_theme_color,
## set_theme, theme_names, current_theme_index) is kept so main.gd continues to
## work untouched while the UI is rewritten around it. New code should use
## palette() and the typed ThemePalette instead.
##

## Legacy signal, no arguments. main.gd connects to this.
signal theme_changed

## Typed replacement, carrying the palette that is now in force.
signal palette_changed(palette: ThemePalette)

const CONFIG_PATH := "user://theme_config.cfg"

const THEME_RESOURCES := {
	"Cyber-Dark": preload("res://themes/cyber_dark.tres"),
	"Cyber-Light": preload("res://themes/cyber_light.tres"),
	"80s Synthwave": preload("res://themes/synthwave.tres"),
}

## Display order in the theme picker.
var theme_names: Array[String] = ["Cyber-Dark", "Cyber-Light", "80s Synthwave"]

var current_theme_index: int = 0

## Working copies, built lazily from the pristine masters. Keyed by theme name.
var _prepared: Dictionary = {}

var _palette := ThemePalette.new()


func _ready() -> void:
	_load_config()
	# Deferred so the scene tree root exists before a theme is pushed onto it.
	apply_theme.call_deferred()


## The colours currently in force. Returns the live palette; treat it as
## read-only and reread it after palette_changed rather than caching a copy.
func palette() -> ThemePalette:
	return _palette


func current_theme_name() -> String:
	return theme_names[clampi(current_theme_index, 0, theme_names.size() - 1)]


func set_theme(index: int) -> void:
	if index < 0 or index >= theme_names.size() or index == current_theme_index:
		return
	current_theme_index = index
	_save_config()
	apply_theme()


func apply_theme() -> void:
	var theme := _prepare(current_theme_name())
	_palette = ThemePalette.from_theme(theme)

	if get_tree() != null:
		get_tree().root.theme = theme

	palette_changed.emit(_palette)
	theme_changed.emit()


## Legacy accessor kept for main.gd. Prefer palette().
func get_theme_color(color_name: String) -> Color:
	return _palette.get_color(StringName(color_name))


## Build (or fetch) the working copy of a theme.
##
## Always derived from the untouched preloaded master, so calling it repeatedly
## cannot compound adjustments the way the previous implementation did.
func _prepare(theme_name: String) -> Theme:
	if _prepared.has(theme_name):
		return _prepared[theme_name]

	var master: Theme = THEME_RESOURCES.get(theme_name)
	if master == null:
		push_error("ThemeService: unknown theme '%s'" % theme_name)
		return Theme.new()

	# duplicate(true) copies the subresources too, so mutating styleboxes on the
	# copy cannot reach back into the shared master.
	var theme: Theme = master.duplicate(true)
	_strip_checkbox_backgrounds(theme)
	_pad_button_styles(theme)
	_build_line_edit_styles(theme)

	_prepared[theme_name] = theme
	return theme


## Checkboxes are drawn with custom artwork, so the built-in backgrounds would
## show through behind it.
func _strip_checkbox_backgrounds(theme: Theme) -> void:
	for state in ["normal", "pressed", "hover", "hover_pressed", "focus", "disabled"]:
		theme.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())


## Give buttons breathing room without editing every .tres by hand.
func _pad_button_styles(theme: Theme) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		if not theme.has_stylebox(state, "Button"):
			continue
		var style := theme.get_stylebox(state, "Button")
		if style is StyleBoxFlat:
			# Duplicate before mutating: several states can share one stylebox
			# resource, and padding one would otherwise pad all of them.
			var padded: StyleBoxFlat = style.duplicate()
			padded.content_margin_left = 12
			padded.content_margin_right = 12
			padded.content_margin_top = 4
			padded.content_margin_bottom = 4
			theme.set_stylebox(state, "Button", padded)


## LineEdit is not styled in every .tres, so synthesise a matching look from the
## palette where it is missing and pad it where it is present.
func _build_line_edit_styles(theme: Theme) -> void:
	var palette := ThemePalette.from_theme(theme)
	for state in ["normal", "focus", "read_only"]:
		var style: StyleBox
		if theme.has_stylebox(state, "LineEdit"):
			style = theme.get_stylebox(state, "LineEdit").duplicate()
		else:
			var flat := StyleBoxFlat.new()
			flat.bg_color = palette.surface
			flat.border_color = palette.accent if state == "focus" else palette.border
			flat.set_border_width_all(1)
			flat.set_corner_radius_all(8)
			style = flat

		if style is StyleBoxFlat:
			style.content_margin_left = 12
			style.content_margin_right = 12
			style.content_margin_top = 8
			style.content_margin_bottom = 8
		theme.set_stylebox(state, "LineEdit", style)


func _load_config() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	var index := AlternityNum.as_int(config.get_value("settings", "theme_index", 0))
	if index >= 0 and index < theme_names.size():
		current_theme_index = index


func _save_config() -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "theme_index", current_theme_index)
	config.save(CONFIG_PATH)
