class_name JsProgram
extends RefCounted

## One script, kept as data: a list of statements in a small JavaScript
## subset, with slots the player fills from a few options. It renders as the
## code the editor shows (`lines()`) and as plain JavaScript (`source()`, which
## the tests hand to Node), and `JsRunner` runs it.
##
## Expressions: an int or float is a number and a String is a string literal.
## {"id": "x"} is a name, {"tpl": [parts]} a template literal (String parts
## are literal text), {"array": [...]} an array literal, {"index": [e, n]} is
## e[n], {"method": [e, "m", [args]]} is e.m(args), {"get": [e, "p"]} is e.p,
## and {"slot": "s"} is whichever option the player picked for slot s.
##
## Statements: {"call": [target, method, args]}, {"const"/"let": name,
## "value": e}, {"log": [e...]}, {"for": [start, op, limit], "body"},
## {"for_of": [name, e], "body"}, {"timeout": [ms], "body"}, {"on": [target,
## event], "body"}, {"if": [l, op, r], "body"}, {"await": [target, method,
## args], "kw": "await" or a slot}, {"all": [[target, method, args]...], "kw"},
## {"async": name, "body"} (declared, then called), {"comment": text}.
## A method name or operator may be a slot too; its options are bare text.

## The file name over the editor, e.g. "jazz.js".
var file_name: String = "script.js"
## Whose to-do list the script fills: "jazz" or "clive". That flatmate is
## the one who runs it, so the player has to be the other.
var runs_on: String = "jazz"
var body: Array = []
## Slot id -> {"options": Array, "pick": int}
var slots: Dictionary = {}
## Slot ids in the order they appear in the code, for moving between them.
var slot_order: PackedStringArray = []
## Slots whose options are bare words (a method name, an operator, a
## keyword) rather than values.
var _bare: Dictionary = {}


static func make(file: String, owner: String, statements: Array, slot_options: Dictionary = {}) -> JsProgram:
	var program := JsProgram.new()
	program.file_name = file
	program.runs_on = owner
	program.body = statements
	for id: String in slot_options:
		program.slots[id] = {"options": slot_options[id], "pick": 0}
	program.slot_order = program._find_slot_order()
	return program


func pick(slot: String) -> int:
	return int(slots[slot]["pick"]) if slots.has(slot) else 0


func set_pick(slot: String, index: int) -> void:
	if not slots.has(slot):
		return
	var options: Array = slots[slot]["options"]
	slots[slot]["pick"] = posmod(index, options.size())


func option(slot: String) -> Variant:
	if not slots.has(slot):
		return null
	return (slots[slot]["options"] as Array)[pick(slot)]


func options(slot: String) -> Array:
	return slots[slot]["options"] if slots.has(slot) else []


## Picks by option value (or by index when the value isn't an option).
func set_picks(picks: Dictionary) -> void:
	for slot: String in picks:
		var at := options(slot).find(picks[slot])
		set_pick(slot, at if at >= 0 else int(picks[slot]))


## A slot's current option; anything else passes through.
func resolve(value: Variant) -> Variant:
	if value is Dictionary and (value as Dictionary).has("slot"):
		return option(str(value["slot"]))
	return value


## How an option reads in the editor's list.
func option_text(slot: String, value: Variant) -> String:
	if _bare.has(slot):
		return str(value) if str(value) != "" else "(nothing)"
	return code(value)


## The picks as {slot: index}, for telemetry-free logging and the tests.
func picks() -> Dictionary:
	var out := {}
	for slot: String in slots:
		out[slot] = pick(slot)
	return out


# --- Rendering --------------------------------------------------------------

## The code as lines of segments, {"t": text, "slot": id or ""}, for the editor.
func lines() -> Array:
	var out: Array = []
	_render_block(body, 0, out)
	return out


## The code as one JavaScript string, every slot filled with its pick.
func source() -> String:
	var text := PackedStringArray()
	for line: Array in lines():
		var row := ""
		for segment: Dictionary in line:
			row += str(segment["t"])
		text.append(row)
	return "\n".join(text)


func _render_block(statements: Array, depth: int, out: Array) -> void:
	for statement: Dictionary in statements:
		_render_statement(statement, depth, out)


