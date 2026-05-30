extends Control

const AlternityRules := preload("res://scripts/alternity_rules.gd")
const TABS := ["Basics", "Skills", "Perks/Flaws", "Equipment", "Cybertech", "Psionics", "Achievements", "Mutations", "Summary"]
const COMPACT_WIDTH := 520.0
const WIDE_WIDTH := 900.0
const DESKTOP_MAX_WIDTH := 1120.0

var rules: AlternityRules
var character: Dictionary = {}
var active_tab := "Basics"
var skill_filter := ""
var psionic_filter := ""
var active_character_file := ""
var deleting_files: Dictionary = {}
var close_char_button: Button
var background_rect: ColorRect


var root_margin: MarginContainer
var shell: VBoxContainer
var header: BoxContainer
var title_label: Label
var optional_rules_button: Button
var tabs: HBoxContainer
var content_scroll: ScrollContainer
var content: VBoxContainer
var status_label: Label
var save_status_label: Label
var optional_rules_overlay: Control
var optional_rules_panel: PanelContainer
var optional_rules_body: VBoxContainer
var optional_rules_scroll: ScrollContainer
var skill_details_overlay: Control
var skill_details_panel: PanelContainer
var skill_details_title: Label
var skill_details_body: VBoxContainer
var skill_details_scroll: ScrollContainer
var equipment_form_overlay: Control
var equipment_form_panel: PanelContainer
var equipment_form_title: Label
var equipment_form_body: VBoxContainer
var equipment_form_scroll: ScrollContainer
var achievement_form_overlay: Control
var achievement_form_panel: PanelContainer
var achievement_form_title: Label
var achievement_form_body: VBoxContainer
var achievement_form_scroll: ScrollContainer
var perk_flaw_catalog_overlay: Control
var perk_flaw_catalog_panel: PanelContainer
var perk_flaw_catalog_title: Label
var perk_flaw_catalog_body: VBoxContainer
var perk_flaw_catalog_scroll: ScrollContainer
var mutation_catalog_overlay: Control
var mutation_catalog_panel: PanelContainer
var mutation_catalog_title: Label
var mutation_catalog_body: VBoxContainer
var mutation_catalog_scroll: ScrollContainer
var skills_body: HBoxContainer
var sticky_skills_panel: VBoxContainer
var tab_buttons: Dictionary = {}
var is_wide_layout := false
var _tab_containers: Dictionary = {}
var _tab_dirty: Dictionary = {}
var _is_tab_changing := false
var main_content: VBoxContainer
var _tab_scroll_positions: Dictionary = {}
var notes_editing := false
var notes_draft := ""
var equipment_filter_text := ""
var equipment_filter_pl_min := 0
var equipment_filter_pl_max := 8
var equipment_filter_category := ""
var equipment_filter_class := ""
var equipment_filter_sources: Dictionary = {}
var equipment_form_state: Dictionary = {}
var achievement_filter_text := ""
var achievement_form_state: Dictionary = {}
var perk_flaw_filter_text := ""
var perk_flaw_catalog_kind := "perk"
var mutation_filter_text := ""
var mutation_catalog_kind := "advantage"
var search_refocus_target := ""
var search_refocus_caret := -1

var color_background: Color
var color_surface: Color
var color_surface_soft: Color
var color_text: Color
var color_muted: Color
var color_accent: Color
var color_warning: Color
var color_border: Color


func _ready() -> void:
	_setup_theme()
	rules = AlternityRules.new()
	rules.load_core_data()
	_build_shell()
	_apply_responsive_layout()

	# Check for last active character to autoload
	var last_char_path := "user://last_character.txt"
	var loaded := false
	if FileAccess.file_exists(last_char_path):
		var last_file := FileAccess.open(last_char_path, FileAccess.READ)
		if last_file != null:
			var last_name := last_file.get_as_text().strip_edges()
			if not last_name.is_empty():
				loaded = _load_character_from_file(last_name)

	if not loaded:
		# Boot directly to character selection menu (State 1)
		active_character_file = ""
		character = rules.default_character()
		rules.ensure_character_shape(character)

	_render()


func _load_character_from_file(file_name: String) -> bool:
	var path := "user://" + file_name
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var content_str := file.get_as_text()
	var json := JSON.new()
	var err := json.parse(content_str)
	if err != OK:
		return false
	var data_parsed = json.get_data()
	if typeof(data_parsed) == TYPE_DICTIONARY:
		character = data_parsed
		rules.ensure_character_shape(character)
		active_character_file = file_name
		return true
	return false


func _notification(what: int) -> void:
	if what != NOTIFICATION_RESIZED or shell == null:
		return

	var was_wide := is_wide_layout
	_apply_responsive_layout()
	if was_wide != is_wide_layout:
		_render()


func _build_shell() -> void:
	background_rect = ColorRect.new()
	background_rect.color = color_background
	background_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background_rect)

	root_margin = MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_margin)

	shell = VBoxContainer.new()
	shell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 10)
	root_margin.add_child(shell)

	header = HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 10)
	shell.add_child(header)

	title_label = Label.new()
	title_label.text = "Wilmer Alternity Sidekick"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.custom_minimum_size = Vector2(1, 0)
	title_label.add_theme_color_override("font_color", color_text)
	title_label.add_theme_font_size_override("font_size", 24)
	header.add_child(title_label)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", color_muted)
	status_label.add_theme_font_size_override("font_size", 13)
	header.add_child(status_label)


	theme_btn = Button.new()
	theme_btn.text = "Theme Settings"
	theme_btn.custom_minimum_size = Vector2(118, 36)
	theme_btn.add_theme_font_size_override("font_size", 12)
	theme_btn.pressed.connect(_show_theme_selector)
	header.add_child(theme_btn)

	optional_rules_button = Button.new()
	optional_rules_button.text = "Optional Rules"
	optional_rules_button.custom_minimum_size = Vector2(118, 36)
	optional_rules_button.add_theme_font_size_override("font_size", 12)
	optional_rules_button.pressed.connect(_show_optional_rules)
	header.add_child(optional_rules_button)

	close_char_button = Button.new()
	close_char_button.text = "Close Character"
	close_char_button.custom_minimum_size = Vector2(120, 36)
	close_char_button.add_theme_font_size_override("font_size", 12)
	close_char_button.pressed.connect(_close_character)
	header.add_child(close_char_button)

	var tabs_scroll := ScrollContainer.new()
	tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	tabs_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_scroll.custom_minimum_size = Vector2(0, 52)
	shell.add_child(tabs_scroll)

	tabs = HBoxContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_theme_constant_override("separation", 6)
	tabs_scroll.add_child(tabs)

	for tab in TABS:
		var button := Button.new()
		button.text = tab
		button.toggle_mode = true
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 42)
		button.add_theme_stylebox_override("normal", _tab_style(color_surface, Color(0, 0, 0, 0), 8))
		button.add_theme_stylebox_override("hover", _tab_style(color_surface_soft, Color(0, 0, 0, 0), 8))
		button.add_theme_stylebox_override("pressed", _tab_style(color_accent, Color(0, 0, 0, 0), 8))
		button.add_theme_stylebox_override("focus", _tab_style(color_surface_soft, color_accent, 8))
		button.add_theme_color_override("font_color", color_text)
		button.add_theme_color_override("font_pressed_color", color_background)
		button.pressed.connect(func(): _set_tab(tab))
		tabs.add_child(button)
		tab_buttons[tab] = button

	content_scroll = ScrollContainer.new()
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_child(content_scroll)

	var content_margin := MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_right", 12)
	content_margin.add_theme_constant_override("margin_left", 4)
	content_margin.add_theme_constant_override("margin_top", 4)
	content_margin.add_theme_constant_override("margin_bottom", 4)
	content_scroll.add_child(content_margin)

	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	content_margin.add_child(content)
	main_content = content

	_build_optional_rules_overlay()
	_build_skill_details_overlay()
	_build_equipment_form_overlay()
	_build_achievement_form_overlay()
	_build_perk_flaw_catalog_overlay()
	_build_mutation_catalog_overlay()
	_build_theme_overlay()


func _resize_modal_panel(panel: Control, available_width: float, max_width: float, height_updater: Callable) -> void:
	if panel != null:
		panel.custom_minimum_size.x = minf(available_width - 12.0, max_width)
		height_updater.call()


func _apply_responsive_layout() -> void:
	var viewport_width := get_viewport_rect().size.x
	var compact := viewport_width < COMPACT_WIDTH
	is_wide_layout = viewport_width >= WIDE_WIDTH

	var outer_margin := 8 if compact else 16
	if is_wide_layout:
		outer_margin = 24

	root_margin.add_theme_constant_override("margin_left", outer_margin)
	root_margin.add_theme_constant_override("margin_right", outer_margin)
	root_margin.add_theme_constant_override("margin_top", 10 if compact else 16)
	root_margin.add_theme_constant_override("margin_bottom", 8 if compact else 14)

	var available_width: float = maxf(280.0, viewport_width - float(outer_margin * 2))
	shell.custom_minimum_size.x = minf(available_width, DESKTOP_MAX_WIDTH)
	_update_header_layout(compact)
	if status_label != null and rules != null and not character.is_empty():
		_refresh_status()

	_resize_modal_panel(optional_rules_panel, available_width, 680.0, _update_optional_rules_modal_height)
	_resize_modal_panel(skill_details_panel, available_width, 720.0, _update_skill_details_modal_height)
	
	var equipment_form_width := 920.0 if String(equipment_form_state.get("mode", "")) == "catalog" else 760.0
	_resize_modal_panel(equipment_form_panel, available_width, equipment_form_width, _update_equipment_form_modal_height)
	
	_resize_modal_panel(achievement_form_panel, available_width, 820.0, _update_achievement_form_modal_height)
	_resize_modal_panel(perk_flaw_catalog_panel, available_width, 820.0, _update_perk_flaw_catalog_modal_height)
	_resize_modal_panel(mutation_catalog_panel, available_width, 820.0, _update_mutation_catalog_modal_height)
	_resize_modal_panel(theme_panel, available_width, 360.0, _update_theme_modal_height)


func _update_header_layout(compact: bool) -> void:
	if compact and header is HBoxContainer:
		var index := shell.get_children().find(header)
		shell.remove_child(header)
		header.queue_free()
		header = VBoxContainer.new()
		header.add_theme_constant_override("separation", 6)
		shell.add_child(header)
		shell.move_child(header, index)
		_reparent_header_children()
	elif not compact and header is VBoxContainer:
		var index := shell.get_children().find(header)
		shell.remove_child(header)
		header.queue_free()
		header = HBoxContainer.new()
		header.alignment = BoxContainer.ALIGNMENT_CENTER
		header.add_theme_constant_override("separation", 10)
		shell.add_child(header)
		shell.move_child(header, index)
		_reparent_header_children()

	title_label.add_theme_font_size_override("font_size", 22 if compact else 24)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if compact else HORIZONTAL_ALIGNMENT_RIGHT
	optional_rules_button.text = "Optional Rules"
	optional_rules_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_SHRINK_END
	optional_rules_button.custom_minimum_size = Vector2(0 if compact else 118, 38 if compact else 36)
	if theme_btn != null:
		theme_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_SHRINK_END
		theme_btn.custom_minimum_size = Vector2(0 if compact else 118, 38 if compact else 36)
	if close_char_button != null:
		close_char_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_SHRINK_END
		close_char_button.custom_minimum_size = Vector2(0 if compact else 120, 38 if compact else 36)


func _reparent_header_children() -> void:
	for node in [title_label, status_label, theme_btn, optional_rules_button, close_char_button]:
		if node != null:
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			header.add_child(node)


