class_name FxPicker
extends VBoxContainer
##
## Browse FX schools, faiths and categories, and buy their powers.
##
## Shaped like SkillPicker on purpose. FX is a skill tree with the same three
## levels core skills have -- an axis to tab across, broads under it, and
## specialties under those -- so it gets the same navigation instead of the flat
## "chosen list plus two Add buttons" it had, which made you leave the tab to
## see what was even available.
##
## The axis here is category (Arcane Magic / Faith / Super Hero) rather than
## governing ability: every FX broad is Will-based, so ability tabs would be one
## useful button and five empty ones.
##
## The broad list is setting-gated in the rules layer via
## get_broad_skills_for_character, so Dark Matter faiths (Incantation) appear
## only while that setting is selected.
##

## The tab should persist the character.
signal change_requested

## Emitted with the skill record when someone asks to read one.
signal detail_requested(skill: Dictionary)

var _ctx: SheetContext

var _category := ""
var _query := ""

var _list: VBoxContainer
var _category_buttons: Dictionary = {}


func _init() -> void:
	add_theme_constant_override("separation", Widgets.GAP_ROW)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func setup(context: SheetContext) -> void:
	_ctx = context
	var categories := _categories()
	_category = "" if categories.is_empty() else String(categories[0])
	_build()


## The categories this character can actually reach, in catalog order.
##
## Derived rather than hardcoded so a setting that adds a category, or a data
## file that renames one, does not leave a dead tab behind.
func _categories() -> Array:
	var rules: AlternityRules = _ctx.rules
	var seen: Array = []
	for broad in rules.fx.get_broad_skills_for_character(_ctx.doc.raw()):
		var category := String(broad.get("category", "")).strip_edges()
		if category.is_empty() or seen.has(category):
			continue
		seen.append(category)
	return seen


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var search := SearchField.new()
	add_child(search)
	search.setup(_ctx.palette, "Search powers")
	search.set_query(_query)
	search.query_changed.connect(func(query: String):
		_query = query
		_refresh_list())

	_build_category_bar()

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", Widgets.GAP_ROW)
	add_child(_list)

	_refresh_list()


func _build_category_bar() -> void:
	var categories := _categories()
	if categories.size() < 2:
		return

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 44)
	add_child(scroll)

	var bar := HBoxContainer.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_constant_override("separation", 4)
	scroll.add_child(bar)

	for category in categories:
		var name := String(category)
		var button := Button.new()
		button.text = name
		button.toggle_mode = true
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button.button_pressed = name == _category
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 38)
		button.pressed.connect(func(): _select_category(name))
		bar.add_child(button)
		_category_buttons[name] = button


func _select_category(category: String) -> void:
	if category == _category:
		return
	_category = category
	for name in _category_buttons:
		_category_buttons[name].button_pressed = name == category
	_refresh_list()


## Rebuild only the list, never the search field, so the caret is never lost.
func _refresh_list() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	var shown := 0
	for broad in _visible_broads():
		_build_broad(broad)
		shown += 1

	if shown == 0:
		Widgets.muted_text(_list, "No powers match.", _ctx.palette)


func _visible_broads() -> Array:
	var rules: AlternityRules = _ctx.rules
	var out: Array = []
	for broad in rules.fx.get_broad_skills_for_character(_ctx.doc.raw()):
		if String(broad.get("category", "")) != _category:
			continue
		if not _matches(broad):
			continue
		out.append(broad)
	out.sort_custom(func(a, b): return String(a.get("name", "")) < String(b.get("name", "")))
	return out


## A broad matches if it or any of its powers matches, so searching for a power
## still shows the school it lives under.
func _matches(broad: Dictionary) -> bool:
	if _query.strip_edges().is_empty():
		return true
	var needle := _query.to_lower()
	if String(broad.get("name", "")).to_lower().contains(needle):
		return true
	for specialty in _specialties(String(broad.get("name", ""))):
		if String(specialty.get("name", "")).to_lower().contains(needle):
			return true
	return false


func _specialties(broad_name: String) -> Array:
	var rules: AlternityRules = _ctx.rules
	return rules.fx.get_specialty_skills_for_broad_and_character(broad_name, _ctx.doc.raw())


func _build_broad(broad: Dictionary) -> void:
	var rules: AlternityRules = _ctx.rules
	var palette := _ctx.palette
	var raw := _ctx.doc.raw()
	var broad_name := String(broad.get("name", ""))
	var owned: bool = rules.fx.is_fx_skill_selected(raw, broad_name)

	var box := Widgets.section(_list, "", palette)
	_build_row(box, broad, true)

	# A power cannot be used without its parent school, so listing powers before
	# the school is owned would offer something unbuyable.
	if not owned:
		Widgets.muted_text(
			box, "Take this school to unlock its powers.", palette, Widgets.FONT_CAPTION
		)
		return

	for specialty in _specialties(broad_name):
		_build_row(box, specialty, false)


