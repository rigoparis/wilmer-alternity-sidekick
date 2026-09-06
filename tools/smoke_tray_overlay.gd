extends "res://tools/test_harness.gd"

const TRAY_ROUTE := preload("res://scenes/ui/routes/dice_tray_route.tscn")
const Check := preload("res://scripts/core/session/skill_check.gd")
const RulesScript := preload("res://scripts/alternity_rules.gd")

var _tray_scene


func _init() -> void:
	begin_async("tray overlay aim and touch filters", 600)
	_run.call_deferred()


func _run() -> void:
	var rules = RulesScript.new()
	rules.load_core_data()

	var check = Check.request("player-1", {"id": 1}, {
		"ordinary": 12, "good": 6, "amazing": 3, "step": 1,
	}, "Athletics - Climb")

	_tray_scene = TRAY_ROUTE.instantiate()
	_tray_scene.configure({
		"palette": ThemePalette.new(),
		"rules": rules,
		"check": check.to_dict(),
	})
	root.add_child(_tray_scene)
	await process_frame
	await process_frame

	# 1. Verify overlay exists and mouse_filter is STOP
	var overlay = _tray_scene._aim_overlay
	check_true(overlay != null, "aim overlay is created")
	check_eq(overlay.mouse_filter, Control.MOUSE_FILTER_STOP, "overlay mouse_filter must be STOP")

	# 2. Verify 4-wall snapping (bound = 4.5 - 0.8 = 3.7)
	var p_left = overlay._snap_hand(Vector3(-5.0, 3.2, 0.0))
	check_true(is_equal_approx(p_left.x, -3.7), "snaps to left wall (got %f)" % p_left.x)

	var p_right = overlay._snap_hand(Vector3(5.0, 3.2, 0.0))
	check_true(is_equal_approx(p_right.x, 3.7), "snaps to right wall (got %f)" % p_right.x)

	var p_top = overlay._snap_hand(Vector3(0.0, 3.2, -5.0))
	check_true(is_equal_approx(p_top.z, -3.7), "snaps to top wall (got %f)" % p_top.z)

	var p_bottom = overlay._snap_hand(Vector3(0.0, 3.2, 5.0))
	check_true(is_equal_approx(p_bottom.z, 3.7), "snaps to bottom wall (got %f)" % p_bottom.z)

	# 3. Verify drag state tracking (scroll mode is no longer toggled --
	# accept_event() prevents scroll stealing without changing minimum sizes)
	var scroll = _tray_scene._scroll
	check_true(scroll != null, "scroll container exists")

	overlay._set_drag_state(true, false)
	check_true(overlay._dragging_hand, "dragging_hand is set")
	check_false(overlay._dragging_target, "dragging_target is not set")

	overlay._set_drag_state(false, false)
	check_false(overlay._dragging_hand, "dragging_hand is cleared")
	check_false(overlay._dragging_target, "dragging_target is cleared")

	# Clean up
	_tray_scene.queue_free()
	await process_frame
	finish()
