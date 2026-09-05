extends RouteScene
##
## One explosion, and who was standing where.
##
## An explosive is not an attack against a target: it goes off somewhere and
## everybody near it takes what their distance earns them. So this asks the one
## question a GM actually answers at the table -- which band each person was in
## -- rather than asking for a distance in metres and three blast radii.
##
## The radii are not in the data. The catalogue carries an explosive's damage
## triple, its impact type and its firepower grade, and no blast dimensions at
## all, so a distance-driven version of this screen would be three numbers typed
## out of a book under pressure. combat.blast_zone() is still there for the day
## the radii arrive; this works in the bands it would have produced.
##
## Somebody who is dodging has thrown themselves flat, which drops them one band
## -- and out of the blast entirely from the outer one. That is applied here,
## because the round already knows who declared a dodge.
##
## Closes with {weapon_name, damage_text, impact_type, firepower, targets}, or
## null if the GM backed out.
##

const MAX_WEAPONS_SHOWN := 40
const LIST_HEIGHT := 170

## The bands, worst first, plus the one that is not a band at all. The ids are
## the degrees they deal, which is what picks the damage entry.
const ZONES := ["amazing", "good", "ordinary", ""]
const ZONE_NAMES := {
	"amazing": "Close",
	"good": "Middle",
	"ordinary": "Outer",
	"": "Clear",
}

var _palette: ThemePalette
var _rules: AlternityRules

## [{id, name, dodging}] -- everyone still on their feet.
var _combatants: Array = []

var _weapon: Dictionary = {}
var _zones: Dictionary = {}

var _weapon_label: Label
var _weapon_list: VBoxContainer
var _picker: VBoxContainer
var _change_button: Button
var _targets_body: VBoxContainer
var _confirm: Button


## props: palette, rules, combatants
func configure(props: Dictionary) -> void:
	_palette = props.get("palette", ThemePalette.new())
	_rules = props.get("rules")
	var given = props.get("combatants", [])
	if typeof(given) == TYPE_ARRAY:
		_combatants = given
	for entry in _combatants:
		# Clear by default. Nobody is caught in a blast because a screen assumed
		# they were standing near it.
		_zones[String(entry.get("id", ""))] = ""
	_build()


func preferred_presentation() -> int:
	return UiRouter.Presentation.PAGE


func title() -> String:
	return "Something goes off"


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

	var heading := Widgets.text(outer, "Something goes off", _palette, Widgets.FONT_SECTION_TITLE, _palette.accent)
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

	_build_weapon(column)
	_build_targets(column)

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
	_confirm.name = "RollBlastButton"
	_confirm.text = "Set it off"
	_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm.custom_minimum_size = Vector2(0, 42)
	_confirm.clip_text = true
	_confirm.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
	_confirm.pressed.connect(_submit)
	actions.add_child(_confirm)

	_refresh()


func _build_weapon(parent: Container) -> void:
	var section := Widgets.section(parent, "What went off", _palette)

	_weapon_label = Widgets.text(section, "Nothing chosen.", _palette, Widgets.FONT_DETAIL)
	_weapon_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_weapon_label.custom_minimum_size = Vector2(1, 0)

	_change_button = Button.new()
	_change_button.name = "ChangeExplosiveButton"
	_change_button.text = "Choose something else"
	_change_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_change_button.custom_minimum_size = Vector2(0, 34)
	_change_button.clip_text = true
	_change_button.visible = false
	_change_button.pressed.connect(_on_change_pressed)
	section.add_child(_change_button)

	_picker = VBoxContainer.new()
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	section.add_child(_picker)

	var search := SearchField.new()
	search.name = "ExplosiveSearch"
	_picker.add_child(search)
	search.setup(_palette, "Search explosives")
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


func _on_change_pressed() -> void:
	_picker.visible = true
	_change_button.visible = false


## Thrown weapons first, because that is what an explosion usually is, and the
## rest of the catalogue after -- a GM setting off a charge should not have to
## fight a filter to find it.
func _refresh_weapons(query: String) -> void:
	if _weapon_list == null or _rules == null:
		return
	for child in _weapon_list.get_children():
		_weapon_list.remove_child(child)
		child.queue_free()

	var needle := query.strip_edges().to_lower()
	var thrown: Array = []
	var rest: Array = []
	for item in _rules.equipment.filtered_equipment({"category": "Weapons"}):
		var combat: Dictionary = item.get("combat", {})
		if String(combat.get("damage", "")).is_empty():
			continue
		if not needle.is_empty() and not String(item.get("name", "")).to_lower().contains(needle):
			continue
		if bool(combat.get("thrown", false)):
			thrown.append(item)
		else:
			rest.append(item)

	var shown := 0
	for item in thrown + rest:
		if shown >= MAX_WEAPONS_SHOWN:
			break
		var combat: Dictionary = item.get("combat", {})
		var button := Button.new()
		button.text = "%s   %s" % [String(item.get("name", "")), String(combat.get("damage", ""))]
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
	_weapon = item
	_picker.visible = false
	_change_button.visible = true
	_refresh()


