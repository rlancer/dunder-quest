extends SceneTree

## Holds data/episodes.json to the event loop, without opening a window:
##
## - every scene's written solution plays (airs its table read exactly),
##   using only cards on its table, each where it's allowed to go;
## - nothing with fewer cards does: every way the scene's cards can be put
##   on its hooks is played, so "par" on screen is the true fewest;
## - none of those ways leaves two timers due so close together that which
##   goes first would hang on the computer's speed (Loop.PHOTO_FINISH);
## - every card has a meaning in plain words, every lesson card's demo airs
##   what the card says it does, every scene has a brief and a hint, and
##   nothing is wider than the panel it's shown in.
##
## Then it writes tests/out/programs.json: every one of those programs, as
## the JavaScript it is, with what the game says it logs. tests/verify_loop.ts
## runs each with the real engine and demands the same.
##
## godot --headless --path . --script res://tests/replay.gd

const OUT := "res://tests/out/programs.json"
## The longest line logged that fits the table read, in characters.
const WIDEST_LOG := 18
## The most lines a table read shows.
const MOST_ROWS := 6
## Programs no table spells, to hold the engine to JavaScript on wider ground.
const PROBES := [
	[{"timeout": 0, "body": [{"log": "T1"}, {"then": [{"log": "T1 then"}]}]}, {"timeout": 0, "body": [{"log": "T2"}]},
		{"chain": [[{"log": "A1"}], [{"log": "A2"}], [{"log": "A3"}]]}, {"chain": [[{"log": "B1"}], [{"log": "B2"}]]},
		{"micro": [{"log": "Q"}]},
		{"async": "lenny", "body": [{"log": "L1"}, {"await": {"log": "L2"}}, {"log": "L3"}, {"wait": 100}, {"log": "L4"}]},
		{"async": "dana", "body": [{"log": "D1"}, {"await": {"call": "lenny"}}, {"log": "D2"}]},
		{"call": "dana"}, {"log": "sync"}],
	[{"async": "quick", "body": [{"log": "Q1"}]}, {"async": "caller", "body": [{"await": {"call": "quick"}}, {"log": "after quick"}]},
		{"call": "caller"}, {"then": [{"log": "then"}]}, {"log": "script"}],
	[{"micro": [{"log": "m1"}, {"micro": [{"log": "m3"}]}]}, {"micro": [{"log": "m2"}]}, {"timeout": 0, "body": [{"log": "t"}]}],
	[{"timeout": 100, "body": [{"log": "100"}, {"timeout": 0, "body": [{"log": "100+1"}]}]}, {"timeout": 100, "body": [{"log": "100 again"}]}, {"timeout": 300, "body": [{"log": "300"}]}],
	[{"chain": [[{"log": "c1"}, {"then": [{"log": "inner"}]}], [{"log": "c2"}], [{"log": "c3"}]]}, {"then": [{"log": "side"}]}],
	[{"async": "a", "body": [{"wait": 200}, {"log": "a done"}]}, {"async": "b", "body": [{"wait": 100}, {"log": "b done"}]},
		{"async": "both", "body": [{"await": {"call": "a"}}, {"await": {"call": "b"}}, {"log": "both done"}]}, {"call": "both"}],
	[{"async": "f", "body": [{"log": "f1"}, {"await": {"call": "g"}}, {"log": "f2"}]}, {"async": "g", "body": [{"log": "g1"}]},
		{"call": "f"}, {"micro": [{"log": "micro"}]}, {"log": "end"}],
]

var _problems: PackedStringArray = []
var _played: int = 0


