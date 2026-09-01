class_name UiRouter
extends RefCounted
##
## Navigation stack for routes presented over the app.
##
## Replaces nine overlays that were built eagerly into the shell and toggled by
## hand. Two consequences of that design, both visible on the primary platform:
##
##   * The Android back button was unhandled. _notification() only handled
##     NOTIFICATION_RESIZED, and quit_on_go_back defaults to true, so opening
##     any overlay and pressing back QUIT THE APP.
##   * Nothing owned stacking, so draw order came from construction order.
##
## RefCounted rather than Node: the router never touches the scene tree -- the
## ModalHost does that -- so it is owned by whoever holds it and cannot be left
## orphaned in memory.
##
## The call site becomes an await, which inverts the control flow that made the
## old catalogs so tangled -- they mutated the character directly and then
## triggered a global re-render:
##
##     var picked: Array = await router.push(PERK_CATALOG, {"kind": "perk"})
##     for id in picked:
##         doc.add_perk(id)
##
## The catalog no longer knows what a perk is for. It returns a selection.
##

## Emitted when the stack changes, so a shell can reflect depth (for example by
## swapping a menu icon for a back arrow).
signal stack_changed(depth: int)

enum Presentation {
	## Let the route decide, falling back to PAGE.
	AUTO,
	## A destination: catalogs, forms. Full-screen on a phone.
	PAGE,
	## A detail view: sized to content, bottom sheet on a phone.
	SHEET,
	## An interruption that needs an answer: confirms, small pickers.
	DIALOG,
}

var _host: ModalHost


func _init(host: ModalHost = null) -> void:
	_host = host


func set_host(host: ModalHost) -> void:
	_host = host


func depth() -> int:
	return 0 if _host == null else _host.depth()


func is_presenting() -> bool:
	return depth() > 0


## Present a route and wait for its result.
##
## Returns whatever the route passed to close(), or null if it was cancelled or
## could not be presented. Callers should guard with is_instance_valid(self)
## after awaiting if they may be freed in the meantime -- awaiting a signal from
## a node that is freed mid-await is the standard Godot footgun.
func push(scene: PackedScene, props: Dictionary = {}, presentation: int = Presentation.AUTO) -> Variant:
	if _host == null:
		push_error("UiRouter has no ModalHost; call set_host() first")
		return null
	if scene == null:
		push_error("UiRouter.push called with a null scene")
		return null

	var route := scene.instantiate()
	if not (route is RouteScene):
		push_error("UiRouter.push expects a RouteScene, got %s" % route.get_class())
		route.free()
		return null

	route.configure(props)

	var resolved := presentation
	if resolved == Presentation.AUTO:
		resolved = route.preferred_presentation()
	if resolved == Presentation.AUTO:
		resolved = Presentation.PAGE

	_host.present(route, resolved)
	stack_changed.emit(depth())

	var result: Variant = await route.closed

	# The route may already be gone if the whole stack was cleared underneath
	# it; dismiss_top is a no-op on an empty stack, so this stays safe.
	if _host.top_route() == route:
		_host.dismiss_top()
	stack_changed.emit(depth())
	return result


## Close the top route, as if it had cancelled.
##
## Returns false when there was nothing to close, which is what lets the back
## handler fall through to whatever should happen at the root.
func pop(result: Variant = null) -> bool:
	if _host == null:
		return false
	var route := _host.top_route()
	if route == null:
		return false
	# close() drives the awaiting push() to finish, which performs the dismissal.
	route.close(result)
	return true


## Close every open route, innermost first.
func pop_all() -> void:
	if _host == null:
		return
	var guard := 0
	while _host.top_route() != null and guard < 64:
		_host.top_route().close(null)
		guard += 1


## Handle a hardware back request. Returns true if it was consumed.
##
## Wire this to NOTIFICATION_WM_GO_BACK_REQUEST. Without it, Android quits the
## app on back, which is what the old UI did from every overlay.
func handle_back_request() -> bool:
	if _host == null:
		return false
	var route := _host.top_route()
	if route == null:
		return false
	if not route.is_dismissible():
		# A route with unsaved edits swallows the press rather than discarding
		# them; it is expected to prompt instead.
		return true
	route.close(null)
	return true
