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
const COMMIT_CHARACTER_ROUTE := preload("res://scenes/ui/routes/commit_character_route.tscn")

## Controls remember their desktop mouse filter while touch-pass mode is active.
## This matters in the editor: switching the helper off must restore deliberate
## IGNORE filters as well as the STOP defaults used by interactive controls.
const TOUCH_SCROLL_FILTER_META := &"_touch_scroll_original_mouse_filter"

var rules
var store: CharacterStore
var campaigns: CampaignStore
var identity: PlayerIdentity
var router: UiRouter

## How an action check gets rolled, wherever it is started from.
##
## Owned here because a check crosses a screen, a network round trip and a
## physics simulation, and the shell is the only thing that already holds all
## three. Screens hand it work; none of them holds the flow.
var checks: CheckRunner

var _background: ColorRect
var _modal_host: ModalHost
var _screens: Control
var _select: CharacterSelectScreen
var _sheet: CharacterSheetScreen
var _campaign_select: CampaignSelectScreen
var _gm: GmScreen
var _table_join: TableJoinScreen
## The table this device is at, when it is at one.
##
## Owned by the shell rather than by a screen, because a player at a table is
## still using the whole app -- the connection has to outlive whichever tab or
## route happens to be showing.
var table: TableSession
var _palette: ThemePalette

var _is_wide: bool = false
var _touch_pass_enabled: bool = false

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
	_touch_pass_enabled = OS.has_feature("mobile")
	# Most UI is assembled procedurally, including route rows that appear after a
	# search. Watching additions keeps those new controls scroll-friendly too.
	get_tree().node_added.connect(_on_tree_node_added)

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
	checks = CheckRunner.new(rules, router, _palette)

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

	_update_mouse_filters_for_touch(self, _touch_pass_enabled)


func _exit_tree() -> void:
	var callback := Callable(self, "_on_tree_node_added")
	if get_tree() != null and get_tree().node_added.is_connected(callback):
		get_tree().node_added.disconnect(callback)


## Let a ScrollContainer claim a finger drag that began over one of its child
## controls. A child using MOUSE_FILTER_STOP receives the initial touch and
## prevents the scroll container from seeing the drag; PASS preserves the
## child's tap/click behaviour while allowing the gesture to bubble upward.
##
## `touch_pass` is explicit so desktop tests and responsive rebuilds can restore
## every control's original filter instead of guessing its class default.
func _update_mouse_filters_for_touch(node: Node, touch_pass: bool) -> void:
	if node == null:
		return
	if node is Control and _has_scroll_ancestor(node):
		var control := node as Control
		if touch_pass:
			if not control.has_meta(TOUCH_SCROLL_FILTER_META):
				control.set_meta(TOUCH_SCROLL_FILTER_META, control.mouse_filter)
			control.mouse_filter = Control.MOUSE_FILTER_PASS
		elif control.has_meta(TOUCH_SCROLL_FILTER_META):
			control.mouse_filter = int(control.get_meta(TOUCH_SCROLL_FILTER_META)) as Control.MouseFilter
			control.remove_meta(TOUCH_SCROLL_FILTER_META)
	for child in node.get_children():
		_update_mouse_filters_for_touch(child, touch_pass)


func _has_scroll_ancestor(node: Node) -> bool:
	# Embedded gesture surfaces own input for their whole subtree, including
	# decorative IGNORE layers. Do not turn those layers into touch blockers.
	var ancestor := node
	while ancestor != null and ancestor != self:
		if ancestor.get_meta(&"owns_touch_gesture", false):
			return false
		if ancestor is ScrollContainer and ancestor != node:
			return true
		ancestor = ancestor.get_parent()
	return false


func _on_tree_node_added(node: Node) -> void:
	if not _touch_pass_enabled or not is_ancestor_of(node):
		return
	# Every member of a newly attached subtree emits node_added after its parent
	# chain is established, so updating just this node covers dynamic lists
	# without queueing one recursive deferred traversal per descendant.
	if node is Control and _has_scroll_ancestor(node):
		var control := node as Control
		if not control.has_meta(TOUCH_SCROLL_FILTER_META):
			control.set_meta(TOUCH_SCROLL_FILTER_META, control.mouse_filter)
		control.mouse_filter = Control.MOUSE_FILTER_PASS