func _build_optional_rules_overlay() -> void:
	optional_rules_overlay = Control.new()
	optional_rules_overlay.visible = false
	optional_rules_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	optional_rules_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(optional_rules_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	optional_rules_overlay.add_child(shade)

	var overlay_margin := MarginContainer.new()
	overlay_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_margin.add_theme_constant_override("margin_left", 12)
	overlay_margin.add_theme_constant_override("margin_right", 12)
	overlay_margin.add_theme_constant_override("margin_top", 12)
	overlay_margin.add_theme_constant_override("margin_bottom", 12)
	optional_rules_overlay.add_child(overlay_margin)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_margin.add_child(center)

	optional_rules_panel = PanelContainer.new()
	optional_rules_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	optional_rules_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	optional_rules_panel.add_theme_stylebox_override("panel", _flat_style(color_surface, color_border, 8))
	center.add_child(optional_rules_panel)

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 14)
	panel_margin.add_theme_constant_override("margin_right", 14)
	panel_margin.add_theme_constant_override("margin_top", 14)
	panel_margin.add_theme_constant_override("margin_bottom", 14)
	optional_rules_panel.add_child(panel_margin)

	var panel_content := VBoxContainer.new()
	panel_content.add_theme_constant_override("separation", 10)
	panel_margin.add_child(panel_content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	panel_content.add_child(header)

	var title := Label.new()
	title.text = "Optional Rules"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", color_text)
	title.add_theme_font_size_override("font_size", 20)
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(76, 36)
	close_button.pressed.connect(func(): optional_rules_overlay.visible = false)
	header.add_child(close_button)

	optional_rules_scroll = ScrollContainer.new()
	optional_rules_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	optional_rules_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	optional_rules_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_content.add_child(optional_rules_scroll)

	optional_rules_body = VBoxContainer.new()
	optional_rules_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	optional_rules_body.add_theme_constant_override("separation", 24)
	optional_rules_scroll.add_child(optional_rules_body)


func _build_skill_details_overlay() -> void:
	skill_details_overlay = Control.new()
	skill_details_overlay.visible = false
	skill_details_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	skill_details_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(skill_details_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skill_details_overlay.add_child(shade)

	var overlay_margin := MarginContainer.new()
	overlay_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_margin.add_theme_constant_override("margin_left", 12)
	overlay_margin.add_theme_constant_override("margin_right", 12)
	overlay_margin.add_theme_constant_override("margin_top", 12)
	overlay_margin.add_theme_constant_override("margin_bottom", 12)
	skill_details_overlay.add_child(overlay_margin)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_margin.add_child(center)

	skill_details_panel = PanelContainer.new()
	skill_details_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skill_details_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skill_details_panel.add_theme_stylebox_override("panel", _flat_style(color_surface, color_border, 8))
	center.add_child(skill_details_panel)

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 14)
	panel_margin.add_theme_constant_override("margin_right", 14)
	panel_margin.add_theme_constant_override("margin_top", 14)
	panel_margin.add_theme_constant_override("margin_bottom", 14)
	skill_details_panel.add_child(panel_margin)

	var panel_content := VBoxContainer.new()
	panel_content.add_theme_constant_override("separation", 10)
	panel_margin.add_child(panel_content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	panel_content.add_child(header)

	skill_details_title = Label.new()
	skill_details_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_details_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_details_title.add_theme_color_override("font_color", color_text)
	skill_details_title.add_theme_font_size_override("font_size", 20)
	header.add_child(skill_details_title)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(76, 36)
	close_button.pressed.connect(func(): skill_details_overlay.visible = false)
	header.add_child(close_button)

	skill_details_scroll = ScrollContainer.new()
	skill_details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	skill_details_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	skill_details_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_content.add_child(skill_details_scroll)

	skill_details_body = VBoxContainer.new()
	skill_details_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_details_body.add_theme_constant_override("separation", 10)
	skill_details_scroll.add_child(skill_details_body)


func _build_equipment_form_overlay() -> void:
	equipment_form_overlay = Control.new()
	equipment_form_overlay.visible = false
	equipment_form_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	equipment_form_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(equipment_form_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	equipment_form_overlay.add_child(shade)

	var overlay_margin := MarginContainer.new()
	overlay_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_margin.add_theme_constant_override("margin_left", 12)
	overlay_margin.add_theme_constant_override("margin_right", 12)
	overlay_margin.add_theme_constant_override("margin_top", 12)
	overlay_margin.add_theme_constant_override("margin_bottom", 12)
	equipment_form_overlay.add_child(overlay_margin)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_margin.add_child(center)

	equipment_form_panel = PanelContainer.new()
	equipment_form_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	equipment_form_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	equipment_form_panel.add_theme_stylebox_override("panel", _flat_style(color_surface, color_border, 8))
	center.add_child(equipment_form_panel)

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 14)
	panel_margin.add_theme_constant_override("margin_right", 14)
	panel_margin.add_theme_constant_override("margin_top", 14)
	panel_margin.add_theme_constant_override("margin_bottom", 14)
	equipment_form_panel.add_child(panel_margin)

	var panel_content := VBoxContainer.new()
	panel_content.add_theme_constant_override("separation", 10)
	panel_margin.add_child(panel_content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	panel_content.add_child(header)

	equipment_form_title = Label.new()
	equipment_form_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_form_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipment_form_title.add_theme_color_override("font_color", color_text)
	equipment_form_title.add_theme_font_size_override("font_size", 20)
	header.add_child(equipment_form_title)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(76, 36)
	close_button.pressed.connect(func(): equipment_form_overlay.visible = false)
	header.add_child(close_button)

	equipment_form_scroll = ScrollContainer.new()
	equipment_form_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	equipment_form_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	equipment_form_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_content.add_child(equipment_form_scroll)

	var scroll_margin := MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_theme_constant_override("margin_left", 12)
	scroll_margin.add_theme_constant_override("margin_right", 12)
	equipment_form_scroll.add_child(scroll_margin)

	equipment_form_body = VBoxContainer.new()
	equipment_form_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_form_body.add_theme_constant_override("separation", 10)
	scroll_margin.add_child(equipment_form_body)


func _build_achievement_form_overlay() -> void:
	achievement_form_overlay = Control.new()
	achievement_form_overlay.visible = false
	achievement_form_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	achievement_form_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(achievement_form_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	achievement_form_overlay.add_child(shade)

	var overlay_margin := MarginContainer.new()
	overlay_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_margin.add_theme_constant_override("margin_left", 12)
	overlay_margin.add_theme_constant_override("margin_right", 12)
	overlay_margin.add_theme_constant_override("margin_top", 12)
	overlay_margin.add_theme_constant_override("margin_bottom", 12)
	achievement_form_overlay.add_child(overlay_margin)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_margin.add_child(center)

	achievement_form_panel = PanelContainer.new()
	achievement_form_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	achievement_form_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	achievement_form_panel.add_theme_stylebox_override("panel", _flat_style(color_surface, color_border, 8))
	center.add_child(achievement_form_panel)

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 14)
	panel_margin.add_theme_constant_override("margin_right", 14)
	panel_margin.add_theme_constant_override("margin_top", 14)
	panel_margin.add_theme_constant_override("margin_bottom", 14)
	achievement_form_panel.add_child(panel_margin)

	var panel_content := VBoxContainer.new()
	panel_content.add_theme_constant_override("separation", 10)
	panel_margin.add_child(panel_content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	panel_content.add_child(header)

	achievement_form_title = Label.new()
	achievement_form_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	achievement_form_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	achievement_form_title.add_theme_color_override("font_color", color_text)
	achievement_form_title.add_theme_font_size_override("font_size", 20)
	header.add_child(achievement_form_title)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(76, 36)
	close_button.pressed.connect(func(): achievement_form_overlay.visible = false)
	header.add_child(close_button)

	achievement_form_scroll = ScrollContainer.new()
	achievement_form_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	achievement_form_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	achievement_form_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_content.add_child(achievement_form_scroll)

	var scroll_margin := MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_theme_constant_override("margin_left", 12)
	scroll_margin.add_theme_constant_override("margin_right", 12)
	achievement_form_scroll.add_child(scroll_margin)

	achievement_form_body = VBoxContainer.new()
	achievement_form_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	achievement_form_body.add_theme_constant_override("separation", 10)
	scroll_margin.add_child(achievement_form_body)


func _build_perk_flaw_catalog_overlay() -> void:
	perk_flaw_catalog_overlay = Control.new()
	perk_flaw_catalog_overlay.visible = false
	perk_flaw_catalog_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	perk_flaw_catalog_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(perk_flaw_catalog_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	perk_flaw_catalog_overlay.add_child(shade)

	var overlay_margin := MarginContainer.new()
	overlay_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_margin.add_theme_constant_override("margin_left", 12)
	overlay_margin.add_theme_constant_override("margin_right", 12)
	overlay_margin.add_theme_constant_override("margin_top", 12)
	overlay_margin.add_theme_constant_override("margin_bottom", 12)
	perk_flaw_catalog_overlay.add_child(overlay_margin)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_margin.add_child(center)

	perk_flaw_catalog_panel = PanelContainer.new()
	perk_flaw_catalog_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	perk_flaw_catalog_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	perk_flaw_catalog_panel.add_theme_stylebox_override("panel", _flat_style(color_surface, color_border, 8))
	center.add_child(perk_flaw_catalog_panel)

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 14)
	panel_margin.add_theme_constant_override("margin_right", 14)
	panel_margin.add_theme_constant_override("margin_top", 14)
	panel_margin.add_theme_constant_override("margin_bottom", 14)
	perk_flaw_catalog_panel.add_child(panel_margin)

	var panel_content := VBoxContainer.new()
	panel_content.add_theme_constant_override("separation", 10)
	panel_margin.add_child(panel_content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	panel_content.add_child(header)

	perk_flaw_catalog_title = Label.new()
	perk_flaw_catalog_title.text = "Add Perk / Flaw"
	perk_flaw_catalog_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	perk_flaw_catalog_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	perk_flaw_catalog_title.add_theme_color_override("font_color", color_text)
	perk_flaw_catalog_title.add_theme_font_size_override("font_size", 20)
	header.add_child(perk_flaw_catalog_title)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(76, 36)
	close_button.pressed.connect(func(): perk_flaw_catalog_overlay.visible = false)
	header.add_child(close_button)

	perk_flaw_catalog_scroll = ScrollContainer.new()
	perk_flaw_catalog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	perk_flaw_catalog_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	perk_flaw_catalog_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_content.add_child(perk_flaw_catalog_scroll)

	var scroll_margin := MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_theme_constant_override("margin_left", 12)
	scroll_margin.add_theme_constant_override("margin_right", 12)
	perk_flaw_catalog_scroll.add_child(scroll_margin)

	perk_flaw_catalog_body = VBoxContainer.new()
	perk_flaw_catalog_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	perk_flaw_catalog_body.add_theme_constant_override("separation", 10)
	scroll_margin.add_child(perk_flaw_catalog_body)


func _build_mutation_catalog_overlay() -> void:
	mutation_catalog_overlay = Control.new()
	mutation_catalog_overlay.visible = false
	mutation_catalog_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	mutation_catalog_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(mutation_catalog_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mutation_catalog_overlay.add_child(shade)

	var overlay_margin := MarginContainer.new()
	overlay_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_margin.add_theme_constant_override("margin_left", 12)
	overlay_margin.add_theme_constant_override("margin_right", 12)
	overlay_margin.add_theme_constant_override("margin_top", 12)
	overlay_margin.add_theme_constant_override("margin_bottom", 12)
	mutation_catalog_overlay.add_child(overlay_margin)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_margin.add_child(center)

	mutation_catalog_panel = PanelContainer.new()
	mutation_catalog_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mutation_catalog_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mutation_catalog_panel.add_theme_stylebox_override("panel", _flat_style(color_surface, color_border, 8))
	center.add_child(mutation_catalog_panel)

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 14)
	panel_margin.add_theme_constant_override("margin_right", 14)
	panel_margin.add_theme_constant_override("margin_top", 14)
	panel_margin.add_theme_constant_override("margin_bottom", 14)
	mutation_catalog_panel.add_child(panel_margin)

	var panel_content := VBoxContainer.new()
	panel_content.add_theme_constant_override("separation", 10)
	panel_margin.add_child(panel_content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	panel_content.add_child(header)

	mutation_catalog_title = Label.new()
	mutation_catalog_title.text = "Add Mutation"
	mutation_catalog_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mutation_catalog_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mutation_catalog_title.add_theme_color_override("font_color", color_text)
	mutation_catalog_title.add_theme_font_size_override("font_size", 20)
	header.add_child(mutation_catalog_title)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(76, 36)
	close_button.pressed.connect(func(): mutation_catalog_overlay.visible = false)
	header.add_child(close_button)

	mutation_catalog_scroll = ScrollContainer.new()
	mutation_catalog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mutation_catalog_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mutation_catalog_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_content.add_child(mutation_catalog_scroll)

	var scroll_margin := MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_theme_constant_override("margin_left", 12)
	scroll_margin.add_theme_constant_override("margin_right", 12)
	mutation_catalog_scroll.add_child(scroll_margin)

	mutation_catalog_body = VBoxContainer.new()
	mutation_catalog_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mutation_catalog_body.add_theme_constant_override("separation", 10)
	scroll_margin.add_child(mutation_catalog_body)


func _build_theme_overlay() -> void:
	theme_overlay = Control.new()
	theme_overlay.visible = false
	theme_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	theme_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(theme_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme_overlay.add_child(shade)

	var overlay_margin := MarginContainer.new()
	overlay_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_margin.add_theme_constant_override("margin_left", 12)
	overlay_margin.add_theme_constant_override("margin_right", 12)
	overlay_margin.add_theme_constant_override("margin_top", 12)
	overlay_margin.add_theme_constant_override("margin_bottom", 12)
	theme_overlay.add_child(overlay_margin)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_margin.add_child(center)

	theme_panel = PanelContainer.new()
	theme_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	theme_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	theme_panel.add_theme_stylebox_override("panel", _flat_style(color_surface, color_border, 8))
	center.add_child(theme_panel)

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 14)
	panel_margin.add_theme_constant_override("margin_right", 14)
	panel_margin.add_theme_constant_override("margin_top", 14)
	panel_margin.add_theme_constant_override("margin_bottom", 14)
	theme_panel.add_child(panel_margin)

	var panel_content := VBoxContainer.new()
	panel_content.add_theme_constant_override("separation", 12)
	panel_margin.add_child(panel_content)

	var header_box := HBoxContainer.new()
	header_box.add_theme_constant_override("separation", 8)
	panel_content.add_child(header_box)

	var title := Label.new()
	title.text = "Theme Settings"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", color_text)
	title.add_theme_font_size_override("font_size", 20)
	header_box.add_child(title)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(76, 36)
	close_button.pressed.connect(func(): theme_overlay.visible = false)
	header_box.add_child(close_button)

	theme_body = VBoxContainer.new()
	theme_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	theme_body.add_theme_constant_override("separation", 8)
	panel_content.add_child(theme_body)


func _update_theme_modal_height() -> void:
	pass


func _refresh_theme_panel() -> void:
	if theme_body == null or not has_node("/root/ThemeManager"):
		return
	for child in theme_body.get_children():
		child.queue_free()

	var tm = get_node("/root/ThemeManager")
	for index in range(tm.theme_names.size()):
		var name = tm.theme_names[index]
		var is_selected = index == tm.current_theme_index

		var btn := Button.new()
		btn.text = name
		btn.custom_minimum_size = Vector2(0, 42)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		if is_selected:
			btn.add_theme_stylebox_override("normal", _flat_style(color_accent, Color(0, 0, 0, 0), 6))
			btn.add_theme_stylebox_override("hover", _flat_style(color_accent.lightened(0.1), Color(0, 0, 0, 0), 6))
			btn.add_theme_stylebox_override("pressed", _flat_style(color_accent.darkened(0.1), Color(0, 0, 0, 0), 6))
			btn.add_theme_color_override("font_color", color_background)
			btn.add_theme_color_override("font_hover_color", color_background)
			btn.add_theme_color_override("font_pressed_color", color_background)
		else:
			btn.add_theme_stylebox_override("normal", _flat_style(color_surface_soft, Color(0, 0, 0, 0), 6))
			btn.add_theme_stylebox_override("hover", _flat_style(color_surface_soft.lightened(0.1), Color(0, 0, 0, 0), 6))
			btn.add_theme_stylebox_override("pressed", _flat_style(color_surface_soft.darkened(0.1), Color(0, 0, 0, 0), 6))
			btn.add_theme_color_override("font_color", color_text)
			btn.add_theme_color_override("font_hover_color", color_text.lightened(0.1))
			btn.add_theme_color_override("font_pressed_color", color_text)

		btn.pressed.connect(func():
			tm.set_theme(index)
		)
		theme_body.add_child(btn)


func _show_optional_rules() -> void:
	_refresh_optional_rules_panel()
	optional_rules_overlay.visible = true
	_update_optional_rules_modal_height.call_deferred()


func _refresh_optional_rules_panel() -> void:
	for child in optional_rules_body.get_children():
		child.queue_free()

	for rule in AlternityRules.OPTIONAL_RULES:
		_add_optional_rule_row(rule)
	_update_optional_rules_modal_height.call_deferred()


func _update_optional_rules_modal_height() -> void:
	if optional_rules_scroll == null:
		return

	var viewport_size := get_viewport_rect().size
	var max_scroll_height := maxf(220.0, viewport_size.y - 170.0)
	var content_height := optional_rules_body.get_combined_minimum_size().y
	var needs_scroll := content_height > max_scroll_height
	optional_rules_scroll.custom_minimum_size.y = max_scroll_height if needs_scroll else content_height
	optional_rules_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if needs_scroll else ScrollContainer.SCROLL_MODE_DISABLED


func _show_skill_details(skill_id: int) -> void:
	var skill := rules.get_skill_by_id(skill_id)
	if skill.is_empty():
		return
	_refresh_skill_details_panel(skill)
	skill_details_overlay.visible = true
	_update_skill_details_modal_height.call_deferred()


func _refresh_skill_details_panel(skill: Dictionary) -> void:
	for child in skill_details_body.get_children():
		child.queue_free()

	var detail := rules.skill_detail(skill, character)
	skill_details_title.text = String(detail.get("name", "Skill"))

	var meta := "%s  |  %s (%s)  |  Base price %d" % [
		detail.get("type_label", "Skill"),
		detail.get("ability_name", ""),
		detail.get("ability", ""),
		rules._as_int(detail.get("base_price", 0)),
	]
	_add_text(skill_details_body, meta, 13, color_muted)

	var rank := rules._as_int(detail.get("rank", 0))
	if skill.get("type", "") == "specialty":
		var next_cost := rules._as_int(detail.get("next_cost", 0))
		var rank_line := "Current rank %d / %d" % [rank, rules._as_int(detail.get("max_rank", AlternityRules.MAX_SPECIALTY_RANK))]
		if rank < AlternityRules.MAX_SPECIALTY_RANK:
			rank_line += "  |  Next rank %d SP" % next_cost
		else:
			rank_line += "  |  Maximum rank"
		_add_text(skill_details_body, rank_line, 13, color_accent)
	else:
		_add_text(skill_details_body, "Cost %d SP%s" % [
			rules._as_int(detail.get("rank_one_cost", 0)),
			"  |  Species free skill" if detail.get("rank_one_cost", 0) == 0 and rules.is_free_species_skill(character, rules._as_int(skill.get("id", -1))) else "",
		], 13, color_accent)

	_add_subheading(skill_details_body, "Use")
	_add_text(skill_details_body, String(detail.get("summary", "")), 14, color_text)

	_add_subheading(skill_details_body, "Roll Notes")
	for note in detail.get("roll_notes", []):
		_add_text(skill_details_body, String(note), 13, color_muted)

	var complex_note := String(detail.get("complex_check", ""))
	if not complex_note.is_empty():
		_add_subheading(skill_details_body, "Complex Check")
		_add_text(skill_details_body, complex_note, 13, color_text)
		_add_text(skill_details_body, AlternityRules.COMPLEX_CHECK_RULES["successes"], 13, color_muted)
		_add_text(skill_details_body, AlternityRules.COMPLEX_CHECK_RULES["failures"], 13, color_muted)
		_add_text(skill_details_body, AlternityRules.COMPLEX_CHECK_RULES["complexity"], 13, color_muted)

	var rank_benefits: Dictionary = detail.get("rank_benefits", {})
	if not rank_benefits.is_empty():
		_add_subheading(skill_details_body, "Rank Benefits")
		var thresholds := rank_benefits.keys()
		thresholds.sort()
		for threshold in thresholds:
			var required_rank := rules._as_int(threshold)
			var color := color_accent if rank >= required_rank else color_muted
			_add_text(skill_details_body, "Rank %d: %s" % [required_rank, String(rank_benefits[threshold])], 13, color)

	_add_subheading(skill_details_body, "Sources")
	var sources := []
	for source in detail.get("sources", []):
		sources.append(String(source))
	_add_text(skill_details_body, ", ".join(sources), 12, color_muted)
	_update_skill_details_modal_height.call_deferred()


func _update_skill_details_modal_height() -> void:
	if skill_details_scroll == null:
		return

	var viewport_size := get_viewport_rect().size
	var max_scroll_height := maxf(240.0, viewport_size.y - 170.0)
	var content_height := skill_details_body.get_combined_minimum_size().y
	var needs_scroll := content_height > max_scroll_height
	skill_details_scroll.custom_minimum_size.y = max_scroll_height if needs_scroll else content_height
	skill_details_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if needs_scroll else ScrollContainer.SCROLL_MODE_DISABLED


func _update_equipment_form_modal_height() -> void:
	if equipment_form_scroll == null:
		return

	var viewport_size := get_viewport_rect().size
	var max_scroll_height := maxf(260.0, viewport_size.y - 170.0)
	var content_height := equipment_form_body.get_combined_minimum_size().y
	var needs_scroll := content_height > max_scroll_height
	equipment_form_scroll.custom_minimum_size.y = max_scroll_height if needs_scroll else content_height
	equipment_form_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if needs_scroll else ScrollContainer.SCROLL_MODE_DISABLED


func _update_achievement_form_modal_height() -> void:
	if achievement_form_scroll == null:
		return

	var viewport_size := get_viewport_rect().size
	var max_scroll_height := maxf(260.0, viewport_size.y - 170.0)
	var content_height := achievement_form_body.get_combined_minimum_size().y
	var needs_scroll := content_height > max_scroll_height
	achievement_form_scroll.custom_minimum_size.y = max_scroll_height if needs_scroll else content_height
	achievement_form_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if needs_scroll else ScrollContainer.SCROLL_MODE_DISABLED


func _update_perk_flaw_catalog_modal_height() -> void:
	if perk_flaw_catalog_scroll == null:
		return

	var viewport_size := get_viewport_rect().size
	var max_scroll_height := maxf(260.0, viewport_size.y - 170.0)
	var content_height := perk_flaw_catalog_body.get_combined_minimum_size().y
	var needs_scroll := content_height > max_scroll_height
	perk_flaw_catalog_scroll.custom_minimum_size.y = max_scroll_height if needs_scroll else content_height
	perk_flaw_catalog_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if needs_scroll else ScrollContainer.SCROLL_MODE_DISABLED


func _update_mutation_catalog_modal_height() -> void:
	if mutation_catalog_scroll == null:
		return

	var viewport_size := get_viewport_rect().size
	var max_scroll_height := maxf(260.0, viewport_size.y - 170.0)
	var content_height := mutation_catalog_body.get_combined_minimum_size().y
	var needs_scroll := content_height > max_scroll_height
	mutation_catalog_scroll.custom_minimum_size.y = max_scroll_height if needs_scroll else content_height
	mutation_catalog_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if needs_scroll else ScrollContainer.SCROLL_MODE_DISABLED


func _add_optional_rule_row(rule: Dictionary) -> void:
	var block_margin := MarginContainer.new()
	block_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block_margin.add_theme_constant_override("margin_bottom", 6)
	optional_rules_body.add_child(block_margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	block_margin.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_theme_constant_override("separation", 6)
	box.add_child(title_row)

	var toggle := CheckBox.new()
	var rule_id := String(rule.get("id", ""))
	toggle.button_pressed = rules.optional_rule_enabled(character, rule_id)
	toggle.custom_minimum_size = Vector2(24, 32)
	toggle.toggled.connect(func(pressed):
		rules.set_optional_rule(character, rule_id, pressed)
		if not active_character_file.is_empty():
			_save_character()
		_render()
		_refresh_optional_rules_panel()
	)
	title_row.add_child(toggle)

	var title := Label.new()
	title.text = "%s: %s" % [rule.get("name", ""), rule.get("summary", "")]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", color_text)
	title.add_theme_font_size_override("font_size", 15)
	title_row.add_child(title)

	_add_text(box, String(rule.get("description", "")), 13, color_muted)


func _visible_tab_count() -> int:
	var count := 0
	for tab in TABS:
		if _tab_visible(tab):
			count += 1
	return max(1, count)


func _tab_visible(tab: String) -> bool:
	if tab == "Mutations":
		return rules != null and rules.mutations.mutations_enabled(character)
	return true


func _refresh_tab_visibility() -> void:
	for tab in tab_buttons.keys():
		var button: Button = tab_buttons[tab]
		button.visible = _tab_visible(String(tab))


func _set_tab(tab: String) -> void:
	if not _tab_visible(tab):
		return
	if not active_character_file.is_empty():
		_save_character()
	if not active_tab.is_empty() and content_scroll != null:
		_tab_scroll_positions[active_tab] = content_scroll.scroll_vertical
	active_tab = tab
	_is_tab_changing = true
	_render()
	_is_tab_changing = false


func _clear_tab_cache() -> void:
	for tab in _tab_containers.keys():
		var container = _tab_containers[tab]
		if is_instance_valid(container):
			container.queue_free()
	_tab_containers.clear()
	_tab_dirty.clear()
	_tab_scroll_positions.clear()


func _mark_tabs_dirty() -> void:
	for tab in tab_buttons.keys():
		_tab_dirty[tab] = true


func _render() -> void:
	if content_scroll != null and not _is_tab_changing and not active_tab.is_empty():
		_tab_scroll_positions[active_tab] = content_scroll.scroll_vertical

	# State 1: Standalone Character Select (no active character)
	if active_character_file.is_empty():
		content = main_content
		_clear_tab_cache()
		if tabs != null and tabs.get_parent() != null:
			tabs.get_parent().visible = false
		if close_char_button != null:
			close_char_button.visible = false
		_set_sticky_skills_layout(false)

		# Clear content containers
		for child in content.get_children():
			child.queue_free()
		if sticky_skills_panel != null:
			for child in sticky_skills_panel.get_children():
				child.queue_free()

		_render_character_select()
		_refresh_status()
		return

	# State 2: Character Sheet Editor (active character loaded)
	if tabs != null and tabs.get_parent() != null:
		tabs.get_parent().visible = true
	if close_char_button != null:
		close_char_button.visible = true

	# Clear any non-tab children in main_content (e.g., character select elements)
	for child in main_content.get_children():
		if not child in _tab_containers.values():
			child.queue_free()

	rules.ensure_character_shape(character)
	if not _tab_visible(active_tab):
		active_tab = "Basics"
	_refresh_tab_visibility()
	_set_sticky_skills_layout(active_tab == "Skills" and is_wide_layout)
	for tab in tab_buttons.keys():
		tab_buttons[tab].button_pressed = tab == active_tab

	# Invalidate caches if this is not a tab switch
	if not _is_tab_changing:
		rules.clear_cache()
		_mark_tabs_dirty()

	# Ensure the active tab container exists
	if not _tab_containers.has(active_tab) or not is_instance_valid(_tab_containers[active_tab]):
		var tab_container := VBoxContainer.new()
		tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tab_container.add_theme_constant_override("separation", 10)
		_tab_containers[active_tab] = tab_container
		main_content.add_child(tab_container)
		_tab_dirty[active_tab] = true

	# Set the active tab container as current content target
	content = _tab_containers[active_tab]

	# Set visibility of all tab containers
	for tab in _tab_containers.keys():
		if is_instance_valid(_tab_containers[tab]):
			_tab_containers[tab].visible = (tab == active_tab)

	# Only rebuild the active tab container if it is dirty
	if _tab_dirty.get(active_tab, true):
		for child in content.get_children():
			child.queue_free()
		if sticky_skills_panel != null:
			for child in sticky_skills_panel.get_children():
				child.queue_free()

		match active_tab:
			"Basics":
				_render_basics()
			"Skills":
				_render_skills()
			"Perks/Flaws":
				_render_perks_flaws()
			"Equipment":
				_render_equipment()
			"Cybertech":
				_render_cybertech()
			"Psionics":
				_render_fx_psionics()
			"Achievements":
				_render_achievements()
			"Mutations":
				_render_mutations()
			"Summary":
				_render_summary()

		_tab_dirty[active_tab] = false

	_refresh_status()
	_restore_scroll_position.call_deferred()


func _restore_scroll_position() -> void:
	if content_scroll != null:
		content_scroll.scroll_vertical = _tab_scroll_positions.get(active_tab, 0)


func _set_sticky_skills_layout(enabled: bool) -> void:
	if enabled and skills_body == null:
		var scroll_index := shell.get_children().find(content_scroll)
		shell.remove_child(content_scroll)

		skills_body = HBoxContainer.new()
		skills_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skills_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		skills_body.add_theme_constant_override("separation", 12)
		shell.add_child(skills_body)
		shell.move_child(skills_body, scroll_index)

		content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content_scroll.size_flags_stretch_ratio = 0.64
		skills_body.add_child(content_scroll)

		sticky_skills_panel = VBoxContainer.new()
		sticky_skills_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sticky_skills_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sticky_skills_panel.size_flags_stretch_ratio = 0.36
		sticky_skills_panel.add_theme_constant_override("separation", 10)
		skills_body.add_child(sticky_skills_panel)
	elif not enabled and skills_body != null:
		var body_index := shell.get_children().find(skills_body)
		skills_body.remove_child(content_scroll)
		shell.add_child(content_scroll)
		shell.move_child(content_scroll, body_index)
		content_scroll.size_flags_stretch_ratio = 1.0
		sticky_skills_panel = null
		skills_body.queue_free()
		skills_body = null


func _refresh_status() -> void:
	var summary := rules.summary(character)
	var hero_name := String(character.get("hero_name", "New Hero")).strip_edges()
	if hero_name.is_empty():
		hero_name = "New Hero"
	var level := rules._as_int(summary.get("achievement_level", 1))
	var skill_remaining := rules._as_int(summary.get("skill_points_remaining", 0))
	var skill_budget := rules._as_int(summary.get("skill_budget", 0))
	var skill_text := "SP %d/%d" % [skill_remaining, skill_budget]

	if get_viewport_rect().size.x < COMPACT_WIDTH:
		status_label.text = "%s | Lv %d | %s" % [hero_name, level, skill_text]
	else:
		var species := rules.get_species_by_id(rules._as_int(character.get("species_id", 0)))
		var profession := rules.get_profession_by_id(rules._as_int(character.get("profession_id", 0)))
		var last_resorts: Dictionary = summary.get("last_resorts", {})
		status_label.text = "%s | %s %s | Lv %d | %s | LR %d/%d" % [
			hero_name,
			String(species.get("name", "")),
			String(profession.get("name", "")),
			level,
			skill_text,
			rules._as_int(last_resorts.get("available", 0)),
			rules._as_int(last_resorts.get("max", 0)),
		]
	status_label.add_theme_color_override("font_color", color_warning if skill_remaining < 0 else color_muted)


func _achievement_level_label(points: int) -> String:
	return "Hero Level %d" % rules.achievements.achievement_level_for_points(points)


func _achievement_next_level_label(points: int) -> String:
	return "Next level at %d achievement points" % rules.achievements.achievement_next_level_points(points)


func _achievement_usage_text(summary: Dictionary) -> String:
	return "Used AP: %d    Available AP: %d" % [
		rules._as_int(summary.get("achievement_points_used", 0)),
		rules._as_int(summary.get("achievement_points_available", 0)),
	]


func _render_basics() -> void:
	var basics_parent: Container = content
	var rules_parent: Container = content
	if is_wide_layout:
		var columns := _add_columns()
		basics_parent = columns[0]
		rules_parent = columns[1]

	var basics := _add_section_to(basics_parent, "Basics")
	_add_line_edit(basics, "Hero", String(character.get("hero_name", "")), func(value): character["hero_name"] = value; _refresh_status())
	_add_line_edit(basics, "Player", String(character.get("player_name", "")), func(value): character["player_name"] = value)
	_add_line_edit(basics, "Career", String(character.get("career", "")), func(value): character["career"] = value)

	var achievement_points := rules._as_int(character.get("achievement_points", 0))
	var level_label := _add_text(basics, _achievement_level_label(achievement_points), 15, color_text)
	var next_level_label := _add_text(basics, _achievement_next_level_label(achievement_points), 12, color_muted)
	var achievement_hbox := HBoxContainer.new()
	achievement_hbox.add_theme_constant_override("separation", 12)
	basics.add_child(achievement_hbox)
	var achievement_input := _add_number_input(achievement_hbox, "Achievement Points", achievement_points, 0, 9999, func(value):
		rules.achievements.set_achievement_points(character, value)
		level_label.text = _achievement_level_label(value)
		next_level_label.text = _achievement_next_level_label(value)
		_refresh_status()
	)
	achievement_input.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	achievement_input.custom_minimum_size = Vector2(120, 42)
	var achievement_summary := rules.summary(character)
	var achievement_usage_label := _add_text(
		basics,
		_achievement_usage_text(achievement_summary),
		13,
		color_text
	)
	achievement_input.text_changed.connect(func(_text):
		achievement_usage_label.text = _achievement_usage_text(rules.summary(character))
	)

	var setting := OptionButton.new()
	setting.add_item("Core", 0)
	setting.add_item("Star*Drive", 1)
	setting.add_item("Dark*Matter", 2)
	setting.select(0)
	setting.set_item_disabled(1, true)
	setting.set_item_disabled(2, true)
	_add_field(basics, "Setting", setting)

	var species_option := OptionButton.new()
	for index in range(rules.species.size()):
		var item: Dictionary = rules.species[index]
		species_option.add_item(String(item.get("name", "")), rules._as_int(item.get("id", 0)))
		if rules._as_int(item.get("id", 0)) == rules._as_int(character.get("species_id", 0)):
			species_option.select(index)
	species_option.item_selected.connect(func(index):
		character["species_id"] = species_option.get_item_id(index)
		rules.clamp_abilities_to_species(character)
		rules.clamp_trackers(character)
		_render()
	)
	_add_field(basics, "Species", species_option)

	var profession_option := OptionButton.new()
	for index in range(AlternityRules.PROFESSION_DEFINITIONS.size()):
		var profession: Dictionary = AlternityRules.PROFESSION_DEFINITIONS[index]
		profession_option.add_item(String(profession.get("name", "")), rules._as_int(profession.get("id", 0)))
		if rules._as_int(profession.get("id", 0)) == rules._as_int(character.get("profession_id", 0)):
			profession_option.select(index)
	profession_option.item_selected.connect(func(index):
		character["profession_id"] = profession_option.get_item_id(index)
		rules.clamp_abilities_to_species(character)
		rules.clamp_trackers(character)
		_render()
	)
	_add_field(basics, "Profession", profession_option)

	_render_abilities_to(basics_parent)

	var species_box := _add_section_to(rules_parent, "Species Rules")
	var free_broad_skill_names := []
	for skill_id in rules.get_free_skill_ids(character):
		var skill_name := rules.skill_name_for_id(skill_id)
		if not skill_name.is_empty():
			free_broad_skill_names.append(skill_name)
	_add_text(species_box, "Free broad skills: %s" % ", ".join(free_broad_skill_names), 14, color_text)
	_add_text(species_box, "Species ability limits, free broad skills, and starting skill differences use Player's Handbook Tables P3-P5, p. 33-34. Profession minimums use Table P1 p. 30.", 12, color_muted)
	var free_specialty_skill_names := []
	for skill_id in rules.get_free_specialty_skill_ids(character):
		var skill_name := rules.skill_name_for_id(skill_id)
		if not skill_name.is_empty():
			free_specialty_skill_names.append(skill_name)
	if not free_specialty_skill_names.is_empty():
		_add_text(species_box, "Free specialty ranks: %s" % ", ".join(free_specialty_skill_names), 14, color_text)
	for note in rules.species_rule_notes(character):
		_add_text(species_box, String(note), 13, color_muted)

	var profession_box := _add_section_to(rules_parent, "Profession Rules")
	var profession := rules.get_profession_by_id(rules._as_int(character.get("profession_id", 0)))
	for note in profession.get("notes", []):
		_add_text(profession_box, String(note), 13, color_muted)


func _render_abilities() -> void:
	_render_abilities_to(content)


func _render_abilities_to(parent: Container) -> void:
	var summary := rules.summary(character)
	var box := _add_section_to(parent, "Abilities")
	var ability_state := "Cost %d / %d" % [summary["ability_total"], summary["ability_target"]]
	_add_text(box, ability_state, 18, color_warning if summary["ability_total"] != summary["ability_target"] else color_accent)

	var ability_parent: Container = box
	if is_wide_layout:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 8)
		box.add_child(grid)
		ability_parent = grid

	for ability in AlternityRules.ABILITIES:
		_add_ability_row(ability_parent, ability)


func _add_ability_row(parent: Container, ability: String) -> void:
	var abilities: Dictionary = character.get("abilities", {})
	var score := rules._as_int(abilities.get(ability, 10))
	var achievement_score := rules._as_int(rules.achievement_adjusted_abilities(character).get(ability, score))
	var effective_score := rules._as_int(rules.effective_abilities(character).get(ability, score))
	var effective_limits := rules.effective_ability_limits(character, ability)
	var adjustment := effective_score - score

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 52)
	parent.add_child(row)

	var label_box := VBoxContainer.new()
	label_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_box.add_theme_constant_override("separation", 0)
	row.add_child(label_box)

	var title := Label.new()
	title.text = "%s  %s" % [ability, AlternityRules.ABILITY_NAMES.get(ability, ability)]
	title.add_theme_color_override("font_color", color_text)
	title.add_theme_font_size_override("font_size", 15)
	label_box.add_child(title)

	var detail := Label.new()
	var adjustment_note := ""
	if adjustment != 0:
		var mutation_adjustment := effective_score - achievement_score
		var parts := []
		if achievement_score != score:
			parts.append("achievement %+d" % (achievement_score - score))
		if mutation_adjustment != 0:
			parts.append("mutation %+d" % mutation_adjustment)
		adjustment_note = "   Purchased %d (%s)" % [score, ", ".join(parts)]
	detail.text = "Range %d-%d   Untrained %d   RM %+d%s" % [
		rules._as_int(effective_limits[0]),
		rules._as_int(effective_limits[1]),
		rules.untrained_score(effective_score),
		rules.resistance_modifier(effective_score),
		adjustment_note,
	]
	detail.add_theme_color_override("font_color", color_muted)
	detail.add_theme_font_size_override("font_size", 12)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_box.add_child(detail)

	var minus := Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(42, 42)
	minus.pressed.connect(func(): _change_ability(ability, -1))
	row.add_child(minus)

	var value := Label.new()
	value.text = str(effective_score)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.custom_minimum_size = Vector2(38, 42)
	value.add_theme_font_size_override("font_size", 22)
	value.add_theme_color_override("font_color", color_text)
	row.add_child(value)

	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(42, 42)
	plus.pressed.connect(func(): _change_ability(ability, 1))
	row.add_child(plus)


func _change_ability(ability: String, delta: int) -> void:
	var abilities: Dictionary = character.get("abilities", {})
	var limits := rules.ability_limits(character, ability)
	abilities[ability] = clampi(rules._as_int(abilities.get(ability, 10)) + delta, rules._as_int(limits[0]), rules._as_int(limits[1]))
	character["abilities"] = abilities
	rules.clamp_trackers(character)
	_render()


func _render_skills() -> void:
	var summary := rules.summary(character)
	if is_wide_layout and sticky_skills_panel != null:
		var picker_box := _add_section("Skill Budget")
		_render_skill_picker(picker_box, summary, false)
		_render_selected_skill_panel(sticky_skills_panel)
		return

	var box := _add_section("Skill Budget")
	_render_skill_picker(box, summary, false)


func _render_perks_flaws() -> void:
	var summary := rules.summary(character)
	var overview := _add_section("Perks / Flaws Budget")
	_add_metric(overview, "Perks Selected", "%d / 3" % rules._as_int(summary.get("perk_count", 0)))
	_add_metric(overview, "Flaws Selected", "%d / 3" % rules._as_int(summary.get("flaw_count", 0)))
	_add_metric(overview, "Perk Skill Point Cost", "%d SP" % rules._as_int(summary.get("perk_points_used", 0)))
	_add_metric(overview, "Flaw Skill Point Bonus", "+%d SP" % rules._as_int(summary.get("flaw_skill_points_bonus", 0)))
	_add_metric(overview, "Skill Points Used/Available", "%d/%d" % [
		rules._as_int(summary.get("skill_points_used", 0)),
		rules._as_int(summary.get("skill_points_remaining", 0)),
	])
	_add_text(overview, "At character creation, perks cost skill points and flaws add skill points. A starting hero can choose up to three perks and up to three flaws. Source: Player's Handbook p. 103 and p. 107.", 12, color_muted)

	var action_row: BoxContainer
	if get_viewport_rect().size.x < COMPACT_WIDTH:
		action_row = VBoxContainer.new()
	else:
		action_row = HBoxContainer.new()
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_theme_constant_override("separation", 8)
	overview.add_child(action_row)

	var add_perk := Button.new()
	add_perk.text = "Add Perk"
	add_perk.custom_minimum_size = Vector2(0, 42)
	add_perk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_perk.pressed.connect(_show_perk_catalog_modal)
	action_row.add_child(add_perk)

	var add_flaw := Button.new()
	add_flaw.text = "Add Flaw"
	add_flaw.custom_minimum_size = Vector2(0, 42)
	add_flaw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_flaw.pressed.connect(_show_flaw_catalog_modal)
	action_row.add_child(add_flaw)

	var perks_parent: Container = content
	var flaws_parent: Container = content
	if is_wide_layout:
		var columns := _add_columns()
		perks_parent = columns[0]
		flaws_parent = columns[1]

	_render_selected_perks(perks_parent)
	_render_selected_flaws(flaws_parent)


func _render_selected_perks(parent: Container) -> void:
	var box := _add_section_to(parent, "Selected Perks")
	var perks := rules.selected_perks(character)
	if perks.is_empty():
		_add_text(box, "No perks selected.", 14, color_muted)
		return

	for index in range(perks.size()):
		var perk: Dictionary = perks[index]
		_add_selected_perk_row(box, perk, index < perks.size() - 1)


func _add_granted_perk_row(parent: VBoxContainer, option: Dictionary) -> void:
	var row_box := VBoxContainer.new()
	row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_box.add_theme_constant_override("separation", 6)
	parent.add_child(row_box)

	_add_text(row_box, "%s  Granted by achievement" % String(option.get("name", "")), 15, color_accent)
	_add_text(row_box, String(option.get("summary", "")), 13, color_text)
	_add_text(row_box, "Source: %s" % String(option.get("source", "")), 11, color_muted)

	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", Color(color_border.r, color_border.g, color_border.b, 0.7))
	row_box.add_child(separator)


func _render_selected_flaws(parent: Container) -> void:
	var box := _add_section_to(parent, "Selected Flaws")
	var flaws := rules.selected_flaws(character)
	if flaws.is_empty():
		_add_text(box, "No flaws selected.", 14, color_muted)
		return

	for index in range(flaws.size()):
		var flaw: Dictionary = flaws[index]
		_add_selected_flaw_row(box, flaw, index < flaws.size() - 1)


func _add_selected_perk_row(parent: VBoxContainer, perk: Dictionary, add_separator: bool) -> void:
	var row_box := VBoxContainer.new()
	row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_box.add_theme_constant_override("separation", 6)
	parent.add_child(row_box)

	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 8)
	row_box.add_child(top_row)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	top_row.add_child(title_box)

	_add_text(title_box, String(perk.get("name", "Perk")), 15, color_text)
	if bool(perk.get("granted_by_achievement", false)):
		_add_text(title_box, "Granted by achievement", 12, color_accent)
	else:
		_add_text(title_box, "%d SP" % rules._as_int(perk.get("cost", 0)), 12, color_muted)

	if not bool(perk.get("granted_by_achievement", false)):
		var remove := Button.new()
		remove.text = "Remove"
		remove.custom_minimum_size = Vector2(86, 34)
		remove.pressed.connect(func():
			rules.set_perk_selected(character, String(perk.get("id", "")), 0)
			_render()
		)
		top_row.add_child(remove)

	_add_text(row_box, String(perk.get("summary", "")), 13, color_text)
	_add_text(row_box, "Source: %s" % String(perk.get("source", "")), 11, color_muted)

	if add_separator:
		var separator := HSeparator.new()
		separator.add_theme_color_override("separator", Color(color_border.r, color_border.g, color_border.b, 0.7))
		row_box.add_child(separator)


func _add_selected_flaw_row(parent: VBoxContainer, flaw: Dictionary, add_separator: bool) -> void:
	var row_box := VBoxContainer.new()
	row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_box.add_theme_constant_override("separation", 6)
	parent.add_child(row_box)

	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 8)
	row_box.add_child(top_row)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	top_row.add_child(title_box)

	_add_text(title_box, String(flaw.get("name", "Flaw")), 15, color_text)
	_add_text(title_box, "+%d SP" % rules._as_int(flaw.get("bonus", 0)), 12, color_muted)

	var remove := Button.new()
	remove.text = "Remove"
	remove.custom_minimum_size = Vector2(86, 34)
	remove.pressed.connect(func():
		rules.set_flaw_selected(character, String(flaw.get("id", "")), 0)
		_render()
	)
	top_row.add_child(remove)

	_add_text(row_box, String(flaw.get("summary", "")), 13, color_text)
	_add_text(row_box, "Source: %s" % String(flaw.get("source", "")), 11, color_muted)

	if add_separator:
		var separator := HSeparator.new()
		separator.add_theme_color_override("separator", Color(color_border.r, color_border.g, color_border.b, 0.7))
		row_box.add_child(separator)


func _show_perk_catalog_modal() -> void:
	_show_perk_flaw_catalog_modal("perk")


func _show_flaw_catalog_modal() -> void:
	_show_perk_flaw_catalog_modal("flaw")


func _show_perk_flaw_catalog_modal(kind: String) -> void:
	perk_flaw_catalog_kind = "flaw" if kind == "flaw" else "perk"
	perk_flaw_filter_text = ""
	_refresh_perk_flaw_catalog_panel()
	perk_flaw_catalog_overlay.visible = true
	_apply_responsive_layout()
	_update_perk_flaw_catalog_modal_height.call_deferred()


func _refresh_perk_flaw_catalog_panel() -> void:
	for child in perk_flaw_catalog_body.get_children():
		child.queue_free()

	var is_flaw_catalog := perk_flaw_catalog_kind == "flaw"
	perk_flaw_catalog_title.text = "Add Flaw" if is_flaw_catalog else "Add Perk"
	var search := LineEdit.new()
	search.text = perk_flaw_filter_text
	search.placeholder_text = "Search flaws" if is_flaw_catalog else "Search perks"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(value):
		perk_flaw_filter_text = value
		_request_search_refresh("perk_flaw", String(value).length(), _refresh_perk_flaw_catalog_panel)
	)
	_add_field(perk_flaw_catalog_body, "Search", search)
	_restore_search_focus(search, "perk_flaw")

	if is_flaw_catalog:
		_add_text(perk_flaw_catalog_body, "Flaws add skill points. A starting hero can choose up to three flaws. Source: Player's Handbook p. 107.", 12, color_muted)
	else:
		_add_text(perk_flaw_catalog_body, "Perks cost skill points. A starting hero can choose up to three perks. Source: Player's Handbook p. 103.", 12, color_muted)

	var filter := perk_flaw_filter_text.strip_edges().to_lower()
	if is_flaw_catalog:
		_add_subheading(perk_flaw_catalog_body, "Flaws")
		var flaw_box := VBoxContainer.new()
		flaw_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flaw_box.add_theme_constant_override("separation", 8)
		perk_flaw_catalog_body.add_child(flaw_box)
		var flaws_shown := _add_flaw_catalog_rows(flaw_box, filter)
		if flaws_shown <= 0:
			_add_text(flaw_box, "No flaws match the current search.", 14, color_muted)
	else:
		_add_subheading(perk_flaw_catalog_body, "Perks")
		var perk_box := VBoxContainer.new()
		perk_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		perk_box.add_theme_constant_override("separation", 8)
		perk_flaw_catalog_body.add_child(perk_box)
		var perks_shown := _add_perk_catalog_rows(perk_box, filter)
		if perks_shown <= 0:
			_add_text(perk_box, "No perks match the current search.", 14, color_muted)

	_update_perk_flaw_catalog_modal_height.call_deferred()


func _add_perk_catalog_rows(parent: VBoxContainer, filter: String) -> int:
	var shown := 0
	for perk in AlternityRules.PERK_DEFINITIONS:
		var option: Dictionary = perk
		if not _character_option_matches_filter(option, filter):
			continue
		shown += 1
		var perk_id := String(option.get("id", ""))
		if rules.achievements.is_perk_granted_by_achievement(character, perk_id):
			_add_granted_perk_row(parent, option)
			continue
		var selected_value := rules.perk_cost_selected(character, perk_id)
		var can_select_new := selected_value > 0 or rules.selected_perk_count(character) < 3
		var change_perk := func(value):
			if value > 0 and selected_value <= 0 and rules.selected_perk_count(character) >= 3:
				return
			rules.set_perk_selected(character, perk_id, value)
			_render()
			_refresh_perk_flaw_catalog_panel()
		_add_character_option_row(
			parent,
			option,
			selected_value,
			{
				"options_key": "cost_options",
				"button_format": "Buy %d SP",
				"selected_format": "Selected %d SP",
				"changed": change_perk,
				"can_select_new": can_select_new,
				"disabled_reason": "The hero already has three perks." if not can_select_new else ""
			}
		)
	return shown


func _add_flaw_catalog_rows(parent: VBoxContainer, filter: String) -> int:
	var shown := 0
	for flaw in AlternityRules.FLAW_DEFINITIONS:
		var option: Dictionary = flaw
		if not _character_option_matches_filter(option, filter):
			continue
		shown += 1
		var flaw_id := String(option.get("id", ""))
		var selected_value := rules.flaw_bonus_selected(character, flaw_id)
		var can_select_new := selected_value > 0 or rules.selected_flaw_count(character) < 3
		var change_flaw := func(value):
			if value > 0 and selected_value <= 0 and rules.selected_flaw_count(character) >= 3:
				return
			rules.set_flaw_selected(character, flaw_id, value)
			_render()
			_refresh_perk_flaw_catalog_panel()
		_add_character_option_row(
			parent,
			option,
			selected_value,
			{
				"options_key": "bonus_options",
				"button_format": "Take +%d SP",
				"selected_format": "Selected +%d SP",
				"changed": change_flaw,
				"can_select_new": can_select_new,
				"disabled_reason": "The hero already has three flaws." if not can_select_new else ""
			}
		)
	return shown


func _character_option_matches_filter(option: Dictionary, filter: String) -> bool:
	if filter.is_empty():
		return true
	var haystack := " ".join([
		String(option.get("name", "")),
		String(option.get("ability", "")),
		String(option.get("activation", "")),
		String(option.get("summary", "")),
		String(option.get("source", "")),
	]).to_lower()
	return haystack.contains(filter)


func _add_character_option_row(parent: VBoxContainer, option: Dictionary, selected_value: int, config: Dictionary) -> void:
	var options_key: String = config.get("options_key", "")
	var button_format: String = config.get("button_format", "")
	var selected_format: String = config.get("selected_format", "")
	var changed: Callable = config.get("changed", Callable())
	var can_select_new: bool = config.get("can_select_new", true)
	var disabled_reason: String = config.get("disabled_reason", "")

	var row_box := VBoxContainer.new()
	row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_box.add_theme_constant_override("separation", 6)
	parent.add_child(row_box)

	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 8)
	row_box.add_child(top_row)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	top_row.add_child(title_box)

	var title := Label.new()
	title.text = String(option.get("name", ""))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", color_text)
	title.add_theme_font_size_override("font_size", 15)
	title_box.add_child(title)

	var meta_parts := []
	var ability := String(option.get("ability", ""))
	var activation := String(option.get("activation", ""))
	if not ability.is_empty():
		meta_parts.append(ability)
	if not activation.is_empty():
		meta_parts.append(activation)
	var values: Array = option.get(options_key, [])
	var point_values := []
	for option_value in values:
		point_values.append("%d" % rules._as_int(option_value))
	meta_parts.append("Options %s SP" % "/".join(point_values))
	_add_text(title_box, " | ".join(meta_parts), 12, color_muted)

	var button_row: BoxContainer
	if get_viewport_rect().size.x < COMPACT_WIDTH:
		button_row = VBoxContainer.new()
	else:
		button_row = HBoxContainer.new()
	button_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_theme_constant_override("separation", 6)
	row_box.add_child(button_row)

	for option_value in values:
		var value_int := rules._as_int(option_value)
		var button := Button.new()
		button.text = (selected_format % value_int) if selected_value == value_int else (button_format % value_int)
		var selecting_new := selected_value <= 0 and value_int > 0
		button.disabled = selected_value == value_int or (selecting_new and not can_select_new)
		if selecting_new and not can_select_new:
			button.tooltip_text = disabled_reason
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 34)
		button.pressed.connect(func(): changed.call(value_int))
		button_row.add_child(button)

	if selected_value > 0:
		var remove := Button.new()
		remove.text = "Remove"
		remove.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		remove.custom_minimum_size = Vector2(0, 34)
		remove.pressed.connect(func(): changed.call(0))
		button_row.add_child(remove)

	if not can_select_new and selected_value <= 0 and not String(disabled_reason).is_empty():
		_add_text(row_box, String(disabled_reason), 12, color_warning)

	_add_text(row_box, String(option.get("summary", "")), 13, color_text)
	_add_text(row_box, "Source: %s" % String(option.get("source", "")), 11, color_muted)

	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", Color(color_border.r, color_border.g, color_border.b, 0.7))
	row_box.add_child(separator)


