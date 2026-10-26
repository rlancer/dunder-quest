class_name CurbScene
extends Node2D

## One scene of the season, built from its entry in data/scenes.json.
##
## It opens on a black title card, the cast bicker, and then the player walks
## Barry around. Whoever has a "!" over their head has a dispute only a plan
## can settle: talking to them opens Barry's legal pad with the plan in Rust.
##
## Running a plan first plays it in Barry's head (sepia), line by line, the
## way rustc reads the whole program before anything happens. If it breaks
## the rules, Sharon bursts in at the offending line with the real rustc error
## and an opinion. If it compiles, the scene plays it out for real: every
## println! is somebody saying that line. The scene only moves on when the
## program prints exactly what should happen. After the last plan, the
## ending plays, freezes on an awkward look, and the sting comes in.

const FLOOR_Y := 246.0
const REACH := 34.0
const PERSON := preload("res://actors/person.gd")
const HUD := preload("res://ui/hud.gd")
const PAD := preload("res://ui/pad.gd")
## Barry's comebacks after Sharon's done with him. New words for an old look.
const COMEBACKS := [
	"Is that a rule? Is that a real rule?",
	"Where is that written? Show me where.",
	"Who decided that? Was there a vote?",
	"Okay. Okay. Okay. Fine.",
	"That's the etiquette? That's what we're doing now?",
	"You're sure? You're sure about that?",
]

var scene_id: int = 1
var data: Dictionary = {}
var barry: Person
var people: Dictionary = {}
var hud: Hud
var pad: LegalPad
var plans: Array[Plan] = []
var done: Array[bool] = []
var tries: int = 0
## Tests set this before a scene starts.
static var test_pace: float = 1.0
## Seconds between steps of a run are multiplied by this; tests shrink it.
var pace: float = test_pace
## "intro", "free", "busy", "ending", "cleared"
var state: String = "intro"

var _audio_locked: bool = false
var _comeback: int = 0
var _leave_armed: float = 0.0
var _cards_seen: Dictionary = {}


func _ready() -> void:
	add_to_group(&"curb_scene")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	data = Story.scene(scene_id)
	var audio := StageAudio.new()
	audio.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(audio)
	var backdrop := Sprite2D.new()
	backdrop.centered = false
	var art := "res://assets/backgrounds/%s.png" % data.get("key", "")
	if ResourceLoader.exists(art):
		backdrop.texture = load(art) as Texture2D
	backdrop.z_index = -10
	add_child(backdrop)
	for entry: Array in data.get("cast", []):
		var person := PERSON.new() as Person
		person.who = str(entry[0])
		person.display_name = Story.name_of(person.who)
		person.position = Vector2(float(entry[1]), FLOOR_Y)
		add_child(person)
		people[person.who] = person
	barry = people.get("barry")
	if barry == null:
		barry = PERSON.new() as Person
		barry.who = "barry"
		barry.display_name = "Barry"
		barry.position = Vector2(60, FLOOR_Y)
		add_child(barry)
		people["barry"] = barry
	barry.z_index = 2
	for who: String in people:
		if who != "barry":
			(people[who] as Person).face(barry.position.x)
	barry.face(240)
	for d: Dictionary in data.get("plans", []):
		plans.append(Plan.from_data(d))
		done.append(false)
	hud = HUD.new() as Hud
	add_child(hud)
	hud.place = str(data.get("place", ""))
	pad = PAD.new() as LegalPad
	add_child(pad)
	pad.run_requested.connect(_on_run)
	pad.closed.connect(func() -> void:
		if state == "pad":
			state = "free")
	if OS.has_feature("web") and not StageAudio.web_audio_unlocked:
		_audio_locked = true
		hud.show_press_to_start()
	else:
		_start.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if _audio_locked and event.is_pressed() and not event.is_echo():
		_audio_locked = false
		StageAudio.web_audio_unlocked = true
		hud.hide_press_to_start()
		get_viewport().set_input_as_handled()
		_start()
		return
	if state != "free":
		return
	if event.is_action_pressed(&"edit") or event.is_action_pressed(&"confirm"):
		var who := _near()
		if who != "":
			get_viewport().set_input_as_handled()
			talk(who)
	elif event.is_action_pressed(&"pause"):
		if _leave_armed > 0.0:
			_leave_to(Main.MAP)
		else:
			_leave_armed = 2.0


