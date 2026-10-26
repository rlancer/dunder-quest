class_name RustChecker
extends RefCounted

## A small rustc for the slice of Rust the plans use. It runs the same phases
## in the same order rustc does, and stops after the first phase that fails:
##
##   1. parse                      (syntax errors, no code)
##   2. names and types            E0425 E0412 E0261 E0106 E0308 E0061 E0599 E0609
##                                 E0277 E0369 E0063 E0560 E0422 E0023
##   3. match exhaustiveness       E0004
##   4. borrow check               E0382 E0381 E0384 E0596 E0594 E0499 E0502 E0503
##                                 E0505 E0506 E0507 E0597
##
## The borrow check is non-lexical like rustc's: a borrow lasts until the last
## use of the reference that holds it (or, in a loop, for the whole loop), so
## finishing with a reference before touching the original again compiles.
## To know where each reference is last used, every function body is walked
## twice with the same numbering: once to type it and record each variable's
## uses, once to check moves and borrows against those uses.
##
## tests/verify_rust.py compiles every plan, in every combination of its
## blanks, with the real rustc and checks this agrees with it.
##
## check(src) -> {"ok": bool, "errors": [{"code", "msg", "line"}]}

const INTS := ["i8", "i16", "i32", "i64", "i128", "isize", "u8", "u16", "u32", "u64", "u128", "usize"]
const BUILTIN_TYPES := ["bool", "char", "f32", "f64", "String", "str", "Vec", "Option", "Result"]

var _structs: Dictionary = {}
var _enums: Dictionary = {}
var _fns: Dictionary = {}
var _methods: Dictionary = {}

var _errors: Array = []
var _match_errors: Array = []
var _borrow_errors: Array = []
var _seen: Dictionary = {}

## "type" on the first walk, "borrow" on the second.
var _mode: String = "type"
var _fn: Dictionary = {}
var _self_type: Variant = null
var _ret: Dictionary = {}
var _seq: int = 0
var _scopes: Array = []
var _vars: Array = []
## Per function, from the first walk: var id -> [use seqs], and loop spans.
var _uses: Dictionary = {}
var _loops: Array = []
var _loop_count: int = 0
var _loans: Array = []


static func check(src: String) -> Dictionary:
	var checker := RustChecker.new()
	return checker._check(src)


func _check(src: String) -> Dictionary:
	var parsed := RustParser.parse(src)
	if parsed.has("error"):
		return {"ok": false, "errors": [parsed.error]}
	var items: Array = parsed["items"]
	_collect(items)
	var bodies: Array = []
	for item: Dictionary in items:
		if item.k == "fn":
			bodies.append([item, null])
		elif item.k == "impl":
			for f: Dictionary in item.fns:
				bodies.append([f, item.name])
	for pair: Array in bodies:
		_signature(pair[0], pair[1])
	if not _fns.has("main") and _errors.is_empty():
		_error("E0601", "`main` function not found in crate", 1)
	if _errors.is_empty():
		var records := {}
		for index in bodies.size():
			_mode = "type"
			_walk_fn(bodies[index][0], bodies[index][1])
			records[index] = [_uses, _loops]
		if _errors.is_empty() and _match_errors.is_empty():
			for index in bodies.size():
				_mode = "borrow"
				_uses = records[index][0]
				_loops = records[index][1]
				_walk_fn(bodies[index][0], bodies[index][1])
	var errors: Array = _errors
	if errors.is_empty():
		errors = _match_errors
	if errors.is_empty():
		errors = _borrow_errors
	return {"ok": errors.is_empty(), "errors": errors}


func _error(code: String, msg: String, line: int) -> void:
	var key := "%s@%d" % [code, line]
	if _seen.has(key):
		return
	_seen[key] = true
	# rustc's label calls an unsuffixed literal plain "integer".
	msg = msg.replace("found `{integer}`", "found integer")
	var entry := {"code": code, "msg": msg, "line": line}
	if code == "E0004":
		_match_errors.append(entry)
	elif _mode == "borrow":
		_borrow_errors.append(entry)
	else:
		_errors.append(entry)


func _type_phase() -> bool:
	return _mode == "type"


# --- Types ------------------------------------------------------------------

static func T(n: String, a: Array = []) -> Dictionary:
	return {"n": n, "a": a}


static func R(inner: Dictionary, mut: bool = false) -> Dictionary:
	return {"n": "&", "mut": mut, "a": [inner]}


const ANY := {"n": "?", "a": []}
const NEVER := {"n": "!", "a": []}
const UNIT := {"n": "()", "a": []}
const INT_LIT := {"n": "{integer}", "a": []}


static func is_ref(t: Dictionary) -> bool:
	return t.n == "&"


static func is_int(t: Dictionary) -> bool:
	return t.n in INTS or t.n == "{integer}"


static func show(t: Dictionary) -> String:
	match str(t.n):
		"&":
			return "&" + ("mut " if t.mut else "") + show(t.a[0])
		"?":
			return "_"
		"Iter":
			return "std::slice::Iter<'_, %s>" % show((t.a[0] as Dictionary).a[0])
	if (t.a as Array).is_empty():
		return str(t.n)
	var parts := PackedStringArray()
	for a: Dictionary in t.a:
		parts.append(show(a))
	return "%s<%s>" % [t.n, ", ".join(parts)]


func _is_copy(t: Dictionary) -> bool:
	if is_int(t) or t.n in ["bool", "char", "f32", "f64", "{float}", "()", "!", "?", "str"]:
		return true
	if is_ref(t):
		return not t.mut
	if t.n == "Option":
		return _is_copy(t.a[0])
	if _structs.has(t.n):
		return "Copy" in _structs[t.n].derives
	if _enums.has(t.n):
		return "Copy" in _enums[t.n].derives
	return false


func _has_trait(t: Dictionary, which: String) -> bool:
	if t.n in ["?", "!"]:
		return true
	if is_ref(t):
		return _has_trait(t.a[0], which)
	if is_int(t) or t.n in ["bool", "char", "f32", "f64", "{float}", "String", "str"]:
		return true
	if which == "Display":
		return false
	if t.n in ["Vec", "Option", "Result"]:
		for a: Dictionary in t.a:
			if not _has_trait(a, which):
				return false
		return true
	if t.n == "()":
		return true
	if _structs.has(t.n):
		return which in _structs[t.n].derives
	if _enums.has(t.n):
		return which in _enums[t.n].derives
	return false


## Structural equality, where `{integer}` matches any integer and `_` anything.
func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.n == "?" or b.n == "?":
		return true
	if a.n == "{integer}" and is_int(b) or b.n == "{integer}" and is_int(a):
		return true
	if a.n != b.n:
		return false
	if is_ref(a) and a.mut != b.mut:
		return false
	if (a.a as Array).size() != (b.a as Array).size():
		return false
	for i in (a.a as Array).size():
		if not _same(a.a[i], b.a[i]):
			return false
	return true


## Whether a value of type `from` can go where `to` is expected, with the
## coercions rustc applies there: &mut T to &T, and deref coercion (&String
## to &str, &&T to &T).
func _coerces(from: Dictionary, to: Dictionary) -> bool:
	if from.n == "!" or from.n == "?" or to.n == "?":
		return true
	if is_ref(from) and is_ref(to):
		if to.mut and not from.mut:
			return false
		var inner: Dictionary = from.a[0]
		var want: Dictionary = to.a[0]
		while true:
			if _same(inner, want):
				return true
			if inner.n == "String" and want.n == "str":
				return true
			if is_ref(inner) and not (want.mut and not inner.mut):
				inner = inner.a[0]
				continue
			return false
	return _same(from, to)


## Replaces leftover `{integer}` with i32, the way an unconstrained integer
## literal defaults.
static func _settle(t: Dictionary) -> Dictionary:
	if t.n == "{integer}":
		return T("i32")
	if (t.a as Array).is_empty():
		return t
	var out := t.duplicate()
	var args: Array = []
	for a: Dictionary in t.a:
		args.append(_settle(a))
	out["a"] = args
	return out


