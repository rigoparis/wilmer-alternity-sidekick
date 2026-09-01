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
const TAB_CYBERTECH := preload("res://scenes/ui/tabs/tab_cybertech.tscn")
const TAB_PERKS_FLAWS := preload("res://scenes/ui/tabs/tab_perks_flaws.tscn")

## Migrated tabs, in display order. Phase 5 adds the remaining eight.
const TABS := [
	{"id": "basics", "label": "Basics", "scene": TAB_BASICS},
	{"id": "perks_flaws", "label": "Perks/Flaws", "scene": TAB_PERKS_FLAWS},
	{"id": "cybertech", "label": "Cybertech", "scene": TAB_CYBERTECH},
	{"id": "equipment", "label": "Equipment", "scene": TAB_EQUIPMENT},
	{"id": "achievements", "label": "Achievements", "scene": TAB_ACHIEVEMENTS},
	{"id": "fx", "label": "FX", "scene": TAB_FX},
	{"id": "mutations", "label": "Mutations", "scene": TAB_MUTATIONS},
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
		var scene: PackedScene = definition["scene"]
		var probe := scene.instantiate()
		var applies: bool = probe.is_available_for(_ctx) if probe is SheetTab else true
		probe.free()
		if applies:
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
		if definition.is_empty():
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