func _render_achievements() -> void:
	var summary := rules.summary(character)
	var box := _add_section("Achievements")
	_add_metric(box, "Hero Level", str(rules._as_int(summary.get("achievement_level", 1))))
	_add_metric(box, "Achievement Points", "%d total, %d used, %d available" % [
		rules._as_int(summary.get("achievement_points", 0)),
		rules._as_int(summary.get("achievement_points_used", 0)),
		rules._as_int(summary.get("achievement_points_available", 0)),
	])
	_add_metric(box, "Skill Points Used/Available", "%d/%d" % [
		rules._as_int(summary.get("skill_points_used", 0)),
		rules._as_int(summary.get("skill_points_remaining", 0)),
	])
	_add_metric(box, "Achievement Benefit Cost", "%d SP" % rules._as_int(summary.get("achievement_benefit_points_used", 0)))

	var add_button := Button.new()
	add_button.text = "Add Achievement"
	add_button.custom_minimum_size = Vector2(0, 42)
	add_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_button.pressed.connect(_show_achievement_catalog_modal)
	box.add_child(add_button)

	for note in rules.achievement_rules:
		_add_text(box, String(note), 12, color_muted)

	var bought := _add_section("Bought Achievements")
	var selected := rules.achievements.selected_achievements(character)
	if selected.is_empty():
		_add_text(bought, "No achievement benefits purchased yet.", 14, color_muted)
		return
	for entry in selected:
		_add_bought_achievement_row(bought, entry)