## Fills `_` holes in `a` from `b` (Option<_> meeting Option<i32>).
func _fill(a: Dictionary, b: Dictionary) -> Dictionary:
	if a.n == "?":
		return b
	if a.n == "{integer}" and is_int(b) and b.n != "{integer}":
		return b
	if a.n != b.n or (a.a as Array).size() != (b.a as Array).size():
		return a
	var out := a.duplicate()
	var args: Array = []
	for i in (a.a as Array).size():
		args.append(_fill(a.a[i], b.a[i]))
	out["a"] = args
	return out


func _subst(t: Dictionary, map: Dictionary) -> Dictionary:
	if map.has(t.n) and (t.a as Array).is_empty():
		return map[t.n]
	if (t.a as Array).is_empty():
		return t
	var out := t.duplicate()
	var args: Array = []
	for a: Dictionary in t.a:
		args.append(_subst(a, map))
	out["a"] = args
	return out


## A type written in the source, resolved. Reports unknown names and
## undeclared lifetimes.
func _resolve(node: Variant, lifetimes: Array = []) -> Dictionary:
	if node == null:
		return UNIT
	var n: Dictionary = node
	match str(n.k):
		"unit":
			return UNIT
		"ref":
			if n.lt != "" and n.lt != "'static" and not (n.lt in lifetimes):
				_error("E0261", "use of undeclared lifetime name `%s`" % n.lt, n.line)
			return R(_resolve(n.inner, lifetimes), n.mut)
	var name := str(n.name)
	if name == "Self" and _self_type != null:
		return _self_type
	var args: Array = []
	for a: Variant in n.args:
		args.append(_resolve(a, lifetimes))
	if name in INTS or name in BUILTIN_TYPES or _structs.has(name) or _enums.has(name):
		var want := {"Vec": 1, "Option": 1, "Result": 2}.get(name, 0) as int
		if args.size() != want:
			_error("E0107", "wrong number of generic arguments on `%s`" % name, n.line)
			return ANY
		return T(name, args)
	_error("E0412", "cannot find type `%s` in this scope" % name, n.line)
	return ANY


# --- Items ------------------------------------------------------------------

func _collect(items: Array) -> void:
	for item: Dictionary in items:
		match str(item.k):
			"struct":
				_structs[item.name] = {"fields": item.fields, "derives": item.derives, "types": {}}
			"enum":
				var variants := {}
				var order: Array = []
				for v: Dictionary in item.variants:
					variants[v.name] = v.fields
					order.append(v.name)
				_enums[item.name] = {"variants": variants, "order": order, "derives": item.derives, "types": {}}
			"fn":
				_fns[item.name] = item
			"impl":
				if not _methods.has(item.name):
					_methods[item.name] = {}
				for f: Dictionary in item.fns:
					_methods[item.name][f.name] = f
	for name: String in _structs:
		for field: Dictionary in _structs[name].fields:
			_structs[name].types[field.name] = _resolve(field.ty)
	for name: String in _enums:
		for vname: String in _enums[name].variants:
			var types: Array = []
			for ty: Variant in _enums[name].variants[vname]:
				types.append(_resolve(ty))
			_enums[name].types[vname] = types


## Resolves a function's parameter and return types and checks lifetime
## elision (E0106): a returned reference needs exactly one input lifetime,
## or &self, unless it names its lifetime.
func _signature(f: Dictionary, impl_name: Variant) -> void:
	_self_type = T(str(impl_name)) if impl_name != null else null
	var params: Array = []
	var inputs := 0
	for p: Dictionary in f.params:
		var ty := _resolve(p.ty, f.lifetimes)
		params.append(ty)
		inputs += _count_refs(p.ty)
	var ret := _resolve(f.ret, f.lifetimes)
	f["param_types"] = params
	f["ret_type"] = ret
	if f.ret != null and _has_elided_ref(f.ret):
		var by_self: bool = f.self_kind in ["&self", "&mut self"]
		if not by_self and inputs != 1:
			_error("E0106", "missing lifetime specifier", (f.ret as Dictionary).line)


static func _count_refs(node: Dictionary) -> int:
	if node.k == "ref":
		return 1 + _count_refs(node.inner)
	if node.k == "ty":
		var total := 0
		for a: Dictionary in node.args:
			total += _count_refs(a)
		return total
	return 0


static func _has_elided_ref(node: Dictionary) -> bool:
	if node.k == "ref":
		return node.lt == "" or _has_elided_ref(node.inner)
	if node.k == "ty":
		for a: Dictionary in node.args:
			if _has_elided_ref(a):
				return true
	return false


# --- Function bodies --------------------------------------------------------

func _walk_fn(f: Dictionary, impl_name: Variant) -> void:
	_fn = f
	_self_type = T(str(impl_name)) if impl_name != null else null
	_ret = f.ret_type
	_seq = 0
	_scopes = [{}]
	_vars = []
	_loans = []
	_loop_count = 0
	if _type_phase():
		_uses = {}
		_loops = []
	if f.self_kind != "":
		var st: Dictionary = _self_type if _self_type != null else ANY
		var self_ty: Dictionary = st
		if f.self_kind == "&self":
			self_ty = R(st, false)
		elif f.self_kind == "&mut self":
			self_ty = R(st, true)
		_declare("self", f.self_kind == "mut self", self_ty, true, f.line)
	for i in (f.params as Array).size():
		var p: Dictionary = f.params[i]
		_declare(p.name, p.mut, f.param_types[i], true, p.line)
	var body: Dictionary = f.body
	var result := _block(body)
	if not _type_phase():
		return
	var got: Dictionary = result.t
	if _ret.n != "()" and body.tail == null and got.n != "!":
		_error("E0308", "mismatched types: expected `%s`, found `()`" % show(_ret), _last_line(body))
	elif got.n != "!" and not _coerces(got, _ret):
		var line: int = (body.tail as Dictionary).line if body.tail != null else body.end_line
		_error("E0308", "mismatched types: expected `%s`, found `%s`" % [show(_ret), show(got)], line)


static func _last_line(body: Dictionary) -> int:
	if not (body.stmts as Array).is_empty():
		return int((body.stmts.back() as Dictionary).line)
	return int(body.line)


func _declare(name: String, mut: bool, ty: Dictionary, init: bool, line: int) -> int:
	var id := _vars.size()
	_vars.append({"name": name, "mut": mut, "ty": ty, "init": init, "moved": {}, "decl": _seq, "line": line, "depth": _scopes.size()})
	(_scopes.back() as Dictionary)[name] = id
	return id


func _lookup(name: String) -> int:
	for i in range(_scopes.size() - 1, -1, -1):
		if (_scopes[i] as Dictionary).has(name):
			return int(_scopes[i][name])
	return -1


func _tick() -> int:
	_seq += 1
	return _seq


func _use(id: int) -> void:
	if _type_phase():
		if not _uses.has(id):
			_uses[id] = []
		(_uses[id] as Array).append(_seq)


## Whether variable `id` is used again after `at` (or anywhere in a loop
## around `at` that it was declared outside of).
func _live_after(id: int, at: int) -> bool:
	var uses: Array = _uses.get(id, [])
	for u: int in uses:
		if u > at:
			return true
	var decl: int = _vars[id].decl if id < _vars.size() else 0
	for span: Array in _loops:
		if span[0] <= at and at <= span[1] and decl < span[0]:
			for u: int in uses:
				if u >= span[0] and u <= span[1]:
					return true
	return false


func _loan_live(loan: Dictionary, at: int) -> bool:
	if int(loan.until) > at:
		return true
	for h: int in loan.holders:
		if _live_after(h, at):
			return true
	return false


func _block(b: Dictionary) -> Dictionary:
	_tick()
	_scopes.append({})
	var diverges := false
	for s: Dictionary in b.stmts:
		var t := _stmt(s)
		if t.n == "!":
			diverges = true
	var out := {"t": UNIT, "loans": []}
	if b.tail != null:
		out = _value(b.tail)
	elif diverges:
		out = {"t": NEVER, "loans": []}
	var end := _tick()
	_end_scope(end, b.end_line)
	_scopes.pop_back()
	if diverges and b.tail == null:
		out["t"] = NEVER
	return out


