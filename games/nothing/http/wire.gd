class_name Wire
extends RefCounted

## JSON as it goes over the wire: written the way JavaScript's JSON.stringify
## writes it (no spaces, whole numbers without a point, keys in the order
## they were put in), and read strictly, the way JSON.parse reads it.


static func write(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT:
			return str(value)
		TYPE_FLOAT:
			var f: float = value
			return str(int(f)) if f == floorf(f) and absf(f) < 1e15 else str(f)
		TYPE_STRING, TYPE_STRING_NAME:
			return JSON.stringify(str(value))
		TYPE_ARRAY:
			var parts := PackedStringArray()
			for v: Variant in value:
				parts.append(write(v))
			return "[" + ",".join(parts) + "]"
		TYPE_DICTIONARY:
			var parts := PackedStringArray()
			for k: Variant in value:
				parts.append(JSON.stringify(str(k)) + ":" + write(value[k]))
			return "{" + ",".join(parts) + "}"
	return JSON.stringify(value)


## The value in `text`, or null if it isn't JSON. Read strictly, as RFC 8259
## and JavaScript's JSON.parse read it (Godot's own reader lets a trailing
## comma through, so this doesn't use it): double-quoted strings and keys,
## no trailing commas, nothing after the value but whitespace.
static func read(text: String) -> Variant:
	var r := _Reader.new(text)
	r.space()
	var value: Variant = r.value()
	r.space()
	if r.bad or r.at < text.length():
		return null
	return value


class _Reader:
	var text: String
	var at: int = 0
	var bad: bool = false

	func _init(t: String) -> void:
		text = t

	func peek() -> String:
		return text[at] if at < text.length() else ""

	func space() -> void:
		while at < text.length() and text[at] in [" ", "\t", "\n", "\r"]:
			at += 1

	func value() -> Variant:
		match peek():
			"{":
				return object()
			"[":
				return array()
			"\"":
				return string()
			"t":
				return word("true", true)
			"f":
				return word("false", false)
			"n":
				return word("null", null)
		if peek() == "-" or peek().is_valid_int():
			return number()
		bad = true
		return null

	func word(w: String, v: Variant) -> Variant:
		if text.substr(at, w.length()) != w:
			bad = true
			return null
		at += w.length()
		return v

	func number() -> Variant:
		var start := at
		if peek() == "-":
			at += 1
		if peek() == "0":
			at += 1
		elif peek().is_valid_int():
			while peek().is_valid_int():
				at += 1
		else:
			bad = true
			return null
		if peek() == ".":
			at += 1
			if not peek().is_valid_int():
				bad = true
				return null
			while peek().is_valid_int():
				at += 1
		if peek() == "e" or peek() == "E":
			at += 1
			if peek() == "+" or peek() == "-":
				at += 1
			if not peek().is_valid_int():
				bad = true
				return null
			while peek().is_valid_int():
				at += 1
		return text.substr(start, at - start).to_float()

	func string() -> Variant:
		var start := at
		at += 1
		while at < text.length() and text[at] != "\"":
			var c := text[at]
			if c.unicode_at(0) < 32:
				bad = true
				return null
			if c == "\\":
				at += 1
				if at >= text.length() or not text[at] in ["\"", "\\", "/", "b", "f", "n", "r", "t", "u"]:
					bad = true
					return null
				if text[at] == "u":
					var hex := text.substr(at + 1, 4)
					if hex.length() < 4 or not hex.is_valid_hex_number():
						bad = true
						return null
					at += 4
			at += 1
		if at >= text.length():
			bad = true
			return null
		at += 1
		var parsed: Variant = JSON.parse_string(text.substr(start, at - start))
		return str(parsed) if parsed != null else ""

	func array() -> Variant:
		var out: Array = []
		at += 1
		space()
		if peek() == "]":
			at += 1
			return out
		while not bad:
			space()
			out.append(value())
			space()
			if peek() == ",":
				at += 1
			elif peek() == "]":
				at += 1
				return out
			else:
				bad = true
		return null

	func object() -> Variant:
		var out := {}
		at += 1
		space()
		if peek() == "}":
			at += 1
			return out
		while not bad:
			space()
			if peek() != "\"":
				bad = true
				return null
			var key := str(string())
			space()
			if peek() != ":":
				bad = true
				return null
			at += 1
			space()
			out[key] = value()
			space()
			if peek() == ",":
				at += 1
			elif peek() == "}":
				at += 1
				return out
			else:
				bad = true
		return null