func _build_row(parent: Container, skill: Dictionary, is_broad: bool) -> void:
	var rules: AlternityRules = _ctx.rules
	var doc := _ctx.doc
	var palette := _ctx.palette
	var raw := doc.raw()
	var skill_name := String(skill.get("name", ""))
	var rank: int = rules.fx.fx_skill_rank(raw, skill_name)
	var owned: bool = rules.fx.is_fx_skill_selected(raw, skill_name)

	# Same reasoning as the core skill rows: at 390px a name, its numbers and
	# two buttons cannot share a line and still leave the name readable.
	var compact := not _ctx.is_wide_layout

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", Widgets.GAP_ROW)
	parent.add_child(row)

	if not is_broad:
		var indent := Control.new()
		indent.custom_minimum_size = Vector2(Widgets.PAD_PANEL, 0)
		row.add_child(indent)

	var host: Container = row
	if compact:
		var stack := VBoxContainer.new()
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
		row.add_child(stack)
		host = stack

	# The name is a button: tapping a power is how you read what it does.
	var name_button := Button.new()
	name_button.text = skill_name
	name_button.tooltip_text = skill_name
	name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_button.clip_text = true
	name_button.custom_minimum_size = Vector2(1, 36)
	if is_broad:
		name_button.add_theme_color_override("font_color", palette.accent)
	name_button.pressed.connect(func(): detail_requested.emit(skill))
	host.add_child(name_button)

	var actions: Container = row
	if compact:
		actions = HBoxContainer.new()
		actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_theme_constant_override("separation", Widgets.GAP_ROW)
		host.add_child(actions)

	var score: Dictionary = rules.fx.fx_skill_score(raw, skill_name)
	var ordinary := AlternityNum.as_int(score.get("ordinary", 0))
	var die := String(score.get("die", ""))
	var reading := "Ordinary score %d, step die %s, rank %d" % [ordinary, die, rank]

	var stats := Label.new()
	stats.text = ("Rank %d   score %d   %s" % [rank, ordinary, die]) if owned else "Not taken"
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if compact else HORIZONTAL_ALIGNMENT_RIGHT
	stats.clip_text = true
	stats.custom_minimum_size = Vector2(1 if compact else 150, 0)
	stats.add_theme_color_override("font_color", palette.muted)
	stats.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
	stats.tooltip_text = reading
	# FX rows carry a wider "Remove" than the core skill rows do, so on compact
	# the numbers get their own line instead of being clipped to "Rank 1  score".
	if compact:
		host.add_child(stats)
		host.move_child(stats, actions.get_index())
	else:
		actions.add_child(stats)

	# A broad is owned or not; a power also has ranks to raise, so it keeps a
	# buy button after the first purchase where the broad does not.
	var can_buy := not owned or not is_broad
	if can_buy:
		var cost: int = rules.fx.fx_skill_cost(raw, skill_name)
		var buy := Widgets.cost_button("Take" if not owned else "+1", cost)
		buy.custom_minimum_size = Vector2(116, 36)
		buy.pressed.connect(func():
			doc.apply([CharacterDoc.FX], func(c): rules.fx.add_fx_skill(c, skill_name))
			change_requested.emit())
		actions.add_child(buy)

	if owned:
		var drop := Button.new()
		var is_rank_drop := not is_broad and rank > 1
		drop.text = "-1" if is_rank_drop else "Remove"
		drop.tooltip_text = "Drop a rank and refund its cost" if is_rank_drop else "Give up this power"
		drop.custom_minimum_size = Vector2(44 if is_rank_drop else 92, 36)
		drop.clip_text = true
		drop.pressed.connect(func():
			doc.apply([CharacterDoc.FX], func(c): rules.fx.remove_fx_skill(c, skill_name))
			change_requested.emit())
		actions.add_child(drop)

	# Only some powers can be made always-active, so the control appears only
	# where it applies rather than being drawn disabled everywhere.
	if owned and rules.fx.can_fx_skill_be_permanent(skill_name):
		var permanent: bool = rules.fx.is_fx_skill_permanent(raw, skill_name)
		var toggle := Widgets.toggle_row(host, "Always active (reserves pool)", permanent, palette)
		toggle.add_theme_font_size_override("font_size", Widgets.FONT_CAPTION)
		toggle.toggled.connect(func(pressed: bool):
			doc.apply([CharacterDoc.FX], func(c):
				rules.fx.set_fx_skill_permanent(c, skill_name, pressed))
			change_requested.emit())
