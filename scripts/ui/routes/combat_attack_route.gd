extends RouteScene
##
## Declaring one attack against one player.
##
## The GM is running something with no character sheet, so this collects the
## three things an attack needs that a sheet would otherwise supply: what is
## swinging, what it is swinging with, and how hard it is to connect. The dice
## are thrown afterwards, by the screen -- this route only decides what to throw.
##
## The weapon comes out of the equipment catalogue rather than being typed. Every
## weapon in the book already carries its damage triple, its impact type, its
## firepower grade and its range bands, so picking one fills in four fields that
## a GM would otherwise get wrong at speed. It is also how an enemy gets a weapon
## before NPC stat blocks exist.
##
## Closes with a declaration dictionary, or null if the GM backed out.
##

const MAX_WEAPONS_SHOWN := 40

## How tall the weapon list is allowed to be. Enough rows to browse, few enough
## that the rest of the attack stays on screen behind it.
const LIST_HEIGHT := 190

var _palette: ThemePalette
var _rules: AlternityRules
var _target_id: String = ""
var _target_name: String = ""

## The catalogue entry chosen, or {} while none is.
var _weapon: Dictionary = {}

var _attacker_field: LineEdit
var _score_stepper: NumberStepper
var _weapon_label: Label
var _weapon_list: VBoxContainer
var _picker: VBoxContainer
var _change_button: Button
var _modifier_note: Label
var _modifier_body: VBoxContainer
var _confirm: Button

## Modifier ids the GM has ticked, and the band chosen for a ranged shot.
var _chosen: Dictionary = {}
var _band: String = "medium"
var _sees_attacker: bool = true
var _from_rear: bool = false
var _pinned: bool = false


## props: palette, rules, target_id, target_name
func configure(props: Dictionary) -> void:
	_palette = props.get("palette", ThemePalette.new())
	_rules = props.get("rules")
	_target_id = String(props.get("target_id", ""))
	_target_name = String(props.get("target_name", "them"))
	_build()


func preferred_presentation() -> int:
	return UiRouter.Presentation.PAGE


func title() -> String:
	return "Attack %s" % _target_name


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", Widgets.flat_style(_palette.surface, _palette.border, 8, true))
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Widgets.PAD_PANEL)
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", Widgets.GAP_ROW)
	margin.add_child(outer)

	var heading := Widgets.text(outer, "Attacking %s" % _target_name, _palette, Widgets.FONT_SECTION_TITLE, _palette.accent)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size = Vector2(1, 0)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", Widgets.GAP_SECTION)
	scroll.add_child(column)

	_build_attacker(column)
	_build_weapon(column)
	_build_modifiers(column)
	_build_awareness(column)

	var actions := HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", Widgets.GAP_ROW)
	outer.add_child(actions)

	var cancel := Button.new()
	cancel.name = "CancelButton"
	cancel.text = "Cancel"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.custom_minimum_size = Vector2(0, 42)
	cancel.clip_text = true
	cancel.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.border, 6))
	cancel.pressed.connect(func(): close(null))
	actions.add_child(cancel)

	_confirm = Button.new()
	_confirm.name = "RollAttackButton"
	_confirm.text = "Roll the attack"
	_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm.custom_minimum_size = Vector2(0, 42)
	_confirm.clip_text = true
	_confirm.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
	_confirm.pressed.connect(_submit)
	actions.add_child(_confirm)

	_refresh()


func _build_attacker(parent: Container) -> void:
	var section := Widgets.section(parent, "Who is attacking", _palette)

	_attacker_field = LineEdit.new()
	_attacker_field.name = "AttackerField"
	_attacker_field.text = "A thug"
	_attacker_field.placeholder_text = "Name of the attacker"
	_attacker_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attacker_field.custom_minimum_size = Vector2(0, 40)
	Widgets.field_row(section, "Name", _attacker_field, _palette)

	# The attacker has no sheet, so the GM supplies the one number a sheet would.
	# Good and Amazing derive from it the way they do for a character.
	_score_stepper = NumberStepper.new()
	section.add_child(_score_stepper)
	_score_stepper.setup(_palette, "Attack score", 12, 1, 30, 1, 0, true)

	var note := Widgets.muted_text(
		section,
		"Their skill score for this attack. Good is half of it and Amazing a quarter, as on a sheet.",
		_palette,
		Widgets.FONT_CAPTION
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(1, 0)


## The weapon, out of the catalogue.
##
## The list is boxed to a few rows and folded away once a weapon is chosen. Left
## open it is four hundred rows tall, and everything that decides the attack sits
## underneath it.
func _build_weapon(parent: Container) -> void:
	var section := Widgets.section(parent, "With what", _palette)

	_weapon_label = Widgets.text(section, "No weapon chosen.", _palette, Widgets.FONT_DETAIL)
	_weapon_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_weapon_label.custom_minimum_size = Vector2(1, 0)

	_change_button = Button.new()
	_change_button.name = "ChangeWeaponButton"
	_change_button.text = "Choose a different weapon"
	_change_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_change_button.custom_minimum_size = Vector2(0, 34)
	_change_button.clip_text = true
	_change_button.visible = false
	_change_button.pressed.connect(_on_change_weapon_pressed)
	section.add_child(_change_button)

	_picker = VBoxContainer.new()
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	section.add_child(_picker)

	var search := SearchField.new()
	search.name = "WeaponSearch"
	_picker.add_child(search)
	search.setup(_palette, "Search weapons")
	search.query_changed.connect(_refresh_weapons)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, LIST_HEIGHT)
	_picker.add_child(scroll)

	_weapon_list = VBoxContainer.new()
	_weapon_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_list.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	scroll.add_child(_weapon_list)
	_refresh_weapons("")


