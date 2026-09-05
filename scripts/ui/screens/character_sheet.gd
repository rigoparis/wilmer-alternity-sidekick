class_name CharacterSheetScreen
extends Control
##
## Tab bar plus the active tab. The sheet half of the app.
##
## Owns only routing and chrome. The old shell also owned every tab renderer,
## every overlay, the scroll offsets, the dirty flags and eight colour members;
## a tab here is a scene that receives a SheetContext and draws itself.
##
## Tabs are declared in TABS below rather than by a match statement over ten
## names. A tab that has not been migrated yet is simply absent from the list,
## which is what lets this run alongside the old UI while the rest move across.
##

## Content takes this many parts against one gutter each side.
const CONTENT_STRETCH := 8.0

## Leave the sheet and return to the character list.
signal closed

## Header icons. preload, not load: these are fixed assets, and the old header
## resolved them at runtime on every build.
const ICON_RULES := preload("res://assets/book.svg")
const ICON_THEME := preload("res://assets/pallete.svg")
const ICON_SHARE := preload("res://assets/share.svg")
const ICON_SAVE := preload("res://assets/diskette.svg")
const ICON_CLOSE := preload("res://assets/logout.svg")
const ICON_ATTACK := preload("res://assets/attack.svg")
const ICON_DICE := preload("res://assets/dice-d20.svg")

const TAB_BASICS := preload("res://scenes/ui/tabs/tab_basics.tscn")
const TAB_ACHIEVEMENTS := preload("res://scenes/ui/tabs/tab_achievements.tscn")
const TAB_EQUIPMENT := preload("res://scenes/ui/tabs/tab_equipment.tscn")
const TAB_MUTATIONS := preload("res://scenes/ui/tabs/tab_mutations.tscn")
const TAB_FX := preload("res://scenes/ui/tabs/tab_fx.tscn")
const TAB_SKILLS := preload("res://scenes/ui/tabs/tab_skills.tscn")
const TAB_PSIONICS := preload("res://scenes/ui/tabs/tab_psionics.tscn")
const TAB_SUMMARY := preload("res://scenes/ui/tabs/tab_summary.tscn")
const TAB_TABLE := preload("res://scenes/ui/tabs/tab_table.tscn")

const OPTIONAL_RULES_ROUTE := preload("res://scenes/ui/routes/optional_rules_route.tscn")
const THEME_ROUTE := preload("res://scenes/ui/routes/theme_route.tscn")
const TAB_CYBERTECH := preload("res://scenes/ui/tabs/tab_cybertech.tscn")
const TAB_PERKS_FLAWS := preload("res://scenes/ui/tabs/tab_perks_flaws.tscn")

## All ten tabs, in display order. A tab may still exclude itself for a given
## character -- Mutations and Psionics both do -- see _available_tabs().
const TABS := [
	{"id": "basics", "label": "Basics", "scene": TAB_BASICS},
	{"id": "skills", "label": "Skills", "scene": TAB_SKILLS},
	{"id": "perks_flaws", "label": "Perks/Flaws", "scene": TAB_PERKS_FLAWS},
	{"id": "cybertech", "label": "Cybertech", "scene": TAB_CYBERTECH},
	{"id": "equipment", "label": "Equipment", "scene": TAB_EQUIPMENT},
	{"id": "achievements", "label": "Achievements", "scene": TAB_ACHIEVEMENTS},
	{"id": "psionics", "label": "Psionics", "scene": TAB_PSIONICS},
	{"id": "fx", "label": "FX", "scene": TAB_FX},
	{"id": "mutations", "label": "Mutations", "scene": TAB_MUTATIONS},
	{"id": "summary", "label": "Summary", "scene": TAB_SUMMARY},
	# Last, and only present while this device is at somebody's table. A player
	# in a campaign is still playing their character, so the table sits beside
	# the sheet rather than replacing it.
	{"id": "table", "label": "Table", "scene": TAB_TABLE},
]

var _ctx: SheetContext
var _store: CharacterStore

var _title: Label
var _status: Label
var _tab_bar: HBoxContainer
var _content_scroll: ScrollContainer
var _content_host: VBoxContainer

var _buttons: Dictionary = {}
var _instances: Dictionary = {}
var _active_id: String = ""

enum BannerType { NONE, ATTACK, ACTION_CHECK, CALLED_CHECK, YOUR_TURN, NOTIFICATION }

var _banner_container: MarginContainer
var _banner_card: PanelContainer
var _banner_icon: TextureRect
var _banner_label: Label
var _banner_roll_btn: Button
var _banner_dismiss_btn: Button
var _current_banner_type: BannerType = BannerType.NONE
var _current_banner_check: SkillCheck = null
var _current_banner_attack: CombatAttack = null
var _notifications: Array[Dictionary] = []
var _current_notification: Dictionary = {}

## Tab ids currently in the bar, so a rebuild only happens when the set changes.
var _listed_ids: Array = []


