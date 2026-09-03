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
## This is the main scene. It replaced main.tscn, whose 6,300-line main.gd built
## the entire UI procedurally in one file.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")
const SELECT_SCREEN := preload("res://scenes/ui/screens/character_select.tscn")
const SHEET_SCREEN := preload("res://scenes/ui/screens/character_sheet.tscn")
const CAMPAIGN_SELECT_SCREEN := preload("res://scenes/ui/screens/campaign_select.tscn")
const GM_SCREEN := preload("res://scenes/ui/screens/gm_screen.tscn")
const TABLE_JOIN_SCREEN := preload("res://scenes/ui/screens/table_join.tscn")
const PLAYER_TABLE_SCREEN := preload("res://scenes/ui/screens/player_table.tscn")

var rules
var store: CharacterStore
var campaigns: CampaignStore
var identity: PlayerIdentity
var router: UiRouter

var _background: ColorRect
var _modal_host: ModalHost
var _screens: Control
var _select: CharacterSelectScreen
var _sheet: CharacterSheetScreen
var _campaign_select: CampaignSelectScreen
var _gm: GmScreen
var _table_join: TableJoinScreen
var _player_table: PlayerTableScreen
var _palette: ThemePalette

var _is_wide: bool = false

## Where characters are read and written. Empty means the real user:// location.
##
## Set before the shell enters the tree to point it somewhere else. Tests must
## do this: without it they would read and overwrite real saved characters.
@export var store_directory: String = ""

## Where campaigns are read and written. Empty means user://campaigns/.
##
## Separate from store_directory because the two stores are separate; a test
## that redirects one and not the other would still write real files.
@export var campaign_directory: String = ""


func _ready() -> void:
	rules = RulesScript.new()
	rules.load_core_data()
	store = CharacterStore.new(rules) if store_directory.is_empty() else CharacterStore.new(rules, store_directory)
	campaigns = CampaignStore.new() if campaign_directory.is_empty() else CampaignStore.new(campaign_directory)
	# Who this device is at other people's tables. Kept beside the characters
	# rather than with the campaigns: it describes the person, not the table.
	identity = PlayerIdentity.new() if store_directory.is_empty() else PlayerIdentity.new(store_directory)

	_palette = _resolve_palette()
	_connect_theme()

	_modal_host = ModalHost.new()
	add_child(_modal_host)
	router = UiRouter.new(_modal_host)

	# The window's own clear colour is not the theme's, so without this the app
	# sits on a grey that no palette chose.
	_background = ColorRect.new()
	_background.name = "Background"
	_background.color = _palette.background
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	_screens = Control.new()
	_screens.name = "Screens"
	_screens.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_screens)
	# Behind the modal host, which sits on its own CanvasLayer.
	move_child(_background, 0)
	move_child(_screens, 1)

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
		# The backdrop is built once and outlives the rebuild below, so it has to
		# be recoloured by hand or the app keeps the old theme's ground.
		if _background != null and is_instance_valid(_background):
			_background.color = palette.background
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
	_select.campaigns_opened.connect(_show_campaigns)


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


## The campaign list, a sibling of the character list rather than a route.
##
## A destination, not an overlay: opening a campaign leads to a full screen of
## its own, and the router's stack is for things you come back from.
func _show_campaigns() -> void:
	_clear_screens()
	_campaign_select = CAMPAIGN_SELECT_SCREEN.instantiate()
	_campaign_select.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screens.add_child(_campaign_select)
	_campaign_select.setup(campaigns, router, _palette)
	_campaign_select.campaign_opened.connect(_open_campaign)
	_campaign_select.join_requested.connect(_show_table_join)
	_campaign_select.closed.connect(_on_campaigns_closed)


func _open_campaign(session: CampaignSession) -> void:
	_clear_screens()
	_gm = GM_SCREEN.instantiate()
	_gm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screens.add_child(_gm)
	_gm.setup(session, campaigns, store, rules, router, _palette)
	_gm.closed.connect(_on_gm_closed)


## The player's side of the same feature, and a sibling of the campaign list.
##
## Reached from there rather than from its own top-level entry because "run a
## table" and "join a table" are the same question asked from two ends, and a
## person who is a GM one week and a player the next should find both in one
## place.
func _show_table_join() -> void:
	_clear_screens()
	_table_join = TABLE_JOIN_SCREEN.instantiate()
	_table_join.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screens.add_child(_table_join)
	_table_join.setup(identity, _palette)
	_table_join.table_joined.connect(_open_player_table)
	_table_join.closed.connect(_show_campaigns)


