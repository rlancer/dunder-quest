class_name Sql
extends RefCounted

## A small SQL engine: the slice of SELECT the cases use, with SQLite's
## semantics. It parses the text the notebook shows (nothing is evaluated
## from the chips directly), resolves names in the order SQLite does, so the
## first error is the one SQLite reports, and answers with SQLite's own error
## text. tests/verify_sql.ts runs the same text through the real SQLite and
## demands the same columns, rows and errors.
##
## What it knows: SELECT [DISTINCT] with * and expressions and AS, FROM,
## [INNER|LEFT] JOIN ... ON, WHERE, GROUP BY, HAVING, ORDER BY, LIMIT;
## = <> < <= > >=, AND OR NOT, IS [NOT] NULL, [NOT] LIKE, [NOT] BETWEEN,
## [NOT] IN (list), + - * / ||; COUNT SUM AVG MIN MAX; NULL and three-valued
## logic; integer, real and text values with SQLite's comparison affinity.
##
## One rule is stricter than SQLite, on purpose (kind "strict"): a column
## beside an aggregate has to be in GROUP BY. SQLite would answer with a value
## from some row of the group; PostgreSQL and most others refuse, in the
## words used here.

const KEYWORDS := ["SELECT", "DISTINCT", "FROM", "JOIN", "LEFT", "INNER", "OUTER", "ON", "WHERE", "GROUP", "BY", "HAVING", "ORDER", "ASC", "DESC", "LIMIT", "AND", "OR", "NOT", "IS", "NULL", "LIKE", "BETWEEN", "IN", "AS"]
const AGGREGATES := ["COUNT", "SUM", "AVG", "MIN", "MAX"]


# --- Tables -----------------------------------------------------------------

## Tables from a case's JSON: {name: {"columns": [[name, type], ...], "rows": [[...], ...]}}.
## JSON numbers arrive as floats, so INTEGER columns are put back to ints.
static func load_tables(source: Dictionary) -> Dictionary:
	var db := {}
	for name: String in source:
		var t: Dictionary = source[name]
		var columns: Array = []
		for c: Array in t.get("columns", []):
			columns.append({"name": str(c[0]), "type": str(c[1]).to_upper()})
		var rows: Array = []
		for r: Array in t.get("rows", []):
			var row: Array = []
			for i in columns.size():
				var v: Variant = r[i] if i < r.size() else null
				if v == null:
					row.append(null)
				elif columns[i].type == "INTEGER":
					row.append(int(v))
				elif columns[i].type == "REAL":
					row.append(float(v))
				else:
					row.append(str(v))
			rows.append(row)
		db[name.to_lower()] = {"name": name, "columns": columns, "rows": rows}
	return db


# --- Running ----------------------------------------------------------------

## Runs one SELECT. Returns {ok, columns, rows, ordered, keys} or
## {ok: false, error: {msg, kind}}; kind is "syntax", "sqlite" or "strict".
## `keys` holds each row's ORDER BY values, so a test can tell a tie from a
## wrong order.
static func run(db: Dictionary, sql: String) -> Dictionary:
	var parser := Parser.new()
	var q := parser.parse(sql)
	if parser.error != "":
		return _fail(parser.error, "syntax")
	var plan := Plan.new()
	plan.db = db
	plan.sql = sql
	var problem := plan.prepare(q)
	if not problem.is_empty():
		return {"ok": false, "error": problem}
	return plan.execute()


static func _fail(msg: String, kind: String = "sqlite") -> Dictionary:
	return {"ok": false, "error": {"msg": msg, "kind": kind}}


## A value the way the sqlite3 shell prints it.
static func show(v: Variant) -> String:
	if v == null:
		return "NULL"
	if v is float:
		var f: float = v
		if is_finite(f) and f == floorf(f) and absf(f) < 1e15:
			return "%d.0" % int(f)
		return String.num(f, 6).rstrip("0").rstrip(".") if absf(f) < 1e15 else str(f)
	return str(v)


# --- Lexer ------------------------------------------------------------------

