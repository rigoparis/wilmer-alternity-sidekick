extends RouteScene
## Encounter presentation owns no campaign state. The roster can sit alongside
## a future map without changing who owns rounds, rolls or character documents.
var _controller: Node
var _palette: ThemePalette
var _body: VBoxContainer
var _queued := false

func title() -> String:
	return "Encounter"

func preferred_presentation() -> int:
	return UiRouter.Presentation.PAGE

func configure(props: Dictionary) -> void:
	_controller = props.get("controller")
	_palette = props.get("palette", ThemePalette.new())
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface, _palette.border, 8, true))
	add_child(panel)
	var page_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		page_margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(page_margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	page_margin.add_child(column)
	var back := Button.new()
	back.text = "Back to table"
	back.custom_minimum_size.y = 42
	back.pressed.connect(func(): close())
	column.add_child(back)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var content_margin := MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_right", 8)
	content_margin.add_theme_constant_override("margin_bottom", 8)
	scroll.add_child(content_margin)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 20)
	content_margin.add_child(_body)
	if is_instance_valid(_controller):
		_controller.connect("encounter_changed", _request_render)
	_render()

func _ready() -> void:
	get_viewport().size_changed.connect(_request_render)
	_request_render()

func _request_render() -> void:
	if not _queued:
		_queued = true
		_render.call_deferred()

func _render() -> void:
	_queued = false
	if is_closed() or not is_instance_valid(_controller):
		return
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var fight: ActionRound = _controller.encounter_round()
	if fight == null:
		_label(_body, "The encounter has ended.", Widgets.FONT_SECTION_TITLE)
		return
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	_body.add_child(heading)
	_label(heading, fight.describe(), Widgets.FONT_SECTION_TITLE, true)
	if fight.state == ActionRound.STATE_ROLLING:
		_label(heading, "%d of %d ready" % [fight.combatants.size() - fight.awaiting_checks().size(), fight.combatants.size()])
	else:
		_label(heading, "Amazing  /  Good  /  Ordinary  /  Marginal", Widgets.FONT_CAPTION)
	var roster := Widgets.section(_body, "Participants" if fight.state == ActionRound.STATE_ROLLING else "Acting this phase", _palette)
	roster.add_theme_constant_override("separation", 12)
	if fight.state == ActionRound.STATE_ROLLING:
		for entry in fight.combatants:
			_card(roster, fight, entry)
	else:
		var actors := fight.acting_now()
		if actors.is_empty():
			_label(roster, "Round complete" if fight.is_finished() else "No actions in this phase")
		var shown: Array = []
		for entry in actors:
			_card(roster, fight, entry)
			shown.append(entry["id"])
		var others := Widgets.section(_body, "On the field", _palette)
		others.add_theme_constant_override("separation", 12)
		for entry in fight.combatants:
			if not shown.has(entry["id"]):
				_card(others, fight, entry)
		var phases := Widgets.section(_body, "Phase order", _palette)
		phases.add_theme_constant_override("separation", 12)
		for phase in ActionRound.PHASES:
			var names: PackedStringArray = []
			for entry in fight.acting_in(phase):
				names.append(String(entry.get("name", "Character")))
			_label(phases, "%s: %s" % [ActionRound.PHASE_NAMES[phase], " → ".join(names) if not names.is_empty() else "No actions"], Widgets.FONT_CAPTION, phase == fight.phase())
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 16)
	var controls_section := Widgets.section(_body, "", _palette)
	controls_section.add_child(controls)
	_controller.encounter_controls(controls)
	_touch_pass(_body)
	size_hint_changed.emit()

func _card(parent: Container, fight: ActionRound, entry: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface_soft, _palette.border, 8, true))
	parent.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var name_text := String(entry.get("name", "Character"))
	PortraitView.add_to(row, String(entry.get("portrait", "")), name_text, _palette, 64)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 6)
	row.add_child(info)
	_label(info, name_text, Widgets.FONT_SUBHEADING)
	var degree := String(entry.get("degree", ""))
	var status := "Waiting for initiative" if degree.is_empty() else "Ready · " + String(ActionRound.PHASE_NAMES.get(degree, degree))
	if bool(entry.get("manual", false)):
		status += " · GM placed"
	if bool(entry.get("out", false)):
		status = "Out of combat (%s)" % String(entry.get("out_reason", "down"))
	elif bool(entry.get("pending_out", false)):
		status = "Out after this phase"
	elif fight.state == ActionRound.STATE_ACTIVE:
		var pid := String(entry.get("id", ""))
		var phase_st := fight.status_in_phase(pid, fight.phase())
		var phase_desc := ""
		if fight.current_actor().get("id", "") == pid:
			phase_desc = "Acting now"
		elif phase_st == ActionRound.STATUS_WAITING:
			phase_desc = "Waiting to act"
		elif phase_st == ActionRound.STATUS_COMPLETED:
			phase_desc = "Acted in %s" % fight.phase_name()
		elif phase_st == ActionRound.STATUS_POSTPONED:
			phase_desc = "Postponed in %s" % fight.phase_name()
		else:
			phase_desc = "Not acting in %s" % fight.phase_name()

		var rem := fight.actions_remaining(pid)
		var opps := fight.opportunities_remaining(pid)
		status = "%s · %d action%s left (%d phase opportunit%s)" % [
			phase_desc,
			rem, "" if rem == 1 else "s",
			opps, "y" if opps == 1 else "ies"
		]
	elif fight.is_finished():
		status = "Round complete"
	_label(info, status)


func _label(parent: Container, text: String, font_size: int = Widgets.FONT_CAPTION, accent: bool = false) -> void:
	var label := Widgets.text(parent, text, _palette, font_size, _palette.accent if accent else _palette.text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1

func _touch_pass(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_touch_pass(child)