func _add_bought_achievement_row(parent: VBoxContainer, entry: Dictionary) -> void:
	var achievement: Dictionary = entry.get("achievement", {})
	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var top := HBoxContainer.new()
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override("separation", 8)
	row.add_child(top)

	var title := Label.new()
	title.text = String(entry.get("name", achievement.get("name", "Achievement")))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", color_text)
	title.add_theme_font_size_override("font_size", 14)
	top.add_child(title)

	var remove := Button.new()
	remove.text = "Remove"
	remove.custom_minimum_size = Vector2(82, 34)
	remove.pressed.connect(func():
		rules.achievements.remove_achievement_purchase(character, String(entry.get("line_id", "")))
		_render()
	)
	top.add_child(remove)

	_add_text(row, "Cost %d SP  |  Bought at level %d" % [
		rules._as_int(entry.get("cost", 0)),
		rules._as_int(entry.get("level", 1)),
	], 12, color_muted)
	_add_text(row, String(entry.get("summary", achievement.get("summary", ""))), 13, color_text)
	_add_text(row, String(achievement.get("reference", "")), 11, color_muted)

	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", Color(color_border.r, color_border.g, color_border.b, 0.55))
	row.add_child(separator)


func _show_achievement_catalog_modal() -> void:
	achievement_form_state = {"mode": "catalog"}
	_refresh_achievement_form_panel()
	achievement_form_overlay.visible = true
	_apply_responsive_layout()
	_update_achievement_form_modal_height.call_deferred()


func _refresh_achievement_form_panel() -> void:
	for child in achievement_form_body.get_children():
		child.queue_free()

	achievement_form_title.text = "Add Achievement"
	var search := LineEdit.new()
	search.text = achievement_filter_text
	search.placeholder_text = "Search achievements"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(value):
		achievement_filter_text = value
		_request_search_refresh("achievement", String(value).length(), _refresh_achievement_form_panel)
	)
	_add_field(achievement_form_body, "Search", search)
	_restore_search_focus(search, "achievement")

	var current_profession := rules.achievements.achievement_profile_key(character).replace("_", " ").capitalize()
	_add_text(achievement_form_body, "Costs and minimum levels shown for %s." % current_profession, 12, color_muted)

	var shown := 0
	var filter := achievement_filter_text.strip_edges().to_lower()
	for achievement in rules.achievement_catalog:
		if typeof(achievement) != TYPE_DICTIONARY:
			continue
		if not _achievement_matches_filter(achievement, filter):
			continue
		shown += 1
		_add_achievement_catalog_row(achievement_form_body, achievement)
	if shown <= 0:
		_add_text(achievement_form_body, "No achievement matches the current search.", 14, color_muted)
	_update_achievement_form_modal_height.call_deferred()


func _achievement_matches_filter(achievement: Dictionary, filter: String) -> bool:
	if filter.is_empty():
		return true
	var haystack := " ".join([
		String(achievement.get("name", "")),
		String(achievement.get("category", "")),
		String(achievement.get("summary", "")),
	]).to_lower()
	return haystack.contains(filter)


func _add_achievement_catalog_row(parent: VBoxContainer, achievement: Dictionary) -> void:
	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)

	var top := HBoxContainer.new()
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override("separation", 8)
	row.add_child(top)

	var title := Label.new()
	title.text = String(achievement.get("name", "Achievement"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", color_text)
	title.add_theme_font_size_override("font_size", 14)
	top.add_child(title)

	var effect: Dictionary = achievement.get("effect", {})
	var effect_type := String(effect.get("type", ""))
	if effect_type == "remove_flaw":
		_add_remove_flaw_achievement_targets(row, achievement)
	else:
		var check := rules.achievements.can_purchase_achievement(character, achievement)
		var add := Button.new()
		add.text = "Add"
		add.custom_minimum_size = Vector2(70, 34)
		add.disabled = not bool(check.get("allowed", false))
		add.pressed.connect(func():
			var result := rules.achievements.add_achievement_purchase(character, String(achievement.get("id", "")))
			if bool(result.get("ok", false)):
				achievement_form_overlay.visible = false
				_render()
			else:
				_refresh_achievement_form_panel()
		)
		top.add_child(add)
		if not bool(check.get("allowed", false)):
			_add_text(row, String(check.get("reason", "")), 12, color_warning)

	_add_text(row, _achievement_meta(achievement), 12, color_muted)
	_add_text(row, String(achievement.get("summary", "")), 13, color_text)
	_add_text(row, String(achievement.get("reference", "")), 11, color_muted)

	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", Color(color_border.r, color_border.g, color_border.b, 0.55))
	row.add_child(separator)


func _add_remove_flaw_achievement_targets(parent: VBoxContainer, achievement: Dictionary) -> void:
	var flaws := rules.selected_flaws(character)
	if flaws.is_empty():
		_add_text(parent, "No selected flaw is available to remove.", 12, color_warning)
		return
	var target_row := VBoxContainer.new()
	target_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_row.add_theme_constant_override("separation", 4)
	parent.add_child(target_row)
	for flaw in flaws:
		var flaw_id := String(flaw.get("id", ""))
		var flaw_bonus := rules._as_int(flaw.get("bonus", 0))
		var check := rules.achievements.can_purchase_achievement(character, achievement, flaw_id, flaw_bonus)
		var button := Button.new()
		button.text = "Remove %s  %d SP" % [
			String(flaw.get("name", "Flaw")),
			rules.achievements.achievement_purchase_cost(character, achievement, flaw_bonus),
		]
		button.disabled = not bool(check.get("allowed", false))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 34)
		button.pressed.connect(func():
			var result := rules.achievements.add_achievement_purchase(character, String(achievement.get("id", "")), flaw_id, flaw_bonus)
			if bool(result.get("ok", false)):
				achievement_form_overlay.visible = false
				_render()
			else:
				_refresh_achievement_form_panel()
		)
		target_row.add_child(button)
		if not bool(check.get("allowed", false)):
			_add_text(target_row, String(check.get("reason", "")), 11, color_warning)


func _achievement_meta(achievement: Dictionary) -> String:
	var cost_info := rules.achievements.achievement_cost_entry(achievement, character)
	var effect: Dictionary = achievement.get("effect", {})
	var cost_text := "%d SP" % rules._as_int(cost_info.get("cost", 0))
	if String(effect.get("type", "")) == "remove_flaw":
		cost_text = "2x flaw bonus"
	return "%s  |  Cost %s  |  Min level %d  |  Max %s" % [
		String(achievement.get("category", "")),
		cost_text,
		rules._as_int(cost_info.get("min_level", 0)),
		"per flaw" if String(effect.get("type", "")) == "remove_flaw" else str(rules._as_int(achievement.get("max", 1))),
	]


func _render_mutations() -> void:
	if not rules.mutations.mutations_enabled(character):
		var unavailable := _add_section("Mutations")
		_add_text(unavailable, "Only Mutant heroes use the Player's Handbook Chapter 13 mutation rules.", 14, color_muted)
		return

	var mutations: Dictionary = character.get("mutations", {})
	var random_generation := String(mutations.get("generation_mode", "random")) == "random"
	var overview := _add_section("Mutation Generation")

	var mode := OptionButton.new()
	var modes := [
		{"id": "random", "name": "Randomly Generated"},
		{"id": "player", "name": "Player Chosen"},
	]
	for index in range(modes.size()):
		var mode_row: Dictionary = modes[index]
		mode.add_item(String(mode_row.get("name", "")), index)
		if String(mutations.get("generation_mode", "random")) == String(mode_row.get("id", "random")):
			mode.select(index)
	mode.item_selected.connect(func(index):
		var mode_row: Dictionary = modes[index]
		rules.mutations.set_mutation_generation_mode(character, String(mode_row.get("id", "random")))
		_render()
	)
	_add_field(overview, "Mutation Generation", mode)

	var origin := OptionButton.new()
	var origins := rules.mutations.mutation_origin_options()
	for index in range(origins.size()):
		var origin_row: Dictionary = origins[index]
		origin.add_item(String(origin_row.get("name", "")), index)
		if String(mutations.get("origin", "engineered")) == String(origin_row.get("id", "")):
			origin.select(index)
	origin.item_selected.connect(func(index):
		var origin_row: Dictionary = origins[index]
		rules.mutations.set_mutation_origin(character, String(origin_row.get("id", "")))
		_render()
	)
	origin.disabled = random_generation
	_add_field(overview, "Mutant Origin", origin)

	var uniqueness := OptionButton.new()
	var uniqueness_rows := rules.mutations.mutation_uniqueness_options(String(character.get("mutations", {}).get("origin", "engineered")))
	for index in range(uniqueness_rows.size()):
		var uniqueness_row: Dictionary = uniqueness_rows[index]
		uniqueness.add_item(String(uniqueness_row.get("name", "")), index)
		if String(mutations.get("uniqueness", "engineered_community")) == String(uniqueness_row.get("id", "")):
			uniqueness.select(index)
	uniqueness.item_selected.connect(func(index):
		var uniqueness_row: Dictionary = uniqueness_rows[index]
		rules.mutations.set_mutation_uniqueness(character, String(uniqueness_row.get("id", "")))
		_render()
	)
	uniqueness.disabled = random_generation
	_add_field(overview, "Mutant Uniqueness", uniqueness)

	var roll_actions: BoxContainer
	if get_viewport_rect().size.x < COMPACT_WIDTH:
		roll_actions = VBoxContainer.new()
	else:
		roll_actions = HBoxContainer.new()
	roll_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roll_actions.add_theme_constant_override("separation", 8)
	overview.add_child(roll_actions)

	var roll_origin := Button.new()
	roll_origin.text = "Roll Origin and Points"
	roll_origin.custom_minimum_size = Vector2(0, 38)
	roll_origin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roll_origin.disabled = not random_generation
	roll_origin.pressed.connect(func():
		rules.mutations.roll_mutation_origin_and_points(character)
		_render()
	)
	roll_actions.add_child(roll_origin)

	if not random_generation:
		_add_text(overview, "Player Chosen mode allows manual origin and uniqueness selection. Point totals and point distributions remain editable in both modes. Source: Player's Handbook p. 214.", 12, color_muted)
	else:
		_add_text(overview, "Randomly Generated mode locks origin and uniqueness; use Roll Origin and Points to roll Table P48 origin, uniqueness, and mutation point totals. Source: Player's Handbook p. 214.", 12, color_muted)
	for note in rules.mutation_rules:
		_add_text(overview, String(note), 12, color_muted)

	var advantage_parent: Container = content
	var drawback_parent: Container = content
	if is_wide_layout:
		var columns := _add_columns()
		advantage_parent = columns[0]
		drawback_parent = columns[1]

	_render_selected_mutation_list(advantage_parent, "Advantageous Mutations", "advantage")
	_render_selected_mutation_list(drawback_parent, "Mutation Drawbacks", "drawback")


func _render_selected_mutation_list(parent: Container, title: String, kind: String) -> void:
	var box := _add_section_to(parent, title)
	var mutation_summary: Dictionary = rules.summary(character).get("mutations", {})
	var is_drawback := kind == "drawback"
	var points_key := "drawback_points" if is_drawback else "advantage_points"
	var used_key := "drawback_points_used" if is_drawback else "advantage_points_used"
	var remaining_key := "drawback_points_remaining" if is_drawback else "advantage_points_remaining"
	var points_label := "Mutation Drawback Points" if is_drawback else "Advantageous Mutation Points"
	var point_total := rules._as_int(mutation_summary.get(points_key, 0))

	_add_number_stepper(box, points_label, point_total, 0, 12, func(value):
		rules.mutations.set_mutation_point_total(character, kind, value)
	)

	var point_actions: BoxContainer
	if get_viewport_rect().size.x < COMPACT_WIDTH:
		point_actions = VBoxContainer.new()
	else:
		point_actions = HBoxContainer.new()
	point_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	point_actions.add_theme_constant_override("separation", 8)

	var distribution := OptionButton.new()
	var distribution_options := rules.mutations.mutation_distribution_options(kind, point_total)
	var selected_distribution_id := rules.mutations.mutation_distribution_id(character, kind)
	for index in range(distribution_options.size()):
		var option: Dictionary = distribution_options[index]
		distribution.add_item(String(option.get("label", "")), index)
		if String(option.get("id", "")) == selected_distribution_id:
			distribution.select(index)
	distribution.item_selected.connect(func(index):
		var option: Dictionary = distribution_options[index]
		rules.mutations.set_mutation_distribution(character, kind, String(option.get("id", "")))
		_render()
	)
	distribution.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_field(box, "Point Distribution", distribution)
	box.add_child(point_actions)

	var roll_points := Button.new()
	roll_points.text = "Roll Points"
	roll_points.custom_minimum_size = Vector2(0, 38)
	roll_points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roll_points.pressed.connect(func():
		rules.mutations.roll_mutation_point_total(character, kind)
		_render()
	)
	point_actions.add_child(roll_points)

	var roll_distribution := Button.new()
	roll_distribution.text = "Roll Distribution"
	roll_distribution.custom_minimum_size = Vector2(0, 38)
	roll_distribution.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roll_distribution.disabled = distribution_options.is_empty()
	roll_distribution.pressed.connect(func():
		rules.mutations.roll_mutation_distribution(character, kind)
		_render()
	)
	point_actions.add_child(roll_distribution)

	_add_metric(box, "Points Used/Available", "%d/%d" % [
		rules._as_int(mutation_summary.get(used_key, 0)),
		rules._as_int(mutation_summary.get(remaining_key, 0)),
	])

	var rows := rules.mutations.selected_mutation_drawbacks(character) if kind == "drawback" else rules.mutations.selected_mutation_advantages(character)
	if rows.is_empty():
		_add_text(box, "No %s selected." % ("mutation drawbacks" if kind == "drawback" else "advantageous mutations"), 14, color_muted)
	else:
		_add_selected_mutation_table(box, rows, kind)

	var actions: BoxContainer
	if get_viewport_rect().size.x < COMPACT_WIDTH:
		actions = VBoxContainer.new()
	else:
		actions = HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)

	var roll := Button.new()
	roll.text = "Roll %s" % ("Drawbacks" if is_drawback else "Mutations")
	roll.custom_minimum_size = Vector2(0, 40)
	roll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roll.disabled = point_total <= 0 or distribution_options.is_empty()
	roll.pressed.connect(func():
		rules.mutations.roll_mutations_for_distribution(character, kind)
		_render()
	)
	actions.add_child(roll)

	var add := Button.new()
	add.text = "Add %s" % ("Drawback" if is_drawback else "Mutation")
	add.custom_minimum_size = Vector2(0, 40)
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add.disabled = point_total <= 0 or distribution_options.is_empty()
	add.pressed.connect(func(): _show_mutation_catalog_modal(kind))
	actions.add_child(add)


func _add_selected_mutation_table(parent: VBoxContainer, rows: Array, kind: String) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)

	_add_table_label(grid, "Mutation", true)
	_add_table_label(grid, "Points", true)
	_add_table_label(grid, "", true)

	for mutation_value in rows:
		var mutation: Dictionary = mutation_value
		_add_table_label(grid, String(mutation.get("name", "Mutation")), false)
		_add_table_label(grid, "%s %d" % [
			String(mutation.get("tier", "")),
			rules._as_int(mutation.get("points", 0)),
		], false)
		var remove := Button.new()
		remove.text = "Remove"
		remove.custom_minimum_size = Vector2(78, 32)
		remove.pressed.connect(func():
			if kind == "drawback":
				rules.mutations.remove_mutation_drawback(character, String(mutation.get("id", "")))
			else:
				rules.mutations.remove_mutation_advantage(character, String(mutation.get("id", "")))
			_render()
		)
		grid.add_child(remove)


func _add_selected_mutation_row(parent: VBoxContainer, mutation: Dictionary, kind: String, add_separator: bool) -> void:
	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)

	var top := HBoxContainer.new()
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override("separation", 8)
	row.add_child(top)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	top.add_child(title_box)
	_add_text(title_box, String(mutation.get("name", "Mutation")), 15, color_text)
	_add_text(title_box, "%s  |  %d points  |  %s" % [
		String(mutation.get("tier", "")),
		rules._as_int(mutation.get("points", 0)),
		String(mutation.get("related_ability", "")),
	], 12, color_muted)

	var remove := Button.new()
	remove.text = "Remove"
	remove.custom_minimum_size = Vector2(82, 34)
	remove.pressed.connect(func():
		if kind == "drawback":
			rules.mutations.remove_mutation_drawback(character, String(mutation.get("id", "")))
		else:
			rules.mutations.remove_mutation_advantage(character, String(mutation.get("id", "")))
		_render()
	)
	top.add_child(remove)

	_add_text(row, String(mutation.get("summary", "")), 13, color_text)
	_add_text(row, String(mutation.get("reference", "")), 11, color_muted)

	if add_separator:
		_add_thin_separator(row)


func _show_mutation_catalog_modal(kind: String) -> void:
	mutation_catalog_kind = "drawback" if kind == "drawback" else "advantage"
	mutation_filter_text = ""
	_refresh_mutation_catalog_panel()
	mutation_catalog_overlay.visible = true
	_apply_responsive_layout()
	_update_mutation_catalog_modal_height.call_deferred()


func _refresh_mutation_catalog_panel() -> void:
	for child in mutation_catalog_body.get_children():
		child.queue_free()

	var is_drawback := mutation_catalog_kind == "drawback"
	mutation_catalog_title.text = "Add Mutation Drawback" if is_drawback else "Add Advantageous Mutation"
	var search := LineEdit.new()
	search.text = mutation_filter_text
	search.placeholder_text = "Search drawbacks" if is_drawback else "Search mutations"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(value):
		mutation_filter_text = value
		_request_search_refresh("mutation", String(value).length(), _refresh_mutation_catalog_panel)
	)
	_add_field(mutation_catalog_body, "Search", search)
	_restore_search_focus(search, "mutation")

	var distribution_label := rules.mutations.mutation_distribution_label(character, mutation_catalog_kind)
	_add_text(mutation_catalog_body, "Showing mutations that fit the selected distribution: %s." % distribution_label, 12, color_muted)
	_add_text(mutation_catalog_body, "Costs use Player's Handbook Table P47. Advantage caps are three Ordinary, two Good, and one Amazing mutation. Source: Player's Handbook p. 214-216.", 12, color_muted)

	var rows := rules.mutation_drawbacks if is_drawback else rules.mutation_advantages
	var filter := mutation_filter_text.strip_edges().to_lower()
	var shown := 0
	var hidden_by_rules := 0
	for mutation_value in rows:
		if typeof(mutation_value) != TYPE_DICTIONARY:
			continue
		var mutation: Dictionary = mutation_value
		if not _mutation_matches_filter(mutation, filter):
			continue
		var check := rules.mutations.can_add_mutation_drawback(character, mutation) if is_drawback else rules.mutations.can_add_mutation_advantage(character, mutation)
		if not bool(check.get("allowed", false)):
			hidden_by_rules += 1
			continue
		shown += 1
		_add_mutation_catalog_row(mutation_catalog_body, mutation, mutation_catalog_kind)
	if shown <= 0:
		var message := "No pickable mutations match the selected distribution."
		if not filter.is_empty():
			message = "No pickable mutations match the selected distribution and search."
		_add_text(mutation_catalog_body, message, 14, color_muted)
	elif hidden_by_rules > 0:
		_add_text(mutation_catalog_body, "%d unavailable mutation%s hidden by the selected distribution or current selections." % [
			hidden_by_rules,
			"" if hidden_by_rules == 1 else "s",
		], 12, color_muted)
	_update_mutation_catalog_modal_height.call_deferred()


func _mutation_matches_filter(mutation: Dictionary, filter: String) -> bool:
	if filter.is_empty():
		return true
	var haystack := " ".join([
		String(mutation.get("name", "")),
		String(mutation.get("tier", "")),
		String(mutation.get("related_ability", "")),
		String(mutation.get("summary", "")),
		String(mutation.get("reference", "")),
	]).to_lower()
	return haystack.contains(filter)


