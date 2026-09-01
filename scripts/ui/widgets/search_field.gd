class_name SearchField
extends VBoxContainer
##
## A search box that survives its results being rebuilt.
##
## The old UI carried three functions and two member variables to work around
## the fact that it did not: _request_search_refresh recorded a target name and
## caret column, deferred the refresh, and _restore_search_focus /
## _focus_line_edit_at then hunted down the *newly built* LineEdit to give it
## focus back and restore the caret. That existed because refreshing a catalog
## tore down the whole panel, search box included, on every keystroke.
##
## Owning the field separately removes the problem rather than compensating for
## it. The tab rebuilds only its results container; this control is never
## destroyed, so focus and caret are simply never lost.
##
## Built in code rather than as a .tscn deliberately: this is a leaf control
## with no designable structure, the same way Godot's own compound controls are
## written. Screens and tabs are scenes; primitives like this are not.
##

## Emitted after the text settles. Connect this to rebuild results.
signal query_changed(query: String)

## Emitted when the person presses enter.
signal submitted(query: String)

## Wait this long after the last keystroke before emitting query_changed.
##
## Filtering the 259-item equipment catalog on every keystroke is affordable on
## desktop and noticeably less so on a phone. Zero disables debouncing.
@export var debounce_seconds: float = 0.15

var _edit: LineEdit
var _timer: Timer
var _palette: ThemePalette

## Last query actually emitted, so the same one is never announced twice.
##
## LineEdit.clear() fires text_changed itself, so an explicit emit alongside it
## produced two. De-duplicating here also means typing a character and deleting
## it again costs no rebuild.
var _last_emitted: String = ""


func _init() -> void:
	add_theme_constant_override("separation", Widgets.GAP_TIGHT)


## Build the field. Call once, after adding it to the tree.
func setup(palette: ThemePalette, placeholder: String = "Search...", label_text: String = "", initial_query: String = "") -> void:
	_palette = palette

	if not label_text.is_empty():
		var label := Label.new()
		label.text = label_text
		label.add_theme_color_override("font_color", palette.muted)
		label.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
		add_child(label)

	_edit = LineEdit.new()
	_edit.placeholder_text = placeholder
	_edit.text = initial_query
	_edit.clear_button_enabled = true
	_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 42px clears the touch-target minimum; this is a phone-first app.
	_edit.custom_minimum_size = Vector2(0, 42)
	_edit.text_changed.connect(_on_text_changed)
	_edit.text_submitted.connect(_on_submitted)
	add_child(_edit)
	_last_emitted = initial_query

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_emit_query)
	add_child(_timer)


func query() -> String:
	return "" if _edit == null else _edit.text


## Set the text without emitting, for restoring saved filter state.
func set_query(value: String) -> void:
	if _edit == null or _edit.text == value:
		return
	_edit.text = value


func focus() -> void:
	if _edit != null:
		_edit.grab_focus()


func clear() -> void:
	if _edit == null:
		return
	# clear() fires text_changed, which schedules the emit; flush it so clearing
	# feels immediate rather than waiting out the debounce.
	_edit.clear()
	_flush()


func _on_text_changed(_value: String) -> void:
	if debounce_seconds <= 0.0 or _timer == null:
		_emit_query()
		return
	_timer.start(debounce_seconds)


func _on_submitted(value: String) -> void:
	# Enter means "search now", so any pending debounce is redundant.
	_flush()
	submitted.emit(value)


## Emit any pending query immediately.
func _flush() -> void:
	if _timer != null:
		_timer.stop()
	_emit_query()


func _emit_query() -> void:
	var current := query()
	if current == _last_emitted:
		return
	_last_emitted = current
	query_changed.emit(current)
