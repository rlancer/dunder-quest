class_name RustRunner
extends RefCounted

## Runs a program the checker has passed, the way the compiled binary would:
## what it prints, line by line, and a panic if it panics. Ownership is
## already proven by then, so values can be shared freely; references point
## at places (a variable's cell, a field, an element) so writing through a
## `&mut` changes the original.
##
## run(src) -> {"stdout": [lines], "events": [{line, say?}], "panic": "" or message, "panic_line": n}

const STEP_LIMIT := 20000

var _fns: Dictionary = {}
var _methods: Dictionary = {}
var _structs: Dictionary = {}
var _scopes: Array = []
var _out: Array = []
var _events: Array = []
var _panic: String = ""
var _panic_line: int = 0
var _returning: bool = false
var _ret_value: Variant = null
var _steps: int = 0


class Panic:
	extends RefCounted


static func run(src: String) -> Dictionary:
	var runner := RustRunner.new()
	return runner._run(src)


func _run(src: String) -> Dictionary:
	var parsed := RustParser.parse(src)
	if parsed.has("error"):
		return {"stdout": [], "events": [], "panic": "does not parse", "panic_line": 0}
	for item: Dictionary in parsed["items"]:
		match str(item.k):
			"fn":
				_fns[item.name] = item
			"impl":
				if not _methods.has(item.name):
					_methods[item.name] = {}
				for f: Dictionary in item.fns:
					_methods[item.name][f.name] = f
			"struct":
				var names: Array = []
				for field: Dictionary in item.fields:
					names.append(field.name)
				_structs[item.name] = names
	if _fns.has("main"):
		_call_fn(_fns["main"], [], null)
	return {"stdout": _out, "events": _events, "panic": _panic, "panic_line": _panic_line}


func _fail(msg: String, line: int) -> void:
	if _panic == "":
		_panic = msg
		_panic_line = line
		_events.append({"line": line, "panic": msg})


func _dead() -> bool:
	return _panic != "" or _returning


# --- Places and values ------------------------------------------------------

## A reference: {"ref": [container, key]}; reading it reads container[key].
static func make_ref(container: Variant, key: Variant) -> Dictionary:
	return {"__ref": [container, key]}


static func is_ref(v: Variant) -> bool:
	return v is Dictionary and (v as Dictionary).has("__ref")


static func deref(v: Variant) -> Variant:
	while is_ref(v):
		var at: Array = v["__ref"]
		v = at[0][at[1]]
	return v


func _declare(name: String, value: Variant) -> void:
	(_scopes.back() as Dictionary)[name] = {"v": value}


func _cell(name: String) -> Dictionary:
	for i in range(_scopes.size() - 1, -1, -1):
		if (_scopes[i] as Dictionary).has(name):
			return _scopes[i][name]
	return {"v": null}


## [container, key] for a place expression, following references.
func _place(e: Dictionary) -> Array:
	match str(e.k):
		"path":
			return [_cell(e.segs[0]), "v"]
		"field":
			var base := _place(e.e)
			var owner: Variant = deref(base[0][base[1]])
			return [owner, e.name]
		"index":
			var base := _place(e.e)
			var vec: Variant = deref(base[0][base[1]])
			var i := int(_eval(e.idx))
			if i < 0 or i >= (vec as Array).size():
				_fail("index out of bounds: the len is %d but the index is %d" % [(vec as Array).size(), i], e.line)
				return [{"v": null}, "v"]
			return [vec, i]
		"deref":
			var base := _place(e.e)
			var r: Variant = base[0][base[1]]
			if is_ref(r):
				return r["__ref"]
			return base
	return [{"v": _eval(e)}, "v"]


static func _clone(v: Variant) -> Variant:
	if v is Array:
		var out: Array = []
		for x: Variant in v:
			out.append(_clone(x))
		return out
	if v is Dictionary and not is_ref(v):
		var out := {}
		for k: Variant in v:
			out[k] = _clone(v[k])
		return out
	return v


# --- Functions --------------------------------------------------------------

func _call_fn(f: Dictionary, args: Array, self_value: Variant) -> Variant:
	var saved := _scopes
	_scopes = [{}]
	if f.self_kind != "":
		_declare("self", self_value)
	for i in (f.params as Array).size():
		_declare(f.params[i].name, args[i] if i < args.size() else null)
	var result: Variant = _block(f.body)
	if _returning:
		result = _ret_value
		_returning = false
	_scopes = saved
	return result


func _block(b: Dictionary) -> Variant:
	_scopes.append({})
	var result: Variant = null
	for s: Dictionary in b.stmts:
		if _dead():
			break
		_stmt(s)
	if b.tail != null and not _dead():
		_step(b.tail.line)
		result = _eval(b.tail)
	_scopes.pop_back()
	return result


