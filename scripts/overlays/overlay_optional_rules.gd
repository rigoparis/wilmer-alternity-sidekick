class_name OverlayOptionalRules
extends Control

const UIBuilder := preload("res://scripts/ui_builder.gd")
const AlternityRules := preload("res://scripts/alternity_rules.gd")

enum Mode {
	MID_RUN,
	NEW_HERO,
	NEW_CAMPAIGN,
}

var mode: Mode = Mode.MID_RUN
var panel: PanelContainer
var body: VBoxContainer
var scroll: ScrollContainer
var main_ui: Node

var title_label: Label
var subtitle_label: Label
var lock_notice_panel: PanelContainer
var lock_notice_label: Label

var actions_box: HBoxContainer
var primary_btn: Button
var secondary_btn: Button
var close_btn: Button

var draft_rules: Dictionary = {}
var active_character: Dictionary = {}
var on_confirm_callback: Callable
var on_cancel_callback: Callable
var on_changed_callback: Callable
var is_gm_locked: bool = false


func build(parent: Node, p_main_ui: Node, color_surface: Color, color_border: Color, color_text: Color) -> void:
	main_ui = p_main_ui

	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(self)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_dim_clicked()
	)
	add_child(dim)

	var overlay_margin := MarginContainer.new()
	overlay_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_margin.add_theme_constant_override("margin_left", 12)
	overlay_margin.add_theme_constant_override("margin_right", 12)
	overlay_margin.add_theme_constant_override("margin_top", 12)
	overlay_margin.add_theme_constant_override("margin_bottom", 12)
	add_child(overlay_margin)

	var center := CenterContainer.new()
	overlay_margin.add_child(center)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 420)
	panel.add_theme_stylebox_override("panel", UIBuilder.flat_style(color_surface, color_border, 8))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	title_label = Label.new()
	title_label.text = "Optional Rules"
	title_label.add_theme_color_override("font_color", color_text)
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Toggle optional rules for this hero."
	subtitle_label.add_theme_color_override("font_color", color_text.darkened(0.3) if color_text.v > 0.5 else color_text.lightened(0.3))
	subtitle_label.add_theme_font_size_override("font_size", 13)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(subtitle_label)

	# GM Lock notice banner
	lock_notice_panel = PanelContainer.new()
	lock_notice_panel.visible = false
	lock_notice_panel.add_theme_stylebox_override("panel", UIBuilder.flat_style(Color(0.2, 0.15, 0.1, 0.8), Color(0.9, 0.6, 0.2), 6))
	box.add_child(lock_notice_panel)

	var lock_margin := MarginContainer.new()
	lock_margin.add_theme_constant_override("margin_left", 10)
	lock_margin.add_theme_constant_override("margin_right", 10)
	lock_margin.add_theme_constant_override("margin_top", 8)
	lock_margin.add_theme_constant_override("margin_bottom", 8)
	lock_notice_panel.add_child(lock_margin)

	lock_notice_label = Label.new()
	lock_notice_label.text = "Optional rules are locked by the Game Master for this campaign."
	lock_notice_label.add_theme_font_size_override("font_size", 12)
	lock_notice_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	lock_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lock_margin.add_child(lock_notice_label)

	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)

	var scroll_margin := MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_theme_constant_override("margin_right", 8)
	scroll.add_child(scroll_margin)

	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll_margin.add_child(body)

	actions_box = HBoxContainer.new()
	actions_box.add_theme_constant_override("separation", 10)
	actions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(actions_box)

	secondary_btn = Button.new()
	secondary_btn.text = "Cancel"
	secondary_btn.custom_minimum_size = Vector2(0, 44)
	secondary_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	secondary_btn.pressed.connect(_on_secondary_pressed)
	actions_box.add_child(secondary_btn)

	primary_btn = Button.new()
	primary_btn.text = "Continue"
	primary_btn.custom_minimum_size = Vector2(0, 44)
	primary_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	primary_btn.pressed.connect(_on_primary_pressed)
	actions_box.add_child(primary_btn)

	close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 44)
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(func(): visible = false)
	actions_box.add_child(close_btn)


func show_for_new_hero(initial_rules: Dictionary, on_confirm: Callable, on_cancel: Callable = Callable()) -> void:
	mode = Mode.NEW_HERO
	is_gm_locked = false
	on_confirm_callback = on_confirm
	on_cancel_callback = on_cancel
	on_changed_callback = Callable()
	active_character = {}

	draft_rules = initial_rules.duplicate(true)
	for rule in AlternityRules.OPTIONAL_RULES:
		var rid: String = String(rule.get("id", ""))
		if not draft_rules.has(rid):
			draft_rules[rid] = false

	title_label.text = "Configure Optional Rules"
	subtitle_label.text = "Select the optional rules to enable for your new hero before beginning character creation. (You can also change these later mid-run from the rulebook icon in the header)."
	lock_notice_panel.visible = false

	secondary_btn.visible = true
	secondary_btn.text = "Cancel"
	primary_btn.visible = true
	primary_btn.text = "Create Hero"
	close_btn.visible = false

	_rebuild_rules_list()
	visible = true


