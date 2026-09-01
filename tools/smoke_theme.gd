extends "res://tools/test_harness.gd"
##
## Palette resolution and the theme-preparation defect this replaced.
##
## The headline test is _test_masters_are_not_mutated. The previous
## implementation adjusted the *preloaded* Theme resources in place, and its
## LineEdit branch duplicated the previous duplicate on every call, so switching
## themes repeatedly grew a chain of styleboxes each built from the last.
##

const Palette := preload("res://scripts/core/theme_palette.gd")
const ThemeServiceScript := preload("res://scripts/core/theme_service.gd")

const THEME_PATHS := [
	"res://themes/cyber_dark.tres",
	"res://themes/cyber_light.tres",
	"res://themes/synthwave.tres",
]


func _init() -> void:
	begin_async("theme service", 200)
	_run.call_deferred()


func _run() -> void:
	_test_palette_defaults()
	_test_palette_lookup()
	_test_shipped_themes_are_complete()
	_test_masters_are_not_mutated()
	await _test_service_behaviour()
	finish()


func _test_palette_defaults() -> void:
	var palette := Palette.new()
	# A default palette must be usable on its own -- it is what the editor and
	# a bare headless instantiation fall back to.
	check_ne(palette.background, Color(0, 0, 0, 0), "default background is set")
	check_ne(palette.text, palette.background, "default text is readable against the background")
	check_eq(Palette.KEYS.size(), 8, "eight semantic colours")

	# from_theme(null) must not crash; it yields the defaults.
	var from_null := Palette.from_theme(null)
	check_eq(from_null.accent, palette.accent, "from_theme(null) falls back to defaults")


func _test_palette_lookup() -> void:
	var palette := Palette.new()
	palette.accent = Color(1, 0, 0)

	# Both spellings resolve, so call sites can use whichever reads better.
	check_eq(palette.get_color(&"color_accent"), Color(1, 0, 0), "lookup by theme key")
	check_eq(palette.get_color(&"accent"), Color(1, 0, 0), "lookup by bare name")

	palette.set_color(&"color_border", Color(0, 1, 0))
	check_eq(palette.border, Color(0, 1, 0), "set_color by theme key")

	var copy := palette.duplicate_palette()
	check_eq(copy.accent, palette.accent, "duplicate copies values")
	copy.accent = Color(0, 0, 1)
	check_ne(palette.accent, copy.accent, "duplicate is independent")

	check_eq(palette.to_dict().size(), 8, "to_dict exposes every colour")


## Every shipped theme must define all eight colours, or the UI silently renders
## part of itself in fallback colours that do not match the rest.
func _test_shipped_themes_are_complete() -> void:
	for path in THEME_PATHS:
		var theme: Theme = load(path)
		if not check(theme != null, "%s loads" % path):
			continue
		var missing := Palette.missing_keys(theme)
		check_true(
			missing.is_empty(),
			"%s defines every palette colour (missing: %s)" % [path.get_file(), str(missing)]
		)

		# The palette read back must actually differ between themes, otherwise
		# switching would be a no-op.
		var palette := Palette.from_theme(theme)
		check_ne(palette.background, Color(0, 0, 0, 0), "%s has a background" % path.get_file())


## The regression test for the defect this replaced.
##
## load() returns the cached instance, so if preparation mutated the master, a
## reload would show it. Preparing every theme repeatedly must leave the masters
## byte-identical.
func _test_masters_are_not_mutated() -> void:
	var before := {}
	for path in THEME_PATHS:
		before[path] = _fingerprint(load(path))

	var service = ThemeServiceScript.new()
	# Prepare each theme several times, including switching back and forth --
	# the pattern that previously compounded the LineEdit styleboxes.
	for _pass in 3:
		for name in service.theme_names:
			service._prepare(name)

	for path in THEME_PATHS:
		check_eq(
			_fingerprint(load(path)), before[path],
			"%s master is untouched by preparation" % path.get_file()
		)

	# Preparation must also be idempotent in its own right: the same theme
	# prepared twice yields the same margins, not compounding ones.
	var first: Theme = service._prepare("Cyber-Dark")
	var first_margin := first.get_stylebox("normal", "LineEdit").content_margin_left
	service._prepared.clear()
	var second: Theme = service._prepare("Cyber-Dark")
	check_eq(
		second.get_stylebox("normal", "LineEdit").content_margin_left, first_margin,
		"preparing twice from pristine gives the same result"
	)
	check_eq(first_margin, 12.0, "LineEdit padding is applied once, not compounded")

	# Button states must not share a stylebox instance, or padding one pads all.
	var normal := second.get_stylebox("normal", "Button")
	var hover := second.get_stylebox("hover", "Button")
	check_true(normal != hover, "button states have independent stylebox instances")

	service.free()


func _test_service_behaviour() -> void:
	# The autoload is the real thing under test where it exists.
	var service = root.get_node_or_null("/root/ThemeService")
	if not check(service != null, "ThemeService autoload is registered"):
		return

	await process_frame

	var palette = service.palette()
	check_true(palette != null, "service exposes a palette")
	check_eq(service.get_theme_color("color_accent"), palette.accent, "legacy accessor agrees with the palette")

	# Switching themes must actually change the palette and fire both signals.
	var legacy_fired := [false]
	var typed_payload := [null]
	service.theme_changed.connect(func(): legacy_fired[0] = true, CONNECT_ONE_SHOT)
	service.palette_changed.connect(func(p): typed_payload[0] = p, CONNECT_ONE_SHOT)

	var start_index: int = service.current_theme_index
	var other_index: int = (start_index + 1) % service.theme_names.size()
	service.set_theme(other_index)

	check_true(legacy_fired[0], "theme_changed fires on switch")
	check_true(typed_payload[0] != null, "palette_changed carries the new palette")
	check_eq(service.current_theme_index, other_index, "the index moves")

	# Setting the same index again is a no-op.
	var refired := [false]
	service.theme_changed.connect(func(): refired[0] = true, CONNECT_ONE_SHOT)
	service.set_theme(other_index)
	check_false(refired[0], "re-selecting the current theme does not re-emit")

	# Out-of-range indices are ignored rather than crashing.
	service.set_theme(-1)
	service.set_theme(999)
	check_eq(service.current_theme_index, other_index, "out-of-range indices are ignored")

	service.set_theme(start_index)


## A cheap structural signature of a theme, enough to notice a stylebox being
## swapped, padded, or added.
func _fingerprint(theme: Theme) -> String:
	if theme == null:
		return "<null>"
	var parts: Array = []
	var types: Array = theme.get_stylebox_type_list()
	types.sort()
	for type_name in types:
		var names: Array = theme.get_stylebox_list(type_name)
		names.sort()
		for stylebox_name in names:
			var style := theme.get_stylebox(stylebox_name, type_name)
			var margin := ""
			if style is StyleBoxFlat:
				margin = "%s/%s" % [style.content_margin_left, style.content_margin_top]
			parts.append("%s.%s:%s:%s" % [type_name, stylebox_name, style.get_class(), margin])
	return "|".join(parts)