func _add_mutation_catalog_row(parent: VBoxContainer, mutation: Dictionary, kind: String) -> void:
	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)

	var top := HBoxContainer.new()
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override("separation", 8)
	row.add_child(top)

	var title := Label.new()
	title.text = String(mutation.get("name", "Mutation"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", color_text)
	title.add_theme_font_size_override("font_size", 14)
	top.add_child(title)

	var check := rules.mutations.can_add_mutation_drawback(character, mutation) if kind == "drawback" else rules.mutations.can_add_mutation_advantage(character, mutation)
	var add := Button.new()
	add.text = "Add"
	add.custom_minimum_size = Vector2(70, 34)
	add.disabled = not bool(check.get("allowed", false))
	add.pressed.connect(func():
		var result := rules.mutations.add_mutation_drawback(character, String(mutation.get("id", ""))) if kind == "drawback" else rules.mutations.add_mutation_advantage(character, String(mutation.get("id", "")))
		if bool(result.get("ok", false)):
			mutation_catalog_overlay.visible = false
			_render()
		else:
			_refresh_mutation_catalog_panel()
	)
	top.add_child(add)

	_add_text(row, "%s  |  %d points  |  %s" % [
		String(mutation.get("tier", "")),
		rules._as_int(mutation.get("points", 0)),
		String(mutation.get("related_ability", "")),
	], 12, color_muted)
	if not bool(check.get("allowed", false)):
		_add_text(row, String(check.get("reason", "")), 12, color_warning)
	_add_text(row, String(mutation.get("summary", "")), 13, color_text)
	_add_text(row, String(mutation.get("reference", "")), 11, color_muted)
	_add_thin_separator(row)


func _render_equipment() -> void:
	_ensure_equipment_source_filter()
	_add_carried_equipment_panel(content)


func _show_equipment_catalog_modal() -> void:
	equipment_form_state = {
		"mode": "catalog",
	}
	_refresh_equipment_form_panel()
	equipment_form_overlay.visible = true
	_apply_responsive_layout()
	_update_equipment_form_modal_height.call_deferred()


func _ensure_equipment_source_filter() -> void:
	for source in rules.equipment.equipment_source_options():
		var source_id := String(source.get("id", ""))
		if source_id.is_empty():
			continue
		if not equipment_filter_sources.has(source_id):
			equipment_filter_sources[source_id] = true


func _equipment_filter_dictionary() -> Dictionary:
	return {
		"search": equipment_filter_text,
		"pl_min": equipment_filter_pl_min,
		"pl_max": equipment_filter_pl_max,
		"category": equipment_filter_category,
		"class": equipment_filter_class,
		"sources": equipment_filter_sources,
	}


func _refresh_equipment_browser(modal: bool) -> void:
	if modal:
		_refresh_equipment_form_panel()
	else:
		_render()


func _request_search_refresh(target: String, caret_column: int, refresh: Callable) -> void:
	search_refocus_target = target
	search_refocus_caret = caret_column
	refresh.call_deferred()


func _restore_search_focus(edit: LineEdit, target: String) -> void:
	if search_refocus_target != target:
		return

	var caret_column := search_refocus_caret
	search_refocus_target = ""
	search_refocus_caret = -1
	_focus_line_edit_at.bind(edit, caret_column).call_deferred()


func _focus_line_edit_at(edit: LineEdit, caret_column: int) -> void:
	if edit == null or not is_instance_valid(edit):
		return
	edit.grab_focus()
	edit.set_caret_column(clampi(caret_column, 0, edit.text.length()))


func _add_equipment_filters(parent: VBoxContainer, modal := false) -> void:
	var search := LineEdit.new()
	search.text = equipment_filter_text
	search.placeholder_text = "Search equipment"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(value):
		equipment_filter_text = value
		_request_search_refresh("equipment", String(value).length(), _refresh_equipment_browser.bind(modal))
	)
	_add_field(parent, "Search", search)
	_restore_search_focus(search, "equipment")

	var pl_row := HBoxContainer.new()
	pl_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pl_row.add_theme_constant_override("separation", 8)
	parent.add_child(pl_row)
	var pl_min_box := VBoxContainer.new()
	pl_min_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pl_row.add_child(pl_min_box)
	_add_number_input(pl_min_box, "PL From", equipment_filter_pl_min, 0, 9, func(value):
		equipment_filter_pl_min = value
		_refresh_equipment_browser(modal)
	)
	var pl_max_box := VBoxContainer.new()
	pl_max_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pl_row.add_child(pl_max_box)
	_add_number_input(pl_max_box, "PL To", equipment_filter_pl_max, 0, 9, func(value):
		equipment_filter_pl_max = value
		_refresh_equipment_browser(modal)
	)

	var category_option := OptionButton.new()
	category_option.add_item("All categories", 0)
	var categories := rules.equipment.equipment_category_options()
	for index in range(categories.size()):
		category_option.add_item(String(categories[index]), index + 1)
		if String(categories[index]) == equipment_filter_category:
			category_option.select(index + 1)
	category_option.item_selected.connect(func(index):
		equipment_filter_category = "" if index == 0 else category_option.get_item_text(index)
		equipment_filter_class = ""
		_refresh_equipment_browser(modal)
	)
	_add_field(parent, "Category", category_option)

	var class_option := OptionButton.new()
	class_option.add_item("All classes", 0)
	var classes := rules.equipment.equipment_class_options(equipment_filter_category)
	for index in range(classes.size()):
		class_option.add_item(String(classes[index]), index + 1)
		if String(classes[index]) == equipment_filter_class:
			class_option.select(index + 1)
	class_option.item_selected.connect(func(index):
		equipment_filter_class = "" if index == 0 else class_option.get_item_text(index)
		_refresh_equipment_browser(modal)
	)
	_add_field(parent, "Class", class_option)

	var sources_box := VBoxContainer.new()
	sources_box.add_theme_constant_override("separation", 4)
	parent.add_child(sources_box)
	_add_text(sources_box, "Sources", 12, color_muted)
	for source in rules.equipment.equipment_source_options():
		var source_id := String(source.get("id", ""))
		var toggle := CheckBox.new()
		toggle.text = String(source.get("name", source_id))
		toggle.button_pressed = bool(equipment_filter_sources.get(source_id, true))
		toggle.add_theme_color_override("font_color", color_text)
		toggle.add_theme_color_override("font_pressed_color", color_text)
		toggle.add_theme_color_override("font_hover_color", color_text)
		toggle.add_theme_color_override("font_hover_pressed_color", color_text)
		toggle.add_theme_color_override("font_focus_color", color_text)
		toggle.toggled.connect(func(pressed):
			equipment_filter_sources[source_id] = pressed
			_refresh_equipment_browser(modal)
		)
		sources_box.add_child(toggle)


func _add_equipment_catalog(parent: VBoxContainer, modal := false) -> void:
	var items := rules.equipment.filtered_equipment(_equipment_filter_dictionary())
	_add_text(parent, "%d matching items" % items.size(), 13, color_muted)
	if items.is_empty():
		_add_text(parent, "No equipment matches the current filters.", 14, color_muted)
		return
	for item in items:
		_add_equipment_catalog_row(parent, item, modal)


func _add_equipment_catalog_row(parent: VBoxContainer, item: Dictionary, modal := false) -> void:
	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var top := HBoxContainer.new()
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override("separation", 8)
	row.add_child(top)

	var title := Label.new()
	title.text = String(item.get("name", "Equipment"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", color_text)
	title.add_theme_font_size_override("font_size", 14)
	top.add_child(title)

	var add_button := Button.new()
	add_button.text = "Add"
	add_button.custom_minimum_size = Vector2(70, 34)
	add_button.pressed.connect(func():
		rules.equipment.add_equipment_to_character(character, String(item.get("id", "")), 1)
		if modal:
			equipment_form_overlay.visible = false
		_render()
	)
	top.add_child(add_button)

	_add_text(row, _equipment_item_meta(item), 12, color_muted)
	var combat_line := _equipment_combat_line(item)
	if not combat_line.is_empty():
		_add_text(row, combat_line, 12, color_text)
	var reference := String(item.get("reference", ""))
	if not reference.is_empty():
		_add_text(row, reference, 11, color_muted)

	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", Color(color_border.r, color_border.g, color_border.b, 0.55))
	row.add_child(separator)


func _add_carried_equipment_panel(parent: Container) -> void:
	var box := _add_section_to(parent, "Carried Equipment")
	var summary := rules.equipment.equipment_summary(character)
	_add_metric(box, "Total Mass", _format_number(rules._as_float(summary.get("total_mass", 0.0))))
	_add_metric(box, "Total Cost", str(rules._as_int(summary.get("total_cost", 0))))

	var actions: BoxContainer
	if get_viewport_rect().size.x < COMPACT_WIDTH:
		actions = VBoxContainer.new()
	else:
		actions = HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)

	var add_button := Button.new()
	add_button.text = "Add Equipment"
	add_button.custom_minimum_size = Vector2(0, 40)
	add_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_button.pressed.connect(_show_equipment_catalog_modal)
	actions.add_child(add_button)

	var custom_button := Button.new()
	custom_button.text = "Custom Equipment"
	custom_button.custom_minimum_size = Vector2(0, 40)
	custom_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_button.pressed.connect(_show_custom_equipment_form)
	actions.add_child(custom_button)

	var rows := rules.equipment.carried_equipment(character)
	if rows.is_empty():
		_add_text(box, "No carried equipment yet.", 14, color_muted)
		return
	for row in rows:
		_add_carried_equipment_row(box, row)


func _add_carried_equipment_row(parent: VBoxContainer, row: Dictionary) -> void:
	var item: Dictionary = row.get("item", {})
	var row_box := VBoxContainer.new()
	row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_box.add_theme_constant_override("separation", 4)
	parent.add_child(row_box)

	var top := HBoxContainer.new()
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override("separation", 8)
	row_box.add_child(top)

	var name := Label.new()
	name.text = "%s x%d%s" % [
		String(item.get("name", "Equipment")),
		rules._as_int(row.get("quantity", 1)),
		"  Equipped" if bool(row.get("equipped", false)) else "",
	]
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_color_override("font_color", color_text)
	name.add_theme_font_size_override("font_size", 14)
	top.add_child(name)

	var edit := Button.new()
	edit.text = "Edit"
	edit.custom_minimum_size = Vector2(64, 34)
	edit.pressed.connect(func(): _show_edit_equipment_form(String(row.get("line_id", ""))))
	top.add_child(edit)

	var remove := Button.new()
	remove.text = "Remove"
	remove.custom_minimum_size = Vector2(80, 34)
	remove.pressed.connect(func():
		rules.equipment.remove_carried_equipment(character, String(row.get("line_id", "")))
		_render()
	)
	top.add_child(remove)

	_add_text(row_box, "%s  |  Total mass %s  |  Total cost %d" % [
		_equipment_item_meta(item),
		_format_number(rules._as_float(row.get("total_mass", 0.0))),
		rules._as_int(row.get("total_cost", 0)),
	], 12, color_muted)
	var combat_line := _equipment_combat_line(item)
	if not combat_line.is_empty():
		_add_text(row_box, combat_line, 12, color_text)
	if not String(row.get("notes", "")).strip_edges().is_empty():
		_add_text(row_box, String(row.get("notes", "")), 12, color_muted)

	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", Color(color_border.r, color_border.g, color_border.b, 0.55))
	row_box.add_child(separator)


func _show_custom_equipment_form() -> void:
	equipment_form_state = {
		"mode": "custom",
		"quantity": 1,
		"equipped": false,
		"slot": "",
		"notes": "",
		"item": {
			"kind": "equipment",
			"name": "",
			"category": "",
			"class": "",
			"availability": "Com",
			"mass": 0.0,
			"cost": 0,
			"pl": 0,
			"source": "Custom",
			"source_code": "custom",
			"reference": "Character custom equipment.",
			"combat": null,
		},
	}
	_refresh_equipment_form_panel()
	equipment_form_overlay.visible = true
	_update_equipment_form_modal_height.call_deferred()


func _show_edit_equipment_form(line_id: String) -> void:
	for row in rules.equipment.carried_equipment(character):
		if String(row.get("line_id", "")) != line_id:
			continue
		var item: Dictionary = row.get("item", {})
		equipment_form_state = {
			"mode": "edit",
			"line_id": line_id,
			"item_id": String(row.get("item_id", "")),
			"is_custom": String(row.get("item_id", "")).begins_with("custom_"),
			"quantity": rules._as_int(row.get("quantity", 1)),
			"equipped": bool(row.get("equipped", false)),
			"slot": String(row.get("slot", "")),
			"notes": String(row.get("notes", "")),
			"item": item.duplicate(true),
		}
		_refresh_equipment_form_panel()
		equipment_form_overlay.visible = true
		_update_equipment_form_modal_height.call_deferred()
		return


func _refresh_equipment_form_panel() -> void:
	for child in equipment_form_body.get_children():
		child.queue_free()

	var mode := String(equipment_form_state.get("mode", "custom"))
	var item: Dictionary = equipment_form_state.get("item", {})
	var editable_item := mode == "custom" or bool(equipment_form_state.get("is_custom", false))
	if mode == "catalog":
		equipment_form_title.text = "Add Equipment"
		_add_equipment_filters(equipment_form_body, true)
		_add_equipment_catalog(equipment_form_body, true)
		_update_equipment_form_modal_height.call_deferred()
		return

	equipment_form_title.text = "Custom Equipment" if mode == "custom" else "Edit Equipment"

	if editable_item:
		_add_equipment_item_editor(equipment_form_body, item)
	else:
		_add_text(equipment_form_body, String(item.get("name", "Equipment")), 16, color_text)
		_add_text(equipment_form_body, _equipment_item_meta(item), 13, color_muted)
		var combat_line := _equipment_combat_line(item)
		if not combat_line.is_empty():
			_add_text(equipment_form_body, combat_line, 13, color_text)
		_add_text(equipment_form_body, String(item.get("reference", "")), 12, color_muted)

	_add_number_input(equipment_form_body, "Quantity", rules._as_int(equipment_form_state.get("quantity", 1)), 1, 999, func(value):
		equipment_form_state["quantity"] = value
	)

	var equipped := CheckBox.new()
	equipped.text = "Equipped"
	equipped.button_pressed = bool(equipment_form_state.get("equipped", false))
	equipped.add_theme_color_override("font_color", color_text)
	equipped.add_theme_color_override("font_pressed_color", color_text)
	equipped.add_theme_color_override("font_hover_color", color_text)
	equipped.add_theme_color_override("font_hover_pressed_color", color_text)
	equipped.add_theme_color_override("font_focus_color", color_text)
	equipped.toggled.connect(func(pressed): equipment_form_state["equipped"] = pressed)
	equipment_form_body.add_child(equipped)

	_add_line_edit(equipment_form_body, "Slot", String(equipment_form_state.get("slot", "")), func(value): equipment_form_state["slot"] = value)

	var notes := TextEdit.new()
	notes.text = String(equipment_form_state.get("notes", ""))
	notes.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	notes.custom_minimum_size = Vector2(0, 90)
	notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes.text_changed.connect(func(): equipment_form_state["notes"] = notes.text)
	_add_field(equipment_form_body, "Notes", notes)

	var actions := HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 8)
	equipment_form_body.add_child(actions)

	var save := Button.new()
	save.text = "Save"
	save.custom_minimum_size = Vector2(0, 40)
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.pressed.connect(_save_equipment_form)
	actions.add_child(save)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(0, 40)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func(): equipment_form_overlay.visible = false)
	actions.add_child(cancel)

	_update_equipment_form_modal_height.call_deferred()


func _add_equipment_item_editor(parent: VBoxContainer, item: Dictionary) -> void:
	var form_parent: Container = parent
	if is_wide_layout:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 8)
		parent.add_child(grid)
		form_parent = grid

	_add_form_line_edit(form_parent, "Name", String(item.get("name", "")), func(value): item["name"] = value)

	var kind := OptionButton.new()
	var kinds := ["equipment", "weapon", "armor"]
	for index in range(kinds.size()):
		kind.add_item(kinds[index].capitalize(), index)
		if String(item.get("kind", "equipment")) == kinds[index]:
			kind.select(index)
	kind.item_selected.connect(func(index): item["kind"] = kinds[index])
	_add_form_cell(form_parent, "Kind", kind)

	_add_form_line_edit(form_parent, "Category", String(item.get("category", "")), func(value): item["category"] = value)
	_add_form_line_edit(form_parent, "Class", String(item.get("class", "")), func(value): item["class"] = value)
	_add_form_line_edit(form_parent, "Availability", String(item.get("availability", "Com")), func(value): item["availability"] = value)
	_add_form_float_input(form_parent, "Mass", rules._as_float(item.get("mass", 0.0)), func(value): item["mass"] = value)
	_add_form_number_input(form_parent, "Cost", rules._as_int(item.get("cost", 0)), 0, 9999999, func(value): item["cost"] = value)
	_add_form_number_input(form_parent, "PL", rules._as_int(item.get("pl", 0)), 0, 9, func(value): item["pl"] = value)
	_add_form_line_edit(form_parent, "Source", String(item.get("source", "Custom")), func(value):
		item["source"] = value
		item["source_code"] = value.to_lower().replace(" ", "_")
	)


func _save_equipment_form() -> void:
	var mode := String(equipment_form_state.get("mode", "custom"))
	var quantity := rules._as_int(equipment_form_state.get("quantity", 1))
	var equipped := bool(equipment_form_state.get("equipped", false))
	var slot := String(equipment_form_state.get("slot", ""))
	var notes := String(equipment_form_state.get("notes", ""))
	if mode == "custom":
		var line_id := rules.equipment.add_custom_equipment_to_character(character, equipment_form_state.get("item", {}), quantity)
		if not line_id.is_empty():
			rules.equipment.update_carried_equipment(character, line_id, quantity, equipped, slot, notes)
	else:
		var item_id := String(equipment_form_state.get("item_id", ""))
		if bool(equipment_form_state.get("is_custom", false)):
			rules.equipment.update_custom_equipment_item(character, item_id, equipment_form_state.get("item", {}))
		rules.equipment.update_carried_equipment(character, String(equipment_form_state.get("line_id", "")), quantity, equipped, slot, notes)
	equipment_form_overlay.visible = false
	_render()


func _equipment_item_meta(item: Dictionary) -> String:
	return "%s  |  PL %d  |  %s / %s  |  Avail %s  |  Mass %s  |  Cost %s" % [
		String(item.get("source", "")),
		rules._as_int(item.get("pl", 0)),
		String(item.get("category", "")),
		String(item.get("class", "")),
		String(item.get("availability", "")),
		_equipment_mass_text(item),
		_equipment_cost_text(item),
	]


func _equipment_mass_text(item: Dictionary) -> String:
	var mass_text := String(item.get("mass_text", ""))
	if not mass_text.is_empty():
		return mass_text
	return _format_number(rules._as_float(item.get("mass", 0.0)))


func _equipment_cost_text(item: Dictionary) -> String:
	var cost_text := String(item.get("cost_text", ""))
	if not cost_text.is_empty():
		return cost_text
	return str(rules._as_int(item.get("cost", 0)))


func _equipment_combat_line(item: Dictionary) -> String:
	var combat = item.get("combat", null)
	if typeof(combat) != TYPE_DICTIONARY:
		return ""
	var lines := []
	if rules.equipment.equipment_has_combat_role(item, "weapon"):
		lines.append("Weapon: %s  Acc %+d  Damage %s  Range %s  Mode %s  Actions %s  Clip %s" % [
			String(combat.get("skill", "")),
			rules._as_int(combat.get("accuracy", 0)),
			String(combat.get("damage", "")),
			String(combat.get("range", "")),
			String(combat.get("mode", "")),
			str(combat.get("actions", "")),
			rules.equipment._dash_for_empty_or_zero(combat.get("clip_size", "")),
		])
	if rules.equipment.equipment_has_combat_role(item, "armor"):
		lines.append("Armor: %s  AP %+d  Toughness %s  LI %s  HI %s  En %s" % [
			String(combat.get("skill", "")),
			rules._as_int(combat.get("action_penalty", 0)),
			str(combat.get("toughness", "")),
			String(combat.get("li", "")),
			String(combat.get("hi", "")),
			String(combat.get("en", "")),
		])
	return "\n".join(lines)


func _add_attack_forms_summary(parent: VBoxContainer, forms: Array) -> void:
	if forms.is_empty():
		_add_text(parent, "Unarmed attack data is unavailable.", 13, color_muted)
		return

	if not is_wide_layout:
		for index in range(forms.size()):
			_add_attack_form_card(parent, forms[index], index < forms.size() - 1)
		return

	var grid := GridContainer.new()
	grid.columns = 9
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)

	for header_text in ["Attack Forms", "Score", "Base Die", "Type", "Range", "Damage", "Hide", "Clip", "Mass"]:
		_add_table_label(grid, header_text, true)
	for form in forms:
		_add_table_label(grid, String(form.get("name", "Attack")), false)
		_add_table_label(grid, String(form.get("score", "")), false)
		_add_table_label(grid, String(form.get("base_die", "")), false)
		_add_table_label(grid, String(form.get("type", "")), false)
		_add_table_label(grid, String(form.get("range", "")), false)
		_add_table_label(grid, String(form.get("damage", "")), false)
		_add_table_label(grid, String(form.get("hide", "")), false)
		_add_table_label(grid, String(form.get("clip_size", "")), false)
		_add_table_label(grid, String(form.get("mass", "")), false)


func _add_attack_form_card(parent: VBoxContainer, form: Dictionary, include_separator := true) -> void:
	var card := VBoxContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_constant_override("separation", 4)
	parent.add_child(card)

	_add_text(card, String(form.get("name", "Attack")), 15, color_text)
	_add_stat_pair_row(card, [
		{"label": "Score", "value": String(form.get("score", ""))},
		{"label": "Die", "value": String(form.get("base_die", ""))},
	])
	_add_labeled_value(card, "Damage O/G/A", String(form.get("damage", "")))
	_add_stat_pair_row(card, [
		{"label": "Type", "value": String(form.get("type", ""))},
		{"label": "Range", "value": String(form.get("range", ""))},
	])
	_add_stat_pair_row(card, [
		{"label": "Hide", "value": String(form.get("hide", ""))},
		{"label": "Clip", "value": String(form.get("clip_size", ""))},
		{"label": "Mass", "value": String(form.get("mass", ""))},
	])
	if include_separator:
		_add_thin_separator(card)


func _add_armor_summary(parent: VBoxContainer, armor_rows: Array) -> void:
	if armor_rows.is_empty():
		_add_text(parent, "No carried armor.", 13, color_muted)
		return

	if not is_wide_layout:
		for index in range(armor_rows.size()):
			_add_armor_card(parent, armor_rows[index], index < armor_rows.size() - 1)
		return

	var grid := GridContainer.new()
	grid.columns = 7
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	for header_text in ["Armor", "AP", "Tough", "LI", "HI", "En", "Mass"]:
		_add_table_label(grid, header_text, true)
	for row in armor_rows:
		var item: Dictionary = row.get("item", {})
		var combat_value = item.get("combat", {})
		var combat: Dictionary = combat_value if typeof(combat_value) == TYPE_DICTIONARY else {}
		_add_table_label(grid, String(item.get("name", "Armor")), false)
		_add_table_label(grid, "%+d" % rules._as_int(combat.get("action_penalty", 0)), false)
		_add_table_label(grid, str(combat.get("toughness", "")), false)
		_add_table_label(grid, String(combat.get("li", "")), false)
		_add_table_label(grid, String(combat.get("hi", "")), false)
		_add_table_label(grid, String(combat.get("en", "")), false)
		_add_table_label(grid, _format_number(rules._as_float(row.get("total_mass", 0.0))), false)


