class_name CharacterSheetScreen
extends Control
##
## Tab bar plus the active tab. The sheet half of the app.
##
## Owns only routing and chrome. The old shell also owned every tab renderer,
## every overlay, the scroll offsets, the dirty flags and eight colour members;
## a tab here is a scene that receives a SheetContext and draws itself.
##
## Tabs are declared in TABS below rather than by a match statement over ten
## names. A tab that has not been migrated yet is simply absent from the list,
## which is what lets this run alongside the old UI while the rest move across.
##

## Content takes this many parts against one gutter each side.
const CONTENT_STRETCH := 8.0

## Leave the sheet and return to the character list.
signal closed

## Header icons. preload, not load: these are fixed assets, and the old header
## resolved them at runtime on every build.
const ICON_RULES := preload("res://assets/book.svg")
const ICON_THEME := preload("res://assets/pallete.svg")
const ICON_SHARE := preload("res://assets/share.svg")
const ICON_CLOSE := preload("res://assets/logout.svg")

const TAB_BASICS := preload("res://scenes/ui/tabs/tab_basics.tscn")
const TAB_ACHIEVEMENTS := preload("res://scenes/ui/tabs/tab_achievements.tscn")
const TAB_EQUIPMENT := preload("res://scenes/ui/tabs/tab_equipment.tscn")
const TAB_MUTATIONS := preload("res://scenes/ui/tabs/tab_mutations.tscn")
const TAB_FX := preload("res://scenes/ui/tabs/tab_fx.tscn")
const TAB_SKILLS := preload("res://scenes/ui/tabs/tab_skills.tscn")
const TAB_PSIONICS := preload("res://scenes/ui/tabs/tab_psionics.tscn")
const TAB_SUMMARY := preload("res://scenes/ui/tabs/tab_summary.tscn")

const OPTIONAL_RULES_ROUTE := preload("res://scenes/ui/routes/optional_rules_route.tscn")
const THEME_ROUTE := preload("res://scenes/ui/routes/theme_route.tscn")
const TAB_CYBERTECH := preload("res://scenes/ui/tabs/tab_cybertech.tscn")
const TAB_PERKS_FLAWS := preload("res://scenes/ui/tabs/tab_perks_flaws.tscn")

## All ten tabs, in display order. A tab may still exclude itself for a given
## character -- Mutations and Psionics both do -- see _available_tabs().
const TABS := [
	{"id": "basics", "label": "Basics", "scene": TAB_BASICS},
	{"id": "skills", "label": "Skills", "scene": TAB_SKILLS},
	{"id": "perks_flaws", "label": "Perks/Flaws", "scene": TAB_PERKS_FLAWS},
	{"id": "cybertech", "label": "Cybertech", "scene": TAB_CYBERTECH},
	{"id": "equipment", "label": "Equipment", "scene": TAB_EQUIPMENT},
	{"id": "achievements", "label": "Achievements", "scene": TAB_ACHIEVEMENTS},
	{"id": "psionics", "label": "Psionics", "scene": TAB_PSIONICS},
	{"id": "fx", "label": "FX", "scene": TAB_FX},
	{"id": "mutations", "label": "Mutations", "scene": TAB_MUTATIONS},
	{"id": "summary", "label": "Summary", "scene": TAB_SUMMARY},
]

var _ctx: SheetContext
var _store: CharacterStore

var _title: Label
var _status: Label
var _tab_bar: HBoxContainer
var _content_scroll: ScrollContainer
var _content_host: VBoxContainer

var _buttons: Dictionary = {}
var _instances: Dictionary = {}
var _active_id: String = ""

## Tab ids currently in the bar, so a rebuild only happens when the set changes.
var _listed_ids: Array = []


func setup(ctx: SheetContext, store: CharacterStore) -> void:
	_ctx = ctx
	_store = store
	_build()

	if _ctx.doc != null:
		_ctx.doc.changed.connect(_on_document_changed)
		_ctx.doc.dirty_changed.connect(_on_dirty_changed)

	var available := _available_tabs()
	if not available.is_empty():
		_select_tab(String(available[0]["id"]))
	_refresh_header()