## Who was standing where, one row each.
func _build_targets(parent: Container) -> void:
	var section := Widgets.section(parent, "Who was near it", _palette)

	var note := Widgets.muted_text(
		section,
		"Close takes the Amazing damage, Middle the Good, Outer the Ordinary. Anyone dodging has hit the deck and drops one band.",
		_palette,
		Widgets.FONT_CAPTION
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(1, 0)

	_targets_body = VBoxContainer.new()
	_targets_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_targets_body.add_theme_constant_override("separation", Widgets.GAP_ROW)
	section.add_child(_targets_body)

	if _combatants.is_empty():
		Widgets.muted_text(_targets_body, "Nobody is on their feet to catch it.", _palette, Widgets.FONT_CAPTION)
		return

	for entry in _combatants:
		var player_id := String(entry.get("id", ""))
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
		_targets_body.add_child(box)

		var name_line := String(entry.get("name", "Someone"))
		if bool(entry.get("dodging", false)):
			name_line += "   (dodging -- drops a band)"
		elif not String(entry.get("dodge_degree", "")).is_empty():
			name_line += "   (dodge failed: %s -- no band drop)" % String(entry.get("dodge_degree", ""))
		var label := Widgets.text(box, name_line, _palette, Widgets.FONT_DETAIL)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(1, 0)

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
		box.add_child(row)
		for zone in ZONES:
			var button := Button.new()
			button.text = String(ZONE_NAMES.get(zone, zone))
			button.toggle_mode = true
			var is_selected: bool = String(_zones.get(player_id, "")) == zone
			button.button_pressed = is_selected
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size = Vector2(0, 34)
			button.clip_text = true
			button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			if is_selected and not zone.is_empty():
				button.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
			else:
				button.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.border, 6))
			button.pressed.connect(_on_zone_pressed.bind(player_id, zone, row))
			row.add_child(button)


func _on_zone_pressed(player_id: String, zone: String, row: HBoxContainer) -> void:
	_zones[player_id] = zone
	var wanted := String(ZONE_NAMES.get(zone, zone))
	for child in row.get_children():
		var btn := child as Button
		if btn == null:
			continue
		var is_selected: bool = btn.text == wanted
		btn.button_pressed = is_selected
		btn.remove_theme_stylebox_override("normal")
		if is_selected and not zone.is_empty():
			btn.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.accent, 6))
		else:
			btn.add_theme_stylebox_override("normal", Widgets.flat_style(_palette.surface_soft, _palette.border, 6))
	_refresh()


func _refresh() -> void:
	if _weapon_label == null:
		return

	if _weapon.is_empty():
		_weapon_label.text = "Nothing chosen."
	else:
		var combat: Dictionary = _weapon.get("combat", {})
		var split: Dictionary = _rules.combat.split_weapon_type(String(combat.get("damage_type", combat.get("type", ""))))
		_weapon_label.text = "%s -- %s, %s impact, firepower %s" % [
			String(_weapon.get("name", "")),
			String(combat.get("damage", "")),
			String(split.get("impact", "en")).to_upper(),
			String(split.get("firepower", "O")),
		]

	if _confirm != null:
		_confirm.disabled = _weapon.is_empty() or caught().is_empty()


## Everyone the blast actually reaches, with the band they end up in.
##
## A dodge is applied here rather than by the caller: hitting the deck drops a
## target one band, and from the outer band it drops them out of the blast
## altogether -- so somebody who dodged out there is not in this list at all.
func caught() -> Array:
	var out: Array = []
	for entry in _combatants:
		var player_id := String(entry.get("id", ""))
		var zone := String(_zones.get(player_id, ""))
		if zone.is_empty():
			continue
		var final_zone: String = _rules.combat.blast_after_dodge(zone, bool(entry.get("dodging", false)))
		if final_zone.is_empty():
			continue
		out.append({
			"player_id": player_id,
			"name": String(entry.get("name", "Someone")),
			"zone": final_zone,
			"declared_zone": zone,
		})
	return out


func _submit() -> void:
	if _weapon.is_empty():
		return
	var targets := caught()
	if targets.is_empty():
		return
	var combat: Dictionary = _weapon.get("combat", {})
	var split: Dictionary = _rules.combat.split_weapon_type(String(combat.get("damage_type", combat.get("type", ""))))
	close({
		"weapon_name": String(_weapon.get("name", "")),
		"damage_text": String(combat.get("damage", "")),
		"impact_type": String(split.get("impact", "en")),
		"firepower": String(split.get("firepower", "O")),
		"targets": targets,
	})
