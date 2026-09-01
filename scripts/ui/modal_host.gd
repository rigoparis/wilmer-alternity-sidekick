class_name ModalHost
extends CanvasLayer
##
## Presents routes on top of the app and owns their stacking and sizing.
##
## A CanvasLayer rather than a plain Control because the old UI had no stacking
## management at all: nine overlays were built eagerly into the shell and shown
## with 30 ad-hoc `visible = true/false` toggles, so their draw order was fixed
## by the order they happened to be constructed in, not by what was opened last.
##
## Sizing lives here too. It was previously seven near-identical
## _update_*_modal_height() functions differing only in two magic numbers, plus
## nine hardcoded calls to _resize_modal_panel -- one of which reached into
## equipment_form_state to pick a width.
##

## Below this viewport width, PAGE and SHEET routes go full-screen. Matches the
## COMPACT_WIDTH the rest of the app lays out against.
const COMPACT_WIDTH := 520.0

const MAX_WIDTH_PAGE := 820.0
const MAX_WIDTH_SHEET := 640.0
const MAX_WIDTH_DIALOG := 480.0

## Fraction of viewport height a bottom sheet may occupy on a phone before it
## scrolls internally.
const SHEET_MAX_HEIGHT_RATIO := 0.85

## Margin around a route that is not full-screen.
const EDGE_MARGIN := 12.0

var _scrim: ColorRect
var _frames: Control

## One entry per presented route: { route, frame, presentation }.
var _entries: Array = []


func _ready() -> void:
	layer = 100
	_build_chrome()
	visible = false
	get_viewport().size_changed.connect(_relayout)


func _build_chrome() -> void:
	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	_scrim.color = Color(0.0, 0.0, 0.0, 0.42)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.gui_input.connect(_on_scrim_input)
	add_child(_scrim)

	_frames = Control.new()
	_frames.name = "Frames"
	_frames.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The frame layer must not swallow input meant for the scrim behind it;
	# individual frames take their own.
	_frames.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frames)


func depth() -> int:
	return _entries.size()


func top_route() -> RouteScene:
	if _entries.is_empty():
		return null
	return _entries[-1]["route"]


## Add a route to the stack and show it.
func present(route: RouteScene, presentation: int) -> void:
	var frame := Control.new()
	frame.name = "Frame%d" % (_entries.size() + 1)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(route)
	_frames.add_child(frame)

	_entries.append({"route": route, "frame": frame, "presentation": presentation})

	# Only the topmost route is interactive; the ones beneath stay visible for
	# context but must not take input.
	_refresh_interactivity()
	_layout_entry(_entries[-1])

	route.size_hint_changed.connect(_relayout)
	visible = true


## Remove the top route and free it. The router owns closing; this only tears
## down the presentation.
func dismiss_top() -> void:
	if _entries.is_empty():
		return
	var entry: Dictionary = _entries.pop_back()
	var frame: Control = entry["frame"]
	if is_instance_valid(frame):
		frame.queue_free()
	_refresh_interactivity()
	visible = not _entries.is_empty()


func _refresh_interactivity() -> void:
	for i in _entries.size():
		var route: RouteScene = _entries[i]["route"]
		if is_instance_valid(route):
			var is_top := i == _entries.size() - 1
			route.mouse_filter = Control.MOUSE_FILTER_STOP if is_top else Control.MOUSE_FILTER_IGNORE
			route.process_mode = Node.PROCESS_MODE_INHERIT if is_top else Node.PROCESS_MODE_DISABLED


func _relayout() -> void:
	for entry in _entries:
		_layout_entry(entry)


## Position one route according to its presentation and the current width.
##
## The same route is a full-screen page on a phone and a centred panel on a
## desktop; this is the only place that decision is made.
func _layout_entry(entry: Dictionary) -> void:
	var route: RouteScene = entry["route"]
	var frame: Control = entry["frame"]
	if not is_instance_valid(route) or not is_instance_valid(frame):
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.x < COMPACT_WIDTH
	var presentation: int = entry["presentation"]

	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	match presentation:
		UiRouter.Presentation.PAGE:
			if compact:
				_fill(route, viewport_size)
			else:
				_center(route, viewport_size, MAX_WIDTH_PAGE, 0.9)
		UiRouter.Presentation.SHEET:
			if compact:
				_bottom_sheet(route, viewport_size)
			else:
				_center(route, viewport_size, MAX_WIDTH_SHEET, 0.8)
		_:
			_center(route, viewport_size, MAX_WIDTH_DIALOG, 0.7)


## Full-bleed, no margin: on a 390px phone the old centred panels lost 24px to
## margins plus the scrollbar, which is what forced the text-wrapping hacks.
func _fill(route: Control, viewport_size: Vector2) -> void:
	route.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	route.custom_minimum_size = Vector2(0, 0)
	route.size = viewport_size


func _center(route: Control, viewport_size: Vector2, max_width: float, height_ratio: float) -> void:
	var width := minf(max_width, viewport_size.x - EDGE_MARGIN * 2.0)
	var max_height := viewport_size.y * height_ratio
	var content_height := route.get_combined_minimum_size().y
	var height := clampf(content_height, 0.0, max_height)
	if height <= 0.0:
		height = max_height

	route.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	route.size = Vector2(width, height)
	route.position = Vector2(
		(viewport_size.x - width) * 0.5,
		(viewport_size.y - height) * 0.5
	)


## Anchored to the bottom edge, sized to content up to a ceiling. Chosen for
## detail views because skill text varies from two lines to a full page, and a
## fixed-height sheet would either crop the long ones or float over the short.
func _bottom_sheet(route: Control, viewport_size: Vector2) -> void:
	var max_height := viewport_size.y * SHEET_MAX_HEIGHT_RATIO
	var content_height := route.get_combined_minimum_size().y
	var height := clampf(content_height, 0.0, max_height)
	if height <= 0.0:
		height = max_height

	route.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	route.size = Vector2(viewport_size.x, height)
	route.position = Vector2(0.0, viewport_size.y - height)


func _on_scrim_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var route := top_route()
	if route != null and route.is_dismissible():
		route.close(null)