func _open_player_table(transport: EnetTransport, campaign_name: String) -> void:
	# The join screen hands the live connection over rather than closing and
	# reopening it: the handshake has already happened, and reconnecting would
	# make the GM see a player leave and arrive for no reason.
	_clear_screens()
	_player_table = PLAYER_TABLE_SCREEN.instantiate()
	_player_table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screens.add_child(_player_table)
	_player_table.setup(transport, identity, store, rules, _palette, campaign_name)
	_player_table.closed.connect(_show_campaigns)


func _on_campaigns_closed() -> void:
	campaigns.clear_last_opened()
	_show_select()


func _on_gm_closed() -> void:
	campaigns.clear_last_opened()
	_show_campaigns()


func _clear_screens() -> void:
	_select = null
	_sheet = null
	_campaign_select = null
	_gm = null
	_table_join = null
	_player_table = null
	for child in _screens.get_children():
		_screens.remove_child(child)
		child.queue_free()


func _rebuild_active_screen() -> void:
	if _sheet != null and is_instance_valid(_sheet):
		var doc: CharacterDoc = _sheet.document()
		if doc != null:
			# Colours are baked into styleboxes at build time, so a rebuild is
			# unavoidable -- but the tab you were on must survive it. Changing
			# the theme used to drop you back on Basics.
			var was_on: String = _sheet.active_tab_id()
			_open_sheet(doc)
			if not was_on.is_empty():
				_sheet.restore_tab(was_on)
			return
	# Colours are baked in at build time, so a theme change rebuilds whatever
	# screen is showing -- not always the character list.
	#
	# The two networked screens are the exception: rebuilding one would close the
	# connection it owns, so changing the theme mid-session would drop the player
	# from the table. They keep the old colours until the table is left, which is
	# the lesser of the two surprises.
	if _player_table != null and is_instance_valid(_player_table):
		return
	if _table_join != null and is_instance_valid(_table_join):
		return
	if _gm != null and is_instance_valid(_gm):
		if _gm.is_hosting():
			return
		_open_campaign(_gm.session())
		return
	if _campaign_select != null and is_instance_valid(_campaign_select):
		_show_campaigns()
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
	if _gm != null and is_instance_valid(_gm):
		_on_gm_closed()
		return
	# Both of these leave the network on the way out: their _exit_tree closes the
	# connection, so backing out of a table cannot leave a socket behind.
	if _player_table != null and is_instance_valid(_player_table):
		_show_campaigns()
		return
	if _table_join != null and is_instance_valid(_table_join):
		_show_campaigns()
		return
	if _campaign_select != null and is_instance_valid(_campaign_select):
		_on_campaigns_closed()
		return
	# At the character list there is nowhere further back, so honour the quit.
	get_tree().quit()


## Escape does what Android back does.
##
## Desktop parity, and it makes the back path reachable without a phone:
## NOTIFICATION_WM_GO_BACK_REQUEST is only ever emitted on Android, so without
## this the unwind logic could not be exercised anywhere else.
func _unhandled_input(event: InputEvent) -> void:
	if _screens == null:
		return
	if not event.is_action_pressed(&"ui_cancel"):
		return
	# Only consume it while something is open; at the character list Escape
	# should not quit the way Android back does, since a desktop window has its
	# own close button.
	if router != null and router.handle_back_request():
		get_viewport().set_input_as_handled()
		return
	if _sheet != null and is_instance_valid(_sheet):
		_on_sheet_closed()
		get_viewport().set_input_as_handled()
		return
	if _gm != null and is_instance_valid(_gm):
		_on_gm_closed()
		get_viewport().set_input_as_handled()
		return
	if _player_table != null and is_instance_valid(_player_table):
		_show_campaigns()
		get_viewport().set_input_as_handled()
		return
	if _table_join != null and is_instance_valid(_table_join):
		_show_campaigns()
		get_viewport().set_input_as_handled()
		return
	if _campaign_select != null and is_instance_valid(_campaign_select):
		_on_campaigns_closed()
		get_viewport().set_input_as_handled()


func _handle_resize() -> void:
	var wide := _compute_is_wide()
	if wide == _is_wide:
		return
	_is_wide = wide
	# Layout is chosen at build time (stacked versus side by side), so crossing
	# the breakpoint means rebuilding.
	_rebuild_active_screen()