func _step(line: int) -> void:
	_steps += 1
	if _steps > STEP_LIMIT:
		_fail("the scene ran too long", line)
		return
	if _events.is_empty() or int(_events.back().line) != line or _events.back().has("say"):
		_events.append({"line": line})


func _stmt(s: Dictionary) -> void:
	_step(s.line)
	if s.k == "let":
		var value: Variant = _eval(s.init) if s.init != null else null
		_declare(s.name, value)
		return
	_eval(s.e)


# --- Expressions ------------------------------------------------------------

func _eval(e: Dictionary) -> Variant:
	if _dead():
		return null
	match str(e.k):
		"int", "float", "str", "char", "bool":
			return e.v
		"unit":
			return null
		"path":
			var segs: Array = e.segs
			if segs.size() == 1:
				if segs[0] == "None":
					return {"__enum": "Option", "v": "None", "f": []}
				return _cell(segs[0]).v
			return {"__enum": segs[0], "v": segs[1], "f": []}
		"field", "index", "deref":
			var at := _place(e)
			return at[0][at[1]]
		"ref":
			var inner: Dictionary = e.e
			if inner.k in ["path", "field", "index", "deref"] and not (inner.k == "path" and (inner.segs as Array).size() != 1):
				var at := _place(inner)
				return make_ref(at[0], at[1])
			return make_ref({"v": _eval(inner)}, "v")
		"unary":
			var v: Variant = deref(_eval(e.e))
			return (not v) if e.op == "!" else -v
		"binary":
			return _binary(e)
		"assign":
			var value: Variant = _eval(e.r)
			var at := _place(e.l)
			if _dead():
				return null
			match str(e.op):
				"=":
					at[0][at[1]] = value
				"+=":
					at[0][at[1]] = deref(at[0][at[1]]) + deref(value)
				"-=":
					at[0][at[1]] = deref(at[0][at[1]]) - deref(value)
				"*=":
					at[0][at[1]] = deref(at[0][at[1]]) * deref(value)
				"/=":
					at[0][at[1]] = _div(deref(at[0][at[1]]), deref(value), e.line)
			return null
		"call":
			return _call(e)
		"mcall":
			return _mcall(e)
		"block":
			return _block(e)
		"if":
			if deref(_eval(e.cond)):
				return _block(e.then)
			if e.else != null:
				return _eval(e.else)
			return null
		"iflet":
			var value: Variant = _eval(e.e)
			var binds := {}
			if _match_pat(e.pat, value, binds):
				_scopes.append(binds_to_scope(binds))
				var r: Variant = _block(e.then)
				_scopes.pop_back()
				return r
			if e.else != null:
				return _eval(e.else)
			return null
		"match":
			var value: Variant = _eval(e.e)
			for arm: Dictionary in e.arms:
				var binds := {}
				if _match_pat(arm.pat, value, binds):
					_scopes.append(binds_to_scope(binds))
					_step(arm.line)
					var r: Variant = _eval(arm.body)
					_scopes.pop_back()
					return r
			return null
		"for":
			var source: Variant = _eval(e.iter)
			var items: Array = []
			if is_ref(source):
				var vec: Array = deref(source)
				for i in vec.size():
					items.append(make_ref(vec, i))
			elif source is Dictionary and (source as Dictionary).has("__iter"):
				items = source["__iter"]
			else:
				items = source
			for item: Variant in items:
				if _dead():
					break
				var binds := {}
				_match_pat(e.pat, item, binds)
				_scopes.append(binds_to_scope(binds))
				_block(e.body)
				_scopes.pop_back()
			return null
		"return":
			var value: Variant = _eval(e.e) if e.e != null else null
			_ret_value = value
			_returning = true
			return null
		"println":
			var text := _format(e)
			if _dead():
				return null
			if e.mac == "panic":
				_fail(text, e.line)
				return null
			if e.mac == "format":
				return text
			_out.append(text)
			_events.append({"line": e.line, "say": text})
			return null
		"vec":
			var out: Array = []
			for item: Dictionary in e.items:
				out.append(_eval(item))
			return out
		"slit":
			var out := {"__struct": e.name}
			var order: Array = _structs.get(e.name, [])
			var given := {}
			for f: Dictionary in e.fields:
				given[f.name] = _eval(f.e)
			for name: String in order:
				out[name] = given.get(name)
			return out
		"try":
			var value: Variant = _eval(e.e)
			if value is Dictionary and (value.v == "Err" or value.v == "None"):
				_ret_value = value
				_returning = true
				return null
			return value.f[0]
	return null