## Locals die at the end of their block: a borrow of one that is still
## needed afterwards doesn't live long enough (E0597).
func _end_scope(at: int, line: int) -> void:
	if _type_phase():
		return
	var scope: Dictionary = _scopes.back()
	for name: String in scope:
		var id: int = scope[name]
		for loan: Dictionary in _loans:
			if loan.root != id:
				continue
			var outside := false
			for h: int in loan.holders:
				if _vars[h].depth < _scopes.size() and _live_after(h, at):
					outside = true
			if outside:
				_error("E0597", "`%s` does not live long enough: borrowed value does not live long enough" % _vars[id].name, int(loan.line))


func _stmt(s: Dictionary) -> Dictionary:
	_tick()
	if s.k == "let":
		var declared: Variant = null
		if s.ty != null:
			declared = _resolve(s.ty)
		var ty: Dictionary = declared if declared != null else ANY
		var carried: Array = []
		if s.init != null:
			var v := _value(s.init, declared)
			carried = v.loans
			if declared != null:
				if _type_phase() and not _coerces(v.t, declared):
					_error("E0308", "mismatched types: expected `%s`, found `%s`" % [show(declared), show(v.t)], s.line)
				ty = _fill(declared, v.t)
			else:
				ty = _settle(v.t)
		var id := _declare(s.name, s.mut, ty, s.init != null, s.line)
		for loan_id: int in carried:
			(_loans[loan_id].holders as Array).append(id)
		return UNIT
	var v := _value(s.e)
	if s.semi or s.e.k in ["for"]:
		return NEVER if v.t.n == "!" else UNIT
	return v.t


# --- Places -----------------------------------------------------------------

## A place expression (a variable, a field, an element, a dereference), or
## null for a temporary. {root, path, desc, through: "" | "&" | "&mut",
## via: var id of the reference passed through, index: bool, t: type}
func _place(e: Dictionary) -> Variant:
	_tick()
	match str(e.k):
		"path":
			if (e.segs as Array).size() != 1:
				return null
			var id := _lookup(e.segs[0])
			if id < 0:
				return null
			_use(id)
			return {"root": id, "path": "", "desc": e.segs[0], "through": "", "via": -1, "index": false, "t": _vars[id].ty}
		"field":
			var base: Variant = _place(e.e)
			if base == null:
				return null
			var p: Dictionary = (base as Dictionary).duplicate()
			var t: Dictionary = p.t
			while is_ref(t):
				p = _through(p, t)
				t = t.a[0]
			var ft := _field_type(t, e.name, e.line)
			p["path"] = str(p.path) + "." + str(e.name)
			p["desc"] = str(p.desc).trim_prefix("*") + "." + str(e.name)
			p["t"] = ft
			return p
		"index":
			var base: Variant = _place(e.e)
			if base == null:
				return null
			var p: Dictionary = (base as Dictionary).duplicate()
			var idx := _value(e.idx)
			var t: Dictionary = p.t
			while is_ref(t):
				p = _through(p, t)
				t = t.a[0]
			if _type_phase() and not is_int(idx.t) and idx.t.n != "?":
				_error("E0277", "the type `[%s]` cannot be indexed by `%s`" % [show(t.a[0]) if t.n == "Vec" else "_", show(idx.t)], e.line)
			if t.n != "Vec" and t.n != "?":
				if _type_phase():
					_error("E0608", "cannot index into a value of type `%s`" % show(t), e.line)
				p["t"] = ANY
				return p
			p["index"] = true
			p["vec"] = t
			p["t"] = t.a[0] if t.n == "Vec" else ANY
			p["desc"] = "%s[_]" % p.desc
			return p
		"deref":
			var base: Variant = _place(e.e)
			if base == null:
				return null
			var p: Dictionary = (base as Dictionary).duplicate()
			var t: Dictionary = p.t
			if not is_ref(t):
				if _type_phase() and t.n != "?":
					_error("E0614", "type `%s` cannot be dereferenced" % show(t), e.line)
				p["t"] = ANY
				return p
			p = _through(p, t)
			p["t"] = t.a[0]
			return p
	return null


func _through(p: Dictionary, ref_type: Dictionary) -> Dictionary:
	var out := p.duplicate()
	if out.through == "":
		out["via"] = p.root
		out["through"] = "&mut" if ref_type.mut else "&"
	elif not ref_type.mut:
		out["through"] = "&"
	out["desc"] = "*" + str(p.desc)
	return out


func _field_type(t: Dictionary, name: String, line: int) -> Dictionary:
	if t.n == "?":
		return ANY
	if _structs.has(t.n) and (_structs[t.n].types as Dictionary).has(name):
		return _structs[t.n].types[name]
	if _type_phase():
		_error("E0609", "no field `%s` on type `%s`" % [name, show(t)], line)
	return ANY


# --- Accesses (the borrow check) --------------------------------------------

## The variable a place lives in, for moves and loans: the reference it went
## through, if any.
func _owner(p: Dictionary) -> int:
	return int(p.via) if p.through != "" else int(p.root)


func _mutable(p: Dictionary) -> bool:
	if p.through == "&":
		return false
	if p.through == "&mut":
		return true
	return bool(_vars[p.root].mut)


## rustc words it "as it is behind" for a borrow (E0596) and "which is
## behind" for an assignment (E0594).
func _not_mutable_why(p: Dictionary, borrow: bool = false) -> String:
	if p.through == "&":
		return "as it is behind a `&` reference" if borrow else "which is behind a `&` reference"
	return "as `%s` is not declared as mutable" % _vars[p.root].name


## Checks one access to a place against moves and live borrows.
## kind: "read" | "borrow" | "borrow_mut" | "move" | "assign"
func _access(p: Dictionary, kind: String, line: int) -> void:
	if _type_phase():
		return
	var owner := _owner(p)
	var v: Dictionary = _vars[owner]
	var path: String = p.path if p.through == "" else ""
	# Initialized and not moved away?
	if kind != "assign" or p.through != "" or path != "":
		if not v.init:
			_error("E0381", "used binding `%s` isn't initialized" % v.name, line)
			return
		for moved: String in v.moved:
			if moved.begins_with(path) or path.begins_with(moved):
				var what := "borrow" if kind in ["borrow", "borrow_mut"] else "use"
				var partly := " partially" if moved.length() > path.length() else ""
				_error("E0382", "%s of%s moved value: `%s` (value moved at line %d)" % [what, partly, v.name + moved, v.moved[moved]], line)
				return
	# Live borrows of the same place, held by someone else.
	if p.through == "":
		for loan: Dictionary in _loans:
			if loan.root != p.root or not _overlaps(str(loan.path), path):
				continue
			if not _loan_live(loan, _seq):
				continue
			var name: String = p.desc
			match kind:
				"read":
					if loan.mut:
						_error("E0503", "cannot use `%s` because it was mutably borrowed" % name, line)
						return
				"borrow":
					if loan.mut:
						_error("E0502", "cannot borrow `%s` as immutable because it is also borrowed as mutable" % name, line)
						return
				"borrow_mut":
					if loan.mut:
						_error("E0499", "cannot borrow `%s` as mutable more than once at a time" % name, line)
					else:
						_error("E0502", "cannot borrow `%s` as mutable because it is also borrowed as immutable" % name, line)
					return
				"move":
					_error("E0505", "cannot move out of `%s` because it is borrowed" % name, line)
					return
				"assign":
					_error("E0506", "cannot assign to `%s` because it is borrowed" % name, line)
					return
	if kind == "move":
		if p.through != "" or p.index:
			var where := "index of `%s`" % show(p.vec) if p.index else "`%s` which is behind a %s reference" % [p.desc, "mutable" if p.through == "&mut" else "shared"]
			_error("E0507", "cannot move out of %s" % where, line)
			return
		v.moved[path] = line


