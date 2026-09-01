class_name SkillDetail
extends RefCounted
##
## Structured content for a skill or FX power detail view.
##
## The target presentation uses named sections -- Effect, Decay Penalties,
## Duration, Synergies, Rank Benefits -- and which sections a skill has varies:
## not every power has rank benefits, and only some have a duration triple.
##
## The stored data cannot express that. Backing "Animate dead" today:
##
##     description: "Governing Ability: Will (WIL). Player Notes: This spell..."
##     meta:        "Cost: 4 skill points / This skill can't be used untrained /..."
##     rank_benefits: { "6": "At rank 6, any zombie...", "12": "..." }
##
## Labels live inside the prose and are applied unevenly across the 140 FX
## skills: "Governing Ability:" appears in 109, "Player Notes:" in 90,
## "Full Text:" in 28, "Modifiers:" in 18, then a one-off tail. That unevenness
## is why UIBuilder.format_note_with_bold_prefix() exists -- it bolds any
## pre-colon prefix under 45 characters and mis-fires on prose with a
## mid-sentence colon.
##
## So this reads BOTH shapes. If an entry has a "sections" array it is used
## directly; otherwise sections are synthesised from the legacy fields by
## splitting the prose on its inline labels. Nothing has to be migrated up
## front, entries can be rewritten one at a time, and the view is the same
## either way.
##

## A plain titled paragraph.
const KIND_TEXT := "text"

## An ordinary / good / amazing triple, as durations and effects are written.
const KIND_OUTCOMES := "outcomes"

## Rank thresholds with what each unlocks.
const KIND_RANKS := "ranks"

## Inline labels seen in the shipped FX descriptions, matched first so their
## capitalisation and spacing are preserved exactly.
const KNOWN_LABELS := [
	"Governing Ability",
	"Player Notes",
	"Full Text",
	"Modifiers",
	"Modifier",
	"Material Restrictions",
	"Duration Boosting",
	"Target Bonuses/Penalties",
	"Cooldown Constraint",
	"Entanglement Penalties",
	"Critical Failure Warning",
]

## Split only on the labels listed above, anchored to the start of the text or
## to a sentence end.
##
## A general "capitalised words followed by a colon" rule looks tempting and is
## wrong: it turns "The hero faces a choice: press on or retreat" into a section
## titled "The hero faces a choice". That is exactly the false positive
## UIBuilder.format_note_with_bold_prefix() makes, which is why this list is
## explicit rather than inferred. Rewritten entries never need it -- they carry
## a sections array.
static var _label_pattern: String = ""

static var _label_regex: RegEx

var title: String = ""

## One-line summary under the title: cost, energy, availability.
var subtitle: String = ""

## Ordered list of section dictionaries. See the KIND_* constants.
var sections: Array = []


## Build from a skill record, accepting either the new or the legacy shape.
static func from_data(data: Dictionary) -> SkillDetail:
	var detail := SkillDetail.new()
	detail.title = String(data.get("name", ""))
	detail.subtitle = String(data.get("meta", "")).strip_edges()

	if typeof(data.get("sections")) == TYPE_ARRAY and not data["sections"].is_empty():
		detail.sections = _sanitize(data["sections"])
	else:
		detail.sections = _from_legacy(data)
	return detail


## True when this record has already been rewritten into explicit sections.
static func is_structured(data: Dictionary) -> bool:
	return typeof(data.get("sections")) == TYPE_ARRAY and not data["sections"].is_empty()


func is_empty() -> bool:
	return sections.is_empty()


func section_titles() -> Array:
	var titles: Array = []
	for section in sections:
		titles.append(String(section.get("title", "")))
	return titles


func find_section(section_title: String) -> Dictionary:
	for section in sections:
		if String(section.get("title", "")).to_lower() == section_title.to_lower():
			return section
	return {}


static func text_section(section_title: String, body: String) -> Dictionary:
	return {"kind": KIND_TEXT, "title": section_title, "body": body}


static func outcomes_section(section_title: String, ordinary: String, good: String, amazing: String) -> Dictionary:
	return {
		"kind": KIND_OUTCOMES,
		"title": section_title,
		"ordinary": ordinary,
		"good": good,
		"amazing": amazing,
	}


