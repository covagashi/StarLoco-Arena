class_name GuiConditions
extends RefCounted
## Evaluates XULOR2 condition trees: {op, value, children}.
## Ops: isNull/isNotNull/isTrue/isFalse/isGreater/isLess/isEqual/
## isDifferent/isNullOrEmpty/isNotNullOrEmpty/Not/and/or.

static func eval(node: Dictionary, v) -> bool:
	if node.is_empty():
		return true
	match String(node.get("op", "")):
		"isNull":
			return v == null
		"isNotNull":
			return v != null
		"isTrue":
			return _truthy(v)
		"isFalse":
			return not _truthy(v)
		"isGreater":
			return _num(v) > _num(node.get("value", "0"))
		"isLess":
			return _num(v) < _num(node.get("value", "0"))
		"isEqual":
			return _eq(v, node.get("value", ""))
		"isDifferent":
			return not _eq(v, node.get("value", ""))
		"isNullOrEmpty":
			return v == null or (v is Array and v.is_empty()) \
				or (v is String and v == "")
		"isNotNullOrEmpty":
			return not (v == null or (v is Array and v.is_empty()) \
				or (v is String and v == ""))
		"Not":
			var kids: Array = node.get("children", [])
			return not (kids.size() > 0 and eval(kids[0], v))
		"and":
			for k in node.get("children", []):
				if not eval(k, v):
					return false
			return true
		"or":
			for k in node.get("children", []):
				if eval(k, v):
					return true
			return false
	return true


static func _truthy(v) -> bool:
	if v is bool:
		return v
	if v is String:
		return v == "true" or v == "1"
	return v != null and v != 0 and v != 0.0


static func _num(v) -> float:
	if v is float or v is int:
		return float(v)
	if v is String and v.is_valid_float():
		return v.to_float()
	return 0.0


static func _eq(v, s: String) -> bool:
	if v is bool:
		return v == (s == "true")
	if v is float or v is int:
		return float(v) == _num(s)
	return str(v) == s
