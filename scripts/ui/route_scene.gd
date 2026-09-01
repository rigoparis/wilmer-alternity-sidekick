class_name RouteScene
extends Control
##
## Base class for anything UiRouter can present: catalogs, forms, detail views,
## confirmations.
##
## A route is a destination, not a modal. Most of what the old UI drew as
## centred overlays -- the perk, mutation, achievement and equipment catalogs,
## the equipment form, the import screen -- are places you go, pick something,
## and come back from. Only genuinely interrupting things (a confirm, the theme
## picker) are dialogs. Presentation is chosen per route and per screen width;
## see UiRouter.Presentation.
##
## Lifecycle:
##
##   1. The router instantiates the scene and calls configure(props).
##   2. The route renders itself and waits for the person to do something.
##   3. It calls close(result) -- or close() to cancel -- exactly once.
##   4. The router pops it, frees it, and returns the result to whoever pushed.
##
## The router awaits `closed`, so a route that is freed without emitting it
## would hang the caller. close() is the only supported exit, and the router
## calls it itself when dismissing a route from the outside (back button, or
## the whole stack being cleared).
##

## Emitted exactly once, when this route is finished. `result` is null for a
## cancellation and route-defined otherwise.
signal closed(result: Variant)

## Ask the router to resize; a route whose content grew or shrank emits this
## rather than reaching for the host.
signal size_hint_changed

var _closed: bool = false


## Receive the arguments this route was pushed with. Override to read props and
## build the view. The default does nothing so trivial routes can skip it.
func configure(_props: Dictionary) -> void:
	pass


## What this route should look like. Override to pin a route to one form;
## returning AUTO lets the router choose from the route kind and screen width.
func preferred_presentation() -> int:
	return UiRouter.Presentation.AUTO


## Shown in the route header, and used as the back-navigation label.
func title() -> String:
	return ""


## Whether tapping the scrim or pressing back dismisses this route.
##
## False for anything with unsaved edits, which should confirm instead of
## discarding silently.
func is_dismissible() -> bool:
	return true


## Finish this route and hand `result` back to whoever pushed it.
##
## Guarded so a route emitting from two paths at once (a Done button and a
## dismiss, say) cannot resolve the awaiting caller twice.
func close(result: Variant = null) -> void:
	if _closed:
		return
	_closed = true
	closed.emit(result)


func is_closed() -> bool:
	return _closed