static func binds_to_scope(binds: Dictionary) -> Dictionary:
	var scope := {}
	for name: String in binds:
		scope[name] = {"v": binds[name]}
	return scope


func _div(a: Variant, b: Variant, line: int) -> Variant:
	if typeof(b) == TYPE_INT and b == 0:
		_fail("attempt to divide by zero", line)
		return 0
	if typeof(a) == TYPE_INT and typeof(b) == TYPE_INT:
		# Rust integer division truncates toward zero.
		var q := absi(a) / absi(b)
		return q if (a < 0) == (b < 0) else -q
	return a / b


func _binary(e: Dictionary) -> Variant:
	if e.op == "&&":
		return bool(deref(_eval(e.l))) and bool(deref(_eval(e.r)))
	if e.op == "||":
		return bool(deref(_eval(e.l))) or bool(deref(_eval(e.r)))
	var a: Variant = deref(_eval(e.l))
	var b: Variant = deref(_eval(e.r))
	match str(e.op):
		"+":
			return a + b
		"-":
			return a - b
		"*":
			return a * b
		"/":
			return _div(a, b, e.line)
		"%":
			if typeof(b) == TYPE_INT and b == 0:
				_fail("attempt to calculate the remainder with a divisor of zero", e.line)
				return 0
			return a - b * _div(a, b, e.line)
		"==":
			return _equal(a, b)
		"!=":
			return not _equal(a, b)
		"<":
			return a < b
		">":
			return a > b
		"<=":
			return a <= b
		">=":
			return a >= b
	return null