static func _overlaps(a: String, b: String) -> bool:
	return a.begins_with(b) or b.begins_with(a)


## A value read out of a place: copied if its type is Copy, moved otherwise.
func _consume(p: Dictionary, line: int) -> Array:
	var t: Dictionary = p.t
	if _is_copy(t):
		_access(p, "read", line)
	else:
		_access(p, "move", line)
	# A reference copied or moved out carries the borrows it holds.
	if is_ref(t) and p.through == "" and p.path == "":
		return _held_by(p.root)
	return []


func _held_by(id: int) -> Array:
	var out: Array = []
	for loan: Dictionary in _loans:
		if id in loan.holders:
			out.append(loan.id)
	return out


func _borrow(p: Dictionary, mut: bool, line: int) -> Array:
	if _type_phase():
		return []
	if mut and not _mutable(p):
		var what := ("`%s`" % p.desc)
		_error("E0596", "cannot borrow %s as mutable, %s" % [what, _not_mutable_why(p, true)], line)
		return []
	_access(p, "borrow_mut" if mut else "borrow", line)
	if p.through != "":
		# Reborrowing through a reference: the new reference lives off the
		# borrows the old one holds.
		return _held_by(int(p.via))
	var id := _loans.size()
	_loans.append({"id": id, "root": p.root, "path": p.path, "mut": mut, "holders": [], "until": -1, "line": line})
	return [id]


# --- Expressions ------------------------------------------------------------

## Types an expression used as a value. Returns {t, loans}: its type and the
## borrows the value carries (when it is, or holds, a reference).
func _value(e: Dictionary, expect: Variant = null) -> Dictionary:
	match str(e.k):
		"path", "field", "index", "deref":
			if e.k == "path" and ((e.segs as Array).size() != 1 or _lookup(e.segs[0]) < 0):
				return _path_value(e, expect)
			var p: Variant = _place(e)
			if p == null:
				return {"t": ANY, "loans": []}
			return {"t": p.t, "loans": _consume(p, e.line)}
	_tick()
	match str(e.k):
		"int":
			if expect != null and is_int(expect):
				return {"t": expect, "loans": []}
			return {"t": INT_LIT, "loans": []}
		"float":
			return {"t": T("f64"), "loans": []}
		"str":
			return {"t": R(T("str")), "loans": []}
		"char":
			return {"t": T("char"), "loans": []}
		"bool":
			return {"t": T("bool"), "loans": []}
		"unit":
			return {"t": UNIT, "loans": []}
		"ref":
			return _ref(e, expect)
		"unary":
			var v := _value(e.e)
			if _type_phase():
				if e.op == "!" and v.t.n != "bool" and v.t.n != "?":
					_error("E0600", "cannot apply unary operator `!` to type `%s`" % show(v.t), e.line)
				if e.op == "-" and not is_int(v.t) and not (v.t.n in ["f64", "?"]):
					_error("E0600", "cannot apply unary operator `-` to type `%s`" % show(v.t), e.line)
			return {"t": v.t, "loans": []}
		"binary":
			return _binary(e)
		"assign":
			return _assign(e)
		"call":
			return _call(e, expect)
		"mcall":
			return _mcall(e)
		"block":
			return _block(e)
		"if":
			return _if(e, expect)
		"iflet":
			return _iflet(e, expect)
		"match":
			return _match(e, expect)
		"for":
			return _for(e)
		"return":
			var v := {"t": UNIT, "loans": []}
			if e.e != null:
				v = _value(e.e, _ret)
			if _type_phase() and not _coerces(v.t, _ret):
				_error("E0308", "mismatched types: expected `%s`, found `%s`" % [show(_ret), show(v.t)], e.line)
			return {"t": NEVER, "loans": []}
		"println":
			return _println(e)
		"vec":
			var item_t: Dictionary = ANY
			var inner_expect: Variant = null
			if expect != null and (expect as Dictionary).n == "Vec":
				inner_expect = expect.a[0]
			for item: Dictionary in e.items:
				var v := _value(item, inner_expect)
				if item_t.n == "?":
					item_t = v.t
				elif _type_phase() and not _coerces(v.t, item_t):
					_error("E0308", "mismatched types: expected `%s`, found `%s`" % [show(item_t), show(v.t)], item.line)
			return {"t": T("Vec", [item_t]), "loans": []}
		"slit":
			return _struct_lit(e)
		"try":
			return _try(e)
	return {"t": ANY, "loans": []}


func _path_value(e: Dictionary, expect: Variant) -> Dictionary:
	_tick()
	var segs: Array = e.segs
	if segs.size() == 1:
		var name := str(segs[0])
		if name == "None":
			var inner: Dictionary = ANY
			if expect != null and (expect as Dictionary).n == "Option":
				inner = expect.a[0]
			return {"t": T("Option", [inner]), "loans": []}
		if _type_phase():
			_error("E0425", "cannot find value `%s` in this scope" % name, e.line)
		return {"t": ANY, "loans": []}
	if segs.size() == 2 and _enums.has(segs[0]):
		var en: Dictionary = _enums[segs[0]]
		if not (en.variants as Dictionary).has(segs[1]):
			if _type_phase():
				_error("E0599", "no variant or associated item named `%s` found for enum `%s`" % [segs[1], segs[0]], e.line)
			return {"t": ANY, "loans": []}
		return {"t": T(segs[0]), "loans": []}
	if _type_phase():
		_error("E0433", "failed to resolve: use of undeclared type `%s`" % segs[0], e.line)
	return {"t": ANY, "loans": []}


func _ref(e: Dictionary, expect: Variant) -> Dictionary:
	var inner: Dictionary = e.e
	if inner.k in ["path", "field", "index", "deref"] and not (inner.k == "path" and _lookup(inner.segs[0]) < 0):
		var p: Variant = _place(inner)
		if p == null:
			return {"t": ANY, "loans": []}
		return {"t": R(p.t, e.mut), "loans": _borrow(p, e.mut, e.line)}
	var inner_expect: Variant = null
	if expect != null and is_ref(expect):
		inner_expect = expect.a[0]
	var v := _value(inner, inner_expect)
	return {"t": R(v.t, e.mut), "loans": v.loans}


## For comparisons and printing: operands are borrowed, not moved.
func _peek_value(e: Dictionary) -> Dictionary:
	if e.k in ["path", "field", "index", "deref"] and not (e.k == "path" and ((e.segs as Array).size() != 1 or _lookup(e.segs[0]) < 0)):
		var p: Variant = _place(e)
		if p == null:
			return {"t": ANY, "loans": []}
		_access(p, "borrow", e.line)
		return {"t": p.t, "loans": []}
	return _value(e)


func _binary(e: Dictionary) -> Dictionary:
	var op := str(e.op)
	if op in ["==", "!=", "<", ">", "<=", ">="]:
		var l := _peek_value(e.l)
		var r := _peek_value(e.r)
		if _type_phase() and not _comparable(l.t, r.t):
			_error("E0308", "mismatched types: expected `%s`, found `%s`" % [show(l.t), show(r.t)], e.line)
		return {"t": T("bool"), "loans": []}
	var lv := _value(e.l)
	var rv := _value(e.r, lv.t if is_int(lv.t) else null)
	if op == "&&" or op == "||":
		if _type_phase():
			for v: Dictionary in [lv, rv]:
				if v.t.n != "bool" and v.t.n != "?":
					_error("E0308", "mismatched types: expected `bool`, found `%s`" % show(v.t), e.line)
		return {"t": T("bool"), "loans": []}
	if lv.t.n == "?" or rv.t.n == "?":
		return {"t": ANY, "loans": []}
	if is_int(lv.t) and is_int(rv.t):
		if not _same(lv.t, rv.t):
			if _type_phase():
				_error("E0308", "mismatched types: expected `%s`, found `%s`" % [show(lv.t), show(rv.t)], e.line)
			return {"t": lv.t, "loans": []}
		return {"t": rv.t if lv.t.n == "{integer}" else lv.t, "loans": []}
	if op == "+" and lv.t.n == "String":
		if not _coerces(rv.t, R(T("str"))):
			if _type_phase():
				_error("E0308", "mismatched types: expected `&str`, found `%s`" % show(rv.t), e.line)
		return {"t": T("String"), "loans": []}
	if _type_phase():
		var verbs := {"+": "add", "-": "subtract", "*": "multiply", "/": "divide", "%": "calculate the remainder of"}
		_error("E0369", "cannot %s `%s` to `%s`" % [verbs.get(op, op), show(rv.t), show(lv.t)], e.line)
	return {"t": ANY, "loans": []}


