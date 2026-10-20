extends RouteScene
## Render the recorded facts only. Never consult today's character or re-roll.

var _palette: ThemePalette

func preferred_presentation() -> int:
	return UiRouter.Presentation.PAGE

func title() -> String:
	return "Roll breakdown"

func configure(props: Dictionary) -> void:
	_palette = props.get("palette", ThemePalette.new())
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.PAD_PANEL)
	add_child(margin)
	margin.add_child(column)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	_line(body, String(props.get("summary", "Recorded action")))
	_line(body, "Older entries may not contain every die or modifier; missing details were not recorded.")
	var event: Dictionary = props.get("event", {})
	var at := AlternityNum.as_int(event.get("at", 0))
	if at > 0:
		_line(body, "Recorded: " + Time.get_datetime_string_from_unix_time(at, true) + " UTC")
	_render(body, event.get("payload", {}))
	var done := Button.new()
	done.text = "Done"
	done.custom_minimum_size.y = 42
	done.pressed.connect(func(): close(null))
	column.add_child(done)

func _line(parent: Container, text: String) -> void:
	var label := Widgets.text(parent, text, _palette, Widgets.FONT_DETAIL)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(1, 0)

func _render(parent: Container, data: Dictionary) -> void:
	if data.has("notation") and data.has("dice"):
		if not String(data.get("character_name", "")).is_empty():
			_line(parent, "Character: " + String(data["character_name"]))
		if not String(data.get("label", "")).is_empty():
			_line(parent, String(data["label"]))
		var faces: Array = []
		for face in data.get("dice", []):
			faces.append(str(face))
		_line(parent, "%s: faces [%s], modifier %+d, sign %+d → total %d" % [
			String(data.get("notation", "")), ", ".join(faces),
			AlternityNum.as_int(data.get("modifier", 0)), AlternityNum.as_int(data.get("sign", 1), 1),
			AlternityNum.as_int(data.get("total", 0))])
		_line(parent, "Source: %s; cocked-dice rethrows: %d" % [String(data.get("source", "not recorded")), AlternityNum.as_int(data.get("rerolls", 0))])
		# A roll payload can also carry its complete check.
		if data.get("check") is Dictionary:
			_render(parent, {"check": data["check"]})
		return
	for key in data:
		if String(key) in ["format_version", "seed", "seed_used", "check_id", "attack_id", "player_id", "target_id", "target_player_id", "attacker_id", "character_id", "skill_id", "at", "created_at", "timestamp"]:
			continue
		if data.has("check") and String(key) in ["control", "situation", "graded"]:
			continue
		var value = data[key]
		var label := String(key).replace("_", " ").capitalize()
		if value is Dictionary:
			if not value.is_empty():
				_line(parent, "— " + label + " —")
				_render(parent, value)
		elif value is Array:
			if value.is_empty():
				continue
			if value[0] is Dictionary:
				_line(parent, "— " + label + " —")
				for entry in value:
					if entry is Dictionary:
						_render(parent, entry)
			else:
				_line(parent, "%s: %s" % [label, str(value)])
		elif str(value) != "":
			_line(parent, "%s: %s" % [label, str(value)])