static func _equal(a: Variant, b: Variant) -> bool:
	a = deref(a)
	b = deref(b)
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			return false
		for i in (a as Array).size():
			if not _equal(a[i], b[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		for k: Variant in a:
			if not (b as Dictionary).has(k) or not _equal(a[k], b[k]):
				return false
		return (a as Dictionary).size() == (b as Dictionary).size()
	return typeof(a) == typeof(b) and a == b


func _match_pat(p: Dictionary, value: Variant, binds: Dictionary, by_ref: bool = false) -> bool:
	match str(p.k):
		"wild":
			return true
		"bind":
			binds[p.name] = value
			return true
		"plit":
			return _equal(value, p.v)
		"pref":
			return _match_pat(p.pat, deref(value), binds)
	# A reference matched against a variant pattern binds by reference.
	var target: Variant = value
	var as_ref := is_ref(value)
	if as_ref:
		target = deref(value)
	if not (target is Dictionary and (target as Dictionary).has("__enum")):
		return false
	if str(target.v) != str((p.segs as Array).back()):
		return false
	var subs: Array = p.get("subs", [])
	for i in subs.size():
		var field: Variant = target.f[i]
		if as_ref:
			field = make_ref(target.f, i)
		if not _match_pat(subs[i], field, binds):
			return false
	return true


func _call(e: Dictionary) -> Variant:
	var segs: Array = e.f.segs
	var name := "::".join(PackedStringArray(segs))
	var args: Array = []
	for a: Dictionary in e.args:
		args.append(_eval(a))
	if _dead():
		return null
	match name:
		"Some":
			return {"__enum": "Option", "v": "Some", "f": args}
		"Ok":
			return {"__enum": "Result", "v": "Ok", "f": args}
		"Err":
			return {"__enum": "Result", "v": "Err", "f": args}
		"String::from":
			return str(deref(args[0]))
		"String::new":
			return ""
		"Vec::new":
			return []
	if _fns.has(name):
		return _call_fn(_fns[name], args, null)
	if segs.size() == 2 and _methods.has(segs[0]) and (_methods[segs[0]] as Dictionary).has(segs[1]):
		return _call_fn(_methods[segs[0]][segs[1]], args, null)
	return {"__enum": segs[0], "v": segs[segs.size() - 1], "f": args}


func _mcall(e: Dictionary) -> Variant:
	var recv: Dictionary = e.recv
	var at: Array
	if recv.k in ["path", "field", "index", "deref"] and not (recv.k == "path" and (recv.segs as Array).size() != 1):
		at = _place(recv)
	else:
		at = [{"v": _eval(recv)}, "v"]
	if _dead():
		return null
	# Follow references to the value the method works on.
	while is_ref(at[0][at[1]]):
		at = at[0][at[1]]["__ref"]
	var target: Variant = at[0][at[1]]
	var args: Array = []
	for a: Dictionary in e.args:
		args.append(_eval(a))
	if _dead():
		return null
	var type_name := ""
	if target is Dictionary and (target as Dictionary).has("__struct"):
		type_name = target["__struct"]
	elif target is Dictionary and (target as Dictionary).has("__enum"):
		type_name = target["__enum"]
	if type_name != "" and _methods.has(type_name) and (_methods[type_name] as Dictionary).has(e.name):
		var f: Dictionary = _methods[type_name][e.name]
		var self_value: Variant = target
		if f.self_kind in ["&self", "&mut self"]:
			self_value = make_ref(at[0], at[1])
		return _call_fn(f, args, self_value)
	match str(e.name):
		"clone", "to_string", "as_str", "to_owned":
			if e.name == "to_string" and typeof(target) != TYPE_STRING:
				return _display(target)
			return _clone(target)
		"len":
			if target is String:
				return (target as String).to_utf8_buffer().size()
			return (target as Array).size()
		"is_empty":
			if target is String:
				return (target as String).is_empty()
			return (target as Array).is_empty()
		"push_str":
			at[0][at[1]] = str(target) + str(deref(args[0]))
			return null
		"push":
			(target as Array).append(args[0])
			return null
		"pop":
			if (target as Array).is_empty():
				return {"__enum": "Option", "v": "None", "f": []}
			return {"__enum": "Option", "v": "Some", "f": [(target as Array).pop_back()]}
		"clear":
			if target is String:
				at[0][at[1]] = ""
			else:
				(target as Array).clear()
			return null
		"iter":
			var items: Array = []
			for i in (target as Array).size():
				items.append(make_ref(target, i))
			return {"__iter": items}
		"contains":
			if target is String:
				return (target as String).contains(str(deref(args[0])))
			for x: Variant in target:
				if _equal(x, args[0]):
					return true
			return false
		"to_uppercase":
			return str(target).to_upper()
		"abs":
			return absi(target)
		"is_some", "is_ok":
			return target.v == "Some" or target.v == "Ok"
		"is_none", "is_err":
			return target.v == "None" or target.v == "Err"
		"unwrap_or":
			return target.f[0] if target.v in ["Some", "Ok"] else args[0]
		"unwrap":
			if target.v == "None":
				_fail("called `Option::unwrap()` on a `None` value", e.line)
				return null
			if target.v == "Err":
				_fail("called `Result::unwrap()` on an `Err` value: %s" % _debug(target.f[0]), e.line)
				return null
			return target.f[0]
	_fail("no method %s" % e.name, e.line)
	return null


# --- Formatting -------------------------------------------------------------

func _format(e: Dictionary) -> String:
	var args: Array = []
	for a: Dictionary in e.args:
		args.append(_eval(a))
	var fmt: String = e.fmt
	var out := ""
	var next := 0
	var i := 0
	while i < fmt.length():
		var c := fmt[i]
		if c == "{" and i + 1 < fmt.length() and fmt[i + 1] == "{":
			out += "{"
			i += 2
			continue
		if c == "}" and i + 1 < fmt.length() and fmt[i + 1] == "}":
			out += "}"
			i += 2
			continue
		if c == "{":
			var close := fmt.find("}", i)
			var hole := fmt.substr(i + 1, close - i - 1)
			var name := hole.get_slice(":", 0)
			var debug := hole.ends_with(":?")
			var value: Variant
			if name == "":
				value = args[next] if next < args.size() else null
				next += 1
			else:
				value = _cell(name).v
			out += _debug(value) if debug else _display(value)
			i = close + 1
			continue
		out += c
		i += 1
	return out


static func _display(v: Variant) -> String:
	v = deref(v)
	if typeof(v) == TYPE_BOOL:
		return "true" if v else "false"
	if typeof(v) == TYPE_FLOAT:
		var f := float(v)
		return str(int(f)) if f == floorf(f) else str(f)
	return str(v)


static func _debug(v: Variant) -> String:
	v = deref(v)
	match typeof(v):
		TYPE_STRING:
			return "\"%s\"" % str(v).replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			var f := float(v)
			return "%s.0" % int(f) if f == floorf(f) else str(f)
		TYPE_NIL:
			return "()"
		TYPE_ARRAY:
			var parts := PackedStringArray()
			for x: Variant in v:
				parts.append(_debug(x))
			return "[%s]" % ", ".join(parts)
		TYPE_DICTIONARY:
			var d: Dictionary = v
			if d.has("__struct"):
				var parts := PackedStringArray()
				for k: Variant in d:
					if str(k) != "__struct":
						parts.append("%s: %s" % [k, _debug(d[k])])
				return "%s { %s }" % [d["__struct"], ", ".join(parts)]
			if d.has("__enum"):
				if (d.f as Array).is_empty():
					return str(d.v)
				var parts := PackedStringArray()
				for x: Variant in d.f:
					parts.append(_debug(x))
				return "%s(%s)" % [d.v, ", ".join(parts)]
	return str(v)
