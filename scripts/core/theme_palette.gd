class_name ThemePalette
extends RefCounted
##
## The eight semantic colours the UI draws with.
##
## These previously had four sources of truth: the Theme/colors/* entries in
## themes/*.tres, ThemeManager caching them, main.gd copying them into eight
## color_* members, and hardcoded fallbacks written out twice more -- once in
## main.gd._setup_theme() and again as default arguments on
## UIBuilder.add_section(). Changing a colour meant finding all four.
##
## This is the one place. A palette is read from a Theme resource; the fallback
## values below are the only hardcoded copy in the project.
##

## Semantic names, in the order they appear in the theme resources. Used for
## dynamic lookup and for validating that a theme defines everything.
const KEYS: Array[StringName] = [
	&"color_background",
	&"color_surface",
	&"color_surface_soft",
	&"color_text",
	&"color_muted",
	&"color_accent",
	&"color_warning",
	&"color_border",
]

## The theme type that custom colours are registered under in the .tres files,
## i.e. Theme/colors/color_accent is get_color("color_accent", "Theme").
const THEME_TYPE := &"Theme"

## Page background, behind everything.
var background: Color = Color(0.05, 0.07, 0.10)

## Panels and cards sitting on the background.
var surface: Color = Color(0.10, 0.12, 0.16)

## Raised or hovered surfaces.
var surface_soft: Color = Color(0.15, 0.18, 0.22)

## Primary readable text.
var text: Color = Color(0.90, 0.92, 0.95)

## Secondary text: labels, captions, disabled states.
var muted: Color = Color(0.50, 0.55, 0.60)

## Selection, focus, and the active tab.
var accent: Color = Color(0.00, 0.80, 0.80)

## Errors and destructive actions.
var warning: Color = Color(0.90, 0.30, 0.20)

## Hairlines and panel outlines.
var border: Color = Color(0.20, 0.25, 0.30)


## Read a palette out of a Theme resource, keeping the fallback for any colour
## the theme does not define. A theme missing an entry renders in the default
## rather than in an unset black.
static func from_theme(theme: Theme) -> ThemePalette:
	var palette := ThemePalette.new()
	if theme == null:
		return palette
	for key in KEYS:
		if theme.has_color(key, THEME_TYPE):
			palette.set_color(key, theme.get_color(key, THEME_TYPE))
	return palette


## Colours this theme fails to define. Empty means fully specified.
static func missing_keys(theme: Theme) -> Array[StringName]:
	var missing: Array[StringName] = []
	if theme == null:
		return KEYS.duplicate()
	for key in KEYS:
		if not theme.has_color(key, THEME_TYPE):
			missing.append(key)
	return missing


## Look up by semantic name. Accepts the theme key ("color_accent") or the bare
## property name ("accent"), so call sites can use whichever reads better.
func get_color(key: StringName) -> Color:
	match _normalize(key):
		&"background": return background
		&"surface": return surface
		&"surface_soft": return surface_soft
		&"text": return text
		&"muted": return muted
		&"accent": return accent
		&"warning": return warning
		&"border": return border
	push_warning("ThemePalette: unknown colour '%s'" % key)
	return text


func set_color(key: StringName, value: Color) -> void:
	match _normalize(key):
		&"background": background = value
		&"surface": surface = value
		&"surface_soft": surface_soft = value
		&"text": text = value
		&"muted": muted = value
		&"accent": accent = value
		&"warning": warning = value
		&"border": border = value
		_: push_warning("ThemePalette: unknown colour '%s'" % key)


func duplicate_palette() -> ThemePalette:
	var copy := ThemePalette.new()
	for key in KEYS:
		copy.set_color(key, get_color(key))
	return copy


func to_dict() -> Dictionary:
	var out := {}
	for key in KEYS:
		out[String(key)] = get_color(key)
	return out


static func _normalize(key: StringName) -> StringName:
	var text_key := String(key)
	return StringName(text_key.trim_prefix("color_"))
