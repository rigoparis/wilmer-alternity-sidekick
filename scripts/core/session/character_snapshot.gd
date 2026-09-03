class_name CharacterSnapshot
extends RefCounted
##
## The read-only view of a hero that a player's device sends the GM.
##
## MULTIPLAYER.md leaves the character sync policy open and names the two
## choices. This is the snapshot-on-change half, and the reason it wins is not
## bandwidth -- it is ownership. A live view would mean the GM's screen holds a
## second copy of a document the player is editing, and every CharacterDoc signal
## becomes a network event. A snapshot is a fact about the past, which nobody can
## be confused about who owns.
##
## What is included is what a GM asks for out loud mid-session: the name, the
## durability track, the action check, last resorts, and how much damage is
## marked. What is deliberately excluded is everything a GM would have to be able
## to edit to make use of -- skills, equipment, perks. Sending those would invite
## exactly the two-writer situation the conflict rule forbids.
##
## Built from the character's own summary rather than recomputed, for the same
## reason the GM screen reads a local character's summary: a second calculation
## of durability is a second answer to a question that must have one.
##

## Bumped when the shape changes, so a GM on a newer build can tell an older
## player's snapshot from a malformed one.
const FORMAT_VERSION := 1


## Take a snapshot of a loaded character.
static func of_doc(doc: CharacterDoc) -> Dictionary:
	if doc == null:
		return {}
	var summary := doc.summary()
	var raw := doc.raw()
	return {
		"format_version": FORMAT_VERSION,
		"hero_name": doc.get_hero_name(),
		"level": AlternityNum.as_int(summary.get("achievement_level", 1), 1),
		"durability": summary.get("durability", {}),
		"action_check": summary.get("action_check", {}),
		"last_resorts": summary.get("last_resorts", {}),
		# What is already marked off, which is the number a GM actually needs
		# mid-fight and the one that changes most often.
		"damage": raw.get("damage", {}).duplicate(true) if typeof(raw.get("damage")) == TYPE_DICTIONARY else {},
		"taken_at": int(Time.get_unix_time_from_system()),
	}


## Whether a received snapshot is worth showing.
##
## A snapshot arrives over the network from another device, so it is checked
## rather than trusted: a version this build does not know is shown as nothing
## rather than as a set of zeroes that would read as a real character with no
## durability at all.
static func is_usable(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	if AlternityNum.as_int(snapshot.get("format_version", 0)) != FORMAT_VERSION:
		return false
	return typeof(snapshot.get("durability")) == TYPE_DICTIONARY


## How long ago a snapshot was taken, in seconds. Negative clock skew between two
## devices is clamped away: "taken -4 seconds ago" helps nobody.
static func age_seconds(snapshot: Dictionary) -> int:
	var taken := AlternityNum.as_int(snapshot.get("taken_at", 0))
	if taken <= 0:
		return -1
	return maxi(0, int(Time.get_unix_time_from_system()) - taken)