func _comparable(a: Dictionary, b: Dictionary) -> bool:
	if _same(a, b):
		return true
	# String == &str and &str == String are both implemented.
	var str_a: bool = is_ref(a) and (a.a[0] as Dictionary).n == "str"
	var str_b: bool = is_ref(b) and (b.a[0] as Dictionary).n == "str"
	return (a.n == "String" and str_b) or (str_a and b.n == "String")


func _assign(e: Dictionary) -> Dictionary:
	var target: Dictionary = e.l
	if not (target.k in ["path", "field", "index", "deref"]):
		if _type_phase():
			_error("E0070", "invalid left-hand side of assignment", e.line)
		return {"t": UNIT, "loans": []}
	if target.k == "path" and ((target.segs as Array).size() != 1 or _lookup(target.segs[0]) < 0):
		if _type_phase():
			_error("E0425", "cannot find value `%s` in this scope" % "::".join(PackedStringArray(target.segs)), e.line)
		return {"t": UNIT, "loans": []}
	# The right side runs first.
	var rv := _value(e.r)
	_tick()
	var p: Dictionary
	if target.k == "path":
		var id := _lookup(target.segs[0])
		# Assigning isn't a use: it doesn't keep the old value's borrows alive.
		p = {"root": id, "path": "", "desc": target.segs[0], "through": "", "via": -1, "index": false, "t": _vars[id].ty}
	else:
		p = _place(target)
	var lt: Dictionary = p.t
	if e.op == "=":
		if lt.n == "?" and target.k == "path":
			lt = _settle(rv.t)
			_vars[p.root].ty = lt
			p["t"] = lt
		elif _type_phase() and not _coerces(rv.t, lt):
			_error("E0308", "mismatched types: expected `%s`, found `%s`" % [show(lt), show(rv.t)], e.line)
	else:
		var ok: bool = (is_int(lt) and is_int(rv.t) and _same(lt, rv.t)) or (e.op == "+=" and lt.n == "String" and _coerces(rv.t, R(T("str"))))
		if _type_phase() and not ok and lt.n != "?" and rv.t.n != "?":
			_error("E0368", "binary assignment operation `%s` cannot be applied to type `%s`" % [e.op, show(lt)], e.line)
	if _type_phase():
		return {"t": UNIT, "loans": []}
	var v: Dictionary = _vars[p.root]
	if p.through == "" and p.path == "" and not p.index:
		if e.op != "=" and v.init:
			if not v.mut:
				_error("E0384", "cannot assign twice to immutable variable `%s`" % v.name, e.line)
				return {"t": UNIT, "loans": []}
			_access(p, "assign", e.line)
			return {"t": UNIT, "loans": []}
		if v.init and not v.mut:
			_error("E0384", "cannot assign twice to immutable variable `%s`" % v.name, e.line)
			return {"t": UNIT, "loans": []}
		if v.init:
			_access(p, "assign", e.line)
		# The old value's borrows end here; the new value's begin.
		for loan: Dictionary in _loans:
			(loan.holders as Array).erase(p.root)
		v.init = true
		v.moved = {}
		for loan_id: int in rv.loans:
			(_loans[loan_id].holders as Array).append(p.root)
		return {"t": UNIT, "loans": []}
	if not _mutable(p):
		_error("E0594", "cannot assign to `%s`, %s" % [p.desc, _not_mutable_why(p)], e.line)
		return {"t": UNIT, "loans": []}
	if p.through == "":
		_access(p, "assign", e.line)
		if e.op == "=":
			(v.moved as Dictionary).erase(p.path)
	else:
		_access(p, "read", e.line)
	return {"t": UNIT, "loans": []}


func _check_args(args: Array, params: Array, what: String, line: int) -> Array:
	var carried: Array = []
	if args.size() != params.size() and _type_phase():
		_error("E0061", "this %s takes %d argument%s but %d argument%s supplied" % [what, params.size(), "" if params.size() == 1 else "s", args.size(), " was" if args.size() == 1 else "s were"], line)
	for i in args.size():
		var want: Variant = params[i] if i < params.size() else null
		var v := _value(args[i], want)
		carried.append_array(v.loans)
		if want != null and _type_phase() and not _coerces(v.t, want):
			_error("E0308", "mismatched types: expected `%s`, found `%s`" % [show(want), show(v.t)], (args[i] as Dictionary).line)
	return carried


static func _has_ref(t: Dictionary) -> bool:
	if is_ref(t) or t.n == "Iter":
		return true
	for a: Dictionary in t.a:
		if _has_ref(a):
			return true
	return false


func _call(e: Dictionary, expect: Variant) -> Dictionary:
	var f: Dictionary = e.f
	if f.k != "path":
		if _type_phase():
			_error("E0618", "expected function", e.line)
		return {"t": ANY, "loans": []}
	var segs: Array = f.segs
	var name := "::".join(PackedStringArray(segs))
	var args: Array = e.args
	var want: Dictionary = expect if expect != null else ANY
	match name:
		"Some":
			var inner: Variant = want.a[0] if want.n == "Option" else null
			var v := _one_arg(args, inner, e.line)
			return {"t": T("Option", [v.t]), "loans": v.loans}
		"Ok":
			var inner: Variant = want.a[0] if want.n == "Result" else null
			var v := _one_arg(args, inner, e.line)
			return {"t": T("Result", [v.t, want.a[1] if want.n == "Result" else ANY]), "loans": v.loans}
		"Err":
			var inner: Variant = want.a[1] if want.n == "Result" else null
			var v := _one_arg(args, inner, e.line)
			return {"t": T("Result", [want.a[0] if want.n == "Result" else ANY, v.t]), "loans": v.loans}
		"String::from":
			_check_args(args, [R(T("str"))], "function", e.line)
			return {"t": T("String"), "loans": []}
		"String::new":
			_check_args(args, [], "function", e.line)
			return {"t": T("String"), "loans": []}
		"Vec::new":
			_check_args(args, [], "function", e.line)
			return {"t": want if want.n == "Vec" else T("Vec", [ANY]), "loans": []}
	if segs.size() == 2 and _enums.has(segs[0]):
		var en: Dictionary = _enums[segs[0]]
		if not (en.types as Dictionary).has(segs[1]):
			if _type_phase():
				_error("E0599", "no variant or associated item named `%s` found for enum `%s`" % [segs[1], segs[0]], e.line)
			return {"t": ANY, "loans": []}
		_check_args(args, en.types[segs[1]], "enum variant", e.line)
		return {"t": T(segs[0]), "loans": []}
	if segs.size() == 1 and _fns.has(name):
		var fn: Dictionary = _fns[name]
		var carried := _check_args(args, fn.param_types, "function", e.line)
		var ret: Dictionary = fn.ret_type
		return {"t": ret, "loans": carried if _has_ref(ret) else []}
	if segs.size() == 2 and _methods.has(segs[0]) and (_methods[segs[0]] as Dictionary).has(segs[1]):
		var fn: Dictionary = _methods[segs[0]][segs[1]]
		if fn.self_kind == "":
			var carried := _check_args(args, fn.param_types, "function", e.line)
			return {"t": fn.ret_type, "loans": carried if _has_ref(fn.ret_type) else []}
	if _type_phase():
		_error("E0425", "cannot find function `%s` in this scope" % name, e.line)
	for a: Dictionary in args:
		_value(a)
	return {"t": ANY, "loans": []}