func _init() -> void:
	var dump: Array = []
	var scenes := 0
	for line: Dictionary in Story.spoken_lines():
		_expect(Story.data().cast.has(str(line.who)), "nobody in the cast is called %s" % line.who)
	for e: Dictionary in Story.episodes():
		for key: String in ["title", "lesson", "place", "music", "intro", "scenes", "outro"]:
			_expect(e.has(key), "episode %s has no %s" % [e.get("id", "?"), key])
		for scene: Dictionary in e.get("scenes", []):
			scenes += 1
			if scene.has("card"):
				_expect(Story.data().cards.has(str(scene.card)), "%s: no card called %s" % [scene.id, scene.card])
			dump.append(_scene(scene))
	for id: String in Story.data().get("cards", {}):
		var card := Story.card(id)
		for key: String in ["title", "text", "chips", "demo", "out"]:
			_expect(card.has(key), "card %s has no %s" % [id, key])
		var ran := Loop.run(card.demo)
		_expect(ran.out == card.out, "card %s: its demo logs %s, not what the card says" % [id, ran.out])
		_expect(not bool(ran.photo), "card %s: its demo's timers are too close to call" % id)
		dump.append({"id": "card " + id, "programs": [_entry(card.demo, ran)]})
	var probes: Array = []
	for program: Array in PROBES:
		probes.append(_entry(program, Loop.run(program)))
	dump.append({"id": "probes", "programs": probes})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	FileAccess.open(OUT.get_base_dir() + "/.gdignore", FileAccess.WRITE).close()
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(dump))
	file.close()
	for line in _problems:
		print("PROBLEM ", line)
	print("REPLAY result=%s scenes=%d programs=%d" % ["ok" if _problems.is_empty() else "FAIL %d" % _problems.size(), scenes, _played])
	quit(0 if _problems.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	if not ok and not _problems.has(what):
		_problems.append(what)


func _entry(program: Array, ran: Dictionary) -> Dictionary:
	return {"source": Loop.source(program), "out": ran.out, "photo": bool(ran.photo)}


func _scene(scene: Dictionary) -> Dictionary:
	var id := str(scene.id)
	for key: String in ["brief", "hint", "script", "cues", "solution", "want"]:
		_expect(scene.has(key), "%s has no %s" % [id, key])
	var want: Array = scene.want
	_expect(want.size() <= MOST_ROWS, "%s wants more lines than the table read shows" % id)
	for text: String in want:
		_expect(text.length() <= WIDEST_LOG, "%s: \"%s\" is wider than the table read" % [id, text])
	for cue: String in scene.cues:
		_expect(Story.meaning(cue) != "", "%s: the card %s means nothing in the glossary" % [id, cue])
	# The solution: on the table, allowed where it goes, and it plays.
	var left: Array = (scene.cues as Array).duplicate()
	var solution: Dictionary = scene.solution
	for slot: String in solution:
		var cue := str(solution[slot])
		_expect(left.has(cue), "%s: its solution uses %s, which isn't on the table (or not that many times)" % [id, cue])
		left.erase(cue)
		_expect(Loop.refuse(scene.script, slot, cue) == "", "%s: its solution puts %s where it can't go" % [id, cue])
	var won := Judge.judge(scene, solution)
	_expect(bool(won.won), "%s: its solution airs %s" % [id, won.out])
	# Everything with the cards on the table.
	var programs: Array = []
	var seen := {}
	var par := Story.par(scene)
	for cues: Dictionary in Loop.placements(scene):
		_played += 1
		var result := Judge.judge(scene, cues)
		if result.has("error"):
			_expect(false, "%s: %s never finishes" % [id, cues])
			continue
		_expect(not bool(result.photo), "%s: with %s two timers are too close to call" % [id, cues])
		if bool(result.won) and cues.size() < par:
			_expect(false, "%s: %s plays with fewer cards than its solution" % [id, cues])
		if not bool(result.won):
			var said := Story.stock(str(result.why))
			_expect(not said.is_empty(), "%s: nothing to say about a take of the kind \"%s\"" % [id, result.why])
			for template: String in said:
				_expect(not Judge.fill(template, result).contains("{"), "%s: an unfilled blank in \"%s\"" % [id, template])
		var text := str(result.source)
		if not seen.has(text):
			seen[text] = true
			programs.append({"source": text, "out": result.out, "photo": bool(result.photo)})
	return {"id": id, "programs": programs}
