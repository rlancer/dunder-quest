extends SceneTree

## Runs every beat's solution, and every query the chips on its page can
## spell (up to three SELECT chips, two WHERE chips), through the in-game
## SQL engine, and checks the script against it: the solution is accepted,
## it returns something, every note is tied to a chip that exists and is
## wrong, and every lesson card's SQL runs. Writes each query and what the
## engine made of it to tests/out/queries.jsonl, for tests/verify_sql.ts to
## put to the real SQLite.
##
## godot --headless --path . --script res://tests/replay.gd

const OUT := "res://tests/out/queries.jsonl"

var _fails: PackedStringArray = []
var _lines: PackedStringArray = []
var _seen: Dictionary = {}


func _init() -> void:
	for c: Dictionary in Story.cases():
		var db := Story.db(int(c.id))
		for beat: Dictionary in c.get("beats", []):
			_beat(c, db, beat)
	_cards()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out"))
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string("\n".join(_lines) + "\n")
	file.close()
	print("REPLAY result=%s queries=%d" % ["ok" if _fails.is_empty() else "FAIL " + "; ".join(_fails), _lines.size()])
	quit(0 if _fails.is_empty() else 1)


func _beat(c: Dictionary, db: Dictionary, beat: Dictionary) -> void:
	var id := str(beat.id)
	var tray: Dictionary = beat.get("tray", {})
	var solution := Query.from_data(beat.get("solution", {}))
	# Every chip the solution uses has to be on the page.
	for line: String in Query.LINES:
		var chips: Array = tray.get(line, [])
		var picked: Array = solution[line] if Query.MULTI.has(line) else ([solution[line]] if str(solution[line]) != "" else [])
		for chip: Variant in picked:
			if not chips.has(chip):
				_fail("%s: the solution's %s chip \"%s\" isn't on the page" % [id, line, chip])
	for table: String in tray.get("from", []):
		if not (c.tables as Dictionary).has(table):
			_fail("%s: FROM chip \"%s\" isn't a table in this case" % [id, table])
	var verdict := Judge.check(db, beat, solution)
	if verdict.verdict != "ok":
		_fail("%s: the solution isn't accepted (%s)" % [id, verdict.says])
		return
	if (verdict.result.rows as Array).is_empty():
		_fail("%s: the solution returns no rows" % id)
	if bool(beat.get("ordered", false)) and not verdict.result.ordered:
		_fail("%s: asks for an order but the solution has no ORDER BY" % id)
	_record(int(c.id), id, "solution", "case:%d" % int(c.id), Query.compose(solution), verdict.result)
	# Notes: a real chip, not in the solution, and wrong when swapped in.
	for key: String in beat.get("notes", {}):
		var line := key.get_slice(":", 0)
		var chip := key.substr(line.length() + 1)
		var chips: Array = tray.get(line, [])
		if not chips.has(chip):
			_fail("%s: note \"%s\" is for a chip that isn't on the page" % [id, key])
			continue
		if Query.has(solution, line, chip):
			_fail("%s: note \"%s\" is for a chip the solution uses" % [id, key])
			continue
		var wrong := solution.duplicate(true)
		if line == "logic":
			wrong["logic"] = chip
		elif Query.MULTI.has(line) and line != "select":
			wrong[line] = [chip]
		elif line == "select":
			(wrong.select as Array).append(chip)
		else:
			wrong[line] = chip
		if Judge.check(db, beat, wrong).verdict == "ok":
			_fail("%s: note \"%s\" is for a chip that also solves it" % [id, key])
	# Everything the page can spell.
	var count := 0
	for select: Array in _subsets(tray.get("select", []), 3, solution.select):
		for from: String in [""] + (tray.get("from", []) as Array):
			for join: Array in _subsets(tray.get("join", []), 1, []):
				for where: Array in _subsets(tray.get("where", []), 2, solution.where):
					for logic: String in (tray.get("logic", ["AND"]) as Array if where.size() > 1 else ["AND"]):
						for group: String in [""] + (tray.get("group", []) as Array):
							for having: String in [""] + (tray.get("having", []) as Array):
								for order: String in [""] + (tray.get("order", []) as Array):
									for limit: String in [""] + (tray.get("limit", []) as Array):
										var picks := {"select": select, "from": from, "join": join, "where": where, "logic": logic, "group": group, "having": having, "order": order, "limit": limit}
										var sql := Query.compose(picks)
										_record(int(c.id), id, "combo", "case:%d" % int(c.id), sql, Sql.run(db, sql))
										count += 1
	print("%s  %d queries" % [id, count])


func _cards() -> void:
	var used := {}
	for c: Dictionary in Story.cases():
		for beat: Dictionary in c.get("beats", []):
			var card_id := str(beat.get("card", ""))
			if card_id == "" or used.has(card_id):
				continue
			used[card_id] = true
			var card := Story.card(card_id, int(c.id))
			if card.is_empty():
				_fail("%s: no card \"%s\"" % [beat.id, card_id])
				continue
			var result := Sql.run(card.db, str(card.sql))
			if not result.ok:
				_fail("card %s: %s" % [card_id, result.error.msg])
			elif (result.rows as Array).is_empty():
				_fail("card %s returns no rows" % card_id)
			var where := "card:%s" % card_id if (Story.data().cards[card_id] as Dictionary).has("tables") else "case:%d" % int(c.id)
			_record(int(c.id), card_id, "card", where, str(card.sql), result)
	for card_id: String in Story.data().get("cards", {}):
		if not used.has(card_id):
			_fail("card %s is never shown" % card_id)


## Subsets of `chips` up to `most` long, in page order, plus `extra` (the
## solution's own picks, which may be longer or in another order).
func _subsets(chips: Array, most: int, extra: Array) -> Array:
	var out: Array = [[]]
	for size in range(1, most + 1):
		_choose(chips, size, 0, [], out)
	if not extra.is_empty() and not out.has(extra):
		out.append(extra.duplicate())
	return out


func _choose(chips: Array, size: int, start: int, current: Array, out: Array) -> void:
	if current.size() == size:
		out.append(current.duplicate())
		return
	for i in range(start, chips.size()):
		current.append(chips[i])
		_choose(chips, size, i + 1, current, out)
		current.pop_back()


func _record(case_id: int, beat: String, role: String, db_key: String, sql: String, result: Dictionary) -> void:
	var id := "%s|%s|%s" % [db_key, role if role != "combo" else "", sql]
	if _seen.has(id):
		return
	_seen[id] = true
	var line := {"case": case_id, "beat": beat, "role": role, "db": db_key, "sql": sql, "ok": result.ok}
	if result.ok:
		line["columns"] = result.columns
		line["rows"] = result.rows
		line["ordered"] = result.ordered
		line["keys"] = result.keys
		line["limited"] = int(result.before_limit) > (result.rows as Array).size()
	else:
		line["error"] = result.error.msg
		line["kind"] = result.error.kind
	_lines.append(JSON.stringify(line))


func _fail(text: String) -> void:
	_fails.append(text)
	print("FAIL ", text)