func show_for_character(target_character: Dictionary, locked: bool = false, on_changed: Callable = Callable()) -> void:
	mode = Mode.MID_RUN
	is_gm_locked = locked
	active_character = target_character
	on_changed_callback = on_changed
	on_confirm_callback = Callable()
	on_cancel_callback = Callable()

	title_label.text = "Optional Rules"
	subtitle_label.text = "Toggle optional rules for this hero. Changing these settings immediately updates all derived character stats, skill budgets, and rank costs."
	lock_notice_panel.visible = locked
	if locked:
		lock_notice_label.text = "Optional rules are locked by the Game Master for this campaign."

	secondary_btn.visible = false
	primary_btn.visible = false
	close_btn.visible = true
	close_btn.text = "Close"

	_rebuild_rules_list()
	visible = true


func show_for_campaign(session: CampaignSession, is_gm: bool, on_confirm: Callable = Callable(), on_cancel: Callable = Callable()) -> void:
	mode = Mode.NEW_CAMPAIGN
	is_gm_locked = not is_gm
	on_confirm_callback = on_confirm
	on_cancel_callback = on_cancel
	on_changed_callback = Callable()
	active_character = {}

	draft_rules = session.get_campaign_optional_rules()
	for rule in AlternityRules.OPTIONAL_RULES:
		var rid: String = String(rule.get("id", ""))
		if not draft_rules.has(rid):
			draft_rules[rid] = false

	title_label.text = "Campaign Optional Rules"
	subtitle_label.text = "Set the optional rules active for your campaign session. All players joining this campaign will inherit these rules."
	lock_notice_panel.visible = not is_gm
	if not is_gm:
		lock_notice_label.text = "Campaign optional rules can only be modified by the Game Master."

	if is_gm:
		secondary_btn.visible = true
		secondary_btn.text = "Cancel"
		primary_btn.visible = true
		primary_btn.text = "Apply Rules"
		close_btn.visible = false
	else:
		secondary_btn.visible = false
		primary_btn.visible = false
		close_btn.visible = true
		close_btn.text = "Close"

	_rebuild_rules_list()
	visible = true


func _rebuild_rules_list() -> void:
	for child in body.get_children():
		child.queue_free()

	for rule in AlternityRules.OPTIONAL_RULES:
		_add_rule_entry(rule)


func _add_rule_entry(rule: Dictionary) -> void:
	var rule_id := String(rule.get("id", ""))
	var block_margin := MarginContainer.new()
	block_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block_margin.add_theme_constant_override("margin_bottom", 6)
	body.add_child(block_margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	block_margin.add_child(box)

	var is_active := false
	if mode == Mode.MID_RUN:
		var rules_engine := (main_ui.rules as AlternityRules) if (main_ui != null and "rules" in main_ui) else null
		if rules_engine != null and not active_character.is_empty():
			is_active = rules_engine.optional_rule_enabled(active_character, rule_id)
		else:
			is_active = bool(active_character.get("optional_rules", {}).get(rule_id, false))
	else:
		is_active = bool(draft_rules.get(rule_id, false))

	var cb := CheckBox.new()
	cb.text = "%s: %s" % [rule.get("name", ""), rule.get("summary", "")]
	cb.button_pressed = is_active
	cb.disabled = is_gm_locked
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cb.add_theme_font_size_override("font_size", 14)
	cb.toggled.connect(func(pressed: bool):
		_on_rule_toggled(rule_id, pressed)
	)
	box.add_child(cb)

	var desc := Label.new()
	desc.text = String(rule.get("description", ""))
	desc.add_theme_font_size_override("font_size", 13)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(1, 0)
	if main_ui != null and "color_muted" in main_ui:
		desc.add_theme_color_override("font_color", main_ui.color_muted)
	box.add_child(desc)


func _on_rule_toggled(rule_id: String, pressed: bool) -> void:
	if mode == Mode.MID_RUN:
		if not active_character.is_empty() and main_ui != null and "rules" in main_ui:
			main_ui.rules.set_optional_rule(active_character, rule_id, pressed)
			if on_changed_callback.is_valid():
				on_changed_callback.call(rule_id, pressed)
			elif main_ui.has_method("_on_optional_rule_toggled"):
				main_ui._on_optional_rule_toggled(rule_id, pressed)
	else:
		draft_rules[rule_id] = pressed


func _on_primary_pressed() -> void:
	visible = false
	if on_confirm_callback.is_valid():
		on_confirm_callback.call(draft_rules.duplicate(true))


func _on_secondary_pressed() -> void:
	visible = false
	if on_cancel_callback.is_valid():
		on_cancel_callback.call()


func _on_dim_clicked() -> void:
	if mode == Mode.MID_RUN or is_gm_locked:
		visible = false
	elif mode == Mode.NEW_HERO:
		visible = false
		if on_cancel_callback.is_valid():
			on_cancel_callback.call()