func setup(ctx: SheetContext, store: CharacterStore) -> void:
	_ctx = ctx
	_store = store
	_build()

	if _ctx.doc != null:
		_ctx.doc.changed.connect(_on_document_changed)
		_ctx.doc.dirty_changed.connect(_on_dirty_changed)

	if _ctx.table != null:
		_ctx.table.check_arrived.connect(_on_table_check_arrived)
		_ctx.table.attack_arrived.connect(_on_table_attack_arrived)
		_ctx.table.attack_resolved.connect(_on_table_attack_resolved)
		_ctx.table.ap_applied.connect(_on_table_ap_applied)
		_ctx.table.scene_ended.connect(_on_table_scene_ended)
		_ctx.table.trouble.connect(_on_table_trouble)
		_ctx.table.round_changed.connect(_on_table_round_changed)
		_ctx.table.action_check_wanted.connect(_on_table_action_check_wanted)
		_ctx.table.changed.connect(_on_table_changed)

	var available := _available_tabs()
	if not available.is_empty():
		_select_tab(String(available[0]["id"]))
	_refresh_header()
	_refresh_incoming_banner()
	_refresh_tab_badges()


## Which tab is showing, so a rebuild can put you back on it.
func active_tab_id() -> String:
	return _active_id


## Reselect a tab after a rebuild, ignoring one that no longer applies.
func restore_tab(id: String) -> void:
	if id.is_empty() or not _buttons.has(id):
		return
	_select_tab(id)


func document() -> CharacterDoc:
	return null if _ctx == null else _ctx.doc


func _build() -> void:
	var root_box := VBoxContainer.new()
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_box.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	add_child(root_box)

	_build_header(root_box)
	_build_incoming_banner(root_box)
	_build_tab_bar(root_box)

	_content_scroll = ScrollContainer.new()
	_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_box.add_child(_content_scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.PAD_PANEL)
	_content_scroll.add_child(margin)

	# Content is centred inside proportional spacers rather than filling the
	# window. A row spanning 1900px puts its label at one edge of the screen and
	# its value at the other, which is unreadable however much space it "uses".
	#
	# Proportional rather than a fixed cap on purpose: Godot 4.6 has no
	# custom_maximum_size (that is 4.7), and the shell only rebuilds when the
	# compact breakpoint is crossed, so an absolute margin computed at build time
	# would not follow an ordinary resize. Stretch ratios do.
	var centred: Container = margin
	if _ctx.is_wide_layout:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin.add_child(row)
		row.add_child(_gutter())
		var body := VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.size_flags_stretch_ratio = CONTENT_STRETCH
		row.add_child(body)
		row.add_child(_gutter())
		centred = body

	# A VBoxContainer, not a bare Control. A Control child anchored full-rect
	# reports no minimum size, so the ScrollContainer cannot measure it and the
	# tab ends up clipped against the top of the viewport. A container measures
	# its children, and it skips invisible ones -- which is exactly what is
	# wanted here, since every tab lives in it and only one is visible.
	_content_host = VBoxContainer.new()
	_content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centred.add_child(_content_host)


## One side of the reading gutter on a wide screen.
func _gutter() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 1.0
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _build_header(parent: Container) -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.PAD_PANEL)
	parent.add_child(margin)

	# The hero name and five text buttons do not fit across a 390px phone. On one
	# row the name was squeezed to its 1px minimum and wrapped to a single letter
	# per line, which grew the header to most of the screen and turned the
	# buttons into tall slabs. Compact stacks it: name first, actions beneath.
	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", Widgets.GAP_ROW)
	margin.add_child(outer)

	var title_row := HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	outer.add_child(title_row)

	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Ellipsis rather than wrap: a long hero name must never be able to grow the
	# header vertically the way wrapping let it.
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.custom_minimum_size = Vector2(1, 0)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", _ctx.palette.text)
	_title.add_theme_font_size_override("font_size", 22 if _ctx.is_wide_layout else 18)
	title_row.add_child(_title)

	_status = Label.new()
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", _ctx.palette.muted)
	_status.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	title_row.add_child(_status)

	# Wide keeps the single row it always had; compact gets its own row where the
	# five buttons share the width evenly instead of competing with the name.
	var actions := HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL if not _ctx.is_wide_layout else Control.SIZE_SHRINK_END
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", Widgets.GAP_ROW)
	if _ctx.is_wide_layout:
		title_row.add_child(actions)
	else:
		outer.add_child(actions)

	# Icons, as the old header had. Five words across the top of a phone is most
	# of the row; five glyphs is a strip. The status label beside them still
	# reports saved state in words, so nothing depends on reading the glyph.
	var buttons := [
		[ICON_RULES, "Optional rules", _open_optional_rules],
		[ICON_THEME, "Theme", _open_theme],
		[ICON_SHARE, "Share character", _share],
		[ICON_SAVE, "Save character", _save],
		[ICON_CLOSE, "Close character", _on_close_pressed],
	]
	for spec in buttons:
		var icon = spec[0]
		var label := String(spec[1])
		var button := Button.new()
		button.tooltip_text = label
		if icon != null:
			button.icon = icon
			button.expand_icon = true
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			button.custom_minimum_size = Vector2(44, 44)
			# Tinted rather than coloured art, so icons follow the palette.
			button.add_theme_color_override("icon_normal_color", _ctx.palette.text)
			button.add_theme_color_override("icon_hover_color", _ctx.palette.accent)
			button.add_theme_color_override("icon_pressed_color", _ctx.palette.accent)
		else:
			# Wide enough to hold its own label. clip_text takes the text out of
			# the minimum size, so without a width the button renders as an
			# empty gap between the icons.
			button.text = label
			button.custom_minimum_size = Vector2(64, 44)
		button.pressed.connect(spec[2])
		actions.add_child(button)


