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

## Leave the sheet and return to the character list.
signal closed

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

	# A VBoxContainer, not a bare Control. A Control child anchored full-rect
	# reports no minimum size, so the ScrollContainer cannot measure it and the
	# tab ends up clipped against the top of the viewport. A container measures
	# its children, and it skips invisible ones -- which is exactly what is
	# wanted here, since every tab lives in it and only one is visible.
	_content_host = VBoxContainer.new()
	_content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(_content_host)


func _build_header(parent: Container) -> void:
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.PAD_PANEL)
	margin.add_child(header)
	parent.add_child(margin)

	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(1, 0)
	_title.add_theme_color_override("font_color", _ctx.palette.text)
	_title.add_theme_font_size_override("font_size", 22)
	header.add_child(_title)

	_status = Label.new()
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", _ctx.palette.muted)
	_status.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	header.add_child(_status)

	var rules_button := Button.new()
	rules_button.text = "Rules"
	rules_button.tooltip_text = "Optional rules"
	rules_button.custom_minimum_size = Vector2(0, 40)
	rules_button.pressed.connect(_open_optional_rules)
	header.add_child(rules_button)

	var theme_button := Button.new()
	theme_button.text = "Theme"
	theme_button.custom_minimum_size = Vector2(0, 40)
	theme_button.pressed.connect(_open_theme)
	header.add_child(theme_button)

	var share := Button.new()
	share.text = "Share"
	share.custom_minimum_size = Vector2(0, 40)
	share.pressed.connect(_share)
	header.add_child(share)

	var save := Button.new()
	save.text = "Save"
	save.custom_minimum_size = Vector2(0, 40)
	save.pressed.connect(_save)
	header.add_child(save)

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 40)
	close.pressed.connect(_on_close_pressed)
	header.add_child(close)


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

	for definition in _available_tabs():
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
func _share() -> void:
	if _store == null or _ctx == null or _ctx.doc == null:
		return
	var text := _store.export_json(_ctx.doc)
	DisplayServer.clipboard_set(text)

	var file_name := "shared_" + CharacterStore.file_name_for(_ctx.doc)
	var path := "user://" + file_name
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()
		_status.text = "Copied, and written to %s" % file_name
	else:
		_status.text = "Copied to clipboard"
	_status.add_theme_color_override("font_color", _ctx.palette.accent)


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
