class_name Judge
extends RefCounted

## Reads what Records sent back and decides what the Lieutenant makes of it.
## A query is right when it returns what the beat's own solution returns:
## the same columns and the same rows (and, where the question asks for an
## order, the same order, from an ORDER BY). Any SQL that gets there counts.


## {verdict, says, result, target}. verdict is "ok", "error", "columns",
## "rows" or "order"; `says` is the Lieutenant's thought when it isn't ok.
static func check(db: Dictionary, beat: Dictionary, picks: Dictionary) -> Dictionary:
	var sql := Query.compose(picks)
	var result := Sql.run(db, sql)
	var target := Sql.run(db, Query.compose(Query.from_data(beat.get("solution", {}))))
	var out := {"sql": sql, "result": result, "target": target, "verdict": "ok", "says": ""}
	var stock: Dictionary = Story.stock("misses")
	if not result.ok:
		out.verdict = "error"
		out.says = _error_line(result.error, picks)
	elif not target.ok:
		out.verdict = "error"
		out.says = "The solution on file doesn't run: %s" % target.error.msg
	else:
		var map := _column_map(result.columns, target.columns)
		var missing: Array = map.missing
		if not missing.is_empty():
			out.verdict = "columns"
			out.says = str(stock.columns_missing) % _list(missing)
		elif result.columns.size() != target.columns.size():
			out.verdict = "columns"
			out.says = str(stock.columns_extra) % _list(target.columns)
		else:
			var got: Array = []
			for row: Array in result.rows:
				var shaped: Array = []
				for index: int in map.order:
					shaped.append(row[index])
				got.append(shaped)
			var want: Array = target.rows
			if not _same_bag(got, want):
				out.verdict = "rows"
				if got.is_empty():
					out.says = str(stock.rows_none)
				elif got.size() > want.size() and _contains(got, want):
					out.says = str(stock.rows_more) % [got.size(), want.size()]
				elif got.size() < want.size() and _contains(want, got):
					out.says = str(stock.rows_fewer) % [got.size(), want.size()]
				else:
					out.says = str(stock.rows_other) % got.size()
			elif bool(beat.get("ordered", false)):
				if not result.ordered:
					out.verdict = "order"
					out.says = str(stock.order_missing)
				elif var_to_str(got) != var_to_str(want):
					out.verdict = "order"
					out.says = str(stock.order_wrong)
	if out.verdict != "ok":
		var note := _note(beat, picks, str(result.error.msg) if not result.ok else "")
		if note != "":
			out.says = note
	return out


## A note the beat keeps for one particular wrong chip, if it's on the page.
## When the query didn't run, only a note about the thing the error names
## is to the point; the rest are about wrong answers.
static func _note(beat: Dictionary, picks: Dictionary, error: String) -> String:
	var notes: Dictionary = beat.get("notes", {})
	var solution := Query.from_data(beat.get("solution", {}))
	for key: String in notes:
		var line := key.get_slice(":", 0)
		var chip := key.substr(line.length() + 1)
		if error != "" and not error.contains(chip):
			continue
		if Query.has(picks, line, chip) and not Query.has(solution, line, chip):
			return str(notes[key])
	return ""


static func _error_line(error: Dictionary, picks: Dictionary) -> String:
	var stock: Dictionary = Story.stock("errors")
	var msg := str(error.msg)
	if error.kind == "syntax":
		return str(stock.empty_select)
	if error.kind == "strict":
		return str(stock.strict)
	if msg.begins_with("no such column: "):
		var column := msg.trim_prefix("no such column: ")
		if str(picks.get("from", "")) == "":
			return str(stock.no_from)
		if column.contains("."):
			return str(stock.no_table_column) % column.get_slice(".", 0)
		return str(stock.no_column)
	if msg.begins_with("ambiguous column name"):
		return str(stock.ambiguous)
	if msg.begins_with("misuse of aggregate"):
		return str(stock.aggregate_where)
	if msg.begins_with("HAVING clause"):
		return str(stock.having)
	return str(stock.other)


## Lines the player's columns up with the target's by name. `order` is, for
## each target column, the index of the player's column that carries it.
static func _column_map(got: Array, want: Array) -> Dictionary:
	var used := {}
	var order: Array = []
	var missing: Array = []
	for name: String in want:
		var found := -1
		for i in got.size():
			if not used.has(i) and str(got[i]) == name:
				found = i
				break
		if found < 0:
			missing.append(name)
		else:
			used[found] = true
			order.append(found)
	return {"order": order, "missing": missing}


static func _counts(rows: Array) -> Dictionary:
	var counts := {}
	for row: Array in rows:
		var id := var_to_str(row)
		counts[id] = int(counts.get(id, 0)) + 1
	return counts


static func _same_bag(a: Array, b: Array) -> bool:
	return a.size() == b.size() and _contains(a, b)


## Does `big` hold every row of `small`, as many times over?
static func _contains(big: Array, small: Array) -> bool:
	var have := _counts(big)
	var need := _counts(small)
	for id: String in need:
		if int(have.get(id, 0)) < int(need[id]):
			return false
	return true


static func _list(names: Array) -> String:
	var parts := PackedStringArray()
	for name: Variant in names:
		parts.append(str(name))
	if parts.size() <= 1:
		return "".join(parts)
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[-1]
