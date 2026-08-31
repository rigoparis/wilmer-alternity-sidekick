class_name CharacterDoc
extends RefCounted
##
## Owns one character and announces what changed about it.
##
## The problem this solves: main.gd and CharacterManager both held the *same*
## Dictionary (dictionaries are reference types in Godot 4), and main.gd wrote
## into it directly in 24 places. The CharacterManager signals were therefore
## advisory -- most edits bypassed them entirely, which is why the UI had to
## fall back on rebuilding the whole active tab after every change, 67 times
## over.
##
## Here the Dictionary is private. Every mutation goes through apply(), which
## requires the caller to declare which sections it touched, and emits them.
## Views subscribe to `changed` and refresh only what is affected.
##
## The stored JSON shape is unchanged -- to_dict() round-trips with what the app
## already saves. That matters both for existing saves and because the same
## shape is what will eventually travel over the network.
##
## The rules engine keeps its `character: Dictionary` API; apply() hands the raw
## dictionary to a callable rather than this class wrapping 133 rules functions:
##
##     doc.apply([CharacterDoc.EQUIPMENT], func(c):
##         return rules.equipment.add_equipment_to_character(c, item_id, 1))
##

## Emitted after any mutation, carrying the affected section names.
signal changed(sections: PackedStringArray)

## Emitted when the unsaved-changes state flips.
signal dirty_changed(is_dirty: bool)

# Section names. A view listens for the ones it renders.
const META := &"meta"
const ABILITIES := &"abilities"
const SKILLS := &"skills"
const PERKS_FLAWS := &"perks_flaws"
const EQUIPMENT := &"equipment"
const CYBERTECH := &"cybertech"
const FX := &"fx"
const ACHIEVEMENTS := &"achievements"
const MUTATIONS := &"mutations"
const DAMAGE := &"damage"
const OPTIONAL_RULES := &"optional_rules"
const NOTES := &"notes"

## Every section, for mutations whose blast radius is broad or unknown.
const ALL: Array[StringName] = [
	META, ABILITIES, SKILLS, PERKS_FLAWS, EQUIPMENT, CYBERTECH,
	FX, ACHIEVEMENTS, MUTATIONS, DAMAGE, OPTIONAL_RULES, NOTES,
]

var _rules
var _data: Dictionary = {}
var _summary_cache: Dictionary = {}
var _summary_valid: bool = false
var _dirty: bool = false

## Filename this document was loaded from / saves to. Empty for a new character.
var source_file: String = ""


func _init(rules, data: Dictionary = {}) -> void:
	_rules = rules
	_data = data if not data.is_empty() else _rules.default_character()
	_rules.ensure_character_shape(_data)


static func from_dict(rules, data: Dictionary, file_name: String = "") -> CharacterDoc:
	var doc := CharacterDoc.new(rules, data.duplicate(true))
	doc.source_file = file_name
	return doc


## A deep copy in the stored JSON shape, safe to serialize or hand to a peer.
func to_dict() -> Dictionary:
	var out := _data.duplicate(true)
	# Transient memo the equipment module writes onto the character for O(1)
	# custom-item lookups. Never part of the saved shape.
	if typeof(out.get("equipment")) == TYPE_DICTIONARY:
		out["equipment"].erase("_custom_items_by_id")
	return out


## Escape hatch to the raw dictionary, for reads.
##
## Needed while the rules engine and the old UI still take `character:
## Dictionary`. Do not mutate what this returns -- mutations must go through
## apply() so the change is announced and the summary cache invalidated.
func raw() -> Dictionary:
	return _data


## The single mutation entry point.
##
## `sections` declares what the action touches, so listeners can refresh
## selectively; pass CharacterDoc.ALL when the blast radius is broad. The
## callable receives the raw dictionary and its return value is passed back, so
## rules functions that report success keep working:
##
##     var ok = doc.apply([CharacterDoc.MUTATIONS], func(c):
##         return rules.mutations.add_mutation_advantage(c, "improved_str"))
func apply(sections: Array, action: Callable) -> Variant:
	var result: Variant = action.call(_data)
	_invalidate(sections)
	return result


