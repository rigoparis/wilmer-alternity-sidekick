class_name CampaignSelectScreen
extends Control
##
## Choosing, creating, renaming and deleting campaigns.
##
## The character list's sibling, and built the same way on purpose: same banner,
## same action bar, same card-per-entry list, same confirm-before-delete. A
## campaign is the other kind of document this app keeps, and the two screens
## should not need to be learned separately.
##
## Reads only the campaign headers -- see CampaignStore.list() -- so opening this
## screen never touches the event logs.
##

## A campaign was chosen or created and should be opened.
signal campaign_opened(session: CampaignSession)

## Join somebody else's table rather than running one.
signal join_requested

## Leave the campaign list and go back to the character list.
signal closed

const CONFIRM_ROUTE := preload("res://scenes/ui/routes/confirm_route.tscn")
const TEXT_PROMPT_ROUTE := preload("res://scenes/ui/routes/text_prompt_route.tscn")

var _store: CampaignStore
var _router: UiRouter
var _palette: ThemePalette

var _list: VBoxContainer
var _empty_note: Label


func setup(store: CampaignStore, router: UiRouter, palette: ThemePalette) -> void:
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

	# Centred inside gutters on a wide screen, the same as the character list.
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

	_empty_note = Widgets.muted_text(
		column,
		"No campaigns yet. Create one to seat your table.",
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

	var heading := Widgets.text(box, "Campaigns", _palette, 20, _palette.accent)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Widgets.muted_text(
		box,
		"A campaign is the table you keep between sittings: who plays, which hero they play, and everything that happened.",
		_palette
	)


func _build_actions(parent: Container) -> void:
	# A grid rather than a row or a stack: three buttons across a 390px phone runs
	# the last one off the screen, and three full-width buttons stacked pushes the
	# campaign list below the fold.
	var bar := GridContainer.new()
	bar.columns = 3 if _is_wide() else 2
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_constant_override("h_separation", Widgets.GAP_SECTION)
	bar.add_theme_constant_override("v_separation", Widgets.GAP_SECTION)
	parent.add_child(bar)

	var create := Button.new()
	create.name = "CreateCampaignButton"
	create.text = "Create Campaign"
	create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create.custom_minimum_size = Vector2(0, 44)
	create.pressed.connect(_on_create_pressed)
	bar.add_child(create)

	var join := Button.new()
	join.name = "JoinTableButton"
	join.text = "Join a Table"
	join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join.custom_minimum_size = Vector2(0, 44)
	join.tooltip_text = "Connect to a GM running a campaign on this network"
	join.pressed.connect(func(): join_requested.emit())
	bar.add_child(join)

	var back := Button.new()
	back.name = "BackToHeroesButton"
	back.text = "Back to Heroes"
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.custom_minimum_size = Vector2(0, 44)
	back.pressed.connect(func(): closed.emit())
	bar.add_child(back)


## One side of the reading gutter on a wide screen.
func _gutter() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 1.0
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _is_wide() -> bool:
	return get_viewport_rect().size.x >= ModalHost.COMPACT_WIDTH


## Redraw the campaign list. Cheap: headers only, never the event logs.
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
	var campaign_id := String(entry.get("campaign_id", ""))
	var display_name := String(entry.get("display_name", "Untitled Campaign"))

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

	Widgets.text(box, display_name, _palette, Widgets.FONT_SECTION_TITLE)
	Widgets.muted_text(box, _describe(entry), _palette, Widgets.FONT_CAPTION)

	var actions := HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	box.add_child(actions)

	var open_button := Button.new()
	open_button.text = "Open"
	open_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_button.custom_minimum_size = Vector2(0, 36)
	open_button.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
	open_button.pressed.connect(_on_open_pressed.bind(campaign_id))
	actions.add_child(open_button)

	var rename_button := Button.new()
	rename_button.text = "Rename"
	rename_button.custom_minimum_size = Vector2(88, 36)
	rename_button.pressed.connect(_on_rename_pressed.bind(campaign_id, display_name))
	actions.add_child(rename_button)

	var delete_button := Button.new()
	delete_button.text = "Delete"
	delete_button.custom_minimum_size = Vector2(80, 36)
	delete_button.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.warning, 6))
	delete_button.add_theme_color_override("font_color", _palette.warning)
	delete_button.pressed.connect(_on_delete_pressed.bind(campaign_id, display_name))
	actions.add_child(delete_button)


func _describe(entry: Dictionary) -> String:
	var seats := AlternityNum.as_int(entry.get("seat_count", 0))
	var events := AlternityNum.as_int(entry.get("event_count", 0))
	var created := AlternityNum.as_int(entry.get("created_at", 0))
	var started := "unknown"
	if created > 0:
		var date := Time.get_datetime_dict_from_unix_time(created)
		started = "%04d-%02d-%02d" % [date["year"], date["month"], date["day"]]
	return "%d %s  -  %d logged %s  -  started %s" % [
		seats,
		"seat" if seats == 1 else "seats",
		events,
		"event" if events == 1 else "events",
		started,
	]


func _on_create_pressed() -> void:
	if _router == null:
		return
	var chosen = await _router.push(TEXT_PROMPT_ROUTE, {
		"palette": _palette,
		"title": "Name the campaign",
		"message": "You can rename it later.",
		"placeholder": "Star Drive: The Verge",
		"confirm_text": "Create",
	})
	if not is_instance_valid(self) or chosen == null:
		return

	var session := CampaignSession.new(String(chosen))
	# Saved immediately so it appears in the list even if the person backs out
	# before seating anyone, matching how a new hero behaves.
	_store.save(session)
	refresh()
	_store.set_last_opened(session.campaign_id)
	campaign_opened.emit(session)


func _on_open_pressed(campaign_id: String) -> void:
	var session := _store.load_session(campaign_id)
	if session == null:
		push_warning("CampaignSelect: could not load %s" % campaign_id)
		refresh()
		return
	_store.set_last_opened(campaign_id)
	campaign_opened.emit(session)


func _on_rename_pressed(campaign_id: String, current_name: String) -> void:
	if _router == null:
		return
	var chosen = await _router.push(TEXT_PROMPT_ROUTE, {
		"palette": _palette,
		"title": "Rename campaign",
		"text": current_name,
		"confirm_text": "Rename",
	})
	if not is_instance_valid(self) or chosen == null:
		return

	# A header-only write. Loading the campaign to change one string would pull a
	# year of events into memory for nothing.
	_store.rename(campaign_id, String(chosen))
	refresh()


func _on_delete_pressed(campaign_id: String, display_name: String) -> void:
	if _router == null:
		return
	var confirmed = await _router.push(CONFIRM_ROUTE, {
		"palette": _palette,
		"title": "Delete %s?" % display_name,
		"message": "This removes the campaign and its whole event log. It cannot be undone.",
		"confirm_text": "Delete",
		"destructive": true,
	})
	# The screen can be torn down while the dialog is open.
	if not is_instance_valid(self):
		return
	if confirmed == true:
		_store.delete(campaign_id)
		refresh()
