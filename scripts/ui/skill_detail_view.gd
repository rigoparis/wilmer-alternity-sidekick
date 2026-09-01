class_name SkillDetailView
extends VBoxContainer
##
## Renders a SkillDetail. One renderer per section kind, plus a text fallback.
##
## Replaces two functions that had diverged despite showing the same kind of
## thing: _refresh_skill_details_panel (63 lines, core skills) and
## _refresh_fx_skill_details_panel (135 lines, FX powers). Both rebuilt an
## overlay body by hand, and only one of them learned each presentation
## improvement.
##
## Adding a section kind later means adding one branch here, not touching the
## view's structure -- and an unknown kind already degrades to text in
## SkillDetail._sanitize, so data can lead the code.
##

const Detail := preload("res://scripts/core/skill_detail.gd")

var _palette: ThemePalette


func _init() -> void:
	add_theme_constant_override("separation", Widgets.GAP_SECTION)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func render(detail: SkillDetail, palette: ThemePalette) -> void:
	_palette = palette
	for child in get_children():
		remove_child(child)
		child.queue_free()

	if not detail.subtitle.is_empty():
		Widgets.muted_text(self, detail.subtitle, palette, Widgets.FONT_CAPTION)

	if detail.is_empty():
		Widgets.muted_text(self, "No description recorded for this skill.", palette)
		return

	for section in detail.sections:
		_render_section(section)


func _render_section(section: Dictionary) -> void:
	match String(section.get("kind", Detail.KIND_TEXT)):
		Detail.KIND_OUTCOMES:
			_render_outcomes(section)
		Detail.KIND_RANKS:
			_render_ranks(section)
		_:
			_render_text(section)


func _render_text(section: Dictionary) -> void:
	var body := String(section.get("body", "")).strip_edges()
	if body.is_empty():
		return
	var box := _block(String(section.get("title", "")))
	Widgets.text(box, body, _palette, Widgets.FONT_DETAIL)


## Ordinary / good / amazing, laid out as rows so the degrees line up rather
## than running together in a sentence.
func _render_outcomes(section: Dictionary) -> void:
	var box := _block(String(section.get("title", "")))
	for degree in ["ordinary", "good", "amazing"]:
		var value := String(section.get(degree, "")).strip_edges()
		if value.is_empty():
			continue
		Widgets.metric(box, degree.capitalize(), value, _palette)


## Rank thresholds. Entries carry their own name where the data provides one;
## legacy entries have none, so the row falls back to "Rank N".
func _render_ranks(section: Dictionary) -> void:
	var box := _block(String(section.get("title", "Rank Benefits")))
	for entry in section.get("entries", []):
		var rank := AlternityNum.as_int(entry.get("rank", 0))
		var entry_title := String(entry.get("title", "")).strip_edges()
		var body := String(entry.get("body", "")).strip_edges()

		var heading := "Rank %d" % rank
		if not entry_title.is_empty():
			heading += ": %s" % entry_title

		var label := Widgets.text(box, heading, _palette, Widgets.FONT_DETAIL, _palette.accent)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		if not body.is_empty():
			var indent := HBoxContainer.new()
			indent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			box.add_child(indent)
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(Widgets.PAD_PANEL, 0)
			indent.add_child(spacer)
			var body_label := Widgets.muted_text(indent, body, _palette)
			body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## A titled group. An untitled section (prose before the first inline label)
## still gets its own block so spacing stays even.
func _block(section_title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", Widgets.GAP_TIGHT)
	add_child(box)

	if not section_title.is_empty():
		Widgets.subheading(box, section_title, _palette)
	return box