## Mark sections changed after a mutation made some other way.
##
## Only for code that still edits the raw dictionary directly, so it can at
## least announce itself. New code should use apply().
func touch(sections: Array) -> void:
	_invalidate(sections)


func _invalidate(sections: Array) -> void:
	_summary_valid = false
	_summary_cache.clear()
	_set_dirty(true)

	var names := PackedStringArray()
	for section in sections:
		names.append(String(section))
	changed.emit(names)


## Computed summary, cached until the next mutation.
##
## The cache lives here rather than on AlternityRules, which held a single slot
## keyed on character.hash(): with one slot, a GM viewing several characters
## would miss on every switch and pay the full cost each time. Per-document
## caching also means invalidation is driven by actual edits instead of a hash
## comparison, so it cannot be fooled by summary() writing back onto the
## character as a side effect.
##
## Returns a copy: the previous implementation handed out the live cached
## dictionary, letting callers mutate the cache.
func summary() -> Dictionary:
	if not _summary_valid:
		_summary_cache = _rules.summary(_data)
		_summary_valid = true
	return _summary_cache.duplicate(true)


func is_dirty() -> bool:
	return _dirty


## Called by the store after a successful save.
func mark_saved() -> void:
	_set_dirty(false)


func _set_dirty(value: bool) -> void:
	if _dirty == value:
		return
	_dirty = value
	dirty_changed.emit(_dirty)


# --- Typed accessors -------------------------------------------------------
#
# Only for the scalar fields the UI reads and writes constantly. Anything
# structural stays behind apply() plus the rules API rather than being
# re-implemented here.

func get_hero_name() -> String:
	return String(_data.get("hero_name", ""))


func set_hero_name(value: String) -> void:
	if get_hero_name() == value:
		return
	_data["hero_name"] = value
	_invalidate([META])


func get_player_name() -> String:
	return String(_data.get("player_name", ""))


func set_player_name(value: String) -> void:
	if get_player_name() == value:
		return
	_data["player_name"] = value
	_invalidate([META])


func get_career() -> String:
	return String(_data.get("career", ""))


func set_career(value: String) -> void:
	if get_career() == value:
		return
	_data["career"] = value
	_invalidate([META])


func get_notes() -> String:
	return String(_data.get("notes", ""))


func set_notes(value: String) -> void:
	if get_notes() == value:
		return
	_data["notes"] = value
	_invalidate([NOTES])


func get_species_id() -> int:
	return AlternityNum.as_int(_data.get("species_id", 0))


func set_species_id(value: int) -> void:
	if get_species_id() == value:
		return
	_data["species_id"] = value
	# Species gates mutations and shifts ability limits and free skills, so the
	# blast radius here really is everything.
	_invalidate(ALL)


func get_profession_id() -> int:
	return AlternityNum.as_int(_data.get("profession_id", 0))


func set_profession_id(value: int) -> void:
	if get_profession_id() == value:
		return
	_data["profession_id"] = value
	# Profession changes skill costs, ability minimums and achievement profile.
	_invalidate(ALL)


func get_ability(ability: StringName) -> int:
	return AlternityNum.as_int(_data.get("abilities", {}).get(String(ability), 10))


## Set one ability score, clamped to the legal range for this character.
func set_ability(ability: StringName, value: int) -> void:
	var key := String(ability)
	var limits: Array = _rules.ability_limits(_data, key)
	var minimum: int = AlternityNum.as_int(limits[0], 4) if limits.size() > 0 else 4
	var maximum: int = AlternityNum.as_int(limits[1], 14) if limits.size() > 1 else 14
	var clamped: int = clampi(value, minimum, maximum)
	if get_ability(ability) == clamped:
		return

	var abilities: Dictionary = _data.get("abilities", {})
	abilities[key] = clamped
	_data["abilities"] = abilities
	_rules.clamp_trackers(_data)
	# Abilities feed skills, durability, equipment loads and action checks.
	_invalidate(ALL)