func _one_arg(args: Array, expect: Variant, line: int) -> Dictionary:
	if args.size() != 1:
		if _type_phase():
			_error("E0061", "this enum variant takes 1 argument but %d arguments were supplied" % args.size(), line)
		for a: Dictionary in args:
			_value(a)
		return {"t": ANY, "loans": []}
	return _value(args[0], expect)


## Built-in methods: [receiver ("&self", "&mut self", "self"), params, return].
## T and E stand for the receiver's type arguments.
const BUILTIN_METHODS := {
	"String": {
		"len": ["&self", [], "usize"], "push_str": ["&mut self", ["&str"], "()"], "clone": ["&self", [], "String"],
		"is_empty": ["&self", [], "bool"], "to_string": ["&self", [], "String"], "as_str": ["&self", [], "&str"],
		"to_uppercase": ["&self", [], "String"], "contains": ["&self", ["&str"], "bool"], "clear": ["&mut self", [], "()"],
	},
	"str": {
		"len": ["&self", [], "usize"], "to_string": ["&self", [], "String"], "is_empty": ["&self", [], "bool"],
		"to_uppercase": ["&self", [], "String"], "contains": ["&self", ["&str"], "bool"], "clone": ["&self", [], "&str"],
	},
	"Vec": {
		"len": ["&self", [], "usize"], "push": ["&mut self", ["T"], "()"], "pop": ["&mut self", [], "Option<T>"],
		"clear": ["&mut self", [], "()"], "iter": ["&self", [], "Iter<&T>"], "clone": ["&self", [], "Vec<T>"],
		"is_empty": ["&self", [], "bool"], "contains": ["&self", ["&T"], "bool"],
	},
	"Option": {
		"unwrap": ["self", [], "T"], "is_some": ["&self", [], "bool"], "is_none": ["&self", [], "bool"],
		"unwrap_or": ["self", ["T"], "T"], "clone": ["&self", [], "Option<T>"],
	},
	"Result": {
		"unwrap": ["self", [], "T"], "is_ok": ["&self", [], "bool"], "is_err": ["&self", [], "bool"],
		"clone": ["&self", [], "Result<T, E>"],
	},
	"int": {"clone": ["&self", [], "Self"], "to_string": ["&self", [], "String"], "abs": ["self", [], "Self"]},
	"bool": {"clone": ["&self", [], "Self"], "to_string": ["&self", [], "String"]},
}


## A type written in BUILTIN_METHODS, read with T, E and Self filled in.
func _builtin_type(text: String, map: Dictionary) -> Dictionary:
	text = text.strip_edges()
	if text.begins_with("&"):
		return R(_builtin_type(text.substr(1), map))
	if map.has(text):
		return map[text]
	if text == "()":
		return UNIT
	var lt := text.find("<")
	if lt < 0:
		return T(text)
	var name := text.substr(0, lt)
	var inner := text.substr(lt + 1, text.length() - lt - 2)
	var args: Array = []
	for part in inner.split(","):
		args.append(_builtin_type(part, map))
	return T(name, args)


func _mcall(e: Dictionary) -> Dictionary:
	var recv: Dictionary = e.recv
	var p: Variant = null
	var rt: Dictionary
	var recv_loans: Array = []
	if recv.k in ["path", "field", "index", "deref"] and not (recv.k == "path" and ((recv.segs as Array).size() != 1 or _lookup(recv.segs[0]) < 0)):
		p = _place(recv)
		if p == null:
			return {"t": ANY, "loans": []}
		rt = p.t
	else:
		var v := _value(recv)
		rt = v.t
		recv_loans = v.loans
	_tick()
	# Auto-deref the receiver to find the method.
	var base := rt
	var through := ""
	while is_ref(base):
		through = "&mut" if base.mut and through != "&" else "&"
		base = base.a[0]
	var sig: Variant = null
	var user: Variant = null
	var map := {"Self": base}
	if base.n == "?":
		for a: Dictionary in e.args:
			_value(a)
		return {"t": ANY, "loans": []}
	if _methods.has(base.n) and (_methods[base.n] as Dictionary).has(e.name):
		user = _methods[base.n][e.name]
		if (user as Dictionary).self_kind == "":
			user = null
	if user == null:
		var table_key: String = "int" if is_int(base) else str(base.n)
		var table: Dictionary = BUILTIN_METHODS.get(table_key, {})
		if base.n == "Vec" or base.n == "Option":
			map["T"] = base.a[0]
		elif base.n == "Result":
			map["T"] = base.a[0]
			map["E"] = base.a[1]
		if e.name == "clone" and (_structs.has(base.n) or _enums.has(base.n)):
			var derives: Array = _structs[base.n].derives if _structs.has(base.n) else _enums[base.n].derives
			if "Clone" in derives:
				table = {"clone": ["&self", [], "Self"]}
		if table.has(e.name):
			sig = table[e.name]
	var kind: String
	var params: Array = []
	var ret: Dictionary
	if user != null:
		kind = "self" if user.self_kind == "mut self" else str(user.self_kind)
		params = user.param_types
		ret = user.ret_type
	elif sig != null:
		kind = sig[0]
		for text: String in sig[1]:
			params.append(_builtin_type(text, map))
		ret = _builtin_type(sig[2], map)
	else:
		if _type_phase():
			var what := "struct" if _structs.has(base.n) else ("enum" if _enums.has(base.n) else "type")
			_error("E0599", "no method named `%s` found for %s `%s` in the current scope" % [e.name, what, show(base)], e.line)
		for a: Dictionary in e.args:
			_value(a)
		return {"t": ANY, "loans": []}
	# The receiver, borrowed or moved as the method asks.
	var carried: Array = recv_loans.duplicate()
	if p != null and not _type_phase():
		var place: Dictionary = (p as Dictionary).duplicate()
		if through != "":
			place = _through(place, R(base, through == "&mut"))
			place["t"] = base
		match kind:
			"&self":
				carried = _borrow(place, false, e.line)
			"&mut self":
				carried = _borrow(place, true, e.line)
			"self":
				carried = _consume(place, e.line)
	var arg_loans := _check_args(e.args, params, "method", e.line)
	if not _has_ref(ret):
		return {"t": ret, "loans": []}
	if user != null and kind == "self":
		carried.append_array(arg_loans)
	return {"t": ret, "loans": carried}


func _println(e: Dictionary) -> Dictionary:
	var fmt: String = e.fmt
	var holes: Array = []
	var i := 0
	while i < fmt.length():
		var c := fmt[i]
		if c == "{":
			if i + 1 < fmt.length() and fmt[i + 1] == "{":
				i += 2
				continue
			var close := fmt.find("}", i)
			if close < 0:
				if _type_phase():
					_error("", "invalid format string: expected `}` but string was terminated", e.line)
				return {"t": UNIT, "loans": []}
			holes.append(fmt.substr(i + 1, close - i - 1))
			i = close + 1
			continue
		if c == "}":
			if i + 1 < fmt.length() and fmt[i + 1] == "}":
				i += 2
				continue
			if _type_phase():
				_error("", "invalid format string: unmatched `}` found", e.line)
			return {"t": UNIT, "loans": []}
		i += 1
	var args: Array = e.args
	var positional := 0
	for hole: String in holes:
		var name := hole.get_slice(":", 0)
		if name == "":
			positional += 1
	if positional != args.size() and _type_phase():
		_error("", "%d positional argument%s in format string, but there %s %d argument%s" % [positional, "" if positional == 1 else "s", "is" if args.size() == 1 else "are", args.size(), "" if args.size() == 1 else "s"], e.line)
		return {"t": UNIT, "loans": []}
	var types: Array = []
	for a: Dictionary in args:
		types.append(_peek_value(a).t)
	var next := 0
	for hole: String in holes:
		var name := hole.get_slice(":", 0)
		var spec := hole.get_slice(":", 1) if hole.contains(":") else ""
		var t: Dictionary
		if name == "":
			t = types[next] if next < types.size() else ANY
			next += 1
		else:
			var id := _lookup(name)
			if id < 0:
				if _type_phase():
					_error("E0425", "cannot find value `%s` in this scope" % name, e.line)
				continue
			var p: Variant = _place({"k": "path", "segs": [name], "line": e.line})
			_access(p, "borrow", e.line)
			t = _vars[id].ty
		var trait_name := "Debug" if spec == "?" else "Display"
		if _type_phase() and not _has_trait(t, trait_name):
			var shown := "`%s` doesn't implement `%s`" % [show(t), "std::fmt::Display" if trait_name == "Display" else "Debug"]
			_error("E0277", shown, e.line)
	return {"t": NEVER if e.mac == "panic" else UNIT, "loans": []}