## Which tab is showing, so a rebuild can put you back on it.
func active_tab_id() -> String:
	return _active_id


## Reselect a tab after a rebuild, ignoring one that no longer applies.
func restore_tab(id: String) -> void:
	if id.is_empty() or not _buttons.has(id):
		return
	_select_tab(id)


func document() -> CharacterDoc:
	return null if _ctx == null else _ctx.doc


func _build() -> void:
	var root_box := VBoxContainer.new()
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_box.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	add_child(root_box)

	_build_header(root_box)
	_build_tab_bar(root_box)

	_content_scroll = ScrollContainer.new()
	_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_box.add_child(_content_scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.PAD_PANEL)
	_content_scroll.add_child(margin)

	# Content is centred inside proportional spacers rather than filling the
	# window. A row spanning 1900px puts its label at one edge of the screen and
	# its value at the other, which is unreadable however much space it "uses".
	#
	# Proportional rather than a fixed cap on purpose: Godot 4.6 has no
	# custom_maximum_size (that is 4.7), and the shell only rebuilds when the
	# compact breakpoint is crossed, so an absolute margin computed at build time
	# would not follow an ordinary resize. Stretch ratios do.
	var centred: Container = margin
	if _ctx.is_wide_layout:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin.add_child(row)
		row.add_child(_gutter())
		var body := VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.size_flags_stretch_ratio = CONTENT_STRETCH
		row.add_child(body)
		row.add_child(_gutter())
		centred = body

	# A VBoxContainer, not a bare Control. A Control child anchored full-rect
	# reports no minimum size, so the ScrollContainer cannot measure it and the
	# tab ends up clipped against the top of the viewport. A container measures
	# its children, and it skips invisible ones -- which is exactly what is
	# wanted here, since every tab lives in it and only one is visible.
	_content_host = VBoxContainer.new()
	_content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centred.add_child(_content_host)


## One side of the reading gutter on a wide screen.
func _gutter() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 1.0
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _build_header(parent: Container) -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.PAD_PANEL)
	parent.add_child(margin)

	# The hero name and five text buttons do not fit across a 390px phone. On one
	# row the name was squeezed to its 1px minimum and wrapped to a single letter
	# per line, which grew the header to most of the screen and turned the
	# buttons into tall slabs. Compact stacks it: name first, actions beneath.
	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", Widgets.GAP_ROW)
	margin.add_child(outer)

	var title_row := HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	outer.add_child(title_row)

	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Ellipsis rather than wrap: a long hero name must never be able to grow the
	# header vertically the way wrapping let it.
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.custom_minimum_size = Vector2(1, 0)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", _ctx.palette.text)
	_title.add_theme_font_size_override("font_size", 22 if _ctx.is_wide_layout else 18)
	title_row.add_child(_title)

	_status = Label.new()
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", _ctx.palette.muted)
	_status.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	title_row.add_child(_status)

	# Wide keeps the single row it always had; compact gets its own row where the
	# five buttons share the width evenly instead of competing with the name.
	var actions := HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", Widgets.GAP_ROW)
	if _ctx.is_wide_layout:
		title_row.add_child(actions)
	else:
		outer.add_child(actions)

	# Icons, as the old header had. Five words across the top of a phone is most
	# of the row; five glyphs is a strip. Save keeps its label because it is the
	# one whose state matters and there is no unambiguous icon for it.
	var buttons := [
		[ICON_RULES, "Optional rules", _open_optional_rules],
		[ICON_THEME, "Theme", _open_theme],
		[ICON_SHARE, "Share character", _share],
		[null, "Save", _save],
		[ICON_CLOSE, "Close character", _on_close_pressed],
	]
	for spec in buttons:
		var icon = spec[0]
		var label := String(spec[1])
		var button := Button.new()
		button.tooltip_text = label
		if icon != null:
			button.icon = icon
			button.expand_icon = true
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			button.custom_minimum_size = Vector2(44, 44)
			# Tinted rather than coloured art, so icons follow the palette.
			button.add_theme_color_override("icon_normal_color", _ctx.palette.text)
			button.add_theme_color_override("icon_hover_color", _ctx.palette.accent)
			button.add_theme_color_override("icon_pressed_color", _ctx.palette.accent)
		else:
			# Wide enough to hold its own label. clip_text takes the text out of
			# the minimum size, so without a width the button renders as an
			# empty gap between the icons.
			button.text = label
			button.custom_minimum_size = Vector2(64, 44)
		button.pressed.connect(spec[2])
		actions.add_child(button)