func _build_incoming_banner(parent: Container) -> void:
	_banner_container = MarginContainer.new()
	_banner_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		_banner_container.add_theme_constant_override("margin_" + side, Widgets.PAD_PANEL)
	parent.add_child(_banner_container)

	_banner_card = PanelContainer.new()
	_banner_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_banner_card.add_theme_stylebox_override("panel", Widgets.flat_style(_ctx.palette.surface_soft, _ctx.palette.accent, 8, true))
	_banner_container.add_child(_banner_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", Widgets.PAD_PANEL)
	margin.add_theme_constant_override("margin_right", Widgets.PAD_PANEL)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_banner_card.add_child(margin)

	_banner_icon = TextureRect.new()
	_banner_icon.custom_minimum_size = Vector2(24, 24)
	_banner_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_banner_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_banner_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_banner_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	_banner_label = Label.new()
	_banner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_label.custom_minimum_size = Vector2(1, 0)
	_banner_label.add_theme_color_override("font_color", _ctx.palette.text)
	_banner_label.add_theme_font_size_override("font_size", Widgets.FONT_BODY)

	_banner_roll_btn = Button.new()
	_banner_roll_btn.text = "Roll Now"
	_banner_roll_btn.custom_minimum_size = Vector2(0, 36)
	_banner_roll_btn.pressed.connect(_on_banner_roll_pressed)

	_banner_dismiss_btn = Button.new()
	_banner_dismiss_btn.text = "Dismiss"
	_banner_dismiss_btn.custom_minimum_size = Vector2(0, 36)
	_banner_dismiss_btn.pressed.connect(_on_banner_dismiss_pressed)

	if _ctx.is_wide_layout:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", Widgets.GAP_ROW)
		margin.add_child(row)
		row.add_child(_banner_icon)
		row.add_child(_banner_label)
		row.add_child(_banner_roll_btn)
		row.add_child(_banner_dismiss_btn)
	else:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", Widgets.GAP_ROW)
		margin.add_child(col)

		var label_row := HBoxContainer.new()
		label_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label_row.add_theme_constant_override("separation", Widgets.GAP_ROW)
		col.add_child(label_row)
		label_row.add_child(_banner_icon)
		label_row.add_child(_banner_label)

		var btn_row := HBoxContainer.new()
		btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_row.alignment = BoxContainer.ALIGNMENT_END
		btn_row.add_theme_constant_override("separation", Widgets.GAP_ROW)
		col.add_child(btn_row)

		_banner_roll_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_banner_dismiss_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_row.add_child(_banner_roll_btn)
		btn_row.add_child(_banner_dismiss_btn)

	_refresh_incoming_banner()


func _refresh_incoming_banner() -> void:
	if _banner_container == null or not is_instance_valid(_banner_container):
		return
	if _ctx == null:
		_banner_container.visible = false
		_current_banner_type = BannerType.NONE
		_current_banner_check = null
		_current_banner_attack = null
		_current_notification = {}
		return

	# Priority 1: Incoming Attack waiting on player armor/damage resolution
	if _ctx.table != null and not _ctx.table.incoming_attacks.is_empty():
		var attack := _ctx.table.incoming_attacks[0] as CombatAttack
		if attack != null:
			_current_banner_type = BannerType.ATTACK
			_current_banner_attack = attack
			_current_banner_check = null
			_current_notification = {}
			var hits: bool = attack.hits()
			var border_color: Color = _ctx.palette.warning if hits else _ctx.palette.border
			_banner_card.add_theme_stylebox_override("panel", Widgets.flat_style(_ctx.palette.surface_soft, border_color, 8, true))

			_banner_roll_btn.remove_theme_stylebox_override("normal")
			_banner_roll_btn.add_theme_stylebox_override("normal", Widgets.flat_style(_ctx.palette.surface, _ctx.palette.warning if hits else _ctx.palette.accent, 6))
			_banner_roll_btn.add_theme_color_override("font_color", _ctx.palette.text)

			_banner_dismiss_btn.remove_theme_stylebox_override("normal")
			_banner_dismiss_btn.add_theme_stylebox_override("normal", Widgets.flat_style(_ctx.palette.surface, _ctx.palette.border, 6))
			_banner_dismiss_btn.add_theme_color_override("font_color", _ctx.palette.text)

			_banner_icon.texture = ICON_ATTACK
			_banner_icon.modulate = border_color

			if hits:
				_banner_label.text = "Attack incoming: %s" % attack.describe()
				_banner_roll_btn.text = "Resolve Armor"
				_banner_dismiss_btn.text = "Table"
			else:
				_banner_label.text = "Incoming: %s" % attack.describe()
				_banner_roll_btn.text = "Dismiss"
				_banner_dismiss_btn.text = "Table"

			_banner_roll_btn.visible = true
			_banner_dismiss_btn.visible = true
			_banner_container.visible = true
			return

	# Priority 2: Initiative / Action check owed for combat round
	if _ctx.table != null and _ctx.table.owes_action_check():
		_current_banner_type = BannerType.ACTION_CHECK
		_current_banner_check = null
		_current_banner_attack = null
		_current_notification = {}
		_banner_card.add_theme_stylebox_override("panel", Widgets.flat_style(_ctx.palette.surface_soft, _ctx.palette.accent, 8, true))

		_banner_roll_btn.remove_theme_stylebox_override("normal")
		_banner_roll_btn.add_theme_stylebox_override("normal", Widgets.flat_style(_ctx.palette.surface, _ctx.palette.accent, 6))
		_banner_roll_btn.add_theme_color_override("font_color", _ctx.palette.text)

		_banner_dismiss_btn.remove_theme_stylebox_override("normal")
		_banner_dismiss_btn.add_theme_stylebox_override("normal", Widgets.flat_style(_ctx.palette.surface, _ctx.palette.border, 6))
		_banner_dismiss_btn.add_theme_color_override("font_color", _ctx.palette.text)

		_banner_icon.texture = ICON_DICE
		_banner_icon.modulate = _ctx.palette.accent

		var round_num := _ctx.table.active_round.number if _ctx.table.active_round != null else 1
		_banner_label.text = "Round %d started! Roll initiative (Action Check) to act." % round_num
		_banner_roll_btn.text = "Roll Initiative"
		_banner_dismiss_btn.text = "Table"
		_banner_roll_btn.visible = true
		_banner_dismiss_btn.visible = true
		_banner_container.visible = true
		return

	# Priority 3: GM called skill check
	if _ctx.table != null and not _ctx.table.incoming_checks.is_empty():
		var check := _ctx.table.incoming_checks[0] as SkillCheck
		if check != null:
			_current_banner_type = BannerType.CALLED_CHECK
			_current_banner_check = check
			_current_banner_attack = null
			_current_notification = {}
			_banner_card.add_theme_stylebox_override("panel", Widgets.flat_style(_ctx.palette.surface_soft, _ctx.palette.accent, 8, true))

			_banner_roll_btn.remove_theme_stylebox_override("normal")
			_banner_roll_btn.add_theme_stylebox_override("normal", Widgets.flat_style(_ctx.palette.surface, _ctx.palette.accent, 6))
			_banner_roll_btn.add_theme_color_override("font_color", _ctx.palette.text)

			_banner_dismiss_btn.remove_theme_stylebox_override("normal")
			_banner_dismiss_btn.add_theme_stylebox_override("normal", Widgets.flat_style(_ctx.palette.surface, _ctx.palette.border, 6))
			_banner_dismiss_btn.add_theme_color_override("font_color", _ctx.palette.text)

			_banner_icon.texture = ICON_DICE
			_banner_icon.modulate = _ctx.palette.accent

			var step_text := "%+d step" % check.gm_step
			var reason_text := "" if check.reason.is_empty() else " -- \"%s\"" % check.reason
			_banner_label.text = "The GM called for: %s (Difficulty: %s%s)" % [
				check.skill_label,
				step_text,
				reason_text
			]
			_banner_roll_btn.text = "Roll Now"
			_banner_dismiss_btn.text = "Dismiss"
			_banner_roll_btn.visible = true
			_banner_dismiss_btn.visible = true
			_banner_container.visible = true
			return

	# Priority 4: Player's turn to act in combat
	if _ctx.table != null and _ctx.table.acting_now():
		_current_banner_type = BannerType.YOUR_TURN
		_current_banner_check = null
		_current_banner_attack = null
		_current_notification = {}
		_banner_card.add_theme_stylebox_override("panel", Widgets.flat_style(_ctx.palette.surface_soft, _ctx.palette.accent, 8, true))

		_banner_roll_btn.remove_theme_stylebox_override("normal")
		_banner_roll_btn.add_theme_stylebox_override("normal", Widgets.flat_style(_ctx.palette.surface, _ctx.palette.accent, 6))
		_banner_roll_btn.add_theme_color_override("font_color", _ctx.palette.text)

		_banner_icon.texture = ICON_ATTACK
		_banner_icon.modulate = _ctx.palette.accent

		var round_info := ""
		if _ctx.table.active_round != null:
			var phase_str: String = _ctx.table.active_round.phase_name().capitalize()
			round_info = "Round %d (%s Phase): " % [_ctx.table.active_round.number, phase_str]
		_banner_label.text = "%sIt is your turn to act!" % round_info
		_banner_roll_btn.text = "Open Table"
		_banner_roll_btn.visible = true
		_banner_dismiss_btn.visible = false
		_banner_container.visible = true
		return

	# Priority 5: Character Changes (Damage taken, AP awarded, Stun cleared, Trouble)
	if not _notifications.is_empty():
		_current_notification = _notifications[0]
		_current_banner_type = BannerType.NOTIFICATION
		_current_banner_check = null
		_current_banner_attack = null

		var is_warning: bool = bool(_current_notification.get("is_warning", false))
		var border_color: Color = _ctx.palette.warning if is_warning else _ctx.palette.accent
		_banner_card.add_theme_stylebox_override("panel", Widgets.flat_style(_ctx.palette.surface_soft, border_color, 8, true))

		_banner_roll_btn.remove_theme_stylebox_override("normal")
		_banner_roll_btn.add_theme_stylebox_override("normal", Widgets.flat_style(_ctx.palette.surface, _ctx.palette.accent, 6))
		_banner_roll_btn.add_theme_color_override("font_color", _ctx.palette.text)

		_banner_dismiss_btn.remove_theme_stylebox_override("normal")
		_banner_dismiss_btn.add_theme_stylebox_override("normal", Widgets.flat_style(_ctx.palette.surface, _ctx.palette.border, 6))
		_banner_dismiss_btn.add_theme_color_override("font_color", _ctx.palette.text)

		var notif_icon = _current_notification.get("icon")
		_banner_icon.texture = notif_icon if notif_icon is Texture2D else ICON_DICE
		_banner_icon.modulate = border_color

		_banner_label.text = String(_current_notification.get("message", ""))
		_banner_roll_btn.text = String(_current_notification.get("action_label", "View"))
		_banner_dismiss_btn.text = "Dismiss"

		_banner_roll_btn.visible = not String(_current_notification.get("target_tab", "")).is_empty()
		_banner_dismiss_btn.visible = true
		_banner_container.visible = true
		return

	# Nothing waiting
	_banner_container.visible = false
	_banner_icon.texture = null
	_current_banner_type = BannerType.NONE
	_current_banner_check = null
	_current_banner_attack = null
	_current_notification = {}


func _on_banner_roll_pressed() -> void:
	match _current_banner_type:
		BannerType.ATTACK:
			if _current_banner_attack != null:
				if _current_banner_attack.hits():
					await _resolve_attack_from_banner(_current_banner_attack)
				else:
					if _ctx != null and _ctx.table != null:
						_ctx.table.apply_attack(_current_banner_attack, 0)
						_ctx.table.report_attack(_current_banner_attack, 0, {})
			_refresh_incoming_banner()
			_refresh_tab_badges()

		BannerType.ACTION_CHECK:
			if _ctx != null and _ctx.table != null and _ctx.checks != null:
				var rolled = await _ctx.checks.run_action_check(_ctx.doc)
				if is_instance_valid(self) and rolled != null:
					_ctx.table.send_action_check(rolled)
			_refresh_incoming_banner()
			_refresh_tab_badges()

		BannerType.CALLED_CHECK:
			if _current_banner_check != null and _ctx != null and _ctx.checks != null:
				var check := _current_banner_check
				var skill := _ctx.rules.get_skill_by_id(check.skill_id) if _ctx.rules != null else {}
				var rolled = await _ctx.checks.run_called(check, _ctx.doc, skill)
				if rolled != null and _ctx.table != null:
					_ctx.table.resolve_called_check(check)
			_refresh_incoming_banner()
			_refresh_tab_badges()

		BannerType.YOUR_TURN:
			_select_tab("table")

		BannerType.NOTIFICATION:
			var target_tab := String(_current_notification.get("target_tab", ""))
			_notifications.erase(_current_notification)
			if not target_tab.is_empty():
				_select_tab(target_tab)
			_refresh_incoming_banner()
			_refresh_tab_badges()


func _on_banner_dismiss_pressed() -> void:
	match _current_banner_type:
		BannerType.ATTACK, BannerType.ACTION_CHECK:
			_select_tab("table")

		BannerType.CALLED_CHECK:
			if _current_banner_check != null and _ctx != null and _ctx.table != null:
				_ctx.table.dismiss_called_check(_current_banner_check)
			_refresh_incoming_banner()
			_refresh_tab_badges()

		BannerType.YOUR_TURN:
			pass

		BannerType.NOTIFICATION:
			_notifications.erase(_current_notification)
			_refresh_incoming_banner()
			_refresh_tab_badges()


## Queue a notification banner for character changes (damage taken, awards, recovery, etc.)
func notify_character_change(
	icon: Texture2D,
	message: String,
	action_label: String = "",
	target_tab: String = "",
	is_warning: bool = false,
	ap_amount: int = 0
) -> void:
	for notif in _notifications:
		if String(notif.get("message", "")) == message:
			return

	_notifications.append({
		"icon": icon,
		"message": message,
		"action_label": action_label if not action_label.is_empty() else "Dismiss",
		"target_tab": target_tab,
		"is_warning": is_warning,
		"ap_amount": ap_amount,
	})
	_refresh_incoming_banner()
	_refresh_tab_badges()


func _resolve_attack_from_banner(attack: CombatAttack) -> void:
	if _ctx == null or _ctx.table == null or _ctx.checks == null or _ctx.doc == null:
		return

	var absorbed := 0
	for layer in _ctx.rules.combat.armor_layers(_ctx.doc.raw(), attack.impact_type):
		var rolled: int = await _ctx.checks.roll_notation(
			String(layer.get("notation", "")),
			"%s absorbs" % String(layer.get("name", "Armor"))
		)
		if not is_instance_valid(self):
			return
		if rolled < 0:
			return
		absorbed = maxi(absorbed, rolled)

	var knockout: Dictionary = _ctx.table.knockout_check_for(attack)
	var outcome: Dictionary = _ctx.table.apply_attack(attack, absorbed)

	var down := false
	if bool(knockout.get("required", false)) and not bool(outcome.get("negated", false)):
		down = not await _survives_knockout(knockout)
		if not is_instance_valid(self):
			return

	_ctx.table.report_attack(attack, absorbed, outcome, down)
	_save()
	_refresh_header()
	_refresh_incoming_banner()
	_refresh_tab_badges()


func _survives_knockout(knockout: Dictionary) -> bool:
	if _ctx == null or _ctx.rules == null or _ctx.checks == null or _ctx.doc == null:
		return true
	var skill: Dictionary = _ctx.rules.get_skill_by_id(AlternityNum.as_int(knockout.get("skill_id", -1), -1))
	if skill.is_empty():
		return true
	var check := SkillCheck.call_for(
		_ctx.rules.skill_label(skill),
		0,
		String(knockout.get("reason", "")),
		AlternityNum.as_int(knockout.get("skill_id", -1), -1)
	)
	var rolled = await _ctx.checks.run_called(check, _ctx.doc, skill)
	if rolled == null:
		return true
	return (rolled as SkillCheck).is_success()


func _refresh_tab_badges() -> void:
	if _buttons.has("table"):
		var btn: Button = _buttons["table"]
		if _ctx == null or _ctx.table == null:
			btn.text = "Table"
		else:
			var count: int = _ctx.table.incoming_checks.size() + _ctx.table.incoming_attacks.size()
			if _ctx.table.owes_action_check():
				count += 1
			elif _ctx.table.acting_now():
				count += 1
			if count > 0:
				btn.text = "Table (%d)" % count
			else:
				var has_table_notif := false
				for notif in _notifications:
					if String(notif.get("target_tab", "")) == "table":
						has_table_notif = true
						break
				if has_table_notif:
					btn.text = "Table (!)"
				else:
					btn.text = "Table"

	if _buttons.has("achievements"):
		var btn_ach: Button = _buttons["achievements"]
		var pending_ap := 0
		var has_ach_notif := false
		for notif in _notifications:
			if String(notif.get("target_tab", "")) == "achievements":
				has_ach_notif = true
				pending_ap += AlternityNum.as_int(notif.get("ap_amount", 0))
		if pending_ap > 0:
			btn_ach.text = "Achievements (+%d)" % pending_ap
		elif has_ach_notif:
			btn_ach.text = "Achievements (!)"
		else:
			btn_ach.text = "Achievements"

	if _buttons.has("summary"):
		var btn_sum: Button = _buttons["summary"]
		var has_sum_notif := false
		for notif in _notifications:
			if String(notif.get("target_tab", "")) == "summary":
				has_sum_notif = true
				break
		if has_sum_notif:
			btn_sum.text = "Summary (!)"
		else:
			btn_sum.text = "Summary"


func _on_table_check_arrived(_check: SkillCheck) -> void:
	_refresh_incoming_banner()
	_refresh_tab_badges()


func _on_table_attack_arrived(_attack: CombatAttack) -> void:
	_refresh_incoming_banner()
	_refresh_tab_badges()


func _on_table_attack_resolved(attack: CombatAttack) -> void:
	if attack == null or not attack.hits():
		return
	var res := attack.result
	var weapon := attack.weapon_name if not attack.weapon_name.is_empty() else "an attack"

	if bool(res.get("parried", false)):
		notify_character_change(ICON_ATTACK, "Parried %s's %s!" % [attack.attacker_name, weapon], "View Summary", "summary", false)
		return

	var primary := AlternityNum.as_int(res.get("primary_damage", 0))
	var sec_stun := AlternityNum.as_int(res.get("secondary_stun", 0))
	var sec_wound := AlternityNum.as_int(res.get("secondary_wound", 0))
	var soaked := AlternityNum.as_int(res.get("absorbed", 0))

	if bool(res.get("negated", false)) or (primary == 0 and sec_stun == 0 and sec_wound == 0):
		if soaked > 0:
			notify_character_change(ICON_ATTACK, "Armor soaked all %d damage from %s's %s." % [soaked, attack.attacker_name, weapon], "View Summary", "summary", false)
		else:
			notify_character_change(ICON_ATTACK, "No damage taken from %s's %s." % [attack.attacker_name, weapon], "View Summary", "summary", false)
		return

	var track := String(res.get("damage_type", attack.track_name())).capitalize()
	var msg := "Took %d %s" % [primary, track]
	if soaked > 0:
		msg += " (%d soaked by armor)" % soaked
	if sec_stun > 0:
		msg += " and %d Stun" % sec_stun
	if sec_wound > 0:
		msg += " and %d Wound" % sec_wound
	msg += " from %s's %s." % [attack.attacker_name, weapon]
	if bool(res.get("knocked_out", false)):
		msg += " Knocked Out!"
	notify_character_change(ICON_ATTACK, msg, "View Summary", "summary", true)


func _on_table_ap_applied(amount: int, reason: String) -> void:
	var msg: String
	if reason == "Total adjusted by GM":
		msg = "The GM set your achievement points to %d." % amount
	else:
		var s := "" if amount == 1 else "s"
		if reason.is_empty():
			msg = "The GM awarded you %d achievement point%s! Added to your hero." % [amount, s]
		else:
			msg = "The GM awarded you %d achievement point%s -- \"%s\"! Added to your hero." % [amount, s, reason]
	notify_character_change(ICON_DICE, msg, "View Achievements", "achievements", false, amount)


func _on_table_scene_ended(stun_cleared: int) -> void:
	var msg := "The scene ended -- %d Stun cleared. Anybody knocked out is awake!" % stun_cleared if stun_cleared > 0 else "The scene ended."
	notify_character_change(ICON_DICE, msg, "View Summary", "summary", false)


func _on_table_trouble(message: String) -> void:
	notify_character_change(ICON_DICE, message, "Open Table", "table", true)


func _on_table_round_changed() -> void:
	_refresh_incoming_banner()
	_refresh_tab_badges()


func _on_table_action_check_wanted() -> void:
	_refresh_incoming_banner()
	_refresh_tab_badges()


func _on_table_changed() -> void:
	_refresh_incoming_banner()
	_refresh_tab_badges()


func _build_tab_bar(parent: Container) -> void:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.PAD_PANEL)
	parent.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 52)
	margin.add_child(scroll)

	_tab_bar = HBoxContainer.new()
	_tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_bar.add_theme_constant_override("separation", 6)
	scroll.add_child(_tab_bar)

	_populate_tab_bar()


