extends SceneTree

## Holds data/shifts.json to the shell engine, without opening a window:
##
## - every ticket's written solution wins it, using only chips on its table,
##   and what it sends is exactly the ticket's `want`;
## - nothing shorter does (every row of chips shorter than the solution is
##   tried, so "par" on screen is the true fewest);
## - every chip has a meaning in plain words, every card's demo is a line
##   the engine runs, every ticket has a hint, and nothing on a ticket is
##   wider than the panel it's shown in;
## - a set of probes (lines no table spells) runs or is refused as expected.
##
## Then it writes tests/out/lines.json: for every ticket, every row of up to
## three chips, a few hundred longer ones picked at random, and the
## solution, each with what the game made of it (what it printed and wrote,
## or the error). tests/verify_shell.ts runs the same lines through the real
## bash and demands the same.
##
## godot --headless --path . --script res://tests/replay.gd

const OUT := "res://tests/out/lines.json"
## Rows of chips this long or shorter are all written out for the verifier.
const ALL_UP_TO := 3
const RANDOM_LONGER := 150
## The widest line of a file or a ticket that fits its panel, in characters.
const WIDEST := 21
## Lines no table can spell, to hold the engine to bash on wider ground.
const PROBES := [
	"wc orders.txt", "wc orders.txt menu.txt", "wc -l orders.txt menu.txt", "cat orders.txt | wc", "cat orders.txt | wc -w",
	"wc -c orders.txt", "wc -l -w orders.txt", "wc < orders.txt", "wc -l < orders.txt", "cat < orders.txt",
	"head orders.txt menu.txt", "head -n 2 orders.txt menu.txt", "tail -n 2 orders.txt menu.txt", "tail -n +6 orders.txt",
	"head -n -5 orders.txt", "tail -n 0 orders.txt", "head -n 0 orders.txt", "head -n x orders.txt", "tail -n x orders.txt",
	"head -n", "head nope.txt", "tail nope.txt", "cat nope.txt", "wc nope.txt", "sort nope.txt", "uniq nope.txt", "cut -f1 nope.txt",
	"grep beef nope.txt", "ls nope.txt", "ls orders.txt", "ls | sort -r", "nope", "nope | wc -l", "| wc -l", "ls |", "ls | | wc",
	"grep", "grep beef orders.txt menu.txt", "grep -c beef orders.txt menu.txt", "grep -n beef orders.txt", "grep -n -i HOT notes.txt",
	"grep -vc beef orders.txt", "grep -i -v hot notes.txt", "grep ^beef menu.txt", "grep 9$ menu.txt", "grep b..f orders.txt",
	"grep zebra orders.txt", "grep zebra orders.txt | wc -l", "cat orders.txt | grep melt | sort -r | head -n 2",
	"sort orders.txt", "sort -r orders.txt", "sort -u sold.txt", "sort -n tabs.txt", "sort -rn tabs.txt", "sort -nr tabs.txt",
	"sort -n -u tabs.txt", "sort -n orders.txt", "sort -rn orders.txt", "sort sold.txt tabs.txt", "sort -z tabs.txt", "sort -q tabs.txt",
	"sort -n menu.txt", "sort -rn menu.txt", "sort -n -u menu.txt", "sort -u -r sold.txt",
	"uniq sold.txt", "uniq -c sold.txt", "sort sold.txt | uniq -d", "sort sold.txt | uniq -u", "sort sold.txt | uniq -c | sort -rn",
	"sort sold.txt | uniq -c | sort -n", "uniq sold.txt out.txt", "uniq a b c", "sort sold.txt | uniq -c | sort -rn | head -n 1",
	"cut -d, -f1 tickets.csv", "cut -d, -f2,3 tickets.csv", "cut -d, -f2- tickets.csv", "cut -d, -f-2 tickets.csv",
	"cut -d, -f1,3 tickets.csv", "cut -d, -f9 tickets.csv", "cut -f2 tickets.csv", "cut -d, tickets.csv", "cut tickets.csv",
	"cut -d, -f0 tickets.csv", "cut -d, -f3-1 tickets.csv", "cut -d,, -f1 tickets.csv", "cut -c1-4 orders.txt", "cut -c 2 orders.txt",
	"cut -d, -f2 -s orders.txt", "cut -d, -f2 orders.txt", "cut -d, -c2 tickets.csv", "cut -d, -fx tickets.csv",
	"cat specials.txt | tr a-z A-Z", "cat specials.txt | tr -d aeiou", "cat specials.txt | tr abc x", "tr a-z A-Z specials.txt",
	"tr a-z", "tr", "cat specials.txt | tr z-a A-Z", "cat specials.txt | tr a-z", "cat specials.txt | tr -d a-z A-Z",
	"tr a-z A-Z < specials.txt", "tr a-z A-Z < nope.txt", "cat specials.txt | tr eo 01",
	"grep 86 notes.txt > board.txt", "grep 86 notes.txt > board.txt | wc -l", "> board.txt", "ls > board.txt",
	"sort tabs.txt > a.txt | sort sold.txt > b.txt", "cat orders.txt menu.txt | wc -l", "cat orders.txt | cat menu.txt",
	"cat -x orders.txt", "wc -x orders.txt", "uniq -x sold.txt", "cut -x tickets.csv", "tr -x a b", "head -x orders.txt",
	"ls | head -n 2", "ls | grep txt | wc -l", "ls | tail -n 1", "head -n 3 orders.txt | sort | tail -n 1",
]

