class_name RustParser
extends RefCounted

## Lexes and parses the small slice of Rust the plans use into plain
## Dictionaries: items (fn, struct, enum, impl), statements and expressions.
## Every node has "k" (its kind) and "line" (1-based). A syntax error is
## reported the way rustc would: no code, just "expected ...".
##
## Items:  {k:"fn", name, lifetimes, self_kind, params:[{name, mut, ty}], ret, body}
##         {k:"struct", name, fields:[{name, ty}], derives}
##         {k:"enum", name, variants:[{name, fields:[ty]}], derives}
##         {k:"impl", name, fns}
## Types:  {k:"ty", name, args} | {k:"ref", mut, lt, inner} | {k:"unit"}
## Exprs:  int, str, bool, path{segs}, call{f, args}, mcall{recv, name, args},
##         field{e, name}, index{e, idx}, unary{op, e}, ref{mut, e}, deref{e},
##         binary{op, l, r}, assign{op, l, r}, if{cond, then, else}, iflet{pat,
##         e, then, else}, match{e, arms:[{pat, body}]}, block{stmts, tail},
##         for{pat, iter, body}, return{e}, println{fmt, args}, vec{items},
##         slit{name, fields:[{name, e}]}, try{e}, unit
## Pats:   wild, bind{name, mut}, ppath{segs}, ptuple{segs, subs}, plit{v}

var _toks: Array = []
var _i: int = 0
var _no_struct: int = 0
var error: Dictionary = {}


# --- Lexer ------------------------------------------------------------------

const PUNCT3 := ["..="]
const PUNCT2 := ["::", "->", "=>", "==", "!=", "<=", ">=", "&&", "||", "+=", "-=", "*=", "/=", "%=", ".."]


static func lex(src: String) -> Array:
	var out: Array = []
	var i := 0
	var line := 1
	var n := src.length()
	while i < n:
		var c := src[i]
		if c == "\n":
			line += 1
			i += 1
			continue
		if c == " " or c == "\t" or c == "\r":
			i += 1
			continue
		if c == "/" and i + 1 < n and src[i + 1] == "/":
			while i < n and src[i] != "\n":
				i += 1
			continue
		if c == "/" and i + 1 < n and src[i + 1] == "*":
			i += 2
			while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
				if src[i] == "\n":
					line += 1
				i += 1
			i += 2
			continue
		if _digit(c):
			var j := i
			while j < n and (_digit(src[j]) or src[j] == "_"):
				j += 1
			var is_float := false
			if j + 1 < n and src[j] == "." and _digit(src[j + 1]):
				is_float = true
				j += 1
				while j < n and _digit(src[j]):
					j += 1
			var text := src.substr(i, j - i).replace("_", "")
			out.append({"t": "float" if is_float else "int", "v": text, "line": line})
			i = j
			continue
		if c == "\"":
			var j := i + 1
			var text := ""
			while j < n and src[j] != "\"":
				if src[j] == "\\" and j + 1 < n:
					var e := src[j + 1]
					text += {"n": "\n", "t": "\t", "\\": "\\", "\"": "\"", "0": ""}.get(e, e)
					j += 2
					continue
				if src[j] == "\n":
					line += 1
				text += src[j]
				j += 1
			out.append({"t": "str", "v": text, "line": line})
			i = j + 1
			continue
		if c == "'" and i + 1 < n and _word(src[i + 1]):
			var j := i + 1
			while j < n and (_word(src[j]) or _digit(src[j])):
				j += 1
			if j < n and src[j] == "'":
				out.append({"t": "char", "v": src.substr(i + 1, j - i - 1), "line": line})
				i = j + 1
			else:
				out.append({"t": "lt", "v": src.substr(i, j - i), "line": line})
				i = j
			continue
		if _word(c):
			var j := i
			while j < n and (_word(src[j]) or _digit(src[j])):
				j += 1
			var word := src.substr(i, j - i)
			if j < n and src[j] == "!" and word in ["println", "print", "vec", "format", "panic"]:
				out.append({"t": "macro", "v": word, "line": line})
				i = j + 1
				continue
			out.append({"t": "id", "v": word, "line": line})
			i = j
			continue
		var three := src.substr(i, 3)
		if three in PUNCT3:
			out.append({"t": "p", "v": three, "line": line})
			i += 3
			continue
		var two := src.substr(i, 2)
		if two in PUNCT2:
			out.append({"t": "p", "v": two, "line": line})
			i += 2
			continue
		out.append({"t": "p", "v": c, "line": line})
		i += 1
	out.append({"t": "eof", "v": "", "line": line})
	return out