func _build_tab_bar(parent: Container) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 52)
	parent.add_child(scroll)

	_tab_bar = HBoxContainer.new()
	_tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_bar.add_theme_constant_override("separation", 6)
	scroll.add_child(_tab_bar)

	_populate_tab_bar()


func _populate_tab_bar() -> void:
	_listed_ids = []
	for definition in _available_tabs():
		_listed_ids.append(String(definition["id"]))
		var button := Button.new()
		button.text = String(definition["label"])
		button.toggle_mode = true
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 42)
		var id := String(definition["id"])
		button.pressed.connect(func(): _select_tab(id))
		_tab_bar.add_child(button)
		_buttons[id] = button


## Tabs that apply to this character. Replaces the Mutations special case that
## was hardcoded into _tab_visible().
func _available_tabs() -> Array:
	var out: Array = []
	for definition in TABS:
		if _is_available(definition):
			out.append(definition)
	return out


func _select_tab(id: String) -> void:
	if id == _active_id:
		return
	_active_id = id

	for tab_id in _buttons:
		_buttons[tab_id].button_pressed = tab_id == id

	# Instantiate on first visit and keep it: a hidden tab costs nothing,
	# because SheetTab defers its rebuild until it is shown again.
	if not _instances.has(id):
		var definition := _definition_for(id)
		# _definition_for searches the whole registry, so without this a caller
		# could open a tab that excludes itself for this character -- Psionics on
		# a non-psionic hero. The tab bar never offers one, but nothing else
		# stopped it.
		if definition.is_empty() or not _is_available(definition):
			return
		var tab: SheetTab = definition["scene"].instantiate()
		# Laid out by the host container, so no anchor preset here.
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.save_requested.connect(_save)
		_content_host.add_child(tab)
		tab.bind(_ctx)
		_instances[id] = tab

	for tab_id in _instances:
		_instances[tab_id].visible = tab_id == id


## Whether a registry entry applies to the current character.
func _is_available(definition: Dictionary) -> bool:
	var probe = definition["scene"].instantiate()
	var applies: bool = probe.is_available_for(_ctx) if probe is SheetTab else true
	probe.free()
	return applies


func _definition_for(id: String) -> Dictionary:
	for definition in TABS:
		if String(definition["id"]) == id:
			return definition
	return {}


func _refresh_header() -> void:
	if _ctx == null or _ctx.doc == null:
		return
	var name := _ctx.doc.get_hero_name()
	_title.text = name if not name.is_empty() else "Unnamed Hero"
	_on_dirty_changed(_ctx.doc.is_dirty())


func _on_document_changed(sections: PackedStringArray) -> void:
	if sections.has(String(CharacterDoc.META)):
		_refresh_header()
	_refresh_tab_bar()


## Rebuild the tab bar when the set of applicable tabs changes.
##
## Which tabs apply is not fixed for the life of a sheet: choosing the Mutant
## species makes Mutations apply, and becoming a Mindwalker makes Psionics
## apply. The bar was built once in setup(), so neither could ever appear --
## you had to close and reopen the character.
func _refresh_tab_bar() -> void:
	var ids: Array = []
	for definition in _available_tabs():
		ids.append(String(definition["id"]))
	if ids == _listed_ids:
		return

	_listed_ids = ids
	_buttons.clear()
	for child in _tab_bar.get_children():
		_tab_bar.remove_child(child)
		child.queue_free()
	_populate_tab_bar()

	# A tab that stopped applying must not stay on screen.
	if not ids.has(_active_id):
		for tab_id in _instances:
			_instances[tab_id].visible = false
		_active_id = ""
		if not ids.is_empty():
			_select_tab(String(ids[0]))
	else:
		for tab_id in _buttons:
			_buttons[tab_id].button_pressed = tab_id == _active_id


