extends SceneTree

## Holds data/jobs.json to the regex engine, without opening a window:
##
## - every poster's written solution wins it, using only chips on its table;
## - nothing shorter does (every row of chips shorter than the solution is
##   tried, so "par" on screen is the true fewest);
## - every chip has a meaning in plain words, every card's demo is a pattern
##   the engine accepts, every poster has a hint;
## - the chip-reader (Rx.check) refuses what it should, in the right words.
##
## Then it writes tests/out/patterns.json: for every poster, every row of up
## to three chips, a few hundred longer ones picked at random, and the
## solution, each with what the game made of it (a refusal, or where it
## matched on every line and what each group caught). tests/verify_regex.ts
## runs the same patterns through JavaScript's RegExp and demands the same.
##
## godot --headless --path . --script res://tests/replay.gd

const OUT := "res://tests/out/patterns.json"
## Rows of chips this long or shorter are all written out for the verifier.
const ALL_UP_TO := 3
const RANDOM_LONGER := 300

var _problems: PackedStringArray = []
var _tried: int = 0


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1874
	var dump: Array = []
	var posters := 0
	for job: Dictionary in Story.jobs():
		for key: String in ["title", "lesson", "place", "music", "intro", "posters", "outro"]:
			_expect(job.has(key), "job %s has no %s" % [job.get("id", "?"), key])
		for poster: Dictionary in job.get("posters", []):
			posters += 1
			dump.append(_poster(poster, rng))
		for line: Dictionary in Story.spoken_lines():
			_expect(Story.data().cast.has(str(line.who)), "nobody in the cast is called %s" % line.who)
	for id: String in Story.data().get("cards", {}):
		var card := Story.card(id)
		for key: String in ["title", "text", "say", "chips"]:
			_expect(card.has(key), "card %s has no %s" % [id, key])
		if card.has("demo"):
			var pattern := str(card.demo.pattern)
			_expect(Rx.compiled(pattern) != null, "card %s: the engine refuses its demo %s" % [id, pattern])
			var rows: Array = []
			var any := false
			for text: String in card.demo.lines:
				var m := Rx.search(pattern, text)
				any = any or bool(m.found)
				rows.append(_spans(m))
			_expect(any, "card %s: its demo %s matches none of its lines" % [id, pattern])
			dump.append({"id": "card " + id, "lines": card.demo.lines, "patterns": [{"pattern": pattern, "rows": rows}]})
	_probes()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	FileAccess.open(OUT.get_base_dir() + "/.gdignore", FileAccess.WRITE).close()
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(dump))
	file.close()
	for line in _problems:
		print("PROBLEM ", line)
	print("REPLAY result=%s posters=%d patterns=%d" % ["ok" if _problems.is_empty() else "FAIL %d" % _problems.size(), posters, _tried])
	quit(0 if _problems.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	if not ok and not _problems.has(what):
		_problems.append(what)


func _poster(poster: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var id := str(poster.id)
	var chips: Array = poster.chips
	var solution: Array = poster.solution
	for key: String in ["brief", "hint", "lines"]:
		_expect(poster.has(key), "%s has no %s" % [id, key])
	for chip: String in solution:
		_expect(chips.has(chip), "%s: its solution uses %s, which isn't on the table" % [id, chip])
	for chip: String in chips:
		_expect(Rx.meaning_of(chip) != "", "%s: the chip %s has no meaning in plain words" % [id, chip])
	var wanted := 0
	for line: Dictionary in poster.lines:
		wanted += 1 if bool(line.want) else 0
		if line.has("take"):
			_expect(str(line.text).contains(str(line.take)), "%s: \"%s\" isn't in \"%s\"" % [id, line.take, line.text])
	_expect(wanted > 0 and wanted < (poster.lines as Array).size(), "%s needs somebody to catch and somebody to leave" % id)
	if poster.has("card"):
		_expect(not Story.card(str(poster.card)).is_empty(), "%s: no card called %s" % [id, poster.card])
	var result := Judge.judge(poster, solution)
	_expect(not result.has("error") and bool(result.get("won", false)), "%s: its solution %s doesn't win it" % [id, Rx.text(solution)])

	# Nothing shorter wins, and what's written out for the verifier.
	var patterns: Array = []
	var shorter := PackedStringArray()
	var row: Array = []
	_every(poster, chips, row, solution.size(), patterns, shorter)
	_expect(shorter.is_empty(), "%s: par is %d, but shorter posters win: %s" % [id, solution.size(), ", ".join(shorter.slice(0, 6))])
	for _i in RANDOM_LONGER:
		var tokens: Array = []
		for _n in rng.randi_range(ALL_UP_TO + 1, 7):
			tokens.append(chips[rng.randi_range(0, chips.size() - 1)])
		patterns.append(_record(poster, tokens))
	patterns.append(_record(poster, solution))
	var texts := PackedStringArray()
	for line: Dictionary in poster.lines:
		texts.append(str(line.text))
	return {"id": id, "lines": texts, "patterns": patterns}


## Every row of chips shorter than `par` (and up to ALL_UP_TO for the
## verifier), depth first.
func _every(poster: Dictionary, chips: Array, row: Array, par: int, patterns: Array, shorter: PackedStringArray) -> void:
	if not row.is_empty():
		_tried += 1
		if row.size() < par and bool(Judge.judge(poster, row).get("won", false)):
			shorter.append(Rx.text(row))
		if row.size() <= ALL_UP_TO:
			patterns.append(_record(poster, row))
	if row.size() >= maxi(par - 1, ALL_UP_TO):
		return
	for chip: String in chips:
		row.append(chip)
		_every(poster, chips, row, par, patterns, shorter)
		row.pop_back()


func _record(poster: Dictionary, tokens: Array) -> Dictionary:
	var pattern := Rx.text(tokens)
	var problem := Rx.check(tokens)
	if not problem.is_empty():
		return {"pattern": pattern, "error": str(problem.error), "house": bool(problem.get("house", false))}
	_expect(Rx.compiled(pattern) != null, "%s: the chip-reader allows %s but the engine refuses it" % [poster.id, pattern])
	var rows: Array = []
	for line: Dictionary in poster.lines:
		rows.append(_spans(Rx.search(pattern, str(line.text))))
	return {"pattern": pattern, "rows": rows}


## A match as the verifier compares it: null, or [[start, end], ...] by group.
func _spans(m: Dictionary) -> Variant:
	return m.groups if bool(m.found) else null


func _probes() -> void:
	var cases := [
		[["*"], "repeat_start"], [["a", "*"], ""], [["a", "*", "?"], ""], [["a", "*", "?", "?"], "lazy_twice"],
		[["a", "+", "*"], "repeat_twice"], [["a", "?", "?"], ""], [["a", "?", "+"], "repeat_twice"],
		[["^", "*"], "repeat_place"], [["\\b", "+"], "repeat_place"], [["a", "$", "?"], "repeat_place"],
		[["(", "+"], "repeat_start"], [["a", "|", "*"], "repeat_start"], [["(", "a", ")", "+"], ""],
		[[")"], "close"], [["(", "a"], "open"], [["(", "(", "a", ")"], "open"], [["(", ")", ")"], "close"],
		[["\\1"], "ref_early"], [["(", "a", "\\1", ")"], "ref_early"], [["(", "a", ")", "\\1"], ""],
		[["a", "{3}"], ""], [["a", "{3}", "?"], ""], [["a", "{3}", "{3}"], "repeat_twice"], [["{3}"], "repeat_start"],
		[["|"], ""], [["(", "|", "a", ")"], ""], [["\\d", "+"], ""], [["[ao]", "*"], ""], [[".", "*", "?"], ""],
	]
	for case: Array in cases:
		var problem := Rx.check(case[0])
		var got := str(problem.get("error", ""))
		_expect(got == str(case[1]), "the chip-reader says \"%s\" to %s, not \"%s\"" % [got, Rx.text(case[0]), case[1]])
		if got == "":
			_expect(Rx.compiled(Rx.text(case[0])) != null, "the engine refuses %s" % Rx.text(case[0]))
		else:
			_expect(Story.error_text(problem) != "", "no words for the error %s" % got)
	# What the lessons claim, checked against the engine.
	_expect(_match("H.nk", "Hank") == "Hank" and _match("H.nk", "Hnk") == "", "the dot is exactly one character")
	_expect(_match("\".*\"", "a \"b\" c \"d\" e") == "\"b\" c \"d\"", "greedy runs to the last quote")
	_expect(_match("\".*?\"", "a \"b\" c \"d\" e") == "\"b\"", "lazy stops at the first quote")
	_expect(_match("pf*t", "pt") == "pt" and _match("pf+t", "pt") == "", "star takes zero, plus doesn't")
	_expect(_match("\\bKid\\b", "Kidney Hobson") == "" and _match("\\bKid\\b", "the Kid") == "Kid", "the word edge")
	_expect(_match("WANTED: DEAD|ALIVE", "STILL ALIVE") == "ALIVE", "a bare | splits the whole pattern")
	_expect(_match("(\\w+) \\1", "Bing Bang Bang") == "Bang Bang", "\\1 is the same text again")


func _match(pattern: String, subject: String) -> String:
	var m := Rx.search(pattern, subject)
	return subject.substr(m.start, int(m.end) - int(m.start)) if bool(m.found) else ""
