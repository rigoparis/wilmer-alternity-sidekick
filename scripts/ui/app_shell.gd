class_name AppShell
extends Control
##
## Root of the rewritten UI. Owns the services and routes between screens.
##
## Two things the old shell did not do:
##
##   * Handles NOTIFICATION_WM_GO_BACK_REQUEST. quit_on_go_back defaults to
##     true, so before this, pressing back on Android from any overlay QUIT THE
##     APP. Back now unwinds the route stack, then leaves the sheet, then falls
##     through to quitting only at the character list.
##   * Owns a ModalHost, so route stacking is by open order rather than by the
##     order nine overlays happened to be constructed in.
##
## Not yet the main scene. main.tscn still runs the old UI while the remaining
## tabs are migrated, because the app is in use for an active campaign and must
## keep working. Run this one directly to try it:
##
##     godot --path . res://scenes/ui/app_shell.tscn
##

const RulesScript := preload("res://scripts/alternity_rules.gd")
const SELECT_SCREEN := preload("res://scenes/ui/screens/character_select.tscn")
const SHEET_SCREEN := preload("res://scenes/ui/screens/character_sheet.tscn")

var rules
var store: CharacterStore
var router: UiRouter

var _modal_host: ModalHost
var _screens: Control
var _select: CharacterSelectScreen
var _sheet: CharacterSheetScreen
var _palette: ThemePalette

var _is_wide: bool = false

## Where characters are read and written. Empty means the real user:// location.
##
## Set before the shell enters the tree to point it somewhere else. Tests must
## do this: without it they would read and overwrite real saved characters.
@export var store_directory: String = ""


func _ready() -> void:
	rules = RulesScript.new()
	rules.load_core_data()
	store = CharacterStore.new(rules) if store_directory.is_empty() else CharacterStore.new(rules, store_directory)

	_palette = _resolve_palette()
	_connect_theme()

	_modal_host = ModalHost.new()
	add_child(_modal_host)
	router = UiRouter.new(_modal_host)

	_screens = Control.new()
	_screens.name = "Screens"
	_screens.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_screens)
	# Behind the modal host, which sits on its own CanvasLayer.
	move_child(_screens, 0)

	_is_wide = _compute_is_wide()
	_show_select()

	# Reopen whatever was last in use, matching the old launch behaviour.
	var last := store.last_opened()
	if not last.is_empty():
		var doc = store.load_doc(last)
		if doc != null:
			_open_sheet(doc)


func _resolve_palette() -> ThemePalette:
	var service := get_node_or_null("/root/ThemeService")
	return service.palette() if service != null else ThemePalette.new()


func _connect_theme() -> void:
	var service := get_node_or_null("/root/ThemeService")
	if service == null:
		return
	service.palette_changed.connect(func(palette: ThemePalette):
		_palette = palette
		# Colours are baked into styleboxes at build time, so a theme change
		# means rebuilding the visible screen.
		_rebuild_active_screen())


func _compute_is_wide() -> bool:
	return get_viewport_rect().size.x >= ModalHost.COMPACT_WIDTH


# --- Screens ---------------------------------------------------------------

func _show_select() -> void:
	_clear_screens()
	_select = SELECT_SCREEN.instantiate()
	_select.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screens.add_child(_select)
	_select.setup(rules, store, router, _palette)
	_select.character_opened.connect(_open_sheet)


func _open_sheet(doc: CharacterDoc) -> void:
	_clear_screens()
	_sheet = SHEET_SCREEN.instantiate()
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screens.add_child(_sheet)

	var ctx := SheetContext.new(doc, rules, router, _palette, _is_wide)
	_sheet.setup(ctx, store)
	_sheet.closed.connect(_on_sheet_closed)


func _on_sheet_closed() -> void:
	store.clear_last_opened()
	_show_select()


func _clear_screens() -> void:
	_select = null
	_sheet = null
	for child in _screens.get_children():
		_screens.remove_child(child)
		child.queue_free()


func _rebuild_active_screen() -> void:
	if _sheet != null and is_instance_valid(_sheet):
		var doc: CharacterDoc = _sheet.document()
		if doc != null:
			_open_sheet(doc)
			return
	_show_select()


# --- Input and layout ------------------------------------------------------

func _notification(what: int) -> void:
	# Both arrive while the node is still entering the tree, before _ready has
	# built the screen host, so nothing here may assume it exists.
	if _screens == null:
		return
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_handle_back()
		NOTIFICATION_RESIZED:
			_handle_resize()


## Back unwinds the deepest thing first.
##
## Returning without quitting is the point: the engine quits on this
## notification by default, which is what made back destructive from every
## overlay in the old UI.
func _handle_back() -> void:
	if router != null and router.handle_back_request():
		return
	if _sheet != null and is_instance_valid(_sheet):
		_on_sheet_closed()
		return
	# At the character list there is nowhere further back, so honour the quit.
	get_tree().quit()


func _handle_resize() -> void:
	var wide := _compute_is_wide()
	if wide == _is_wide:
		return
	_is_wide = wide
	# Layout is chosen at build time (stacked versus side by side), so crossing
	# the breakpoint means rebuilding.
	_rebuild_active_screen()