func _resolve_palette() -> ThemePalette:
	var service := get_node_or_null("/root/ThemeService")
	return service.palette() if service != null else ThemePalette.new()


func _connect_theme() -> void:
	var service := get_node_or_null("/root/ThemeService")
	if service == null:
		return
	service.palette_changed.connect(func(palette: ThemePalette):
		_palette = palette
		# CheckRunner is deliberately longer-lived than any one screen or route.
		# Refresh its palette too, or the difficulty dialog and dice tray keep the
		# colours that were active when the app started.
		if checks != null:
			checks.use_palette(palette)
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
	# The sheet is where a player picks a skill, so it is where a check starts.
	ctx.checks = checks
	# And where the table lives, when there is one: a player in a campaign is
	# still playing their character, so the Table tab sits beside Skills rather
	# than replacing the whole sheet.
	ctx.table = table
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
	checks.use_transport(null)
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
	_table_join.table_joined.connect(_on_table_joined)
	_table_join.closed.connect(_show_campaigns)


## Joined a table: ask which hero, then open that hero's sheet.
##
## The player's main screen at a table is their own character sheet, with a Table
## tab on it. It used to be a separate screen, which meant a player could look at
## the table or at their character but never both -- for a campaign that runs for
## months.
func _on_table_joined(transport: EnetTransport, campaign_name: String) -> void:
	table = TableSession.new(transport, identity, store, rules, campaign_name)
	table.leave_requested.connect(_leave_table)
	checks.use_transport(transport)
	set_process(true)

	var doc := await _choose_committed_hero(campaign_name)
	if not is_instance_valid(self):
		return
	if doc != null:
		table.commit(doc)
		store.set_last_opened(doc.source_file)
	_open_sheet(doc if doc != null else CharacterDoc.new(rules))


## Which hero is being played here, and make one if there is none.
##
## Returns null only when the player backed out, in which case they are still
## connected -- the Table tab says so plainly rather than pretending otherwise.
func _choose_committed_hero(campaign_name: String) -> CharacterDoc:
	var answer = await router.push(COMMIT_CHARACTER_ROUTE, {
		"palette": _palette,
		"rules": rules,
		"store": store,
		"campaign_name": campaign_name,
		"optional_rules": table.transport.campaign_optional_rules() if table.transport != null else {},
	})
	if not is_instance_valid(self) or typeof(answer) != TYPE_DICTIONARY:
		return null

	var file_name := String(answer.get("file_name", ""))
	if not file_name.is_empty():
		return store.load_doc(file_name)

	if bool(answer.get("create", false)):
		# Saved immediately so the hero exists on disk before it is committed to
		# a campaign that is about to hold a copy of it.
		var fresh := CharacterDoc.new(rules)
		store.save(fresh)
		return fresh
	return null


func _leave_table() -> void:
	if table != null:
		table.leave()
		table = null
	checks.use_transport(null)
	set_process(false)
	_show_campaigns()


## Pump the table.
##
## Here rather than on a screen so the connection survives the player moving
## between the sheet, a catalog and the dice tray.
func _process(_delta: float) -> void:
	if table != null:
		table.poll()


func _on_campaigns_closed() -> void:
	campaigns.clear_last_opened()
	checks.use_transport(null)
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
	for child in _screens.get_children():
		child.hide()
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
	# The join screen is the exception: it owns a discovery socket and a
	# half-finished handshake, and rebuilding it mid-join would drop both. It
	# keeps the old colours until the player is through it.
	#
	# The sheet is not an exception any more. A player at a table is on their own
	# sheet, and the connection lives on the shell rather than on the screen, so a
	# theme change rebuilds the sheet and the table carries on.
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
	# Backing out while at a table has to close the connection, not just change
	# screens -- the shell owns it now, so nothing else will.
	if table != null:
		_leave_table()
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
	if table != null:
		_leave_table()
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