## Rank entries carry a title as well as a body, which the legacy
## {rank: "flat string"} shape cannot express. The target wording is
## "Rank 6: More Durable Zombies -- ...", so the name is its own field.
static func ranks_section(section_title: String, entries: Array) -> Dictionary:
	return {"kind": KIND_RANKS, "title": section_title, "entries": entries}


static func rank_entry(rank: int, entry_title: String, body: String) -> Dictionary:
	return {"rank": rank, "title": entry_title, "body": body}


# --- Legacy synthesis ------------------------------------------------------

static func _from_legacy(data: Dictionary) -> Array:
	var built: Array = []

	for part in _split_labelled_prose(String(data.get("description", ""))):
		built.append(part)

	var ranks := _legacy_rank_entries(data.get("rank_benefits", {}))
	if not ranks.is_empty():
		built.append(ranks_section("Rank Benefits", ranks))

	return built


## Split prose that carries its own inline labels into titled sections.
##
## "Governing Ability: Will (WIL). Player Notes: This spell imbues..." becomes
## two sections rather than one paragraph with bolding guessed at display time.
## Text before the first label is kept as an untitled section so nothing is lost.
static func _split_labelled_prose(prose: String) -> Array:
	var clean := prose.strip_edges()
	if clean.is_empty():
		return []

	_ensure_regex()
	var matches := _label_regex.search_all(clean)
	if matches.is_empty():
		return [text_section("", clean)]

	var built: Array = []
	var lead := clean.substr(0, matches[0].get_start()).strip_edges()
	if not lead.is_empty():
		built.append(text_section("", lead))

	for i in matches.size():
		var current := matches[i]
		var body_start := current.get_end()
		var body_end := matches[i + 1].get_start() if i + 1 < matches.size() else clean.length()
		var body := clean.substr(body_start, body_end - body_start).strip_edges()
		if not body.is_empty():
			built.append(text_section(current.get_string(1).strip_edges(), body))
	return built


static func _legacy_rank_entries(raw: Variant) -> Array:
	if typeof(raw) != TYPE_DICTIONARY:
		return []
	var ranks: Array = raw.keys()
	# Keys are strings ("6", "12"), so sort numerically or 12 precedes 6.
	ranks.sort_custom(func(a, b): return AlternityNum.as_int(a) < AlternityNum.as_int(b))

	var entries: Array = []
	for key in ranks:
		var body := String(raw[key]).strip_edges()
		if body.is_empty():
			continue
		# Legacy entries have no per-benefit name; the title stays empty and the
		# view falls back to "Rank N".
		entries.append(rank_entry(AlternityNum.as_int(key), "", body))
	return entries


## Normalise an authored sections array: drop malformed entries, default the
## kind, and coerce rank numbers.
static func _sanitize(raw: Array) -> Array:
	var built: Array = []
	for item in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var kind := String(item.get("kind", KIND_TEXT))
		var section := {"kind": kind, "title": String(item.get("title", ""))}

		match kind:
			KIND_OUTCOMES:
				section["ordinary"] = String(item.get("ordinary", ""))
				section["good"] = String(item.get("good", ""))
				section["amazing"] = String(item.get("amazing", ""))
			KIND_RANKS:
				var entries: Array = []
				for entry in item.get("entries", []):
					if typeof(entry) != TYPE_DICTIONARY:
						continue
					entries.append(rank_entry(
						AlternityNum.as_int(entry.get("rank", 0)),
						String(entry.get("title", "")),
						String(entry.get("body", ""))
					))
				section["entries"] = entries
			_:
				# Unknown kinds degrade to text rather than vanishing, so a
				# section type added to the data before the view knows about it
				# still shows its content.
				section["kind"] = KIND_TEXT
				section["body"] = String(item.get("body", ""))
		built.append(section)
	return built


static func _ensure_regex() -> void:
	if _label_regex != null:
		return
	# Longest first, so "Modifiers" is preferred over the "Modifier" prefix.
	var sorted_labels := KNOWN_LABELS.duplicate()
	sorted_labels.sort_custom(func(a, b): return a.length() > b.length())
	_label_pattern = "(?:^|(?<=[.!?])\\s+)(%s):\\s*" % "|".join(sorted_labels)
	_label_regex = RegEx.new()
	_label_regex.compile(_label_pattern)
