class_name CharacterSelectScreen
extends Control
##
## Choosing, creating, importing and deleting characters.
##
## Its own screen rather than a tab. It always was one in effect: the old
## _render() branched on whether a character was loaded, hid the tab bar and two
## header buttons, cleared the content, rendered the list and RETURNED EARLY,
## skipping the entire sheet path. Making that explicit removes the branch.
##
## Deleting now goes through a confirm route instead of the old inline
## two-state card, which put the file into a `deleting_files` dictionary and
## triggered a global re-render to redraw the same card with different buttons.
##

## A character was chosen or created and should be opened.
signal character_opened(doc: CharacterDoc)

const CONFIRM_ROUTE := preload("res://scenes/ui/routes/confirm_route.tscn")

var _rules
var _store: CharacterStore
var _router: UiRouter
var _palette: ThemePalette

var _list: VBoxContainer
var _empty_note: Label


func setup(rules, store: CharacterStore, router: UiRouter, palette: ThemePalette) -> void:
	_rules = rules
	_store = store
	_router = router
	_palette = palette
	_build()
	refresh()


func _build() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.PAD_PANEL)
	scroll.add_child(margin)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)

	_build_banner(column)
	_build_actions(column)

	_empty_note = Widgets.muted_text(
		column,
		"No saved heroes yet. Create one to begin.",
		_palette
	)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	column.add_child(_list)


func _build_banner(parent: Container) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface, Color(0, 0, 0, 0), 8))
	parent.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var heading := Widgets.text(box, "Character Selection", _palette, 20, _palette.accent)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Widgets.muted_text(
		box,
		"Manage your saved Alternity heroes or create a new one to begin your adventure.",
		_palette
	)


func _build_actions(parent: Container) -> void:
	# Stacked on a phone, side by side when there is room. The old code chose
	# between a VBox and an HBox at build time and could not react to a resize;
	# a VBoxContainer that switches its own layout would need a rebuild either
	# way, so this keeps the simple form and lets the shell rebuild on resize.
	var bar: BoxContainer = HBoxContainer.new() if _is_wide() else VBoxContainer.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	parent.add_child(bar)

	var create := Button.new()
	create.text = "Create New Hero"
	create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create.custom_minimum_size = Vector2(0, 44)
	create.pressed.connect(_on_create_pressed)
	bar.add_child(create)

	var import_button := Button.new()
	import_button.text = "Import Hero"
	import_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	import_button.custom_minimum_size = Vector2(0, 44)
	import_button.pressed.connect(_on_import_pressed)
	bar.add_child(import_button)


func _is_wide() -> bool:
	return get_viewport_rect().size.x >= ModalHost.COMPACT_WIDTH


## Redraw the saved-character list. Cheap: it reads the summary block embedded
## at save time rather than recomputing each sheet.
func refresh() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	var saved: Array = _store.list()
	_empty_note.visible = saved.is_empty()
	for entry in saved:
		_build_card(entry)


func _build_card(entry: Dictionary) -> void:
	var file_name := String(entry.get("file_name", ""))
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface, _palette.border, 8))
	_list.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.PAD_PANEL)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", Widgets.GAP_ROW)
	margin.add_child(box)

	Widgets.text(box, String(entry.get("hero_name", "Unnamed")), _palette, Widgets.FONT_SECTION_TITLE)
	Widgets.muted_text(box, _describe(entry), _palette, Widgets.FONT_CAPTION)

	var actions := HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	box.add_child(actions)

	var load_button := Button.new()
	load_button.text = "Load Hero"
	load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_button.custom_minimum_size = Vector2(0, 36)
	load_button.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
	load_button.pressed.connect(_on_load_pressed.bind(file_name))
	actions.add_child(load_button)

	var delete_button := Button.new()
	delete_button.text = "Delete"
	delete_button.custom_minimum_size = Vector2(80, 36)
	delete_button.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.warning, 6))
	delete_button.add_theme_color_override("font_color", _palette.warning)
	delete_button.pressed.connect(_on_delete_pressed.bind(file_name, String(entry.get("hero_name", ""))))
	actions.add_child(delete_button)


func _describe(entry: Dictionary) -> String:
	var species: Dictionary = _rules.get_species_by_id(AlternityNum.as_int(entry.get("species_id", 0)))
	var profession: Dictionary = _rules.get_profession_by_id(AlternityNum.as_int(entry.get("profession_id", 0)))
	return "%s %s  -  Level %d" % [
		String(species.get("name", "Unknown")),
		String(profession.get("name", "Unknown")),
		AlternityNum.as_int(entry.get("level", 1), 1),
	]


func _on_create_pressed() -> void:
	var doc: CharacterDoc = CharacterDoc.new(_rules)
	# Saved immediately so the hero appears in the list even if the person backs
	# out before editing anything.
	_store.save(doc)
	character_opened.emit(doc)


func _on_load_pressed(file_name: String) -> void:
	var doc = _store.load_doc(file_name)
	if doc == null:
		push_warning("CharacterSelect: could not load %s" % file_name)
		refresh()
		return
	_store.set_last_opened(file_name)
	character_opened.emit(doc)


func _on_delete_pressed(file_name: String, hero_name: String) -> void:
	if _router == null:
		return
	var confirmed = await _router.push(CONFIRM_ROUTE, {
		"palette": _palette,
		"title": "Delete %s?" % hero_name,
		"message": "This permanently removes the saved character file. It cannot be undone.",
		"confirm_text": "Delete",
		"destructive": true,
	})
	# The screen can be torn down while the dialog is open.
	if not is_instance_valid(self):
		return
	if confirmed == true:
		_store.delete(file_name)
		refresh()


func _on_import_pressed() -> void:
	# The import flow lands with the rest of the import overlay in phase 5; the
	# button is present so the screen is not silently missing a capability.
	if _router == null:
		return
	await _router.push(CONFIRM_ROUTE, {
		"palette": _palette,
		"title": "Import not migrated yet",
		"message": "Importing a shared character still lives in the old screen and moves across in the next phase.",
		"confirm_text": "OK",
		"cancel_text": "Close",
	})