func _add_armor_card(parent: VBoxContainer, row: Dictionary, include_separator := true) -> void:
	var item: Dictionary = row.get("item", {})
	var combat_value = item.get("combat", {})
	var combat: Dictionary = combat_value if typeof(combat_value) == TYPE_DICTIONARY else {}

	var card := VBoxContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_constant_override("separation", 4)
	parent.add_child(card)

	_add_text(card, "%s%s" % [
		String(item.get("name", "Armor")),
		"  Equipped" if bool(row.get("equipped", false)) else "",
	], 15, color_text)
	_add_stat_pair_row(card, [
		{"label": "AP", "value": "%+d" % rules._as_int(combat.get("action_penalty", 0))},
		{"label": "Tough", "value": str(combat.get("toughness", ""))},
		{"label": "Mass", "value": _format_number(rules._as_float(row.get("total_mass", 0.0)))},
	])
	_add_stat_pair_row(card, [
		{"label": "LI", "value": String(combat.get("li", ""))},
		{"label": "HI", "value": String(combat.get("hi", ""))},
		{"label": "En", "value": String(combat.get("en", ""))},
	])
	if include_separator:
		_add_thin_separator(card)


func _add_stat_pair_row(parent: VBoxContainer, pairs: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = pairs.size()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 2)
	parent.add_child(grid)
	for pair_value in pairs:
		if typeof(pair_value) != TYPE_DICTIONARY:
			continue
		var pair: Dictionary = pair_value
		_add_labeled_value_to(grid, String(pair.get("label", "")), String(pair.get("value", "")))


func _add_labeled_value(parent: VBoxContainer, label_text: String, value_text: String) -> void:
	_add_labeled_value_to(parent, label_text, value_text)


func _add_labeled_value_to(parent: Container, label_text: String, value_text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 1)
	parent.add_child(box)

	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", color_muted)
	label.add_theme_font_size_override("font_size", 10)
	box.add_child(label)

	var value := Label.new()
	value.text = value_text
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.custom_minimum_size = Vector2(1, 0)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.add_theme_color_override("font_color", color_text)
	value.add_theme_font_size_override("font_size", 12)
	box.add_child(value)
	return box


func _add_thin_separator(parent: VBoxContainer) -> void:
	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", Color(color_border.r, color_border.g, color_border.b, 0.55))
	parent.add_child(separator)


func _add_table_label(parent: GridContainer, text: String, header_cell: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(1, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", color_text if header_cell else color_muted)
	label.add_theme_font_size_override("font_size", 11 if header_cell else 10)
	if header_cell:
		label.add_theme_color_override("font_color", color_text)
	parent.add_child(label)
	return label


func _render_skill_picker(box: VBoxContainer, summary: Dictionary, is_psionics := false) -> void:
	_add_progress_metric(box, "Skill Points Used/Available", summary["skill_points_used"], summary["skill_budget"], "%d / %d" % [summary["skill_points_used"], summary["skill_points_remaining"]])
	if rules._as_int(summary.get("perk_points_used", 0)) > 0 or rules._as_int(summary.get("flaw_skill_points_bonus", 0)) > 0:
		_add_metric(box, "Skill Purchases / Perks", "%d / %d SP" % [
			rules._as_int(summary.get("skill_purchase_points_used", 0)),
			rules._as_int(summary.get("perk_points_used", 0)),
		])
		_add_metric(box, "Flaw Skill Point Bonus", "+%d SP" % rules._as_int(summary.get("flaw_skill_points_bonus", 0)))
	
	if rules.optional_rule_enabled(character, "2b"):
		_add_progress_metric(box, "Additional Broad Used/Available", summary["additional_broad_skills_used"], summary["additional_broad_skills_used"] + summary["additional_broad_skills_remaining"], "%d / %d" % [summary["additional_broad_skills_used"], summary["additional_broad_skills_remaining"]])
	else:
		_add_progress_metric(box, "Broad Skills Used/Available", summary["broad_skills_used"], summary["max_broad_skills"], "%d / %d" % [summary["broad_skills_used"], summary["broad_skills_remaining"]])
	var budget_note := "Starting %d + achievement %d" % [
		rules._as_int(summary.get("starting_skill_budget", 0)),
		rules._as_int(summary.get("achievement_points", 0)),
	]
	if rules._as_int(summary.get("achievement_skill_bonus", 0)) > 0:
		budget_note += " + Tech Op bonus %d" % rules._as_int(summary.get("achievement_skill_bonus", 0))
	if rules._as_int(summary.get("flaw_skill_points_bonus", 0)) > 0:
		budget_note += " (includes flaw bonus %d)" % rules._as_int(summary.get("flaw_skill_points_bonus", 0))
	if rules._as_int(summary.get("perk_points_used", 0)) > 0:
		budget_note += "; perks spend %d SP" % rules._as_int(summary.get("perk_points_used", 0))
	if rules._as_int(summary.get("achievement_benefit_points_used", 0)) > 0:
		budget_note += "; achievements spend %d SP" % rules._as_int(summary.get("achievement_benefit_points_used", 0))
	_add_text(box, budget_note, 12, color_muted)
	if summary["skill_points_remaining"] < 0:
		_add_text(box, "Skill points are overspent by %d." % abs(summary["skill_points_remaining"]), 13, color_warning)
	if summary["broad_skills_remaining"] < 0:
		_add_text(box, "Broad skills exceed the limit by %d." % abs(summary["broad_skills_remaining"]), 13, color_warning)
	if rules.optional_rule_enabled(character, "2b"):
		_add_text(box, "Racial broad skills do not count against this limit: %d." % summary["racial_broad_skills"], 13, color_muted)

	var search := LineEdit.new()
	search.text = psionic_filter if is_psionics else skill_filter
	search.placeholder_text = "Search psionic skills" if is_psionics else "Search core skills"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(search)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	box.add_child(list)

	search.text_changed.connect(func(value):
		if is_psionics:
			psionic_filter = value
		else:
			skill_filter = value
		_refresh_skill_rows(list, is_psionics)
	)
	_refresh_skill_rows(list, is_psionics)


func _render_selected_skill_panel(parent: Container) -> void:
	var box := _add_section_to(parent, "Selected Skills")
	var selected := rules.selected_skills(character)
	if selected.is_empty():
		_add_text(box, "Only species free broad skills are selected.", 14, color_muted)
		return

	_add_selected_skill_table(box, selected)


func _add_selected_skill_table(parent: VBoxContainer, selected: Array) -> void:
	var compact := get_viewport_rect().size.x < COMPACT_WIDTH
	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8 if compact else 12)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)

	_add_selected_skill_cell(grid, "Cost", true, HORIZONTAL_ALIGNMENT_LEFT, 34 if compact else 62)
	_add_selected_skill_cell(grid, "Rank", true, HORIZONTAL_ALIGNMENT_LEFT, 36 if compact else 58)
	_add_selected_skill_cell(grid, "Skill", true, HORIZONTAL_ALIGNMENT_LEFT, 50 if compact else 170, true)
	_add_selected_skill_cell(grid, "Score", true, HORIZONTAL_ALIGNMENT_LEFT, 64 if compact else 86)
	_add_selected_skill_cell(grid, "Die", true, HORIZONTAL_ALIGNMENT_LEFT, 30 if compact else 42)

	for skill in selected:
		var score: Dictionary = skill["score"]
		var spent := rules._as_int(skill.get("cost", 0))
		var cost_text := "Free" if bool(skill.get("free", false)) and spent <= 0 else ("Free+%d" % spent if bool(skill.get("free", false)) else "%d SP" % spent)
		var rank_text := "Broad" if skill.get("type", "") == "broad" else "R%d" % rules._as_int(skill.get("rank", 0))
		var score_text := "O%d/G%d/A%d" % [
			rules._as_int(score.get("ordinary", 0)),
			rules._as_int(score.get("good", 0)),
			rules._as_int(score.get("amazing", 0)),
		]
		_add_selected_skill_cell(grid, cost_text, false, HORIZONTAL_ALIGNMENT_LEFT, 34 if compact else 62)
		_add_selected_skill_cell(grid, rank_text, false, HORIZONTAL_ALIGNMENT_LEFT, 36 if compact else 58)
		_add_selected_skill_cell(grid, rules.skill_label(skill), false, HORIZONTAL_ALIGNMENT_LEFT, 50 if compact else 170, true)
		_add_selected_skill_cell(grid, score_text, false, HORIZONTAL_ALIGNMENT_LEFT, 64 if compact else 86)
		_add_selected_skill_cell(grid, String(score.get("die", "")), false, HORIZONTAL_ALIGNMENT_LEFT, 30 if compact else 42)


func _add_selected_skill_cell(parent: GridContainer, text: String, header_cell: bool, alignment: HorizontalAlignment, min_width: int, expand := false) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = min_width
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_SHRINK_BEGIN
	label.add_theme_color_override("font_color", color_muted if header_cell else color_text)
	label.add_theme_font_size_override("font_size", 11 if header_cell else 12)
	parent.add_child(label)
	return label


func _refresh_skill_rows(list: VBoxContainer, is_psionics := false) -> void:
	for child in list.get_children():
		child.queue_free()

	var filter := (psionic_filter if is_psionics else skill_filter).strip_edges().to_lower()
	for ability in AlternityRules.ABILITIES:
		var rows_for_ability := []
		for broad in rules.broad_skills:
			if String(broad.get("stat", "")) != ability:
				continue
			if (broad.get("source", "") == "psionics") != is_psionics:
				continue

			var broad_id := rules._as_int(broad.get("id", -1))
			var child_matches := []
			for specialty in rules.specialty_skills_by_broad_id.get(broad_id, []):
				var specialty_label := rules.skill_label(specialty).to_lower()
				if filter.is_empty() or specialty_label.contains(filter):
					child_matches.append(specialty)

			var broad_label := rules.skill_label(broad).to_lower()
			var show_broad := filter.is_empty() or broad_label.contains(filter) or not child_matches.is_empty()
			if show_broad:
				rows_for_ability.append({
					"broad": broad,
					"specialties": child_matches,
				})

		if rows_for_ability.is_empty():
			continue

		var ability_label := Label.new()
		ability_label.text = "%s  %s" % [ability, AlternityRules.ABILITY_NAMES.get(ability, ability)]
		ability_label.add_theme_color_override("font_color", color_accent)
		ability_label.add_theme_font_size_override("font_size", 16)
		list.add_child(ability_label)

		for row in rows_for_ability:
			var broad: Dictionary = row["broad"]
			var broad_id := rules._as_int(broad.get("id", -1))
			_add_skill_row(list, broad, false)
			if rules.is_skill_selected(character, broad_id) or not filter.is_empty():
				for specialty in row["specialties"]:
					_add_skill_row(list, specialty, true)


func _add_skill_row(parent: VBoxContainer, skill: Dictionary, indented: bool) -> void:
	var skill_id := rules._as_int(skill.get("id", -1))
	var selected := rules.is_skill_selected(character, skill_id)
	var free := rules.is_free_species_skill(character, skill_id)
	var free_rank := rules.free_species_skill_rank(character, skill_id)
	var rank := rules.skill_rank(character, skill_id)
	var is_specialty: bool = skill.get("type", "") == "specialty"

	var row_box := VBoxContainer.new()
	row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_box.add_theme_constant_override("separation", 4)
	parent.add_child(row_box)

	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 8)
	top_row.custom_minimum_size = Vector2(0, 38)
	row_box.add_child(top_row)

	if indented:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(18, 1)
		top_row.add_child(spacer)

	var check := CheckBox.new()
	check.button_pressed = selected
	check.disabled = free or is_specialty
	check.custom_minimum_size = Vector2(38, 38)
	top_row.add_child(check)

	var name := Label.new()
	name.text = String(skill.get("name", ""))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.add_theme_color_override("font_color", color_text)
	name.add_theme_font_size_override("font_size", 14 if indented else 15)
	top_row.add_child(name)

	var info := Button.new()
	info.text = "?"
	info.tooltip_text = "Skill details"
	info.custom_minimum_size = Vector2(34, 34)
	info.pressed.connect(func(): _show_skill_details(skill_id))
	top_row.add_child(info)

	var cost := Label.new()
	if free and rank > free_rank:
		cost.text = "Free + %d" % rules.skill_rank_total_cost(character, skill)
	elif free:
		cost.text = "Free"
	elif is_specialty:
		cost.text = "Rank %d" % rank
	else:
		if selected:
			cost.text = "Spent %d" % rules.skill_rank_total_cost(character, skill)
		else:
			cost.text = "Cost %d" % rules.skill_cost(character, skill)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost.custom_minimum_size = Vector2(78, 38)
	cost.add_theme_color_override("font_color", color_accent if selected else color_muted)
	cost.add_theme_font_size_override("font_size", 13)
	top_row.add_child(cost)

	if not free and not is_specialty:
		check.toggled.connect(func(pressed):
			rules.set_skill_selected(character, skill_id, pressed)
			_render()
		)

	if is_specialty:
		var controls_container: Container
		if is_wide_layout:
			controls_container = HBoxContainer.new()
		else:
			controls_container = VBoxContainer.new()
		controls_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_box.add_child(controls_container)

		var controls := HBoxContainer.new()
		controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		controls.add_theme_constant_override("separation", 6)
		controls_container.add_child(controls)

		var control_spacer := Control.new()
		control_spacer.custom_minimum_size = Vector2(56, 1) if indented else Vector2(38, 1)
		controls.add_child(control_spacer)

		var minus := Button.new()
		minus.text = "-"
		minus.disabled = rank <= free_rank
		minus.custom_minimum_size = Vector2(36, 34) if is_wide_layout else Vector2(44, 44)
		minus.pressed.connect(func():
			rules.change_skill_rank(character, skill_id, -1)
			_render()
		)
		controls.add_child(minus)

		var rank_label := Label.new()
		rank_label.text = "Rank %d" % rank
		rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rank_label.custom_minimum_size = Vector2(62, 34) if is_wide_layout else Vector2(62, 44)
		rank_label.add_theme_color_override("font_color", color_text if rank > 0 else color_muted)
		rank_label.add_theme_font_size_override("font_size", 13)
		controls.add_child(rank_label)

		var plus := Button.new()
		plus.text = "+"
		plus.disabled = rank >= AlternityRules.MAX_SPECIALTY_RANK
		plus.custom_minimum_size = Vector2(36, 34) if is_wide_layout else Vector2(44, 44)
		plus.pressed.connect(func():
			rules.change_skill_rank(character, skill_id, 1)
			_render()
		)
		controls.add_child(plus)

		var next_cost := rules.next_skill_rank_cost(character, skill)
		var cost_note := Label.new()
		if rank >= AlternityRules.MAX_SPECIALTY_RANK:
			cost_note.text = "Max rank"
		elif free and rank <= free_rank:
			cost_note.text = "Free rank %d  |  Next %d SP" % [free_rank, next_cost]
		elif rank <= 0:
			cost_note.text = "Buy %d SP" % next_cost
		else:
			cost_note.text = "Spent %d SP  |  Next %d SP" % [rules.skill_rank_total_cost(character, skill), next_cost]
		cost_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cost_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cost_note.add_theme_color_override("font_color", color_muted)
		cost_note.add_theme_font_size_override("font_size", 12)
		
		if is_wide_layout:
			controls.add_child(cost_note)
		else:
			var cost_box := HBoxContainer.new()
			var cost_spacer := Control.new()
			cost_spacer.custom_minimum_size = Vector2(56, 1) if indented else Vector2(38, 1)
			cost_box.add_child(cost_spacer)
			cost_box.add_child(cost_note)
			controls_container.add_child(cost_box)


func _render_cybertech() -> void:
	var cybertech_data = rules.cybertech._cybertech_data(character)
	var enabled = rules.cybertech.cybertech_enabled(character)
	var top_section = _add_section("Cybertech")
	_add_text(top_section, "Cybertech allows characters to enhance their bodies with technology. Your Cyber Tolerance is equal to your Constitution score (Mechalus get +4). Installing items uses up your tolerance. Items that tap into your nervous system (like Reflex or Fast Chips) risk giving you Cykosis, a mental strain that reduces your Will-based checks by -1 per point of Cykosis.", 12, color_muted)

	_add_large_checkbox(top_section, "Hero uses Cybertech", enabled, func(checked):
		rules.cybertech.set_cybertech_enabled(character, checked)
		_save_character()
		_render()
	)
	if not enabled:
		return

	var metrics_row = VBoxContainer.new()
	metrics_row.add_theme_constant_override("separation", 8)
	top_section.add_child(metrics_row)

	var tolerance = rules.cybertech.cyber_tolerance_breakdown(character)
	_add_metric(metrics_row, "Cyber Tolerance Used / Total", "%d / %d" % [tolerance.used, tolerance.total])
	_add_metric(metrics_row, "Cyber Tolerance Thresholds", "%d / %d / %d" % [tolerance.left, tolerance.left + tolerance.center, tolerance.total])

	var cyk_total = rules.cybertech.cykosis_total(character)
	var cyk_used = rules.cybertech.cykosis_used(character)
	_add_number_stepper(metrics_row, "Cykosis Points Used (Max %d)" % cyk_total, cyk_used, 0, cyk_total, func(value):
		rules.cybertech.set_cykosis_used(character, value)
		_save_character()
	)
	_add_thin_separator(top_section)

	var skill_purchased = rules.cybertech.is_cybertech_skill_purchased(character)
	_add_large_checkbox(top_section, "Purchase the Cybertech skill required to use certain cybertech for 10 skill points", skill_purchased, func(checked):
		rules.cybertech.set_cybertech_skill_purchased(character, checked)
		_save_character()
		_render()
	)
	_add_thin_separator(top_section)

	var catalog_section = _add_section("Cybertech Catalog")

	for item_value in rules.cybertech_catalog:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		var row = VBoxContainer.new()
		catalog_section.add_child(row)
		
		var title = _add_text(row, String(item.get("name", "")), 16, color_accent)
		
		var info_str = "PL: %d  |  Mass: %s  |  Size: %s" % [
			rules._as_int(item.get("pl", 6)),
			str(item.get("mass", item.get("mass_ordinary", 0))),
			str(item.get("size", item.get("size_ordinary", 0)))
		]
		var source_str = String(item.get("source", ""))
		if not source_str.is_empty():
			info_str += "  |  Source: %s" % source_str
		_add_text(row, info_str, 12, color_muted)
		
		_add_text(row, String(item.get("description", "")), 14, color_text)
		
		var action_margin = MarginContainer.new()
		action_margin.add_theme_constant_override("margin_top", 12)
		action_margin.add_theme_constant_override("margin_bottom", 8)
		row.add_child(action_margin)
		
		var action_row = HFlowContainer.new()
		action_row.add_theme_constant_override("h_separation", 8)
		action_row.add_theme_constant_override("v_separation", 8)
		action_margin.add_child(action_row)
		
		var installed = false
		for inst in rules.cybertech.installed_cybertech(character):
			if String(inst.get("item_id", "")) == String(item.get("id", "")):
				installed = true
				break
		if installed:
			var btn_remove = Button.new()
			btn_remove.text = "Remove"
			btn_remove.pressed.connect(func():
				rules.cybertech.remove_cybertech(character, String(item.get("id", "")))
				_save_character()
				_render()
			)
			action_row.add_child(btn_remove)
		else:
			for q in ["ordinary", "good", "amazing"]:
				var cost = item.get("cost_%s" % q, 0)
				if rules._as_int(cost) > 0:
					var btn_add = Button.new()
					btn_add.text = "Install %s" % q.capitalize()
					btn_add.pressed.connect(func():
						var res = rules.cybertech.install_cybertech(character, String(item.get("id", "")), q)
						if res.get("ok", false):
							_save_character()
							_render()
					)
					action_row.add_child(btn_add)
		_add_thin_separator(row)

func _render_fx_psionics() -> void:
	var overview := _add_section("Psionic Energy & Mindwalker Status")
	
	var is_psionic: bool = rules._as_int(character.get("species_id", 0)) == 1 or character.get("profession_id", 0) == 6 # Fraal or Mindwalker
	var summary := rules.summary(character)
	if is_psionic:
		var base_wil := rules._as_int(rules.effective_abilities(character).get("WIL", 10))
		var is_fraal: bool = rules._as_int(character.get("species_id", 0)) == 1
		var is_mindwalker: bool = character.get("profession_id", 0) == 6
		
		var energy_points := base_wil / 2
		if is_fraal and is_mindwalker:
			energy_points = int(base_wil * 1.5)
		elif is_fraal or is_mindwalker:
			energy_points = base_wil
			
		_add_progress_metric(overview, "Psionic Energy Points", energy_points, energy_points, "%d / %d" % [energy_points, energy_points])
		_add_text(overview, "Your Psionic Energy is derived from your Will score. Use these points to power psionic abilities.", 12, color_muted)
	else:
		_add_text(overview, "You do not currently possess psionic potential. Only Fraal or heroes with the Mindwalker profession/perk can access these powers.", 13, color_warning)

	var skills_box := _add_section("Psionic Skills")
	if is_psionic:
		_render_skill_picker(skills_box, summary, true)
	else:
		_add_text(skills_box, "Psionic skills are locked.", 13, color_muted)