func _struct_lit(e: Dictionary) -> Dictionary:
	if not _structs.has(e.name):
		if _type_phase():
			_error("E0422", "cannot find struct, variant or union type `%s` in this scope" % e.name, e.line)
		for f: Dictionary in e.fields:
			_value(f.e)
		return {"t": ANY, "loans": []}
	var st: Dictionary = _structs[e.name]
	var given := {}
	for f: Dictionary in e.fields:
		var want: Variant = (st.types as Dictionary).get(f.name, null)
		var v := _value(f.e, want)
		given[f.name] = true
		if want == null:
			if _type_phase():
				_error("E0560", "struct `%s` has no field named `%s`" % [e.name, f.name], f.line)
		elif _type_phase() and not _coerces(v.t, want):
			_error("E0308", "mismatched types: expected `%s`, found `%s`" % [show(want), show(v.t)], f.line)
	var missing: Array = []
	for field: Dictionary in st.fields:
		if not given.has(field.name):
			missing.append("`%s`" % field.name)
	if not missing.is_empty() and _type_phase():
		_error("E0063", "missing field%s %s in initializer of `%s`" % ["" if missing.size() == 1 else "s", ", ".join(PackedStringArray(missing)), e.name], e.line)
	return {"t": T(e.name), "loans": []}


func _try(e: Dictionary) -> Dictionary:
	var v := _value(e.e)
	var t: Dictionary = v.t
	if t.n == "?":
		return {"t": ANY, "loans": []}
	if t.n != "Result" and t.n != "Option":
		if _type_phase():
			_error("E0277", "the `?` operator can only be applied to values that implement `Try`", e.line)
		return {"t": ANY, "loans": []}
	if _type_phase():
		if _ret.n != t.n:
			_error("E0277", "the `?` operator can only be used in a function that returns `Result` or `Option`", e.line)
		elif t.n == "Result" and not _same(t.a[1], _ret.a[1]):
			_error("E0277", "`?` couldn't convert the error to `%s`" % show(_ret.a[1]), e.line)
	return {"t": t.a[0], "loans": v.loans}


func _unify(a: Dictionary, b: Dictionary) -> Variant:
	if a.n == "!":
		return b
	if b.n == "!":
		return a
	if _coerces(b, a):
		return _fill(a, b)
	if _coerces(a, b):
		return _fill(b, a)
	return null


func _if(e: Dictionary, expect: Variant) -> Dictionary:
	var cond := _value(e.cond)
	if _type_phase() and cond.t.n != "bool" and cond.t.n != "?" and cond.t.n != "!":
		_error("E0308", "mismatched types: expected `bool`, found `%s`" % show(cond.t), (e.cond as Dictionary).line)
	var before := _snapshot()
	var then := _block(e.then)
	if e.else == null:
		_merge([_snapshot(), before])
		return {"t": UNIT, "loans": then.loans}
	var after_then := _snapshot()
	_restore(before)
	var other: Dictionary
	if (e.else as Dictionary).k == "if":
		other = _if(e.else, expect)
	else:
		other = _block(e.else)
	_merge([after_then, _snapshot()])
	var t: Variant = _unify(then.t, other.t)
	if t == null:
		if _type_phase():
			_error("E0308", "`if` and `else` have incompatible types: expected `%s`, found `%s`" % [show(then.t), show(other.t)], e.line)
		t = ANY
	var loans: Array = then.loans.duplicate()
	loans.append_array(other.loans)
	return {"t": t, "loans": loans}


## Move state is copied per branch and merged after: a value moved on any
## path counts as moved.
func _snapshot() -> Array:
	var out: Array = []
	for v: Dictionary in _vars:
		out.append([v.init, (v.moved as Dictionary).duplicate()])
	return out


func _restore(snap: Array) -> void:
	for i in snap.size():
		_vars[i].init = snap[i][0]
		_vars[i].moved = (snap[i][1] as Dictionary).duplicate()


func _merge(snaps: Array) -> void:
	for i in _vars.size():
		var init := true
		var moved := {}
		for snap: Array in snaps:
			if i >= snap.size():
				continue
			init = init and bool(snap[i][0])
			moved.merge(snap[i][1])
		_vars[i].init = init
		_vars[i].moved = moved


## Whether the scrutinee is a place, read by the patterns or moved into them.
func _scrutinee(e: Dictionary) -> Dictionary:
	if e.k in ["path", "field", "index", "deref"] and not (e.k == "path" and ((e.segs as Array).size() != 1 or _lookup(e.segs[0]) < 0)):
		var p: Variant = _place(e)
		if p == null:
			return {"t": ANY, "place": null, "loans": []}
		return {"t": p.t, "place": p, "loans": []}
	var v := _value(e)
	return {"t": v.t, "place": null, "loans": v.loans}


func _bind_moves(scrut: Dictionary, moves: bool, line: int) -> void:
	if scrut.place == null or _type_phase():
		return
	if moves:
		_access(scrut.place, "move", line)
	else:
		_access(scrut.place, "read", line)


func _iflet(e: Dictionary, expect: Variant) -> Dictionary:
	var scrut := _scrutinee(e.e)
	var before := _snapshot()
	_scopes.append({})
	var bound: Array = []
	var moves := _pattern(e.pat, scrut.t, bound, false)
	_bind_moves(scrut, moves, e.line)
	for b: Array in bound:
		_declare(b[0], b[1], b[2], true, e.line)
	var then := _block(e.then)
	_scopes.pop_back()
	var after_then := _snapshot()
	_restore(before)
	var other := {"t": UNIT, "loans": []}
	if e.else != null:
		other = _if(e.else, expect) if (e.else as Dictionary).k == "if" else _block(e.else)
	_merge([after_then, _snapshot()])
	var t: Variant = _unify(then.t, other.t)
	return {"t": t if t != null else ANY, "loans": []}


func _match(e: Dictionary, expect: Variant) -> Dictionary:
	var scrut := _scrutinee(e.e)
	var before := _snapshot()
	var ends: Array = []
	var result: Variant = null
	var any_moves := false
	var bindings: Array = []
	for arm: Dictionary in e.arms:
		var bound: Array = []
		any_moves = _pattern(arm.pat, scrut.t, bound, false) or any_moves
		bindings.append(bound)
	_bind_moves(scrut, any_moves, e.line)
	var loans: Array = []
	for index in (e.arms as Array).size():
		var arm: Dictionary = e.arms[index]
		if index > 0:
			_restore(before)
		_scopes.append({})
		for b: Array in bindings[index]:
			_declare(b[0], b[1], b[2], true, arm.line)
		var v := _value(arm.body, expect)
		loans.append_array(v.loans)
		_scopes.pop_back()
		ends.append(_snapshot())
		if result == null:
			result = v.t
		else:
			var t: Variant = _unify(result, v.t)
			if t == null:
				if _type_phase():
					_error("E0308", "`match` arms have incompatible types: expected `%s`, found `%s`" % [show(result), show(v.t)], (arm.body as Dictionary).line)
				t = ANY
			result = t
	if not ends.is_empty():
		_merge(ends)
	if _type_phase():
		_exhaustive(e, scrut.t)
	return {"t": result if result != null else NEVER, "loans": loans}


