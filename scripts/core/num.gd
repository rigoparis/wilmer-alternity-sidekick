class_name AlternityNum
extends RefCounted
##
## Numeric coercion for values read out of stored character JSON.
##
## Saved characters do not have reliable types: JSON round-trips turn integers
## into floats (real saves in tests/fixtures/ contain "profession_id": 5.0), and
## older builds wrote some fields as strings. Every read of a numeric field goes
## through here.
##
## These are static because they are pure. They were previously instance methods
## on AlternityRules, which meant the rules sub-modules reached them through
## _get_parent()._as_int(...) -- a weakref dereference plus a dynamic dispatch on
## roughly 140 hot-path calls, for arithmetic that touches no state at all.
##
## AlternityRules keeps thin _as_int/_as_float forwarders so existing call sites
## continue to work; new code should call AlternityNum directly.
##


## Coerce to int, falling back to default_value for anything uncoercible.
## Accepts int, float (truncated), and numeric strings in either form.
static func as_int(value: Variant, default_value: int = 0) -> int:
	if value == null:
		return default_value

	match typeof(value):
		TYPE_INT:
			return value as int
		TYPE_FLOAT:
			return int(value as float)
		TYPE_STRING:
			var str_val := value as String
			if str_val.is_valid_int():
				return str_val.to_int()
			if str_val.is_valid_float():
				return int(str_val.to_float())
	return default_value


## Coerce to float, falling back to default_value for anything uncoercible.
##
## Note the asymmetry with as_int: there is no explicit null guard here. It is
## still safe -- typeof(null) is TYPE_NIL, which matches no case and falls
## through to default_value -- but it is safe by accident rather than by intent.
## Left as-is deliberately: this move must not change behaviour. Flagged for the
## rules/logic review.
static func as_float(value: Variant, default_value: float = 0.0) -> float:
	match typeof(value):
		TYPE_INT:
			return float(value)
		TYPE_FLOAT:
			return value
		TYPE_STRING:
			if String(value).is_valid_float():
				return float(value)
	return default_value
