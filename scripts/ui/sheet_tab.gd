class_name SheetTab
extends VBoxContainer
##
## Base class for the ten character-sheet tabs.
##
## The contract exists to kill the global re-render. The old UI called _render()
## from 67 places, and each call tore down and rebuilt the entire active tab --
## every Label, every Button -- because nothing knew what had actually changed.
## The tab cache, dirty flags, saved scroll offsets, custom_minimum_size
## freezing and the double `await process_frame` in _restore_scroll_position
## were all machinery compensating for that.
##
## Here a tab declares which sections of the character it renders, and the base
## refreshes it only when one of those changes. A tab that is not on screen
## defers its refresh until it is shown, so switching to a stale tab is one
## rebuild rather than the whole sheet rebuilding on every keystroke elsewhere.
##
## Subclasses implement build(), which draws into the container they are given,
## and declare watched_sections(). They never call a global render.
##

## Ask the shell to persist the character. Emitted rather than calling a store
## directly so a tab has no opinion about where characters live -- the old code
## threaded notes_editing and notes_draft through save_character() at 14 call
## sites from unrelated tabs.
signal save_requested

var ctx: SheetContext

## Set when a watched section changed while this tab was hidden.
var _needs_rebuild: bool = true

var _bound: bool = false


## Which parts of the character this tab draws.
##
## Override to narrow it. The default is everything, which is correct but makes
## the tab rebuild more than it needs to; Summary genuinely wants ALL because it
## aggregates the whole sheet.
func watched_sections() -> Array:
	return CharacterDoc.ALL


## Whether this tab applies to this character at all.
##
## Replaces the special case hardcoded in _tab_visible(): Mutations only appears
## for the Mutant species.
##
## Takes the whole context rather than just the document, because deciding
## usually needs the rules too -- "is this the Mutant species" means asking the
## rules for that id. The shell asks on a probe instance before binding, so
## `ctx` is still null here: use the argument, never the member.
func is_available_for(_context: SheetContext) -> bool:
	return true


## Draw the tab. Called with a fresh, empty container.
##
## Subclasses must not retain nodes across calls: the container is cleared
## before each build.
func build(_container: Container) -> void:
	push_error("%s does not implement build()" % get_script().resource_path)


## Attach this tab to a character. Idempotent; safe to call again after the
## context changes (a GM switching which player they are looking at).
func bind(context: SheetContext) -> void:
	if _bound and ctx != null and ctx.doc != null and is_instance_valid(ctx.doc):
		if ctx.doc.changed.is_connected(_on_document_changed):
			ctx.doc.changed.disconnect(_on_document_changed)

	ctx = context
	_bound = true
	_needs_rebuild = true

	if ctx != null and ctx.doc != null:
		ctx.doc.changed.connect(_on_document_changed)

	if is_visible_in_tree():
		refresh()


func unbind() -> void:
	if ctx != null and ctx.doc != null and is_instance_valid(ctx.doc):
		if ctx.doc.changed.is_connected(_on_document_changed):
			ctx.doc.changed.disconnect(_on_document_changed)
	ctx = null
	_bound = false


## Rebuild now if anything has changed since the last build.
func refresh(force: bool = false) -> void:
	if ctx == null or not ctx.is_valid():
		return
	if not force and not _needs_rebuild:
		return
	_needs_rebuild = false
	_rebuild()


func needs_rebuild() -> bool:
	return _needs_rebuild


func _rebuild() -> void:
	var container := _content_container()
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	build(container)


## Where build() draws. Defaults to this node -- a VBoxContainer, matching the
## vertical stack every tab renderer already produces. Override when a tab scene
## has a dedicated content node beneath its own chrome (a sticky header, say).
func _content_container() -> Container:
	return self


func _on_document_changed(sections: PackedStringArray) -> void:
	if not _touches_watched(sections):
		return
	_needs_rebuild = true
	# Only rebuild if the person is looking at this tab. A hidden tab catches up
	# when it is shown, so editing on one tab does not rebuild the other nine.
	if is_visible_in_tree():
		refresh()


func _touches_watched(sections: PackedStringArray) -> bool:
	var watched := watched_sections()
	for section in sections:
		if watched.has(StringName(section)):
			return true
	return false


func _notification(what: int) -> void:
	# Becoming visible is the moment a deferred rebuild has to happen.
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		refresh()