func _populate_tab_bar() -> void:
	_listed_ids = []
	for definition in _available_tabs():
		_listed_ids.append(String(definition["id"]))
		var button := Button.new()
		button.text = String(definition["label"])
		button.toggle_mode = true
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 42)
		var id := String(definition["id"])
		button.pressed.connect(func(): _select_tab(id))
		_tab_bar.add_child(button)
		_buttons[id] = button


## Tabs that apply to this character. Replaces the Mutations special case that
## was hardcoded into _tab_visible().
func _available_tabs() -> Array:
	var out: Array = []
	for definition in TABS:
		if _is_available(definition):
			out.append(definition)
	return out


func _select_tab(id: String) -> void:
	# Dismiss any pending notifications for this tab now that the player has opened it.
	var remaining: Array[Dictionary] = []
	var cleared_any := false
	for notif in _notifications:
		if String(notif.get("target_tab", "")) == id:
			cleared_any = true
		else:
			remaining.append(notif)
	if cleared_any:
		_notifications = remaining
		_refresh_incoming_banner()
		_refresh_tab_badges()

	if id == _active_id:
		return
	_active_id = id

	for tab_id in _buttons:
		_buttons[tab_id].button_pressed = tab_id == id

	# Instantiate on first visit and keep it: a hidden tab costs nothing,
	# because SheetTab defers its rebuild until it is shown again.
	if not _instances.has(id):
		var definition := _definition_for(id)
		# _definition_for searches the whole registry, so without this a caller
		# could open a tab that excludes itself for this character -- Psionics on
		# a non-psionic hero. The tab bar never offers one, but nothing else
		# stopped it.
		if definition.is_empty() or not _is_available(definition):
			return
		var tab: SheetTab = definition["scene"].instantiate()
		# Laid out by the host container, so no anchor preset here.
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tab.save_requested.connect(_save)
		_content_host.add_child(tab)
		tab.bind(_ctx)
		_instances[id] = tab

	for tab_id in _instances:
		_instances[tab_id].visible = tab_id == id

	var active_tab = _instances.get(id)
	if active_tab != null and active_tab.has_method("has_custom_scroll") and active_tab.has_custom_scroll():
		_content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	else:
		_content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO


## Whether a registry entry applies to the current character.
func _is_available(definition: Dictionary) -> bool:
	var probe = definition["scene"].instantiate()
	var applies: bool = probe.is_available_for(_ctx) if probe is SheetTab else true
	probe.free()
	return applies


func _definition_for(id: String) -> Dictionary:
	for definition in TABS:
		if String(definition["id"]) == id:
			return definition
	return {}


func _refresh_header() -> void:
	if _ctx == null or _ctx.doc == null:
		return
	var name := _ctx.doc.get_hero_name()
	_title.text = name if not name.is_empty() else "Unnamed Hero"
	_on_dirty_changed(_ctx.doc.is_dirty())


## Sections that can never change which tabs apply.
##
## Named as an exclusion rather than an inclusion, because the cost of being
## wrong runs one way. _refresh_tab_bar instantiates and frees every tab scene
## to ask whether it applies, which is too expensive to run on each point of
## damage during a fight -- but a list of the sections that *do* matter has to
## be kept in step with every is_available_for in the app, and the two that are
## easiest to miss are the ones nobody associates with a tab: the Psionic
## Talents optional rule and the Superior Talent perk both reveal Psionics.
## Leaving them out cost nothing visible; the tab simply never appeared until
## the character was closed and reopened.
const TAB_SET_UNAFFECTED_BY := [CharacterDoc.DAMAGE, CharacterDoc.NOTES]


