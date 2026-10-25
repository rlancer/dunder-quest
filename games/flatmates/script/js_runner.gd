class_name JsRunner
extends Node

## Runs a `JsProgram` the way JavaScript would. The script's own lines run
## straight through in one go; a flatmate's methods only add steps to his
## to-do list (he works through it in order) and hand back a promise. Timers
## and event listeners run their callbacks later, from the game loop, and
## `await` pauses the rest of an async function until its promise settles.
## So `setTimeout(f, 0)` still runs after the lines below it, as in a browser.
##
## Names resolve to the script's own consts first, then to the stage's
## objects (`world.js_lookup`). Running again cancels the last run's timers,
## listeners and paused functions.

## The console: every console.log line and every uncaught error.
signal logged(text: String, kind: StringName)

## Laps a loop may take before the runner calls it off.
const LOOP_CAP := 40

## Must have js_lookup(name) -> Variant, or null for an unknown name.
var world: Node
var _serial: int = 0
var _listeners: Array[Dictionary] = []


## Starts `program` fresh. Its first lines run before this returns; the
## rest (timers, listeners, awaits) runs later. Errors go to the console.
func run(program: JsProgram) -> void:
	stop()
	_exec_block(program, program.body, {}, _serial)


## Cancels everything the last run left waiting.
func stop() -> void:
	_serial += 1
	for entry in _listeners:
		var source: Object = entry["source"]
		if is_instance_valid(source) and source.is_connected(&"fired", entry["callable"]):
			source.disconnect(&"fired", entry["callable"])
	_listeners.clear()


func is_current(serial: int) -> bool:
	return serial == _serial and is_inside_tree()


## Runs statements in order. Returns false when one throws or the run was
## cancelled, so whoever called it stops too.
func _exec_block(program: JsProgram, statements: Array, scope: Dictionary, serial: int) -> bool:
	for statement: Dictionary in statements:
		if not is_current(serial):
			return false
		var ok: bool = await _exec(program, statement, scope, serial)
		if not ok:
			return false
	return true


func _exec(program: JsProgram, s: Dictionary, scope: Dictionary, serial: int) -> bool:
	if s.has("comment"):
		return true
	if s.has("call"):
		return _ok(_call(program, s["call"], scope))
	if s.has("const") or s.has("let"):
		var keyword := "const" if s.has("const") else "let"
		var value: Variant = _eval(program, s["value"], scope)
		if not _ok(value):
			return false
		scope[str(s[keyword])] = value
		return true
	if s.has("log"):
		var parts := PackedStringArray()
		for arg: Variant in s["log"]:
			var value: Variant = _eval(program, arg, scope)
			if not _ok(value):
				return false
			parts.append(text_of(value))
		logged.emit(" ".join(parts), &"log")
		return true
	if s.has("for"):
		return await _exec_for(program, s, scope, serial)
	if s.has("for_of"):
		var items: Variant = _eval(program, s["for_of"][1], scope)
		if not _ok(items):
			return false
		if not items is Array:
			return _throw(JsError.make("TypeError", "%s is not iterable" % JsProgram.code(program.resolve(s["for_of"][1]))))
		for item: Variant in items:
			var inner := scope.duplicate()
			inner[str(s["for_of"][0])] = item
			if not await _exec_block(program, s["body"], inner, serial):
				return false
		return true
	if s.has("timeout"):
		var ms: Variant = _eval(program, s["timeout"][0], scope)
		if not _ok(ms):
			return false
		var body: Array = s["body"]
		var captured := scope.duplicate()
		get_tree().create_timer(maxf(float(ms), 0.0) / 1000.0, false).timeout.connect(func() -> void:
			if is_current(serial):
				_exec_block(program, body, captured.duplicate(), serial))
		return true
	if s.has("on"):
		return _listen(program, s, scope, serial)
	if s.has("if"):
		var cond: Array = s["if"]
		var left: Variant = _eval(program, cond[0], scope)
		var right: Variant = _eval(program, cond[2], scope)
		if not _ok(left) or not _ok(right):
			return false
		var result: Variant = compare(left, str(program.resolve(cond[1])), right)
		if not _ok(result):
			return false
		if result:
			return await _exec_block(program, s["body"], scope.duplicate(), serial)
		return true
	if s.has("await"):
		var promise: Variant = _call(program, s["await"], scope)
		if not _ok(promise):
			return false
		if str(program.resolve(s.get("kw", "await"))) == "await":
			if promise is JsPromise and not (promise as JsPromise).done:
				await (promise as JsPromise).settled
			return is_current(serial)
		return true
	if s.has("all"):
		var promises: Array = []
		for call: Array in s["all"]:
			var promise: Variant = _call(program, call, scope)
			if not _ok(promise):
				return false
			promises.append(promise)
		if str(program.resolve(s.get("kw", "await"))) == "await":
			for promise: Variant in promises:
				if promise is JsPromise and not (promise as JsPromise).done:
					await (promise as JsPromise).settled
					if not is_current(serial):
						return false
		return is_current(serial)
	if s.has("async"):
		# Declared and called on the next line. The call runs until its first
		# await and then the script carries on, as an async function does.
		_exec_block(program, s["body"], scope.duplicate(), serial)
		return true
	push_error("Unknown statement %s" % s)
	return false


