class_name CharacterSnapshot
extends RefCounted
##
## The copy of a hero a player's device commits to a campaign.
##
## A player picks their character when they join, and that character is committed
## to the table: the GM can open its sheet and read anything on it. Earlier this
## carried only the numbers a GM asks for out loud -- durability, action check,
## last resorts -- on the theory that sending less was safer. It was the wrong
## trade. A GM who cannot see a player's skills cannot rule on a check involving
## them, and the numbers alone made the roster a wall of digits with no character
## behind it.
##
## Sending the whole sheet does not weaken the ownership rule, because ownership
## was never about what crossed the wire. It is about who writes:
##
##     the player's device   owns the character file and is its only writer
##     the GM's device       holds a copy, renders it, and never writes it back
##
## A snapshot is a fact about the past, taken when the character changed. Nothing
## on the GM's side can edit one, and nothing sends one back.
##

## Bumped when the stored shape changes.
##
## 2 carries the whole character. A version 1 snapshot held only derived numbers
## and cannot be opened as a sheet, so it is refused rather than shown half-empty.
const FORMAT_VERSION := 2


## Take a snapshot of a loaded character.
static func of_doc(doc: CharacterDoc) -> Dictionary:
	if doc == null:
		return {}
	var summary := doc.summary()
	return {
		"format_version": FORMAT_VERSION,
		"hero_name": doc.get_hero_name(),
		"level": AlternityNum.as_int(summary.get("achievement_level", 1), 1),
		# The whole character. Everything the GM's roster shows is derived from
		# this through the rules engine rather than shipped beside it, so the two
		# devices cannot disagree about a number.
		"character": doc.raw().duplicate(true),
		"source_file": doc.source_file,
		"taken_at": int(Time.get_unix_time_from_system()),
	}


## Whether a received snapshot is worth showing.
##
## Checked rather than trusted: it arrives from another device. A version this
## build does not know is refused outright, because showing a partly understood
## character is worse than showing none -- the missing halves would read as
## zeroes, which look exactly like a real hero with nothing on their sheet.
static func is_usable(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	if AlternityNum.as_int(snapshot.get("format_version", 0)) != FORMAT_VERSION:
		return false
	return typeof(snapshot.get("character")) == TYPE_DICTIONARY


## The committed character, or {} if there is not a usable one.
##
## Duplicated on the way out. The GM's copy is read-only by rule, and handing out
## the stored dictionary would make that rule depend on every caller remembering
## it.
static func character_of(snapshot: Dictionary) -> Dictionary:
	if not is_usable(snapshot):
		return {}
	return (snapshot.get("character") as Dictionary).duplicate(true)


## Open the committed character as a document the sheet can render.
##
## Deliberately not given a `source_file`: a document with one could be saved,
## and the GM's copy must never be written to disk on the GM's device.
static func doc_of(snapshot: Dictionary, rules) -> CharacterDoc:
	var character := character_of(snapshot)
	if character.is_empty() or rules == null:
		return null
	return CharacterDoc.from_dict(rules, character)


static func hero_name_of(snapshot: Dictionary) -> String:
	return String(snapshot.get("hero_name", ""))


## How long ago a snapshot was taken, in seconds, or -1 when it does not say.
##
## Negative clock skew between two devices is clamped away: "taken -4 seconds
## ago" helps nobody.
static func age_seconds(snapshot: Dictionary) -> int:
	var taken := AlternityNum.as_int(snapshot.get("taken_at", 0))
	if taken <= 0:
		return -1
	return maxi(0, int(Time.get_unix_time_from_system()) - taken)


## "just now", "4 minutes ago", or "at some point".
static func freshness(snapshot: Dictionary) -> String:
	var age := age_seconds(snapshot)
	if age < 0:
		return "at some point"
	if age < 60:
		return "just now"
	if age < 3600:
		return "%d minutes ago" % int(age / 60.0)
	return "%d hours ago" % int(age / 3600.0)