func _on_document_changed(sections: PackedStringArray) -> void:
	if sections.has(String(CharacterDoc.META)):
		_refresh_header()
	for section in sections:
		if not TAB_SET_UNAFFECTED_BY.has(StringName(section)):
			_refresh_tab_bar()
			return


## Rebuild the tab bar when the set of applicable tabs changes.
##
## Which tabs apply is not fixed for the life of a sheet: choosing the Mutant
## species makes Mutations apply, and becoming a Mindwalker makes Psionics
## apply. The bar was built once in setup(), so neither could ever appear --
## you had to close and reopen the character.
func _refresh_tab_bar() -> void:
	var ids: Array = []
	for definition in _available_tabs():
		ids.append(String(definition["id"]))
	if ids == _listed_ids:
		return

	_listed_ids = ids
	_buttons.clear()
	for child in _tab_bar.get_children():
		_tab_bar.remove_child(child)
		child.queue_free()
	_populate_tab_bar()

	# A tab that stopped applying must not stay on screen.
	if not ids.has(_active_id):
		for tab_id in _instances:
			_instances[tab_id].visible = false
		_active_id = ""
		if not ids.is_empty():
			_select_tab(String(ids[0]))
	else:
		for tab_id in _buttons:
			_buttons[tab_id].button_pressed = tab_id == _active_id


