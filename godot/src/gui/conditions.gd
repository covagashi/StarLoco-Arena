class_name GuiConditions
extends RefCounted
## Evaluates XULOR2 condition trees: {op, value, key, children}.
## Ops: isNull/isNotNull/isTrue/isFalse/isGreater/isLess/isEqual/
## isDifferent/isNullOrEmpty/isNotNullOrEmpty/Not/and/or plus the
## scope wrappers itemCondition (against the item) and listCondition
## key=X (against ctx[key]: index/count/selectedIndex...).

static func eval(node: Dictionary, v, ctx := {}) -> bool:
	if node.is_empty():
		return true
	var kids: Array = node.get("children", [])
	# a <property name= attribute="comparedValue"><valueReplacer/> child
	# replaces the tested operand with a resolved model value
	if not kids.is_empty() and String(kids[0].get("op", "")) == "propertyValue":
		v = resolve(kids[0], ctx)
	match String(node.get("op", "")):
		"itemCondition", "condition":
			return kids.is_empty() or eval(kids[0], v, ctx)
		"listCondition":
			var lv = ctx.get(node.get("key", ""), null)
			return kids.is_empty() or eval(kids[0], lv, ctx)
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
		"Not", "not":
			return not (kids.size() > 0 and eval(kids[0], v, ctx))
		"and":
			for k in kids:
				if not eval(k, v, ctx):
					return false
			return true
		"or":
			for k in kids:
				if eval(k, v, ctx):
					return true
			return false
		"propertyValue", "valueReplacer":
			# value-producing nodes evaluated as operands elsewhere —
			# standalone they just test truthiness of the resolution
			return _truthy(resolve(node, ctx))
	return true


## value-producing cond nodes: <property name= attribute=> resolves a model
## path; a nested <valueReplacer key=> transforms it (size → element count)
static func resolve(node: Dictionary, ctx := {}) -> Variant:
	match String(node.get("op", "")):
		"propertyValue":
			var m = ctx.get("model")
			if m == null:
				return null
			var v2 = m.get_value(node.get("name", ""))
			var kids2: Array = node.get("children", [])
			if not kids2.is_empty():
				return _apply_replacer(kids2[0].get("key", ""), v2)
			return v2
		"valueReplacer":
			return null
	return null


static func _apply_replacer(key: String, v) -> Variant:
	match key:
		"size":
			if v is Array or v is Dictionary or v is String:
				return v.size()
			return 0
	return v


static func _truthy(v) -> bool:
	if v is bool:
		return v
	if v is String:
		return v == "true" or v == "1"
	if v is int or v is float:
		return v != 0
	return v != null


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