func _start() -> void:
	var music := "res://assets/audio/music_%s.ogg" % data.get("music", "scene")
	if ResourceLoader.exists(music):
		MusicDirector.play(load(music) as AudioStream)
	await hud.title_card(str(data.get("title", "")), str(data.get("place", "")))
	for line: Array in data.get("opening", []):
		await _say(line)
	state = "free"
	_update_markers()


func _physics_process(delta: float) -> void:
	_leave_armed = maxf(_leave_armed - delta, 0.0)
	if state != "free" or pad.is_open():
		barry.walk_dir = 0.0
		if state != "free":
			hud.prompt = ""
		return
	barry.walk_dir = Input.get_axis(&"move_left", &"move_right")
	var who := _near()
	if _leave_armed > 0.0:
		hud.prompt = "Esc again: back to the map"
	elif who != "":
		var key := "Tap TALK" if TouchControls.active else "E"
		hud.prompt = "%s: talk to %s" % [key, Story.name_of(who)]
	else:
		var next := next_plan()
		hud.prompt = "Go and talk to %s" % Story.name_of(str(plans[next].data.npc)) if next >= 0 else ""


## Index of the first unfinished plan, or -1.
func next_plan() -> int:
	for i in plans.size():
		if not done[i]:
			return i
	return -1


## Whoever with a pending plan Barry is standing next to, or "".
func _near() -> String:
	var next := next_plan()
	if next < 0:
		return ""
	var who := str(plans[next].data.npc)
	var person: Person = people.get(who)
	if person != null and absf(person.position.x - barry.position.x) <= REACH:
		return who
	return ""


func npc_of(index: int) -> Person:
	return people.get(str(plans[index].data.npc))


func _update_markers() -> void:
	for who: String in people:
		(people[who] as Person).marker = ""
	for i in plans.size():
		var person := npc_of(i)
		if person == null:
			continue
		if done[i] and person.marker == "":
			person.marker = "ok"
	var next := next_plan()
	if next >= 0 and npc_of(next) != null:
		npc_of(next).marker = "!"


## Starts the dispute with `who`: a lesson card the first time, then the pad.
func talk(who: String) -> void:
	var index := next_plan()
	if index < 0 or str(plans[index].data.npc) != who:
		return
	state = "busy"
	var person: Person = people[who]
	barry.face(person.position.x)
	person.face(barry.position.x)
	var card_id := str(plans[index].data.get("card", ""))
	if card_id != "" and not _cards_seen.has(card_id):
		_cards_seen[card_id] = true
		var card := Story.card(card_id)
		if not card.is_empty():
			Progress.read_card(card_id)
			await hud.show_card(card)
	open_pad(index)


func open_pad(index: int) -> void:
	state = "pad"
	pad.open(plans[index], str(plans[index].data.get("hint", "")))


func _on_run(plan: Plan) -> void:
	state = "busy"
	perform(plan)


## Plays a plan: the rehearsal (the borrow check), then the real thing.
func perform(plan: Plan) -> void:
	tries += 1
	var index := plans.find(plan)
	var npc := npc_of(index)
	var result := plan.evaluate()
	if not result.ok:
		await _rehearse(plan, result.error)
		pad.flagged_line = int(result.error.get("line", 0))
		open_pad(index)
		return
	pad.flagged_line = 0
	hud.show_code(plan, false)
	var run: Dictionary = result.run
	for event: Dictionary in run.events:
		hud.highlight(int(event.line))
		if event.has("say"):
			var said := _speaker_of(str(event.say))
			hud.show_line(said[0], said[1])
			await _pause(0.9 + str(said[1]).length() * 0.035)
			hud.clear_line()
		elif event.has("panic"):
			hud.mark_error_line(int(event.line))
			hud.flash()
			StageAudio.play(get_tree(), preload("res://assets/audio/break.wav"))
			for who: String in people:
				(people[who] as Person).strike(Person.Pose.YELL, 1.5)
			var lines: Array = plan.data.get("panic_line", [])
			var speaker := str(lines[0][0]) if not lines.is_empty() else Story.checker()
			var text := str(lines[0][1]) if not lines.is_empty() else Story.rant(plan.data, "panic")
			await hud.panic(speaker, text, str(event.panic), plan, int(event.line))
		else:
			await _pause(0.22)
	hud.hide_code()
	if result.passed:
		var picks := plan.picks()
		var remarks: Dictionary = plan.data.get("remarks", {})
		for slot: String in picks:
			var key := "%s=%s" % [slot, picks[slot]]
			for line: Array in remarks.get(key, []):
				await _say(line)
		for line: Array in plan.data.get("success", []):
			await _say(line)
		done[index] = true
		_update_markers()
		if next_plan() < 0:
			await _ending()
		else:
			state = "free"
		return
	if run.panic == "":
		var wrong: Array = plan.data.get("wrong", [])
		if wrong.is_empty():
			wrong = [[str(npc.who) if npc != null else Story.checker(), Story.rant(plan.data, "wrong")]]
		for line: Array in wrong:
			await _say(line)
	open_pad(index)