## Types a pattern against `t`, collecting its bindings as [name, mut, type].
## Returns true when it moves a non-Copy value out into a binding. Matching a
## reference against a non-reference pattern binds by reference (rustc's
## default binding modes).
func _pattern(p: Dictionary, t: Dictionary, bound: Array, by_ref: bool) -> bool:
	var moves := false
	if is_ref(t) and p.k in ["ptuple", "ppath", "plit"]:
		if p.k == "plit" and (t.a[0] as Dictionary).n == "str":
			pass
		else:
			return _pattern(p, t.a[0], bound, true)
	match str(p.k):
		"wild":
			return false
		"bind":
			var bt: Dictionary = R(t) if by_ref else t
			bound.append([p.name, p.mut, bt])
			return not by_ref and not _is_copy(t)
		"plit":
			var lit_t: Dictionary
			if typeof(p.v) == TYPE_BOOL:
				lit_t = T("bool")
			elif typeof(p.v) == TYPE_INT:
				lit_t = INT_LIT
			else:
				lit_t = R(T("str"))
			if _type_phase() and not _same(lit_t, t) and t.n != "?":
				_error("E0308", "mismatched types: expected `%s`, found `%s`" % [show(t), show(lit_t)], p.line)
			return false
		"pref":
			if is_ref(t):
				return _pattern(p.pat, t.a[0], bound, false)
			if _type_phase() and t.n != "?":
				_error("E0308", "mismatched types: expected `%s`, found `&_`" % show(t), p.line)
			return false
		"ppath", "ptuple":
			var info := _variant(p, t)
			if info.is_empty():
				for sub: Dictionary in p.get("subs", []):
					_pattern(sub, ANY, bound, by_ref)
				return false
			var fields: Array = info.fields
			var subs: Array = p.get("subs", [])
			if p.k == "ppath" and not fields.is_empty() and _type_phase():
				_error("E0532", "expected unit struct, unit variant or constant, found tuple variant `%s`" % "::".join(PackedStringArray(p.segs)), p.line)
			if subs.size() != fields.size() and p.k == "ptuple" and _type_phase():
				_error("E0023", "this pattern has %d field%s, but the corresponding tuple variant has %d field%s" % [subs.size(), "" if subs.size() == 1 else "s", fields.size(), "" if fields.size() == 1 else "s"], p.line)
			for i in subs.size():
				var ft: Dictionary = fields[i] if i < fields.size() else ANY
				moves = _pattern(subs[i], ft, bound, by_ref) or moves
			return moves
	return false


## Which variant a path pattern names, checked against the scrutinee type:
## {fields: [types]} or {} after reporting the problem.
func _variant(p: Dictionary, t: Dictionary) -> Dictionary:
	var segs: Array = p.segs
	var last := str(segs.back())
	var enum_name := ""
	var fields: Array = []
	if segs.size() == 1 and last in ["Some", "None"]:
		enum_name = "Option"
		var inner: Dictionary = t.a[0] if t.n == "Option" else ANY
		fields = [inner] if last == "Some" else []
	elif segs.size() == 1 and last in ["Ok", "Err"]:
		enum_name = "Result"
		var ok_t: Dictionary = t.a[0] if t.n == "Result" else ANY
		var err_t: Dictionary = t.a[1] if t.n == "Result" else ANY
		fields = [ok_t] if last == "Ok" else [err_t]
	elif segs.size() == 2 and _enums.has(segs[0]):
		enum_name = segs[0]
		if not (_enums[enum_name].types as Dictionary).has(last):
			if _type_phase():
				_error("E0599", "no variant or associated item named `%s` found for enum `%s`" % [last, enum_name], p.line)
			return {}
		fields = _enums[enum_name].types[last]
	else:
		if _type_phase():
			_error("E0531", "cannot find tuple struct or tuple variant `%s` in this scope" % last, p.line)
		return {}
	if t.n != enum_name and t.n != "?":
		if _type_phase():
			var shown := "%s<_>" % enum_name if enum_name in ["Option"] else ("%s<_, _>" % enum_name if enum_name == "Result" else enum_name)
			_error("E0308", "mismatched types: expected `%s`, found `%s`" % [show(t), shown], p.line)
		return {}
	return {"fields": fields, "enum": enum_name}


## E0004: every value of the scrutinee's type has to match some arm.
func _exhaustive(e: Dictionary, t: Dictionary) -> void:
	while is_ref(t):
		t = t.a[0]
	if t.n == "?":
		return
	var covered := {}
	for arm: Dictionary in e.arms:
		var p: Dictionary = arm.pat
		while p.k == "pref":
			p = p.pat
		if p.k == "wild" or p.k == "bind":
			return
		if p.k == "ppath":
			covered[str((p.segs as Array).back())] = true
		elif p.k == "ptuple":
			var all_irrefutable := true
			for sub: Dictionary in p.subs:
				if not (sub.k in ["wild", "bind"]):
					all_irrefutable = false
			if all_irrefutable:
				covered[str((p.segs as Array).back())] = true
		elif p.k == "plit" and typeof(p.v) == TYPE_BOOL:
			covered[str(p.v)] = true
	var all: Array = []
	var prefix := ""
	if t.n == "Option":
		all = ["Some", "None"]
	elif t.n == "Result":
		all = ["Ok", "Err"]
	elif t.n == "bool":
		all = ["true", "false"]
	elif _enums.has(t.n):
		all = _enums[t.n].order
		prefix = t.n + "::"
	else:
		_error("E0004", "non-exhaustive patterns: `_` not covered", e.line)
		return
	var missing: Array = []
	for name: String in all:
		if not covered.has(name):
			var fields: Array = []
			if t.n == "Option" and name == "Some" or t.n == "Result":
				fields = ["_"]
			elif _enums.has(t.n):
				for _f: Variant in _enums[t.n].types[name]:
					fields.append("_")
			var shown := prefix + name
			if not fields.is_empty():
				shown += "(%s)" % ", ".join(PackedStringArray(fields))
			missing.append("`%s`" % shown)
	if not missing.is_empty():
		var listed := ", ".join(PackedStringArray(missing)) if missing.size() < 3 else "%s and %d more" % [", ".join(PackedStringArray(missing.slice(0, 2))), missing.size() - 2]
		_error("E0004", "non-exhaustive patterns: %s not covered" % listed.replace("`, `", "` and `") if missing.size() == 2 else "non-exhaustive patterns: %s not covered" % listed, e.line)


func _for(e: Dictionary) -> Dictionary:
	var iter := _scrutinee(e.iter)
	var t: Dictionary = iter.t
	var item: Dictionary = ANY
	var start := _seq
	var loans: Array = iter.loans
	if t.n == "Vec":
		item = t.a[0]
		if iter.place != null:
			_bind_moves(iter, not _is_copy(t), e.line)
	elif is_ref(t) and (t.a[0] as Dictionary).n == "Vec":
		item = R((t.a[0] as Dictionary).a[0], t.mut)
		if iter.place != null:
			loans = _consume(iter.place, e.line)
	elif t.n == "Iter":
		item = t.a[0]
	elif t.n != "?":
		if _type_phase():
			_error("E0277", "`%s` is not an iterator" % show(t), (e.iter as Dictionary).line)
	_tick()
	var my_span := _loop_count
	_loop_count += 1
	if _type_phase():
		_loops.append([_seq, 0])
	_scopes.append({})
	var bound: Array = []
	_pattern(e.pat, item, bound, false)
	var ids: Array = []
	for b: Array in bound:
		ids.append(_declare(b[0], b[1], b[2], true, e.line))
	var before := _snapshot()
	_block(e.body)
	var end := _tick()
	if _type_phase():
		_loops[my_span][1] = end
	# The iterator keeps its borrow for the whole loop.
	if not _type_phase():
		for loan_id: int in loans:
			_loans[loan_id].until = maxi(int(_loans[loan_id].until), end)
		# A value moved inside the loop is gone by the next time round.
		for i in before.size():
			var was: Dictionary = before[i][1]
			for path: String in _vars[i].moved:
				if not was.has(path) and _vars[i].decl < start:
					_error("E0382", "use of moved value: `%s` (value moved here, in previous iteration of loop)" % (str(_vars[i].name) + path), int(_vars[i].moved[path]))
	_scopes.pop_back()
	return {"t": UNIT, "loans": []}
