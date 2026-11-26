class_name Rx
extends RefCounted

## A poster's pattern: a row of chips, each a piece of regular expression.
## The chips are joined and handed to Godot's RegEx, which is PCRE2, so what
## lights up on a line is what a real regex engine matched.
##
## Before that, `check` reads the chips for the mistakes a regex engine
## refuses (a counter with nothing to count, a ) with no (, and so on), in
## the Kid's words rather than the engine's. It is as strict as JavaScript's
## engine, which is stricter than PCRE2 in a few places (PCRE2 would read
## `a?+` as a possessive counter; JavaScript and this game call it an error),
## so a poster that works here works in both. tests/verify_regex.ts runs
## every pattern the tests try through JavaScript's RegExp and demands the
## same matches and the same refusals.
##
## One rule is the game's own: \1 must come after group 1 has closed.
## JavaScript lets it come early (and matches nothing with it); PCRE2
## refuses to match. Neither is any use, so the Kid says so. It is marked
## `house` so the verifier knows not to expect an error from JavaScript.

const QUANTIFIERS := ["*", "+", "?"]

static var _cache: Dictionary = {}


## "quant", "place" (matches a position, no characters), "open", "close",
## "pipe", "ref" or "atom".
static func kind(token: String) -> String:
	if token in QUANTIFIERS or (token.begins_with("{") and token.ends_with("}")):
		return "quant"
	if token in ["^", "$", "\\b"]:
		return "place"
	if token == "(":
		return "open"
	if token == ")":
		return "close"
	if token == "|":
		return "pipe"
	if token.length() == 2 and token[0] == "\\" and token[1].is_valid_int():
		return "ref"
	return "atom"


static func text(tokens: Array) -> String:
	return "".join(PackedStringArray(tokens))


## {} if the chips make a pattern a regex engine accepts; otherwise
## {"error": a key into data/jobs.json's errors, "at": the chip's index,
## "token": the chip, "house": true if it's this game's rule alone}.
static func check(tokens: Array) -> Dictionary:
	var prev := "start"
	var open: Array = []
	var opened := 0
	for i in tokens.size():
		var token := str(tokens[i])
		var k := kind(token)
		match k:
			"quant":
				if prev == "quant":
					if token != "?":
						return {"error": "repeat_twice", "at": i, "token": token}
					prev = "lazy"
					continue
				if prev == "lazy":
					return {"error": "lazy_twice" if token == "?" else "repeat_twice", "at": i, "token": token}
				if prev == "place":
					return {"error": "repeat_place", "at": i, "token": token}
				if prev != "atom" and prev != "close":
					return {"error": "repeat_start", "at": i, "token": token}
				prev = "quant"
				continue
			"open":
				opened += 1
				open.append(opened)
			"close":
				if open.is_empty():
					return {"error": "close", "at": i, "token": token}
				open.pop_back()
			"ref":
				var n := int(token.substr(1))
				# Group n is closed once n groups have opened and it isn't
				# still on the stack.
				if n < 1 or n > opened or open.has(n):
					return {"error": "ref_early", "at": i, "token": token, "house": true}
				prev = "atom"
				continue
		prev = k
	if not open.is_empty():
		return {"error": "open", "at": tokens.size() - 1, "token": "("}
	return {}


static func compiled(pattern: String) -> RegEx:
	if not _cache.has(pattern):
		if _cache.size() > 4000:
			_cache.clear()
		var regex := RegEx.new()
		_cache[pattern] = regex if regex.compile(pattern, false) == OK else null
	return _cache[pattern]


## The first match of `pattern` in `subject`: {"found": false}, or
## {"found": true, "start", "end", "groups": [[start, end], ...]} with group 0
## first and [-1, -1] for a group that took no part.
static func search(pattern: String, subject: String) -> Dictionary:
	var regex := compiled(pattern)
	if regex == null:
		return {"found": false, "invalid": true}
	var m := regex.search(subject)
	if m == null:
		return {"found": false}
	var groups: Array = []
	for g in regex.get_group_count() + 1:
		groups.append([m.get_start(g), m.get_end(g)])
	return {"found": true, "start": m.get_start(0), "end": m.get_end(0), "groups": groups}


## What a chip means, in plain words, where it sits in `tokens`.
static func meaning(tokens: Array, index: int) -> String:
	var token := str(tokens[index])
	if token == "?" and index > 0 and kind(str(tokens[index - 1])) == "quant":
		return str((Story.data().get("glossary", {}) as Dictionary).get("lazy", ""))
	return meaning_of(token)


static func meaning_of(token: String) -> String:
	var glossary: Dictionary = Story.data().get("glossary", {})
	if glossary.has(token):
		return str(glossary[token])
	if token.begins_with("{") and token.ends_with("}"):
		var inside := token.substr(1, token.length() - 2)
		if inside.ends_with(","):
			return "%s or more of the thing before it" % inside.trim_suffix(",")
		if inside.contains(","):
			return "%s to %s of the thing before it" % [inside.get_slice(",", 0), inside.get_slice(",", 1)]
		return "exactly %s of the thing before it" % inside
	if token.begins_with("[") and token.ends_with("]"):
		var letters := PackedStringArray()
		for c in token.substr(1, token.length() - 2):
			letters.append(c)
		return "one character: %s" % " or ".join(letters)
	if token.length() == 1:
		return "the letter %s" % token
	return "the text \"%s\", exactly" % token