func _on_dirty_changed(is_dirty: bool) -> void:
	if _status == null:
		return
	_status.text = "Unsaved changes" if is_dirty else "Saved"
	_status.add_theme_color_override(
		"font_color",
		_ctx.palette.warning if is_dirty else _ctx.palette.muted
	)


func _open_optional_rules() -> void:
	if _ctx == null or _ctx.router == null:
		return
	var changed = await _ctx.router.push(OPTIONAL_RULES_ROUTE, {
		"palette": _ctx.palette,
		"rules": _ctx.rules,
		"character": _ctx.doc.raw(),
	})
	if not is_instance_valid(self) or typeof(changed) != TYPE_DICTIONARY or changed.is_empty():
		return

	# Optional rules move skill budgets and ability limits, so this invalidates
	# the whole sheet rather than one section.
	var rules: AlternityRules = _ctx.rules
	_ctx.doc.apply(CharacterDoc.ALL, func(c):
		for rule_id in changed:
			rules.set_optional_rule(c, String(rule_id), bool(changed[rule_id])))
	_save()


func _open_theme() -> void:
	if _ctx == null or _ctx.router == null:
		return
	await _ctx.router.push(THEME_ROUTE, {
		"palette": _ctx.palette,
		"service": get_node_or_null("/root/ThemeService"),
	})