func _exec_for(program: JsProgram, s: Dictionary, scope: Dictionary, serial: int) -> bool:
	var head: Array = s["for"]
	var limit: Variant = _eval(program, head[2], scope)
	if not _ok(limit):
		return false
	var op := str(program.resolve(head[1]))
	var i: Variant = head[0]
	var laps := 0
	while true:
		var keep_going: Variant = compare(i, op, limit)
		if not _ok(keep_going):
			return false
		if not keep_going:
			break
		laps += 1
		if laps > LOOP_CAP:
			logged.emit("Gave up after %d laps. Is that loop ever going to stop?" % LOOP_CAP, &"error")
			return false
		var inner := scope.duplicate()
		inner["i"] = i
		if not await _exec_block(program, s["body"], inner, serial):
			return false
		i = int(i) + 1
	return true


func _listen(program: JsProgram, s: Dictionary, scope: Dictionary, serial: int) -> bool:
	var target: Variant = _lookup(str(s["on"][0]), scope)
	if not _ok(target):
		return false
	var event: Variant = _eval(program, s["on"][1], scope)
	if not _ok(event):
		return false
	if not (target is Object and (target as Object).has_signal(&"fired")):
		return _throw(JsError.make("TypeError", "%s.addEventListener is not a function" % s["on"][0]))
	var body: Array = s["body"]
	var captured := scope.duplicate()
	var callable := func(fired: String) -> void:
		if fired == str(event) and is_current(serial):
			_exec_block(program, body, captured.duplicate(), serial)
	(target as Object).connect(&"fired", callable)
	_listeners.append({"source": target, "callable": callable})
	return true


## target.method(args): a flatmate's step, a gadget's method, or an array's.
func _call(program: JsProgram, call: Array, scope: Dictionary) -> Variant:
	var name := str(call[0])
	var target: Variant = _lookup(name, scope)
	if not _ok(target):
		return target
	var method := str(program.resolve(call[1]))
	var args: Array = []
	for arg: Variant in (call[2] if call.size() > 2 else []):
		var value: Variant = _eval(program, arg, scope)
		if not _ok(value):
			return value
		args.append(value)
	return _invoke(target, name, method, args)


func _invoke(target: Variant, name: String, method: String, args: Array) -> Variant:
	if target is Array:
		var list: Array = target
		match method:
			"slice":
				var from: int = int(args[0]) if args.size() > 0 else 0
				var to: int = int(args[1]) if args.size() > 1 else list.size()
				return list.slice(from, to)
			"includes":
				return args.size() > 0 and list.has(args[0])
	if target is Object and (target as Object).has_method(&"js_call"):
		var methods: PackedStringArray = (target as Object).call(&"js_methods")
		if methods.has(method):
			return (target as Object).call(&"js_call", method, args)
	return JsError.make("TypeError", "%s.%s is not a function" % [name, method])