func _on_dirty_changed(is_dirty: bool) -> void:
	if _status == null:
		return
	_status.text = "Unsaved changes" if is_dirty else "Saved"
	_status.add_theme_color_override(
		"font_color",
		_ctx.palette.warning if is_dirty else _ctx.palette.muted
	)


func _open_optional_rules() -> void:
	if _ctx == null or _ctx.router == null:
		return
	var changed = await _ctx.router.push(OPTIONAL_RULES_ROUTE, {
		"palette": _ctx.palette,
		"rules": _ctx.rules,
		"character": _ctx.doc.raw(),
	})
	if not is_instance_valid(self) or typeof(changed) != TYPE_DICTIONARY or changed.is_empty():
		return

	# Optional rules move skill budgets and ability limits, so this invalidates
	# the whole sheet rather than one section.
	var rules: AlternityRules = _ctx.rules
	_ctx.doc.apply(CharacterDoc.ALL, func(c):
		for rule_id in changed:
			rules.set_optional_rule(c, String(rule_id), bool(changed[rule_id])))
	_save()


func _open_theme() -> void:
	if _ctx == null or _ctx.router == null:
		return
	await _ctx.router.push(THEME_ROUTE, {
		"palette": _ctx.palette,
		"service": get_node_or_null("/root/ThemeService"),
	})


## Hand the character to whatever the platform uses for sharing.
##
## Writes next to the save rather than opening a dialog on mobile: Android has
## no usable native save picker here, and a file the person can find beats a
## dialog that never appears.
## Hand the character to the person, somewhere they can actually reach it.
##
## The rewrite had reduced this to a clipboard copy plus a file in user://,
## which on Android is inside the app sandbox and on desktop is buried under
## AppData -- neither is a place you can send a file to a friend from.
##
## Restores the two paths the old flow used: a native Save dialog where the
## platform has one, so the file lands wherever you choose; and Downloads plus
## a shell_open on Android, which is what makes it reachable from the share
## sheet. The clipboard copy is kept as well, since pasting the JSON straight
## into chat is the quickest way to pass a hero around.
func _share() -> void:
	if _store == null or _ctx == null or _ctx.doc == null:
		return
	var text := _store.export_json(_ctx.doc)
	DisplayServer.clipboard_set(text)

	var file_name := CharacterStore.file_name_for(_ctx.doc)

	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG):
		var on_chosen := func(accepted: bool, paths: PackedStringArray, _filter: int) -> void:
			if not is_instance_valid(self):
				return
			if not accepted or paths.is_empty():
				_set_status("Copied to clipboard", _ctx.palette.muted)
				return
			var chosen := String(paths[0])
			if _write(chosen, text):
				_set_status("Saved to %s" % chosen.get_file(), _ctx.palette.accent)
			else:
				_set_status("Could not write %s" % chosen.get_file(), _ctx.palette.warning)
		DisplayServer.file_dialog_show(
			"Save Character", "", file_name, false,
			DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, ["*.json"], on_chosen
		)
		return

	# No native dialog: Android and anywhere else headless-ish. Downloads is the
	# one directory the system file picker and the share sheet both see.
	var downloads := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	var path := "%s/shared_%s" % [downloads, file_name] if not downloads.is_empty() else "user://shared_" + file_name
	if _write(path, text):
		OS.shell_open(ProjectSettings.globalize_path(path))
		_set_status("Saved to %s" % path.get_file(), _ctx.palette.accent)
	else:
		_set_status("Copied to clipboard", _ctx.palette.muted)


func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


func _set_status(message: String, color: Color) -> void:
	if _status == null or not is_instance_valid(_status):
		return
	_status.text = message
	_status.add_theme_color_override("font_color", color)


func _save() -> void:
	if _store == null or _ctx == null or _ctx.doc == null:
		return
	_store.save(_ctx.doc)
	_refresh_header()


func _on_close_pressed() -> void:
	# Saving on the way out matches the old behaviour, where closing offered to
	# save first; unsaved work should never be lost by leaving the sheet.
	if _ctx != null and _ctx.doc != null and _ctx.doc.is_dirty():
		_save()
	closed.emit()