func _render_summary() -> void:
	var summary := rules.summary(character)
	var current_species := rules.get_species_by_id(rules._as_int(character.get("species_id", 0)))
	var profession := rules.get_profession_by_id(rules._as_int(character.get("profession_id", 0)))

	var left_parent: Container = content
	var right_parent: Container = content
	if is_wide_layout:
		var columns := _add_columns()
		left_parent = columns[0]
		right_parent = columns[1]

	var overview := _add_section_to(left_parent, "Character")
	_add_text(overview, "%s  |  %s  |  %s" % [
		String(character.get("hero_name", "")),
		current_species.get("name", ""),
		profession.get("name", ""),
	], 18, color_text)
	if not String(character.get("career", "")).is_empty():
		_add_text(overview, String(character.get("career", "")), 13, color_muted)
	_add_text(overview, "Level %d  |  AP %d total, %d used, %d available" % [
		rules._as_int(summary.get("achievement_level", 1)),
		rules._as_int(summary.get("achievement_points", 0)),
		rules._as_int(summary.get("achievement_points_used", 0)),
		rules._as_int(summary.get("achievement_points_available", 0)),
	], 13, color_muted)
	_add_text(overview, "Next level at %d AP" % rules._as_int(summary.get("achievement_next_level_points", 0)), 12, color_muted)
	_add_compact_abilities(overview)
	var action: Dictionary = summary["action_check"]
	_add_metric(overview, "Action Check Score", "M%d / O%d / G%d / A%d  %s" % [
		action["marginal"],
		action["ordinary"],
		action["good"],
		action["amazing"],
		action["die"],
	])
	_add_metric(overview, "Actions / Round", str(action["actions"]))

	var last_resorts: Dictionary = summary["last_resorts"]
	_add_tracker_row(
		overview,
		"Last Resorts",
		rules._as_int(last_resorts.get("max", 0)),
		rules._as_int(last_resorts.get("used", 0)),
		func(value):
			rules.set_last_resorts_used(character, value)
			_render()
	)
	_add_text(overview, "%d available of %d max. Replacement cost: %d skill points." % [
		rules._as_int(last_resorts.get("available", 0)),
		rules._as_int(last_resorts.get("max", 0)),
		rules._as_int(last_resorts.get("cost", 0)),
	], 13, color_muted)
	if rules._as_int(last_resorts.get("profession_bonus", 0)) > 0:
		_add_text(overview, "Free Agent maximum includes +%d and may spend 2 points on one action." % rules._as_int(last_resorts.get("profession_bonus", 0)), 13, color_muted)

	var durability_box := _add_section_to(left_parent, "Durability")
	var durability: Dictionary = summary["durability"]
	for damage_type in ["stun", "wound", "mortal", "fatigue"]:
		var damage_key := String(damage_type)
		_add_tracker_row(
			durability_box,
			damage_key.capitalize(),
			rules._as_int(durability.get(damage_key, 0)),
			rules._as_int(character.get("damage", {}).get(damage_key, 0)),
			func(value):
				rules.set_damage_used(character, damage_key, value)
				_render()
		)

	var movement_box := _add_section_to(left_parent, "Combat Movement")
	var movement: Dictionary = summary["movement"]
	_add_metric(movement_box, "STR + DEX", str(movement["total"]))
	_add_metric(movement_box, "Rates", "Sprint %s   Run %s   Walk %s" % [
		str(movement["sprint"]),
		str(movement["run"]),
		str(movement["walk"]),
	])
	_add_metric(movement_box, "Water / Air", "Easy Swim %s   Swim %s   Glide %s   Fly %s" % [
		str(movement["easy_swim"]),
		str(movement["swim"]),
		str(movement["glide"]),
		str(movement["fly"]),
	])
	for effect in movement.get("effects", []):
		_add_text(movement_box, "%s: %s" % [effect.get("mode", ""), effect.get("effect", "")], 12, color_muted)

	var equipment_summary: Dictionary = summary.get("equipment", {})
	var attack_forms_box := _add_section_to(left_parent, "Attack Forms")
	var combined_attacks: Array = equipment_summary.get("attack_forms", []).duplicate(true)
	combined_attacks.append_array(rules.cybertech.cybertech_attack_forms(character))
	_add_attack_forms_summary(attack_forms_box, combined_attacks)
	var armor_box := _add_section_to(left_parent, "Armor")
	var combined_armor: Array = equipment_summary.get("combat_armor", []).duplicate(true)
	combined_armor.append_array(rules.cybertech.cybertech_armor_rows(character))
	_add_armor_summary(armor_box, combined_armor)

	_render_notes_section(left_parent)

	var validation_box := _add_section_to(right_parent, "Rules")
	if summary["validations"].is_empty():
		_add_text(validation_box, "No rule issues found for the implemented Core checks.", 14, color_accent)
	else:
		for message in summary["validations"]:
			_add_text(validation_box, String(message), 14, color_warning)

	var all_selected := rules.selected_skills(character)
	var standard_skills := []
	var psionic_skills := []
	for s in all_selected:
		if s.get("source", "") == "psionics":
			psionic_skills.append(s)
		else:
			standard_skills.append(s)

	var skill_box := _add_section_to(right_parent, "Selected Skills")
	if standard_skills.is_empty():
		_add_text(skill_box, "No purchased skills beyond species free broad skills.", 14, color_muted)
	else:
		_add_selected_skill_table(skill_box, standard_skills)

	if not psionic_skills.is_empty():
		var psionics_box := _add_section_to(right_parent, "Selected Psionics")
		_add_selected_skill_table(psionics_box, psionic_skills)

	var perks_box := _add_section_to(right_parent, "Perks")
	_add_selected_perks_summary(perks_box)

	var flaws_box := _add_section_to(right_parent, "Flaws")
	_add_selected_flaws_summary(flaws_box)

	if rules.mutations.mutations_enabled(character):
		var mutation_summary: Dictionary = summary.get("mutations", {})
		var advantage_box := _add_section_to(right_parent, "Advantageous Mutations")
		_add_mutation_summary_panel(advantage_box, rules.mutations.selected_mutation_advantages(character), "advantage", mutation_summary)
		var drawback_box := _add_section_to(right_parent, "Mutation Drawbacks")
		_add_mutation_summary_panel(drawback_box, rules.mutations.selected_mutation_drawbacks(character), "drawback", mutation_summary)

	var cybertech_summary: Dictionary = summary.get("cybertech", {})
	if bool(cybertech_summary.get("enabled", false)):
		var cybertech_box := _add_section_to(right_parent, "Cybertech")
		var installed: Array = cybertech_summary.get("installed", [])
		if installed.is_empty():
			_add_text(cybertech_box, "No cybertech installed.", 14, color_muted)
		else:
			for i in range(installed.size()):
				var item = installed[i]
				_add_text(cybertech_box, "%s (%s)" % [String(item.get("item", {}).get("name", "")), String(item.get("quality", "ordinary")).capitalize()], 14, color_text)
				var desc = String(item.get("item", {}).get("description", ""))
				if not desc.is_empty():
					_add_text(cybertech_box, desc, 12, color_muted)
				if i < installed.size() - 1:
					_add_thin_separator(cybertech_box)
	var achievements_box := _add_section_to(right_parent, "Achievements")
	var selected_achievements: Array = summary.get("selected_achievements", [])
	if selected_achievements.is_empty():
		_add_text(achievements_box, "No achievement benefits purchased.", 14, color_muted)
	else:
		for group in _achievement_summary_groups(selected_achievements):
			var achievement: Dictionary = group.get("achievement", {})
			_add_text(achievements_box, _achievement_summary_group_title(group), 13, color_text)
			_add_text(achievements_box, "%s Source: %s" % [
				String(group.get("summary", achievement.get("summary", ""))),
				String(achievement.get("reference", "")),
			], 11, color_muted)

	var roll_box := _add_section_to(right_parent, "Roll Notes")
	var roll_notes := rules.skill_roll_notes_for_character(character)
	if roll_notes.is_empty():
		_add_text(roll_box, "No selected skill has an extra implemented roll note yet.", 14, color_muted)
	else:
		for note in roll_notes:
			_add_rich_note(roll_box, String(note), 13, color_text)

	_add_rank_benefits_summary(right_parent)

	var save_box := _add_section_to(right_parent, "Save")
	var save_button := Button.new()
	save_button.text = "Save JSON"
	save_button.custom_minimum_size = Vector2(0, 44)
	save_button.pressed.connect(_save_character)
	save_box.add_child(save_button)
	save_status_label = Label.new()
	save_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_status_label.add_theme_color_override("font_color", color_muted)
	save_box.add_child(save_status_label)


func _add_rank_benefits_summary(parent: VBoxContainer) -> void:
	var benefit_box := _add_section_to(parent, "Rank Benefits")
	var rank_groups := rules.skill_rank_benefit_groups(character)
	if rank_groups.is_empty():
		_add_text(benefit_box, "No selected specialty rank benefits are active yet.", 14, color_muted)
		return

	for group in rank_groups:
		var entries: Array = group.get("entries", [])
		if entries.is_empty():
			continue

		var skill_name := String(group.get("skill", "Skill"))
		if entries.size() >= 2:
			_add_rich_note(benefit_box, "%s:" % skill_name, 13, color_text)
			for entry in entries:
				_add_indented_text(benefit_box, "Rank %d: %s" % [
					rules._as_int(entry.get("rank", 0)),
					String(entry.get("text", "")),
				], 13, color_text)
		else:
			var entry: Dictionary = entries[0]
			_add_rich_note(benefit_box, "%s rank %d: %s" % [
				skill_name,
				rules._as_int(entry.get("rank", 0)),
				String(entry.get("text", "")),
			], 13, color_text)


func _achievement_summary_groups(entries: Array) -> Array:
	var groups := []
	var indexes := {}
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var achievement: Dictionary = entry.get("achievement", {})
		var name := String(entry.get("name", achievement.get("name", "Achievement")))
		var summary_text := String(entry.get("summary", achievement.get("summary", "")))
		var reference := String(achievement.get("reference", ""))
		var key := "%s|%s|%s" % [name, summary_text, reference]
		if not indexes.has(key):
			indexes[key] = groups.size()
			groups.append({
				"name": name,
				"summary": summary_text,
				"achievement": achievement,
				"count": 0,
				"unit_cost": rules._as_int(entry.get("cost", 0)),
				"total_cost": 0,
				"same_cost": true,
			})
		var group: Dictionary = groups[rules._as_int(indexes[key])]
		var cost := rules._as_int(entry.get("cost", 0))
		group["count"] = rules._as_int(group.get("count", 0)) + 1
		group["total_cost"] = rules._as_int(group.get("total_cost", 0)) + cost
		if cost != rules._as_int(group.get("unit_cost", 0)):
			group["same_cost"] = false
	return groups


func _achievement_summary_group_title(group: Dictionary) -> String:
	var name := String(group.get("name", "Achievement"))
	var count := rules._as_int(group.get("count", 1))
	var unit_cost := rules._as_int(group.get("unit_cost", 0))
	var total_cost := rules._as_int(group.get("total_cost", unit_cost))
	if count <= 1:
		return "%s  %d SP" % [name, total_cost]
	if bool(group.get("same_cost", true)):
		return "%s  %d SP (bought %d times)" % [name, unit_cost, count]
	return "%s  %d SP total (bought %d times)" % [name, total_cost, count]


func _render_notes_section(parent: Container) -> void:
	var box := _add_section_to(parent, "Notes")
	if notes_editing:
		var editor := TextEdit.new()
		editor.text = notes_draft
		editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		editor.custom_minimum_size = Vector2(0, 220 if is_wide_layout else 180)
		editor.text_changed.connect(func(): notes_draft = editor.text)
		box.add_child(editor)

		var actions := HBoxContainer.new()
		actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_theme_constant_override("separation", 8)
		box.add_child(actions)

		var save := Button.new()
		save.text = "Save Notes"
		save.custom_minimum_size = Vector2(0, 38)
		save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		save.pressed.connect(func():
			character["notes"] = notes_draft
			notes_editing = false
			_render()
		)
		actions.add_child(save)

		var cancel := Button.new()
		cancel.text = "Cancel"
		cancel.custom_minimum_size = Vector2(0, 38)
		cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cancel.pressed.connect(func():
			notes_draft = ""
			notes_editing = false
			_render()
		)
		actions.add_child(cancel)
		return

	var notes := String(character.get("notes", "")).strip_edges()
	_add_text(box, notes if not notes.is_empty() else "No notes yet.", 14, color_text if not notes.is_empty() else color_muted)

	var edit := Button.new()
	edit.text = "Edit Notes"
	edit.custom_minimum_size = Vector2(0, 38)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.pressed.connect(func():
		notes_draft = String(character.get("notes", ""))
		notes_editing = true
		_render()
	)
	box.add_child(edit)


func _add_selected_character_options_summary(parent: VBoxContainer) -> void:
	var perks := rules.selected_perks(character)
	var flaws := rules.selected_flaws(character)
	if perks.is_empty() and flaws.is_empty():
		_add_text(parent, "No perks or flaws selected.", 14, color_muted)
		return

	if not perks.is_empty():
		_add_selected_perks_summary(parent)

	if not flaws.is_empty():
		_add_selected_flaws_summary(parent)


func _add_selected_perks_summary(parent: VBoxContainer) -> void:
	var perks := rules.selected_perks(character)
	if perks.is_empty():
		_add_text(parent, "No perks selected.", 14, color_muted)
		return

	for index in range(perks.size()):
		var perk: Dictionary = perks[index]
		var title := ""
		if bool(perk.get("granted_by_achievement", false)):
			title = "%s  Granted by achievement" % String(perk.get("name", ""))
		else:
			title = "%s  %d SP" % [
				String(perk.get("name", "")),
				rules._as_int(perk.get("cost", 0)),
			]
		_add_text(parent, title, 15, color_text)
		_add_text(parent, "%s Source: %s" % [
			String(perk.get("summary", "")),
			String(perk.get("source", "")),
		], 11, color_muted)
		if index < perks.size() - 1:
			_add_thin_separator(parent)


func _add_selected_flaws_summary(parent: VBoxContainer) -> void:
	var flaws := rules.selected_flaws(character)
	if flaws.is_empty():
		_add_text(parent, "No flaws selected.", 14, color_muted)
		return

	for index in range(flaws.size()):
		var flaw: Dictionary = flaws[index]
		_add_text(parent, "%s  +%d SP" % [
			String(flaw.get("name", "")),
			rules._as_int(flaw.get("bonus", 0)),
		], 15, color_text)
		_add_text(parent, "%s Source: %s" % [
			String(flaw.get("summary", "")),
			String(flaw.get("source", "")),
		], 11, color_muted)
		if index < flaws.size() - 1:
			_add_thin_separator(parent)


func _add_mutation_summary_panel(parent: VBoxContainer, rows: Array, kind: String, mutation_summary: Dictionary) -> void:
	var is_drawback := kind == "drawback"
	var distribution_label := String(mutation_summary.get("drawback_distribution_label" if is_drawback else "advantage_distribution_label", "None"))
	var used_key := "drawback_points_used" if is_drawback else "advantage_points_used"
	var remaining_key := "drawback_points_remaining" if is_drawback else "advantage_points_remaining"
	_add_metric(parent, "Distribution", distribution_label)
	_add_metric(parent, "Points Used/Available", "%d/%d" % [
		rules._as_int(mutation_summary.get(used_key, 0)),
		rules._as_int(mutation_summary.get(remaining_key, 0)),
	])

	if rows.is_empty():
		_add_text(parent, "None selected.", 14, color_muted)
		return
	for index in range(rows.size()):
		var mutation: Dictionary = rows[index]
		_add_mutation_summary_row(parent, mutation)
		if index < rows.size() - 1:
			_add_thin_separator(parent)


func _add_mutation_summary_row(parent: VBoxContainer, mutation: Dictionary) -> void:
	var related_ability := String(mutation.get("related_ability", ""))
	_add_text(parent, String(mutation.get("name", "Mutation")), 15, color_text)
	_add_text(parent, "%s  |  %d points%s" % [
		String(mutation.get("tier", "")),
		rules._as_int(mutation.get("points", 0)),
		"  |  %s" % related_ability if not related_ability.is_empty() else "",
	], 12, color_muted)
	_add_text(parent, String(mutation.get("summary", "")), 13, color_text)
	_add_text(parent, String(mutation.get("reference", "")), 11, color_muted)


func _enabled_optional_rules_label() -> String:
	var enabled := []
	for rule in AlternityRules.OPTIONAL_RULES:
		var rule_id := String(rule.get("id", ""))
		if rules.optional_rule_enabled(character, rule_id):
			enabled.append(String(rule.get("name", "")))
	return "Standard" if enabled.is_empty() else ", ".join(enabled)


func _save_character() -> void:
	if notes_editing:
		character["notes"] = notes_draft
	var safe_name := _safe_filename(String(character.get("hero_name", "hero")))
	if safe_name.is_empty():
		safe_name = "hero"
	
	var filename := safe_name + ".json"
	var path := "user://" + filename
	
	# If active character name changed, delete the old file to avoid duplicates
	if not active_character_file.is_empty() and active_character_file != filename:
		var old_path := "user://" + active_character_file
		if FileAccess.file_exists(old_path) and old_path != path:
			DirAccess.remove_absolute(old_path)
			
	active_character_file = filename
	
	# Persist last active character reference
	var tracker := FileAccess.open("user://last_character.txt", FileAccess.WRITE)
	if tracker != null:
		tracker.store_string(filename)
		
	var payload := character.duplicate(true)
	payload["summary"] = rules.summary(character)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		if is_instance_valid(save_status_label):
			save_status_label.text = "Save failed."
			save_status_label.add_theme_color_override("font_color", color_warning)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	if is_instance_valid(save_status_label):
		save_status_label.text = ProjectSettings.globalize_path(path)
		save_status_label.add_theme_color_override("font_color", color_accent)


func _close_character() -> void:
	if not active_character_file.is_empty():
		_save_character()
	active_character_file = ""
	
	var last_char_path := "user://last_character.txt"
	if FileAccess.file_exists(last_char_path):
		DirAccess.remove_absolute(last_char_path)
		
	active_tab = "Basics"
	_render()


func _create_new_character() -> void:
	character = rules.default_character()
	rules.ensure_character_shape(character)
	
	var base_name := "New Hero"
	var safe_name := _safe_filename(base_name)
	var final_filename := safe_name + ".json"
	
	var counter := 1
	while FileAccess.file_exists("user://" + final_filename):
		counter += 1
		final_filename = "%s_%d.json" % [safe_name, counter]
		
	var display_name := base_name
	if counter > 1:
		display_name = "%s %d" % [base_name, counter]
	character["hero_name"] = display_name
	
	active_character_file = final_filename
	_save_character()
	active_tab = "Basics"
	_render()


func _get_saved_characters() -> Array:
	var saved := []
	var dir := DirAccess.open("user://")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json") and file_name != "last_character.txt":
				var path := "user://" + file_name
				var file := FileAccess.open(path, FileAccess.READ)
				if file != null:
					var content_str := file.get_as_text()
					var json := JSON.new()
					var err := json.parse(content_str)
					if err == OK:
						var data_parsed = json.get_data()
						if typeof(data_parsed) == TYPE_DICTIONARY:
							var hero_name := String(data_parsed.get("hero_name", "New Hero"))
							var species_id := rules._as_int(data_parsed.get("species_id", 0))
							var profession_id := rules._as_int(data_parsed.get("profession_id", 0))
							var summary: Dictionary = data_parsed.get("summary", {})
							var level := rules._as_int(summary.get("achievement_level", 1))
							if level == 1:
								level = rules._as_int(data_parsed.get("achievement_level", 1))
							
							var mod_time := FileAccess.get_modified_time(path)
							saved.append({
								"file_name": file_name,
								"hero_name": hero_name,
								"species_id": species_id,
								"profession_id": profession_id,
								"level": level,
								"mod_time": mod_time
							})
			file_name = dir.get_next()
	saved.sort_custom(func(a, b): return a["mod_time"] > b["mod_time"])
	return saved