## Hand the character to whatever the platform uses for sharing.
##
## Writes next to the save rather than opening a dialog on mobile: Android has
## no usable native save picker here, and a file the person can find beats a
## dialog that never appears.
## Hand the character to the person, somewhere they can actually reach it.
##
## The rewrite had reduced this to a clipboard copy plus a file in user://,
## which on Android is inside the app sandbox and on desktop is buried under
## AppData -- neither is a place you can send a file to a friend from.
##
## Restores the two paths the old flow used: a native Save dialog where the
## platform has one, so the file lands wherever you choose; and Downloads plus
## a shell_open on Android, which is what makes it reachable from the share
## sheet. The clipboard copy is kept as well, since pasting the JSON straight
## into chat is the quickest way to pass a hero around.
func _share() -> void:
	if _store == null or _ctx == null or _ctx.doc == null:
		return
	var text := _store.export_json(_ctx.doc)
	DisplayServer.clipboard_set(text)

	var file_name := CharacterStore.file_name_for(_ctx.doc)

	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG):
		var on_chosen := func(accepted: bool, paths: PackedStringArray, _filter: int) -> void:
			if not is_instance_valid(self):
				return
			if not accepted or paths.is_empty():
				_set_status("Copied to clipboard", _ctx.palette.muted)
				return
			var chosen := String(paths[0])
			if _write(chosen, text):
				_set_status("Saved to %s" % chosen.get_file(), _ctx.palette.accent)
			else:
				_set_status("Could not write %s" % chosen.get_file(), _ctx.palette.warning)
		DisplayServer.file_dialog_show(
			"Save Character", "", file_name, false,
			DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, ["*.json"], on_chosen
		)
		return

	# No native dialog: Android and anywhere else headless-ish. Downloads is the
	# one directory the system file picker and the share sheet both see.
	var downloads := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	var path := "%s/shared_%s" % [downloads, file_name] if not downloads.is_empty() else "user://shared_" + file_name
	if _write(path, text):
		OS.shell_open(ProjectSettings.globalize_path(path))
		_set_status("Saved to %s" % path.get_file(), _ctx.palette.accent)
	else:
		_set_status("Copied to clipboard", _ctx.palette.muted)


func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


func _set_status(message: String, color: Color) -> void:
	if _status == null or not is_instance_valid(_status):
		return
	_status.text = message
	_status.add_theme_color_override("font_color", color)


func _save() -> void:
	if _store == null or _ctx == null or _ctx.doc == null:
		return
	_store.save(_ctx.doc)
	_refresh_header()


func _on_close_pressed() -> void:
	# Saving on the way out matches the old behaviour, where closing offered to
	# save first; unsaved work should never be lost by leaving the sheet.
	if _ctx != null and _ctx.doc != null and _ctx.doc.is_dirty():
		_save()
	closed.emit()