static func _digit(c: String) -> bool:
	return c >= "0" and c <= "9"


static func _word(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_"


# --- Parser entry -----------------------------------------------------------

## Returns {"items": [...]} or {"error": {...}}.
static func parse(src: String) -> Dictionary:
	var p := RustParser.new()
	p._toks = lex(src)
	var items: Array = p._items()
	if not p.error.is_empty():
		return {"error": p.error}
	return {"items": items}


func _peek(o: int = 0) -> Dictionary:
	return _toks[mini(_i + o, _toks.size() - 1)]


func _at(v: String, o: int = 0) -> bool:
	var t := _peek(o)
	return (t.t == "p" or t.t == "id") and t.v == v


func _next() -> Dictionary:
	var t: Dictionary = _toks[_i]
	if _i < _toks.size() - 1:
		_i += 1
	return t


func _eat(v: String) -> bool:
	if _at(v):
		_next()
		return true
	return false


func _expect(v: String) -> Dictionary:
	if _at(v):
		return _next()
	_fail("expected `%s`, found %s" % [v, _describe(_peek())])
	return _peek()


func _describe(t: Dictionary) -> String:
	if t.t == "eof":
		return "end of file"
	if t.t == "str":
		return "`\"%s\"`" % t.v
	return "`%s`" % t.v


func _fail(msg: String) -> void:
	if error.is_empty():
		error = {"code": "", "msg": msg, "line": int(_peek().line)}
	# Jump to the end so every loop stops.
	_i = _toks.size() - 1


func _ident() -> String:
	var t := _peek()
	if t.t == "id":
		_next()
		return str(t.v)
	_fail("expected identifier, found %s" % _describe(t))
	return "_"


# --- Items ------------------------------------------------------------------

func _items() -> Array:
	var items: Array = []
	while _peek().t != "eof" and error.is_empty():
		var derives: Array = []
		while _at("#"):
			derives.append_array(_attribute())
		if _at("fn"):
			items.append(_fn())
		elif _at("struct"):
			items.append(_struct(derives))
		elif _at("enum"):
			items.append(_enum(derives))
		elif _at("impl"):
			items.append(_impl())
		else:
			_fail("expected item, found %s" % _describe(_peek()))
	return items


func _attribute() -> Array:
	_expect("#")
	_expect("[")
	var names: Array = []
	if _ident() == "derive":
		_expect("(")
		while not _at(")") and error.is_empty():
			names.append(_ident())
			if not _eat(","):
				break
		_expect(")")
	else:
		while not _at("]") and error.is_empty():
			_next()
	_expect("]")
	return names


func _fn() -> Dictionary:
	var line := int(_expect("fn").line)
	var name := _ident()
	var lifetimes: Array = []
	if _eat("<"):
		while not _at(">") and error.is_empty():
			var t := _next()
			if t.t != "lt":
				_fail("expected lifetime parameter, found %s" % _describe(t))
				break
			lifetimes.append(t.v)
			if not _eat(","):
				break
		_expect(">")
	_expect("(")
	var params: Array = []
	var self_kind := ""
	if _at("self") or (_at("&") and (_at("self", 1) or (_at("mut", 1) and _at("self", 2)))) or (_at("mut") and _at("self", 1)):
		if _eat("&"):
			self_kind = "&mut self" if _eat("mut") else "&self"
		else:
			self_kind = "mut self" if _eat("mut") else "self"
		_expect("self")
		if not _eat(","):
			pass
	while not _at(")") and error.is_empty():
		var mut := _eat("mut")
		var pline := int(_peek().line)
		var pname := _ident()
		_expect(":")
		params.append({"name": pname, "mut": mut, "ty": _type(), "line": pline})
		if not _eat(","):
			break
	_expect(")")
	var ret: Variant = null
	if _eat("->"):
		ret = _type()
	var body := _block()
	return {"k": "fn", "name": name, "lifetimes": lifetimes, "self_kind": self_kind, "params": params, "ret": ret, "body": body, "line": line}


func _struct(derives: Array) -> Dictionary:
	var line := int(_expect("struct").line)
	var name := _ident()
	_expect("{")
	var fields: Array = []
	while not _at("}") and error.is_empty():
		var fname := _ident()
		_expect(":")
		fields.append({"name": fname, "ty": _type()})
		if not _eat(","):
			break
	_expect("}")
	return {"k": "struct", "name": name, "fields": fields, "derives": derives, "line": line}


func _enum(derives: Array) -> Dictionary:
	var line := int(_expect("enum").line)
	var name := _ident()
	_expect("{")
	var variants: Array = []
	while not _at("}") and error.is_empty():
		var vname := _ident()
		var fields: Array = []
		if _eat("("):
			while not _at(")") and error.is_empty():
				fields.append(_type())
				if not _eat(","):
					break
			_expect(")")
		variants.append({"name": vname, "fields": fields})
		if not _eat(","):
			break
	_expect("}")
	return {"k": "enum", "name": name, "variants": variants, "derives": derives, "line": line}


func _impl() -> Dictionary:
	var line := int(_expect("impl").line)
	var name := _ident()
	_expect("{")
	var fns: Array = []
	while not _at("}") and error.is_empty():
		fns.append(_fn())
	_expect("}")
	return {"k": "impl", "name": name, "fns": fns, "line": line}


func _type() -> Dictionary:
	var line := int(_peek().line)
	if _eat("&"):
		var lt := ""
		if _peek().t == "lt":
			lt = str(_next().v)
		var mut := _eat("mut")
		return {"k": "ref", "mut": mut, "lt": lt, "inner": _type(), "line": line}
	if _at("&&"):
		_next()
		var inner := {"k": "ref", "mut": _eat("mut"), "lt": "", "inner": _type(), "line": line}
		return {"k": "ref", "mut": false, "lt": "", "inner": inner, "line": line}
	if _eat("("):
		_expect(")")
		return {"k": "unit", "line": line}
	var name := _ident()
	var args: Array = []
	if _eat("<"):
		while not _at(">") and error.is_empty():
			args.append(_type())
			if not _eat(","):
				break
		_expect(">")
	return {"k": "ty", "name": name, "args": args, "line": line}


# --- Statements -------------------------------------------------------------

func _block() -> Dictionary:
	var line := int(_expect("{").line)
	var stmts: Array = []
	var tail: Variant = null
	while not _at("}") and error.is_empty():
		if _eat(";"):
			continue
		if _at("let"):
			stmts.append(_let())
			continue
		var e := _expr()
		if _eat(";"):
			stmts.append({"k": "expr", "e": e, "semi": true, "line": e.line})
		elif _at("}"):
			tail = e
		elif _block_like(e):
			stmts.append({"k": "expr", "e": e, "semi": false, "line": e.line})
		else:
			_fail("expected `;`, found %s" % _describe(_peek()))
	var end := int(_expect("}").line)
	return {"k": "block", "stmts": stmts, "tail": tail, "line": line, "end_line": end}


static func _block_like(e: Dictionary) -> bool:
	return e.k in ["if", "iflet", "match", "block", "for"]


func _let() -> Dictionary:
	var line := int(_expect("let").line)
	var mut := _eat("mut")
	var name := _ident()
	var ty: Variant = null
	if _eat(":"):
		ty = _type()
	var init: Variant = null
	if _eat("="):
		init = _expr()
	_expect(";")
	return {"k": "let", "name": name, "mut": mut, "ty": ty, "init": init, "line": line}


# --- Expressions ------------------------------------------------------------

func _expr() -> Dictionary:
	return _assign()


func _assign() -> Dictionary:
	var left := _binary(0)
	var t := _peek()
	if t.t == "p" and t.v in ["=", "+=", "-=", "*=", "/=", "%="]:
		_next()
		var right := _assign()
		return {"k": "assign", "op": t.v, "l": left, "r": right, "line": left.line}
	return left


const LEVELS := [["||"], ["&&"], ["==", "!=", "<", ">", "<=", ">="], ["+", "-"], ["*", "/", "%"]]


func _binary(level: int) -> Dictionary:
	if level >= LEVELS.size():
		return _unary()
	var left := _binary(level + 1)
	while error.is_empty():
		var t := _peek()
		if t.t == "p" and t.v in LEVELS[level]:
			_next()
			var right := _binary(level + 1)
			left = {"k": "binary", "op": t.v, "l": left, "r": right, "line": left.line}
			if level == 2:
				break
		else:
			break
	return left


func _unary() -> Dictionary:
	var t := _peek()
	var line := int(t.line)
	if t.t == "p":
		if t.v == "&" or t.v == "&&":
			_next()
			var mut := _eat("mut")
			var inner := {"k": "ref", "mut": mut, "e": _unary(), "line": line}
			if t.v == "&&":
				return {"k": "ref", "mut": false, "e": inner, "line": line}
			return inner
		if t.v == "*":
			_next()
			return {"k": "deref", "e": _unary(), "line": line}
		if t.v == "-" or t.v == "!":
			_next()
			return {"k": "unary", "op": t.v, "e": _unary(), "line": line}
	return _postfix(_primary())


func _postfix(e: Dictionary) -> Dictionary:
	while error.is_empty():
		var line := int(_peek().line)
		if _at("."):
			_next()
			var t := _peek()
			if t.t == "int":
				_next()
				e = {"k": "field", "e": e, "name": str(t.v), "line": line}
				continue
			var name := _ident()
			if _at("::"):
				# Turbofish: x.sum::<i32>()
				_next()
				_expect("<")
				_type()
				_expect(">")
			if _eat("("):
				e = {"k": "mcall", "recv": e, "name": name, "args": _args(")"), "line": line}
			else:
				e = {"k": "field", "e": e, "name": name, "line": line}
		elif _at("("):
			_next()
			e = {"k": "call", "f": e, "args": _args(")"), "line": e.line}
		elif _at("["):
			_next()
			var idx := _expr()
			_expect("]")
			e = {"k": "index", "e": e, "idx": idx, "line": line}
		elif _at("?"):
			_next()
			e = {"k": "try", "e": e, "line": line}
		else:
			break
	return e


func _args(close: String) -> Array:
	var args: Array = []
	_no_struct_push(false)
	while not _at(close) and error.is_empty():
		args.append(_expr())
		if not _eat(","):
			break
	_expect(close)
	_no_struct_pop()
	return args


var _struct_stack: Array = []


func _no_struct_push(value: bool) -> void:
	_struct_stack.append(_no_struct)
	_no_struct = 1 if value else 0


func _no_struct_pop() -> void:
	_no_struct = int(_struct_stack.pop_back())


func _primary() -> Dictionary:
	var t := _peek()
	var line := int(t.line)
	match str(t.t):
		"int":
			_next()
			return {"k": "int", "v": int(t.v), "line": line}
		"float":
			_next()
			return {"k": "float", "v": float(t.v), "line": line}
		"str":
			_next()
			return {"k": "str", "v": t.v, "line": line}
		"char":
			_next()
			return {"k": "char", "v": t.v, "line": line}
		"macro":
			return _macro()
	if _at("("):
		_next()
		if _eat(")"):
			return {"k": "unit", "line": line}
		_no_struct_push(false)
		var inner := _expr()
		_no_struct_pop()
		_expect(")")
		return inner
	if _at("{"):
		_no_struct_push(false)
		var b := _block()
		_no_struct_pop()
		return b
	if _at("if"):
		return _if()
	if _at("match"):
		return _match()
	if _at("for"):
		return _for()
	if _at("return"):
		_next()
		if _at(";") or _at("}"):
			return {"k": "return", "e": null, "line": line}
		return {"k": "return", "e": _expr(), "line": line}
	if _at("true") or _at("false"):
		_next()
		return {"k": "bool", "v": t.v == "true", "line": line}
	if t.t == "id":
		var segs: Array = [_ident()]
		while _at("::") and error.is_empty():
			_next()
			segs.append(_ident())
		if _at("{") and _no_struct == 0 and segs.size() == 1 and str(segs[0])[0] == str(segs[0])[0].to_upper() and str(segs[0])[0] != "_":
			return _struct_lit(str(segs[0]), line)
		return {"k": "path", "segs": segs, "line": line}
	_fail("expected expression, found %s" % _describe(t))
	return {"k": "unit", "line": line}


func _struct_lit(name: String, line: int) -> Dictionary:
	_expect("{")
	var fields: Array = []
	while not _at("}") and error.is_empty():
		var fline := int(_peek().line)
		var fname := _ident()
		var value: Dictionary
		if _eat(":"):
			_no_struct_push(false)
			value = _expr()
			_no_struct_pop()
		else:
			value = {"k": "path", "segs": [fname], "line": fline}
		fields.append({"name": fname, "e": value, "line": fline})
		if not _eat(","):
			break
	_expect("}")
	return {"k": "slit", "name": name, "fields": fields, "line": line}


func _macro() -> Dictionary:
	var t := _next()
	var line := int(t.line)
	var close := ")"
	if _eat("["):
		close = "]"
	else:
		_expect("(")
	if t.v == "vec":
		return {"k": "vec", "items": _args_raw(close), "line": line}
	var args := _args_raw(close)
	var fmt := ""
	if not args.is_empty() and (args[0] as Dictionary).k == "str":
		fmt = str(args.pop_front().v)
	elif t.v != "panic" or not args.is_empty():
		_fail("format argument must be a string literal")
	return {"k": "println", "mac": t.v, "fmt": fmt, "args": args, "line": line}


func _args_raw(close: String) -> Array:
	var items: Array = []
	_no_struct_push(false)
	while not _at(close) and error.is_empty():
		items.append(_expr())
		if not _eat(","):
			break
	_expect(close)
	_no_struct_pop()
	return items


func _cond() -> Dictionary:
	_no_struct_push(true)
	var e := _expr()
	_no_struct_pop()
	return e


func _if() -> Dictionary:
	var line := int(_expect("if").line)
	if _eat("let"):
		var pat := _pattern()
		_expect("=")
		var scrut := _cond()
		var then := _block()
		return {"k": "iflet", "pat": pat, "e": scrut, "then": then, "else": _else(), "line": line}
	var cond := _cond()
	var then_b := _block()
	return {"k": "if", "cond": cond, "then": then_b, "else": _else(), "line": line}


func _else() -> Variant:
	if not _eat("else"):
		return null
	if _at("if"):
		return _if()
	return _block()


func _match() -> Dictionary:
	var line := int(_expect("match").line)
	var scrut := _cond()
	_expect("{")
	var arms: Array = []
	while not _at("}") and error.is_empty():
		var aline := int(_peek().line)
		var pat := _pattern()
		_expect("=>")
		_no_struct_push(false)
		var body := _expr()
		_no_struct_pop()
		arms.append({"pat": pat, "body": body, "line": aline})
		if not _eat(","):
			if body.k != "block" and not _at("}"):
				_fail("expected `,` following `match` arm")
	_expect("}")
	return {"k": "match", "e": scrut, "arms": arms, "line": line}


func _for() -> Dictionary:
	var line := int(_expect("for").line)
	var pat := _pattern()
	_expect("in")
	var iter := _cond()
	var body := _block()
	return {"k": "for", "pat": pat, "iter": iter, "body": body, "line": line}


func _pattern() -> Dictionary:
	var t := _peek()
	var line := int(t.line)
	if t.t == "int" or t.t == "str":
		_next()
		return {"k": "plit", "v": int(t.v) if t.t == "int" else t.v, "line": line}
	if _at("-") and _peek(1).t == "int":
		_next()
		return {"k": "plit", "v": -int(_next().v), "line": line}
	if _at("true") or _at("false"):
		_next()
		return {"k": "plit", "v": t.v == "true", "line": line}
	if _at("_"):
		_next()
		return {"k": "wild", "line": line}
	if _at("&"):
		_next()
		return {"k": "pref", "pat": _pattern(), "line": line}
	var mut := _eat("mut")
	var segs: Array = [_ident()]
	while _at("::") and error.is_empty():
		_next()
		segs.append(_ident())
	if _eat("("):
		var subs: Array = []
		while not _at(")") and error.is_empty():
			subs.append(_pattern())
			if not _eat(","):
				break
		_expect(")")
		return {"k": "ptuple", "segs": segs, "subs": subs, "line": line}
	var first := str(segs[0])
	if segs.size() == 1 and (mut or first[0] != first[0].to_upper() or first[0] == "_"):
		return {"k": "bind", "name": first, "mut": mut, "line": line}
	return {"k": "ppath", "segs": segs, "line": line}