func _on_change_weapon_pressed() -> void:
	_picker.visible = true
	_change_button.visible = false


func _refresh_weapons(query: String) -> void:
	if _weapon_list == null or _rules == null:
		return
	for child in _weapon_list.get_children():
		_weapon_list.remove_child(child)
		child.queue_free()

	var needle := query.strip_edges().to_lower()
	var shown := 0
	for item in _rules.equipment.filtered_equipment({"category": "Weapons"}):
		if shown >= MAX_WEAPONS_SHOWN:
			break
		var name := String(item.get("name", ""))
		if not needle.is_empty() and not name.to_lower().contains(needle):
			continue
		var combat: Dictionary = item.get("combat", {})
		if String(combat.get("damage", "")).is_empty():
			continue

		var button := Button.new()
		button.text = "%s   %s" % [name, String(combat.get("damage", ""))]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 34)
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(_choose_weapon.bind(item))
		_weapon_list.add_child(button)
		shown += 1

	if shown == 0:
		Widgets.muted_text(_weapon_list, "Nothing matches that.", _palette, Widgets.FONT_CAPTION)


func _choose_weapon(item: Dictionary) -> void:
	var was_melee := _is_melee()
	_weapon = item
	# The two tables share ids only where they share rows, so a switch between
	# them drops anything the new table does not have rather than quietly
	# applying a cover penalty to a sword.
	if was_melee != _is_melee():
		var still_valid: Dictionary = {}
		for row in _rules.attack_modifiers_for("melee" if _is_melee() else "ranged"):
			var id := String(row.get("id", ""))
			if _chosen.has(id):
				still_valid[id] = true
		_chosen = still_valid
	_picker.visible = false
	_change_button.visible = true
	_render_modifiers()
	_refresh()


## The modifier panel: the real tables, netting to a total the GM can see.
##
## Rebuilt whenever the weapon changes, because the two tables are not the same
## table. Cover is a ranged row and charging is a melee one, and offering a GM
## the wrong half is how a sword ends up with a range penalty.
func _build_modifiers(parent: Container) -> void:
	var section := Widgets.section(parent, "How hard is it", _palette)

	_modifier_note = Widgets.text(section, "", _palette, Widgets.FONT_BODY, _palette.accent)
	_modifier_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modifier_note.custom_minimum_size = Vector2(1, 0)

	_modifier_body = VBoxContainer.new()
	_modifier_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modifier_body.add_theme_constant_override("separation", Widgets.GAP_ROW)
	section.add_child(_modifier_body)
	_render_modifiers()


func _render_modifiers() -> void:
	if _modifier_body == null:
		return
	for child in _modifier_body.get_children():
		_modifier_body.remove_child(child)
		child.queue_free()

	var scope := "melee" if _is_melee() else "ranged"

	# Range first, because it is the one that depends on the weapon and the one
	# a GM changes most. A melee weapon has no bands at all.
	if not _is_melee():
		var band_row := HBoxContainer.new()
		band_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		band_row.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
		_modifier_body.add_child(band_row)
		for band in ["short", "medium", "long"]:
			var button := Button.new()
			button.text = _band_label(band)
			button.toggle_mode = true
			button.button_pressed = band == _band
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size = Vector2(0, 34)
			button.clip_text = true
			button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			button.pressed.connect(_on_band_pressed.bind(band))
			band_row.add_child(button)

	var grid := GridContainer.new()
	grid.columns = 2 if _is_wide() else 1
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", Widgets.GAP_ROW)
	grid.add_theme_constant_override("v_separation", Widgets.GAP_TIGHT)
	_modifier_body.add_child(grid)

	for row in _rules.attack_modifiers_for(scope):
		var id := String(row.get("id", ""))
		var label := "%s (%+d)" % [String(row.get("name", "")), AlternityNum.as_int(row.get("step", 0))]
		var toggle := Widgets.toggle_row(grid, label, _chosen.has(id), _palette, true, true)
		toggle.toggled.connect(_on_modifier_toggled.bind(id))


