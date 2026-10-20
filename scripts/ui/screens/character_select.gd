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

## The campaign list was asked for. A sibling destination, not an overlay: a
## campaign opens onto a screen of its own.
signal campaigns_opened

const CONFIRM_ROUTE := preload("res://scenes/ui/routes/confirm_route.tscn")
const IMPORT_ROUTE := preload("res://scenes/ui/routes/import_character_route.tscn")
const OPTIONAL_RULES_ROUTE := preload("res://scenes/ui/routes/optional_rules_route.tscn")

var _rules
var _store: CharacterStore
var _router: UiRouter
var _palette: ThemePalette

var _list: VBoxContainer
var _empty_note: Label

## Shows the storage notice whatever the platform. For tests: the notice is
## Android-only and no suite runs there.
var force_storage_notice: bool = false

var _storage_notice: PanelContainer
var _storage_detail: Label
var _storage_moved: Label
## Set while the player is away granting storage access, so coming back to the
## app knows to look again.
var _awaiting_storage: bool = false


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

	# Centred inside gutters on a wide screen, the same as the sheet. Filling a
	# 1920px window makes "Load Hero" a 1780px button, which is not using the
	# space so much as stretching two controls across it.
	var host: Container = margin
	if _is_wide():
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin.add_child(row)
		row.add_child(_gutter())
		var body := VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.size_flags_stretch_ratio = CharacterSheetScreen.CONTENT_STRETCH
		row.add_child(body)
		row.add_child(_gutter())
		host = body

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 20)
	host.add_child(column)

	_build_banner(column)
	_build_actions(column)
	_build_storage_notice(column)

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
	var bar: BoxContainer
	if _is_wide():
		bar = HBoxContainer.new()
	else:
		bar = VBoxContainer.new()
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

	var campaigns := Button.new()
	campaigns.name = "CampaignsButton"
	campaigns.text = "Campaigns"
	campaigns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campaigns.custom_minimum_size = Vector2(0, 44)
	campaigns.pressed.connect(func(): campaigns_opened.emit())
	bar.add_child(campaigns)


## Shown on Android while heroes are kept where uninstalling deletes them.
##
## Players lost every hero in v0.1.8 because their saves lived in the app's
## private storage. Shared Documents survives an uninstall, but on Android 11+
## the app can only read it back with All files access, which the system never
## grants by itself -- so the player is asked here, once, rather than the app
## quietly saving somewhere that only looks safe.
func _build_storage_notice(parent: Container) -> void:
	_storage_notice = PanelContainer.new()
	_storage_notice.name = "StorageNotice"
	_storage_notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_storage_notice.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface, _palette.warning, 8))
	parent.add_child(_storage_notice)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.PAD_PANEL)
	_storage_notice.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Widgets.GAP_ROW)
	margin.add_child(box)

	Widgets.text(box, "Your heroes are not safe from an uninstall yet", _palette, Widgets.FONT_SECTION_TITLE, _palette.warning)
	Widgets.muted_text(
		box,
		"They are kept inside the app, and Android deletes them if the app is uninstalled. Allow file access and they are saved in Documents/%s instead, where they survive a reinstall." % CharacterStore.SHARED_FOLDER,
		_palette
	)

	var allow := Button.new()
	allow.name = "KeepHeroesButton"
	allow.text = "Keep heroes on this phone"
	allow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	allow.custom_minimum_size = Vector2(0, 44)
	allow.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
	allow.pressed.connect(_on_keep_heroes_pressed)
	box.add_child(allow)

	_storage_detail = Widgets.muted_text(box, "", _palette, Widgets.FONT_CAPTION)
	_storage_detail.visible = false

	_storage_moved = Widgets.text(parent, "", _palette, Widgets.FONT_CAPTION, _palette.accent)
	_storage_moved.visible = false


func _refresh_storage_notice() -> void:
	if _storage_notice == null:
		return
	_storage_notice.visible = force_storage_notice or CharacterStore.is_lost_on_uninstall(OS.get_name(), _store.directory())


func _on_keep_heroes_pressed() -> void:
	_awaiting_storage = true
	_storage_detail.visible = false
	# On Android 11+ All files access is a settings page, not a dialog: the call
	# opens it and the only word back is the app resuming. On Android 10 and
	# below it is a no-op that returns true, and the older write permission is
	# asked for with an ordinary dialog instead, which does report back.
	if OS.request_permission(CharacterStore.MANAGE_STORAGE):
		if OS.request_permission(CharacterStore.WRITE_STORAGE):
			_check_storage_access()


func _ready() -> void:
	if not get_tree().on_request_permissions_result.is_connected(_on_permission_result):
		get_tree().on_request_permissions_result.connect(_on_permission_result)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and _awaiting_storage:
		_check_storage_access()


func _on_permission_result(_permission: String, _granted: bool) -> void:
	if _awaiting_storage:
		_check_storage_access()


## Move the saves if access was granted, or say what to do instead if not.
func _check_storage_access() -> void:
	if _store == null:
		return
	var asked := _awaiting_storage
	_awaiting_storage = false
	var target := CharacterStore.default_directory()
	if target == _store.directory():
		if asked:
			_storage_detail.text = "File access was not granted, so heroes stay inside the app. Before uninstalling, open each hero and use Share to save a copy."
			_storage_detail.visible = true
		return

	var brought := _store.relocate(target)
	_storage_moved.text = "Heroes are now saved in Documents/%s%s." % [
		CharacterStore.SHARED_FOLDER,
		"" if brought == 0 else " (%d brought across)" % brought,
	]
	_storage_moved.visible = true
	refresh()


## One side of the reading gutter on a wide screen.
func _gutter() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 1.0
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _is_wide() -> bool:
	return get_viewport_rect().size.x >= ModalHost.COMPACT_WIDTH


## Redraw the saved-character list. Cheap: it reads the summary block embedded
## at save time rather than recomputing each sheet.
func refresh() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.hide()
		child.queue_free()

	_refresh_storage_notice()
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

	# Ask which optional rules the campaign uses before the hero exists, because
	# several of them change the starting skill budget and ability limits ---
	# applying them afterwards would mean re-deriving a spread already spent.
	if _router != null:
		var chosen = await _router.push(OPTIONAL_RULES_ROUTE, {
			"palette": _palette,
			"rules": _rules,
			"character": doc.raw(),
			"confirm_text": "Create Hero",
		})
		if not is_instance_valid(self):
			return
		if typeof(chosen) == TYPE_DICTIONARY and not chosen.is_empty():
			var rule_changes: Dictionary = chosen.get("rules", {})
			for rule_id in rule_changes:
				_rules.set_optional_rule(doc.raw(), String(rule_id), bool(rule_changes[rule_id]))
			var supplement_changes: Dictionary = chosen.get("supplements", {})
			for supplement_id in supplement_changes:
				_rules.set_supplement(doc.raw(), String(supplement_id), bool(supplement_changes[supplement_id]))

	# Saved immediately so the hero appears in the list even if the person backs
	# out before editing anything.
	_store.save(doc)
	refresh()
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
	if _router == null:
		return
	var doc = await _router.push(IMPORT_ROUTE, {
		"palette": _palette,
		"store": _store,
	})
	if not is_instance_valid(self) or doc == null:
		return

	# Saved on arrival so it appears in the list and survives a back press, the
	# same as a newly created hero.
	_store.save(doc)
	refresh()
	character_opened.emit(doc)