func _eval(program: JsProgram, value: Variant, scope: Dictionary) -> Variant:
	value = program.resolve(value)
	if not value is Dictionary:
		return value
	var d: Dictionary = value
	if d.has("id"):
		return _lookup(str(d["id"]), scope)
	if d.has("tpl"):
		var text := ""
		for part: Variant in d["tpl"]:
			if part is String:
				text += part
				continue
			var inner: Variant = _eval(program, part, scope)
			if not _ok(inner):
				return inner
			text += text_of(inner)
		return text
	if d.has("array"):
		var items: Array = []
		for item: Variant in d["array"]:
			var inner: Variant = _eval(program, item, scope)
			if not _ok(inner):
				return inner
			items.append(inner)
		return items
	if d.has("index"):
		var list: Variant = _eval(program, d["index"][0], scope)
		if not _ok(list):
			return list
		var at := int(d["index"][1])
		if list is Array:
			return (list as Array)[at] if at >= 0 and at < (list as Array).size() else null
		if list is String:
			return (list as String)[at] if at >= 0 and at < (list as String).length() else null
		return null
	if d.has("get"):
		var owner: Variant = _eval(program, d["get"][0], scope)
		if not _ok(owner):
			return owner
		var prop := str(d["get"][1])
		if (owner is Array or owner is String) and prop == "length":
			return owner.size() if owner is Array else (owner as String).length()
		if owner is Object and (owner as Object).has_method(&"js_get"):
			return (owner as Object).call(&"js_get", prop)
		return null
	if d.has("method"):
		var owner: Variant = _eval(program, d["method"][0], scope)
		if not _ok(owner):
			return owner
		var args: Array = []
		for arg: Variant in d["method"][2]:
			var inner: Variant = _eval(program, arg, scope)
			if not _ok(inner):
				return inner
			args.append(inner)
		return _invoke(owner, JsProgram.code(d["method"][0]), str(d["method"][1]), args)
	return value


func _lookup(name: String, scope: Dictionary) -> Variant:
	if scope.has(name):
		return scope[name]
	var found: Variant = world.call(&"js_lookup", name) if world != null else null
	if found == null:
		return JsError.make("ReferenceError", "%s is not defined" % name)
	return found


## False for a thrown error, which is logged; true for anything else.
func _ok(value: Variant) -> bool:
	if value is JsError:
		return _throw(value)
	return true


func _throw(error: JsError) -> bool:
	logged.emit("Uncaught " + error.message, &"error")
	return false


## Comparison operators with JavaScript's rules for the types scripts use.
## === never converts; < and friends compare numbers, or strings by letter.
static func compare(left: Variant, op: String, right: Variant) -> Variant:
	var numbers := _is_number(left) and _is_number(right)
	match op:
		"===":
			return _strict_equal(left, right)
		"!==":
			return not _strict_equal(left, right)
		"<", "<=", ">", ">=":
			if not numbers and not (left is String and right is String):
				return false
			if numbers:
				left = float(left)
				right = float(right)
			match op:
				"<":
					return left < right
				"<=":
					return left <= right
				">":
					return left > right
				_:
					return left >= right
	return JsError.make("SyntaxError", "Unexpected token '%s'" % op)


static func _strict_equal(left: Variant, right: Variant) -> bool:
	if _is_number(left) and _is_number(right):
		return float(left) == float(right)
	if typeof(left) != typeof(right):
		return false
	return left == right


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


## How JavaScript turns a value into text: 3 not 3.0, objects by name.
static func text_of(value: Variant) -> String:
	if value == null:
		return "undefined"
	if value is bool:
		return "true" if value else "false"
	if value is float:
		return str(int(value)) if is_equal_approx(value, roundf(value)) else str(value)
	if value is Array:
		var items := PackedStringArray()
		for item: Variant in value:
			items.append(text_of(item))
		return ",".join(items)
	if value is Object and (value as Object).has_method(&"js_label"):
		return "[object %s]" % (value as Object).call(&"js_label")
	return str(value)