func _render_character_select() -> void:
	var main_box := VBoxContainer.new()
	main_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_box.add_theme_constant_override("separation", 20)
	content.add_child(main_box)

	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", _flat_style(color_surface, Color(0, 0, 0, 0), 8))
	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_box.add_child(banner)

	var banner_margin := MarginContainer.new()
	banner_margin.add_theme_constant_override("margin_top", 16)
	banner_margin.add_theme_constant_override("margin_bottom", 16)
	banner_margin.add_theme_constant_override("margin_left", 16)
	banner_margin.add_theme_constant_override("margin_right", 16)
	banner.add_child(banner_margin)

	var banner_box := VBoxContainer.new()
	banner_box.add_theme_constant_override("separation", 6)
	banner_margin.add_child(banner_box)

	var welcome_label := Label.new()
	welcome_label.text = "Character Selection"
	welcome_label.add_theme_font_size_override("font_size", 20)
	welcome_label.add_theme_color_override("font_color", color_accent)
	banner_box.add_child(welcome_label)

	var welcome_desc := Label.new()
	welcome_desc.text = "Manage your saved Alternity heroes or create a new one to begin your adventure."
	welcome_desc.add_theme_font_size_override("font_size", 13)
	welcome_desc.add_theme_color_override("font_color", color_muted)
	welcome_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_box.add_child(welcome_desc)

	var actions_bar := HBoxContainer.new()
	actions_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	main_box.add_child(actions_bar)

	var create_btn := Button.new()
	create_btn.text = "Create New Hero"
	create_btn.custom_minimum_size = Vector2(200, 44)
	create_btn.add_theme_font_size_override("font_size", 14)
	create_btn.add_theme_stylebox_override("normal", _flat_style(color_accent, Color(0, 0, 0, 0), 8))
	create_btn.add_theme_stylebox_override("hover", _flat_style(color_accent.lightened(0.15), Color(0, 0, 0, 0), 8))
	create_btn.add_theme_stylebox_override("pressed", _flat_style(color_accent.darkened(0.15), Color(0, 0, 0, 0), 8))
	create_btn.add_theme_color_override("font_color", color_background)
	create_btn.add_theme_color_override("font_hover_color", color_background)
	create_btn.add_theme_color_override("font_pressed_color", color_background)
	create_btn.pressed.connect(_create_new_character)
	actions_bar.add_child(create_btn)

	var saved_heroes := _get_saved_characters()

	var list_header := Label.new()
	list_header.text = "Saved Heroes" if not saved_heroes.is_empty() else ""
	list_header.add_theme_font_size_override("font_size", 15)
	list_header.add_theme_color_override("font_color", color_text)
	main_box.add_child(list_header)

	if saved_heroes.is_empty():
		var empty_panel := PanelContainer.new()
		empty_panel.add_theme_stylebox_override("panel", _flat_style(Color(0, 0, 0, 0), color_border, 8))
		empty_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_box.add_child(empty_panel)

		var empty_margin := MarginContainer.new()
		empty_margin.add_theme_constant_override("margin_top", 32)
		empty_margin.add_theme_constant_override("margin_bottom", 32)
		empty_panel.add_child(empty_margin)

		var empty_label := Label.new()
		empty_label.text = "No saved heroes found. Click the button above to create one!"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.add_theme_color_override("font_color", color_muted)
		empty_margin.add_child(empty_label)
		return

	var grid := GridContainer.new()
	grid.columns = 2 if is_wide_layout else 1
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	main_box.add_child(grid)

	for hero in saved_heroes:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _flat_style(color_surface, color_border, 8, true))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)

		var card_margin := MarginContainer.new()
		card_margin.add_theme_constant_override("margin_top", 12)
		card_margin.add_theme_constant_override("margin_bottom", 12)
		card_margin.add_theme_constant_override("margin_left", 14)
		card_margin.add_theme_constant_override("margin_right", 14)
		card.add_child(card_margin)

		var card_box := VBoxContainer.new()
		card_box.add_theme_constant_override("separation", 6)
		card_margin.add_child(card_box)

		var name_label := Label.new()
		name_label.text = hero["hero_name"]
		name_label.add_theme_font_size_override("font_size", 17)
		name_label.add_theme_color_override("font_color", color_text)
		card_box.add_child(name_label)

		var species := rules.get_species_by_id(hero["species_id"])
		var profession := rules.get_profession_by_id(hero["profession_id"])
		var spec_label := Label.new()
		spec_label.text = "Level %d  |  %s %s" % [
			hero["level"],
			String(species.get("name", "Unknown Species")),
			String(profession.get("name", "Unknown Profession"))
		]
		spec_label.add_theme_font_size_override("font_size", 12)
		spec_label.add_theme_color_override("font_color", color_muted)
		card_box.add_child(spec_label)

		var time_str := Time.get_datetime_string_from_unix_time(hero["mod_time"], true)
		var time_parts := time_str.split(":")
		if time_parts.size() >= 2:
			time_str = time_parts[0] + ":" + time_parts[1]

		var date_label := Label.new()
		date_label.text = "Saved: " + time_str
		date_label.add_theme_font_size_override("font_size", 11)
		date_label.add_theme_color_override("font_color", color_muted)
		card_box.add_child(date_label)

		var btn_spacer := Control.new()
		btn_spacer.custom_minimum_size = Vector2(1, 4)
		card_box.add_child(btn_spacer)

		var file_name: String = hero["file_name"]
		if deleting_files.has(file_name):
			var conf_row := HBoxContainer.new()
			conf_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			conf_row.add_theme_constant_override("separation", 10)
			card_box.add_child(conf_row)

			var warning_lbl := Label.new()
			warning_lbl.text = "Delete? "
			warning_lbl.add_theme_font_size_override("font_size", 12)
			warning_lbl.add_theme_color_override("font_color", color_warning)
			conf_row.add_child(warning_lbl)

			var yes_btn := Button.new()
			yes_btn.text = "Yes"
			yes_btn.custom_minimum_size = Vector2(56, 32)
			yes_btn.add_theme_font_size_override("font_size", 12)
			yes_btn.add_theme_stylebox_override("normal", _flat_style(color_warning, Color(0, 0, 0, 0), 6))
			yes_btn.add_theme_stylebox_override("hover", _flat_style(color_warning.lightened(0.15), Color(0, 0, 0, 0), 6))
			yes_btn.add_theme_stylebox_override("pressed", _flat_style(color_warning.darkened(0.15), Color(0, 0, 0, 0), 6))
			yes_btn.add_theme_color_override("font_color", color_text)
			yes_btn.pressed.connect(func():
				var path := "user://" + file_name
				if FileAccess.file_exists(path):
					DirAccess.remove_absolute(path)
				if active_character_file == file_name:
					active_character_file = ""
					var tracker_path := "user://last_character.txt"
					if FileAccess.file_exists(tracker_path):
						DirAccess.remove_absolute(tracker_path)
				deleting_files.erase(file_name)
				_render()
			)
			conf_row.add_child(yes_btn)

			var cancel_btn := Button.new()
			cancel_btn.text = "Cancel"
			cancel_btn.custom_minimum_size = Vector2(70, 32)
			cancel_btn.add_theme_font_size_override("font_size", 12)
			cancel_btn.add_theme_stylebox_override("normal", _flat_style(color_surface_soft, Color(0, 0, 0, 0), 6))
			cancel_btn.add_theme_stylebox_override("hover", _flat_style(color_surface_soft.lightened(0.1), Color(0, 0, 0, 0), 6))
			cancel_btn.add_theme_stylebox_override("pressed", _flat_style(color_surface_soft.darkened(0.1), Color(0, 0, 0, 0), 6))
			cancel_btn.add_theme_color_override("font_color", color_text)
			cancel_btn.pressed.connect(func():
				deleting_files.erase(file_name)
				_render()
			)
			conf_row.add_child(cancel_btn)
		else:
			var act_row := HBoxContainer.new()
			act_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			act_row.add_theme_constant_override("separation", 10)
			card_box.add_child(act_row)

			var load_btn := Button.new()
			load_btn.text = "Load Hero"
			load_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			load_btn.custom_minimum_size = Vector2(0, 32)
			load_btn.add_theme_font_size_override("font_size", 12)
			load_btn.add_theme_stylebox_override("normal", _flat_style(color_surface_soft, color_accent, 6))
			load_btn.add_theme_stylebox_override("hover", _flat_style(color_surface_soft.lightened(0.1), color_accent, 6))
			load_btn.add_theme_stylebox_override("pressed", _flat_style(color_accent, Color(0,0,0,0), 6))
			load_btn.add_theme_color_override("font_color", color_text)
			load_btn.add_theme_color_override("font_pressed_color", color_background)
			load_btn.pressed.connect(func():
				if _load_character_from_file(file_name):
					var tracker := FileAccess.open("user://last_character.txt", FileAccess.WRITE)
					if tracker != null:
						tracker.store_string(file_name)
					active_tab = "Basics"
					_render()
			)
			act_row.add_child(load_btn)

			var del_btn := Button.new()
			del_btn.text = "Delete"
			del_btn.custom_minimum_size = Vector2(70, 32)
			del_btn.add_theme_font_size_override("font_size", 12)
			del_btn.add_theme_stylebox_override("normal", _flat_style(color_surface_soft, color_warning, 6))
			del_btn.add_theme_stylebox_override("hover", _flat_style(color_surface_soft.lightened(0.1), color_warning, 6))
			del_btn.add_theme_stylebox_override("pressed", _flat_style(color_warning, Color(0,0,0,0), 6))
			del_btn.add_theme_color_override("font_color", color_text)
			del_btn.pressed.connect(func():
				deleting_files[file_name] = true
				_render()
			)
			act_row.add_child(del_btn)


func _safe_filename(value: String) -> String:
	var safe := value.strip_edges().replace(" ", "_")
	for character_to_replace in ["<", ">", ":", "\"", "/", "\\", "|", "?", "*"]:
		safe = safe.replace(character_to_replace, "_")
	return safe


func _add_columns(left_ratio := 0.5) -> Array:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	content.add_child(row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = left_ratio
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = max(0.1, 1.0 - left_ratio)
	right.add_theme_constant_override("separation", 10)
	row.add_child(right)

	return [left, right]


func _add_section(title: String) -> VBoxContainer:
	return _add_section_to(content, title)


func _add_section_to(parent: Container, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _flat_style(color_surface, color_border, 8, true))
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var label := Label.new()
	label.text = title
	label.add_theme_color_override("font_color", color_text)
	label.add_theme_font_size_override("font_size", 18)
	box.add_child(label)

	return box


func _add_form_cell(parent: Container, label_text: String, control: Control) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)
	_add_field(box, label_text, control)


func _add_form_line_edit(parent: Container, label_text: String, value: String, changed: Callable) -> void:
	var edit := LineEdit.new()
	edit.text = value
	edit.text_changed.connect(changed)
	_add_form_cell(parent, label_text, edit)


func _add_form_number_input(parent: Container, label_text: String, value: int, minimum: int, maximum: int, changed: Callable) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = str(clampi(value, minimum, maximum))
	edit.placeholder_text = str(minimum)
	edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var state := {"value": clampi(value, minimum, maximum)}
	edit.text_changed.connect(func(text):
		state["value"] = _number_input_value(text, rules._as_int(state.get("value", value)), minimum, maximum)
		changed.call(state["value"])
	)
	edit.text_submitted.connect(func(_text):
		edit.text = str(rules._as_int(state.get("value", value)))
	)
	edit.focus_exited.connect(func():
		edit.text = str(rules._as_int(state.get("value", value)))
	)
	_add_form_cell(parent, label_text, edit)
	return edit


func _add_form_float_input(parent: Container, label_text: String, value: float, changed: Callable) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = _format_number(value)
	edit.placeholder_text = "0"
	edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var state := {"value": maxf(0.0, value)}
	edit.text_changed.connect(func(text):
		var stripped := String(text).strip_edges()
		if stripped.is_valid_float():
			state["value"] = maxf(0.0, float(stripped))
			changed.call(state["value"])
	)
	edit.text_submitted.connect(func(_text):
		edit.text = _format_number(rules._as_float(state.get("value", value)))
	)
	edit.focus_exited.connect(func():
		edit.text = _format_number(rules._as_float(state.get("value", value)))
	)
	_add_form_cell(parent, label_text, edit)
	return edit


func _add_field(parent: Container, label_text: String, control: Control) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", color_muted)
	label.add_theme_font_size_override("font_size", 12)
	parent.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size = Vector2(0, 42)
	parent.add_child(control)


func _add_line_edit(parent: VBoxContainer, label_text: String, value: String, changed: Callable) -> void:
	var edit := LineEdit.new()
	edit.text = value
	edit.text_changed.connect(changed)
	_add_field(parent, label_text, edit)


func _add_readonly_number_pair(parent: VBoxContainer, left_label_text: String, left_value: int, right_label_text: String, right_value: int) -> Array:
	var row: BoxContainer
	if get_viewport_rect().size.x < COMPACT_WIDTH:
		row = VBoxContainer.new()
	else:
		row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var left_edit := _add_readonly_number_cell(row, left_label_text, left_value)
	var right_edit := _add_readonly_number_cell(row, right_label_text, right_value)
	return [left_edit, right_edit]


func _add_readonly_number_cell(parent: BoxContainer, label_text: String, value: int) -> LineEdit:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)

	var label := Label.new()
	label.text = label_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(1, 0)
	label.add_theme_color_override("font_color", color_muted)
	label.add_theme_font_size_override("font_size", 12)
	box.add_child(label)

	var edit := LineEdit.new()
	edit.text = str(value)
	edit.editable = false
	edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0, 42)
	box.add_child(edit)
	return edit


func _add_number_input(parent: Container, label_text: String, value: int, minimum: int, maximum: int, changed: Callable) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = str(clampi(value, minimum, maximum))
	edit.placeholder_text = str(minimum)
	edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var state := {"value": clampi(value, minimum, maximum)}
	edit.text_changed.connect(func(text):
		state["value"] = _number_input_value(text, rules._as_int(state.get("value", value)), minimum, maximum)
		changed.call(state["value"])
	)
	edit.text_submitted.connect(func(_text):
		edit.text = str(rules._as_int(state.get("value", value)))
	)
	edit.focus_exited.connect(func():
		edit.text = str(rules._as_int(state.get("value", value)))
	)
	_add_field(parent, label_text, edit)
	return edit


func _add_float_input(parent: VBoxContainer, label_text: String, value: float, changed: Callable) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = _format_number(value)
	edit.placeholder_text = "0"
	edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var state := {"value": maxf(0.0, value)}
	edit.text_changed.connect(func(text):
		var stripped := String(text).strip_edges()
		if stripped.is_valid_float():
			state["value"] = maxf(0.0, float(stripped))
			changed.call(state["value"])
	)
	edit.text_submitted.connect(func(_text):
		edit.text = _format_number(rules._as_float(state.get("value", value)))
	)
	edit.focus_exited.connect(func():
		edit.text = _format_number(rules._as_float(state.get("value", value)))
	)
	_add_field(parent, label_text, edit)
	return edit


func _number_input_value(text: String, fallback: int, minimum: int, maximum: int) -> int:
	var stripped := text.strip_edges()
	if stripped.is_empty() or not stripped.is_valid_int():
		return clampi(fallback, minimum, maximum)
	return clampi(int(stripped), minimum, maximum)


func _format_number(value: float) -> String:
	if is_equal_approx(value, float(int(value))):
		return str(int(value))
	return "%.2f" % value


func _add_number_stepper(parent: VBoxContainer, label_text: String, value: int, minimum: int, maximum: int, changed: Callable) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", color_muted)
	label.add_theme_font_size_override("font_size", 12)
	parent.add_child(label)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var minus := Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(42, 38)
	minus.disabled = value <= minimum
	minus.pressed.connect(func():
		changed.call(clampi(value - 1, minimum, maximum))
		_render()
	)
	row.add_child(minus)

	var value_label := Label.new()
	value_label.text = str(value)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.custom_minimum_size = Vector2(0, 38)
	value_label.add_theme_color_override("font_color", color_text)
	value_label.add_theme_font_size_override("font_size", 18)
	row.add_child(value_label)

	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(42, 38)
	plus.disabled = value >= maximum
	plus.pressed.connect(func():
		changed.call(clampi(value + 1, minimum, maximum))
		_render()
	)
	row.add_child(plus)


func _add_text(parent: Container, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(1, 0)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _add_indented_text(parent: VBoxContainer, text: String, font_size: int, color: Color) -> Label:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 14)
	parent.add_child(margin)
	return _add_text(margin, text, font_size, color)


func _add_rich_note(parent: VBoxContainer, text: String, font_size: int, color: Color) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.selection_enabled = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(1, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_font_size_override("bold_font_size", font_size)
	label.add_theme_color_override("default_color", color)
	label.text = _format_note_bbcode(text)
	parent.add_child(label)
	return label


func _format_note_bbcode(text: String) -> String:
	var rank_index := text.find(" rank ")
	var separator_index := text.find(":")
	var source_index := text.find("Source:")
	if source_index >= 0 and separator_index >= source_index:
		separator_index = -1
	if rank_index > 0 and separator_index > rank_index:
		return "[b]%s[/b]%s" % [
			_escape_bbcode(text.substr(0, rank_index)),
			_escape_bbcode(text.substr(rank_index)),
		]
	if separator_index > 0:
		return "[b]%s[/b]%s" % [
			_escape_bbcode(text.substr(0, separator_index)),
			_escape_bbcode(text.substr(separator_index)),
		]
	return _escape_bbcode(text)


func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")


func _add_subheading(parent: VBoxContainer, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", color_text)
	parent.add_child(label)
	return label


func _add_metric(parent: VBoxContainer, name: String, value: String) -> void:
	var row: BoxContainer
	if get_viewport_rect().size.x < COMPACT_WIDTH:
		row = VBoxContainer.new()
	else:
		row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var name_label := Label.new()
	name_label.text = name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", color_muted)
	name_label.add_theme_font_size_override("font_size", 13)
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if row is VBoxContainer else HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.custom_minimum_size = Vector2(1, 0)
	value_label.add_theme_color_override("font_color", color_text)
	value_label.add_theme_font_size_override("font_size", 13)
	row.add_child(value_label)


func _add_progress_metric(parent: VBoxContainer, name: String, current: float, maximum: float, value_text: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)

	var label_row := HBoxContainer.new()
	label_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(label_row)

	var name_label := Label.new()
	name_label.text = name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", color_muted)
	name_label.add_theme_font_size_override("font_size", 13)
	label_row.add_child(name_label)

	var value_label := Label.new()
	value_label.text = value_text
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", color_text)
	value_label.add_theme_font_size_override("font_size", 14)
	label_row.add_child(value_label)

	var progress := ProgressBar.new()
	progress.max_value = maximum
	progress.value = current
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(0, 6)
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = color_accent
	sb.set_corner_radius_all(3)
	var bg := StyleBoxFlat.new()
	bg.bg_color = color_border
	bg.set_corner_radius_all(3)
	progress.add_theme_stylebox_override("fill", sb)
	progress.add_theme_stylebox_override("background", bg)
	box.add_child(progress)

func _add_compact_abilities(parent: VBoxContainer) -> void:
	var title := Label.new()
	title.text = "Abilities"
	title.add_theme_color_override("font_color", color_muted)
	title.add_theme_font_size_override("font_size", 12)
	parent.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 5)
	parent.add_child(grid)

	for header_text in ["Ability", "Score", "Untr.", "RM"]:
		_add_ability_summary_cell(grid, header_text, true)

	var abilities: Dictionary = character.get("abilities", {})
	var effective_abilities := rules.effective_abilities(character)
	for ability in AlternityRules.ABILITIES:
		var base_score := rules._as_int(abilities.get(ability, 0))
		var score := rules._as_int(effective_abilities.get(ability, base_score))
		var score_text := str(score) if score == base_score else "%d (%d+%d)" % [score, base_score, score - base_score]
		_add_ability_summary_cell(grid, ability, false)
		_add_ability_summary_cell(grid, score_text, false)
		_add_ability_summary_cell(grid, str(rules.untrained_score(score)), false)
		_add_ability_summary_cell(grid, "%+d" % rules.resistance_modifier(score), false)


func _add_ability_summary_cell(parent: GridContainer, text: String, header_cell: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(1, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", color_muted if header_cell else color_text)
	label.add_theme_font_size_override("font_size", 10 if header_cell else 11)
	parent.add_child(label)
	return label


func _add_large_checkbox(parent: Container, label_text: String, is_checked: bool, changed: Callable) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color_text)
	var button := Button.new()
	button.toggle_mode = true
	button.button_pressed = is_checked
	button.text = "✔" if is_checked else ""
	button.custom_minimum_size = Vector2(24, 24)
	button.add_theme_stylebox_override("normal", _flat_style(color_surface, color_border, 4))
	button.add_theme_stylebox_override("hover", _flat_style(color_surface_soft, color_border, 4))
	button.add_theme_stylebox_override("pressed", _flat_style(color_accent, color_accent, 4))
	button.toggled.connect(func(c):
		button.text = "✔" if c else ""
		changed.call(c)
	)
	row.add_child(label)
	row.add_child(button)
	parent.add_child(row)


func _add_tracker_row(parent: VBoxContainer, name: String, total: int, used: int, changed: Callable) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)

	var label := Label.new()
	label.text = "%s  %d / %d" % [name, used, total]
	label.add_theme_color_override("font_color", color_muted)
	label.add_theme_font_size_override("font_size", 13)
	box.add_child(label)

	if total <= 0:
		_add_text(box, "None", 13, color_muted)
		return

	var grid := GridContainer.new()
	grid.columns = 8 if get_viewport_rect().size.x < COMPACT_WIDTH else 12
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)

	for index in range(total):
		var box_number := index + 1
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = box_number <= used
		button.text = ""
		button.tooltip_text = "%s box %d" % [name, box_number]
		button.custom_minimum_size = Vector2(24, 24)
		button.add_theme_stylebox_override("normal", _flat_style(color_surface, color_border, 4))
		button.add_theme_stylebox_override("hover", _flat_style(color_surface_soft, color_border, 4))
		button.add_theme_stylebox_override("pressed", _flat_style(color_warning, color_warning, 4))
		button.pressed.connect(func():
			var next_used := box_number
			if box_number == used:
				next_used = box_number - 1
			changed.call(next_used)
		)
		grid.add_child(button)


func _flat_style(background: Color, border: Color, radius: int, shadow: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_corner_radius_all(radius)
	if border.a > 0.0:
		style.border_color = border
		style.set_border_width_all(1)
	else:
		style.set_border_width_all(0)
	if shadow:
		style.shadow_color = Color(0, 0, 0, 0.4)
		style.shadow_size = 8
		style.shadow_offset = Vector2(0, 4)
	return style


func _tab_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := _flat_style(background, border, radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

var theme_btn: Button
var theme_overlay: Control
var theme_panel: PanelContainer
var theme_body: VBoxContainer

func _setup_theme() -> void:
	if not Engine.is_editor_hint() and has_node("/root/ThemeManager"):
		var tm = get_node("/root/ThemeManager")
		if tm.theme_changed.is_connected(_on_theme_changed):
			return
		tm.theme_changed.connect(_on_theme_changed)
		_on_theme_changed()
	else:
		color_background = Color(0.05, 0.07, 0.10)
		color_surface = Color(0.10, 0.12, 0.16)
		color_surface_soft = Color(0.15, 0.18, 0.22)
		color_text = Color(0.90, 0.92, 0.95)
		color_muted = Color(0.50, 0.55, 0.60)
		color_accent = Color(0.00, 0.80, 0.80)
		color_warning = Color(0.90, 0.30, 0.20)
		color_border = Color(0.20, 0.25, 0.30)

func _on_theme_changed() -> void:
	if has_node("/root/ThemeManager"):
		var tm = get_node("/root/ThemeManager")
		color_background = tm.get_theme_color("color_background")
		color_surface = tm.get_theme_color("color_surface")
		color_surface_soft = tm.get_theme_color("color_surface_soft")
		color_text = tm.get_theme_color("color_text")
		color_muted = tm.get_theme_color("color_muted")
		color_accent = tm.get_theme_color("color_accent")
		color_warning = tm.get_theme_color("color_warning")
		color_border = tm.get_theme_color("color_border")

		if background_rect != null:
			background_rect.color = color_background
		if title_label != null:
			title_label.add_theme_color_override("font_color", color_text)
		if status_label != null:
			status_label.add_theme_color_override("font_color", color_muted)

		# Update tab buttons
		for tab in tab_buttons.keys():
			var button = tab_buttons[tab]
			if button != null:
				button.add_theme_stylebox_override("normal", _tab_style(color_surface, Color(0, 0, 0, 0), 8))
				button.add_theme_stylebox_override("hover", _tab_style(color_surface_soft, Color(0, 0, 0, 0), 8))
				button.add_theme_stylebox_override("pressed", _tab_style(color_accent, Color(0, 0, 0, 0), 8))
				button.add_theme_stylebox_override("focus", _tab_style(color_surface_soft, color_accent, 8))
				button.add_theme_color_override("font_color", color_text)
				button.add_theme_color_override("font_pressed_color", color_background)

		# Update permanent overlay panels
		if optional_rules_panel != null:
			optional_rules_panel.add_theme_stylebox_override("panel", _flat_style(color_surface, color_border, 8))
		if skill_details_panel != null:
			skill_details_panel.add_theme_stylebox_override("panel", _flat_style(color_surface, color_border, 8))
		if equipment_form_panel != null:
			equipment_form_panel.add_theme_stylebox_override("panel", _flat_style(color_surface, color_border, 8))
		if achievement_form_panel != null:
			achievement_form_panel.add_theme_stylebox_override("panel", _flat_style(color_surface, color_border, 8))
		if perk_flaw_catalog_panel != null:
			perk_flaw_catalog_panel.add_theme_stylebox_override("panel", _flat_style(color_surface, color_border, 8))
		if mutation_catalog_panel != null:
			mutation_catalog_panel.add_theme_stylebox_override("panel", _flat_style(color_surface, color_border, 8))
		if theme_panel != null:
			theme_panel.add_theme_stylebox_override("panel", _flat_style(color_surface, color_border, 8))

		_refresh_theme_panel()
		if main_content != null:
			_render()

func _show_theme_selector() -> void:
	if not has_node("/root/ThemeManager"):
		return
	_refresh_theme_panel()
	theme_overlay.visible = true
	_update_theme_modal_height.call_deferred()