## [{t, v, text, s, e}, ...] ending in {t: "end"}; t is kw, id, num, str or op.
## On a bad token, the last entry is {t: "bad", text}.
static func lex(sql: String) -> Array:
	var out: Array = []
	var i := 0
	var n := sql.length()
	while i < n:
		var c := sql[i]
		if c == " " or c == "\n" or c == "\t" or c == "\r":
			i += 1
			continue
		var start := i
		if c == "'":
			var j := i + 1
			var text := ""
			var closed := false
			while j < n:
				if sql[j] == "'":
					if j + 1 < n and sql[j + 1] == "'":
						text += "'"
						j += 2
						continue
					closed = true
					break
				text += sql[j]
				j += 1
			if not closed:
				out.append({"t": "bad", "text": sql.substr(start), "s": start, "e": n})
				return out
			i = j + 1
			out.append({"t": "str", "v": text, "text": sql.substr(start, i - start), "s": start, "e": i})
		elif _digit(c):
			var j := i
			var real := false
			while j < n and (_digit(sql[j]) or (sql[j] == "." and not real and j + 1 < n and _digit(sql[j + 1]))):
				if sql[j] == ".":
					real = true
				j += 1
			var word := sql.substr(i, j - i)
			i = j
			out.append({"t": "num", "v": float(word) if real else int(word), "text": word, "s": start, "e": i})
		elif _alpha(c):
			var j := i
			while j < n and (_alpha(sql[j]) or _digit(sql[j])):
				j += 1
			var word := sql.substr(i, j - i)
			i = j
			if KEYWORDS.has(word.to_upper()):
				out.append({"t": "kw", "v": word.to_upper(), "text": word, "s": start, "e": i})
			else:
				out.append({"t": "id", "v": word, "text": word, "s": start, "e": i})
		else:
			var two := sql.substr(i, 2)
			if two in ["<>", "<=", ">=", "!=", "==", "||"]:
				i += 2
				out.append({"t": "op", "v": two, "text": two, "s": start, "e": i})
			elif c in ["=", "<", ">", "+", "-", "*", "/", "(", ")", ",", ".", ";"]:
				i += 1
				out.append({"t": "op", "v": c, "text": c, "s": start, "e": i})
			else:
				out.append({"t": "bad", "text": c, "s": start, "e": i + 1})
				return out
	out.append({"t": "end", "v": "", "text": "", "s": n, "e": n})
	return out


static func _digit(c: String) -> bool:
	return c >= "0" and c <= "9"


