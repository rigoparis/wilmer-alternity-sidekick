extends "res://tools/test_harness.gd"
##
## Navigation stack behaviour.
##
## The back-button cases matter most: they have no existing behaviour to
## regress against, because the old UI did not handle back at all and Android
## quit the app from every overlay.
##

const RouterScript := preload("res://scripts/ui/ui_router.gd")
const HostScript := preload("res://scripts/ui/modal_host.gd")
const RouteScript := preload("res://scripts/ui/route_scene.gd")

var _host
var _router


## A minimal route, packed at runtime so these tests need no .tscn fixtures.
class TestRoute:
	extends RouteScene

	var configured_props: Dictionary = {}
	var pinned_presentation: int = UiRouter.Presentation.AUTO
	var dismissible: bool = true

	func configure(props: Dictionary) -> void:
		configured_props = props
		if props.has("pinned_presentation"):
			pinned_presentation = props["pinned_presentation"]
		if props.has("dismissible"):
			dismissible = props["dismissible"]

	func preferred_presentation() -> int:
		return pinned_presentation

	func is_dismissible() -> bool:
		return dismissible


func _init() -> void:
	begin_async("ui router", 600)
	_run.call_deferred()


func _run() -> void:
	_host = HostScript.new()
	root.add_child(_host)
	await process_frame

	_router = RouterScript.new(_host)

	await _test_push_returns_result()
	await _test_configure_receives_props()
	await _test_cancel_returns_null()
	await _test_stacking()
	await _test_back_button()
	await _test_non_dismissible()
	await _test_pop_all()
	_test_guards()

	_host.queue_free()
	finish()


func _packed(props: Dictionary = {}) -> PackedScene:
	var route := TestRoute.new()
	var packed := PackedScene.new()
	packed.pack(route)
	route.free()
	return packed


## Close the top route on the next frame, so a pending push() can resolve.
func _close_top_soon(result: Variant) -> void:
	await process_frame
	var route = _host.top_route()
	if route != null:
		route.close(result)


func _test_push_returns_result() -> void:
	_close_top_soon.call_deferred(["perk_a", "perk_b"])
	var result = await _router.push(_packed())
	check_eq(result, ["perk_a", "perk_b"], "push returns what the route closed with")
	check_eq(_router.depth(), 0, "the route is popped once it closes")
	check_false(_router.is_presenting(), "nothing is presenting afterwards")


func _test_configure_receives_props() -> void:
	var captured := [null]
	# Capture the live instance before closing it, to inspect what it was given.
	var grab := func() -> void:
		await process_frame
		captured[0] = _host.top_route()
		_host.top_route().close("done")
	grab.call_deferred()

	await _router.push(_packed(), {"kind": "perk", "budget": 12})
	var route = captured[0]
	if check(route != null, "the route instance was reachable while presented"):
		check_eq(route.configured_props.get("kind", ""), "perk", "configure receives props")
		check_eq(route.configured_props.get("budget", 0), 12, "configure receives every prop")


func _test_cancel_returns_null() -> void:
	_close_top_soon.call_deferred(null)
	var result = await _router.push(_packed())
	check_true(result == null, "a cancelled route returns null")


func _test_stacking() -> void:
	# Push one route, then a second from inside it, and unwind in order.
	var outer_done := [false]
	var inner_result := [null]

	var outer := func() -> void:
		await process_frame
		# A second route on top of the first.
		var nested := func() -> void:
			await process_frame
			check_eq(_router.depth(), 2, "two routes are stacked")
			var top = _host.top_route()
			check_true(top != null, "the inner route is on top")
			top.close("inner")
		nested.call_deferred()
		inner_result[0] = await _router.push(_packed())
		check_eq(_router.depth(), 1, "closing the inner route leaves the outer one")
		# close() emits synchronously and resumes the awaiting caller inline, so
		# anything this lambda still needs to record must be set first.
		outer_done[0] = true
		_host.top_route().close("outer")

	outer.call_deferred()
	var result = await _router.push(_packed())

	check_true(outer_done[0], "the outer route completed")
	check_eq(inner_result[0], "inner", "the inner push resolved with its own result")
	check_eq(result, "outer", "the outer push resolved with its own result")
	check_eq(_router.depth(), 0, "the stack is empty again")


## The case that quit the app before.
func _test_back_button() -> void:
	check_false(_router.handle_back_request(), "back is not consumed when nothing is presented")

	var pressed_back := func() -> void:
		await process_frame
		check_eq(_router.depth(), 1, "a route is presented")
		check_true(_router.handle_back_request(), "back is consumed while presenting")
	pressed_back.call_deferred()

	var result = await _router.push(_packed())
	check_true(result == null, "back dismisses the route as a cancellation")
	check_eq(_router.depth(), 0, "back pops the stack")
	check_false(_router.handle_back_request(), "back falls through again once the stack is empty")


## A route with unsaved edits swallows back rather than discarding them.
func _test_non_dismissible() -> void:
	var finished := [false]
	var guarded := func() -> void:
		await process_frame
		check_true(_router.handle_back_request(), "back is consumed by a non-dismissible route")
		check_eq(_router.depth(), 1, "a non-dismissible route survives back")
		# It still closes when it decides to.
		finished[0] = true
		_host.top_route().close("saved")
	guarded.call_deferred()

	var result = await _router.push(_packed(), {"dismissible": false})
	check_true(finished[0], "the guarded route ran its checks")
	check_eq(result, "saved", "the route closes on its own terms")


func _test_pop_all() -> void:
	var done := [false]
	var build_stack := func() -> void:
		await process_frame
		var second := func() -> void:
			await process_frame
			check_eq(_router.depth(), 2, "two routes before clearing")
			done[0] = true
			_router.pop_all()
		second.call_deferred()
		await _router.push(_packed())

	build_stack.call_deferred()
	await _router.push(_packed())
	check_true(done[0], "pop_all ran")
	check_eq(_router.depth(), 0, "pop_all empties the stack")


func _test_guards() -> void:
	# A router with no host must fail loudly rather than silently doing nothing.
	var orphan = RouterScript.new()
	check_eq(orphan.depth(), 0, "a hostless router reports an empty stack")
	check_false(orphan.pop(), "popping a hostless router reports failure")
	check_false(orphan.handle_back_request(), "back on a hostless router is not consumed")

	check_false(_router.pop(), "popping an empty stack reports failure")
