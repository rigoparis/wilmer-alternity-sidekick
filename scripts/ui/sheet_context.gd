class_name SheetContext
extends RefCounted
##
## Everything a tab needs, handed to it once.
##
## Replaces the ambient state the old renderers read off the shell: `rules`,
## `char_manager`, `character`, `content`, `is_wide_layout` and eight colour
## members, all reached as `self.` from 160 functions in one file. A tab now
## receives its dependencies explicitly and holds nothing global.
##
## Deliberately not an autoload. A GM view will eventually show several
## characters at once, so there must be no single ambient "current character" --
## each view gets its own context.
##

## The character this view edits. Mutations go through doc.apply().
var doc: CharacterDoc

## The rules engine. Shared across contexts: it is catalog data plus pure
## functions, with no per-character state.
##
## Typed rather than left as a Variant. Untyped inference is an error in this
## project, so an untyped handle makes every `var x := rules.something()` in
## every tab a parse error, and forces an explicit annotation on each. Typing it
## once here fixes all of them -- and lets the parser check arity, turning
## wrong-argument calls into parse errors instead of runtime ones.
var rules: AlternityRules

## Navigation, for opening catalogs, forms and detail views.
var router: UiRouter

## Colours in force. Reread on ThemeService.palette_changed rather than cached
## for the lifetime of a view.
var palette: ThemePalette

## True on tablet and desktop widths, where side-by-side layouts are usable.
## Tabs should treat this as a hint, not a platform check.
var is_wide_layout: bool = false


func _init(
	p_doc: CharacterDoc = null,
	p_rules: AlternityRules = null,
	p_router: UiRouter = null,
	p_palette: ThemePalette = null,
	p_is_wide: bool = false
) -> void:
	doc = p_doc
	rules = p_rules
	router = p_router
	palette = p_palette if p_palette != null else ThemePalette.new()
	is_wide_layout = p_is_wide


## A copy pointing at a different character, keeping the shared services.
##
## This is how a GM view will open several sheets without duplicating the rules
## engine or the router.
func for_document(other_doc: CharacterDoc) -> SheetContext:
	return SheetContext.new(other_doc, rules, router, palette, is_wide_layout)


func is_valid() -> bool:
	return doc != null and rules != null