static func _alpha(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_"


# --- Parser -----------------------------------------------------------------

class Parser:
	var tokens: Array = []
	var pos: int = 0
	var sql: String = ""
	var error: String = ""

	func parse(text: String) -> Dictionary:
		sql = text
		tokens = Sql.lex(text)
		if tokens[-1].t == "bad":
			error = "unrecognized token: \"%s\"" % tokens[-1].text
			return {}
		var q := _select()
		if error != "":
			return {}
		if _is_op(";"):
			pos += 1
		if _peek().t != "end":
			_unexpected()
			return {}
		return q

	func _peek() -> Dictionary:
		return tokens[pos]

	func _is_kw(word: String) -> bool:
		return tokens[pos].t == "kw" and tokens[pos].v == word

	func _is_op(op: String) -> bool:
		return tokens[pos].t == "op" and tokens[pos].v == op

	func _take_kw(word: String) -> bool:
		if _is_kw(word):
			pos += 1
			return true
		return false

	func _take_op(op: String) -> bool:
		if _is_op(op):
			pos += 1
			return true
		return false

	## SQLite's words for a token it can't use here.
	func _unexpected() -> void:
		if error != "":
			return
		var t: Dictionary = tokens[pos]
		error = "incomplete input" if t.t == "end" else "near \"%s\": syntax error" % t.text

	func _expect_kw(word: String) -> bool:
		if _take_kw(word):
			return true
		_unexpected()
		return false

	func _expect_op(op: String) -> bool:
		if _take_op(op):
			return true
		_unexpected()
		return false

	func _select() -> Dictionary:
		var q := {"distinct": false, "items": [], "from": [], "where": null, "group": [], "having": null, "order": [], "limit": -1}
		if not _expect_kw("SELECT"):
			return q
		if _take_kw("DISTINCT"):
			q.distinct = true
		while true:
			var item := _item()
			if error != "":
				return q
			q.items.append(item)
			if not _take_op(","):
				break
		if _take_kw("FROM"):
			var first := _table_ref()
			if error != "":
				return q
			first["join"] = "first"
			q.from.append(first)
			while true:
				var kind := ""
				if _take_op(","):
					kind = "inner"
				elif _is_kw("JOIN") or _is_kw("INNER") or _is_kw("LEFT"):
					kind = "inner"
					if _take_kw("LEFT"):
						kind = "left"
						_take_kw("OUTER")
					else:
						_take_kw("INNER")
					if not _expect_kw("JOIN"):
						return q
				else:
					break
				var ref := _table_ref()
				if error != "":
					return q
				ref["join"] = kind
				if _take_kw("ON"):
					ref["on"] = _expr()
					if error != "":
						return q
				q.from.append(ref)
		if _take_kw("WHERE"):
			q.where = _expr()
			if error != "":
				return q
		if _take_kw("GROUP"):
			if not _expect_kw("BY"):
				return q
			while true:
				q.group.append(_expr())
				if error != "":
					return q
				if not _take_op(","):
					break
		if _take_kw("HAVING"):
			q.having = _expr()
			if error != "":
				return q
		if _take_kw("ORDER"):
			if not _expect_kw("BY"):
				return q
			while true:
				var term := {"e": _expr(), "desc": false}
				if error != "":
					return q
				if _take_kw("DESC"):
					term.desc = true
				else:
					_take_kw("ASC")
				q.order.append(term)
				if not _take_op(","):
					break
		if _take_kw("LIMIT"):
			if _peek().t != "num" or not (_peek().v is int):
				_unexpected()
				return q
			q.limit = int(_peek().v)
			pos += 1
		return q

	func _table_ref() -> Dictionary:
		if _peek().t != "id":
			_unexpected()
			return {}
		var ref := {"name": str(_peek().v), "alias": ""}
		pos += 1
		if _take_kw("AS"):
			if _peek().t != "id":
				_unexpected()
				return ref
			ref.alias = str(_peek().v)
			pos += 1
		elif _peek().t == "id":
			ref.alias = str(_peek().v)
			pos += 1
		return ref

	func _item() -> Dictionary:
		if _is_op("*"):
			pos += 1
			return {"star": true, "table": ""}
		if _peek().t == "id" and tokens[pos + 1].t == "op" and tokens[pos + 1].v == "." and tokens[pos + 2].t == "op" and tokens[pos + 2].v == "*":
			var table := str(_peek().v)
			pos += 3
			return {"star": true, "table": table}
		var e := _expr()
		if error != "":
			return {}
		var item := {"star": false, "e": e, "alias": ""}
		if _take_kw("AS"):
			if _peek().t != "id":
				_unexpected()
				return item
			item.alias = str(_peek().v)
			pos += 1
		elif _peek().t == "id":
			item.alias = str(_peek().v)
			pos += 1
		return item

	## Wraps a node with the text it was written as (SQLite names a result
	## column after its expression's text).
	func _span(node: Dictionary, start: int) -> Dictionary:
		if error != "" or node.is_empty():
			return node
		var s: int = tokens[start].s
		var e: int = tokens[pos - 1].e
		node["text"] = sql.substr(s, e - s)
		return node

	func _expr() -> Dictionary:
		return _or()

	func _or() -> Dictionary:
		var start := pos
		var left := _and()
		while error == "" and _take_kw("OR"):
			left = _span({"k": "bin", "op": "OR", "l": left, "r": _and()}, start)
		return left

	func _and() -> Dictionary:
		var start := pos
		var left := _not()
		while error == "" and _take_kw("AND"):
			left = _span({"k": "bin", "op": "AND", "l": left, "r": _not()}, start)
		return left

	func _not() -> Dictionary:
		var start := pos
		if _take_kw("NOT"):
			return _span({"k": "not", "e": _not()}, start)
		return _equality()

	func _equality() -> Dictionary:
		var start := pos
		var left := _comparison()
		while error == "":
			if _is_op("=") or _is_op("==") or _is_op("<>") or _is_op("!="):
				var op := "=" if (_is_op("=") or _is_op("==")) else "<>"
				pos += 1
				left = _span({"k": "bin", "op": op, "l": left, "r": _comparison()}, start)
			elif _is_kw("IS"):
				pos += 1
				var neg := _take_kw("NOT")
				if not _expect_kw("NULL"):
					return {}
				left = _span({"k": "isnull", "e": left, "neg": neg}, start)
			elif _is_kw("LIKE") or _is_kw("BETWEEN") or _is_kw("IN") or (_is_kw("NOT") and tokens[pos + 1].t == "kw" and tokens[pos + 1].v in ["LIKE", "BETWEEN", "IN"]):
				var neg := _take_kw("NOT")
				if _take_kw("LIKE"):
					left = {"k": "bin", "op": "LIKE", "l": left, "r": _comparison()}
					left = _span(left, start)
					if neg:
						left = _span({"k": "not", "e": left}, start)
				elif _take_kw("BETWEEN"):
					var lo := _comparison()
					if not _expect_kw("AND"):
						return {}
					left = _span({"k": "between", "e": left, "lo": lo, "hi": _comparison(), "neg": neg}, start)
				else:
					pos += 1
					if not _expect_op("("):
						return {}
					var list: Array = []
					while true:
						list.append(_expr())
						if error != "":
							return {}
						if not _take_op(","):
							break
					if not _expect_op(")"):
						return {}
					left = _span({"k": "in", "e": left, "list": list, "neg": neg}, start)
			else:
				break
		return left

	func _comparison() -> Dictionary:
		var start := pos
		var left := _additive()
		while error == "" and (_is_op("<") or _is_op("<=") or _is_op(">") or _is_op(">=")):
			var op := str(_peek().v)
			pos += 1
			left = _span({"k": "bin", "op": op, "l": left, "r": _additive()}, start)
		return left

	func _additive() -> Dictionary:
		var start := pos
		var left := _multiplicative()
		while error == "" and (_is_op("+") or _is_op("-")):
			var op := str(_peek().v)
			pos += 1
			left = _span({"k": "bin", "op": op, "l": left, "r": _multiplicative()}, start)
		return left

	func _multiplicative() -> Dictionary:
		var start := pos
		var left := _concat()
		while error == "" and (_is_op("*") or _is_op("/")):
			var op := str(_peek().v)
			pos += 1
			left = _span({"k": "bin", "op": op, "l": left, "r": _concat()}, start)
		return left

	func _concat() -> Dictionary:
		var start := pos
		var left := _unary()
		while error == "" and _is_op("||"):
			pos += 1
			left = _span({"k": "bin", "op": "||", "l": left, "r": _unary()}, start)
		return left

	func _unary() -> Dictionary:
		var start := pos
		if _take_op("-"):
			return _span({"k": "neg", "e": _unary()}, start)
		if _take_op("+"):
			return _unary()
		return _primary()

	func _primary() -> Dictionary:
		var start := pos
		var t := _peek()
		if t.t == "num":
			pos += 1
			return _span({"k": "lit", "v": t.v}, start)
		if t.t == "str":
			pos += 1
			return _span({"k": "lit", "v": t.v}, start)
		if _take_kw("NULL"):
			return _span({"k": "lit", "v": null}, start)
		if _take_op("("):
			var inner := _expr()
			if error != "" or not _expect_op(")"):
				return {}
			return _span({"k": "paren", "e": inner}, start)
		# SQLite lets a join keyword stand as a name here, so "SELECT LEFT JOIN"
		# trips on JOIN, not on LEFT.
		if t.t == "id" or (t.t == "kw" and t.v in ["LEFT", "INNER", "OUTER"]):
			pos += 1
			if _take_op("("):
				var call := {"k": "func", "name": str(t.text).to_upper(), "args": [], "star": false, "distinct": false}
				if _take_op("*"):
					call.star = true
				elif not _is_op(")"):
					if _take_kw("DISTINCT"):
						call.distinct = true
					while true:
						call.args.append(_expr())
						if error != "":
							return {}
						if not _take_op(","):
							break
				if not _expect_op(")"):
					return {}
				return _span(call, start)
			if _take_op("."):
				if _peek().t != "id":
					_unexpected()
					return {}
				var column := str(_peek().v)
				pos += 1
				return _span({"k": "col", "table": str(t.text), "name": column}, start)
			return _span({"k": "col", "table": "", "name": str(t.text)}, start)
		_unexpected()
		return {}


# --- Planner and executor ---------------------------------------------------

class Plan:
	var db: Dictionary
	var sql: String
	var q: Dictionary
	## [{def, key (how it's referred to), left, on}, ...] in FROM order.
	var sources: Array = []
	## [{e, label}, ...]: the result columns, with * expanded.
	var outputs: Array = []
	var aggregate: bool = false
	var _error: Dictionary = {}
	## A misplaced aggregate that SQLite only trips over once every name has
	## been found (it words that one differently).
	var _late: String = ""

	func prepare(query: Dictionary) -> Dictionary:
		q = query
		for ref: Dictionary in q.from:
			var key := str(ref.name).to_lower()
			if not db.has(key):
				return _sqlite("no such table: %s" % ref.name)
			var alias := str(ref.alias)
			sources.append({"def": db[key], "key": (alias if alias != "" else str(ref.name)).to_lower(), "left": ref.join == "left", "on": ref.get("on")})
		# The result columns, with * spread out.
		for item: Dictionary in q.items:
			if item.star:
				var table := str(item.table).to_lower()
				var found := false
				for s in sources.size():
					if table != "" and sources[s].key != table:
						continue
					found = true
					var def: Dictionary = sources[s].def
					for earlier in s:
						if sources[earlier].key == sources[s].key:
							return _sqlite("ambiguous column name: main.%s.%s" % [def.name, def.columns[0].name])
					for c in def.columns.size():
						outputs.append({"e": {"k": "col", "src": s, "col": c, "aff": def.columns[c].type, "table": "", "name": def.columns[c].name, "text": def.columns[c].name, "done": true}, "label": def.columns[c].name, "alias": ""})
				if not found:
					return _sqlite("no such table: %s" % item.table if table != "" else "no tables specified")
			else:
				outputs.append({"e": item.e, "label": "", "alias": str(item.alias)})
		# An aggregate query is one with GROUP BY or an aggregate among its
		# result columns; SQLite decides that before it reads anything else.
		for out: Dictionary in outputs:
			if not _resolve(out.e, "result", false):
				return _error
		for out: Dictionary in outputs:
			if _has_aggregate(out.e):
				aggregate = true
		if not q.group.is_empty():
			aggregate = true
		for out: Dictionary in outputs:
			if out.alias != "":
				out.label = out.alias
			elif out.e.k == "col":
				out.label = sources[int(out.e.src)].def.columns[int(out.e.col)].name
			else:
				out.label = str(out.e.get("text", ""))
		if q.having != null:
			if not aggregate:
				return _sqlite("HAVING clause on a non-aggregate query")
			if not _resolve(q.having, "having", false):
				return _error
		if q.where != null and not _resolve(q.where, "where", false):
			return _error
		for s: Dictionary in sources:
			if s.on != null and not _resolve(s.on, "where", false):
				return _error
		for term: Dictionary in q.order:
			var target := _order_target(term.e)
			if target >= 0:
				term["out"] = target
			elif not _resolve(term.e, "order" if aggregate else "order_plain", false):
				return _error
		for e: Dictionary in q.group:
			if not _resolve(e, "group", false):
				return _error
		for e: Dictionary in q.group:
			if _has_aggregate(e):
				return _sqlite("aggregate functions are not allowed in the GROUP BY clause")
		if _late != "":
			return _sqlite(_late)
		if aggregate:
			# The stricter rule: beside an aggregate, a bare column has to be grouped.
			for out: Dictionary in outputs:
				var loose := _ungrouped(out.e)
				if loose != "":
					return _strict(loose)
			if q.having != null:
				var loose := _ungrouped(q.having)
				if loose != "":
					return _strict(loose)
			for term: Dictionary in q.order:
				if not term.has("out"):
					var loose := _ungrouped(term.e)
					if loose != "":
						return _strict(loose)
		return {}

	func _sqlite(msg: String) -> Dictionary:
		_error = {"msg": msg, "kind": "sqlite"}
		return _error

	func _strict(column: String) -> Dictionary:
		_error = {"msg": "column \"%s\" must appear in the GROUP BY clause or be used in an aggregate function" % column, "kind": "strict"}
		return _error

	## ORDER BY 2, or ORDER BY an alias: the result column it means, or -1.
	func _order_target(e: Dictionary) -> int:
		if e.k == "lit" and e.v is int:
			return int(e.v) - 1 if int(e.v) >= 1 and int(e.v) <= outputs.size() else -1
		if e.k == "col" and str(e.table) == "":
			for i in outputs.size():
				if str(outputs[i].alias) != "" and str(outputs[i].alias).to_lower() == str(e.name).to_lower():
					return i
		return -1

	## Finds every column and checks where aggregates may stand. Returns false
	## with _error set to SQLite's message.
	func _resolve(e: Dictionary, where: String, inside_aggregate: bool) -> bool:
		match str(e.k):
			"lit":
				return true
			"col":
				if e.has("done"):
					return true
				var name := str(e.name).to_lower()
				var table := str(e.table).to_lower()
				var hits: Array = []
				for s in sources.size():
					if table != "" and sources[s].key != table:
						continue
					var columns: Array = sources[s].def.columns
					for c in columns.size():
						if str(columns[c].name).to_lower() == name:
							hits.append([s, c])
				var shown := "%s.%s" % [e.table, e.name] if table != "" else str(e.name)
				if hits.is_empty():
					_sqlite("no such column: %s" % shown)
					return false
				if hits.size() > 1:
					_sqlite("ambiguous column name: %s" % shown)
					return false
				e["src"] = hits[0][0]
				e["col"] = hits[0][1]
				e["aff"] = sources[int(hits[0][0])].def.columns[int(hits[0][1])].type
				return true
			"func":
				var name := str(e.name)
				if not Sql.AGGREGATES.has(name):
					_sqlite("no such function: %s" % name)
					return false
				if (e.star and name != "COUNT") or (not e.star and e.args.size() != 1):
					_sqlite("wrong number of arguments to function %s()" % name)
					return false
				# In a plain query SQLite refuses an aggregate in WHERE as it
				# reads it. In an aggregate query (and for ORDER BY in a plain
				# one) it lets it by and trips later, after the other names.
				if inside_aggregate or (where == "where" and not aggregate):
					_sqlite("misuse of aggregate function %s()" % name)
					return false
				if (where == "where" or where == "order_plain") and _late == "":
					_late = "misuse of aggregate: %s()" % name
				for arg: Dictionary in e.args:
					if not _resolve(arg, where, true):
						return false
				e["agg"] = true
				return true
			"bin":
				return _resolve(e.l, where, inside_aggregate) and _resolve(e.r, where, inside_aggregate)
			"not", "neg", "paren", "isnull":
				return _resolve(e.e, where, inside_aggregate)
			"between":
				return _resolve(e.e, where, inside_aggregate) and _resolve(e.lo, where, inside_aggregate) and _resolve(e.hi, where, inside_aggregate)
			"in":
				if not _resolve(e.e, where, inside_aggregate):
					return false
				for item: Dictionary in e.list:
					if not _resolve(item, where, inside_aggregate):
						return false
				return true
		return true

	func _has_aggregate(e: Dictionary) -> bool:
		match str(e.k):
			"func":
				return true
			"bin":
				return _has_aggregate(e.l) or _has_aggregate(e.r)
			"not", "neg", "paren", "isnull":
				return _has_aggregate(e.e)
			"between":
				return _has_aggregate(e.e) or _has_aggregate(e.lo) or _has_aggregate(e.hi)
			"in":
				if _has_aggregate(e.e):
					return true
				for item: Dictionary in e.list:
					if _has_aggregate(item):
						return true
		return false

	## The first column in `e` that is neither inside an aggregate nor in
	## GROUP BY, as "table.column"; "" if there is none.
	func _ungrouped(e: Dictionary) -> String:
		for g: Dictionary in q.group:
			if _same(g, e):
				return ""
		match str(e.k):
			"col":
				return "%s.%s" % [sources[int(e.src)].def.name, sources[int(e.src)].def.columns[int(e.col)].name]
			"bin":
				var left := _ungrouped(e.l)
				return left if left != "" else _ungrouped(e.r)
			"not", "neg", "paren", "isnull":
				return _ungrouped(e.e)
			"between":
				for part: Dictionary in [e.e, e.lo, e.hi]:
					var loose := _ungrouped(part)
					if loose != "":
						return loose
			"in":
				var loose := _ungrouped(e.e)
				if loose != "":
					return loose
				for item: Dictionary in e.list:
					loose = _ungrouped(item)
					if loose != "":
						return loose
		return ""

	func _same(a: Dictionary, b: Dictionary) -> bool:
		while str(a.k) == "paren":
			a = a.e
		while str(b.k) == "paren":
			b = b.e
		if a.k == "col" and b.k == "col":
			return int(a.src) == int(b.src) and int(a.col) == int(b.col)
		return a.k != "col" and b.k != "col" and str(a.get("text", "?")) == str(b.get("text", "!"))

	# --- Execution ---

	func execute() -> Dictionary:
		# FROM and the joins: every combination of rows that passes its ON.
		var envs: Array = [[]]
		for s: Dictionary in sources:
			var next: Array = []
			var blank: Array = []
			blank.resize(s.def.columns.size())
			for env: Array in envs:
				var matched := false
				for row: Array in s.def.rows:
					var candidate := env.duplicate()
					candidate.append(row)
					if s.on == null or Sql._truth(_eval(s.on, candidate, [])) == true:
						next.append(candidate)
						matched = true
				if s.left and not matched:
					var candidate := env.duplicate()
					candidate.append(blank)
					next.append(candidate)
			envs = next
		if sources.is_empty():
			envs = [[]]
		if q.where != null:
			envs = envs.filter(func(env: Array) -> bool: return Sql._truth(_eval(q.where, env, [])) == true)
		# Each result row, with the values ORDER BY will sort it on.
		var produced: Array = []
		if aggregate:
			var groups: Array = []
			if q.group.is_empty():
				groups.append(envs)
			else:
				var by_key := {}
				var keys: Array = []
				for env: Array in envs:
					var key: Array = []
					for g: Dictionary in q.group:
						key.append(_eval(g, env, []))
					var id := var_to_str(key)
					if not by_key.has(id):
						by_key[id] = []
						keys.append(key)
					by_key[id].append(env)
				# SQLite hands groups back in the order of their keys.
				var order: Array = range(keys.size())
				order.sort_custom(func(a: int, b: int) -> bool:
					var c := Sql._compare_rows(keys[a], keys[b])
					return c < 0 if c != 0 else a < b)
				for i: int in order:
					groups.append(by_key[var_to_str(keys[i])])
			for group: Array in groups:
				var first: Array = group[0] if not group.is_empty() else _blank_env()
				if q.having != null and Sql._truth(_eval(q.having, first, group)) != true:
					continue
				produced.append(_produce(first, group))
		else:
			for env: Array in envs:
				produced.append(_produce(env, []))
		if q.distinct:
			var seen := {}
			var unique: Array = []
			for p: Dictionary in produced:
				var id := var_to_str(p.row)
				if not seen.has(id):
					seen[id] = true
					unique.append(p)
			produced = unique
		var ordered: bool = not q.order.is_empty()
		if ordered:
			var order: Array = range(produced.size())
			order.sort_custom(func(a: int, b: int) -> bool:
				var ka: Array = produced[a].keys
				var kb: Array = produced[b].keys
				for i in ka.size():
					var c := Sql.compare(ka[i], kb[i])
					if c != 0:
						return (c > 0) if q.order[i].desc else (c < 0)
				return a < b)
			var sorted: Array = []
			for i: int in order:
				sorted.append(produced[i])
			produced = sorted
		var total := produced.size()
		if int(q.limit) >= 0 and produced.size() > int(q.limit):
			produced = produced.slice(0, int(q.limit))
		var columns: Array = []
		for out: Dictionary in outputs:
			columns.append(out.label)
		var rows: Array = []
		var keys: Array = []
		for p: Dictionary in produced:
			rows.append(p.row)
			keys.append(p.keys)
		return {"ok": true, "columns": columns, "rows": rows, "ordered": ordered, "keys": keys, "before_limit": total}

	func _blank_env() -> Array:
		var env: Array = []
		for s: Dictionary in sources:
			var blank: Array = []
			blank.resize(s.def.columns.size())
			env.append(blank)
		return env

	func _produce(env: Array, group: Array) -> Dictionary:
		var row: Array = []
		for out: Dictionary in outputs:
			row.append(_eval(out.e, env, group))
		var keys: Array = []
		for term: Dictionary in q.order:
			keys.append(row[int(term.out)] if term.has("out") else _eval(term.e, env, group))
		return {"row": row, "keys": keys}

	func _eval(e: Dictionary, env: Array, group: Array) -> Variant:
		match str(e.k):
			"lit":
				return e.v
			"col":
				return env[int(e.src)][int(e.col)]
			"paren":
				return _eval(e.e, env, group)
			"neg":
				var v: Variant = Sql._number(_eval(e.e, env, group))
				return null if v == null else -v
			"not":
				var t: Variant = Sql._truth(_eval(e.e, env, group))
				return null if t == null else int(not t)
			"isnull":
				var v: Variant = _eval(e.e, env, group)
				return int((v == null) != bool(e.neg))
			"between":
				var v: Variant = _eval(e.e, env, group)
				var lo: Variant = _compare_op(">=", e.e, e.lo, v, _eval(e.lo, env, group))
				var hi: Variant = _compare_op("<=", e.e, e.hi, v, _eval(e.hi, env, group))
				var both: Variant = Sql._and(lo, hi)
				return both if not e.neg or both == null else int(not both)
			"in":
				var v: Variant = _eval(e.e, env, group)
				if v == null:
					return null
				var unknown := false
				for item: Dictionary in e.list:
					var eq: Variant = _compare_op("=", e.e, item, v, _eval(item, env, group))
					if eq == null:
						unknown = true
					elif eq == 1:
						return 0 if e.neg else 1
				return null if unknown else (1 if e.neg else 0)
			"func":
				return _aggregate(e, group)
			"bin":
				var op := str(e.op)
				if op == "AND" or op == "OR":
					var l: Variant = Sql._truth(_eval(e.l, env, group))
					var r: Variant = Sql._truth(_eval(e.r, env, group))
					return Sql._and(l, r) if op == "AND" else Sql._or(l, r)
				var a: Variant = _eval(e.l, env, group)
				var b: Variant = _eval(e.r, env, group)
				match op:
					"=", "<>", "<", "<=", ">", ">=":
						return _compare_op(op, e.l, e.r, a, b)
					"LIKE":
						if a == null or b == null:
							return null
						return int(Sql.like(Sql.text(b), Sql.text(a)))
					"||":
						if a == null or b == null:
							return null
						return Sql.text(a) + Sql.text(b)
				var x: Variant = Sql._number(a)
				var y: Variant = Sql._number(b)
				if x == null or y == null:
					return null
				match op:
					"+":
						return x + y
					"-":
						return x - y
					"*":
						return x * y
					"/":
						if y == 0:
							return null
						if x is int and y is int:
							@warning_ignore("integer_division")
							return int(x) / int(y)
						return float(x) / float(y)
		return null

	## A comparison, after SQLite's affinity rule: a number column pulls a
	## numeric-looking string over to a number, and a text column pulls a bare
	## number over to text.
	func _compare_op(op: String, left: Dictionary, right: Dictionary, a: Variant, b: Variant) -> Variant:
		if a == null or b == null:
			return null
		var la := _affinity(left)
		var ra := _affinity(right)
		if la in ["INTEGER", "REAL"] and ra in ["TEXT", ""]:
			b = Sql._numeric(b)
		elif ra in ["INTEGER", "REAL"] and la in ["TEXT", ""]:
			a = Sql._numeric(a)
		elif la == "TEXT" and ra == "":
			b = Sql.text(b)
		elif ra == "TEXT" and la == "":
			a = Sql.text(a)
		var c := Sql.compare(a, b)
		match op:
			"=":
				return int(c == 0)
			"<>":
				return int(c != 0)
			"<":
				return int(c < 0)
			"<=":
				return int(c <= 0)
			">":
				return int(c > 0)
		return int(c >= 0)

	func _affinity(e: Dictionary) -> String:
		if e.k == "paren":
			return _affinity(e.e)
		return str(e.get("aff", "")) if e.k == "col" else ""

	func _aggregate(e: Dictionary, group: Array) -> Variant:
		var name := str(e.name)
		if e.star:
			return group.size()
		var values: Array = []
		var seen := {}
		for env: Array in group:
			var v: Variant = _eval(e.args[0], env, [])
			if v == null:
				continue
			if e.distinct:
				var id := var_to_str(v)
				if seen.has(id):
					continue
				seen[id] = true
			values.append(v)
		match name:
			"COUNT":
				return values.size()
			"SUM", "AVG":
				if values.is_empty():
					return null
				var total: Variant = 0
				for v: Variant in values:
					total += Sql._number(v)
				return float(total) / values.size() if name == "AVG" else total
			"MIN", "MAX":
				if values.is_empty():
					return null
				var best: Variant = values[0]
				for v: Variant in values:
					var c := Sql.compare(v, best)
					if (name == "MIN" and c < 0) or (name == "MAX" and c > 0):
						best = v
				return best
		return null


# --- Values -----------------------------------------------------------------

## SQLite's order: NULL, then numbers, then text (compared byte by byte).
static func compare(a: Variant, b: Variant) -> int:
	var ra := 0 if a == null else (2 if a is String else 1)
	var rb := 0 if b == null else (2 if b is String else 1)
	if ra != rb:
		return -1 if ra < rb else 1
	if ra == 0:
		return 0
	if ra == 2:
		var x: String = a
		var y: String = b
		return 0 if x == y else (-1 if x < y else 1)
	return 0 if a == b else (-1 if a < b else 1)


static func _compare_rows(a: Array, b: Array) -> int:
	for i in a.size():
		var c := compare(a[i], b[i])
		if c != 0:
			return c
	return 0


## true, false or null (unknown), the way WHERE reads a value.
static func _truth(v: Variant) -> Variant:
	if v == null:
		return null
	var n: Variant = _number(v)
	return n != 0


static func _and(l: Variant, r: Variant) -> Variant:
	var a: Variant = _truth(l)
	var b: Variant = _truth(r)
	if a == false or b == false:
		return 0
	if a == null or b == null:
		return null
	return 1


static func _or(l: Variant, r: Variant) -> Variant:
	var a: Variant = _truth(l)
	var b: Variant = _truth(r)
	if a == true or b == true:
		return 1
	if a == null or b == null:
		return null
	return 0


## A value as a number for arithmetic: text counts as the number it starts
## with, or 0.
static func _number(v: Variant) -> Variant:
	if v == null or v is int or v is float:
		return v
	if v is bool:
		return int(v)
	var s := str(v).strip_edges()
	if s.is_valid_int():
		return int(s)
	if s.is_valid_float():
		return float(s)
	var i := 0
	while i < s.length() and (_digit(s[i]) or (i == 0 and s[i] == "-")):
		i += 1
	return int(s.substr(0, i)) if i > 0 and s.substr(0, i) != "-" else 0


## Numeric affinity: a string that is entirely a number becomes that number.
static func _numeric(v: Variant) -> Variant:
	if v is String:
		var s: String = v
		if s.is_valid_int():
			return int(s)
		if s.is_valid_float():
			return float(s)
	return v


static func text(v: Variant) -> String:
	return show(v) if v != null else ""


## LIKE: % is any run, _ any one character, and ASCII letters match in
## either case.
static func like(pattern: String, value: String) -> bool:
	return _like(pattern.to_lower(), 0, value.to_lower(), 0)


static func _like(p: String, pi: int, s: String, si: int) -> bool:
	while pi < p.length():
		var c := p[pi]
		if c == "%":
			while pi < p.length() and p[pi] == "%":
				pi += 1
			if pi == p.length():
				return true
			for start in range(si, s.length() + 1):
				if _like(p, pi, s, start):
					return true
			return false
		if si >= s.length():
			return false
		if c != "_" and c != s[si]:
			return false
		pi += 1
		si += 1
	return si == s.length()
