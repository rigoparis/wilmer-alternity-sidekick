class_name RandomSource
extends RefCounted
##
## Where dice results come from.
##
## Two implementations are intended:
##
##   RngSource            a seeded RandomNumberGenerator. Used by the rules
##                        engine (mutation tables) and by every headless test,
##                        neither of which has a physics scene.
##
##   PhysicalDiceSource   reads the settled faces of tumbling 3D dice, which is
##                        authoritative for rolls made at the table. Not built
##                        yet; the tray is a later phase.
##
## The split exists so the rules layer stays testable. If rule code called the
## tray directly, generating a mutant would need a 3D scene and could not run
## headless.
##
## roll() is declared to return a RollResult but implementations may be async --
## the physical source has to await the dice settling. Callers should treat the
## return value as awaitable:
##
##     var result: RollResult = await source.roll(term)
##
## Awaiting a non-coroutine is a no-op in GDScript, so the same call site works
## for both.
##

## Resolve one parsed notation term (see DiceNotation.parse) into a result.
func roll(_term: Dictionary, _label: String = "") -> RollResult:
	push_error("RandomSource.roll is abstract -- use RngSource or PhysicalDiceSource")
	return RollResult.new()


## Convenience: parse and roll in one step. Returns a result with ok=false
## semantics (an empty notation and zero total) if the text does not parse.
func roll_notation(text: String, label: String = "") -> RollResult:
	var term := DiceNotation.parse(text)
	if not bool(term.get("ok", false)):
		var empty := RollResult.new()
		empty.notation = text
		empty.label = label
		empty.timestamp = int(Time.get_unix_time_from_system())
		return empty
	return await roll(term, label)
