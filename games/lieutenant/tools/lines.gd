extends Node

## Prints every line the game speaks, for tools/voice.py: the prologue, each
## case's cold open, its talk, the questions put to Records and their hints,
## the lesson cards, and what Doris and the Lieutenant say over a printout.
##
## The printout's lines carry numbers and column names, so they're found the
## way tests/replay.gd finds the queries: every query each page can spell
## (up to three SELECT chips and two WHERE chips) goes through the Judge,
## and every line that comes back is listed. A page spelled past that (a
## fourth SELECT chip) can say a line with no clip; it's read in silence.
##
##     godot --headless --path . res://tools/lines.tscn

var _out: Array = []
var _seen: Dictionary = {}


func _ready() -> void:
	for page: Dictionary in Intro.script_beats():
		_add(Intro.page_line(page))
	_add(Notebook.DIALING)
	_add({"who": "lt", "text": Notebook.OK_REMARK})
	var cards := {}
	for c: Dictionary in Story.cases():
		var id := int(c.id)
		for entry: Array in c.get("cold_open", []):
			_add(Hud.caption_line(str(entry[0]), str(entry[1])))
		var said: Array = c.get("opening", []) + c.get("ending", [])
		for p: Dictionary in c.get("props", []):
			said += p.get("lines", []) as Array
		for beat: Dictionary in c.get("beats", []):
			said += (beat.get("claim", []) as Array) + (beat.get("success", []) as Array)
		for entry: Array in said:
			_add(Voice.of(entry))
		var db := Story.db(id)
		for beat: Dictionary in c.get("beats", []):
			_add({"who": "lt", "text": str(beat.get("ask", ""))})
			if str(beat.get("hint", "")) != "":
				_add(Notebook.hint_line(beat))
			var card_id := str(beat.get("card", ""))
			if card_id != "" and not cards.has(card_id):
				cards[card_id] = true
				_add(Hud.card_line(Story.card(card_id, id)))
			_printouts(db, beat)
	print("LINES " + JSON.stringify(_out))
	get_tree().quit()


## Everything Records and the Lieutenant can say over this page's printouts.
func _printouts(db: Dictionary, beat: Dictionary) -> void:
	var tray: Dictionary = beat.get("tray", {})
	var solution := Query.from_data(beat.get("solution", {}))
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
										for line: Dictionary in Notebook.printout_lines(Judge.check(db, beat, picks)):
											_add(line)


func _add(line: Dictionary) -> void:
	var said := Voice.spoken(line)
	var key := Voice.key_of(line)
	if said == "" or _seen.has(key):
		return
	_seen[key] = true
	_out.append({"key": key, "voice": str(line.get("who", "narrator")), "text": said})


## Subsets of `chips` up to `most` long, plus `extra`, as tests/replay.gd makes them.
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