## Barry runs the plan in his head, line by line, up to the line that breaks
## the rules, and Sharon interrupts.
func _rehearse(plan: Plan, error: Dictionary) -> void:
	hud.show_code(plan, true)
	hud.set_sepia(1.0)
	var stop := int(error.get("line", 1))
	var src := plan.source().split("\n")
	for line in range(1, maxi(stop, 1) + 1):
		if line <= src.size() and str(src[line - 1]).strip_edges() == "":
			continue
		hud.highlight(line)
		await _pause(0.16)
	hud.mark_error_line(stop)
	StageAudio.play(get_tree(), preload("res://assets/audio/scratch.wav"))
	hud.flash()
	MusicDirector.duck(true)
	var checker := Story.checker()
	await hud.rant(checker, Story.rant(plan.data, str(error.get("code", "syntax")) if str(error.get("code", "")) != "" else "syntax"), error, plan)
	hud.set_sepia(0.0)
	hud.hide_code()
	MusicDirector.duck(false)
	# Each scene starts further along the list, so the comebacks rotate across the season.
	await _say(["barry", COMEBACKS[(_comeback + (scene_id - 1) * 2) % COMEBACKS.size()], "squint"])
	_comeback += 1


## The freeze-frame ending: the last awkward beat, a held look, the sting,
## then the black end card.
func _ending() -> void:
	state = "ending"
	for line: Array in data.get("ending", []):
		await _say(line, true)
	MusicDirector.stop()
	hud.set_freeze(1.0)
	barry.strike(Person.Pose.SQUINT, 99.0)
	hud.closeup("barry", 2, 1 if barry.position.x < 240 else -1)
	get_tree().paused = true
	await get_tree().create_timer(0.9 * maxf(pace, 0.05), true).timeout
	StageAudio.play(get_tree(), preload("res://assets/audio/sting.wav"))
	await get_tree().create_timer(1.2 * maxf(pace, 0.05), true).timeout
	hud.closeup("", 0)
	Progress.mark_cleared(scene_id, tries)
	state = "cleared"
	var plural := "try" if tries == 1 else "tries"
	await hud.end_card([str(data.get("title", "")), "Today's lesson: %s" % data.get("lesson", ""), "%d %s" % [tries, plural]])
	get_tree().paused = false
	_leave_to(Main.MAP)


func _leave_to(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


## "Name: text" said by Name, if Name is in the scene; otherwise a caption.
func _speaker_of(line: String) -> Array:
	var colon := line.find(": ")
	if colon > 0:
		var name := line.substr(0, colon)
		for who: String in people:
			if (people[who] as Person).display_name == name:
				return [people[who], line.substr(colon + 2)]
	return [null, line]


func _say(line: Array, ending: bool = false) -> void:
	var who := str(line[0])
	var person: Person = people.get(who)
	if person == null and who != "":
		# Sharon has a way of turning up wherever Barry is.
		person = _walk_on(who)
	var mood := str(line[2]) if line.size() > 2 else ""
	if person != null:
		if person != barry:
			person.face(barry.position.x)
			barry.face(person.position.x)
	await hud.say(person, str(line[1]), mood)
	if ending and mood == "squint":
		barry.strike(Person.Pose.SQUINT, 99.0)


func _walk_on(who: String) -> Person:
	var person := PERSON.new() as Person
	person.who = who
	person.display_name = Story.name_of(who)
	person.position = Vector2(440 if barry.position.x < 240 else 40, FLOOR_Y)
	add_child(person)
	people[who] = person
	return person


func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds * pace, false).timeout