func _on_band_pressed(band: String) -> void:
	_band = band
	_render_modifiers()
	_refresh()


func _on_modifier_toggled(on: bool, id: String) -> void:
	if on:
		_chosen[id] = true
	else:
		_chosen.erase(id)
	_refresh()


## A band, and how far that reaches with this weapon.
func _band_label(band: String) -> String:
	if _weapon.is_empty():
		return band.capitalize()
	var combat: Dictionary = _weapon.get("combat", {})
	var bands: Dictionary = _rules.combat.range_bands(String(combat.get("range", "")))
	var metres := AlternityNum.as_float(bands.get(band, 0.0))
	if metres <= 0.0:
		return band.capitalize()
	return "%s %dm" % [band.capitalize(), int(metres)]


func _is_melee() -> bool:
	if _weapon.is_empty():
		return false
	return bool(_weapon.get("combat", {}).get("melee", false))


## What the target can do about it, which only the GM knows.
func _build_awareness(parent: Container) -> void:
	var section := Widgets.section(parent, "Can they see it coming", _palette)

	var unseen := Widgets.toggle_row(section, "They cannot see the attacker", not _sees_attacker, _palette)
	unseen.toggled.connect(func(on: bool):
		_sees_attacker = not on
		_refresh())

	var rear := Widgets.toggle_row(section, "From behind", _from_rear, _palette)
	rear.toggled.connect(func(on: bool):
		_from_rear = on
		_refresh())

	var held := Widgets.toggle_row(section, "Pinned", _pinned, _palette)
	held.toggled.connect(func(on: bool):
		_pinned = on
		_refresh())

	var note := Widgets.muted_text(
		section,
		"An unseen or pinned target does not resist and cannot dodge. From behind they still resist -- they simply cannot turn to meet it.",
		_palette,
		Widgets.FONT_CAPTION
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(1, 0)


## Whether there is room for two columns of toggles.
##
## configure() runs before the router presents the route, so during the first
## build there is no viewport to measure and asking for one is an error. The
## panel is rebuilt in _ready, which is the first moment the answer is real.
func _is_wide() -> bool:
	if not is_inside_tree():
		return false
	return get_viewport_rect().size.x >= ModalHost.COMPACT_WIDTH


func _ready() -> void:
	_render_modifiers()


# --- Netting ---------------------------------------------------------------

## Every step this attack is worth, and the die it comes to.
func net_steps() -> int:
	var total := _rules.net_situation_steps(_chosen.keys())
	total += _range_step()
	return total


func _range_step() -> int:
	if _weapon.is_empty():
		return 0
	if _is_melee():
		return 0
	var combat: Dictionary = _weapon.get("combat", {})
	var weapon_class: String = _rules.combat.weapon_range_class(AlternityNum.as_int(combat.get("skill_id", -1), -1))
	if weapon_class.is_empty():
		return 0
	return _rules.range_step_for(weapon_class, _band)


func _refresh() -> void:
	if _weapon_label == null:
		return

	if _weapon.is_empty():
		_weapon_label.text = "No weapon chosen."
	else:
		var combat: Dictionary = _weapon.get("combat", {})
		var split: Dictionary = _rules.combat.split_weapon_type(String(combat.get("damage_type", combat.get("type", ""))))
		_weapon_label.text = "%s -- %s, %s impact, firepower %s%s" % [
			String(_weapon.get("name", "")),
			String(combat.get("damage", "")),
			String(split.get("impact", "hi")).to_upper(),
			String(split.get("firepower", "O")),
			("" if _is_melee() else ", range %s" % String(combat.get("range", ""))),
		]

	var steps := net_steps()
	_modifier_note.text = "%+d steps -- situation die %s" % [steps, _rules.action_step_die(steps)]
	if _confirm != null:
		_confirm.disabled = _weapon.is_empty()


func _submit() -> void:
	if _weapon.is_empty():
		return
	var combat: Dictionary = _weapon.get("combat", {})
	var split: Dictionary = _rules.combat.split_weapon_type(String(combat.get("damage_type", combat.get("type", ""))))
	close({
		"target_id": _target_id,
		"target_name": _target_name,
		"attacker_name": _attacker_field.text.strip_edges(),
		"attack_score": _score_stepper.value(),
		"weapon_name": String(_weapon.get("name", "")),
		"damage_text": String(combat.get("damage", "")),
		"impact_type": String(split.get("impact", "hi")),
		"firepower": String(split.get("firepower", "O")),
		"is_melee": bool(combat.get("melee", false)),
		"steps": net_steps(),
		"called_shot": _chosen.has("called_shot"),
		"sees_attacker": _sees_attacker,
		"from_rear": _from_rear,
		"pinned": _pinned,
	})