var _problems: PackedStringArray = []
var _tried: int = 0
var _unsupported: int = 0


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1971
	var dump: Array = []
	var tickets := 0
	for line: Dictionary in Story.spoken_lines():
		_expect(Story.data().cast.has(str(line.who)), "nobody in the cast is called %s" % line.who)
	for name: String in Story.data().files:
		for text: String in Story.data().files[name]:
			_expect(text.length() <= WIDEST, "%s: \"%s\" is wider than the rail" % [name, text])
	for shift: Dictionary in Story.shifts():
		for key: String in ["title", "lesson", "place", "music", "intro", "tickets", "outro"]:
			_expect(shift.has(key), "shift %s has no %s" % [shift.get("id", "?"), key])
		for ticket: Dictionary in shift.get("tickets", []):
			tickets += 1
			dump.append(_ticket(ticket, rng))
	for id: String in Story.data().get("cards", {}):
		var card := Story.card(id)
		for key: String in ["title", "text", "chips", "demo"]:
			_expect(card.has(key), "card %s has no %s" % [id, key])
		var files := Story.files(card.demo.files)
		var ran := Shell.run(str(card.demo.line), files)
		_expect(not ran.has("error"), "card %s: the engine refuses its demo %s" % [id, card.demo.line])
		# What the card (and the site's page) says it prints is what it prints.
		if not ran.has("error"):
			var into := str(card.demo.get("into", ""))
			var printed: Array = Judge.lines(str(ran.files.get(into, "")) if into != "" else str(ran.out))
			_expect(not printed.is_empty() and printed == card.demo.out, "card %s: its demo prints %s, not what the card says" % [id, printed])
		dump.append({"id": "card " + id, "files": files, "lines": [_entry(str(card.demo.line), files)]})
	var kitchen := Story.files((Story.data().files as Dictionary).keys())
	var probes: Array = []
	for line: String in PROBES:
		probes.append(_entry(line, kitchen))
	dump.append({"id": "probes", "files": kitchen, "lines": probes})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	FileAccess.open(OUT.get_base_dir() + "/.gdignore", FileAccess.WRITE).close()
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(dump))
	file.close()
	for line in _problems:
		print("PROBLEM ", line)
	print("REPLAY result=%s tickets=%d lines=%d unsupported=%d" % ["ok" if _problems.is_empty() else "FAIL %d" % _problems.size(), tickets, _tried, _unsupported])
	quit(0 if _problems.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	if not ok and not _problems.has(what):
		_problems.append(what)


## What the game makes of a line, for the verifier.
func _entry(line: String, files: Dictionary) -> Dictionary:
	var ran := Shell.run(line, files)
	if ran.has("error"):
		if str(ran.kind) == "unsupported":
			_unsupported += 1
		return {"line": line, "error": ran.error, "kind": ran.kind, "count": ran.get("count", 0)}
	return {"line": line, "out": ran.out, "files": ran.files}


func _ticket(ticket: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var id := str(ticket.id)
	var chips: Array = ticket.chips
	var solution: Array = ticket.solution
	for key: String in ["brief", "hint", "files", "want"]:
		_expect(ticket.has(key), "%s has no %s" % [id, key])
	for chip: String in solution:
		_expect(chips.has(chip), "%s: its solution uses %s, which isn't on the table" % [id, chip])
	for chip: String in chips:
		_expect(Story.meaning(chip) != "", "%s: the chip %s has no meaning in the glossary" % [id, chip])
	for text: String in ticket.want:
		_expect(text.length() <= WIDEST, "%s: \"%s\" is wider than the ticket" % [id, text])
	_expect((ticket.want as Array).size() <= 7, "%s wants more lines than the ticket shows" % id)
	var files := Story.files(ticket.files)
	var result := Judge.judge(ticket, solution)
	_expect(not result.has("error"), "%s: the engine refuses its solution" % id)
	_expect(bool(result.get("won", false)), "%s: its solution doesn't win (%s)" % [id, result.get("why", "error")])
	# Nothing shorter may win; and every miss must have something said about it.
	var lines: Array = []
	var seen := {}
	var row: Array = []
	for length in range(1, solution.size()):
		row.resize(length)
		_rows(ticket, chips, row, 0, files, lines, seen, length <= ALL_UP_TO)
	for _i in RANDOM_LONGER:
		var length := rng.randi_range(ALL_UP_TO + 1, maxi(ALL_UP_TO + 1, solution.size() + 1))
		var pick: Array = []
		for _k in length:
			pick.append(chips[rng.randi_range(0, chips.size() - 1)])
		_note(" ".join(PackedStringArray(pick)), files, lines, seen)
	_note(" ".join(PackedStringArray(solution)), files, lines, seen)
	return {"id": id, "files": files, "lines": lines}


func _rows(ticket: Dictionary, chips: Array, row: Array, at: int, files: Dictionary, lines: Array, seen: Dictionary, keep: bool) -> void:
	if at == row.size():
		_tried += 1
		var result := Judge.judge(ticket, row)
		if bool(result.get("won", false)):
			_expect(false, "%s: \"%s\" wins with fewer chips than its solution" % [ticket.id, result.line])
		elif not result.has("error"):
			var said := Story.stock(str(result.why))
			_expect(not said.is_empty(), "%s: nothing to say about a miss of the kind \"%s\"" % [ticket.id, result.why])
			for template: String in said:
				_expect(not Judge.fill(template, ticket, result).contains("{"), "%s: an unfilled blank in \"%s\"" % [ticket.id, template])
		if keep:
			_note(" ".join(PackedStringArray(row)), files, lines, seen)
		return
	for chip: String in chips:
		row[at] = chip
		_rows(ticket, chips, row, at + 1, files, lines, seen, keep)


func _note(line: String, files: Dictionary, lines: Array, seen: Dictionary) -> void:
	if seen.has(line):
		return
	seen[line] = true
	lines.append(_entry(line, files))