func _render_statement(s: Dictionary, depth: int, out: Array) -> void:
	var pad := "  ".repeat(depth)
	var line: Array = [_seg(pad)]
	if s.has("comment"):
		line.append(_seg("// " + str(s["comment"])))
		out.append(line)
	elif s.has("call"):
		line.append_array(_call_segments(s["call"]))
		line.append(_seg(";"))
		out.append(line)
	elif s.has("const") or s.has("let"):
		var keyword := "const" if s.has("const") else "let"
		line.append(_seg("%s %s = " % [keyword, s[keyword]]))
		line.append_array(_expr(s["value"]))
		line.append(_seg(";"))
		out.append(line)
	elif s.has("log"):
		line.append(_seg("console.log("))
		line.append_array(_list(s["log"]))
		line.append(_seg(");"))
		out.append(line)
	elif s.has("for"):
		var head: Array = s["for"]
		line.append(_seg("for (let i = %s; i " % str(head[0])))
		line.append_array(_name(head[1]))
		line.append(_seg(" "))
		line.append_array(_expr(head[2]))
		line.append(_seg("; i++) {"))
		out.append(line)
		_render_block(s["body"], depth + 1, out)
		out.append([_seg(pad + "}")])
	elif s.has("for_of"):
		line.append(_seg("for (const %s of " % s["for_of"][0]))
		line.append_array(_expr(s["for_of"][1]))
		line.append(_seg(") {"))
		out.append(line)
		_render_block(s["body"], depth + 1, out)
		out.append([_seg(pad + "}")])
	elif s.has("timeout"):
		line.append(_seg("setTimeout(() => {"))
		out.append(line)
		_render_block(s["body"], depth + 1, out)
		var close: Array = [_seg(pad + "}, ")]
		close.append_array(_expr(s["timeout"][0]))
		close.append(_seg(");"))
		out.append(close)
	elif s.has("on"):
		line.append(_seg("%s.addEventListener(" % s["on"][0]))
		line.append_array(_expr(s["on"][1]))
		line.append(_seg(", () => {"))
		out.append(line)
		_render_block(s["body"], depth + 1, out)
		out.append([_seg(pad + "});")])
	elif s.has("if"):
		var cond: Array = s["if"]
		line.append(_seg("if ("))
		line.append_array(_expr(cond[0]))
		line.append(_seg(" "))
		line.append_array(_name(cond[1]))
		line.append(_seg(" "))
		line.append_array(_expr(cond[2]))
		line.append(_seg(") {"))
		out.append(line)
		_render_block(s["body"], depth + 1, out)
		out.append([_seg(pad + "}")])
	elif s.has("await"):
		line.append_array(_keyword(s.get("kw", "await")))
		line.append_array(_call_segments(s["await"]))
		line.append(_seg(";"))
		out.append(line)
	elif s.has("all"):
		line.append_array(_keyword(s.get("kw", "await")))
		line.append(_seg("Promise.all(["))
		var calls: Array = s["all"]
		for index in calls.size():
			if index > 0:
				line.append(_seg(", "))
			line.append_array(_call_segments(calls[index]))
		line.append(_seg("]);"))
		out.append(line)
	elif s.has("async"):
		line.append(_seg("async function %s() {" % s["async"]))
		out.append(line)
		_render_block(s["body"], depth + 1, out)
		out.append([_seg(pad + "}")])
		out.append([_seg(pad + "%s();" % s["async"])])


func _call_segments(call: Array) -> Array:
	var segments: Array = [_seg("%s." % call[0])]
	segments.append_array(_name(call[1]))
	segments.append(_seg("("))
	segments.append_array(_list(call[2] if call.size() > 2 else []))
	segments.append(_seg(")"))
	return segments


## A method name or operator, which may be a slot of bare words.
func _name(value: Variant) -> Array:
	if value is Dictionary and (value as Dictionary).has("slot"):
		_bare[str(value["slot"])] = true
		return [_slot_seg(str(value["slot"]), str(option(str(value["slot"]))))]
	return [_seg(str(value))]


## A keyword slot ("await" or nothing) renders with its trailing space. An
## empty pick still shows a gap the player can see and change.
func _keyword(value: Variant) -> Array:
	if value is Dictionary and (value as Dictionary).has("slot"):
		var id := str(value["slot"])
		_bare[id] = true
		var word := str(option(id))
		return [_slot_seg(id, word if word != "" else "     "), _seg(" ")]
	return [_seg(str(value) + " ")] if str(value) != "" else []


func _list(values: Array) -> Array:
	var segments: Array = []
	for index in values.size():
		if index > 0:
			segments.append(_seg(", "))
		segments.append_array(_expr(values[index]))
	return segments


func _expr(value: Variant) -> Array:
	if value is Dictionary and (value as Dictionary).has("slot"):
		var id := str(value["slot"])
		return [_slot_seg(id, code(option(id)))]
	if value is Dictionary and (value as Dictionary).has("tpl"):
		# A template literal can hold blanks of its own: `${?}`.
		var segments: Array = [_seg("`")]
		for part: Variant in value["tpl"]:
			if part is String:
				segments.append(_seg(part))
			else:
				segments.append(_seg("${"))
				segments.append_array(_expr(part))
				segments.append(_seg("}"))
		segments.append(_seg("`"))
		return segments
	return [_seg(code(value))]


## An expression as JavaScript source.
static func code(value: Variant) -> String:
	if value is String:
		return "\"%s\"" % str(value).c_escape()
	if value is bool:
		return "true" if value else "false"
	if value is int or value is float:
		return str(value)
	if value is Dictionary:
		var d: Dictionary = value
		if d.has("id"):
			return str(d["id"])
		if d.has("tpl"):
			var text := "`"
			for part: Variant in d["tpl"]:
				text += str(part) if part is String else "${%s}" % code(part)
			return text + "`"
		if d.has("array"):
			var items := PackedStringArray()
			for item: Variant in d["array"]:
				items.append(code(item))
			return "[%s]" % ", ".join(items)
		if d.has("index"):
			return "%s[%s]" % [code(d["index"][0]), code(d["index"][1])]
		if d.has("get"):
			return "%s.%s" % [code(d["get"][0]), d["get"][1]]
		if d.has("method"):
			var args := PackedStringArray()
			for arg: Variant in d["method"][2]:
				args.append(code(arg))
			return "%s.%s(%s)" % [code(d["method"][0]), d["method"][1], ", ".join(args)]
	return str(value)


func _seg(text: String) -> Dictionary:
	return {"t": text, "slot": ""}


func _slot_seg(id: String, text: String) -> Dictionary:
	return {"t": text, "slot": id}


func _find_slot_order() -> PackedStringArray:
	var order := PackedStringArray()
	for line: Array in lines():
		for segment: Dictionary in line:
			var id := str(segment["slot"])
			if id != "" and not order.has(id):
				order.append(id)
	return order
